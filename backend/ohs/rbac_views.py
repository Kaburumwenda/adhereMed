"""Roles & Access (RBAC) API for the OHSMS module.

Endpoints (registered under ``/api/ohs/``):

    GET    rbac/                          live role × capability matrix
    PATCH  rbac/users/<id>/role/          reassign a member's role
    GET    rbac/roles/                    list custom roles
    POST   rbac/roles/                    create a custom role
    PATCH  rbac/roles/<id>/               edit a custom role
    DELETE rbac/roles/<id>/               delete a custom role
    PATCH  rbac/builtin-roles/<key>/      override a built-in role's caps
    DELETE rbac/builtin-roles/<key>/      reset a built-in role to defaults

All mutation endpoints are tenant-admin only; the matrix itself is readable
by anyone with ``rbac.manage`` or ``staff.view`` so the page can render
read-only for curious managers.
"""
from django.db import transaction
from rest_framework import serializers, status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import OhsRoleDefinition
from .rbac import (
    ALL_CAP_KEYS, ASSIGNABLE_ROLES, BUILTIN_ROLE_CAPS, CAPABILITY_LABELS,
    EDITABLE_BUILTIN_ROLES, PROTECTED_BUILTIN_CAPS, RESERVED_ROLE_KEYS,
    ROLE_META, TIERS, capability_groups, capability_matrix,
    get_role_capabilities, has_capability, _role_caps, role_risk_summary,
)


# ─────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────
def _can_view(request):
    return (has_capability(request, 'rbac.manage')
            or has_capability(request, 'staff.view'))


def _can_manage(request):
    user = getattr(request, 'user', None)
    role = getattr(user, 'role', '') or ''
    if role == 'super_admin' or getattr(user, 'is_superuser', False):
        return True
    return has_capability(request, 'rbac.manage')


def _members(request, include_self=True):
    """Active tenant users that make sense in a safety role matrix."""
    from accounts.models import User

    tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
    qs = User.objects.filter(is_active=True)
    if tenant is not None:
        qs = qs.filter(tenant=tenant)
    qs = qs.exclude(role__in=[
        'patient', 'caregiver', 'super_admin', 'doctor', 'nurse', 'midwife',
        'pharmacist', 'pharmacy_tech', 'cashier',
    ])
    out = []
    for u in qs.order_by('first_name', 'last_name'):
        name = f'{u.first_name} {u.last_name}'.strip() or u.email
        out.append({
            'id': u.id,
            'name': name,
            'email': u.email,
            'role': u.role,
            'is_active': u.is_active,
        })
    return out


def _custom_roles():
    try:
        return list(OhsRoleDefinition.objects.filter(is_system=False, is_active=True))
    except Exception:
        return []


def _override_keys():
    try:
        return set(OhsRoleDefinition.objects
                   .filter(is_system=True, is_active=True)
                   .values_list('key', flat=True))
    except Exception:
        return set()


def _serialize_role(meta, members, overrides):
    caps = sorted(_role_caps(meta['key']))
    tier = meta.get('tier', 'custom')
    return {
        **meta,
        'tier_label': (TIERS.get(tier) or {}).get('label', 'Custom'),
        'tier_color': (TIERS.get(tier) or {}).get('color', 'primary'),
        'is_custom': meta.get('is_custom', False),
        'is_override': meta['key'] in overrides,
        'editable': meta.get('editable', False),
        'capabilities': caps,
        'capability_count': len(caps),
        'user_count': len([m for m in members if m['role'] == meta['key']]),
        'users': [m for m in members if m['role'] == meta['key']],
        'risk': role_risk_summary(set(caps)),
    }


# ─────────────────────────────────────────────────────────────────────────
#  Matrix
# ─────────────────────────────────────────────────────────────────────────
class OhsRBACMatrixView(APIView):
    """The live role × capability matrix plus staff grouped by role."""

    def get(self, request):
        if not _can_view(request):
            return Response(
                {'detail': 'You do not have permission to view roles & access.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        members = _members(request)
        overrides = _override_keys()

        builtin = [
            _serialize_role(
                {**meta, 'editable': meta['key'] in EDITABLE_BUILTIN_ROLES},
                members, overrides,
            )
            for meta in ROLE_META
        ]

        custom = [
            _serialize_role(
                {
                    'key': rd.key, 'label': rd.label, 'tier': 'custom',
                    'icon': rd.icon or 'mdi-badge-account-horizontal-outline',
                    'description': rd.description or '',
                    'editable': True, 'is_custom': True, 'id': rd.id,
                },
                members, overrides,
            )
            for rd in _custom_roles()
        ]

        assignable = list(ASSIGNABLE_ROLES) + [rd.key for rd in _custom_roles()]
        my_caps = sorted(get_role_capabilities(request))

        return Response({
            'roles': builtin + custom,
            'custom_roles': custom,
            'capability_groups': capability_groups(),
            'capabilities': capability_matrix(),
            'assignable_roles': assignable,
            'tiers': TIERS,
            'protected_caps': sorted(PROTECTED_BUILTIN_CAPS),
            'can_manage': _can_manage(request),
            'my_role': getattr(request.user, 'role', ''),
            'my_capabilities': my_caps,
            'my_capability_count': len(my_caps),
            'total_capabilities': len(ALL_CAP_KEYS),
            'unassigned': [m for m in members
                           if m['role'] not in
                           {r['key'] for r in builtin + custom}],
        })


# ─────────────────────────────────────────────────────────────────────────
#  Assign a member's role
# ─────────────────────────────────────────────────────────────────────────
class OhsRBACSetUserRoleView(APIView):
    """Change one member's role. Owner roles are out of scope."""

    def patch(self, request, user_id):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=status.HTTP_403_FORBIDDEN)

        from accounts.models import User

        new_role = (request.data.get('role') or '').strip()
        allowed = set(ASSIGNABLE_ROLES) | {rd.key for rd in _custom_roles()}
        if new_role not in allowed:
            return Response(
                {'detail': f'That role cannot be assigned here. Choose one of: '
                           f'{", ".join(sorted(allowed))}.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
        qs = User.objects.filter(pk=user_id)
        if tenant is not None:
            qs = qs.filter(tenant=tenant)
        user = qs.first()
        if user is None:
            return Response({'detail': 'Member not found in this organization.'},
                            status=status.HTTP_404_NOT_FOUND)
        if user.role in ('tenant_admin', 'super_admin'):
            return Response(
                {'detail': 'The owner role can only be transferred by the platform.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.pk == request.user.pk:
            return Response({'detail': 'You cannot change your own role.'},
                            status=status.HTTP_400_BAD_REQUEST)

        old_role = user.role
        user.role = new_role
        user.save(update_fields=['role'])

        try:
            from audit.utils import log_event
            log_event(
                request=request, action='config', object_type='ohs/rbac',
                object_id=user.pk,
                object_repr=f'{user.email}: {old_role} → {new_role}',
                description=f'Changed {user.email} role from {old_role} to {new_role}',
                severity='warning',
                payload_diff={'before': {'role': old_role},
                              'after': {'role': new_role}},
            )
        except Exception:
            pass

        return Response({
            'id': user.pk, 'role': user.role,
            'name': f'{user.first_name} {user.last_name}'.strip() or user.email,
        })


# ─────────────────────────────────────────────────────────────────────────
#  Custom roles CRUD
# ─────────────────────────────────────────────────────────────────────────
class OhsRoleDefinitionSerializer(serializers.Serializer):
    key = serializers.SlugField(max_length=20, required=False)
    label = serializers.CharField(max_length=100)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    icon = serializers.CharField(required=False, allow_blank=True,
                                 default='mdi-badge-account-horizontal-outline')
    capabilities = serializers.ListField(
        child=serializers.CharField(), required=False, default=list,
    )
    is_active = serializers.BooleanField(required=False, default=True)

    def validate_key(self, value):
        value = value.lower().strip()
        if value in RESERVED_ROLE_KEYS:
            raise serializers.ValidationError(
                'That key belongs to a built-in role — pick another one.')
        return value

    def validate_capabilities(self, value):
        unknown = set(value) - ALL_CAP_KEYS
        if unknown:
            raise serializers.ValidationError(
                f'Unknown capabilities: {", ".join(sorted(unknown))}.')
        return sorted(set(value))

    def to_representation(self, instance):
        return {
            'id': instance.id,
            'key': instance.key,
            'label': instance.label,
            'description': instance.description,
            'icon': instance.icon,
            'capabilities': sorted(instance.capabilities or []),
            'capability_count': len(instance.capabilities or []),
            'is_system': instance.is_system,
            'is_active': instance.is_active,
            'created_at': instance.created_at,
        }


class OhsRoleDefinitionViewSet(viewsets.ViewSet):
    """CRUD for tenant-created custom OHS roles."""

    def list(self, request):
        if not _can_view(request):
            return Response({'detail': 'Permission denied.'}, status=403)
        rows = OhsRoleDefinition.objects.filter(is_system=False).order_by('label')
        return Response(OhsRoleDefinitionSerializer(rows, many=True).data)

    def create(self, request):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        ser = OhsRoleDefinitionSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        data = ser.validated_data

        key = data.get('key') or data['label'].lower()
        key = ''.join(c if c.isalnum() else '_' for c in key)[:20].strip('_')
        if not key:
            return Response({'detail': 'Could not derive a role key from the label.'},
                            status=400)
        if key in RESERVED_ROLE_KEYS:
            return Response(
                {'detail': f'"{key}" is reserved by a built-in role.'}, status=400)
        if OhsRoleDefinition.objects.filter(key=key).exists():
            return Response({'detail': f'A role with key "{key}" already exists.'},
                            status=400)
        if not data.get('capabilities'):
            return Response({'detail': 'Grant at least one capability.'}, status=400)

        rd = OhsRoleDefinition.objects.create(
            key=key,
            label=data['label'],
            description=data.get('description', ''),
            icon=data.get('icon') or 'mdi-badge-account-horizontal-outline',
            capabilities=data['capabilities'],
            is_system=False,
        )
        return Response(OhsRoleDefinitionSerializer(rd).data, status=201)

    def partial_update(self, request, pk=None):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        rd = OhsRoleDefinition.objects.filter(pk=pk, is_system=False).first()
        if rd is None:
            return Response({'detail': 'Custom role not found.'}, status=404)
        ser = OhsRoleDefinitionSerializer(data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        data = ser.validated_data
        for field in ('label', 'description', 'icon', 'is_active'):
            if field in data:
                setattr(rd, field, data[field])
        if 'capabilities' in data:
            if not data['capabilities']:
                return Response({'detail': 'Grant at least one capability.'},
                                status=400)
            rd.capabilities = data['capabilities']
        rd.save()
        return Response(OhsRoleDefinitionSerializer(rd).data)

    def destroy(self, request, pk=None):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        rd = OhsRoleDefinition.objects.filter(pk=pk, is_system=False).first()
        if rd is None:
            return Response({'detail': 'Custom role not found.'}, status=404)
        in_use = _members(request)
        used_by = [m for m in in_use if m['role'] == rd.key]
        if used_by:
            return Response(
                {'detail': f'{len(used_by)} member(s) still hold this role. '
                           f'Reassign them before deleting.'},
                status=400,
            )
        rd.delete()
        return Response(status=204)


# ─────────────────────────────────────────────────────────────────────────
#  Built-in role overrides
# ─────────────────────────────────────────────────────────────────────────
class OhsRBACBuiltinRoleView(APIView):
    """Customise (PATCH) or reset (DELETE) a built-in role's capabilities."""

    def _check(self, request, key):
        if key not in BUILTIN_ROLE_CAPS:
            return Response({'detail': 'Unknown built-in role.'}, status=404)
        if key in ('tenant_admin', 'admin'):
            return Response(
                {'detail': 'The owner role is platform-managed and cannot be '
                           'restricted.'},
                status=400,
            )
        if key not in EDITABLE_BUILTIN_ROLES:
            return Response(
                {'detail': 'This role is platform-managed and cannot be edited.'},
                status=400,
            )
        return None

    def patch(self, request, key):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        bad = self._check(request, key)
        if bad:
            return bad

        caps = request.data.get('capabilities')
        if not isinstance(caps, list) or not caps:
            return Response({'detail': 'A non-empty capability list is required.'},
                            status=400)
        unknown = set(caps) - ALL_CAP_KEYS
        if unknown:
            return Response(
                {'detail': f'Unknown capabilities: {", ".join(sorted(unknown))}.'},
                status=400,
            )
        missing = PROTECTED_BUILTIN_CAPS - set(caps)
        if missing:
            return Response(
                {'detail': f'These capabilities are required and cannot be '
                           f'removed: {", ".join(sorted(missing))}.'},
                status=400,
            )

        with transaction.atomic():
            rd, _ = OhsRoleDefinition.objects.update_or_create(
                key=key,
                defaults={
                    'label': next((m['label'] for m in ROLE_META
                                   if m['key'] == key), key),
                    'description': 'Tenant-customised capability set',
                    'capabilities': sorted(set(caps)),
                    'is_system': True,
                    'is_active': True,
                },
            )

        try:
            from audit.utils import log_event
            log_event(
                request=request, action='config', object_type='ohs/rbac',
                object_id=key, object_repr=f'Role {key}',
                description=f'Customised capabilities for the {key} role '
                            f'({len(caps)} granted)',
                severity='warning',
                payload_diff={'after': {'capabilities': sorted(set(caps))}},
            )
        except Exception:
            pass

        return Response({
            'key': key,
            'capabilities': sorted(rd.capabilities or []),
            'is_override': True,
        })

    def delete(self, request, key):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        bad = self._check(request, key)
        if bad:
            return bad

        OhsRoleDefinition.objects.filter(key=key, is_system=True).delete()

        try:
            from audit.utils import log_event
            log_event(
                request=request, action='config', object_type='ohs/rbac',
                object_id=key, object_repr=f'Role {key}',
                description=f'Reset the {key} role to platform defaults',
                severity='notice',
            )
        except Exception:
            pass

        return Response({
            'key': key,
            'capabilities': sorted(BUILTIN_ROLE_CAPS.get(key, set())),
            'is_override': False,
        })
