"""Stock takes (cycle counts)."""
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
from ..services import stock_take as stock_take_service
from .base import (_assignable_roles_for, _audit, _editable_builtin_roles_for,
                   _forced_branch_id, _is_pharmacy, _parse_date, _require_branch,
                   _role_meta_for, _tenant_type)

logger = logging.getLogger(__name__)


def _pdf_context(request):
    """Letterhead inputs for a printed inventory document.

    Returns ``(org, logo_path, palette, business_name, prepared_by)``. Kept in
    one place so the count sheet and the register cannot print different
    organisation details; the branding layer already resolves the tenant logo
    (falling back to the bundled mark) and the tenant palette.
    """
    from config.pdf_branding import resolve_branding, resolve_palette

    try:
        logo_path, resolved_name = resolve_branding(request)
        palette = resolve_palette(request)
    except Exception:
        logger.exception('could not resolve document branding')
        logo_path, resolved_name, palette = None, '', None

    tenant = getattr(request, 'tenant', None)
    org = {
        'name': getattr(tenant, 'name', '') or resolved_name or '',
        'address': getattr(tenant, 'address', '') or '',
        'city': getattr(tenant, 'city', '') or '',
        'country': getattr(tenant, 'country', '') or '',
        'phone': getattr(tenant, 'phone', '') or '',
        'email': getattr(tenant, 'email', '') or '',
        'website': getattr(tenant, 'website', '') or '',
    }
    business_name = org['name'] or resolved_name or ''

    user = getattr(request, 'user', None)
    prepared_by = ''
    if user is not None and getattr(user, 'is_authenticated', False):
        prepared_by = (getattr(user, 'full_name', '')
                       or getattr(user, 'email', '') or '')

    return org, logo_path, palette, business_name, prepared_by


def _pdf_response(body, filename):
    response = HttpResponse(body, content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="{filename}"'
    return response


def _document_stamp():
    return timezone.localtime(timezone.now()).strftime('%Y%m%d-%H%M')


class InventoryCountViewSet(viewsets.ModelViewSet):
    queryset = InventoryCount.objects.select_related('branch', 'category', 'created_by', 'completed_by').prefetch_related('lines__stock__unit').all()
    serializer_class = InventoryCountSerializer
    permission_classes = [StockTakePermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'branch', 'category']
    search_fields = ['reference', 'name', 'notes']
    ordering_fields = ['created_at', 'completed_at']

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user if self.request.user.is_authenticated else None)

    @action(detail=True, methods=['get'], url_path='pdf')
    def pdf(self, request, pk=None):
        """The count sheet as a printable, letterheaded A4 form.

        Printed sheets are the artefact a warehouse actually walks the aisle
        with, so the document carries the tenant's logo, name, address and
        contacts on page 1 and leaves a blank box for every line that has not
        been counted yet.
        """
        count = self.get_object()
        show_cost = can_view_cost(request)
        lines = list(count.lines.all())

        sheet = stock_take_service._sheet(count, lines, show_cost=show_cost)

        line_rows = []
        for line in lines:
            cost = float(line.stock.cost_price or 0) if (show_cost and line.stock) else 0.0
            delta = (None if line.counted_quantity is None
                     else int(line.counted_quantity) - int(line.expected_quantity))
            line_rows.append({
                'name': line.stock.medication_name if line.stock else '-',
                'unit': (line.stock.unit.abbreviation
                         if line.stock and line.stock.unit else ''),
                'category': (line.stock.category.name
                             if line.stock and line.stock.category else ''),
                'expected': line.expected_quantity,
                'counted': line.counted_quantity,
                'variance': delta,
                'value': (cost * delta) if delta is not None else None,
                'note': line.notes or '',
            })

        org, logo_path, palette, business_name, prepared_by = _pdf_context(request)

        from ..reports.stock_take_render import render_count_sheet_pdf
        try:
            body = render_count_sheet_pdf(
                sheet=sheet, lines=line_rows, org=org, logo_path=logo_path,
                palette=palette, business_name=business_name,
                prepared_by=prepared_by, show_cost=show_cost,
            )
        except Exception:
            logger.exception('count sheet PDF render failed')
            return Response({'detail': 'Could not build this document.'},
                            status=500)

        _audit(request, 'stock_sheet_pdf', count,
               description=f'Downloaded the count sheet PDF for '
                           f'{count.reference} ({len(lines)} line(s))')
        return _pdf_response(body, f'{count.reference}-{_document_stamp()}.pdf')

    @action(detail=True, methods=['post'], url_path='generate-sheet')
    def generate_sheet(self, request, pk=None):
        """Populate count lines with current expected qty from active stocks."""
        count = self.get_object()
        if count.status not in (InventoryCount.Status.DRAFT, InventoryCount.Status.IN_PROGRESS):
            return Response({'detail': 'Sheet can only be generated while draft / in progress.'}, status=400)

        qs = MedicationStock.objects.filter(is_active=True).prefetch_related('batches')
        if count.category_id:
            qs = qs.filter(category_id=count.category_id)
        if count.branch_id:
            # A count sheet scoped to a warehouse must only list that
            # warehouse's items (plus shared/unassigned stock).
            qs = qs.filter(Q(branch_id=count.branch_id) | Q(branch__isnull=True))

        # Wipe old lines and rebuild
        count.lines.all().delete()
        lines = []
        for s in qs:
            lines.append(InventoryCountLine(
                count=count, stock=s,
                expected_quantity=s.total_quantity,
            ))
        InventoryCountLine.objects.bulk_create(lines)
        count.status = InventoryCount.Status.IN_PROGRESS
        count.save(update_fields=['status'])
        return Response(self.get_serializer(count).data)

    @action(detail=True, methods=['post'], url_path='save-counts')
    def save_counts(self, request, pk=None):
        """Bulk-update counted quantities. Payload: {lines: [{id, counted_quantity, notes}]}"""
        count = self.get_object()
        if count.status == InventoryCount.Status.COMPLETED:
            return Response({'detail': 'Count is completed and cannot be edited.'}, status=400)
        lines = request.data.get('lines') or []
        by_id = {l.id: l for l in count.lines.all()}
        errors = []
        for payload in lines:
            line = by_id.get(payload.get('id'))
            if not line:
                continue
            cq = payload.get('counted_quantity')
            if cq is None or cq == '':
                line.counted_quantity = None
            else:
                try:
                    value = int(cq)
                except (TypeError, ValueError):
                    value = None
                if value is None or value < 0:
                    errors.append(f'{line.stock.medication_name}: counted quantity '
                                  f'must be a whole number of 0 or more.')
                    continue
                line.counted_quantity = value
            line.notes = payload.get('notes', line.notes) or ''
            line.save(update_fields=['counted_quantity', 'notes'])
        if errors:
            return Response({'detail': ' '.join(errors)}, status=400)
        return Response(self.get_serializer(count).data)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        """Finalise the count: create StockAdjustments for any variance."""
        from django.db import transaction as db_transaction

        count = self.get_object()
        if count.status == InventoryCount.Status.COMPLETED:
            return Response({'detail': 'Already completed.'}, status=400)

        # A half-finished sheet used to complete silently: un-counted lines were
        # skipped by the adjustment loop, yet ``advance_from_count`` still
        # pushed *every* line's cadence forward. Twenty-eight items could skip a
        # whole cycle because one of them had been counted. Require an explicit
        # override, and state exactly how much is outstanding.
        total_lines = count.lines.count()
        outstanding = count.lines.filter(counted_quantity__isnull=True).count()
        allow_partial = bool(request.data.get('allow_partial'))
        if outstanding and not allow_partial:
            return Response({
                'detail': (f'{outstanding} of {total_lines} line(s) have no '
                           f'counted quantity. Count them, or pass '
                           f'allow_partial to reconcile only what was counted.'),
                'outstanding': outstanding,
                'total_lines': total_lines,
                'counted_lines': total_lines - outstanding,
            }, status=400)
        if not total_lines:
            return Response({'detail': 'This sheet has no lines to count.'},
                            status=400)

        adjustments_created = 0
        with db_transaction.atomic():
            for line in (count.lines.exclude(counted_quantity__isnull=True)
                         .select_related('stock')):
                # Variance must be measured against what is on the shelf *now*,
                # not against the quantity captured when the sheet was
                # generated: a sale, transfer or adjustment in between would
                # otherwise be silently undone by the count. The stock row is
                # locked so two completions cannot interleave.
                stock = (MedicationStock.objects.select_for_update()
                         .filter(pk=line.stock_id).first())
                if stock is None:
                    continue
                current = (StockBatch.objects
                           .filter(stock_id=stock.pk, quantity_remaining__gt=0)
                           .aggregate(total=Sum('quantity_remaining'))['total'] or 0)
                delta = int(line.counted_quantity) - int(current)
                if delta == 0:
                    continue
                try:
                    apply_quantity_change(
                        stock, delta,
                        reason=StockAdjustment.Reason.COUNT_CORRECTION,
                        notes=f'Stock take {count.reference} '
                              f'(expected {line.expected_quantity}, counted {line.counted_quantity})',
                        user=request.user,
                    )
                except InsufficientStock as exc:
                    # Raise rather than return: a plain return would COMMIT
                    # the variances already posted for earlier lines.
                    raise serializers.ValidationError({
                        'detail': str(exc),
                        'stock_id': line.stock_id,
                        'expected': line.expected_quantity,
                        'counted': line.counted_quantity,
                    })
                adjustments_created += 1

            count.status = InventoryCount.Status.COMPLETED
            count.completed_at = timezone.now()
            count.completed_by = request.user if request.user.is_authenticated else None
            count.save(update_fields=['status', 'completed_at', 'completed_by'])

            # The ABC plan advances on completion, not on sheet creation.
            try:
                from ..services import cycle_count as cycle_service
                cycle_service.advance_from_count(count)
            except Exception:
                logger.exception('could not advance the cycle-count schedule')

        # Lines changed underneath us; drop the cached relation.
        if hasattr(count, '_prefetched_objects_cache'):
            count._prefetched_objects_cache.pop('lines', None)
        return Response({**self.get_serializer(count).data,
                         'adjustments_created': adjustments_created})


class StockTakeBoardView(APIView):
    """Aggregated posture for the premium stock-take screen.

    The sheet list endpoint carries every line of every count, which makes it
    a poor fit for a dashboard: this view rolls the same data up server-side
    so the page needs one request for the queue, the variance history and the
    accuracy trend.
    """
    permission_classes = [StockTakePermission]

    def get(self, request):
        branch = request.query_params.get('branch') or None
        try:
            limit = int(request.query_params.get('limit', 60) or 60)
        except (TypeError, ValueError):
            limit = 60
        try:
            window_days = int(request.query_params.get('window', 365) or 365)
        except (TypeError, ValueError):
            window_days = 365
        return Response(stock_take_service.board(
            branch_id=branch,
            limit=limit,
            window_days=window_days,
            show_cost=can_view_cost(request),
        ))


class StockTakeRegisterPdfView(APIView):
    """The stock-take board as a filed premium PDF document."""
    permission_classes = [StockTakePermission]

    def get(self, request):
        branch = request.query_params.get('branch') or None
        try:
            limit = int(request.query_params.get('limit', 60) or 60)
        except (TypeError, ValueError):
            limit = 60
        try:
            window_days = int(request.query_params.get('window', 365) or 365)
        except (TypeError, ValueError):
            window_days = 365

        show_cost = can_view_cost(request)
        payload = stock_take_service.board(
            branch_id=branch, limit=limit, window_days=window_days,
            show_cost=show_cost)

        branch_label = 'All warehouses'
        if branch:
            branch_label = (Branch.objects.filter(pk=branch)
                            .values_list('name', flat=True).first()
                            or 'Selected warehouse')

        org, logo_path, palette, business_name, prepared_by = _pdf_context(request)

        from ..reports.stock_take_render import render_stock_take_register_pdf
        try:
            body = render_stock_take_register_pdf(
                payload=payload, org=org, logo_path=logo_path,
                palette=palette, business_name=business_name,
                prepared_by=prepared_by, show_cost=show_cost,
                branch_label=branch_label,
                window_days=payload.get('window_days') or window_days,
            )
        except Exception:
            logger.exception('stock take register PDF render failed')
            return Response({'detail': 'Could not build this document.'},
                            status=500)

        summary = payload.get('summary') or {}
        _audit(request, 'stock_take_pdf', 'counts',
               description=f'Downloaded the stock-take register PDF '
                           f'({summary.get("open_sheets", 0)} open sheet(s), '
                           f'{branch_label})')
        return _pdf_response(
            body, f'stock-take-register-{_document_stamp()}.pdf')
