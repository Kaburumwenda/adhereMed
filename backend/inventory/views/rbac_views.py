"""Roles & Access administration endpoints."""
from __future__ import annotations

import csv
import io
import logging
import os
from datetime import timedelta

from django.db.models import (Sum, Count, Max, F, DecimalField, IntegerField, Q,
                              ExpressionWrapper, Prefetch)
from django.db.models.functions import Coalesce
from django.http import HttpResponse
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import serializers, status, viewsets, filters
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated, SAFE_METHODS
from rest_framework.response import Response
from rest_framework.views import APIView

from config.branch_scope import (BranchScopedMixin, get_user_branch,
                                 is_branch_scoped_user)
from pharmacy_profile.models import Branch

from ..models import (Category, Unit, Classification, MedicationStock, StockBatch,
                      StockAdjustment, InventoryCount, InventoryCountLine,
                      StockTransfer, StockTransferLine, ControlledSubstanceLog,
                      RoleDefinition)
from ..rbac import (InventoryPermission, AdjustmentPermission, StockTakePermission,
                    TransferPermission, ControlledRegisterPermission,
                    TenantAdminOnly, has_capability, can_view_cost,
                    ROLE_META, ALL_CAP_KEYS, CAPABILITY_LABELS, ASSIGNABLE_ROLES,
                    RESERVED_ROLE_KEYS, capability_matrix, BUILTIN_ROLE_CAPS,
                    EDITABLE_BUILTIN_ROLES, PROTECTED_BUILTIN_CAPS,
                    PHARMACY_ROLE_META, PHARMACY_ASSIGNABLE_ROLES,
                    PHARMACY_EDITABLE_BUILTIN_ROLES, _role_caps)
from ..serializers import (CategorySerializer, UnitSerializer,
                           ClassificationSerializer, MedicationStockSerializer,
                           MedicationStockListSerializer, StockBatchSerializer,
                           StockAdjustmentSerializer, InventoryCountSerializer,
                           InventoryCountLineSerializer, StockTransferSerializer,
                           ControlledSubstanceLogSerializer)
from ..services.stock import (InsufficientStock, apply_quantity_change,
                              reconcile_quantity)
from .base import (_assignable_roles_for, _audit, _editable_builtin_roles_for,
                   _forced_branch_id, _is_pharmacy, _parse_date, _require_branch,
                   _role_meta_for, _tenant_type)

logger = logging.getLogger(__name__)


class RBACMatrixView(APIView):
    """Serves the live role/capability matrix plus the staff grouped by role
    for the Roles & Access administration page. Includes tenant-created
    custom roles."""

    permission_classes = [TenantAdminOnly]

    def get(self, request):
        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)

        users = []
        if tenant is not None:
            from accounts.models import User
            qs = (User.objects
                  .filter(tenant=tenant, is_active=True)
                  .exclude(role__in=['patient', 'caregiver', 'super_admin']))
            for u in qs:
                branch_name = None
                try:
                    sp = u.staff_profile
                    branch_name = sp.branch.name if sp.branch else None
                except Exception:
                    pass
                users.append({
                    'id': u.id,
                    'name': f'{u.first_name} {u.last_name}'.strip() or u.email,
                    'email': u.email,
                    'role': u.role,
                    'branch_name': branch_name,
                })

        # Built-in roles (with any tenant capability overrides applied).
        # RoleDefinition lookups are guarded so a schema whose tenant
        # migrations are still pending renders the built-in matrix instead
        # of a 500.
        try:
            override_keys = set(RoleDefinition.objects
                                .filter(is_system=True, is_active=True)
                                .values_list('key', flat=True))
        except Exception:
            override_keys = set()
        role_meta = _role_meta_for(request)
        editable_roles = _editable_builtin_roles_for(request)
        roles = []
        for meta in role_meta:
            role_users = [u for u in users if u['role'] == meta['key']]
            is_override = meta['key'] in override_keys
            roles.append({**meta, 'user_count': len(role_users),
                          'users': role_users, 'is_custom': False,
                          'is_override': is_override,
                          'capabilities': sorted(_role_caps(meta['key'])),
                          'editable': meta['key'] in editable_roles})

        # Tenant-created custom roles
        custom_roles = []
        try:
            rd_qs = RoleDefinition.objects.filter(is_active=True, is_system=False)
        except Exception:
            rd_qs = RoleDefinition.objects.none()
        for rd in rd_qs:
            role_users = [u for u in users if u['role'] == rd.key]
            custom_roles.append({
                'key': rd.key, 'label': rd.label, 'tier': 'custom',
                'icon': rd.icon or 'mdi-badge-account-horizontal-outline',
                'description': rd.description or '',
                'user_count': len(role_users), 'users': role_users,
                'is_custom': True, 'is_override': False, 'editable': True,
                'capabilities': sorted(rd.capabilities or []),
                'id': rd.id,
            })

        # Assignable roles = built-in operational roles + custom role keys
        assignable = list(_assignable_roles_for(request)) + [r['key'] for r in custom_roles]

        return Response({
            'roles': roles + custom_roles,
            'custom_roles': custom_roles,
            'capabilities': capability_matrix(),
            'assignable_roles': assignable,
            'can_change': True,
        })


class RBACSetUserRoleView(APIView):
    """Change a member's role from the Roles & Access page.

    Tenant-admin ownership cannot be granted/revoked here — only the four
    operational inventory roles and tenant-created custom roles are
    assignable.
    """
    permission_classes = [TenantAdminOnly]

    def patch(self, request, user_id=None):
        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
        if tenant is None:
            return Response({'detail': 'No organization context.'},
                            status=status.HTTP_400_BAD_REQUEST)

        new_role = (request.data.get('role') or '').strip()
        custom_keys = set(RoleDefinition.objects
                          .filter(is_active=True)
                          .values_list('key', flat=True))
        assignable = _assignable_roles_for(request)
        if new_role not in assignable and new_role not in custom_keys:
            return Response(
                {'detail': 'Unknown or non-assignable role. Assignable roles are '
                           'the operational roles and your custom roles.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # A deactivated/renamed custom role can no longer be re-assigned.
        if new_role in custom_keys and new_role not in assignable and \
                not RoleDefinition.objects.filter(key=new_role, is_active=True).exists():
            return Response({'detail': 'This custom role is no longer active.'},
                            status=status.HTTP_400_BAD_REQUEST)

        from accounts.models import User
        user = User.objects.filter(id=user_id, tenant=tenant).first()
        if not user:
            return Response({'detail': 'Member not found in this organization.'},
                            status=status.HTTP_404_NOT_FOUND)
        if user.role == 'tenant_admin':
            return Response(
                {'detail': 'The tenant owner role can only be changed by the '
                           'platform superadmin.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.id == request.user.id:
            return Response(
                {'detail': 'You cannot change your own role from here.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.role == new_role:
            return Response({'detail': f'{user} already has this role.',
                             'user': {'id': user.id, 'name': str(user),
                                      'email': user.email, 'role': user.role}},
                            status=status.HTTP_200_OK)

        old_role = user.role
        user.role = new_role
        user.save(update_fields=['role'])

        # Audit trail
        try:
            from audit.utils import log_event
            log_event(request, action='role_change', object_type='user',
                      object_id=user.id,
                      details={'from': old_role, 'to': new_role,
                               'member': user.email})
        except Exception:
            pass

        return Response({
            'detail': f'{user} role updated to {new_role.replace("_", " ")}.',
            'user': {'id': user.id, 'name': str(user), 'email': user.email,
                     'role': new_role},
        })


# ── Custom role CRUD (add / edit / remove roles) ──────────────────────────
def _slugify_role(label):
    import re
    key = re.sub(r'[^a-z0-9]+', '_', (label or '').strip().lower()).strip('_')
    return key[:20]


class RoleDefinitionSerializer(serializers.Serializer):
    """Read/write serializer for tenant-created roles."""
    id = serializers.IntegerField(read_only=True)
    key = serializers.SlugField(read_only=True)
    label = serializers.CharField(max_length=100)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    icon = serializers.CharField(required=False, allow_blank=True,
                                 default='mdi-badge-account-horizontal-outline')
    capabilities = serializers.ListField(
        child=serializers.CharField(), required=False, default=list)
    is_active = serializers.BooleanField(required=False, default=True)

    def validate_label(self, value):
        label = value.strip()
        if not label:
            raise serializers.ValidationError('Label is required.')
        key = _slugify_role(label)
        if key in RESERVED_ROLE_KEYS:
            raise serializers.ValidationError(
                f'"{label}" collides with a reserved built-in role.')
        if not key:
            raise serializers.ValidationError('Label must contain letters or digits.')
        return label

    def validate_capabilities(self, value):
        unknown = [c for c in (value or []) if c not in ALL_CAP_KEYS]
        if unknown:
            raise serializers.ValidationError(
                f'Unknown capabilities: {", ".join(unknown)}.')
        caps = list(dict.fromkeys(value or []))  # dedupe, keep order
        return caps

    def create(self, validated_data):
        label = validated_data['label']
        key = _slugify_role(label)
        # Ensure key uniqueness for this tenant schema
        base, suffix = key, 2
        while RoleDefinition.objects.filter(key=key).exists():
            suffix_str = str(suffix)
            key = base[:20 - len(suffix_str)] + suffix_str
            suffix += 1
        rd = RoleDefinition.objects.create(
            key=key, label=label,
            description=validated_data.get('description', ''),
            icon=validated_data.get('icon') or 'mdi-badge-account-horizontal-outline',
            capabilities=validated_data.get('capabilities', []),
            is_active=validated_data.get('is_active', True),
        )
        return rd

    def update(self, instance, validated_data):
        for f in ('label', 'description', 'icon', 'capabilities', 'is_active'):
            if f in validated_data:
                setattr(instance, f, validated_data[f])
        instance.save()
        return instance


class RoleDefinitionViewSet(viewsets.ModelViewSet):
    """CRUD for tenant-created custom roles (Roles & Access page).

    * create  — add a role with a chosen capability list
    * update  — rename / re-icon / toggle capabilities
    * delete  — remove the role (blocked while members still hold it)
    """
    queryset = RoleDefinition.objects.all()
    serializer_class = RoleDefinitionSerializer
    permission_classes = [TenantAdminOnly]
    filter_backends = [filters.OrderingFilter]
    ordering = ['label']
    http_method_names = ['get', 'post', 'patch', 'delete', 'head', 'options']

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        rd = serializer.save()
        return Response(self.get_serializer(rd).data,
                        status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', True)
        instance = self.get_object()
        if instance.is_system:
            return Response(
                {'detail': 'Built-in role overrides are managed through their '
                           'own action (edit via the role editor).'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        rd = serializer.save()
        return Response(self.get_serializer(rd).data)

    def destroy(self, request, *args, **kwargs):
        """Remove a custom role — blocked while any member still holds it."""
        role = self.get_object()
        if role.is_system:
            return Response(
                {'detail': 'Built-in roles cannot be removed. Use the reset '
                           'action to restore platform defaults.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
        if tenant is not None:
            from accounts.models import User
            members = list(User.objects
                           .filter(tenant=tenant, role=role.key, is_active=True)
                           .values_list('email', flat=True))
            if members:
                return Response(
                    {'detail': f'Cannot remove "{role.label}" while members still '
                               f'hold it: {", ".join(members[:5])}. Reassign them first.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        role.delete()
        return Response({'detail': f'Role "{role.label}" removed.'},
                        status=status.HTTP_200_OK)


class RBACBuiltinRoleOverrideView(APIView):
    """Customize (or reset) the capabilities of a built-in role.

    PATCH   {capabilities: [...]}  — stores a tenant override (is_system row)
    DELETE                            — removes the override, restoring the
                                        platform defaults
    The tenant owner role is platform-managed and cannot be overridden.
    """
    permission_classes = [TenantAdminOnly]

    def _validate_caps(self, caps):
        if not isinstance(caps, list) or not caps:
            return 'A non-empty capability list is required.'
        unknown = [c for c in caps if c not in ALL_CAP_KEYS]
        if unknown:
            return f'Unknown capabilities: {", ".join(unknown)}.'
        missing = PROTECTED_BUILTIN_CAPS - set(caps)
        if missing:
            return (f'Cannot remove required capabilities: {", ".join(sorted(missing))}. '
                    f'Every role must keep basic stock visibility.')
        return None

    def patch(self, request, key):
        editable_roles = _editable_builtin_roles_for(request)
        if key not in editable_roles:
            return Response(
                {'detail': 'This role is managed by the platform and cannot '
                           'be customized.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        err = self._validate_caps(request.data.get('capabilities'))
        if err:
            return Response({'detail': err}, status=status.HTTP_400_BAD_REQUEST)

        meta = next((m for m in _role_meta_for(request) if m['key'] == key), None)
        caps = list(dict.fromkeys(request.data['capabilities']))
        rd, _ = RoleDefinition.objects.update_or_create(
            key=key,
            defaults={
                'label': meta['label'] if meta else key.title(),
                'icon': meta['icon'] if meta else 'mdi-badge-account-horizontal-outline',
                'description': (meta['description'] if meta else '') + ' (customized)',
                'capabilities': caps,
                'is_system': True,
                'is_active': True,
            },
        )
        try:
            from audit.utils import log_event
            log_event(request, action='role_cap_ovrd', object_type='role',
                      object_id=rd.id,
                      details={'role': key, 'capabilities': caps})
        except Exception:
            pass
        return Response({
            'detail': f'"{rd.label}" capabilities updated — effective immediately.',
            'key': key, 'capabilities': sorted(caps), 'is_override': True,
        })

    def delete(self, request, key):
        editable_roles = _editable_builtin_roles_for(request)
        if key not in editable_roles:
            return Response(
                {'detail': 'This role is managed by the platform.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        deleted, _ = RoleDefinition.objects.filter(key=key, is_system=True).delete()
        if deleted:
            try:
                from audit.utils import log_event
                log_event(request, action='role_cap_reset', object_type='role',
                          object_id=None, details={'role': key})
            except Exception:
                pass
            return Response({
                'detail': 'Platform defaults restored.',
                'key': key,
                'capabilities': sorted(BUILTIN_ROLE_CAPS.get(key, [])),
                'is_override': False,
            })
        return Response({'detail': 'No override existed — already on defaults.',
                         'key': key,
                         'capabilities': sorted(BUILTIN_ROLE_CAPS.get(key, [])),
                         'is_override': False},
                        status=status.HTTP_200_OK)
