"""Shared imports and helpers for the inventory API package.

Every domain module imports its names from here so the split is a pure
file move with no behavioural change.
"""
from rest_framework import viewsets, filters, status, serializers
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, SAFE_METHODS
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Sum, Count, Max, F, DecimalField, IntegerField, Q
from django.db.models import ExpressionWrapper, Prefetch
from django.db.models.functions import Coalesce
from django.utils import timezone
from django.http import HttpResponse
from datetime import timedelta
import csv
import io
import logging
import os

logger = logging.getLogger(__name__)

from ..models import (
    Category, Unit, Classification, MedicationStock, StockBatch, StockAdjustment,
    InventoryCount, InventoryCountLine,
    StockTransfer, StockTransferLine,
    ControlledSubstanceLog,
)
from ..serializers import (
    CategorySerializer, UnitSerializer, ClassificationSerializer,
    MedicationStockSerializer, MedicationStockListSerializer,
    StockBatchSerializer, StockAdjustmentSerializer,
    InventoryCountSerializer, InventoryCountLineSerializer,
    StockTransferSerializer,
    ControlledSubstanceLogSerializer,
)
from config.branch_scope import (
    BranchScopedMixin, get_user_branch, is_branch_scoped_user,
)
from pharmacy_profile.models import Branch
from ..models import RoleDefinition
from ..services.stock import (
    InsufficientStock, apply_quantity_change, reconcile_quantity,
)
from ..rbac import (
    InventoryPermission, AdjustmentPermission, StockTakePermission,
    TransferPermission, ControlledRegisterPermission, TenantAdminOnly,
    has_capability, can_view_cost,
    ROLE_META, ALL_CAP_KEYS, CAPABILITY_LABELS,
    ASSIGNABLE_ROLES, RESERVED_ROLE_KEYS, capability_matrix,
    BUILTIN_ROLE_CAPS, EDITABLE_BUILTIN_ROLES, PROTECTED_BUILTIN_CAPS,
    PHARMACY_ROLE_META, PHARMACY_ASSIGNABLE_ROLES, PHARMACY_EDITABLE_BUILTIN_ROLES,
    _role_caps,
)


def _tenant_type(request):
    """Return the current tenant type ('pharmacy', 'inventory', ...) or None."""
    tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
    return getattr(tenant, 'type', None)


def _is_pharmacy(request):
    return _tenant_type(request) == 'pharmacy'


# ── Branch-scope enforcement ─────────────────────────────────────────────
def _forced_branch_id(user):
    """Return the branch id a non-admin user is locked to, else ``None``.

    Mirrors :class:`config.branch_scope.BranchScopedMixin` so that *write*
    paths (imports, adjustments, transfers) can enforce the same scope the
    read paths already apply. Only bypass roles and superusers are free to
    target any warehouse; a user with no assigned branch is unrestricted for
    backwards compatibility.
    """
    from config.branch_scope import get_scoped_branch_id
    return get_scoped_branch_id(user)


def _require_branch(request, branch_id):
    """Return an error string when ``branch_id`` is out of the user's scope."""
    forced = _forced_branch_id(getattr(request, 'user', None))
    if forced and branch_id and int(branch_id) != int(forced):
        return ('You can only work within your assigned warehouse. '
                'Ask an administrator to move stock between warehouses.')
    return None


def _parse_date(value):
    """Parse ``YYYY-MM-DD`` into a :class:`datetime.date` (raises on bad input)."""
    from datetime import date as _date, datetime as _datetime
    if isinstance(value, _datetime):
        return value.date()
    if isinstance(value, _date):
        return value
    return _datetime.strptime(str(value).strip()[:10], '%Y-%m-%d').date()


def _audit(request, action, obj, *, description='', severity=None, **extra):
    """Record a domain-level audit event. Never raises.

    The generic :class:`audit.middleware.AuditMiddleware` already logs one
    row per mutating request, but it cannot describe *why* stock moved.
    These semantic events (quantity before/after, batch, reference) are what
    a warehouse audit trail actually needs.
    """
    try:
        from audit.utils import log_event
        log_event(
            request=request,
            action=action,
            object_type='inventory',
            object_id=getattr(obj, 'pk', obj),
            object_repr=str(obj)[:255],
            description=description[:255],
            severity=severity,
            **extra,
        )
    except Exception:  # pragma: no cover - auditing must never break a write
        logger.exception('inventory audit event failed (%s)', action)


def _role_meta_for(request):
    """Built-in role list for the current tenant type."""
    return PHARMACY_ROLE_META if _is_pharmacy(request) else ROLE_META


def _assignable_roles_for(request):
    """Operational roles assignable from the Roles & Access page."""
    if _is_pharmacy(request):
        return PHARMACY_ASSIGNABLE_ROLES
    return ASSIGNABLE_ROLES


def _editable_builtin_roles_for(request):
    """Built-in roles whose capabilities the tenant may customize."""
    if _is_pharmacy(request):
        return PHARMACY_EDITABLE_BUILTIN_ROLES
    return EDITABLE_BUILTIN_ROLES
