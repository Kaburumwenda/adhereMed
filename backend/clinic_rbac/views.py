"""Roles & Access (RBAC) API for clinics.

Endpoints (registered under ``/api/clinic-rbac/``):

    GET    matrix/                       live role × capability matrix
    PATCH  users/<id>/role/              reassign a member's role
    GET    roles/                        list custom roles
    POST   roles/                        create a custom role
    PATCH  roles/<id>/                   edit a custom role
    DELETE roles/<id>/                   delete a custom role
    PATCH  builtin-roles/<key>/          override a built-in role's caps
    DELETE builtin-roles/<key>/          reset a built-in role to defaults

Reading the matrix needs ``rbac.manage`` or ``staff.view`` so a site lead can
open the page in read-only mode; every mutation needs ``rbac.manage``.
"""
from django.db import transaction
from rest_framework import serializers, status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import ClinicRoleDefinition
from .rbac import (
    ALL_CAP_KEYS, ASSIGNABLE_ROLES, BUILTIN_ROLE_CAPS, CRITICAL_CAPS,
    EDITABLE_BUILTIN_ROLES,
    PROTECTED_BUILTIN_CAPS, RESERVED_ROLE_KEYS, ROLE_META, SENSITIVE_CAPS,
    TIERS, capability_groups, capability_matrix, get_role_capabilities,
    has_capability, role_caps, role_risk_summary,
)

DEFAULT_ICON = 'mdi-badge-account-horizontal-outline'


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


def _tenant_users(request):
    """Active users belonging to this clinic."""
    from accounts.models import User

    tenant = getattr(request, 'tenant', None) or getattr(
        request.user, 'tenant', None)
    qs = User.objects.filter(is_active=True)
    if tenant is not None:
        qs = qs.filter(tenant=tenant)
    # Patients are not staff and never appear in the role matrix.
    return qs.exclude(role__in=['patient', 'caregiver', 'super_admin'])


def _members(request):
    out = []
    for user in _tenant_users(request).order_by('first_name', 'last_name', 'email'):
        name = f'{user.first_name} {user.last_name}'.strip() or user.email
        out.append({
            'id': user.id,
            'name': name,
            'email': user.email,
            'role': user.role,
            'is_active': user.is_active,
            'initials': ''.join(
                part[0] for part in name.split()[:2]
            ).upper() or '?',
        })
    return out


def _custom_roles():
    try:
        return list(ClinicRoleDefinition.objects.filter(
            is_system=False, is_active=True).order_by('label'))
    except Exception:  # noqa: BLE001 — pending migration
        return []


def _overridden_keys():
    try:
        return set(ClinicRoleDefinition.objects
                   .filter(is_system=True, is_active=True)
                   .values_list('key', flat=True))
    except Exception:  # noqa: BLE001
        return set()


def _serialize_role(meta, members, overrides):
    caps = sorted(role_caps(meta['key']))
    tier = meta.get('tier', 'custom')
    tier_meta = TIERS.get(tier) or {}
    return {
        **meta,
        'tier_label': tier_meta.get('label', 'Custom'),
        'tier_color': tier_meta.get('color', 'secondary'),
        'tier_desc': tier_meta.get('desc', ''),
        'is_custom': meta.get('is_custom', False),
        'is_override': meta['key'] in overrides,
        'editable': meta.get('editable', False),
        'capabilities': caps,
        'capability_count': len(caps),
        'user_count': len([m for m in members if m['role'] == meta['key']]),
        'users': [m for m in members if m['role'] == meta['key']],
        'risk': role_risk_summary(set(caps)),
    }


def _log(request, description, **kwargs):
    """Audit trail — never let a logging failure break the request."""
    try:
        from audit.utils import log_event
        log_event(
            request=request, action='config', object_type='clinic/rbac',
            object_repr=kwargs.get('object_repr', 'Clinic role'),
            object_id=kwargs.get('object_id'),
            description=description, severity=kwargs.get('severity', 'warning'),
            payload_diff=kwargs.get('payload_diff'),
        )
    except Exception:  # noqa: BLE001
        pass


# ─────────────────────────────────────────────────────────────────────────
#  Matrix
# ─────────────────────────────────────────────────────────────────────────
class ClinicRBACMatrixView(APIView):
    """The live role × capability matrix plus staff grouped by role."""

    def get(self, request):
        if not _can_view(request):
            return Response(
                {'detail': 'You do not have permission to view roles & access.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        members = _members(request)
        overrides = _overridden_keys()

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
                    'key': definition.key,
                    'label': definition.label,
                    'tier': 'custom',
                    'icon': definition.icon or DEFAULT_ICON,
                    'description': definition.description or '',
                    'editable': True,
                    'is_custom': True,
                    'id': definition.id,
                },
                members, overrides,
            )
            for definition in _custom_roles()
        ]

        known_keys = {r['key'] for r in builtin + custom}
        my_caps = sorted(get_role_capabilities(request))

        return Response({
            'roles': builtin + custom,
            'custom_roles': custom,
            'capability_groups': capability_groups(),
            'capabilities': capability_matrix(),
            'assignable_roles': list(ASSIGNABLE_ROLES)
                                + [d.key for d in _custom_roles()],
            'tiers': TIERS,
            'protected_caps': sorted(PROTECTED_BUILTIN_CAPS),
            # Impact weights, so the editor's live risk preview is computed
            # exactly the way the server rates a saved role.
            'critical_caps': sorted(CRITICAL_CAPS),
            'sensitive_caps': sorted(SENSITIVE_CAPS),
            'can_manage': _can_manage(request),
            'my_role': getattr(request.user, 'role', ''),
            'my_capabilities': my_caps,
            'my_capability_count': len(my_caps),
            'total_capabilities': len(ALL_CAP_KEYS),
            'unassigned': [m for m in members if m['role'] not in known_keys],
        })


# ─────────────────────────────────────────────────────────────────────────
#  Assign a member's role
# ─────────────────────────────────────────────────────────────────────────
class ClinicRBACSetUserRoleView(APIView):
    """Change one member's role. Owner roles are out of scope."""

    def patch(self, request, user_id):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=status.HTTP_403_FORBIDDEN)

        new_role = (request.data.get('role') or '').strip()
        allowed = set(ASSIGNABLE_ROLES) | {d.key for d in _custom_roles()}
        if new_role not in allowed:
            return Response(
                {'detail': 'That role cannot be assigned here. Choose one of: '
                           f'{", ".join(sorted(allowed))}.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = _tenant_users(request).filter(pk=user_id).first()
        if user is None:
            return Response({'detail': 'Member not found in this clinic.'},
                            status=status.HTTP_404_NOT_FOUND)
        if user.role in ('tenant_admin', 'super_admin'):
            return Response(
                {'detail': 'The owner role can only be transferred by the platform.'},
                status=status.HTTP_400_BAD_REQUEST)
        if user.pk == request.user.pk:
            return Response({'detail': 'You cannot change your own role.'},
                            status=status.HTTP_400_BAD_REQUEST)

        old_role = user.role
        user.role = new_role
        user.save(update_fields=['role'])

        _log(
            request,
            f'Changed {user.email} role from {old_role} to {new_role}',
            object_id=user.pk,
            object_repr=f'{user.first_name} {user.last_name}'.strip() or user.email,
            payload_diff={'before': {'role': old_role},
                          'after': {'role': new_role}},
        )

        name = f'{user.first_name} {user.last_name}'.strip() or user.email
        return Response({
            'id': user.pk,
            'role': user.role,
            'name': name,
            'initials': ''.join(p[0] for p in name.split()[:2]).upper() or '?',
        })


# ─────────────────────────────────────────────────────────────────────────
#  Custom roles CRUD
# ─────────────────────────────────────────────────────────────────────────
class ClinicRoleDefinitionSerializer(serializers.Serializer):
    key = serializers.SlugField(max_length=20, required=False)
    label = serializers.CharField(max_length=100)
    description = serializers.CharField(
        required=False, allow_blank=True, default='')
    icon = serializers.CharField(
        required=False, allow_blank=True, default=DEFAULT_ICON)
    capabilities = serializers.ListField(
        child=serializers.CharField(), required=False, default=list)
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
            'capability_count': instance.capability_count,
            'is_system': instance.is_system,
            'is_active': instance.is_active,
            'created_at': instance.created_at,
        }


def _slugify_role(value):
    """'Ward Clerk' → 'ward_clerk', trimmed to the 20-char key budget."""
    slug = ''.join(c if c.isalnum() else '_' for c in (value or '').lower())
    return slug.strip('_')[:20].strip('_')


class ClinicRoleDefinitionViewSet(viewsets.ViewSet):
    """CRUD for clinic-created custom roles."""

    def list(self, request):
        if not _can_view(request):
            return Response({'detail': 'Permission denied.'}, status=403)
        rows = ClinicRoleDefinition.objects.filter(
            is_system=False).order_by('label')
        return Response(ClinicRoleDefinitionSerializer(rows, many=True).data)

    def create(self, request):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        serializer = ClinicRoleDefinitionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        key = data.get('key') or _slugify_role(data['label'])
        if not key:
            return Response(
                {'detail': 'Could not derive a role key from that label.'},
                status=400)
        if key in RESERVED_ROLE_KEYS:
            return Response(
                {'detail': f'"{key}" is reserved by a built-in role.'},
                status=400)
        if ClinicRoleDefinition.objects.filter(key=key).exists():
            return Response(
                {'detail': f'A role with the key "{key}" already exists.'},
                status=400)
        if not data.get('capabilities'):
            return Response({'detail': 'Grant at least one capability.'},
                            status=400)

        definition = ClinicRoleDefinition.objects.create(
            key=key,
            label=data['label'],
            description=data.get('description', ''),
            icon=data.get('icon') or DEFAULT_ICON,
            capabilities=data['capabilities'],
            is_system=False,
        )
        _log(request, f'Created custom clinic role "{definition.label}" '
                      f'({len(definition.capabilities)} capabilities)',
             object_id=definition.pk, object_repr=definition.label)
        return Response(
            ClinicRoleDefinitionSerializer(definition).data, status=201)

    def partial_update(self, request, pk=None):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        definition = ClinicRoleDefinition.objects.filter(
            pk=pk, is_system=False).first()
        if definition is None:
            return Response({'detail': 'Custom role not found.'}, status=404)

        serializer = ClinicRoleDefinitionSerializer(
            data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        for field in ('label', 'description', 'icon', 'is_active'):
            if field in data:
                setattr(definition, field, data[field])
        if 'capabilities' in data:
            if not data['capabilities']:
                return Response({'detail': 'Grant at least one capability.'},
                                status=400)
            definition.capabilities = data['capabilities']
        definition.save()

        _log(request, f'Updated custom clinic role "{definition.label}" '
                      f'({definition.capability_count} capabilities)',
             object_id=definition.pk, object_repr=definition.label)
        return Response(ClinicRoleDefinitionSerializer(definition).data)

    def destroy(self, request, pk=None):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        definition = ClinicRoleDefinition.objects.filter(
            pk=pk, is_system=False).first()
        if definition is None:
            return Response({'detail': 'Custom role not found.'}, status=404)

        holders = [m for m in _members(request) if m['role'] == definition.key]
        if holders:
            return Response(
                {'detail': f'{len(holders)} member(s) still hold this role. '
                           'Reassign them before deleting.'},
                status=400)

        label = definition.label
        definition.delete()
        _log(request, f'Deleted custom clinic role "{label}"',
             object_repr=label, severity='notice')
        return Response(status=204)


# ─────────────────────────────────────────────────────────────────────────
#  Built-in role overrides
# ─────────────────────────────────────────────────────────────────────────
class ClinicRBACBuiltinRoleView(APIView):
    """Customise (PATCH) or reset (DELETE) a built-in role's capabilities."""

    def _guard(self, key):
        if key not in BUILTIN_ROLE_CAPS:
            return Response({'detail': 'Unknown built-in role.'}, status=404)
        if key in ('tenant_admin', 'clinic_admin', 'admin'):
            return Response(
                {'detail': 'The owner role is platform-managed and cannot be '
                           'restricted.'},
                status=400)
        if key not in EDITABLE_BUILTIN_ROLES:
            return Response(
                {'detail': 'This role is platform-managed and cannot be edited.'},
                status=400)
        return None

    def patch(self, request, key):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        blocked = self._guard(key)
        if blocked:
            return blocked

        caps = request.data.get('capabilities')
        if not isinstance(caps, list) or not caps:
            return Response(
                {'detail': 'A non-empty capability list is required.'},
                status=400)
        unknown = set(caps) - ALL_CAP_KEYS
        if unknown:
            return Response(
                {'detail': f'Unknown capabilities: {", ".join(sorted(unknown))}.'},
                status=400)
        missing = PROTECTED_BUILTIN_CAPS - set(caps)
        if missing:
            return Response(
                {'detail': 'These capabilities are required and cannot be '
                           f'removed: {", ".join(sorted(missing))}.'},
                status=400)

        with transaction.atomic():
            definition, _ = ClinicRoleDefinition.objects.update_or_create(
                key=key,
                defaults={
                    'label': next((m['label'] for m in ROLE_META
                                   if m['key'] == key), key),
                    'description': 'Customised by this clinic',
                    'capabilities': sorted(set(caps)),
                    'is_system': True,
                    'is_active': True,
                },
            )

        _log(request, f'Customised capabilities for the {key} role '
                      f'({len(caps)} granted)',
             object_id=key, object_repr=definition.label,
             payload_diff={'after': {'capabilities': sorted(set(caps))}})
        return Response({
            'key': key,
            'capabilities': sorted(definition.capabilities or []),
            'is_override': True,
        })

    def delete(self, request, key):
        if not _can_manage(request):
            return Response({'detail': 'Administrator permission required.'},
                            status=403)
        blocked = self._guard(key)
        if blocked:
            return blocked

        ClinicRoleDefinition.objects.filter(key=key, is_system=True).delete()
        _log(request, f'Reset the {key} role to platform defaults',
             object_id=key, severity='notice')
        return Response({
            'key': key,
            'capabilities': sorted(BUILTIN_ROLE_CAPS.get(key, set())),
            'is_override': False,
        })
