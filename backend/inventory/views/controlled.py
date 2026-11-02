"""Controlled-substance register."""
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


class ControlledSubstanceLogViewSet(viewsets.ModelViewSet):
    queryset = ControlledSubstanceLog.objects.select_related('recorded_by').all()
    serializer_class = ControlledSubstanceLogSerializer
    permission_classes = [ControlledRegisterPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['action', 'medication_name', 'schedule']
    search_fields = ['medication_name', 'patient_name', 'patient_id_number',
                     'prescriber_name', 'prescription_reference', 'batch_number']
    ordering_fields = ['created_at', 'medication_name']

    def get_queryset(self):
        qs = super().get_queryset()
        df = self.request.query_params.get('date_from')
        dt = self.request.query_params.get('date_to')
        if df:
            qs = qs.filter(created_at__date__gte=df)
        if dt:
            qs = qs.filter(created_at__date__lte=dt)
        return qs

    def perform_create(self, serializer):
        serializer.save(recorded_by=self.request.user if self.request.user.is_authenticated else None)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        from django.db.models import Sum
        qs = self.get_queryset()
        by_action = {}
        for row in qs.values('action').annotate(c=Sum('quantity')):
            by_action[row['action']] = float(row['c'] or 0)
        by_med = list(
            qs.values('medication_name')
              .annotate(total=Sum('quantity'))
              .order_by('-total')[:10]
        )
        return Response({
            'total_records': qs.count(),
            'by_action': by_action,
            'top_medications': by_med,
        })
