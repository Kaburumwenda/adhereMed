"""Warehouse-to-warehouse transfers: lifecycle, analytics and printable documents."""
from __future__ import annotations

import csv
import io
import logging
import os
from datetime import timedelta

from django.db.models import (Sum, Count, Max, F, DecimalField, IntegerField, Q,
                              ExpressionWrapper, Prefetch)
from django.db import transaction
from django.db.models.functions import Coalesce
from django.db.utils import IntegrityError
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


from django_filters import DateFilter, FilterSet, CharFilter


class StockTransferFilterSet(FilterSet):
    """Adds from_date / to_date (inclusive, by requested_at) on top of the
    standard status / source / destination filters."""
    from_date = DateFilter(field_name='requested_at__date', lookup_expr='gte')
    to_date = DateFilter(field_name='requested_at__date', lookup_expr='lte')
    branch = CharFilter(method='filter_branch', help_text='Filter by either source or dest branch')

    class Meta:
        model = StockTransfer
        fields = ['status', 'source_branch', 'dest_branch', 'from_date', 'to_date']

    def filter_branch(self, queryset, name, value):
        from django.db.models import Q
        if not value:
            return queryset
        return queryset.filter(Q(source_branch_id=value) | Q(dest_branch_id=value))


class StockTransferViewSet(viewsets.ModelViewSet):
    queryset = StockTransfer.objects.select_related(
        'source_branch', 'dest_branch', 'requested_by', 'approved_by', 'received_by'
    ).prefetch_related('lines__stock__unit', 'lines__batch').all()
    serializer_class = StockTransferSerializer
    permission_classes = [TransferPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = StockTransferFilterSet
    search_fields = ['reference', 'notes']
    ordering_fields = ['requested_at', 'shipped_at', 'received_at']

    def get_queryset(self):
        """Branch-scoped visibility.

        Non-admin users (storekeepers, branch_admins, etc.) see only:
          * transfers their branch initiated (source = my branch, any status)
          * transfers addressed to their branch that are in transit or
            completed (i.e. actually moving stock toward them)
        Admins / super-admins see every transfer (the existing behaviour).
        """
        qs = super().get_queryset()
        user = self.request.user
        if not user or not getattr(user, 'is_authenticated', False):
            return qs
        # Single source of truth for the bypass rule.
        if _forced_branch_id(user) is None:
            return qs
        branch_id = _forced_branch_id(user)
        return qs.filter(
            Q(source_branch_id=branch_id)
            | Q(
                dest_branch_id=branch_id,
                status__in=[
                    StockTransfer.Status.IN_TRANSIT,
                    StockTransfer.Status.COMPLETED,
                ],
            )
        )

    def perform_create(self, serializer):
        """A scoped user may only ship stock out of their own warehouse."""
        from rest_framework.exceptions import PermissionDenied

        src = serializer.validated_data.get('source_branch')
        forced = _forced_branch_id(self.request.user)
        if forced and src and src.id != forced:
            raise PermissionDenied(
                'You can only create transfers originating from your assigned '
                'warehouse.')

        # Each line must draw from an item that actually lives in the source
        # warehouse (shared/unassigned items are allowed).
        lines = serializer.validated_data.get('lines') or []
        if src:
            mismatched = [
                line['stock'].medication_name for line in lines
                if line.get('stock') and line['stock'].branch_id
                and line['stock'].branch_id != src.id
            ]
            if mismatched:
                raise serializers.ValidationError({
                    'lines': 'These items do not belong to the source warehouse: '
                             + ', '.join(sorted(set(mismatched))[:5])
                })
        serializer.save()

    @staticmethod
    def _find_or_create_dest_stock(source_stock, dest_branch, lock=False):
        """Find an existing MedicationStock at `dest_branch` representing the
        same medication as `source_stock`, otherwise clone one.

        Match key is the medication name (case-insensitive) within the
        destination branch, narrowed by strength when both sides have one so
        that "Amoxicillin 250mg" and "Amoxicillin 500mg" are never merged
        into a single destination item. A brand-new branch may never have
        carried this item, in which case we clone the source's catalog fields
        so the destination's records stay consistent.
        """
        if not source_stock or not dest_branch:
            return None, False
        # ``MedicationStock.save()`` back-fills ``strength`` (and brand/generic)
        # from the shared medication catalog, so the value stored is *not*
        # necessarily the one we hold here. The destination item must therefore
        # be located by name, preferring an exact strength match, rather than
        # by a (name, strength) pair we cannot predict — that mismatch used to
        # fall through to an insert and die on
        # ``uniq_inv_stock_branch_name_strength`` (shown to the receiver as a
        # 500). The savepoint below covers the residual race.
        qs = (MedicationStock.objects
              .filter(branch=dest_branch,
                      medication_name__iexact=source_stock.medication_name))
        # Only exclude the source row when it lives in a *different* branch.
        # A transfer of an item that is already recorded at the destination
        # (e.g. shipped from HQ but the item's own branch is Coast) must simply
        # receive into that existing row — excluding it forced a clone and the
        # clone collided with the very row we excluded, surfacing as a 500.
        if source_stock.branch_id != dest_branch.id:
            qs = qs.exclude(pk=source_stock.pk)
        if lock:
            qs = qs.select_for_update()
        candidates = list(qs.order_by('pk'))
        if candidates:
            wanted = (source_stock.strength or '').strip().lower()
            exact = [c for c in candidates if (c.strength or '').strip().lower() == wanted]
            return (exact[0] if exact else candidates[0]), False
        clone = MedicationStock(
            medication_name=source_stock.medication_name,
            abbreviation=source_stock.abbreviation or '',
            brand_name=source_stock.brand_name or '',
            generic_name=source_stock.generic_name or '',
            strength=source_stock.strength or '',
            dosage_form=source_stock.dosage_form or '',
            category=source_stock.category,
            unit=source_stock.unit,
            classification=source_stock.classification,
            branch=dest_branch,
            selling_price=source_stock.selling_price,
            cost_price=source_stock.cost_price,
            tax_percent=source_stock.tax_percent,
            discount_percent=source_stock.discount_percent,
            reorder_level=source_stock.reorder_level or 0,
            reorder_quantity=source_stock.reorder_quantity or 0,
            location_in_store='',
            barcode=source_stock.barcode,
            prescription_required=source_stock.prescription_required,
            items_per_unit=source_stock.items_per_unit or 0,
            is_active=True,
        )
        try:
            # A savepoint keeps the outer transaction usable if the insert
            # still collides — without it, catching IntegrityError leaves the
            # connection aborted and every later query in receive() fails.
            with transaction.atomic():
                clone.save()
        except IntegrityError:
            existing = (MedicationStock.objects
                        .filter(branch=dest_branch,
                                medication_name__iexact=source_stock.medication_name)
                        .order_by('pk')
                        .first())
            if existing is None:
                raise
            return existing, False
        return clone, True

    def _set_status(self, transfer, new_status, user, field):
        transfer.status = new_status
        if user and user.is_authenticated:
            setattr(transfer, field, user)
        if new_status == StockTransfer.Status.IN_TRANSIT:
            transfer.shipped_at = timezone.now()
        if new_status == StockTransfer.Status.COMPLETED:
            transfer.received_at = timezone.now()
        transfer.save()

    @staticmethod
    def _clean_signature(raw):
        """Normalise a captured signature payload.

        Returns:
          * ``''``  — no signature supplied (allowed; the UI requires one).
          * the data-URL string when valid.
          * ``None`` — payload present but not a base64 image data-URL, so the
            caller can answer 400 instead of storing garbage.
        """
        if raw in (None, ''):
            return ''
        if not isinstance(raw, str):
            return None
        value = raw.strip()
        if not value:
            return ''
        # Accept only image data-URLs (PNG/JPEG/SVG) and cap the size so a
        # malicious client cannot bloat the row.
        if not value.startswith('data:image/'):
            return None
        if ';base64,' not in value:
            return None
        if len(value) > 2_000_000:  # ~2 MB of base64 text
            return None
        return value

    @staticmethod
    def _consumed_payload(batch, qty: int) -> dict:
        """Snapshot of a lot drained at approval, stored on the transfer line."""
        return {
            'batch_id': batch.id,
            'batch_number': batch.batch_number or '',
            'expiry_date': batch.expiry_date.isoformat() if batch.expiry_date else None,
            'cost_price_per_unit': float(batch.cost_price_per_unit or 0),
            'supplier_id': batch.supplier_id,
            'branch_id': batch.branch_id,
            'qty': int(qty),
        }

    # ── Notification helper for transfer status changes ──
    def _notify_transfer(self, transfer, new_status, actor):
        """Create a system notification about a transfer status change.

        Notifies the transfer's requester (and approver/receiver if
        different from the actor) so they can track progress.
        """
        from notifications.models import Notification

        status_labels = {
            'draft': 'saved as draft',
            'requested': 'submitted for approval',
            'in_transit': 'approved and shipped',
            'completed': 'received and completed',
            'cancelled': 'cancelled',
        }
        label = status_labels.get(new_status, new_status)
        title = f'Transfer {transfer.reference} — {label.title()}'
        message = (
            f'Stock transfer {transfer.reference} ({transfer.source_branch.name} → '
            f'{transfer.dest_branch.name}) has been {label}.'
        )
        # Build recipient set: requester, approver, receiver — but not the actor
        recipients = set()
        for u in [transfer.requested_by, transfer.approved_by]:
            if u and u != actor:
                recipients.add(u)
        # Always notify the requester unless they are the actor
        if transfer.requested_by and transfer.requested_by != actor:
            recipients.add(transfer.requested_by)
        for user in recipients:
            Notification.objects.create(
                recipient=user,
                type=Notification.NotificationType.SYSTEM,
                title=title,
                message=message,
                data={
                    'transfer_id': transfer.id,
                    'reference': transfer.reference,
                    'status': new_status,
                    'source_branch': transfer.source_branch.name,
                    'dest_branch': transfer.dest_branch.name,
                },
            )

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """KPIs for the transfers dashboard header."""
        qs = self.filter_queryset(self.get_queryset())
        by_status = {s: qs.filter(status=s).count() for s in
                     ['draft', 'requested', 'in_transit', 'completed', 'cancelled']}
        in_transit = qs.filter(status='in_transit').prefetch_related('lines__stock')
        transit_value = sum(
            float(l.stock.cost_price or 0) * l.quantity
            for t in in_transit for l in t.lines.all() if l.stock
        )
        month_start = timezone.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        completed_month = qs.filter(status='completed', received_at__gte=month_start).count()
        completed = qs.filter(status='completed').prefetch_related('lines')
        variance_units = sum(l.variance for t in completed for l in t.lines.all())
        durations = [(t.received_at - t.requested_at).total_seconds() / 3600
                     for t in completed
                     if t.received_at and t.requested_at and t.received_at > t.requested_at]
        avg_cycle_hours = round(sum(durations) / len(durations), 1) if durations else None
        return Response({
            'total': qs.count(),
            'by_status': by_status,
            'in_transit_value': round(transit_value, 2),
            'completed_this_month': completed_month,
            'variance_units': variance_units,
            'avg_cycle_hours': avg_cycle_hours,
        })

    @action(detail=False, methods=['get'])
    def analytics(self, request):
        """Comprehensive analytics for the transfers analytics page."""
        return Response(self._analytics_payload(request))

    def _analytics_payload(self, request):
        """Build the analytics payload shared by the JSON endpoint and the PDF.

        Query params:
          ?date_from=&date_to=  ISO dates filtering ``requested_at``
          ?branch=              branch id — transfers leaving or entering it
          ?granularity=         day|week|month (trend buckets, default week)
          ?buckets=             number of trend buckets (default 12, max 52)

        Everything is derived from this tenant's transfers so the page needs a
        single round-trip. Volume is expected to be modest (hundreds to a few
        thousand rows), so aggregation happens in Python after a single
        prefetch rather than in a dozen separate queries.
        """
        from datetime import date as _date, timedelta as _td
        from collections import defaultdict

        def _parse_date(value):
            try:
                return _date.fromisoformat(str(value))
            except (TypeError, ValueError):
                return None

        qs = StockTransfer.objects.select_related(
            'source_branch', 'dest_branch', 'requested_by', 'approved_by',
            'received_by', 'assigned_driver', 'assigned_carrier',
        ).prefetch_related('lines__stock')

        branch_id = request.query_params.get('branch')
        if branch_id:
            qs = qs.filter(Q(source_branch_id=branch_id) | Q(dest_branch_id=branch_id))

        date_from = _parse_date(request.query_params.get('date_from'))
        date_to = _parse_date(request.query_params.get('date_to'))
        if date_from:
            qs = qs.filter(requested_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(requested_at__date__lte=date_to)

        granularity = (request.query_params.get('granularity') or 'week').lower()
        if granularity not in ('day', 'week', 'month'):
            granularity = 'week'
        try:
            bucket_count = int(request.query_params.get('buckets') or 12)
        except (TypeError, ValueError):
            bucket_count = 12
        bucket_count = max(2, min(52, bucket_count))

        transfers = list(qs.order_by('requested_at'))

        STATUS_META = {
            'draft': ('Draft', 'pencil-outline', 'grey'),
            'requested': ('Requested', 'clock-outline', 'blue'),
            'in_transit': ('In transit', 'truck-fast-outline', 'indigo'),
            'completed': ('Completed', 'check-circle-outline', 'green'),
            'cancelled': ('Cancelled', 'cancel', 'red'),
        }

        def line_value(line):
            try:
                return float(line.stock.cost_price or 0) * (line.quantity or 0)
            except Exception:
                return 0.0

        def hours_between(a, b):
            if not a or not b:
                return None
            delta = (b - a).total_seconds() / 3600
            return delta if delta >= 0 else None

        # ── Per-transfer rollups ────────────────────────────────────────
        by_status = defaultdict(int)
        priority_stats = defaultdict(lambda: {'count': 0, 'units': 0, 'value': 0.0,
                                              'cycles': [], 'on_time': [], })
        routes = defaultdict(lambda: {'count': 0, 'units': 0, 'value': 0.0, 'transits': []})
        warehouses = defaultdict(lambda: {'out': 0, 'out_value': 0.0,
                                          'in': 0, 'in_value': 0.0})
        items = defaultdict(lambda: {'units': 0, 'value': 0.0, 'transfers': 0,
                                     'variance': 0, 'name': ''})
        carriers = defaultdict(lambda: {'count': 0, 'units': 0, 'value': 0.0,
                                        'transits': [], 'on_time': [], 'variance': 0})
        discrepancies = []

        totals = {
            'value': 0.0, 'units': 0, 'items': 0,
            'sent_units': 0, 'received_units': 0,
            'variance_units': 0, 'variance_value': 0.0,
        }
        cycle_hours, approval_hours, transit_hours = [], [], []
        on_time_flags = []
        completed_this_month = 0
        month_start = timezone.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        for t in transfers:
            by_status[t.status] += 1
            lines = list(t.lines.all())
            t_units = sum(l.quantity or 0 for l in lines)
            t_value = sum(line_value(l) for l in lines)

            totals['value'] += t_value
            totals['units'] += t_units
            totals['items'] += len(lines)

            if t.status == 'completed':
                completed_this_month += 1 if (t.received_at and t.received_at >= month_start) else 0
                totals['sent_units'] += t_units
                totals['received_units'] += sum(l.quantity_received or 0 for l in lines)
                var_u = sum((l.quantity_received or 0) - (l.quantity or 0) for l in lines)
                var_v = sum(((l.quantity_received or 0) - (l.quantity or 0))
                            * float(l.stock.cost_price or 0) for l in lines if l.stock)
                totals['variance_units'] += var_u
                totals['variance_value'] += var_v
                if var_u:
                    discrepancies.append({
                        'reference': t.reference,
                        'id': t.id,
                        'route': f'{t.source_branch.name} → {t.dest_branch.name}',
                        'units_sent': t_units,
                        'units_received': sum(l.quantity_received or 0 for l in lines),
                        'variance_units': var_u,
                        'variance_value': round(var_v, 2),
                        'received_at': t.received_at,
                        'priority': t.priority,
                    })

            # Durations
            appr = hours_between(t.requested_at, t.shipped_at)
            transit = hours_between(t.shipped_at, t.received_at)
            cycle = hours_between(t.requested_at, t.received_at)
            if appr is not None:
                approval_hours.append(appr)
            if transit is not None:
                transit_hours.append(transit)
            if cycle is not None:
                cycle_hours.append(cycle)

            # On-time delivery vs. the scheduled delivery date
            otm = None
            if t.status == 'completed' and t.scheduled_delivery and t.received_at:
                otm = t.received_at <= t.scheduled_delivery
                on_time_flags.append(otm)

            # Priority bucket
            p = priority_stats[t.priority or 'normal']
            p['count'] += 1
            p['units'] += t_units
            p['value'] += t_value
            if cycle is not None:
                p['cycles'].append(cycle)
            if otm is not None:
                p['on_time'].append(otm)

            # Route bucket
            key = (t.source_branch.name, t.dest_branch.name)
            r = routes[key]
            r['count'] += 1
            r['units'] += t_units
            r['value'] += t_value
            if transit is not None:
                r['transits'].append(transit)

            # Warehouse throughput (out = dispatched, in = completed receipts)
            src = warehouses[t.source_branch.name]
            if t.status in ('in_transit', 'completed'):
                src['out'] += 1
                src['out_value'] += t_value
            dst = warehouses[t.dest_branch.name]
            if t.status == 'completed':
                dst['in'] += 1
                dst['in_value'] += t_value

            # Item rollup
            for l in lines:
                if not l.stock:
                    continue
                it = items[l.stock_id]
                it['name'] = l.stock.medication_name
                it['units'] += l.quantity or 0
                it['value'] += line_value(l)
                it['transfers'] += 1
                it['variance'] += (l.quantity_received or 0) - (l.quantity or 0)

            # Carrier / driver performance
            carrier_name = None
            if t.assigned_carrier_id:
                carrier_name = t.assigned_carrier.name if t.assigned_carrier else 'Carrier'
            elif t.assigned_driver_id:
                carrier_name = (t.assigned_driver.full_name
                                if t.assigned_driver else 'Internal driver')
            if carrier_name:
                c = carriers[carrier_name]
                c['count'] += 1
                c['units'] += t_units
                c['value'] += t_value
                if transit is not None:
                    c['transits'].append(transit)
                if otm is not None:
                    c['on_time'].append(otm)
                if t.status == 'completed':
                    c['variance'] += sum(
                        (l.quantity_received or 0) - (l.quantity or 0) for l in lines)

        def avg(values, nd=1):
            return round(sum(values) / len(values), nd) if values else None

        def pct(part, whole, nd=1):
            return round((part / whole) * 100, nd) if whole else 0.0

        total = len(transfers)
        status_rows = []
        for key, (label, icon, color) in STATUS_META.items():
            count = by_status.get(key, 0)
            status_rows.append({
                'status': key, 'label': label, 'icon': icon, 'color': color,
                'count': count, 'pct': pct(count, total),
            })

        priority_rows = []
        for key in ('low', 'normal', 'high', 'urgent'):
            data = priority_stats.get(key)
            if not data:
                continue
            priority_rows.append({
                'priority': key,
                'count': data['count'],
                'units': data['units'],
                'value': round(data['value'], 2),
                'avg_cycle_hours': avg(data['cycles']),
                'on_time_pct': (pct(data['on_time'].count(True), len(data['on_time']))
                                if data['on_time'] else None),
            })

        route_rows = sorted(
            ({
                'route': f'{src} → {dst}',
                'source': src,
                'dest': dst,
                'count': v['count'],
                'units': v['units'],
                'value': round(v['value'], 2),
                'avg_transit_hours': avg(v['transits']),
            } for (src, dst), v in routes.items()),
            key=lambda x: (-x['count'], -x['value']),
        )[:8]

        warehouse_rows = sorted(
            ({
                'branch': name,
                'dispatched': v['out'],
                'dispatched_value': round(v['out_value'], 2),
                'received': v['in'],
                'received_value': round(v['in_value'], 2),
                'total': v['out'] + v['in'],
            } for name, v in warehouses.items()),
            key=lambda x: -x['total'],
        )

        top_items = sorted(
            ({
                'name': v['name'],
                'units': v['units'],
                'value': round(v['value'], 2),
                'transfers': v['transfers'],
                'variance': v['variance'],
            } for v in items.values()),
            key=lambda x: (-x['units'], -x['value']),
        )[:10]

        carrier_rows = sorted(
            ({
                'name': name,
                'shipments': v['count'],
                'units': v['units'],
                'value': round(v['value'], 2),
                'avg_transit_hours': avg(v['transits']),
                'on_time_pct': (pct(v['on_time'].count(True), len(v['on_time']))
                                if v['on_time'] else None),
                'variance_units': v['variance'],
            } for name, v in carriers.items()),
            key=lambda x: (-x['shipments'], -x['units']),
        )[:10]

        # ── Trend buckets ───────────────────────────────────────────────
        def bucket_start(d, gran):
            if gran == 'day':
                return d
            if gran == 'week':
                return d - _td(days=d.weekday())
            return d.replace(day=1)

        def next_bucket(d, gran):
            if gran == 'day':
                return d + _td(days=1)
            if gran == 'week':
                return d + _td(days=7)
            return (d.replace(day=28) + _td(days=4)).replace(day=1)

        def bucket_label(d, gran):
            if gran == 'day':
                return d.strftime('%b %d')
            if gran == 'week':
                return f'wk {d.strftime("%b %d")}'
            return d.strftime('%b %Y')

        today = timezone.localdate()
        end_bucket = bucket_start(today, granularity)
        bucket_starts = []
        cursor = end_bucket
        for _ in range(bucket_count):
            bucket_starts.append(cursor)
            if granularity == 'day':
                cursor -= _td(days=1)
            elif granularity == 'week':
                cursor -= _td(days=7)
            else:
                cursor = (cursor - _td(days=1)).replace(day=1)
        bucket_starts.reverse()

        trend_map = {
            d: {'created': 0, 'completed': 0, 'cancelled': 0,
                'units': 0, 'value': 0.0, 'received_units': 0}
            for d in bucket_starts
        }

        for t in transfers:
            if not t.requested_at:
                continue
            req_local = timezone.localtime(t.requested_at)
            b = bucket_start(req_local.date(), granularity)
            if b not in trend_map:
                continue
            row = trend_map[b]
            row['created'] += 1
            row['units'] += sum(l.quantity or 0 for l in t.lines.all())
            row['value'] += sum(line_value(l) for l in t.lines.all())
            if t.status == 'cancelled':
                row['cancelled'] += 1
            if t.status == 'completed':
                row['completed'] += 1
                row['received_units'] += sum(l.quantity_received or 0
                                             for l in t.lines.all())

        trend_rows = [{
            'label': bucket_label(d, granularity),
            'date': d.isoformat(),
            **trend_map[d],
            'value': round(trend_map[d]['value'], 2),
        } for d in bucket_starts]

        # ── Aging of open transfers ─────────────────────────────────────
        now = timezone.now()
        aging_buckets = [
            ('0–1 day', 0, 1),
            ('1–3 days', 1, 3),
            ('3–7 days', 3, 7),
            ('7+ days', 7, None),
        ]
        aging_counts = {label: 0 for label, _, _ in aging_buckets}
        aging_value = {label: 0.0 for label, _, _ in aging_buckets}
        for t in transfers:
            if t.status not in ('requested', 'in_transit'):
                continue
            age_days = (now - t.requested_at).total_seconds() / 86400
            for label, lo, hi in aging_buckets:
                if age_days >= lo and (hi is None or age_days < hi):
                    aging_counts[label] += 1
                    aging_value[label] += sum(line_value(l) for l in t.lines.all())
                    break
        aging_rows = [{
            'label': label,
            'count': aging_counts[label],
            'value': round(aging_value[label], 2),
        } for label, _, _ in aging_buckets]

        fill_rate = pct(totals['received_units'], totals['sent_units'])
        on_time_pct = (pct(on_time_flags.count(True), len(on_time_flags))
                       if on_time_flags else None)

        return {
            'filters': {
                'date_from': date_from.isoformat() if date_from else None,
                'date_to': date_to.isoformat() if date_to else None,
                'branch': int(branch_id) if branch_id and str(branch_id).isdigit() else None,
                'granularity': granularity,
                'buckets': bucket_count,
            },
            'kpis': {
                'total': total,
                'completed': by_status.get('completed', 0),
                'in_transit': by_status.get('in_transit', 0),
                'requested': by_status.get('requested', 0),
                'draft': by_status.get('draft', 0),
                'cancelled': by_status.get('cancelled', 0),
                'completion_pct': pct(by_status.get('completed', 0), total),
                'cancel_pct': pct(by_status.get('cancelled', 0), total),
                'units': totals['units'],
                'items': totals['items'],
                'value': round(totals['value'], 2),
                'sent_units': totals['sent_units'],
                'received_units': totals['received_units'],
                'fill_rate_pct': fill_rate,
                'variance_units': totals['variance_units'],
                'variance_value': round(totals['variance_value'], 2),
                'avg_cycle_hours': avg(cycle_hours),
                'avg_approval_hours': avg(approval_hours),
                'avg_transit_hours': avg(transit_hours),
                'on_time_pct': on_time_pct,
                'completed_this_month': completed_this_month,
                'discrepancy_count': len(discrepancies),
            },
            'status_breakdown': status_rows,
            'priority_breakdown': priority_rows,
            'trend': trend_rows,
            'top_routes': route_rows,
            'warehouse_throughput': warehouse_rows,
            'top_items': top_items,
            'partner_performance': carrier_rows,
            'discrepancies': sorted(discrepancies, key=lambda x: x['received_at'],
                                    reverse=True)[:12],
            'aging': aging_rows,
        }

    @action(detail=False, methods=['get'], url_path='analytics-pdf')
    def analytics_pdf(self, request):
        """Premium PDF report of the transfer analytics dashboard.

        Accepts the same query params as :meth:`analytics` and renders the whole
        dashboard — KPI strip, volume trend, pipeline mix, service quality,
        aging, priority performance, busiest lanes, warehouse throughput, top
        items, carrier performance and receipt discrepancies — as a branded
        landscape-A4 document.
        """
        import io as _io
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle, HRFlowable)
        from reportlab.graphics.shapes import (Drawing, Rect, Circle, Wedge,
                                               Line as GLine, PolyLine,
                                               String as GString)

        payload = self._analytics_payload(request)
        kpis = payload['kpis']
        filters = payload['filters']
        status_rows = payload['status_breakdown']
        priority_rows = payload['priority_breakdown']
        trend_rows = payload['trend']
        route_rows = payload['top_routes']
        warehouse_rows = payload['warehouse_throughput']
        item_rows = payload['top_items']
        partner_rows = payload['partner_performance']
        discrepancy_rows = payload['discrepancies']
        aging_rows = payload['aging']

        # ── Branding / scope ────────────────────────────────────────────
        from config.pdf_branding import resolve_branding

        logo_path, business_name = None, ''
        try:
            logo_path, business_name = resolve_branding(request)
        except (ImportError, NotImplementedError, OSError, ValueError,
                AttributeError) as exc:  # branding is best-effort
            logger.warning('Transfer analytics PDF: branding unavailable (%s)', exc)
            logo_path, business_name = None, ''
        business_name = (business_name
                         or getattr(getattr(request, 'tenant', None), 'name', '')
                         or 'AdhereMed')

        branch_label = 'All branches'
        if filters.get('branch'):
            try:
                branch_obj = Branch.objects.filter(id=filters['branch']).first()
                branch_label = branch_obj.name if branch_obj else f"Branch #{filters['branch']}"
            except Exception:
                branch_label = f"Branch #{filters['branch']}"

        period_label = 'All time'
        if filters.get('date_from'):
            def _pretty(iso):
                try:
                    from datetime import datetime as _dtp
                    return _dtp.strptime(str(iso), '%Y-%m-%d').strftime('%b %d %Y')
                except (TypeError, ValueError):
                    return str(iso)
            period_label = (f"{_pretty(filters['date_from'])} – "
                            f"{_pretty(filters.get('date_to') or timezone.localdate())}")
        gran_label = {'day': 'Daily', 'week': 'Weekly',
                      'month': 'Monthly'}.get(filters.get('granularity'), 'Weekly')

        # ── Palette ─────────────────────────────────────────────────────
        NAVY = '#0F172A'
        SLATE = '#64748B'
        BORDER = '#E2E8F0'
        TRACK = '#EDF1F7'
        GREEN = '#16A34A'
        RED = '#DC2626'
        AMBER = '#F59E0B'
        INDIGO = '#6366F1'
        GREY = '#94A3B8'
        TEAL = '#14B8A6'
        BLUE = '#3B82F6'

        # Brand palette — read live from the tenant so a palette change at
        # /ims/organization/branding repaints this document too. Mirrors
        # `useBranding()` on the web app (same defaults, same accent softening).
        tenant = getattr(request, 'tenant', None)

        def _brand_hex(attr, default):
            """Hex colour configured at /ims/organization/branding."""
            raw = getattr(tenant, attr, '') if tenant else ''
            if isinstance(raw, str):
                raw = raw.strip()
                if len(raw) == 7 and raw.startswith('#'):
                    try:
                        int(raw[1:], 16)
                        return '#' + raw[1:].upper()
                    except ValueError:
                        pass
            return default

        BRAND = _brand_hex('brand_primary', '#2F6DFF')
        DEEP = _brand_hex('brand_secondary', '#143CE1')
        ACCENT_SOURCE = _brand_hex('brand_accent', '#37D6FF')

        def _rgb(hex_color):
            h = str(hex_color).lstrip('#')
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

        def mix(hex_color, factor):
            """Blend a hex colour toward white (factor > 0) or black (factor < 0)."""
            r, g, b = _rgb(hex_color)
            if factor >= 0:
                r, g, b = (round(v + (255 - v) * factor) for v in (r, g, b))
            else:
                r, g, b = (round(v * (1 + factor)) for v in (r, g, b))
            return '#%02X%02X%02X' % (r, g, b)

        def blend(a_hex, b_hex, amount):
            """Blend two hex colours; ``amount`` 0 = a, 1 = b."""
            a, b = _rgb(a_hex), _rgb(b_hex)
            t = min(max(amount, 0.0), 1.0)
            return '#%02X%02X%02X' % tuple(
                round(a[i] + (b[i] - a[i]) * t) for i in range(3))

        # Third gradient stop: accent softened toward the primary, exactly like
        # `gradientStops` in the web `useBranding()` composable.
        ACCENT = blend(ACCENT_SOURCE, BRAND, 0.55)

        COLOR_MAP = {'grey': GREY, 'blue': BLUE, 'indigo': INDIGO, 'green': GREEN,
                     'red': RED, 'amber': AMBER, 'teal': TEAL, 'primary': BRAND,
                     'error': RED, 'success': GREEN}

        def _grad_at(t):
            stops = ((0.0, _rgb(DEEP)), (0.52, _rgb(BRAND)), (1.0, _rgb(ACCENT)))
            if t <= stops[0][0]:
                return stops[0][1]
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t <= t1:
                    f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                    return tuple(c0[k] + (c1[k] - c0[k]) * f for k in range(3))
            return stops[-1][1]

        # ── Formatters ──────────────────────────────────────────────────
        def money(v):
            try:
                return f'KES {float(v or 0):,.2f}'
            except (TypeError, ValueError):
                return 'KES 0.00'

        def ints(v):
            try:
                return f'{int(v or 0):,}'
            except (TypeError, ValueError):
                return '0'

        def pct(v):
            return '—' if v is None else f'{float(v):.1f}%'

        def hours(v):
            if v is None:
                return '—'
            try:
                h = float(v)
            except (TypeError, ValueError):
                return '—'
            if h < 1:
                return f'{round(h * 60)}m'
            if h < 48:
                return f'{h:.1f}h'
            return f'{h / 24:.1f}d'

        def stamp(value):
            if not value:
                return '—'
            try:
                return timezone.localtime(value).strftime('%b %d %Y, %I:%M %p')
            except Exception:
                return str(value)

        PRIORITY_META = {
            'low': ('Low', GREY),
            'normal': ('Normal', BRAND),
            'high': ('High', AMBER),
            'urgent': ('Urgent', RED),
        }

        # ── Styles ──────────────────────────────────────────────────────
        st_card_title = ParagraphStyle('ct', fontName='Helvetica-Bold', fontSize=9.5,
                                       textColor=HexColor(NAVY), leading=12)
        st_card_sub = ParagraphStyle('cs', fontName='Helvetica', fontSize=6.5,
                                     textColor=HexColor(SLATE), leading=8.5)
        st_cap = ParagraphStyle('cap', fontName='Helvetica', fontSize=6,
                                textColor=HexColor(SLATE), leading=8)
        st_cap_r = ParagraphStyle('capr', parent=st_cap, alignment=TA_RIGHT)
        st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=7,
                                 textColor=HexColor(NAVY), leading=9)
        st_cell_b = ParagraphStyle('cellb', parent=st_cell, fontName='Helvetica-Bold')
        st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
        st_cell_c = ParagraphStyle('cellc', parent=st_cell, alignment=TA_CENTER)
        st_colhead = ParagraphStyle('ch', fontName='Helvetica-Bold', fontSize=6,
                                    textColor=HexColor(SLATE), leading=8)
        st_colhead_r = ParagraphStyle('chr', parent=st_colhead, alignment=TA_RIGHT)
        st_colhead_c = ParagraphStyle('chc', parent=st_colhead, alignment=TA_CENTER)
        st_scope_label = ParagraphStyle('sl', fontName='Helvetica-Bold', fontSize=5.6,
                                        textColor=HexColor(SLATE), leading=7.5)
        st_scope_value = ParagraphStyle('sv', fontName='Helvetica-Bold', fontSize=8,
                                        textColor=HexColor(NAVY), leading=10.5)
        st_note = ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=6.5,
                                 textColor=HexColor(SLATE), leading=9)
        st_body = ParagraphStyle('body', fontName='Helvetica', fontSize=7.2,
                                 textColor=HexColor(NAVY), leading=10.5)

        def chip(text, color_hex, size=6):
            style = ParagraphStyle(
                f'chip{size}', fontName='Helvetica-Bold', fontSize=size,
                leading=size + 2.2, alignment=TA_CENTER,
                textColor=HexColor(mix(color_hex, -0.25)),
                backColor=HexColor(mix(color_hex, 0.84)), borderPadding=1.7,
            )
            return Paragraph(str(text), style)

        def dot(color_hex, size=5.4):
            d = Drawing(size, size)
            d.add(Circle(size / 2, size / 2, size / 2, fillColor=HexColor(color_hex),
                         strokeWidth=0))
            return d

        def bar(frac, color_hex, width, height=4.4):
            d = Drawing(width, height)
            d.add(Rect(0, 0, width, height, fillColor=HexColor(TRACK), strokeWidth=0))
            filled = max(1.4, width * min(1.0, max(0.0, frac or 0)))
            d.add(Rect(0, 0, filled, height, fillColor=HexColor(color_hex), strokeWidth=0))
            return d

        # ── Geometry ────────────────────────────────────────────────────
        W, H = landscape(A4)
        MARGIN = 14 * mm
        CONTENT_W = W - 2 * MARGIN
        GAP = 5 * mm
        HALF_W = (CONTENT_W - GAP) / 2

        # ── Page furniture ──────────────────────────────────────────────
        def _has_logo():
            return bool(logo_path) and os.path.exists(logo_path)

        def _fit(canv, text, font_name, font_size, max_width):
            """Truncate ``text`` with an ASCII ellipsis so it fits ``max_width``."""
            if not text:
                return ''
            if canv.stringWidth(text, font_name, font_size) <= max_width:
                return text
            ell = '...'
            lo, hi = 0, len(text)
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if canv.stringWidth(text[:mid] + ell, font_name, font_size) <= max_width:
                    lo = mid
                else:
                    hi = mid - 1
            return (text[:lo].rstrip() + ell) if lo else ''

        def _draw_trailing_logo(canv, band_bottom, band_h, box, pad=1.5 * mm):
            """Tenant logo flush against the right edge of the header band.

            Returns the drawn tile width (0 when there is no usable logo) so
            callers can pull the company details clear of it.
            """
            if not _has_logo():
                return 0.0
            tile = box + 2 * pad
            x = W - MARGIN - 5 * mm - tile
            y = band_bottom + (band_h - tile) / 2
            canv.saveState()
            canv.setFillColor(white)
            canv.roundRect(x, y, tile, tile, 2.2 * mm, stroke=0, fill=1)
            try:
                canv.drawImage(logo_path, x + pad, y + pad, box, box,
                               preserveAspectRatio=True, anchor='c', mask='auto')
            except (OSError, ValueError, TypeError):
                canv.restoreState()
                return 0.0
            canv.restoreState()
            return tile

        def _page(canv, doc):
            canv.saveState()
            page_no = canv.getPageNumber()
            right_edge = W - MARGIN - 5 * mm
            left_x = MARGIN + 5 * mm
            if page_no == 1:
                band_top = H - 10 * mm
                band_h = 24 * mm
                band_bottom = band_top - band_h
                canv.saveState()
                path = canv.beginPath()
                path.roundRect(MARGIN, band_bottom, CONTENT_W, band_h, 3 * mm)
                canv.clipPath(path, stroke=0, fill=0)
                steps = 150
                slice_w = CONTENT_W / steps
                for i in range(steps):
                    r, g, b = _grad_at(i / (steps - 1))
                    canv.setFillColorRGB(r / 255, g / 255, b / 255)
                    canv.rect(MARGIN + i * slice_w, band_bottom,
                              slice_w + 0.8, band_h, stroke=0, fill=1)
                canv.restoreState()

                # Tenant logo — last element on the right, after the details.
                tile = _draw_trailing_logo(canv, band_bottom, band_h, 15 * mm)
                text_right = right_edge - (tile + 6 * mm if tile else 0)

                canv.setFillColor(white)
                canv.setFont('Helvetica-Bold', 5.8)
                canv.drawString(left_x, H - 15.6 * mm,
                                'INVENTORY · LOGISTICS · ANALYTICS', charSpace=1.1)
                canv.setFont('Helvetica-Bold', 16)
                canv.drawString(left_x, H - 22.4 * mm, 'Transfer Analytics')
                canv.setFont('Helvetica', 7)
                subtitle = ('Throughput, cycle time, fill rate and partner performance '
                            'across every warehouse move')
                canv.drawString(left_x, H - 27.4 * mm,
                                _fit(canv, subtitle, 'Helvetica', 7,
                                     text_right - left_x - 6 * mm))

                # Company details — right-aligned, sitting left of the logo
                canv.setFont('Helvetica-Bold', 9.5)
                canv.setFillColor(white)
                canv.drawRightString(text_right, H - 16.4 * mm, business_name[:52])
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 21.2 * mm,
                                     f'Period: {period_label}')
                canv.drawRightString(text_right, H - 25 * mm,
                                     f'Scope: {branch_label}')
                canv.drawRightString(text_right, H - 28.8 * mm,
                                     'Generated '
                                     + timezone.localtime(timezone.now())
                                     .strftime('%b %d %Y, %I:%M %p'))
            else:
                band_top = H - 10 * mm
                band_h = 17 * mm
                band_bottom = band_top - band_h
                canv.setFillColor(HexColor('#F6F8FC'))
                canv.rect(MARGIN, band_bottom, CONTENT_W, band_h, stroke=0, fill=1)
                canv.setFillColor(HexColor(BRAND))
                canv.rect(MARGIN, band_bottom, 2.6 * mm, band_h, stroke=0, fill=1)

                tile = _draw_trailing_logo(canv, band_bottom, band_h, 11 * mm,
                                           pad=1.2 * mm)
                text_right = right_edge - (tile + 5 * mm if tile else 0)

                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 10)
                canv.drawString(left_x, H - 17.6 * mm, 'Transfer Analytics')
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                meta = f'{business_name} · {branch_label} · {period_label}'
                canv.drawString(left_x, H - 22.6 * mm,
                                _fit(canv, meta, 'Helvetica', 6.6,
                                     text_right - left_x - 6 * mm))

                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 7)
                canv.drawRightString(text_right, H - 18 * mm, business_name[:52])
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 23 * mm,
                                     'Analytics report · continued')

            # Footer band
            canv.setStrokeColor(HexColor(BORDER))
            canv.setLineWidth(0.6)
            canv.line(MARGIN, 12 * mm, W - MARGIN, 12 * mm)
            canv.setFillColor(HexColor(SLATE))
            canv.setFont('Helvetica', 6.8)
            canv.drawString(MARGIN, 7.6 * mm, f'{business_name} · Transfer Analytics Report')
            canv.setFont('Helvetica-Bold', 6.8)
            canv.setFillColor(HexColor(BRAND))
            canv.drawCentredString(W / 2, 7.6 * mm,
                                   'Powered by AdhereMed · www.adheremed.co')
            canv.setFont('Helvetica', 6.8)
            canv.setFillColor(HexColor(SLATE))
            canv.drawRightString(W - MARGIN, 7.6 * mm, f'Page {page_no}')
            canv.restoreState()

        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=landscape(A4),
            leftMargin=MARGIN, rightMargin=MARGIN,
            topMargin=34 * mm, bottomMargin=16 * mm,
            title='Transfer Analytics Report',
            author=business_name, subject='Stock transfer analytics',
        )
        flow = [Spacer(1, 1 * mm)]

        # ── Reusable blocks ─────────────────────────────────────────────
        def card(title, subtitle, content, width):
            rows = [[Paragraph(title, st_card_title)]]
            if subtitle:
                rows.append([Paragraph(subtitle, st_card_sub)])
            rows += [[item] for item in content]
            tbl = Table(rows, colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 1.5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5),
                ('TOPPADDING', (0, 0), (0, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 0 if subtitle else 4),
                ('BOTTOMPADDING', (0, -1), (-1, -1), 7),
            ]))
            return tbl

        def two_col(left, right, left_w=None):
            lw = left_w or HALF_W
            rw = CONTENT_W - lw - GAP
            tbl = Table([[left, '', right]], colWidths=[lw, GAP, rw], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            return tbl

        def kpi_tile(label, value, sub, color_hex, width):
            value_style = ParagraphStyle('kv', fontName='Helvetica-Bold', fontSize=11.5,
                                         textColor=HexColor(color_hex), leading=14)
            body = [Paragraph(label, st_scope_label),
                    Paragraph(value, value_style),
                    Paragraph(sub, st_cap)]
            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('LINEBEFORE', (0, 0), (0, -1), 2.6, HexColor(color_hex)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 7),
                ('RIGHTPADDING', (0, 0), (-1, -1), 5),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return tbl

        def stat_tile(label, value, sub, color_hex, width):
            value_style = ParagraphStyle('sv2', fontName='Helvetica-Bold', fontSize=12.5,
                                         textColor=HexColor(mix(color_hex, -0.15)),
                                         leading=15)
            body = [Paragraph(value, value_style),
                    Paragraph(label, st_scope_label),
                    Paragraph(sub, st_cap)]
            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(mix(color_hex, 0.62))),
                ('BACKGROUND', (0, 0), (-1, -1), HexColor(mix(color_hex, 0.9))),
                ('LEFTPADDING', (0, 0), (-1, -1), 7),
                ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return tbl

        def data_table(header, rows, widths, aligns=None):
            aligns = aligns or ['LEFT'] * len(header)
            head = []
            for i, label in enumerate(header):
                style = (st_colhead_r if aligns[i] == 'RIGHT'
                         else st_colhead_c if aligns[i] == 'CENTER' else st_colhead)
                head.append(Paragraph(label, style))
            body = [head] + rows
            tbl = Table(body, colWidths=widths, hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.7, HexColor(BORDER)),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 3),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            return tbl

        def empty_note(text):
            return Paragraph(text, st_note)

        # ── 1. Scope bar ────────────────────────────────────────────────
        def scope_cell(label, value):
            return [Paragraph(label, st_scope_label), Paragraph(value, st_scope_value)]

        scope = Table([[
            scope_cell('REPORTING PERIOD', period_label),
            scope_cell('BRANCH SCOPE', branch_label),
            scope_cell('GRANULARITY', f'{gran_label} · {len(trend_rows)} buckets'),
            scope_cell('DATASET', f'{ints(kpis["total"])} transfers · '
                                  f'{ints(kpis["items"])} line items'),
        ]], colWidths=[CONTENT_W / 4] * 4, hAlign='LEFT')
        scope.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), HexColor('#F6F8FC')),
            ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ]))
        flow += [scope, Spacer(1, 4 * mm)]

        # ── 2. KPI strip ────────────────────────────────────────────────
        tile_gap = 4.4 * mm
        tile_w = (CONTENT_W - 5 * tile_gap) / 6
        fill_color = GREEN if (kpis.get('fill_rate_pct') or 100) >= 98 else AMBER
        on_time = kpis.get('on_time_pct')
        on_time_color = GREY if on_time is None else (GREEN if on_time >= 90 else AMBER)
        tiles = [
            kpi_tile('TRANSFERS', ints(kpis['total']),
                     f"{ints(kpis['completed'])} completed · "
                     f"{ints(kpis['cancelled'])} cancelled", BRAND, tile_w),
            kpi_tile('VALUE MOVED', money(kpis['value']),
                     f"{ints(kpis['units'])} units at cost", TEAL, tile_w),
            kpi_tile('IN TRANSIT', ints(kpis['in_transit']),
                     f"{ints(kpis['requested'])} awaiting approval", INDIGO, tile_w),
            kpi_tile('FILL RATE', pct(kpis.get('fill_rate_pct')),
                     f"{ints(kpis['variance_units'])} units variance", fill_color, tile_w),
            kpi_tile('AVG CYCLE', hours(kpis.get('avg_cycle_hours')),
                     f"{hours(kpis.get('avg_approval_hours'))} to approve · "
                     f"{hours(kpis.get('avg_transit_hours'))} transit", BLUE, tile_w),
            kpi_tile('ON TIME', pct(on_time),
                     'vs scheduled delivery' if on_time is not None else 'no ETA recorded',
                     on_time_color, tile_w),
        ]
        tile_row, tile_widths = [], []
        for idx, tile in enumerate(tiles):
            tile_row.append(tile)
            tile_widths.append(tile_w)
            if idx < len(tiles) - 1:
                tile_row.append('')
                tile_widths.append(tile_gap)
        kpi_tbl = Table([tile_row], colWidths=tile_widths, hAlign='LEFT')
        kpi_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        flow += [kpi_tbl, Spacer(1, 4 * mm)]

        # ── 3. Executive summary ────────────────────────────────────────
        summary_bits = []
        summary_bits.append(
            f"Moved <b>{ints(kpis['units'])} units</b> worth <b>{money(kpis['value'])}</b> "
            f"across <b>{ints(kpis['total'])} transfers</b>, completing "
            f"<b>{ints(kpis['completed'])}</b> ({pct(kpis.get('completion_pct'))}).")
        if route_rows:
            top = route_rows[0]
            summary_bits.append(
                f"The busiest lane is <b>{top['source']} → {top['dest']}</b> with "
                f"{ints(top['count'])} transfers ({ints(top['units'])} units).")
        if kpis.get('fill_rate_pct') is not None:
            summary_bits.append(
                f"Receipts ran at <b>{pct(kpis['fill_rate_pct'])} fill rate</b> "
                f"({ints(kpis['received_units'])} of {ints(kpis['sent_units'])} units)")
            if kpis.get('discrepancy_count'):
                summary_bits.append(
                    f"with <b>{ints(kpis['discrepancy_count'])} discrepanc"
                    f"{'y' if kpis['discrepancy_count'] == 1 else 'ies'}</b> logged.")
            else:
                summary_bits.append('with no discrepancies logged.')
        stale = sum(a['count'] for a in aging_rows if a['label'] in ('3–7 days', '7+ days'))
        open_count = sum(a['count'] for a in aging_rows)
        if open_count:
            summary_bits.append(
                f"<b>{ints(open_count)} open transfer"
                f"{'' if open_count == 1 else 's'}</b> remain in the pipeline"
                + (f", {ints(stale)} of them aged 3+ days." if stale
                   else ', all under 3 days old.'))
        summary = ' '.join(summary_bits)
        flow += [card('At a glance', 'Live figures for the selected scope',
                      [Paragraph(summary, st_body)], CONTENT_W),
                 Spacer(1, 4 * mm)]

        # ── 4. Volume trend chart ───────────────────────────────────────
        trend_show = trend_rows[-26:]
        chart_w = CONTENT_W - 16
        chart_h = 54 * mm
        if trend_show:
            dr = Drawing(chart_w, chart_h)
            n = len(trend_show)
            pad_l, pad_r, pad_t, pad_b = 22, 5, 6, 14
            iw, ih = chart_w - pad_l - pad_r, chart_h - pad_t - pad_b
            maxv = max([1] + [max(r['created'], r['completed'], r.get('cancelled') or 0)
                              for r in trend_show])
            for i in range(4):
                gy = pad_b + i * ih / 3
                dr.add(GLine(pad_l, gy, pad_l + iw, gy, strokeColor=HexColor('#EEF2F7'),
                             strokeWidth=0.6))
                tick = f'{maxv * i / 3:.0f}'
                if i == 0 or tick != f'{maxv * (i - 1) / 3:.0f}':
                    dr.add(GString(pad_l - 3, gy - 2, tick,
                                   fontName='Helvetica', fontSize=5.4,
                                   fillColor=HexColor(SLATE), textAnchor='end'))
            gw = iw / max(1, n)
            bw = max(1.8, min(2.9 * mm, gw * 0.2))
            for i, row in enumerate(trend_show):
                gx = pad_l + i * gw + gw / 2
                for k, (key, colr) in enumerate((('created', BRAND),
                                                 ('completed', GREEN),
                                                 ('cancelled', RED))):
                    val = row.get(key) or 0
                    if not val:
                        continue
                    bar_h = max(1.2, (val / maxv) * ih)
                    x = gx - 1.5 * bw + k * bw
                    dr.add(Rect(x, pad_b, bw * 0.86, bar_h,
                                fillColor=HexColor(colr), strokeWidth=0))
            step = max(1, int(round(n / 13)))
            for i, row in enumerate(trend_show):
                if i % step == 0 or i == n - 1:
                    label = str(row['label']).replace('wk ', '')
                    dr.add(GString(pad_l + i * gw + gw / 2, 2.5, label,
                                   fontName='Helvetica', fontSize=5.2,
                                   fillColor=HexColor(SLATE), textAnchor='middle'))
            dr.add(GLine(pad_l, pad_b, pad_l + iw, pad_b, strokeColor=HexColor(BORDER),
                         strokeWidth=0.7))

            legend = Table([[
                dot(BRAND), Paragraph('Created', st_cap), '',
                dot(GREEN), Paragraph('Completed', st_cap), '',
                dot(RED), Paragraph('Cancelled', st_cap),
            ]], colWidths=[7, 34, 8, 7, 40, 8, 7, 40], hAlign='RIGHT')
            legend.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            peak = max(trend_show, key=lambda r: r['created'])
            total_value = sum(r.get('value') or 0 for r in trend_show)
            total_units = sum(r.get('units') or 0 for r in trend_show)
            footer_bits = (f"Peak bucket <b>{peak['label']}</b> ({ints(peak['created'])} created)"
                           f" · {ints(total_units)} units · {money(total_value)} in window")
            if len(trend_rows) > len(trend_show):
                footer_bits += f" · showing last {len(trend_show)} of {len(trend_rows)} buckets"
            trend_content = [legend, Spacer(1, 1.5 * mm), dr, Spacer(1, 1 * mm),
                             Paragraph(footer_bits, st_cap)]
            flow += [card('Transfer volume & value',
                          f'Created, completed and cancelled transfers per '
                          f'{gran_label.lower().rstrip("ly")} bucket',
                          trend_content, CONTENT_W),
                     Spacer(1, 4 * mm)]
        else:
            flow += [card('Transfer volume & value', 'No activity in this window',
                          [empty_note('Widen the reporting period to see history.')],
                          CONTENT_W),
                     Spacer(1, 4 * mm)]

        # ── 5. Pipeline mix + service quality ───────────────────────────
        donut_size = 34 * mm
        segments = [{'label': s['label'], 'value': s['count'],
                     'color': COLOR_MAP.get(s['color'], BLUE)}
                    for s in status_rows if s['count'] > 0]
        donut_drawing = None
        if segments:
            donut_drawing = Drawing(donut_size, donut_size)
            seg_total = sum(s['value'] for s in segments)
            radius = donut_size / 2 - 1
            angle = 90.0
            for seg in segments:
                sweep = 360.0 * seg['value'] / seg_total
                donut_drawing.add(Wedge(donut_size / 2, donut_size / 2, radius,
                                        angle - sweep, angle,
                                        fillColor=HexColor(seg['color']),
                                        strokeColor=white, strokeWidth=1))
                angle -= sweep
            donut_drawing.add(Circle(donut_size / 2, donut_size / 2, radius * 0.62,
                                     fillColor=white, strokeWidth=0))
            donut_drawing.add(GString(donut_size / 2, donut_size / 2 - 1,
                                      ints(kpis['total']), fontName='Helvetica-Bold',
                                      fontSize=13, fillColor=HexColor(NAVY),
                                      textAnchor='middle'))
            donut_drawing.add(GString(donut_size / 2, donut_size / 2 - 9, 'transfers',
                                      fontName='Helvetica', fontSize=5,
                                      fillColor=HexColor(SLATE), textAnchor='middle'))

        legend_rows = []
        for row in status_rows:
            legend_rows.append([
                dot(COLOR_MAP.get(row['color'], BLUE)),
                Paragraph(row['label'], st_cell),
                Paragraph(ints(row['count']), st_cell_b),
                Paragraph(f"{row['pct']}%", st_cap_r),
            ])
        legend_tbl = Table(legend_rows, colWidths=[8, 52, 26, 24], hAlign='LEFT')
        legend_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 1),
            ('RIGHTPADDING', (0, 0), (-1, -1), 1),
            ('TOPPADDING', (0, 0), (-1, -1), 2.2),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2.2),
        ]))

        mini_gap = 3 * mm
        mini_w = (HALF_W - 16 - mini_gap) / 2
        mini_row = Table([[
            stat_tile('COMPLETION RATE', pct(kpis.get('completion_pct')),
                      f"{ints(kpis['completed'])} of {ints(kpis['total'])}", BRAND, mini_w),
            '',
            stat_tile('CANCELLATION', pct(kpis.get('cancel_pct')),
                      f"{ints(kpis['cancelled'])} cancelled", RED, mini_w),
        ]], colWidths=[mini_w, mini_gap, mini_w], hAlign='LEFT')
        mini_row.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))

        pipeline_content = []
        if donut_drawing:
            holder = Table([[donut_drawing]], colWidths=[HALF_W - 16], hAlign='CENTER')
            holder.setStyle(TableStyle([
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
            ]))
            pipeline_content += [holder, Spacer(1, 2 * mm)]
        pipeline_content += [legend_tbl, Spacer(1, 3 * mm),
                             HRFlowable(width='100%', thickness=0.5,
                                        color=HexColor(BORDER), spaceAfter=3),
                             mini_row]
        pipeline_card = card('Pipeline mix', 'Where every transfer sits today',
                             pipeline_content, HALF_W)

        quality_gap = 3 * mm
        quality_w = (HALF_W - 16 - quality_gap) / 2
        quality_tiles = [
            ('FILL RATE', pct(kpis.get('fill_rate_pct')),
             f"{ints(kpis['received_units'])} / {ints(kpis['sent_units'])} units",
             fill_color),
            ('ON-TIME DELIVERY', pct(on_time),
             'vs scheduled' if on_time is not None else 'no ETA set', on_time_color),
            ('TO APPROVE', hours(kpis.get('avg_approval_hours')),
             'request → dispatch', BLUE),
            ('IN TRANSIT', hours(kpis.get('avg_transit_hours')),
             'dispatch → receipt', INDIGO),
        ]
        quality_rows = []
        for i in range(0, 4, 2):
            quality_rows.append([
                stat_tile(*quality_tiles[i], quality_w),
                '',
                stat_tile(*quality_tiles[i + 1], quality_w),
            ])
        quality_grid = Table(quality_rows, colWidths=[quality_w, quality_gap, quality_w],
                             hAlign='LEFT')
        quality_grid.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))

        kv_rows = [
            ('Units moved', ints(kpis['units'])),
            ('Line items', ints(kpis['items'])),
            ('Sent units', ints(kpis['sent_units'])),
            ('Received units', ints(kpis['received_units'])),
            ('Variance (units)', ints(kpis['variance_units'])),
            ('Variance (value)', money(kpis['variance_value'])),
            ('Discrepancies', ints(kpis['discrepancy_count'])),
            ('Completed this month', ints(kpis['completed_this_month'])),
        ]
        kv_table = Table(
            [[Paragraph(label, st_cap), Paragraph(value, st_cell_r)]
             for label, value in kv_rows],
            colWidths=[(HALF_W - 16) * 0.58, (HALF_W - 16) * 0.42], hAlign='LEFT')
        kv_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 1.6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 1.6),
        ]))
        quality_card = card('Service quality', 'Accuracy, punctuality and speed',
                            [quality_grid, Spacer(1, 2 * mm),
                             HRFlowable(width='100%', thickness=0.5,
                                        color=HexColor(BORDER), spaceAfter=3),
                             kv_table], HALF_W)

        flow += [two_col(pipeline_card, quality_card), Spacer(1, 4 * mm)]

        # ── 6. Aging + priority ─────────────────────────────────────────
        aging_max = max([1] + [a['count'] for a in aging_rows])
        aging_inner = HALF_W - 16
        aging_label_w = 42
        aging_count_w = 18
        aging_value_w = 60
        aging_bar_w = aging_inner - aging_label_w - aging_count_w - aging_value_w - 10
        aging_rows_tbl = []
        for row in aging_rows:
            tone = (RED if row['label'] == '7+ days'
                    else AMBER if row['label'] == '3–7 days'
                    else BLUE if row['label'] == '1–3 days' else TEAL)
            aging_rows_tbl.append([
                Paragraph(str(row['label']), st_cell),
                bar(row['count'] / aging_max, tone, aging_bar_w),
                Paragraph(f"{ints(row['count'])}", st_cell_b),
                Paragraph(money(row['value']), st_cap_r),
            ])
        aging_table = Table(
            aging_rows_tbl,
            colWidths=[aging_label_w, aging_bar_w + 10, aging_count_w, aging_value_w],
            hAlign='LEFT')
        aging_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))
        stale_note = ('Nothing is aging — open transfers are all recent.'
                      if not stale else
                      f'{ints(stale)} transfer{"s" if stale != 1 else ""} have been '
                      f'open for 3+ days — worth chasing.')
        aging_card = card('Open transfer aging', 'Awaiting approval or still in transit',
                          [aging_table, Spacer(1, 2 * mm),
                           Paragraph(f'<font color="{RED if stale else GREEN}">'
                                     f'<b>{stale_note}</b></font>', st_cap)],
                          HALF_W)

        priority_max = max([1] + [p['count'] for p in priority_rows]) if priority_rows else 1
        priority_bar_w = HALF_W - 16 - 6
        priority_tbl_rows = []
        for row in priority_rows:
            label, tone = PRIORITY_META.get(row['priority'], ('Normal', BRAND))
            meta_bits = [f"{ints(row['units'])} unit"
                         f"{'' if row['units'] == 1 else 's'}",
                         f"cycle {hours(row.get('avg_cycle_hours'))}"]
            if row.get('on_time_pct') is not None:
                meta_bits.append(f"{pct(row['on_time_pct'])} on time")
            priority_tbl_rows.append([
                [chip(label, tone),
                 Paragraph(f"<b>{ints(row['count'])}</b> transfer"
                           f"{'' if row['count'] == 1 else 's'} · "
                           + ' · '.join(meta_bits) + f" · {money(row['value'])}", st_cap),
                 Spacer(1, 1.4 * mm),
                 bar(row['count'] / priority_max, tone, priority_bar_w, 4.2)],
            ])
        if priority_tbl_rows:
            priority_table = Table(priority_tbl_rows, colWidths=[HALF_W - 16], hAlign='LEFT')
            priority_table.setStyle(TableStyle([
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            priority_content = [priority_table]
        else:
            priority_content = [empty_note('No priority data recorded yet.')]
        priority_card = card('Priority performance', 'Volume and cycle time by urgency',
                             priority_content, HALF_W)

        flow += [two_col(aging_card, priority_card), Spacer(1, 4 * mm)]

        # ── 7. Busiest lanes + warehouse throughput ─────────────────────
        lanes_w = CONTENT_W * 0.6 - GAP / 2
        lane_rows = []
        for row in route_rows:
            lane_rows.append([
                [Paragraph(str(row['source']), st_cell_b),
                 Paragraph(f"→ {row['dest']}", st_cap)],
                Paragraph(ints(row['count']), st_cell_b),
                Paragraph(ints(row['units']), st_cell),
                Paragraph(money(row['value']), st_cell_r),
                Paragraph(hours(row.get('avg_transit_hours')), st_cap_r),
            ])
        if lane_rows:
            inner = lanes_w - 16
            lanes_table = data_table(
                ['LANE', 'TRANSFERS', 'UNITS', 'VALUE', 'TRANSIT'], lane_rows,
                [inner * 0.44, inner * 0.14, inner * 0.13, inner * 0.17, inner * 0.12],
                ['LEFT', 'RIGHT', 'RIGHT', 'RIGHT', 'RIGHT'])
            lanes_content = [lanes_table]
        else:
            lanes_content = [empty_note('No routes recorded in this window.')]
        lanes_card = card('Busiest lanes', 'Top warehouse-to-warehouse routes',
                          lanes_content, lanes_w)

        wh_w = CONTENT_W - lanes_w - GAP
        wh_inner = wh_w - 16
        wh_max = max([1] + [max(w['dispatched'], w['received']) for w in warehouse_rows]) \
            if warehouse_rows else 1
        wh_rows = []
        for row in warehouse_rows[:6]:
            wh_rows.append([[
                Paragraph(f"<b>{row['branch']}</b>", st_cell),
                Paragraph(f"{ints(row['total'])} moves", st_cap),
                Spacer(1, 1.4 * mm),
                Paragraph(f"Dispatched {ints(row['dispatched'])} · "
                          f"{money(row['dispatched_value'])}", st_cap),
                bar(row['dispatched'] / wh_max, BRAND, wh_inner - 2, 3.6),
                Spacer(1, 1.2 * mm),
                Paragraph(f"Received {ints(row['received'])} · "
                          f"{money(row['received_value'])}", st_cap),
                bar(row['received'] / wh_max, TEAL, wh_inner - 2, 3.6),
            ]])
        if wh_rows:
            wh_table = Table(wh_rows, colWidths=[wh_inner], hAlign='LEFT')
            wh_table.setStyle(TableStyle([
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            wh_content = [wh_table]
        else:
            wh_content = [empty_note('No warehouse activity recorded yet.')]
        wh_card = card('Warehouse throughput', 'Dispatched out vs. received in',
                       wh_content, wh_w)

        flow += [two_col(lanes_card, wh_card, lanes_w), Spacer(1, 4 * mm)]

        # ── 8. Top items + carrier performance ──────────────────────────
        item_inner = HALF_W - 16
        item_rows_tbl = []
        item_max = max([1] + [i['units'] for i in item_rows]) if item_rows else 1
        for idx, row in enumerate(item_rows[:8], 1):
            meta = f"{money(row['value'])} · {ints(row['transfers'])} line" \
                   f"{'' if row['transfers'] == 1 else 's'}"
            if row.get('variance'):
                meta += f" · {row['variance']:+d} variance"
            item_rows_tbl.append([
                Paragraph(f'<b>{idx}</b>', st_cap),
                [Paragraph(str(row['name'])[:46], st_cell_b),
                 Paragraph(meta, st_cap),
                 Spacer(1, 1.2 * mm),
                 bar(row['units'] / item_max, BRAND, item_inner - 14, 3.6)],
                Paragraph(f"<b>{ints(row['units'])}</b>", st_cell_r),
            ])
        if item_rows_tbl:
            items_table = Table(item_rows_tbl, colWidths=[10, item_inner - 48, 34],
                                hAlign='LEFT')
            items_table.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            items_content = [items_table]
        else:
            items_content = [empty_note('No item movement recorded in this window.')]
        items_card = card('Most transferred items', 'Ranked by units moved',
                          items_content, HALF_W)

        partner_rows_tbl = []
        for row in partner_rows[:8]:
            on_time_val = row.get('on_time_pct')
            partner_rows_tbl.append([
                Paragraph(str(row['name'])[:34], st_cell_b),
                Paragraph(ints(row['shipments']), st_cell_b),
                Paragraph(ints(row['units']), st_cell),
                Paragraph(hours(row.get('avg_transit_hours')), st_cap_r),
                chip(pct(on_time_val),
                     GREEN if (on_time_val or 0) >= 90 else
                     AMBER if (on_time_val or 0) >= 70 else RED)
                if on_time_val is not None else Paragraph('—', st_cap_r),
            ])
        if partner_rows_tbl:
            p_inner = HALF_W - 16
            partners_table = data_table(
                ['PARTNER', 'MOVES', 'UNITS', 'TRANSIT', 'ON TIME'], partner_rows_tbl,
                [p_inner * 0.4, p_inner * 0.14, p_inner * 0.16,
                 p_inner * 0.15, p_inner * 0.15],
                ['LEFT', 'RIGHT', 'RIGHT', 'RIGHT', 'CENTER'])
            partners_content = [partners_table]
        else:
            partners_content = [empty_note('No carrier or driver assignments recorded.')]
        partners_card = card('Carrier & driver performance', 'Who moves the stock, and how well',
                             partners_content, HALF_W)

        flow += [two_col(items_card, partners_card), Spacer(1, 4 * mm)]

        # ── 9. Receipt discrepancies ────────────────────────────────────
        disc_rows = []
        for row in discrepancy_rows[:10]:
            label, tone = PRIORITY_META.get(row.get('priority'), ('Normal', BRAND))
            disc_rows.append([
                Paragraph(str(row['reference']), st_cell_b),
                Paragraph(str(row['route'])[:56], st_cell),
                chip(label, tone),
                Paragraph(ints(row['units_sent']), st_cell_r),
                Paragraph(ints(row['units_received']), st_cell_r),
                Paragraph(f"<font color='{RED if row['variance_units'] < 0 else GREEN}'>"
                          f"<b>{row['variance_units']:+d}</b></font>", st_cell_r),
                Paragraph(money(row['variance_value']), st_cap_r),
                Paragraph(stamp(row.get('received_at')), st_cap),
            ])
        disc_inner = CONTENT_W - 16
        if disc_rows:
            disc_table = data_table(
                ['REFERENCE', 'ROUTE', 'PRIORITY', 'SENT', 'RECEIVED',
                 'VARIANCE', 'VALUE', 'RECEIVED AT'], disc_rows,
                [disc_inner * 0.12, disc_inner * 0.28, disc_inner * 0.1,
                 disc_inner * 0.08, disc_inner * 0.1, disc_inner * 0.1,
                 disc_inner * 0.11, disc_inner * 0.14],
                ['LEFT', 'LEFT', 'CENTER', 'RIGHT', 'RIGHT', 'RIGHT', 'RIGHT', 'LEFT'])
            disc_content = [disc_table]
        else:
            disc_content = [Paragraph(
                f'<font color="{GREEN}"><b>No discrepancies</b></font> — every completed '
                'receipt matched exactly what was dispatched.', st_cap)]
        disc_card = card('Receipt discrepancies',
                         'Short or over receipts recorded at destination',
                         disc_content, CONTENT_W)

        flow += [disc_card, Spacer(1, 3 * mm)]

        # ── 10. Metric definitions ──────────────────────────────────────
        definitions = [
            ('Transfers', 'Every stock transfer created in the reporting period, '
                          'regardless of status.'),
            ('Value at cost', 'Units moved multiplied by the item cost price.'),
            ('Fill rate', 'Units received divided by units dispatched on completed transfers.'),
            ('On-time delivery', 'Completed receipts landing on or before the '
                                 'scheduled delivery date.'),
            ('Cycle time', 'Hours from the request being raised to the goods being received.'),
            ('Approval time', 'Hours from request raised to approved and dispatched.'),
            ('Transit time', 'Hours from dispatch to receipt at the destination branch.'),
            ('Variance', 'Units received minus units dispatched ' '(negative = short receipt).'),
            ('Aging', 'Days an open requested or in-transit transfer has been waiting.'),
            ('Discrepancy', 'A completed receipt where received units differ from dispatched.'),
        ]
        def_gap = 8
        def_w = (CONTENT_W - 16 - def_gap) / 2
        def_rows = []
        for i in range(0, len(definitions), 2):
            pair = definitions[i:i + 2]
            row = []
            for j in range(2):
                if j < len(pair):
                    term, desc = pair[j]
                    row.append([Paragraph(term, st_cell_b), Paragraph(desc, st_cap)])
                else:
                    row.append('')
                if j == 0:
                    row.append('')
            def_rows.append(row)
        def_table = Table(def_rows, colWidths=[def_w, def_gap, def_w], hAlign='LEFT')
        def_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 2.5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3.5),
        ]))
        flow += [card('How these figures are calculated',
                      'Definitions used throughout this report',
                      [def_table], CONTENT_W),
                 Spacer(1, 3 * mm)]

        # ── 11. Footnote ────────────────────────────────────────────────
        scope_phrase = (f'over {period_label} scoped to {branch_label}'
                        if filters.get('date_from')
                        else f'across all time, scoped to {branch_label}')
        flow.append(Paragraph(
            f'Figures cover {ints(kpis["total"])} transfers {scope_phrase} and are '
            'computed live from transfer, line and batch records at the time of '
            'generation.', st_note))

        doc.build(flow, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        stamp_str = timezone.localtime(timezone.now()).strftime('%Y%m%d')
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={
                'Content-Disposition':
                    f'attachment; filename="transfer-analytics_{stamp_str}.pdf"',
            },
        )

    @action(detail=False, methods=['get'])
    def suggestions(self, request):
        """Cross-branch rebalancing suggestions.

        Scans every active branch's usable stock and proposes transfers that
        move supply from branches holding more than their fair share toward
        branches that are short. Fair share is weighted by real POS demand
        (units sold per branch in the lookback window), so the proposal reads
        "send it where it actually sells" instead of a blind equal split.

        Query params:
          ?cover_days=   target days of cover per branch (default 30)
          ?window=       sales lookback window in days (default 90)
          ?branch=       only return suggestions touching this branch
          ?expiry_days=  window for expiry-rescue suggestions (default 90)
          ?limit=        max suggestions (default 40, max 200)
        """
        return Response(self._suggestions_payload(request))

    def _suggestions_payload(self, request):
        """Build the rebalancing plan shared by the JSON endpoint and the PDF."""
        from collections import defaultdict
        from datetime import timedelta as _td

        def _int_param(name, default, lo, hi):
            try:
                value = int(request.query_params.get(name) or default)
            except (TypeError, ValueError):
                return default
            return max(lo, min(hi, value))

        cover_days = _int_param('cover_days', 30, 7, 180)
        window_days = _int_param('window', 90, 7, 730)
        expiry_days = _int_param('expiry_days', 90, 7, 365)
        limit = _int_param('limit', 40, 1, 200)
        focus_branch = request.query_params.get('branch')

        today = timezone.localdate()
        window_start = timezone.now() - _td(days=window_days)
        expiry_cutoff = today + _td(days=expiry_days)

        branches = list(Branch.objects.filter(is_active=True)
                        .order_by('-is_main', 'name'))
        branch_meta = {b.id: {'id': b.id, 'name': b.name, 'is_main': b.is_main}
                       for b in branches}
        branch_ids = set(branch_meta)
        if not branch_ids:
            return {
                'filters': {'cover_days': cover_days, 'window': window_days,
                            'expiry_days': expiry_days, 'branch': None},
                'scope': {'branches': [], 'items': 0, 'window_days': window_days,
                          'cover_days': cover_days},
                'score': {'overall': 100.0, 'grade': 'A', 'label': 'Balanced'},
                'summary': {}, 'branch_health': [], 'suggestions': [],
                'expiry_rescue': [], 'dead_stock': [], 'imbalances': [],
            }

        # ── Demand signal: units sold per (item, branch) in the window ──
        demand_by_item = defaultdict(dict)
        demand_available = True
        try:
            from pos.models import TransactionItem
            rows = (TransactionItem.objects
                    .filter(transaction__status='completed',
                            transaction__created_at__gte=window_start,
                            transaction__branch_id__isnull=False,
                            stock__isnull=False)
                    .values('stock__medication_name', 'transaction__branch_id')
                    .annotate(units=Sum('quantity')))
            for row in rows:
                key = (row['stock__medication_name'] or '').strip().lower()
                if not key:
                    continue
                demand_by_item[key][row['transaction__branch_id']] = \
                    demand_by_item[key].get(row['transaction__branch_id'], 0.0) \
                    + float(row['units'] or 0)
        except Exception as exc:  # POS may not be installed for this tenant
            demand_available = False
            logger.warning('Transfer suggestions: POS demand unavailable (%s)', exc)

        # ── Inventory snapshot across every branch ─────────────────────
        stocks = (MedicationStock.objects
                  .filter(is_active=True, branch_id__in=branch_ids)
                  .select_related('branch', 'category', 'unit')
                  .prefetch_related('batches'))

        items = {}
        for st in stocks:
            key = (st.medication_name or '').strip().lower()
            if not key:
                continue

            usable = 0
            expired = 0
            batch_rows = []
            for batch in st.batches.all():
                remaining = int(batch.quantity_remaining or 0)
                if remaining <= 0:
                    continue
                if batch.expiry_date and batch.expiry_date < today:
                    expired += remaining
                    continue
                usable += remaining
                days_left = ((batch.expiry_date - today).days
                             if batch.expiry_date else None)
                batch_rows.append({
                    'id': batch.id,
                    'batch_number': batch.batch_number,
                    'quantity': remaining,
                    'expiry_date': (batch.expiry_date.isoformat()
                                    if batch.expiry_date else None),
                    'days_to_expiry': days_left,
                })
            # FEFO — earliest expiry first, undated batches last.
            batch_rows.sort(key=lambda r: (r['days_to_expiry'] is None,
                                           r['days_to_expiry'] or 0))

            entry = items.setdefault(key, {
                'key': key,
                'name': st.medication_name,
                'category': st.category.name if st.category_id else '',
                'unit': (st.unit.name if st.unit_id else 'unit'),
                'cost': float(st.cost_price or 0),
                'price': float(st.selling_price or 0),
                'branches': {},
            })
            entry['branches'][st.branch_id] = {
                'stock_id': st.id,
                'branch_id': st.branch_id,
                'branch': st.branch.name,
                'qty': usable,
                'expired': expired,
                'committed': int(st.committed_qty or 0),
                'reorder_level': int(st.reorder_level or 0),
                'reorder_quantity': int(st.reorder_quantity or 0),
                'batches': batch_rows,
            }

        def pct_label(value, digits=0):
            return '—' if value is None else f'{float(value):.{digits}f}%'

        def cover_days_for(qty, velocity):
            if velocity and velocity > 0:
                return round(qty / velocity, 1)
            return None

        def best_demand_destination(item_key, exclude_bid):
            """Branch with the greatest demand for ``item_key`` (excluding one)."""
            rows = demand_by_item.get(item_key) or {}
            best_bid, best_units = None, 0.0
            for bid, units in rows.items():
                if bid == exclude_bid or bid not in branch_ids:
                    continue
                if units > best_units:
                    best_bid, best_units = bid, units
            return best_bid, best_units

        # ── Per-item network analysis ──────────────────────────────────
        suggestions = []
        imbalances = []
        branch_health = {
            bid: {'branch_id': bid, 'branch': branch_meta[bid]['name'],
                  'items': 0, 'units': 0, 'value': 0.0,
                  'below_reorder': 0, 'zero_stock': 0, 'overstocked': 0,
                  'deficit_units': 0, 'surplus_units': 0, 'expiring_units': 0,
                  'expired_units': 0, 'coverage_days': None}
            for bid in branch_ids
        }
        velocity_total_by_branch = defaultdict(float)
        units_total_by_branch = defaultdict(float)
        deviation_sum = 0.0
        ideal_sum = 0.0

        for item_key, item in items.items():
            per_branch = item['branches']
            demand_rows = demand_by_item.get(item_key) or {}

            total_qty = sum(v['qty'] for v in per_branch.values())
            velocities = {bid: units / window_days
                          for bid, units in demand_rows.items() if bid in branch_ids}

            candidate_bids = set(per_branch) | set(velocities)
            if not candidate_bids:
                continue

            total_velocity = sum(velocities.values())
            if total_velocity > 0:
                share = {b: (velocities.get(b, 0.0) / total_velocity)
                         for b in candidate_bids}
            else:
                share = {b: 1.0 / len(candidate_bids) for b in candidate_bids}

            target = {b: share[b] * total_qty for b in candidate_bids}
            # A branch also needs at least `cover_days` of its own demand, so a
            # busy branch is never drained just because the network average is
            # low. This is what makes the target "balanced" rather than merely
            # "proportional".
            fair_share = {b: max(target[b], velocities.get(b, 0.0) * cover_days)
                          for b in candidate_bids}
            deviation_sum += sum(abs(per_branch.get(b, {}).get('qty', 0) - fair_share[b])
                                 for b in candidate_bids)
            ideal_sum += sum(fair_share.values())

            needs, movables = {}, {}
            for bid in candidate_bids:
                row = per_branch.get(bid) or {}
                qty = float(row.get('qty', 0))
                reorder = float(row.get('reorder_level', 0) or 0)
                fair = fair_share[bid]
                velocity = velocities.get(bid, 0.0)

                need = max(0.0, fair - qty)
                if reorder and qty < reorder:
                    need = max(need, reorder - qty)
                if velocity <= 0 and reorder > 0:
                    # No sales history here, so a fair-share target would be a
                    # guess. Respect the branch's declared minimum instead and
                    # never ship more than it takes to clear its reorder level.
                    need = min(need, max(0.0, reorder - qty))
                if need >= 1:
                    needs[bid] = need

                # Never strip a branch below either its fair share or its own
                # reorder level — whichever it can actually afford.
                keep = max(fair, min(reorder, qty))
                movable = max(0.0, qty - keep)
                if movable >= 1:
                    movables[bid] = movable

            # ── Branch health rollup ───────────────────────────────────
            for bid, row in per_branch.items():
                h = branch_health[bid]
                h['items'] += 1
                h['units'] += row['qty']
                h['value'] += row['qty'] * item['cost']
                h['expired_units'] += row['expired']
                h['expiring_units'] += sum(
                    b['quantity'] for b in row['batches']
                    if b['days_to_expiry'] is not None
                    and 0 <= b['days_to_expiry'] <= expiry_days)
                if row['qty'] <= 0:
                    h['zero_stock'] += 1
                elif row['reorder_level'] and row['qty'] < row['reorder_level']:
                    h['below_reorder'] += 1
                if row['reorder_level'] and row['qty'] > row['reorder_level'] * 2:
                    h['overstocked'] += 1
                units_total_by_branch[bid] += row['qty']
                velocity_total_by_branch[bid] += velocities.get(bid, 0.0)

            for bid, need in needs.items():
                branch_health[bid]['deficit_units'] += int(round(need))
            for bid, movable in movables.items():
                branch_health[bid]['surplus_units'] += int(round(movable))

            if not needs or not movables:
                # Record the imbalance even when nothing can be moved yet.
                if needs:
                    imbalances.append({
                        'medication': item['name'],
                        'category': item['category'],
                        'total_qty': int(total_qty),
                        'branches': [{
                            'branch': (per_branch.get(b) or {}).get('branch')
                                      or branch_meta[b]['name'],
                            'qty': int((per_branch.get(b) or {}).get('qty', 0)),
                            'share_pct': round(share[b] * 100, 1),
                            'need': int(round(needs.get(b, 0))),
                            'surplus': 0,
                        } for b in sorted(needs)],
                        'blocked': 'No branch holds a movable surplus.',
                    })
                continue

            # ── Greedy pairing: biggest surplus → biggest need ─────────
            remaining = dict(movables)
            # Only branches that already carry a stock row can receive a
            # transfer line, so a branch that simply does not stock the item is
            # reported as an imbalance instead of a transfer.
            pending = {b: n for b, n in needs.items() if b in per_branch}
            for src in sorted(movables, key=lambda b: -movables[b]):
                while remaining.get(src, 0) >= 1:
                    dest = max((b for b in pending if b != src and pending[b] >= 1),
                               key=lambda b: pending[b], default=None)
                    if dest is None:
                        break
                    move = int(min(remaining[src], pending[dest]))
                    if move < 1:
                        break
                    remaining[src] -= move
                    pending[dest] -= move

                    src_row = per_branch[src]
                    dst_row = per_branch.get(dest) or {}
                    src_qty = int(src_row['qty'])
                    dst_qty = int(dst_row.get('qty', 0))
                    dst_reorder = int(dst_row.get('reorder_level', 0) or 0)
                    src_vel = velocities.get(src, 0.0)
                    dst_vel = velocities.get(dest, 0.0)

                    if dst_qty <= 0:
                        urgency = 'critical'
                        reason = 'Destination is out of stock'
                        detail = (f"{dst_row.get('branch') or branch_meta[dest]['name']} "
                                  f"holds none of this item while {src_row['branch']} "
                                  f"holds {src_qty}.")
                    elif dst_reorder and dst_qty < dst_reorder:
                        ratio = dst_qty / dst_reorder if dst_reorder else 0
                        urgency = 'high' if ratio < 0.5 or dst_vel > 0 else 'medium'
                        reason = 'Destination is below its reorder level'
                        detail = (f"{dst_row['branch']} holds {dst_qty} against a "
                                  f"reorder level of {dst_reorder}.")
                    else:
                        urgency = 'medium' if dst_vel > 0 else 'low'
                        reason = 'Rebalance toward demand share'
                        detail = (f"{dst_row['branch']} accounts for "
                                  f"{pct_label(share[dest] * 100)} of demand but only "
                                  f"holds {pct_label((dst_qty / total_qty * 100) if total_qty else 0)} "
                                  f"of the network stock.")

                    # FEFO source batch for the draft transfer.
                    src_batches = [b for b in src_row['batches'] if b['quantity'] > 0]
                    pick_batch = src_batches[0] if src_batches else None
                    expiring_pick = (pick_batch if pick_batch
                                     and pick_batch['days_to_expiry'] is not None
                                     and pick_batch['days_to_expiry'] <= expiry_days
                                     else None)

                    suggestions.append({
                        'kind': 'rebalance',
                        'medication': item['name'],
                        'category': item['category'],
                        'unit': item['unit'],
                        'source_stock_id': src_row['stock_id'],
                        'source_branch_id': src,
                        'source_branch': src_row['branch'],
                        'dest_stock_id': dst_row.get('stock_id'),
                        'dest_branch_id': dest,
                        'dest_branch': dst_row.get('branch') or branch_meta[dest]['name'],
                        'units': move,
                        'value': round(move * item['cost'], 2),
                        'urgency': urgency,
                        'reason': reason,
                        'detail': detail,
                        'source_qty': src_qty,
                        'dest_qty': dst_qty,
                        'dest_reorder': dst_reorder,
                        'demand_share_pct': round(share[dest] * 100, 1),
                        'velocity_per_day': round(dst_vel, 2),
                        'coverage_before': cover_days_for(dst_qty, dst_vel),
                        'coverage_after': cover_days_for(dst_qty + move, dst_vel),
                        'priority': {'critical': 'urgent', 'high': 'high',
                                     'medium': 'normal', 'low': 'low'}[urgency],
                        'batch_id': pick_batch['id'] if pick_batch else None,
                        'batch_number': pick_batch['batch_number'] if pick_batch else None,
                        'expiry_date': pick_batch['expiry_date'] if pick_batch else None,
                        'days_to_expiry': (pick_batch['days_to_expiry']
                                           if pick_batch else None),
                        'expiring': bool(expiring_pick),
                    })

            imbalances.append({
                'medication': item['name'],
                'category': item['category'],
                'total_qty': int(total_qty),
                'branches': sorted(({
                    'branch': (per_branch.get(bid) or {}).get('branch')
                              or branch_meta[bid]['name'],
                    'qty': int((per_branch.get(bid) or {}).get('qty', 0)),
                    'share_pct': round(share.get(bid, 0) * 100, 1),
                    'need': int(round(needs.get(bid, 0))),
                    'surplus': int(round(movables.get(bid, 0))),
                    'not_stocked': bid not in per_branch,
                } for bid in (set(per_branch) | set(needs))),
                    key=lambda r: (-r['qty'], r['branch'])),
            })

        # ── Expiry rescue: stock that will die where it currently sits ──
        expiry_rescue = []
        for item_key, item in items.items():
            for bid, row in item['branches'].items():
                velocity = (demand_by_item.get(item_key) or {}).get(bid, 0.0) / window_days
                for batch in row['batches']:
                    days_left = batch['days_to_expiry']
                    if days_left is None or days_left > expiry_days:
                        continue
                    consumable = velocity * max(1, days_left)
                    excess = batch['quantity'] - consumable
                    if excess < 1:
                        continue
                    dest, dest_units = best_demand_destination(item_key, bid)
                    if dest is None:
                        continue
                    move = int(min(excess, max(1, dest_units)))
                    expiry_rescue.append({
                        'medication': item['name'],
                        'source_stock_id': row['stock_id'],
                        'source_branch_id': bid,
                        'source_branch': row['branch'],
                        'dest_branch_id': dest,
                        'dest_branch': branch_meta[dest]['name'],
                        'batch_id': batch['id'],
                        'batch_number': batch['batch_number'],
                        'expiry_date': batch['expiry_date'],
                        'days_to_expiry': days_left,
                        'quantity': batch['quantity'],
                        'units': move,
                        'value': round(move * item['cost'], 2),
                        'local_velocity': round(velocity, 2),
                        'urgency': 'critical' if days_left <= 14 else 'high',
                    })
        expiry_rescue.sort(key=lambda r: (r['days_to_expiry'], -r['value']))

        # ── Dead stock: stock with no local movement at all ────────────
        dead_stock = []
        for item_key, item in items.items():
            demand_rows = demand_by_item.get(item_key) or {}
            if not demand_rows:
                continue
            for bid, row in item['branches'].items():
                if row['qty'] < 10:
                    continue
                if demand_rows.get(bid, 0.0) > 0:
                    continue
                dest, dest_units = best_demand_destination(item_key, bid)
                if dest is None:
                    continue
                dest_qty = (item['branches'].get(dest) or {}).get('qty', 0)
                dest_velocity = dest_units / window_days
                room = max(0, int(round(dest_velocity * cover_days)) - int(dest_qty))
                if room < 1:
                    continue
                move = int(min(row['qty'], room))
                dead_stock.append({
                    'medication': item['name'],
                    'source_stock_id': row['stock_id'],
                    'source_branch_id': bid,
                    'source_branch': row['branch'],
                    'dest_branch_id': dest,
                    'dest_branch': branch_meta[dest]['name'],
                    'units': move,
                    'held': row['qty'],
                    'value': round(move * item['cost'], 2),
                    'dest_velocity_per_day': round(dest_velocity, 2),
                    'urgency': 'high' if row['qty'] >= 50 else 'medium',
                })
        dead_stock.sort(key=lambda r: -r['value'])

        # ── Filtering / ordering ───────────────────────────────────────
        if focus_branch:
            suggestions = [s for s in suggestions
                           if str(s['source_branch_id']) == str(focus_branch)
                           or str(s['dest_branch_id']) == str(focus_branch)]

        SEVERITY_ORDER = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
        suggestions.sort(key=lambda s: (SEVERITY_ORDER.get(s['urgency'], 9),
                                        -s['value'], -s['units']))
        total_found = len(suggestions)
        suggestions = suggestions[:limit]
        for idx, sug in enumerate(suggestions, 1):
            sug['id'] = f'SUG-{idx:03d}'

        # ── Branch health scoring ──────────────────────────────────────
        for bid, h in branch_health.items():
            h['value'] = round(h['value'], 2)
            velocity = velocity_total_by_branch.get(bid, 0.0)
            h['demand_units'] = int(round(velocity * window_days))
            h['has_demand'] = velocity > 0
            raw_cover = (units_total_by_branch[bid] / velocity) if velocity > 0 else None
            h['coverage_days'] = (round(min(raw_cover, 3650), 1)
                                  if raw_cover is not None else None)
            h['coverage_capped'] = bool(raw_cover is not None and raw_cover > 3650)
            tracked = max(1, h['items'])
            penalty = ((h['below_reorder'] * 1.0 + h['zero_stock'] * 1.6
                        + h['overstocked'] * 0.6) / tracked) * 100
            h['score'] = round(max(0.0, min(100.0, 100 - penalty)), 1)
            h['status'] = ('healthy' if h['score'] >= 80
                           else 'watch' if h['score'] >= 55 else 'at_risk')

        branch_health_rows = sorted(branch_health.values(), key=lambda h: h['score'])

        # ── Network balance score ──────────────────────────────────────
        if ideal_sum > 0:
            balance = 100.0 * (1 - (deviation_sum / (2 * ideal_sum)))
        else:
            balance = 100.0
        balance = round(max(0.0, min(100.0, balance)), 1)
        if balance >= 90:
            grade, label = 'A', 'Balanced'
        elif balance >= 80:
            grade, label = 'B', 'Healthy'
        elif balance >= 70:
            grade, label = 'C', 'Drifting'
        elif balance >= 55:
            grade, label = 'D', 'Unbalanced'
        else:
            grade, label = 'F', 'Fragmented'

        totals = {
            'suggestions': len(suggestions),
            'found': total_found,
            'units': sum(s['units'] for s in suggestions),
            'value': round(sum(s['value'] for s in suggestions), 2),
            'critical': sum(1 for s in suggestions if s['urgency'] == 'critical'),
            'high': sum(1 for s in suggestions if s['urgency'] == 'high'),
            'medium': sum(1 for s in suggestions if s['urgency'] == 'medium'),
            'low': sum(1 for s in suggestions if s['urgency'] == 'low'),
            'items': len({s['medication'] for s in suggestions}),
            'lanes': len({(s['source_branch_id'], s['dest_branch_id'])
                          for s in suggestions}),
            'expiry_moves': len(expiry_rescue),
            'expiry_units': sum(r['units'] for r in expiry_rescue),
            'dead_stock_moves': len(dead_stock),
            'dead_stock_units': sum(r['units'] for r in dead_stock),
            'branches_scanned': len(branch_ids),
            'branches_with_demand': sum(1 for h in branch_health_rows if h['has_demand']),
            'branches_short': sum(1 for h in branch_health_rows if h['status'] != 'healthy'),
            'zero_stock_items': sum(h['zero_stock'] for h in branch_health_rows),
            'below_reorder_items': sum(h['below_reorder'] for h in branch_health_rows),
            'expired_units': sum(h['expired_units'] for h in branch_health_rows),
            'expiring_units': sum(h['expiring_units'] for h in branch_health_rows),
            'demand_signal': demand_available,
        }

        return {
            'filters': {
                'cover_days': cover_days,
                'window': window_days,
                'expiry_days': expiry_days,
                'branch': (int(focus_branch)
                           if focus_branch and str(focus_branch).isdigit() else None),
            },
            'scope': {
                'branches': [branch_meta[b] for b in branch_meta],
                'items': len(items),
                'window_days': window_days,
                'cover_days': cover_days,
            },
            'score': {'overall': balance, 'grade': grade, 'label': label},
            'summary': totals,
            'branch_health': branch_health_rows,
            'suggestions': suggestions,
            'expiry_rescue': expiry_rescue[:12],
            'dead_stock': dead_stock[:12],
            'imbalances': sorted(
                imbalances,
                key=lambda i: -sum(b['need'] for b in i['branches']),
            )[:15],
        }

    @action(detail=False, methods=['get'], url_path='suggestions-pdf')
    def suggestions_pdf(self, request):
        """Branded PDF of the cross-branch rebalancing suggestions."""
        import io as _io
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle)
        from reportlab.graphics.shapes import Drawing, Circle, Rect

        payload = self._suggestions_payload(request)
        score = payload['score']
        summ = payload['summary']
        scope = payload['scope']
        health_rows = payload['branch_health']
        suggestions = payload['suggestions']
        expiry_rows = payload['expiry_rescue']
        dead_rows = payload['dead_stock']
        imbalance_rows = payload['imbalances']
        filters = payload['filters']

        from config.pdf_branding import resolve_branding

        logo_path, business_name = None, ''
        try:
            logo_path, business_name = resolve_branding(request)
        except (ImportError, NotImplementedError, OSError, ValueError,
                AttributeError) as exc:
            logger.warning('Suggestions PDF: branding unavailable (%s)', exc)
        tenant = getattr(request, 'tenant', None)
        business_name = (business_name or getattr(tenant, 'name', '') or 'AdhereMed')

        branch_label = 'All branches'
        if filters.get('branch'):
            try:
                obj = Branch.objects.filter(id=filters['branch']).first()
                branch_label = obj.name if obj else f"Branch #{filters['branch']}"
            except Exception:
                branch_label = f"Branch #{filters['branch']}"

        # ── Palette (live from the tenant) ──────────────────────────────
        NAVY = '#0F172A'
        SLATE = '#64748B'
        BORDER = '#E2E8F0'
        GREEN = '#16A34A'
        RED = '#DC2626'
        AMBER = '#F59E0B'
        BLUE = '#3B82F6'
        GREY = '#94A3B8'
        TEAL = '#14B8A6'

        def _brand_hex(attr, default):
            raw = getattr(tenant, attr, '') if tenant else ''
            if isinstance(raw, str) and len(raw.strip()) == 7 and raw.strip().startswith('#'):
                try:
                    int(raw.strip()[1:], 16)
                    return '#' + raw.strip()[1:].upper()
                except ValueError:
                    pass
            return default

        BRAND = _brand_hex('brand_primary', '#2F6DFF')
        DEEP = _brand_hex('brand_secondary', '#143CE1')
        ACCENT_SRC = _brand_hex('brand_accent', '#37D6FF')

        def _rgb(hex_color):
            h = str(hex_color).lstrip('#')
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

        def blend(a_hex, b_hex, amount):
            a, b = _rgb(a_hex), _rgb(b_hex)
            t = min(max(amount, 0.0), 1.0)
            return '#%02X%02X%02X' % tuple(round(a[i] + (b[i] - a[i]) * t)
                                           for i in range(3))

        ACCENT = blend(ACCENT_SRC, BRAND, 0.55)

        def _grad_at(t):
            stops = ((0.0, _rgb(DEEP)), (0.52, _rgb(BRAND)), (1.0, _rgb(ACCENT)))
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t <= t1:
                    f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                    return tuple(c0[k] + (c1[k] - c0[k]) * f for k in range(3))
            return stops[-1][1]

        URGENCY_COLOR = {'critical': RED, 'high': '#EA580C',
                         'medium': AMBER, 'low': BLUE}
        STATUS_COLOR = {'healthy': GREEN, 'watch': AMBER, 'at_risk': RED}

        def money(v):
            try:
                return f'KES {float(v or 0):,.0f}'
            except (TypeError, ValueError):
                return 'KES 0'

        def ints(v):
            try:
                return f'{int(v or 0):,}'
            except (TypeError, ValueError):
                return '0'

        def cover_txt(days, capped=False):
            if days is None:
                return '—'
            if capped or days > 3650:
                return '>10y'
            d = float(days)
            if d < 1:
                return '<1d'
            if d < 60:
                return f'{d:.1f}d'.replace('.0d', 'd')
            if d < 365:
                return f'{round(d / 30)}mo'
            return '>1y'

        # ── Styles ──────────────────────────────────────────────────────
        st_card_title = ParagraphStyle('ct', fontName='Helvetica-Bold', fontSize=9.5,
                                       textColor=HexColor(NAVY), leading=12)
        st_card_sub = ParagraphStyle('cs', fontName='Helvetica', fontSize=6.5,
                                     textColor=HexColor(SLATE), leading=8.5)
        st_cap = ParagraphStyle('cap', fontName='Helvetica', fontSize=6,
                                textColor=HexColor(SLATE), leading=8)
        st_cap_r = ParagraphStyle('capr', parent=st_cap, alignment=TA_RIGHT)
        st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=7,
                                 textColor=HexColor(NAVY), leading=9)
        st_cell_b = ParagraphStyle('cellb', parent=st_cell, fontName='Helvetica-Bold')
        st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
        st_colhead = ParagraphStyle('ch', fontName='Helvetica-Bold', fontSize=6,
                                    textColor=HexColor(SLATE), leading=8)
        st_colhead_r = ParagraphStyle('chr', parent=st_colhead, alignment=TA_RIGHT)
        st_colhead_c = ParagraphStyle('chc', parent=st_colhead, alignment=TA_CENTER)
        st_scope_label = ParagraphStyle('sl', fontName='Helvetica-Bold', fontSize=5.6,
                                        textColor=HexColor(SLATE), leading=7.5)
        st_scope_value = ParagraphStyle('sv', fontName='Helvetica-Bold', fontSize=8,
                                        textColor=HexColor(NAVY), leading=10.5)
        st_note = ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=6.5,
                                 textColor=HexColor(SLATE), leading=9)
        st_body = ParagraphStyle('body', fontName='Helvetica', fontSize=7.2,
                                 textColor=HexColor(NAVY), leading=10.5)

        def chip(text, color_hex, size=5.6):
            style = ParagraphStyle(
                f'chp{size}', fontName='Helvetica-Bold', fontSize=size,
                leading=size + 2.2, alignment=TA_CENTER,
                textColor=HexColor(blend(color_hex, '#000000', 0.25)),
                backColor=HexColor(blend(color_hex, '#FFFFFF', 0.84)),
                borderPadding=1.7,
            )
            return Paragraph(str(text), style)

        def dot(color_hex, size=5.4):
            d = Drawing(size, size)
            d.add(Circle(size / 2, size / 2, size / 2,
                         fillColor=HexColor(color_hex), strokeWidth=0))
            return d

        # ── Geometry / furniture ────────────────────────────────────────
        W, H = landscape(A4)
        MARGIN = 14 * mm
        CONTENT_W = W - 2 * MARGIN
        GAP = 5 * mm
        HALF_W = (CONTENT_W - GAP) / 2

        period_label = f'Last {filters.get("window", 90)} days of demand'

        def _has_logo():
            return bool(logo_path) and os.path.exists(logo_path)

        def _draw_trailing_logo(canv, band_bottom, band_h, box, pad=1.5 * mm):
            if not _has_logo():
                return 0.0
            tile = box + 2 * pad
            x = W - MARGIN - 5 * mm - tile
            y = band_bottom + (band_h - tile) / 2
            canv.saveState()
            canv.setFillColor(white)
            canv.roundRect(x, y, tile, tile, 2.2 * mm, stroke=0, fill=1)
            try:
                canv.drawImage(logo_path, x + pad, y + pad, box, box,
                               preserveAspectRatio=True, anchor='c', mask='auto')
            except (OSError, ValueError, TypeError):
                canv.restoreState()
                return 0.0
            canv.restoreState()
            return tile

        def _page(canv, doc):
            canv.saveState()
            page_no = canv.getPageNumber()
            right_edge = W - MARGIN - 5 * mm
            left_x = MARGIN + 5 * mm
            if page_no == 1:
                band_bottom = H - 34 * mm
                band_h = 24 * mm
                canv.saveState()
                path = canv.beginPath()
                path.roundRect(MARGIN, band_bottom, CONTENT_W, band_h, 3 * mm)
                canv.clipPath(path, stroke=0, fill=0)
                steps = 150
                slice_w = CONTENT_W / steps
                for i in range(steps):
                    r, g, b = _grad_at(i / (steps - 1))
                    canv.setFillColorRGB(r / 255, g / 255, b / 255)
                    canv.rect(MARGIN + i * slice_w, band_bottom,
                              slice_w + 0.8, band_h, stroke=0, fill=1)
                canv.restoreState()

                tile = _draw_trailing_logo(canv, band_bottom, band_h, 15 * mm)
                text_right = right_edge - (tile + 6 * mm if tile else 0)

                canv.setFillColor(white)
                canv.setFont('Helvetica-Bold', 5.8)
                canv.drawString(left_x, H - 15.6 * mm,
                                'INVENTORY · LOGISTICS · SUGGESTIONS', charSpace=1.1)
                canv.setFont('Helvetica-Bold', 16)
                canv.drawString(left_x, H - 22.4 * mm, 'Transfer Suggestions')
                canv.setFont('Helvetica', 7)
                canv.drawString(left_x, H - 27.4 * mm,
                                'Every branch scanned against its own demand — where to move '
                                'stock to balance the network')

                canv.setFont('Helvetica-Bold', 9.5)
                canv.drawRightString(text_right, H - 16.4 * mm, business_name[:52])
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 21.2 * mm, period_label)
                canv.drawRightString(text_right, H - 25 * mm, f'Scope: {branch_label}')
                canv.drawRightString(text_right, H - 28.8 * mm,
                                     'Generated ' + timezone.localtime(timezone.now())
                                     .strftime('%b %d %Y, %I:%M %p'))
            else:
                band_bottom = H - 27 * mm
                band_h = 17 * mm
                canv.setFillColor(HexColor('#F6F8FC'))
                canv.rect(MARGIN, band_bottom, CONTENT_W, band_h, stroke=0, fill=1)
                canv.setFillColor(HexColor(BRAND))
                canv.rect(MARGIN, band_bottom, 2.6 * mm, band_h, stroke=0, fill=1)
                tile = _draw_trailing_logo(canv, band_bottom, band_h, 11 * mm,
                                           pad=1.2 * mm)
                text_right = right_edge - (tile + 5 * mm if tile else 0)
                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 10)
                canv.drawString(left_x, H - 17.6 * mm, 'Transfer Suggestions')
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawString(left_x, H - 22.6 * mm,
                                f'{business_name} · {branch_label} · {period_label}')
                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 7)
                canv.drawRightString(text_right, H - 18 * mm, business_name[:52])
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 23 * mm,
                                     'Rebalancing plan · continued')

            canv.setStrokeColor(HexColor(BORDER))
            canv.setLineWidth(0.6)
            canv.line(MARGIN, 12 * mm, W - MARGIN, 12 * mm)
            canv.setFillColor(HexColor(SLATE))
            canv.setFont('Helvetica', 6.8)
            canv.drawString(MARGIN, 7.6 * mm,
                            f'{business_name} · Transfer Suggestions')
            canv.setFont('Helvetica-Bold', 6.8)
            canv.setFillColor(HexColor(BRAND))
            canv.drawCentredString(W / 2, 7.6 * mm,
                                   'Powered by AdhereMed · www.adheremed.co')
            canv.setFont('Helvetica', 6.8)
            canv.setFillColor(HexColor(SLATE))
            canv.drawRightString(W - MARGIN, 7.6 * mm, f'Page {page_no}')
            canv.restoreState()

        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=landscape(A4),
            leftMargin=MARGIN, rightMargin=MARGIN,
            topMargin=34 * mm, bottomMargin=16 * mm,
            title='Transfer Suggestions', author=business_name,
            subject='Cross-branch stock rebalancing',
        )
        flow = [Spacer(1, 1 * mm)]

        def card(title, subtitle, content, width):
            rows = [[Paragraph(title, st_card_title)]]
            if subtitle:
                rows.append([Paragraph(subtitle, st_card_sub)])
            rows += [[item] for item in content]
            tbl = Table(rows, colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 1.5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5),
                ('TOPPADDING', (0, 0), (0, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 0 if subtitle else 4),
                ('BOTTOMPADDING', (0, -1), (-1, -1), 7),
            ]))
            return tbl

        def data_table(header, rows, widths, aligns=None):
            aligns = aligns or ['LEFT'] * len(header)
            head = []
            for i, label in enumerate(header):
                style = (st_colhead_r if aligns[i] == 'RIGHT'
                         else st_colhead_c if aligns[i] == 'CENTER' else st_colhead)
                head.append(Paragraph(label, style))
            tbl = Table([head] + rows, colWidths=widths, hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.7, HexColor(BORDER)),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 3),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            return tbl

        def stat_tile(label, value, sub, color_hex, width):
            value_style = ParagraphStyle('sv2', fontName='Helvetica-Bold', fontSize=12.5,
                                         textColor=HexColor(blend(color_hex, '#000000', 0.15)),
                                         leading=15)
            body = [Paragraph(value, value_style),
                    Paragraph(label, st_scope_label),
                    Paragraph(sub, st_cap)]
            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(blend(color_hex, '#FFFFFF', 0.62))),
                ('BACKGROUND', (0, 0), (-1, -1), HexColor(blend(color_hex, '#FFFFFF', 0.9))),
                ('LEFTPADDING', (0, 0), (-1, -1), 7),
                ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return tbl

        # ── 1. Scope bar ────────────────────────────────────────────────
        def scope_cell(label, value):
            return [Paragraph(label, st_scope_label), Paragraph(value, st_scope_value)]

        scope_tbl = Table([[
            scope_cell('SALES WINDOW', f'Last {filters.get("window")} days'),
            scope_cell('BALANCE TARGET', f'{filters.get("cover_days")} days cover'),
            scope_cell('BRANCHES', str(len(scope.get('branches') or []))),
            scope_cell('ITEMS TRACKED', ints(scope.get('items'))),
        ]], colWidths=[CONTENT_W / 4] * 4, hAlign='LEFT')
        scope_tbl.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), HexColor('#F6F8FC')),
            ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ]))
        flow += [scope_tbl, Spacer(1, 4 * mm)]

        # ── 2. Headline tiles ───────────────────────────────────────────
        tile_gap = 4.4 * mm
        tile_w = (CONTENT_W - 3 * tile_gap) / 4
        score_color = (GREEN if score.get('overall', 0) >= 80
                       else AMBER if score.get('overall', 0) >= 55 else RED)
        tiles = [
            stat_tile('NETWORK BALANCE', f"{score.get('overall')}/100",
                      f"Grade {score.get('grade')} · {score.get('label')}",
                      score_color, tile_w),
            stat_tile('SUGGESTIONS', ints(summ.get('suggestions')),
                      f"{ints(summ.get('items'))} items · {ints(summ.get('lanes'))} lanes",
                      BRAND, tile_w),
            stat_tile('UNITS TO MOVE', ints(summ.get('units')),
                      money(summ.get('value')) + ' at cost', TEAL, tile_w),
            stat_tile('URGENCY', f"{ints(summ.get('critical'))} / {ints(summ.get('high'))}",
                      'critical / high priority moves',
                      RED if summ.get('critical') else AMBER, tile_w),
        ]
        row_items, row_widths = [], []
        for idx, tile in enumerate(tiles):
            row_items.append(tile)
            row_widths.append(tile_w)
            if idx < len(tiles) - 1:
                row_items.append('')
                row_widths.append(tile_gap)
        strip = Table([row_items], colWidths=row_widths, hAlign='LEFT')
        strip.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        flow += [strip, Spacer(1, 4 * mm)]

        # ── 3. Executive read-out ───────────────────────────────────────
        bits = [
            f"<b>{ints(summ.get('suggestions'))} transfer"
            f"{'' if summ.get('suggestions') == 1 else 's'}</b> would move "
            f"<b>{ints(summ.get('units'))} units</b> worth "
            f"<b>{money(summ.get('value'))}</b> across "
            f"<b>{ints(summ.get('lanes'))} lane"
            f"{'' if summ.get('lanes') == 1 else 's'}</b>."
        ]
        if summ.get('zero_stock_items'):
            bits.append(f"{ints(summ.get('zero_stock_items'))} item/branch pairs are "
                        f"completely out of stock and {ints(summ.get('below_reorder_items'))} "
                        f"sit below their reorder level.")
        if summ.get('expiring_units'):
            bits.append(f"{ints(summ.get('expiring_units'))} units expire within "
                        f"{filters.get('expiry_days')} days and "
                        f"{ints(summ.get('expired_units'))} units have already lapsed.")
        if summ.get('dead_stock_moves'):
            bits.append(f"{ints(summ.get('dead_stock_moves'))} dormant stock moves are "
                        f"flagged where the item sells elsewhere but not locally.")
        if summ.get('branches_with_demand', 0) < summ.get('branches_scanned', 0):
            bits.append(f"Only {ints(summ.get('branches_with_demand'))} of "
                        f"{ints(summ.get('branches_scanned'))} branches have sales "
                        f"history; the rest are topped up to their declared reorder levels.")
        flow += [card('Executive summary', 'What this scan found across the network',
                      [Paragraph(' '.join(bits), st_body)], CONTENT_W),
                 Spacer(1, 4 * mm)]

        # ── 4. Branch health ────────────────────────────────────────────
        health_pdf_rows = []
        for h in health_rows:
            health_pdf_rows.append([
                [Paragraph(str(h['branch']), st_cell_b),
                 Paragraph(f"{ints(h['items'])} items · {ints(h['units'])} units", st_cap)],
                chip(str(h.get('status', 'watch')).replace('_', ' ').title(),
                     STATUS_COLOR.get(h.get('status'), AMBER)),
                Paragraph(f"<b>{h['score']}</b>", st_cell_r),
                Paragraph(cover_txt(h.get('coverage_days'), h.get('coverage_capped')),
                          st_cell_r),
                Paragraph(ints(h.get('below_reorder')), st_cell_r),
                Paragraph(ints(h.get('zero_stock')), st_cell_r),
                Paragraph(ints(h.get('overstocked')), st_cell_r),
                Paragraph(ints(h.get('expiring_units')), st_cell_r),
                Paragraph(money(h.get('value')), st_cap_r),
            ])
        if health_pdf_rows:
            inner = CONTENT_W - 16
            health_tbl = data_table(
                ['BRANCH', 'STATUS', 'SCORE', 'COVER', 'BELOW REORDER',
                 'OUT OF STOCK', 'OVERSTOCKED', 'EXPIRING', 'VALUE'],
                health_pdf_rows,
                [inner * 0.24, inner * 0.11, inner * 0.08, inner * 0.09,
                 inner * 0.11, inner * 0.1, inner * 0.1, inner * 0.08, inner * 0.09],
                ['LEFT', 'CENTER', 'RIGHT', 'RIGHT', 'RIGHT', 'RIGHT', 'RIGHT',
                 'RIGHT', 'RIGHT'])
            flow += [card('Branch health', 'Weakest branch first', [health_tbl],
                          CONTENT_W),
                     Spacer(1, 4 * mm)]

        # ── 5. Suggestions ──────────────────────────────────────────────
        sug_rows = []
        for idx, s in enumerate(suggestions, 1):
            sug_rows.append([
                Paragraph(str(idx), st_cap),
                [Paragraph(str(s['medication']), st_cell_b),
                 Paragraph(f"{s.get('category') or 'Uncategorised'} · {s.get('unit')}",
                           st_cap)],
                [Paragraph(f"{s['source_branch']} → {s['dest_branch']}", st_cell),
                 Paragraph(str(s['reason']), st_cap)],
                Paragraph(f"<b>{ints(s['units'])}</b>", st_cell_r),
                Paragraph(money(s['value']), st_cap_r),
                chip(str(s['urgency']).title(),
                     URGENCY_COLOR.get(s['urgency'], BLUE)),
                Paragraph(f"{ints(s['source_qty'])} / {ints(s['dest_qty'])}", st_cap_r),
                Paragraph(cover_txt(s.get('coverage_after')), st_cap_r),
                Paragraph(str(s.get('batch_number') or '—'), st_cap),
            ])
        if sug_rows:
            inner = CONTENT_W - 16
            sug_tbl = data_table(
                ['#', 'ITEM', 'LANE & REASON', 'UNITS', 'VALUE', 'URGENCY',
                 'FROM / TO', 'COVER AFTER', 'FEFO BATCH'],
                sug_rows,
                [inner * 0.03, inner * 0.2, inner * 0.25, inner * 0.07,
                 inner * 0.09, inner * 0.08, inner * 0.11, inner * 0.08,
                 inner * 0.09],
                ['LEFT', 'LEFT', 'LEFT', 'RIGHT', 'RIGHT', 'CENTER', 'RIGHT',
                 'RIGHT', 'LEFT'])
            flow += [card('Recommended transfers',
                          'Ranked by urgency, then by the value it unlocks',
                          [sug_tbl], CONTENT_W),
                     Spacer(1, 4 * mm)]
        else:
            flow += [card('Recommended transfers', 'Nothing to move',
                          [Paragraph('Every branch is already holding stock in line '
                                     'with its demand.', st_note)], CONTENT_W),
                     Spacer(1, 4 * mm)]

        # ── 6. Expiry rescue + dead stock ───────────────────────────────
        def mini_table(rows, columns, widths, aligns):
            return data_table(columns, rows, widths, aligns)

        expiry_pdf = []
        for r in expiry_rows:
            expiry_pdf.append([
                [Paragraph(str(r['medication']), st_cell_b),
                 Paragraph(f"{r['source_branch']} → {r['dest_branch']}", st_cap)],
                Paragraph(str(r['batch_number']), st_cap),
                Paragraph(f"<b>{ints(r['units'])}</b>", st_cell_r),
                Paragraph(f"{r['days_to_expiry']}d", st_cap_r),
            ])
        dead_pdf = []
        for r in dead_rows:
            dead_pdf.append([
                [Paragraph(str(r['medication']), st_cell_b),
                 Paragraph(f"{r['source_branch']} → {r['dest_branch']}", st_cap)],
                Paragraph(ints(r['held']), st_cap_r),
                Paragraph(f"<b>{ints(r['units'])}</b>", st_cell_r),
                Paragraph(money(r['value']), st_cap_r),
            ])

        side_gap = 5 * mm
        lw = (CONTENT_W - side_gap) / 2
        lwin = lw - 16

        left_card = card(
            'Expiry rescue',
            'Short-dated batches this branch cannot sell in time',
            [mini_table(expiry_pdf, ['ITEM', 'BATCH', 'MOVE', 'LEFT'],
                        [lwin * 0.46, lwin * 0.24, lwin * 0.16, lwin * 0.14],
                        ['LEFT', 'LEFT', 'RIGHT', 'RIGHT'])]
            if expiry_pdf else
            [Paragraph('Nothing short-dated in the pipeline.', st_note)],
            lw)
        right_card = card(
            'Dead stock',
            'Held here, selling there',
            [mini_table(dead_pdf, ['ITEM', 'HELD', 'MOVE', 'VALUE'],
                        [lwin * 0.5, lwin * 0.16, lwin * 0.16, lwin * 0.18],
                        ['LEFT', 'RIGHT', 'RIGHT', 'RIGHT'])]
            if dead_pdf else
            [Paragraph('No dormant stock in this window.', st_note)],
            lw)

        pair = Table([[left_card, '', right_card]],
                     colWidths=[lw, side_gap, lw], hAlign='LEFT')
        pair.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        flow += [pair, Spacer(1, 4 * mm)]

        # ── 7. Imbalance matrix ─────────────────────────────────────────
        imb_rows = []
        for item in imbalance_rows[:12]:
            spread = ' · '.join(
                f"{b['branch']}: {ints(b['qty'])}"
                for b in item['branches'][:4])
            imb_rows.append([
                [Paragraph(str(item['medication']), st_cell_b),
                 Paragraph(str(item.get('category') or ''), st_cap)],
                Paragraph(spread, st_cap),
                Paragraph(ints(item['total_qty']), st_cell_r),
                Paragraph(ints(sum(b['need'] for b in item['branches'])), st_cell_r),
                Paragraph(ints(sum(b['surplus'] for b in item['branches'])), st_cell_r),
            ])
        if imb_rows:
            inner = CONTENT_W - 16
            flow += [card('Where the imbalance sits',
                          'Stock spread per item versus demand',
                          [data_table(['ITEM', 'BRANCH SPREAD', 'TOTAL', 'NEEDED', 'SPARE'],
                                      imb_rows,
                                      [inner * 0.26, inner * 0.44, inner * 0.1,
                                       inner * 0.1, inner * 0.1],
                                      ['LEFT', 'LEFT', 'RIGHT', 'RIGHT', 'RIGHT'])],
                          CONTENT_W),
                     Spacer(1, 3 * mm)]

        flow.append(Paragraph(
            f"Fair share blends each branch's share of demand over the last "
            f"{filters.get('window')} days with {filters.get('cover_days')} days of "
            f"cover and its own reorder level. Expired batches are excluded from every "
            f"calculation. Scanned {len(scope.get('branches') or [])} active branches "
            f"covering {ints(scope.get('items'))} stock items.", st_note))

        doc.build(flow, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        stamp_str = timezone.localtime(timezone.now()).strftime('%Y%m%d')
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={
                'Content-Disposition':
                    f'attachment; filename="transfer-suggestions_{stamp_str}.pdf"',
            },
        )

    @action(detail=False, methods=['get'])
    def optimization(self, request):
        """Optimisation plan for the stock-transfer network.

        Turns the raw transfer history into a ranked, actionable backlog:
        a weighted health score, stage bottlenecks, and a set of scored
        recommendations (severity × impact × ease) covering approval lag,
        aging, carrier assignment, receipt accuracy, lane imbalance,
        consolidation, priority discipline, expiry risk and value
        concentration.

        Accepts the same filters as :meth:`analytics` so the page and the
        dashboard never disagree about the scope.
        """
        return Response(self._optimization_payload(request))

    def _optimization_payload(self, request):
        """Build the optimization plan shared by the JSON endpoint and the PDF."""
        from collections import defaultdict
        from datetime import date as _date
        from datetime import timedelta as _td

        def _parse_date(value):
            try:
                return _date.fromisoformat(str(value))
            except (TypeError, ValueError):
                return None

        def clamp(value, lo=0.0, hi=100.0):
            return max(lo, min(hi, value))

        def pct_label(value, digits=1):
            return '—' if value is None else f'{float(value):.{digits}f}%'

        def avg(values, nd=1):
            return round(sum(values) / len(values), nd) if values else None

        def hours_between(a, b):
            if not a or not b:
                return None
            delta = (b - a).total_seconds() / 3600
            return delta if delta >= 0 else None

        def line_value(line):
            try:
                return float(line.stock.cost_price or 0) * (line.quantity or 0)
            except Exception:
                return 0.0

        # ── Baseline (shared with the analytics dashboard) ──────────────
        base = self._analytics_payload(request)
        kpis = base['kpis']
        filters = base['filters']

        # ── Entity set (same scope, richer prefetch) ────────────────────
        qs = StockTransfer.objects.select_related(
            'source_branch', 'dest_branch', 'assigned_driver',
            'assigned_carrier', 'assigned_vehicle',
            'requested_by', 'approved_by', 'received_by',
        ).prefetch_related('lines__stock', 'lines__batch')

        branch_id = request.query_params.get('branch')
        if branch_id:
            qs = qs.filter(Q(source_branch_id=branch_id) | Q(dest_branch_id=branch_id))
        date_from = _parse_date(request.query_params.get('date_from'))
        date_to = _parse_date(request.query_params.get('date_to'))
        if date_from:
            qs = qs.filter(requested_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(requested_at__date__lte=date_to)

        transfers = list(qs.order_by('requested_at'))
        now = timezone.now()
        today = timezone.localdate()

        OPEN = ('draft', 'requested', 'approved', 'in_transit')

        # Per-transfer rollups, computed once and reused by every rule.
        rows = []
        for t in transfers:
            lines = list(t.lines.all())
            units = sum(l.quantity or 0 for l in lines)
            value = sum(line_value(l) for l in lines)
            received = sum(l.quantity_received or 0 for l in lines)
            variance = received - units
            rows.append({
                'id': t.id,
                'reference': t.reference,
                'status': t.status,
                'priority': t.priority or 'normal',
                'source': t.source_branch.name,
                'dest': t.dest_branch.name,
                'lane': f'{t.source_branch.name} → {t.dest_branch.name}',
                'units': units,
                'value': value,
                'received': received,
                'variance': variance,
                'lines': len(lines),
                'requested_at': t.requested_at,
                'shipped_at': t.shipped_at,
                'received_at': t.received_at,
                'scheduled_delivery': t.scheduled_delivery,
                'has_carrier': bool(t.assigned_carrier_id or t.assigned_driver_id),
                'has_vehicle': bool(t.assigned_vehicle_id or (t.assigned_vehicle_note or '').strip()),
                'has_signature': bool((t.approved_signature or '') and (t.received_signature or '')),
                'approval_h': hours_between(t.requested_at, t.shipped_at),
                'transit_h': hours_between(t.shipped_at, t.received_at),
                'cycle_h': hours_between(t.requested_at, t.received_at),
                'age_days': ((now - t.requested_at).total_seconds() / 86400
                             if t.requested_at else 0.0),
                'carrier': (t.assigned_carrier.name if t.assigned_carrier_id else
                            (t.assigned_driver.full_name if t.assigned_driver_id else '')),
                'batches': [l.batch for l in lines if l.batch_id],
            })

        completed = [r for r in rows if r['status'] == 'completed']
        open_rows = [r for r in rows if r['status'] in OPEN]
        total = len(rows)

        # Aggregate durations for the funnel.
        approval_hours = [r['approval_h'] for r in rows if r['approval_h'] is not None]
        transit_hours = [r['transit_h'] for r in rows if r['transit_h'] is not None]
        cycle_hours = [r['cycle_h'] for r in rows if r['cycle_h'] is not None]

        # ═══════════════════ HEALTH SCORE ══════════════════════════════
        APPROVAL_TARGET_H = 6.0
        TRANSIT_TARGET_H = 30.0
        CYCLE_TARGET_H = 48.0

        avg_approval = avg(approval_hours) or 0.0
        avg_transit = avg(transit_hours) or 0.0
        avg_cycle = avg(cycle_hours) or 0.0

        def speed_score(hours_val, target):
            """100 at ≤ target, 0 at ≥ 5× target."""
            if hours_val <= 0:
                return 100.0
            return clamp(100.0 * (5 * target - hours_val) / (4 * target))

        speed = round(speed_score(avg_cycle, CYCLE_TARGET_H), 1)

        fill = kpis.get('fill_rate_pct')
        accuracy = round(clamp(fill if fill is not None else 100.0), 1)

        # Reliability: on-time where an ETA exists, else completion rate.
        eta_rows = [r for r in completed if r['scheduled_delivery'] and r['received_at']]
        if eta_rows:
            on_time = sum(1 for r in eta_rows
                          if r['received_at'] <= r['scheduled_delivery'])
            reliability = round(clamp(100.0 * on_time / len(eta_rows)), 1)
            reliability_basis = f'{on_time} of {len(eta_rows)} deliveries on time'
        else:
            reliability = round(clamp(kpis.get('completion_pct') or 0), 1)
            reliability_basis = 'no delivery ETAs recorded — using completion rate'

        # Discipline: paperwork/fleet completeness across non-draft transfers.
        actionable = [r for r in rows if r['status'] != 'draft'] or rows
        discipline_parts = []
        if actionable:
            discipline_parts.append(
                100.0 * sum(1 for r in actionable if r['has_carrier']) / len(actionable))
            discipline_parts.append(
                100.0 * sum(1 for r in actionable if r['scheduled_delivery']) / len(actionable))
            done = [r for r in completed]
            if done:
                discipline_parts.append(
                    100.0 * sum(1 for r in done if r['has_signature']) / len(done))
        discipline = round(clamp(sum(discipline_parts) / len(discipline_parts)
                                 if discipline_parts else 100.0), 1)

        # Balance: how two-way each lane pair is (1.0 = perfectly balanced).
        pair_totals = defaultdict(lambda: defaultdict(int))
        for r in rows:
            pair_totals[tuple(sorted((r['source'], r['dest'])))][(r['source'], r['dest'])] += 1
        imbalances = []
        for pair, directions in pair_totals.items():
            counts = list(directions.values())
            if len(counts) == 1:
                imbalances.append(1.0)
            else:
                imbalances.append(1.0 - min(counts) / max(counts))
        balance = round(clamp(100.0 * (1.0 - (sum(imbalances) / len(imbalances))
                                       if imbalances else 0.0)), 1)

        pillars = [
            {'key': 'speed', 'label': 'Cycle speed', 'score': speed, 'weight': 0.24,
             'note': f'avg cycle {avg_cycle:.1f}h vs {CYCLE_TARGET_H:.0f}h target',
             'target': CYCLE_TARGET_H},
            {'key': 'accuracy', 'label': 'Receipt accuracy', 'score': accuracy, 'weight': 0.24,
             'note': f'fill rate {pct_label(fill)}',
             'target': 100.0},
            {'key': 'reliability', 'label': 'On-time reliability', 'score': reliability,
             'weight': 0.20, 'note': reliability_basis, 'target': 100.0},
            {'key': 'discipline', 'label': 'Process discipline', 'score': discipline,
             'weight': 0.18,
             'note': 'carrier assigned · delivery scheduled · signatures captured',
             'target': 100.0},
            {'key': 'balance', 'label': 'Network balance', 'score': balance, 'weight': 0.14,
             'note': 'how evenly freight flows in both directions',
             'target': 100.0},
        ]
        overall = round(sum(p['score'] * p['weight'] for p in pillars), 1)
        grade = ('A+' if overall >= 92 else 'A' if overall >= 84 else
                 'B' if overall >= 74 else 'C' if overall >= 62 else
                 'D' if overall >= 50 else 'E')
        grade_label = ('Excellent' if overall >= 92 else 'Strong' if overall >= 84 else
                       'Good' if overall >= 74 else 'Fair' if overall >= 62 else
                       'Weak' if overall >= 50 else 'Critical')

        # ═══════════════════ RULES → RECOMMENDATIONS ═══════════════════
        SEVERITY_W = {'critical': 1.0, 'high': 0.78, 'medium': 0.52, 'low': 0.28}
        IMPACT_W = {'high': 1.0, 'medium': 0.62, 'low': 0.32}
        EFFORT_W = {'low': 1.0, 'medium': 0.62, 'high': 0.3}
        CATEGORY_META = {
            'speed': ('Cycle speed', 'mdi-timer-sand'),
            'accuracy': ('Receipt accuracy', 'mdi-shield-check-outline'),
            'cost': ('Cost efficiency', 'mdi-cash-multiple'),
            'risk': ('Risk control', 'mdi-alert-decagram-outline'),
            'balance': ('Network balance', 'mdi-scale-balance'),
            'process': ('Process discipline', 'mdi-clipboard-check-outline'),
        }

        recs = []

        def add(rec_id, title, category, severity, impact, effort, summary, detail,
                actions, metrics, affected=None, save_hours=0.0, save_value=0.0,
                save_units=0, quick_win=False):
            score = round(100 * (0.45 * SEVERITY_W[severity] +
                                 0.35 * IMPACT_W[impact] +
                                 0.20 * EFFORT_W[effort]), 1)
            cat_label, cat_icon = CATEGORY_META[category]
            recs.append({
                'id': rec_id,
                'title': title,
                'category': category,
                'category_label': cat_label,
                'category_icon': cat_icon,
                'severity': severity,
                'impact': impact,
                'effort': effort,
                'score': score,
                'quick_win': quick_win or (effort == 'low' and impact in ('high', 'medium')),
                'summary': summary,
                'detail': detail,
                'actions': actions,
                'metrics': metrics,
                'affected': (affected or [])[:8],
                'save_hours': round(save_hours, 1),
                'save_value': round(save_value, 2),
                'save_units': save_units,
            })

        # ── 1. Approval bottleneck ─────────────────────────────────────
        slow_approvals = [r for r in rows
                          if r['approval_h'] is not None and r['approval_h'] > 8]
        if slow_approvals:
            excess = sum(r['approval_h'] - APPROVAL_TARGET_H for r in slow_approvals)
            worst = sorted(slow_approvals, key=lambda r: -r['approval_h'])[:5]
            add('approval-lag', 'Approvals are holding stock back',
                'speed',
                'critical' if len(slow_approvals) / max(1, len(approval_hours)) > 0.4 else 'high',
                'high', 'low',
                f'{len(slow_approvals)} transfers waited more than 8h between request '
                f'and dispatch (avg {avg_approval:.1f}h overall).',
                'Every hour between request and dispatch is an hour the destination '
                f'branch sits under-stocked. Against a {APPROVAL_TARGET_H:.0f}h target, '
                f'this queue has cost about {excess:.0f} hours of delay.',
                ['Set a 4-hour approval SLA with an auto-escalation after 8 hours.',
                 'Let branch admins auto-approve transfers below a value threshold.',
                 'Show a live "awaiting approval" queue on the approver dashboard.'],
                [{'label': 'Avg approval', 'value': f'{avg_approval:.1f}h'},
                 {'label': 'Over SLA', 'value': str(len(slow_approvals))},
                 {'label': 'Delay cost', 'value': f'{excess:.0f}h'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['approval_h']:.1f}h to dispatch",
                  'value': f"KES {r['value']:,.0f}"} for r in worst],
                save_hours=excess)

        # ── 2. Aging / stalled pipeline ────────────────────────────────
        stalled = [r for r in open_rows if r['age_days'] >= 3]
        if stalled:
            at_risk = sum(r['value'] for r in stalled)
            units_risk = sum(r['units'] for r in stalled)
            oldest = sorted(stalled, key=lambda r: -r['age_days'])[:5]
            add('aging-pipeline', 'Stalled transfers are tying up stock and cash',
                'risk',
                'critical' if any(r['age_days'] >= 7 for r in stalled) else 'high',
                'high', 'low',
                f'{len(stalled)} open transfer{"s" if len(stalled) != 1 else ""} '
                f'have been waiting 3+ days, holding '
                f'{units_risk:,} units worth KES {at_risk:,.0f}.',
                'Open transfers are committed stock: the destination cannot sell it '
                'and the source has already ring-fenced it. Ageing past three days is '
                'the clearest signal of a stuck hand-off.',
                ['Chase the oldest transfers first — oldest first, value second.',
                 'Auto-cancel drafts that never get submitted within 48 hours.',
                 'Add a daily digest to the branch admin listing transfers older than 3 days.'],
                [{'label': 'Stalled', 'value': str(len(stalled))},
                 {'label': 'Units held', 'value': f'{units_risk:,}'},
                 {'label': 'Value held', 'value': f'KES {at_risk:,.0f}'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['age_days']:.1f} days · {r['status'].replace('_', ' ')}",
                  'value': f"KES {r['value']:,.0f}"} for r in oldest],
                save_value=at_risk, save_units=units_risk, quick_win=True)

        # ── 3. Carrier / fleet assignment gaps ─────────────────────────
        unassigned = [r for r in rows
                      if r['status'] in ('requested', 'approved', 'in_transit')
                      and not r['has_carrier']]
        if unassigned:
            add('unassigned-fleet', 'Shipments go out without a carrier',
                'process',
                'high' if len(unassigned) > 2 else 'medium',
                'medium', 'low',
                f'{len(unassigned)} active transfer'
                f'{"s" if len(unassigned) != 1 else ""} '
                'have no driver or carrier assigned.',
                'Unassigned freight is the single biggest predictor of a late receipt — '
                'nobody owns the journey, so delays surface only when the destination '
                'chases the load.',
                ['Require a carrier or driver before a transfer can move to in-transit.',
                 'Default to the lane\'s most-used carrier when the approver does not pick one.',
                 'Surface unassigned transfers as a badge on the logistics dashboard.'],
                [{'label': 'Unassigned', 'value': str(len(unassigned))},
                 {'label': 'Of active', 'value': f'{100 * len(unassigned) / max(1, len([r for r in rows if r["status"] in ("requested", "approved", "in_transit")])):.0f}%'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['units']:,} units · {r['priority']}",
                  'value': f"KES {r['value']:,.0f}"} for r in unassigned[:5]],
                quick_win=True)

        # ── 4. Missing delivery ETAs ───────────────────────────────────
        no_eta = [r for r in rows
                  if r['status'] in ('requested', 'approved', 'in_transit')
                  and not r['scheduled_delivery']]
        if no_eta:
            add('missing-eta', 'Most transfers carry no delivery ETA',
                'process',
                'high' if (kpis.get('on_time_pct') is None) else 'medium',
                'medium', 'low',
                f'{len(no_eta)} active transfer'
                f'{"s" if len(no_eta) != 1 else ""} have no scheduled delivery date, '
                'so on-time performance cannot be measured.',
                'Without an ETA there is no commitment to hold anyone to — the platform '
                'reports "no ETA recorded" instead of a real reliability figure. Setting '
                'even a default lead time turns that into a measurable target.',
                ['Default the delivery date to request + 2 days based on lane history.',
                 'Capture the ETA in the transfer wizard as a required field.',
                 'Flag ETA-less transfers on the analytics dashboard.'],
                [{'label': 'No ETA', 'value': str(len(no_eta))},
                 {'label': 'On-time', 'value': pct_label(kpis.get('on_time_pct'))}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['priority']} · {r['status'].replace('_', ' ')}",
                  'value': f"KES {r['value']:,.0f}"} for r in no_eta[:5]],
                quick_win=True)

        # ── 5. Receipt accuracy ────────────────────────────────────────
        disc = [r for r in completed if r['variance'] != 0]
        if disc:
            value_gap = sum(abs(r['variance']) *
                            (r['value'] / r['units'] if r['units'] else 0) for r in disc)
            rate = 100.0 * len(disc) / max(1, len(completed))
            add('receipt-accuracy', 'Receipts keep coming up short',
                'accuracy',
                'critical' if rate > 25 else 'high' if rate > 12 else 'medium',
                'high', 'medium',
                f'{len(disc)} of {len(completed)} completed transfers '
                f'({rate:.0f}%) closed with a unit variance, '
                f'a combined gap of {sum(abs(r["variance"]) for r in disc):,} units.',
                'Short receipts usually mean the load was split, damaged, or counted '
                'in a hurry at the destination. Each one silently corrupts stock '
                'levels at both ends of the lane.',
                ['Require a variance reason and photo on any receipt that does not match.',
                 'Scan batch barcodes at dispatch and receipt instead of counting by hand.',
                 'Recount any line with a variance the next working day.'],
                [{'label': 'Variance rate', 'value': f'{rate:.0f}%'},
                 {'label': 'Units missing', 'value': f'{sum(abs(r["variance"]) for r in disc):,}'},
                 {'label': 'Value gap', 'value': f'KES {value_gap:,.0f}'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['received']:,} of {r['units']:,} units received",
                  'value': f"{r['variance']:+d}"} for r in disc[:5]],
                save_value=value_gap)

        # ── 6. Lane imbalance ──────────────────────────────────────────
        lane_pairs = defaultdict(lambda: {'out': 0, 'back': 0,
                                          'out_units': 0, 'back_units': 0,
                                          'out_value': 0.0, 'transit': []})
        for r in rows:
            key = tuple(sorted((r['source'], r['dest'])))
            entry = lane_pairs[key]
            if r['source'] == key[0]:
                entry['out'] += 1
                entry['out_units'] += r['units']
                entry['out_value'] += r['value']
            else:
                entry['back'] += 1
                entry['back_units'] += r['units']
            if r['transit_h'] is not None:
                entry['transit'].append(r['transit_h'])

        imbalanced = []
        for (a, b), v in lane_pairs.items():
            heavy, light = max(v['out'], v['back']), min(v['out'], v['back'])
            if heavy >= 3 and (light == 0 or heavy / max(1, light) >= 2.5):
                imbalanced.append({
                    'lane': f'{a} ⇄ {b}',
                    'dominant': a if v['out'] >= v['back'] else b,
                    'dominant_count': heavy,
                    'return_count': light,
                    'units': v['out_units'] + v['back_units'],
                    'value': round(v['out_value'], 2),
                    'ratio': round(heavy / max(1, light), 1),
                    'avg_transit_hours': avg(v['transit']),
                })
        imbalanced.sort(key=lambda x: -x['dominant_count'])
        if imbalanced:
            top = imbalanced[:5]
            add('lane-imbalance', 'One-way lanes mean empty return trips',
                'balance',
                'high' if imbalanced[0]['ratio'] >= 4 else 'medium',
                'high', 'high',
                f'{len(imbalanced)} lane pair'
                f'{"s" if len(imbalanced) != 1 else ""} move freight almost entirely '
                f'in one direction — the worst runs {imbalanced[0]["ratio"]:.1f}:1.',
                'A lane that only flows one way pays for a full return journey with '
                'nothing on board. Rebalancing the return leg — even partially — '
                'cuts cost per unit without buying new capacity.',
                ['Batch return loads: hold non-urgent transfers to the dominant '
                 'destination until a return leg is available.',
                 'Quote the empty return leg to neighbouring branches as cheap capacity.',
                 'Review whether the dominant direction is caused by over-ordering.'],
                [{'label': 'Imbalanced lanes', 'value': str(len(imbalanced))},
                 {'label': 'Worst ratio', 'value': f'{imbalanced[0]["ratio"]:.1f}:1'},
                 {'label': 'Trips involved', 'value': f'{sum(x["dominant_count"] for x in imbalanced)}'}],
                [{'reference': x['lane'],
                  'label': f"{x['dominant_count']} out · {x['return_count']} back",
                  'detail': f"ratio {x['ratio']:.1f}:1 · {x['units']:,} units",
                  'value': f"KES {x['value']:,.0f}"} for x in top])

        # ── 7. Consolidation opportunities ─────────────────────────────
        consolidated = []
        lane_windows = defaultdict(list)
        for r in rows:
            if r['status'] == 'completed':
                continue
            lane_windows[r['lane']].append(r)
        for lane, group in lane_windows.items():
            group.sort(key=lambda r: r['requested_at'])
            cluster = []
            for r in group:
                if cluster and (r['requested_at'] - cluster[-1]['requested_at']).days <= 2:
                    cluster.append(r)
                else:
                    if len(cluster) >= 2:
                        consolidated.append({'lane': lane, 'transfers': cluster})
                    cluster = [r]
            if len(cluster) >= 2:
                consolidated.append({'lane': lane, 'transfers': cluster})
        consolidated = [c for c in consolidated if len(c['transfers']) >= 2]
        if consolidated:
            trips_saved = sum(len(c['transfers']) - 1 for c in consolidated)
            units = sum(sum(r['units'] for r in c['transfers']) for c in consolidated)
            value = sum(sum(r['value'] for r in c['transfers']) for c in consolidated)
            add('consolidation', 'Open transfers on the same lane can share a trip',
                'cost',
                'high' if trips_saved >= 3 else 'medium',
                'high', 'medium',
                f'{trips_saved} trip{"s" if trips_saved != 1 else ""} could be saved by '
                f'merging {sum(len(c["transfers"]) for c in consolidated)} open transfers '
                f'into {len(consolidated)} consolidated run'
                f'{"s" if len(consolidated) != 1 else ""}.',
                'Two or three small transfers dispatched to the same branch within a '
                'couple of days each pay the full fixed cost of a journey. Merging them '
                'into one run cuts fuel, handling and driver time with no loss of service.',
                ['Group open transfers by lane and only dispatch when a full load '
                 'or the SLA deadline is reached, whichever comes first.',
                 'Offer a "merge into next run" option when creating a transfer.',
                 'Set a minimum load size per lane before a dedicated trip is allowed.'],
                [{'label': 'Trips saved', 'value': str(trips_saved)},
                 {'label': 'Transfers merged', 'value': f'{sum(len(c["transfers"]) for c in consolidated)}'},
                 {'label': 'Units involved', 'value': f'{units:,}'}],
                [{'reference': c['lane'],
                  'label': f"{len(c['transfers'])} transfers",
                  'detail': ' · '.join(r['reference'] for r in c['transfers'][:4]),
                  'value': f"KES {sum(r['value'] for r in c['transfers']):,.0f}"}
                 for c in consolidated[:5]],
                save_value=value)

        # ── 8. Priority discipline ─────────────────────────────────────
        urgent = [r for r in rows if r['priority'] in ('high', 'urgent')]
        if urgent:
            urgent_slow = [r for r in urgent
                           if (r['cycle_h'] is not None and r['cycle_h'] > CYCLE_TARGET_H)
                           or (r['status'] in OPEN and r['age_days'] > 2)]
            share = 100.0 * len(urgent) / max(1, total)
            if urgent_slow or share > 40:
                add('priority-discipline', 'Priority flags have stopped meaning anything',
                    'process',
                    'high' if len(urgent_slow) >= 3 else 'medium',
                    'medium', 'low',
                    f'{share:.0f}% of transfers are flagged high or urgent, and '
                    f'{len(urgent_slow)} of them still ran past the '
                    f'{CYCLE_TARGET_H:.0f}h cycle target.',
                    'When most work is urgent, nothing is. Priority should reserve '
                    'expedited handling for genuine stock-outs — otherwise the fast '
                    'path gets as congested as the normal one.',
                    ['Reserve "urgent" for lines that would stock out within 48 hours.',
                     'Report the share of urgent volume per branch every week.',
                     'Auto-downgrade urgent flags that were not actioned within a day.'],
                    [{'label': 'High/urgent', 'value': f'{len(urgent)} ({share:.0f}%)'},
                     {'label': 'Missed target', 'value': str(len(urgent_slow))}],
                    [{'reference': r['reference'], 'label': r['lane'],
                      'detail': f"{r['priority']} · {r['status'].replace('_', ' ')}",
                      'value': (f"{r['cycle_h']:.0f}h" if r['cycle_h'] is not None
                                else f"{r['age_days']:.0f}d open")}
                     for r in (urgent_slow or urgent)[:5]],
                    quick_win=True)

        # ── 9. Draft backlog ───────────────────────────────────────────
        drafts = [r for r in rows if r['status'] == 'draft']
        if len(drafts) >= 2:
            add('draft-backlog', 'Drafts are piling up and never get submitted',
                'process',
                'medium' if len(drafts) < 5 else 'high',
                'low', 'low',
                f'{len(drafts)} transfers were created but never submitted, worth '
                f'KES {sum(r["value"] for r in drafts):,.0f}.',
                'Abandoned drafts clutter the list and hide the real workload. They also '
                'suggest the wizard is being used as a scratchpad rather than a '
                'commitment.',
                ['Auto-expire drafts after 7 days with a notification to the creator.',
                 'Show a "finish or discard" prompt the next time the author opens the page.',
                 'Pre-fill drafts from the last transfer on the same lane.'],
                [{'label': 'Drafts', 'value': str(len(drafts))},
                 {'label': 'Value', 'value': f'KES {sum(r["value"] for r in drafts):,.0f}'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['age_days']:.0f} days old",
                  'value': f"KES {r['value']:,.0f}"} for r in drafts[:5]],
                quick_win=True)

        # ── 10. Expiry risk ────────────────────────────────────────────
        expiring = []
        horizon = today + _td(days=90)
        for r in rows:
            if r['status'] not in OPEN:
                continue
            for batch in r['batches']:
                if not batch or not batch.expiry_date:
                    continue
                if batch.expiry_date <= horizon:
                    days_left = (batch.expiry_date - today).days
                    expiring.append({
                        'reference': r['reference'],
                        'lane': r['lane'],
                        'stock': batch.stock.medication_name,
                        'batch': batch.batch_number,
                        'expiry': batch.expiry_date.isoformat(),
                        'days_left': days_left,
                        'quantity': batch.quantity_remaining,
                    })
        expiring.sort(key=lambda x: x['days_left'])
        if expiring:
            add('expiry-risk', 'In-flight stock is close to expiry',
                'risk',
                'critical' if expiring[0]['days_left'] <= 30 else 'high',
                'medium', 'low',
                f'{len(expiring)} batch pick'
                f'{"s" if len(expiring) != 1 else ""} on open transfers expire within '
                f'90 days — the soonest in {max(0, expiring[0]["days_left"])} days.',
                'Sending near-expiry stock to another branch just moves the problem. '
                'Either the receiving branch sells it fast or it expires on their '
                'shelf instead of yours.',
                ['Prioritise dispatching these batches and flag them as short-dated '
                 'at the destination.',
                 'Offer short-dated stock to high-velocity branches first.',
                 'Block transfers of batches under 30 days to expiry without approval.'],
                [{'label': 'Batches at risk', 'value': str(len(expiring))},
                 {'label': 'Soonest', 'value': f'{max(0, expiring[0]["days_left"])} days'},
                 {'label': 'Units', 'value': f'{sum(x["quantity"] or 0 for x in expiring):,}'}],
                [{'reference': x['reference'], 'label': x['stock'],
                  'detail': f"Batch {x['batch']} · expires {x['expiry']}",
                  'value': f"{x['days_left']}d"} for x in expiring[:5]],
                quick_win=True)

        # ── 11. Carrier performance spread ─────────────────────────────
        carrier_stats = defaultdict(lambda: {'count': 0, 'transit': [], 'on_time': []})
        for r in rows:
            if not r['carrier']:
                continue
            c = carrier_stats[r['carrier']]
            c['count'] += 1
            if r['transit_h'] is not None:
                c['transit'].append(r['transit_h'])
            if r['scheduled_delivery'] and r['received_at']:
                c['on_time'].append(r['received_at'] <= r['scheduled_delivery'])
        carriers = []
        for name, c in carrier_stats.items():
            carriers.append({
                'name': name,
                'shipments': c['count'],
                'avg_transit_hours': avg(c['transit']),
                'on_time_pct': (100.0 * c['on_time'].count(True) / len(c['on_time'])
                                if c['on_time'] else None),
            })
        carriers.sort(key=lambda x: -x['shipments'])
        slow_carriers = [c for c in carriers
                         if c['avg_transit_hours'] is not None
                         and avg_transit and c['avg_transit_hours'] > avg_transit * 1.4]
        if len(carriers) >= 2 and slow_carriers:
            add('carrier-spread', 'Carrier performance varies widely by lane',
                'cost',
                'medium', 'medium', 'medium',
                f'{len(slow_carriers)} of {len(carriers)} carriers run at least 40% '
                f'slower than the network average of {avg_transit:.1f}h in transit.',
                'Transit time differences of this size usually come from route choice '
                'and load scheduling rather than distance. Shifting volume to the '
                'faster carriers is the cheapest speed improvement available.',
                ['Review the slowest carrier first and confirm the delays are theirs, '
                 'not queue time at the dock.',
                 'Weight carrier selection by measured transit time per lane.',
                 'Set a maximum acceptable transit time per lane and alert on breaches.'],
                [{'label': 'Carriers', 'value': str(len(carriers))},
                 {'label': 'Below avg', 'value': str(len(slow_carriers))},
                 {'label': 'Network transit', 'value': f'{avg_transit:.1f}h'}],
                [{'reference': c['name'], 'label': f"{c['shipments']} shipments",
                  'detail': f"{c['avg_transit_hours']:.1f}h transit",
                  'value': pct_label(c['on_time_pct'])} for c in slow_carriers[:5]])

        # ── 12. Value concentration ────────────────────────────────────
        lane_value = defaultdict(float)
        for r in rows:
            lane_value[tuple(sorted((r['source'], r['dest'])))] += r['value']
        total_value = sum(lane_value.values()) or 1.0
        top_lane, top_value = max(lane_value.items(), key=lambda kv: kv[1])
        concentration = 100.0 * top_value / total_value
        if concentration >= 45 and len(lane_value) > 1:
            add('value-concentration', 'One lane carries most of the transfer value',
                'risk',
                'medium', 'medium', 'high',
                f'{concentration:.0f}% of transferred value moves on a single lane '
                f'({top_lane[0]} ⇄ {top_lane[1]}).',
                'A network that depends on one corridor has no slack: a road closure, '
                'a fleet breakdown or a stock-out at either end stops the bulk of the '
                'flow. Secondary lanes are also where the cheaper consolidation '
                'opportunities hide.',
                ['Build a secondary supply path for the top three items on that lane.',
                 'Keep a safety stock buffer at both ends of the dominant corridor.',
                 'Track lane-level value concentration as a monthly resilience metric.'],
                [{'label': 'Top lane share', 'value': f'{concentration:.0f}%'},
                 {'label': 'Lane value', 'value': f'KES {top_value:,.0f}'},
                 {'label': 'Active lanes', 'value': str(len(lane_value))}])

        # ── 13. Small-load dispatch ────────────────────────────────────
        small = [r for r in rows if r['status'] == 'completed' and r['units'] > 0
                 and r['units'] <= 25]
        if len(small) >= 3 and len(small) / max(1, len(completed)) >= 0.3:
            add('small-loads', 'Many trips carry very small loads',
                'cost',
                'medium', 'medium', 'medium',
                f'{len(small)} of {len(completed)} completed transfers moved 25 units '
                f'or fewer ({100 * len(small) / max(1, len(completed)):.0f}% of all runs).',
                'Fixed trip costs — driver time, fuel, dock handling — dominate the '
                'economics of a short run. Consolidating or scheduling small loads onto '
                'shared runs usually beats dispatching them on demand.',
                ['Introduce a scheduled milk-run for small loads on high-frequency lanes.',
                 'Show the estimated cost per unit at the point of creating a transfer.',
                 'Encourage branches to order in fewer, larger batches.'],
                [{'label': 'Small runs', 'value': str(len(small))},
                 {'label': 'Avg load', 'value': f'{avg([r["units"] for r in small]) or 0:.0f} units'},
                 {'label': 'Share of runs', 'value': f'{100 * len(small) / max(1, len(completed)):.0f}%'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['units']:,} units",
                  'value': f"KES {r['value']:,.0f}"} for r in small[:5]])

        # ── 14. Weekday concentration ──────────────────────────────────
        weekday_counts = defaultdict(int)
        for r in rows:
            if r['requested_at']:
                weekday_counts[timezone.localtime(r['requested_at']).strftime('%A')] += 1
        if weekday_counts and total >= 6:
            top_day, top_count = max(weekday_counts.items(), key=lambda kv: kv[1])
            day_share = 100.0 * top_count / total
            if day_share >= 45:
                add('weekday-peak', f'{top_day} concentration is straining dispatch',
                    'process',
                    'medium', 'low', 'low',
                    f'{day_share:.0f}% of all transfers are raised on {top_day}.',
                    'A sharp weekly peak means the dispatch desk and the fleet are '
                    'idle most of the week and overloaded on one day — which is '
                    'exactly when approval and loading delays creep in.',
                    ['Spread replenishment requests across the week per branch.',
                     'Schedule approval cover for the peak day.',
                     'Pre-build peak-day loads the afternoon before.'],
                    [{'label': 'Peak day', 'value': top_day},
                     {'label': 'Share', 'value': f'{day_share:.0f}%'},
                     {'label': 'Volume', 'value': str(top_count)}],
                    quick_win=True)

        recs.sort(key=lambda r: -r['score'])
        for idx, rec in enumerate(recs, 1):
            rec['rank'] = idx

        # ═══════════════════ STAGE FUNNEL ══════════════════════════════
        funnel = [
            {'key': 'draft', 'label': 'Draft', 'count': 0, 'target_hours': None},
            {'key': 'requested', 'label': 'Awaiting approval', 'count': 0,
             'target_hours': APPROVAL_TARGET_H},
            {'key': 'in_transit', 'label': 'In transit', 'count': 0,
             'target_hours': TRANSIT_TARGET_H},
            {'key': 'completed', 'label': 'Received', 'count': 0, 'target_hours': None},
        ]
        funnel_by_key = {f['key']: f for f in funnel}
        for r in rows:
            key = 'completed' if r['status'] == 'completed' else (
                'draft' if r['status'] == 'draft' else (
                    'in_transit' if r['status'] == 'in_transit' else 'requested'))
            if key in funnel_by_key:
                funnel_by_key[key]['count'] += 1
        funnel_by_key['requested']['avg_hours'] = avg_approval
        funnel_by_key['in_transit']['avg_hours'] = avg_transit
        funnel_by_key['completed']['avg_hours'] = avg_cycle
        funnel_by_key['draft']['avg_hours'] = None

        # ═══════════════════ LANE TABLE ════════════════════════════════
        lane_rows = []
        for (a, b), v in lane_pairs.items():
            total_lane = v['out'] + v['back']
            heavy = max(v['out'], v['back'])
            lane_rows.append({
                'lane': f'{a} ⇄ {b}',
                'forward': v['out'],
                'reverse': v['back'],
                'total': total_lane,
                'units': v['out_units'] + v['back_units'],
                'value': round(v['out_value'], 2),
                'avg_transit_hours': avg(v['transit']),
                'balance_pct': round(100.0 * min(v['out'], v['back']) / max(1, heavy), 0),
            })
        lane_rows.sort(key=lambda x: -x['total'])

        # ═══════════════════ BRANCH SCORECARD ══════════════════════════
        branch_stats = defaultdict(lambda: {
            'out': 0, 'in': 0, 'cycles': [], 'variances': 0, 'completed': 0,
            'on_time': [], 'value': 0.0,
        })
        for r in rows:
            out_b = branch_stats[r['source']]
            in_b = branch_stats[r['dest']]
            out_b['out'] += 1
            out_b['value'] += r['value']
            in_b['in'] += 1
            if r['cycle_h'] is not None:
                in_b['cycles'].append(r['cycle_h'])
            if r['status'] == 'completed':
                in_b['completed'] += 1
                if r['variance']:
                    in_b['variances'] += 1
                if r['scheduled_delivery'] and r['received_at']:
                    in_b['on_time'].append(r['received_at'] <= r['scheduled_delivery'])

        scorecard = []
        network_accuracy = accuracy
        network_reliability = reliability
        for name, s in branch_stats.items():
            # Small samples are noisy: a branch with one short receipt should not
            # be scored 0% accuracy. Blend toward the network figure instead.
            if s['completed'] >= 3:
                accuracy_b = 100.0 * (s['completed'] - s['variances']) / s['completed']
            elif s['completed'] == 0:
                accuracy_b = network_accuracy
            else:
                own = 100.0 * (s['completed'] - s['variances']) / s['completed']
                weight = s['completed'] / 3.0
                accuracy_b = own * weight + network_accuracy * (1 - weight)

            speed_b = speed_score(avg(s['cycles']) or 0, CYCLE_TARGET_H)
            if len(s['on_time']) >= 3:
                rel_b = 100.0 * s['on_time'].count(True) / len(s['on_time'])
            elif s['on_time']:
                own = 100.0 * s['on_time'].count(True) / len(s['on_time'])
                weight = len(s['on_time']) / 3.0
                rel_b = own * weight + network_reliability * (1 - weight)
            else:
                rel_b = network_reliability

            score_b = round(clamp(0.45 * speed_b + 0.35 * accuracy_b + 0.20 * rel_b), 1)
            scorecard.append({
                'branch': name,
                'dispatched': s['out'],
                'received': s['in'],
                'completed': s['completed'],
                'value': round(s['value'], 2),
                'avg_cycle_hours': avg(s['cycles']),
                'accuracy_pct': round(accuracy_b, 1),
                'reliability_pct': round(rel_b, 1),
                'score': score_b,
                'grade': ('A' if score_b >= 85 else 'B' if score_b >= 72 else
                          'C' if score_b >= 58 else 'D'),
            })
        scorecard.sort(key=lambda x: -x['score'])

        # ═══════════════════ TOTALS ════════════════════════════════════
        quick_wins = [r for r in recs if r['quick_win']]
        return {
            'filters': filters,
            'scope': {
                'transfers': total,
                'open': len(open_rows),
                'completed': len(completed),
                'units': kpis.get('units') or 0,
                'value': kpis.get('value') or 0,
                'lanes': len(lane_rows),
                'avg_approval_hours': avg_approval,
                'avg_transit_hours': avg_transit,
                'avg_cycle_hours': avg_cycle,
            },
            'score': {
                'overall': overall,
                'grade': grade,
                'label': grade_label,
                'pillars': pillars,
            },
            'summary': {
                'recommendations': len(recs),
                'quick_wins': len(quick_wins),
                'critical': sum(1 for r in recs if r['severity'] == 'critical'),
                'high': sum(1 for r in recs if r['severity'] == 'high'),
                'potential_hours': round(sum(r['save_hours'] for r in recs), 1),
                'potential_value': round(sum(r['save_value'] for r in recs), 2),
                'value_at_risk': round(sum(r['value'] for r in open_rows), 2),
                'units_at_risk': sum(r['units'] for r in open_rows),
            },
            'recommendations': recs,
            'funnel': funnel,
            'lanes': lane_rows[:10],
            'consolidation': [{
                'lane': c['lane'],
                'count': len(c['transfers']),
                'units': sum(r['units'] for r in c['transfers']),
                'value': round(sum(r['value'] for r in c['transfers']), 2),
                'references': [r['reference'] for r in c['transfers']],
            } for c in consolidated[:6]],
            'expiry_risk': expiring[:8],
            'carriers': carriers[:8],
            'scorecard': scorecard,
        }

    @action(detail=False, methods=['get'], url_path='optimization-pdf')
    def optimization_pdf(self, request):
        """Branded PDF of the transfer optimisation plan.

        Page 1 summarises the health score, pillars and stage funnel; page 2
        lists the ranked recommendations with their action plans; page 3 closes
        with lanes, consolidation, expiry risk and the branch scorecard.
        """
        import io as _io
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle, HRFlowable, PageBreak)
        from reportlab.graphics.shapes import (Drawing, Rect, Circle, Wedge,
                                               String as GString)

        payload = self._optimization_payload(request)
        scope = payload['scope']
        score = payload['score']
        summary = payload['summary']
        recs = payload['recommendations']
        funnel = payload['funnel']
        lane_rows = payload['lanes']
        consolidation = payload['consolidation']
        expiry_risk = payload['expiry_risk']
        carrier_rows = payload['carriers']
        scorecard = payload['scorecard']
        filters = payload['filters']

        # ── Branding ────────────────────────────────────────────────────
        from config.pdf_branding import resolve_branding

        logo_path, business_name = None, ''
        try:
            logo_path, business_name = resolve_branding(request)
        except (ImportError, NotImplementedError, OSError, ValueError,
                AttributeError) as exc:
            logger.warning('Optimization PDF: branding unavailable (%s)', exc)
        tenant = getattr(request, 'tenant', None)
        business_name = business_name or getattr(tenant, 'name', '') or 'AdhereMed'

        def _brand_hex(attr, default):
            raw = getattr(tenant, attr, '') if tenant else ''
            if isinstance(raw, str):
                raw = raw.strip()
                if len(raw) == 7 and raw.startswith('#'):
                    try:
                        int(raw[1:], 16)
                        return '#' + raw[1:].upper()
                    except ValueError:
                        pass
            return default

        BRAND = _brand_hex('brand_primary', '#2F6DFF')
        DEEP = _brand_hex('brand_secondary', '#143CE1')
        ACCENT_SOURCE = _brand_hex('brand_accent', '#37D6FF')

        NAVY = '#0F172A'
        SLATE = '#64748B'
        BORDER = '#E2E8F0'
        TRACK = '#EDF1F7'
        GREEN = '#16A34A'
        RED = '#DC2626'
        AMBER = '#F59E0B'
        TEAL = '#14B8A6'
        GREY = '#94A3B8'

        def _rgb(hex_color):
            h = str(hex_color).lstrip('#')
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

        def mix(hex_color, factor):
            r, g, b = _rgb(hex_color)
            if factor >= 0:
                r, g, b = (round(v + (255 - v) * factor) for v in (r, g, b))
            else:
                r, g, b = (round(v * (1 + factor)) for v in (r, g, b))
            return '#%02X%02X%02X' % (r, g, b)

        def blend(a_hex, b_hex, amount):
            a, b = _rgb(a_hex), _rgb(b_hex)
            t = min(max(amount, 0.0), 1.0)
            return '#%02X%02X%02X' % tuple(
                round(a[i] + (b[i] - a[i]) * t) for i in range(3))

        ACCENT = blend(ACCENT_SOURCE, BRAND, 0.55)

        def _grad_at(t):
            stops = ((0.0, _rgb(DEEP)), (0.52, _rgb(BRAND)), (1.0, _rgb(ACCENT)))
            if t <= stops[0][0]:
                return stops[0][1]
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t <= t1:
                    f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                    return tuple(c0[k] + (c1[k] - c0[k]) * f for k in range(3))
            return stops[-1][1]

        def money(v):
            try:
                return f'KES {float(v or 0):,.0f}'
            except (TypeError, ValueError):
                return 'KES 0'

        def ints(v):
            try:
                return f'{int(v or 0):,}'
            except (TypeError, ValueError):
                return '0'

        def fmt_hours(v):
            if v is None:
                return '—'
            try:
                h = float(v)
            except (TypeError, ValueError):
                return '—'
            if h < 1:
                return f'{round(h * 60)}m'
            if h < 48:
                return f'{h:.1f}h'
            return f'{h / 24:.1f}d'

        def tone_for(value):
            try:
                v = float(value)
            except (TypeError, ValueError):
                return GREY
            if v >= 84:
                return GREEN
            if v >= 70:
                return TEAL
            if v >= 58:
                return AMBER
            return RED

        SEV_HEX = {'critical': RED, 'high': '#EA580C', 'medium': AMBER, 'low': GREY}

        period_label = 'All time'
        if filters.get('date_from'):
            def _pretty(iso):
                try:
                    from datetime import datetime as _dtp
                    return _dtp.strptime(str(iso), '%Y-%m-%d').strftime('%b %d %Y')
                except (TypeError, ValueError):
                    return str(iso)
            period_label = (f"{_pretty(filters['date_from'])} – "
                            f"{_pretty(filters.get('date_to') or timezone.localdate())}")

        branch_label = 'All branches'
        if filters.get('branch'):
            try:
                obj = Branch.objects.filter(id=filters['branch']).first()
                branch_label = obj.name if obj else f"Branch #{filters['branch']}"
            except Exception:
                branch_label = f"Branch #{filters['branch']}"

        # ── Styles ──────────────────────────────────────────────────────
        st_card_title = ParagraphStyle('oct', fontName='Helvetica-Bold', fontSize=9.5,
                                       textColor=HexColor(NAVY), leading=12)
        st_card_sub = ParagraphStyle('ocs', fontName='Helvetica', fontSize=6.5,
                                     textColor=HexColor(SLATE), leading=8.5)
        st_cap = ParagraphStyle('ocap', fontName='Helvetica', fontSize=6,
                                textColor=HexColor(SLATE), leading=8)
        st_cap_r = ParagraphStyle('ocapr', parent=st_cap, alignment=TA_RIGHT)
        st_cell = ParagraphStyle('ocell', fontName='Helvetica', fontSize=7,
                                 textColor=HexColor(NAVY), leading=9)
        st_cell_b = ParagraphStyle('ocellb', parent=st_cell, fontName='Helvetica-Bold')
        st_cell_r = ParagraphStyle('ocellr', parent=st_cell, alignment=TA_RIGHT)
        st_body = ParagraphStyle('obody', fontName='Helvetica', fontSize=7.2,
                                 textColor=HexColor(NAVY), leading=10.5)
        st_colhead = ParagraphStyle('och', fontName='Helvetica-Bold', fontSize=6,
                                    textColor=HexColor(SLATE), leading=8)
        st_colhead_r = ParagraphStyle('ochr', parent=st_colhead, alignment=TA_RIGHT)
        st_scope_label = ParagraphStyle('osl', fontName='Helvetica-Bold', fontSize=5.6,
                                        textColor=HexColor(SLATE), leading=7.5)
        st_scope_value = ParagraphStyle('osv', fontName='Helvetica-Bold', fontSize=9,
                                        textColor=HexColor(NAVY), leading=11.5)
        st_note = ParagraphStyle('onote', fontName='Helvetica-Oblique', fontSize=6.5,
                                 textColor=HexColor(SLATE), leading=9)
        st_rec_title = ParagraphStyle('ort', fontName='Helvetica-Bold', fontSize=9.5,
                                      textColor=HexColor(NAVY), leading=11.5)
        st_rec_summary = ParagraphStyle('ors', fontName='Helvetica', fontSize=7,
                                        textColor=HexColor('#334155'), leading=9.6)
        st_action = ParagraphStyle('oac', fontName='Helvetica', fontSize=6.6,
                                   textColor=HexColor('#334155'), leading=9,
                                   leftIndent=7, bulletIndent=0)

        def chip(text, color_hex, size=5.8):
            style = ParagraphStyle(
                f'ochip{size}{color_hex}', fontName='Helvetica-Bold', fontSize=size,
                leading=size + 2.2, alignment=TA_CENTER,
                textColor=HexColor(mix(color_hex, -0.28)),
                backColor=HexColor(mix(color_hex, 0.84)), borderPadding=1.7,
            )
            return Paragraph(str(text).upper(), style)

        def dot(color_hex, size=5.2):
            d = Drawing(size, size)
            d.add(Circle(size / 2, size / 2, size / 2, fillColor=HexColor(color_hex),
                         strokeWidth=0))
            return d

        def bar(frac, color_hex, width, height=4.2, target=None):
            d = Drawing(width, height)
            d.add(Rect(0, 0, width, height, fillColor=HexColor(TRACK), strokeWidth=0))
            filled = max(1.2, width * min(1.0, max(0.0, frac or 0)))
            d.add(Rect(0, 0, filled, height, fillColor=HexColor(color_hex), strokeWidth=0))
            if target is not None:
                tx = width * min(1.0, max(0.0, target))
                d.add(Rect(tx - 0.4, -0.7, 0.9, height + 1.4,
                           fillColor=HexColor('#94A3B8'), strokeWidth=0))
            return d

        # ── Geometry ────────────────────────────────────────────────────
        W, H = landscape(A4)
        MARGIN = 14 * mm
        CONTENT_W = W - 2 * MARGIN
        GAP = 5 * mm
        HALF_W = (CONTENT_W - GAP) / 2

        def _has_logo():
            return bool(logo_path) and os.path.exists(logo_path)

        def _draw_trailing_logo(canv, band_bottom, band_h, box, pad=1.5 * mm):
            if not _has_logo():
                return 0.0
            tile = box + 2 * pad
            x = W - MARGIN - 5 * mm - tile
            y = band_bottom + (band_h - tile) / 2
            canv.saveState()
            canv.setFillColor(white)
            canv.roundRect(x, y, tile, tile, 2.2 * mm, stroke=0, fill=1)
            try:
                canv.drawImage(logo_path, x + pad, y + pad, box, box,
                               preserveAspectRatio=True, anchor='c', mask='auto')
            except (OSError, ValueError, TypeError):
                canv.restoreState()
                return 0.0
            canv.restoreState()
            return tile

        def _fit(canv, text, font_name, font_size, max_width):
            if not text:
                return ''
            if canv.stringWidth(text, font_name, font_size) <= max_width:
                return text
            ell = '...'
            lo, hi = 0, len(text)
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if canv.stringWidth(text[:mid] + ell, font_name, font_size) <= max_width:
                    lo = mid
                else:
                    hi = mid - 1
            return (text[:lo].rstrip() + ell) if lo else ''

        def _page(canv, doc):
            canv.saveState()
            page_no = canv.getPageNumber()
            right_edge = W - MARGIN - 5 * mm
            left_x = MARGIN + 5 * mm
            if page_no == 1:
                band_top = H - 10 * mm
                band_h = 24 * mm
                band_bottom = band_top - band_h
                canv.saveState()
                path = canv.beginPath()
                path.roundRect(MARGIN, band_bottom, CONTENT_W, band_h, 3 * mm)
                canv.clipPath(path, stroke=0, fill=0)
                steps = 150
                slice_w = CONTENT_W / steps
                for i in range(steps):
                    r, g, b = _grad_at(i / (steps - 1))
                    canv.setFillColorRGB(r / 255, g / 255, b / 255)
                    canv.rect(MARGIN + i * slice_w, band_bottom,
                              slice_w + 0.8, band_h, stroke=0, fill=1)
                canv.restoreState()
            else:
                band_top = H - 10 * mm
                band_h = 17 * mm
                band_bottom = band_top - band_h
                canv.setFillColor(HexColor('#F6F8FC'))
                canv.rect(MARGIN, band_bottom, CONTENT_W, band_h, stroke=0, fill=1)
                canv.setFillColor(HexColor(BRAND))
                canv.rect(MARGIN, band_bottom, 2.6 * mm, band_h, stroke=0, fill=1)

            tile = _draw_trailing_logo(canv, band_bottom, band_h,
                                       15 * mm if page_no == 1 else 11 * mm,
                                       pad=1.5 * mm if page_no == 1 else 1.2 * mm)
            text_right = right_edge - (tile + (6 * mm if page_no == 1 else 5 * mm)
                                       if tile else 0)

            if page_no == 1:
                canv.setFillColor(white)
                canv.setFont('Helvetica-Bold', 5.8)
                canv.drawString(left_x, H - 15.6 * mm,
                                'INVENTORY · LOGISTICS · OPTIMIZATION', charSpace=1.1)
                canv.setFont('Helvetica-Bold', 16)
                canv.drawString(left_x, H - 22.4 * mm, 'Transfer Optimization')
                canv.setFont('Helvetica', 7)
                canv.drawString(left_x, H - 27.4 * mm,
                                _fit(canv,
                                     'A ranked plan to cut cycle time, tighten receipts '
                                     'and stop paying for empty return trips',
                                     'Helvetica', 7, text_right - left_x - 6 * mm))

                canv.setFont('Helvetica-Bold', 9.5)
                canv.drawRightString(text_right, H - 16.4 * mm, business_name[:52])
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 21.2 * mm, f'Period: {period_label}')
                canv.drawRightString(text_right, H - 25 * mm, f'Scope: {branch_label}')
                canv.drawRightString(text_right, H - 28.8 * mm,
                                     'Generated '
                                     + timezone.localtime(timezone.now())
                                     .strftime('%b %d %Y, %I:%M %p'))
            else:
                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 10)
                canv.drawString(left_x, H - 17.6 * mm, 'Transfer Optimization')
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawString(left_x, H - 22.6 * mm,
                                _fit(canv,
                                     f'{business_name} · {branch_label} · {period_label}',
                                     'Helvetica', 6.6, text_right - left_x - 6 * mm))
                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 7)
                canv.drawRightString(text_right, H - 18 * mm, business_name[:52])
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 23 * mm,
                                     'Optimization plan · continued')

            canv.setStrokeColor(HexColor(BORDER))
            canv.setLineWidth(0.6)
            canv.line(MARGIN, 12 * mm, W - MARGIN, 12 * mm)
            canv.setFillColor(HexColor(SLATE))
            canv.setFont('Helvetica', 6.8)
            canv.drawString(MARGIN, 7.6 * mm,
                            f'{business_name} · Transfer Optimization Plan')
            canv.setFont('Helvetica-Bold', 6.8)
            canv.setFillColor(HexColor(BRAND))
            canv.drawCentredString(W / 2, 7.6 * mm,
                                   'Powered by AdhereMed · www.adheremed.co')
            canv.setFont('Helvetica', 6.8)
            canv.setFillColor(HexColor(SLATE))
            canv.drawRightString(W - MARGIN, 7.6 * mm, f'Page {page_no}')
            canv.restoreState()

        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=landscape(A4),
            leftMargin=MARGIN, rightMargin=MARGIN,
            topMargin=34 * mm, bottomMargin=16 * mm,
            title='Transfer Optimization Plan',
            author=business_name,
        )
        flow = [Spacer(1, 1 * mm)]

        def card(title, subtitle, content, width):
            rows = [[Paragraph(title, st_card_title)]]
            if subtitle:
                rows.append([Paragraph(subtitle, st_card_sub)])
            rows += [[item] for item in content]
            tbl = Table(rows, colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 1.5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5),
                ('TOPPADDING', (0, 0), (0, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 0 if subtitle else 4),
                ('BOTTOMPADDING', (0, -1), (-1, -1), 7),
            ]))
            return tbl

        def two_col(left, right, left_w=None):
            lw = left_w or HALF_W
            rw = CONTENT_W - lw - GAP
            tbl = Table([[left, '', right]], colWidths=[lw, GAP, rw], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            return tbl

        # ── 1. Score + pillars + summary ────────────────────────────────
        gauge_size = 40 * mm
        gauge = Drawing(gauge_size, gauge_size)
        gauge_value = float(score.get('overall') or 0)
        gauge_color = tone_for(gauge_value)
        cx = gauge_size / 2
        radius = gauge_size / 2 - 3
        ring_w = 7
        gauge.add(Circle(cx, cx, radius - ring_w / 2, fillColor=HexColor(TRACK),
                         strokeWidth=0))
        gauge.add(Circle(cx, cx, radius - ring_w, fillColor=white, strokeWidth=0))
        sweep = 360.0 * min(100.0, max(0.0, gauge_value)) / 100.0
        if sweep > 0:
            gauge.add(Wedge(cx, cx, radius, 90 - sweep, 90,
                            fillColor=HexColor(gauge_color), strokeWidth=0))
            gauge.add(Circle(cx, cx, radius - ring_w, fillColor=white, strokeWidth=0))
        from reportlab.graphics.shapes import String as GString
        gauge.add(GString(cx, cx + 1, f'{gauge_value:.1f}', fontName='Helvetica-Bold',
                          fontSize=17, fillColor=HexColor(gauge_color),
                          textAnchor='middle'))
        gauge.add(GString(cx, cx - 8, f"GRADE {score.get('grade', '-')}",
                          fontName='Helvetica-Bold', fontSize=6,
                          fillColor=HexColor(SLATE), textAnchor='middle'))
        gauge.add(GString(cx, cx - 15, str(score.get('label') or ''),
                          fontName='Helvetica', fontSize=5.6,
                          fillColor=HexColor(SLATE), textAnchor='middle'))

        pillar_rows = []
        p_width = HALF_W - 16 - 46
        for p in score.get('pillars', []):
            pillar_rows.append([
                [Paragraph(p['label'], st_cell_b),
                 Paragraph(p['note'], st_cap),
                 Spacer(1, 1.2 * mm),
                 bar((p['score'] or 0) / 100, tone_for(p['score']), p_width, 4.0,
                     target=(p.get('target') or 100) / 100)],
                Paragraph(f"<b>{p['score']}</b>", st_cell_r),
                Paragraph(f"{round(p['weight'] * 100)}%", st_cap_r),
            ])
        pillars_tbl = Table(pillar_rows,
                            colWidths=[p_width + 10, 22, 18], hAlign='LEFT')
        pillars_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 2.5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3.5),
            ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
        ]))

        score_holder = Table([[gauge, pillars_tbl]],
                             colWidths=[gauge_size + 6, HALF_W - 16 - gauge_size - 12],
                             hAlign='LEFT')
        score_holder.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        score_card = card('Network health', 'Weighted across five operational pillars',
                          [score_holder], HALF_W)

        tile_gap = 3 * mm
        tile_w = (HALF_W - 16 - tile_gap) / 2
        summary_defs = [
            ('RECOMMENDATIONS', str(summary.get('recommendations', 0)),
             f"{summary.get('critical', 0)} critical · {summary.get('high', 0)} high",
             BRAND),
            ('QUICK WINS', str(summary.get('quick_wins', 0)),
             'low effort, measurable', GREEN),
            ('VALUE HELD', money(summary.get('value_at_risk')),
             f"{ints(summary.get('units_at_risk'))} units in open transfers", AMBER),
            ('POTENTIAL UNLOCK', money(summary.get('potential_value')),
             (f"+ {fmt_hours(summary.get('potential_hours'))} recovered"
              if summary.get('potential_hours') else 'from flagged fixes'), TEAL),
        ]

        def stat_tile(label, value, sub, color_hex, width):
            value_style = ParagraphStyle(
                f'osv{label}', fontName='Helvetica-Bold', fontSize=11.5,
                textColor=HexColor(mix(color_hex, -0.15)), leading=14)
            body = [Paragraph(value, value_style),
                    Paragraph(label, st_scope_label),
                    Paragraph(sub, st_cap)]
            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(mix(color_hex, 0.62))),
                ('BACKGROUND', (0, 0), (-1, -1), HexColor(mix(color_hex, 0.9))),
                ('LEFTPADDING', (0, 0), (-1, -1), 7),
                ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return tbl

        summary_rows = []
        for i in range(0, 4, 2):
            summary_rows.append([
                stat_tile(*summary_defs[i], tile_w),
                '',
                stat_tile(*summary_defs[i + 1], tile_w),
            ])
        summary_grid = Table(summary_rows, colWidths=[tile_w, tile_gap, tile_w],
                             hAlign='LEFT')
        summary_grid.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))

        scope_line = (
            f"<b>{ints(scope.get('transfers'))}</b> transfers moved "
            f"<b>{ints(scope.get('units'))}</b> units worth "
            f"<b>{money(scope.get('value'))}</b> across "
            f"<b>{scope.get('lanes', 0)}</b> lane"
            f"{'' if scope.get('lanes') == 1 else 's'}, with "
            f"{scope.get('open', 0)} still in the pipeline. Average cycle time is "
            f"<b>{fmt_hours(scope.get('avg_cycle_hours'))}</b>.")
        worst_pillar = min(score.get('pillars', []),
                           key=lambda p: p['score'], default=None)
        worst_line = ''
        if worst_pillar:
            worst_line = (
                f" The biggest single gain is lifting <b>{worst_pillar['label'].lower()}</b> "
                f"from <b>{worst_pillar['score']}</b> toward "
                f"{round(worst_pillar.get('target') or 100)}.")

        summary_card = card('Executive read-out', 'What the numbers say about this network',
                            [summary_grid, Spacer(1, 2.5 * mm),
                             Paragraph(scope_line + worst_line, st_body)], HALF_W)

        flow += [two_col(score_card, summary_card), Spacer(1, 4 * mm)]

        # ── 2. Funnel + lanes ───────────────────────────────────────────
        funnel_max = max([1] + [f['count'] for f in funnel])
        funnel_w = HALF_W - 16 - 74
        funnel_rows = []
        for f in funnel:
            tone = (AMBER if (f.get('target_hours') and f.get('avg_hours') is not None
                              and f['avg_hours'] > f['target_hours'])
                    else {'draft': GREY, 'completed': GREEN}.get(f['key'], BRAND))
            meta = fmt_hours(f.get('avg_hours'))
            if f.get('target_hours'):
                meta += f"  /  target {fmt_hours(f['target_hours'])}"
            funnel_rows.append([
                [Paragraph(f['label'], st_cell_b), Paragraph(meta, st_cap),
                 Spacer(1, 1.2 * mm),
                 bar(f['count'] / funnel_max, tone, funnel_w, 4.4)],
                Paragraph(f"<b>{f['count']}</b>", st_cell_r),
            ])
        funnel_tbl = Table(funnel_rows, colWidths=[funnel_w + 10, 24], hAlign='LEFT')
        funnel_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
        ]))
        funnel_card = card('Stage funnel', 'Volume and dwell time at each stage',
                           [funnel_tbl], HALF_W)

        lane_w = HALF_W - 16
        lane_bar_w = lane_w - 118
        lane_max = max([1] + [max(l['forward'], l['reverse']) for l in lane_rows]) \
            if lane_rows else 1
        lane_table_rows = []
        for l in lane_rows[:7]:
            lane_table_rows.append([
                [Paragraph(str(l['lane'])[:44], st_cell_b),
                 Paragraph(f"{ints(l['units'])} units · {money(l['value'])} · "
                           f"transit {fmt_hours(l.get('avg_transit_hours'))}", st_cap)],
                [Paragraph(f"out {l['forward']}", st_cap),
                 bar(l['forward'] / lane_max, BRAND, lane_bar_w * 0.62, 3.4),
                 Paragraph(f"back {l['reverse']}", st_cap),
                 bar(l['reverse'] / lane_max, TEAL, lane_bar_w * 0.62, 3.4)],
                chip(f"{l['balance_pct']:.0f}% balanced",
                     GREEN if l['balance_pct'] >= 70 else
                     AMBER if l['balance_pct'] >= 40 else RED),
            ])
        if lane_table_rows:
            lanes_tbl = Table(lane_table_rows,
                              colWidths=[lane_w * 0.44, lane_w * 0.36, lane_w * 0.20],
                              hAlign='LEFT')
            lanes_tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            lanes_content = [lanes_tbl]
        else:
            lanes_content = [Paragraph('No lanes recorded in this scope.', st_note)]
        lanes_card = card('Lane balance', 'How evenly freight flows in both directions',
                          lanes_content, HALF_W)

        flow += [two_col(funnel_card, lanes_card), Spacer(1, 4 * mm)]

        # ── 3. Priority recommendations (page 2) ────────────────────────
        flow.append(PageBreak())
        flow.append(Paragraph('Priority action plan',
                              ParagraphStyle('ortitle', fontName='Helvetica-Bold',
                                             fontSize=11, textColor=HexColor(NAVY),
                                             leading=14)))
        flow.append(Paragraph(
            f'{len(recs)} recommendation'
            f'{"s" if len(recs) != 1 else ""} ranked by severity (45%), impact (35%) '
            'and ease of implementation (20%).', st_card_sub))
        flow.append(Spacer(1, 3 * mm))

        def rec_block(rec, width):
            sev_hex = SEV_HEX.get(rec['severity'], GREY)
            inner = width - 16
            head = Table([[
                Paragraph(f"<b>{rec['rank']}</b>", ParagraphStyle(
                    'orank', fontName='Helvetica-Bold', fontSize=11,
                    textColor=HexColor(sev_hex), leading=13, alignment=TA_CENTER)),
                [Paragraph(rec['title'], st_rec_title),
                 Paragraph(rec['summary'], st_rec_summary)],
                Paragraph(f"<b>{rec['score']}</b>", ParagraphStyle(
                    'oscore', fontName='Helvetica-Bold', fontSize=13,
                    textColor=HexColor(sev_hex), leading=15, alignment=TA_RIGHT)),
            ]], colWidths=[9 * mm, inner - 9 * mm - 13 * mm, 13 * mm], hAlign='LEFT')
            head.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))

            meta_cells = [chip(rec['severity'], sev_hex),
                          chip(rec['category_label'], BRAND)]
            if rec.get('quick_win'):
                meta_cells.append(chip('Quick win', GREEN))
            meta_cells.append(Paragraph(
                f'<font color="{SLATE}" size="6">impact {rec["impact"]} '
                f'· effort {rec["effort"]}</font>', st_cap))
            meta_row = Table([meta_cells], hAlign='LEFT')
            meta_row.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            # Simple metric strip
            metric_cells = []
            for m in rec['metrics'][:3]:
                metric_cells.append([Paragraph(f"<b>{m['value']}</b>",
                                               ParagraphStyle('omv', parent=st_cell,
                                                              fontName='Helvetica-Bold',
                                                              fontSize=8.5, leading=10)),
                                     Paragraph(m['label'], st_cap)])
            metric_tbl = None
            if metric_cells:
                metric_tbl = Table([metric_cells],
                                   colWidths=[inner / max(1, len(metric_cells))] *
                                   max(1, len(metric_cells)), hAlign='LEFT')
                metric_tbl.setStyle(TableStyle([
                    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                    ('LEFTPADDING', (0, 0), (-1, -1), 0),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                    ('TOPPADDING', (0, 0), (-1, -1), 0),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
                ]))

            actions = [Paragraph(f'• {a}', st_action) for a in rec['actions']]
            affected_txt = ''
            if rec['affected']:
                refs = ', '.join(str(a['reference']) for a in rec['affected'][:5])
                affected_txt = f'<font color="{SLATE}" size="6">Affected: {refs}</font>'

            body = [head, Spacer(1, 1.6 * mm), meta_row, Spacer(1, 2 * mm)]
            if metric_tbl is not None:
                body += [metric_tbl, Spacer(1, 2 * mm)]
            body += actions
            if affected_txt:
                body += [Spacer(1, 1.2 * mm), Paragraph(affected_txt, st_cap)]

            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('LINEBEFORE', (0, 0), (0, -1), 2.8, HexColor(sev_hex)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 7),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
            ]))
            return tbl

        if recs:
            # Pair the cards left/right so reportlab can page-break between
            # rows — a single tall column would overflow the frame.
            for i in range(0, min(len(recs), 10), 2):
                left_rec = rec_block(recs[i], HALF_W)
                right_rec = (rec_block(recs[i + 1], HALF_W)
                             if i + 1 < min(len(recs), 10)
                             else Paragraph('', st_note))
                flow.append(two_col(left_rec, right_rec))
                if i + 2 < min(len(recs), 10):
                    flow.append(Spacer(1, 3 * mm))
            if len(recs) > 10:
                flow.append(Spacer(1, 2 * mm))
                flow.append(Paragraph(
                    f'Showing the top 10 of {len(recs)} recommendations — '
                    'the Optimization page lists the full plan.', st_note))
        else:
            flow.append(Paragraph(
                f'<font color="{GREEN}"><b>No open recommendations</b></font> — '
                'this network is running clean for the selected scope.', st_cap))

        # ── 4. Closing detail (page 3) ──────────────────────────────────
        flow.append(PageBreak())

        consol_rows = []
        for c in consolidation[:5]:
            consol_rows.append([
                Paragraph(str(c['lane'])[:42], st_cell_b),
                Paragraph(str(c['count']), st_cell_r),
                Paragraph(ints(c['units']), st_cell_r),
                Paragraph(money(c['value']), st_cell_r),
                chip(f"-{c['count'] - 1} trip" + ('' if c['count'] - 1 == 1 else 's'), GREEN),
            ])
        inner_w = HALF_W - 16
        if consol_rows:
            consol_tbl = Table(
                [[Paragraph('LANE', st_colhead), Paragraph('COUNT', st_colhead_r),
                  Paragraph('UNITS', st_colhead_r), Paragraph('VALUE', st_colhead_r),
                  Paragraph('SAVE', st_colhead)]] + consol_rows,
                colWidths=[inner_w * 0.42, inner_w * 0.12, inner_w * 0.14,
                           inner_w * 0.18, inner_w * 0.14], hAlign='LEFT')
            consol_tbl.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.7, HexColor(BORDER)),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 2),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            consol_content = [consol_tbl]
        else:
            consol_content = [Paragraph(
                f'<font color="{GREEN}"><b>No merge candidates</b></font> — every open '
                'transfer is on its own lane or timeline.', st_cap)]
        consol_card = card('Consolidation opportunities',
                           'Open transfers that could share a single run',
                           consol_content, HALF_W)

        exp_rows = []
        for e in expiry_risk[:6]:
            tone = RED if e['days_left'] <= 30 else AMBER if e['days_left'] <= 60 else SLATE
            exp_rows.append([
                Paragraph(f"<font color='{tone}'><b>{e['days_left']}d</b></font>", st_cell),
                [Paragraph(str(e['stock'])[:40], st_cell_b),
                 Paragraph(f"Batch {e['batch']} · expires {e['expiry']} · "
                           f"{e['reference']}", st_cap)],
                Paragraph(ints(e['quantity']), st_cell_r),
            ])
        if exp_rows:
            exp_tbl = Table(exp_rows,
                            colWidths=[14, inner_w - 14 - 22, 22], hAlign='LEFT')
            exp_tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            exp_content = [exp_tbl]
        else:
            exp_content = [Paragraph(
                f'<font color="{GREEN}"><b>No short-dated stock</b></font> — nothing in '
                'the pipeline expires within 90 days.', st_cap)]
        exp_card = card('Expiry risk in flight',
                        'Batches on open transfers expiring within 90 days',
                        exp_content, HALF_W)

        flow += [two_col(consol_card, exp_card), Spacer(1, 4 * mm)]

        carrier_rows_pdf = []
        for c in carrier_rows[:6]:
            carrier_rows_pdf.append([
                Paragraph(str(c['name'])[:30], st_cell_b),
                Paragraph(str(c['shipments']), st_cell_r),
                Paragraph(fmt_hours(c.get('avg_transit_hours')), st_cell_r),
                chip(f"{c['on_time_pct']:.0f}%",
                     GREEN if (c['on_time_pct'] or 0) >= 90 else
                     AMBER if (c['on_time_pct'] or 0) >= 70 else RED)
                if c.get('on_time_pct') is not None else Paragraph('—', st_cap_r),
            ])
        if carrier_rows_pdf:
            carrier_tbl = Table(
                [[Paragraph('CARRIER', st_colhead), Paragraph('MOVES', st_colhead_r),
                  Paragraph('TRANSIT', st_colhead_r), Paragraph('ON TIME', st_colhead)]] +
                carrier_rows_pdf,
                colWidths=[inner_w * 0.5, inner_w * 0.16, inner_w * 0.18,
                           inner_w * 0.16], hAlign='LEFT')
            carrier_tbl.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.7, HexColor(BORDER)),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 2),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            carrier_content = [carrier_tbl]
        else:
            carrier_content = [Paragraph('No carrier assignments recorded.', st_note)]
        carrier_card = card('Carrier performance', 'Measured transit time per carrier',
                            carrier_content, HALF_W)

        branch_rows_pdf = []
        for b in scorecard[:6]:
            tone = tone_for(b['score'])
            branch_rows_pdf.append([
                chip(b['grade'], tone),
                [Paragraph(str(b['branch'])[:34], st_cell_b),
                 Paragraph(f"{b['dispatched']} out · {b['received']} in · "
                           f"cycle {fmt_hours(b.get('avg_cycle_hours'))}", st_cap),
                 Spacer(1, 1 * mm),
                 bar(b['score'] / 100, tone, inner_w - 54, 3.4)],
                Paragraph(f"<b>{b['score']}</b>", st_cell_r),
            ])
        if branch_rows_pdf:
            branch_tbl = Table(branch_rows_pdf,
                               colWidths=[14, inner_w - 14 - 24, 24], hAlign='LEFT')
            branch_tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            branch_content = [branch_tbl]
        else:
            branch_content = [Paragraph('No branch activity recorded.', st_note)]
        branch_card = card('Branch scorecard', 'Speed, accuracy and reliability per site',
                           branch_content, HALF_W)

        flow += [two_col(carrier_card, branch_card), Spacer(1, 3 * mm)]
        flow.append(Paragraph(
            f'Derived from {ints(scope.get("transfers"))} transfers over '
            f'{period_label.lower()} scoped to {branch_label.lower()}. Recommendation '
            'scores weight severity (45%), impact (35%) and ease of implementation '
            '(20%).', st_note))

        doc.build(flow, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        stamp_str = timezone.localtime(timezone.now()).strftime('%Y%m%d')
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={
                'Content-Disposition':
                    f'attachment; filename="transfer-optimization_{stamp_str}.pdf"',
            },
        )

    @action(detail=True, methods=['post'])
    def submit(self, request, pk=None):
        """Move from draft to requested."""
        transfer = self.get_object()
        if transfer.status != StockTransfer.Status.DRAFT:
            return Response({'detail': 'Only drafts can be submitted.'}, status=400)
        transfer.status = StockTransfer.Status.REQUESTED
        transfer.save(update_fields=['status'])
        self._notify_transfer(transfer, 'requested', request.user)
        return Response(self.get_serializer(transfer).data)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Approve and ship: deduct from source-branch stock immediately.

        Fails with a shortage report if any line exceeds the on-hand stock,
        leaving all quantities untouched (atomic)."""
        from django.db import transaction as db_transaction

        transfer = self.get_object()
        if transfer.status not in (StockTransfer.Status.REQUESTED, StockTransfer.Status.DRAFT):
            return Response({'detail': 'Only requested transfers can be approved.'},
                            status=status.HTTP_409_CONFLICT)
        if not has_capability(request, 'transfer.approve'):
            return Response(
                {'detail': 'You do not have permission to approve and ship '
                           'transfers (transfer.approve capability required).'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Validate the signature payload before touching stock so an invalid
        # value cannot leave a half-applied transfer behind.
        signature = self._clean_signature(request.data.get('signature'))
        if signature is None:
            return Response(
                {'detail': 'Invalid signature data — expected a base64 image data-URL.'},
                status=400,
            )

        with db_transaction.atomic():
            # Re-read the transfer under a row lock so two concurrent approvals
            # cannot both pass the availability check and double-deduct.
            locked = (StockTransfer.objects.select_for_update()
                      .filter(pk=transfer.pk).first())
            if locked is None:
                return Response({'detail': 'Transfer no longer exists.'}, status=404)
            if locked.status not in (StockTransfer.Status.REQUESTED,
                                     StockTransfer.Status.DRAFT):
                return Response(
                    {'detail': 'This transfer has already been processed.'},
                    status=status.HTTP_409_CONFLICT)
            transfer = locked

            lines = list(transfer.lines.select_related('stock').all())
            stock_ids = {line.stock_id for line in lines if line.stock_id}
            today = timezone.localdate()

            # Lock every batch that could be touched, then work from those
            # locked instances instead of the (stale) select_related copies.
            list(StockBatch.objects.select_for_update()
                 .filter(stock_id__in=stock_ids).order_by('expiry_date'))
            batches = {}
            for b in (StockBatch.objects.filter(stock_id__in=stock_ids)
                      .order_by('expiry_date', 'received_date')):
                batches.setdefault(b.stock_id, []).append(b)
            batch_by_id = {b.id: b for bs in batches.values() for b in bs}

            def _shippable(batch) -> bool:
                """Stock that may physically leave this warehouse.

                Three things used to be ignored here: an expired lot, a lot
                quarantined by auto-quarantine / a recall / a cold-chain
                breach, and a lot sitting at a *different* branch (which the
                FEFO loop happily drained).
                """
                return (
                    (batch.quantity_remaining or 0) > 0
                    and not batch.is_blocked
                    and (batch.expiry_date is None or batch.expiry_date >= today)
                    and batch.branch_id in (transfer.source_branch_id, None)
                )

            # ── Pre-flight: verify on-hand stock covers every line ──────
            # Demand is accumulated per stock / per pinned batch so two lines
            # that each fit individually cannot jointly oversell the item.
            demand_stock, demand_batch = {}, {}
            for line in lines:
                if line.batch_id:
                    demand_batch[line.batch_id] = \
                        demand_batch.get(line.batch_id, 0) + line.quantity
                else:
                    demand_stock[line.stock_id] = \
                        demand_stock.get(line.stock_id, 0) + line.quantity

            shortages, seen = [], set()
            for line in lines:
                if line.batch_id:
                    pinned = batch_by_id.get(line.batch_id)
                    available = (pinned.quantity_remaining
                                 if pinned and _shippable(pinned) else 0)
                    need = demand_batch.get(line.batch_id, 0)
                    label = pinned.batch_number if pinned else None
                    key = ('batch', line.batch_id)
                    reason = ('batch is quarantined or expired'
                              if pinned and not _shippable(pinned) else None)
                else:
                    available = sum(b.quantity_remaining or 0
                                    for b in batches.get(line.stock_id, [])
                                    if _shippable(b))
                    need = demand_stock.get(line.stock_id, 0)
                    label = None
                    key = ('stock', line.stock_id)
                    reason = None
                if need > available and key not in seen:
                    seen.add(key)
                    shortages.append({
                        'stock': line.stock.medication_name,
                        'requested': need,
                        'available': available,
                        'batch': label,
                        'reason': reason,
                    })
            if shortages:
                return Response(
                    {'detail': 'Insufficient sellable stock for this transfer.',
                     'shortages': shortages},
                    status=400,
                )

            # ── Deduction ─────────────────────────────────────────────────
            # Every consumed lot is recorded on the line so receiving books the
            # real batch/expiry/supplier instead of guessing later (the source
            # lot is often drained to zero by the time the goods arrive).
            for line in lines:
                consumed = []
                if line.batch_id:
                    pinned = batch_by_id.get(line.batch_id)
                    if pinned:
                        pinned.quantity_remaining = \
                            (pinned.quantity_remaining or 0) - line.quantity
                        pinned.save(update_fields=['quantity_remaining'])
                        consumed.append(self._consumed_payload(pinned, line.quantity))
                else:
                    remaining = line.quantity
                    for batch in (b for b in batches.get(line.stock_id, [])
                                  if _shippable(b)):
                        if remaining <= 0:
                            break
                        take = min(batch.quantity_remaining, remaining)
                        batch.quantity_remaining -= take
                        batch.save(update_fields=['quantity_remaining'])
                        consumed.append(self._consumed_payload(batch, take))
                        remaining -= take
                    if remaining > 0:
                        # Unreachable after the cumulative pre-flight; abort the
                        # whole transaction rather than shipping phantom stock.
                        raise serializers.ValidationError({
                            'detail': f'Stock for {line.stock.medication_name} changed '
                                      f'while approving — please retry.'})

                if consumed:
                    line.batches_deducted = consumed
                    line.save(update_fields=['batches_deducted'])

            # ── Digital signature (captured in the approval dialog) ───────
            if signature:
                transfer.approved_signature = signature

            self._set_status(transfer, StockTransfer.Status.IN_TRANSIT, request.user, 'approved_by')
            _audit(
                request, 'transfer_approve', transfer,
                description=f'Transfer {transfer.reference} approved and shipped',
                payload_diff={
                    'status': 'in_transit',
                    'source_branch': transfer.source_branch_id,
                    'dest_branch': transfer.dest_branch_id,
                    'lines': [
                        {'stock_id': ln.stock_id, 'qty': ln.quantity}
                        for ln in lines
                    ],
                },
            )
        self._notify_transfer(transfer, 'in_transit', request.user)
        return Response(self.get_serializer(transfer).data)

    @action(detail=True, methods=['post'])
    def receive(self, request, pk=None):
        """Receive at destination: create a new batch per line.

        Payload: {lines: [{id, quantity_received, notes}]} to record short
        receipts and per-line remarks (e.g. "2 units damaged").

        Validations: received qty must be 0 <= qty <= sent qty.

        If the source-branch stock item does not exist in the destination
        branch's inventory yet, a new MedicationStock is created there
        (cloning the source's catalog fields), and the line is reported back
        via ``added_to_inventory`` so the UI can confirm to the receiver.
        """
        transfer = self.get_object()
        if transfer.status != StockTransfer.Status.IN_TRANSIT:
            return Response({'detail': 'Only in-transit transfers can be received.'},
                            status=status.HTTP_409_CONFLICT)
        if not has_capability(request, 'transfer.receive'):
            return Response(
                {'detail': 'You do not have permission to receive transfers '
                           '(transfer.receive capability required).'},
                status=status.HTTP_403_FORBIDDEN,
            )

        received_map = {}
        notes_map = {}
        overrides = {}
        for payload in (request.data.get('lines') or []):
            line_id = payload.get('id')
            received_map[line_id] = payload.get('quantity_received')
            if payload.get('notes'):
                notes_map[line_id] = str(payload['notes']).strip()
            extra = {k: payload.get(k)
                     for k in ('expiry_date', 'batch_number', 'supplier')
                     if payload.get(k) not in (None, '')}
            if extra:
                overrides[line_id] = extra

        # Validate the signature before mutating stock/batches.
        signature = self._clean_signature(request.data.get('signature'))
        if signature is None:
            return Response(
                {'detail': 'Invalid signature data — expected a base64 image data-URL.'},
                status=400,
            )

        # ── Validate before touching anything ──────────────────────────
        errors = []
        for line in transfer.lines.select_related('stock').all():
            qr = received_map.get(line.id)
            qty_received = int(qr) if qr not in (None, '') else line.quantity
            if qty_received < 0:
                errors.append(f'{line.stock.medication_name}: received quantity cannot be negative.')
            elif qty_received > line.quantity:
                errors.append(
                    f'{line.stock.medication_name}: received ({qty_received}) exceeds sent ({line.quantity}).')
            expiry_raw = (overrides.get(line.id) or {}).get('expiry_date')
            if expiry_raw:
                try:
                    _parse_date(expiry_raw)
                except (TypeError, ValueError):
                    errors.append(
                        f'{line.stock.medication_name}: expiry date must be YYYY-MM-DD.')
        if errors:
            return Response({'detail': ' '.join(errors)}, status=400)

        from datetime import date as _d, timedelta as _td
        from django.db import transaction as db_transaction

        total_sent = total_received = 0
        value_received = 0.0
        new_items = []

        with db_transaction.atomic():
            # Lock the transfer so two receivers cannot both post the same
            # shipment (double stock) — same guard as approve().
            locked = (StockTransfer.objects.select_for_update()
                      .filter(pk=transfer.pk).first())
            if locked is None:
                return Response({'detail': 'Transfer no longer exists.'}, status=404)
            if locked.status != StockTransfer.Status.IN_TRANSIT:
                return Response(
                    {'detail': 'This transfer has already been received.'},
                    status=status.HTTP_409_CONFLICT)
            transfer = locked

            # ── Apply receipt ────────────────────────────────────────────
            for line in transfer.lines.select_related('stock', 'batch').all():
                qr = received_map.get(line.id)
                qty_received = int(qr) if qr not in (None, '') else line.quantity
                line.quantity_received = qty_received
                if line.id in notes_map:
                    line.notes = notes_map[line.id]
                line.save(update_fields=['quantity_received', 'notes'])
                total_sent += line.quantity
                total_received += qty_received

                if qty_received <= 0 or not line.stock:
                    continue

                override = overrides.get(line.id) or {}
                dest_stock, was_created = self._find_or_create_dest_stock(
                    line.stock, transfer.dest_branch, lock=True,
                )
                if dest_stock is None:
                    # Previously this fell back to `line.stock`, which booked
                    # the received units into the *shipping* warehouse.
                    raise serializers.ValidationError({
                        'detail': f'Could not resolve a destination item for '
                                  f'{line.stock.medication_name}.',
                    })
                if was_created:
                    new_items.append({
                        'medication_name': dest_stock.medication_name,
                        'stock_id': dest_stock.id,
                        'generic_name': dest_stock.generic_name,
                        'brand_name': dest_stock.brand_name,
                        'strength': dest_stock.strength,
                        'quantity_received': qty_received,
                    })

                for lot in self._receipt_lots(line, qty_received, override):
                    StockBatch.objects.create(
                        stock=dest_stock,
                        batch_number=lot['batch_number'],
                        quantity_received=lot['qty'],
                        quantity_remaining=lot['qty'],
                        cost_price_per_unit=lot['cost_price_per_unit'],
                        expiry_date=lot['expiry_date'],
                        supplier=lot['supplier'],
                        branch=transfer.dest_branch,
                    )
                    value_received += float(lot['cost_price_per_unit'] or 0) * lot['qty']

                # Units that left the source but never arrived are a real loss:
                # record them, or the shelf silently disagrees with the books.
                short = int(line.quantity) - qty_received
                if short > 0:
                    StockAdjustment.objects.create(
                        stock=line.stock,
                        batch=None,
                        quantity_change=-short,
                        reason=StockAdjustment.Reason.TRANSFER_SHORTAGE,
                        notes=(f'Transfer {transfer.reference}: received '
                               f'{qty_received}/{line.quantity} units'),
                        adjusted_by=(request.user
                                     if request.user.is_authenticated else None),
                    )

            # ── Digital signature (captured in the receive dialog) ───────
            if signature:
                transfer.received_signature = signature

            self._set_status(transfer, StockTransfer.Status.COMPLETED,
                             request.user, 'received_by')

            _audit(
                request, 'transfer_receive', transfer,
                description=f'Transfer {transfer.reference} received '
                            f'({total_received}/{total_sent} units)',
                payload_diff={
                    'status': 'completed',
                    'units_sent': total_sent,
                    'units_received': total_received,
                    'new_items': [i['stock_id'] for i in new_items],
                },
            )

        # ── Notify the receiver (and any other recipients) that new stock
        #    items were created in the destination branch's inventory.
        if new_items:
            from notifications.models import Notification
            title = f'{len(new_items)} new item(s) added to {transfer.dest_branch.name} inventory'
            message = (
                f'Receiving transfer {transfer.reference} introduced '
                f'{len(new_items)} new medication item(s) to the '
                f'{transfer.dest_branch.name} inventory: '
                + ', '.join(i['medication_name'] for i in new_items[:5])
                + (' …' if len(new_items) > 5 else '')
                + '.'
            )
            recipients = {transfer.received_by, transfer.requested_by}
            for u in recipients:
                if u and u == request.user:
                    continue
                Notification.objects.create(
                    recipient=u,
                    type=Notification.NotificationType.SYSTEM,
                    title=title,
                    message=message,
                    data={
                        'transfer_id': transfer.id,
                        'reference': transfer.reference,
                        'branch_id': transfer.dest_branch_id,
                        'branch_name': transfer.dest_branch.name,
                        'new_items': new_items,
                    },
                )

        # Lines were mutated — drop the prefetched cache so the response
        # reflects the freshly saved values (get_object() prefetches lines).
        if hasattr(transfer, '_prefetched_objects_cache'):
            transfer._prefetched_objects_cache.pop('lines', None)

        self._notify_transfer(transfer, 'completed', request.user)
        return Response({
            **self.get_serializer(transfer).data,
            'receipt_summary': {
                'units_sent': total_sent,
                'units_received': total_received,
                'variance': total_received - total_sent,
                'value_received': round(value_received, 2),
                'discrepancy_value': round(
                    value_received - sum(
                        float(l.stock.cost_price or 0) * l.quantity
                        for l in transfer.lines.select_related('stock').all() if l.stock
                    ), 2),
            },
            'added_to_inventory': {
                'branch_id': transfer.dest_branch_id,
                'branch_name': transfer.dest_branch.name,
                'count': len(new_items),
                'items': new_items,
            },
        })

    @action(detail=True, methods=['get'], url_path='preview-receive')
    def preview_receive(self, request, pk=None):
        """Per-line inventory status at the destination branch.

        Returns, for every shipped line, whether the item already exists in
        the destination branch's inventory and how many units are on hand
        there. The Receive dialog uses this to flag items that will be
        auto-created as new MedicationStock records on confirmation.
        """
        transfer = self.get_object()
        if transfer.status != StockTransfer.Status.IN_TRANSIT:
            return Response({'detail': 'Only in-transit transfers can be previewed.'},
                            status=400)
        lines_data = []
        for line in transfer.lines.select_related('stock').all():
            exists = False
            dest_stock_id = None
            qty_at_dest = 0
            if line.stock:
                dest_stock = (
                    MedicationStock.objects
                    .filter(branch=transfer.dest_branch_id,
                            medication_name__iexact=line.stock.medication_name)
                    .exclude(pk=line.stock_id)
                    .first()
                )
                if dest_stock:
                    exists = True
                    dest_stock_id = dest_stock.id
                    qty_at_dest = dest_stock.total_quantity
            lines_data.append({
                'id': line.id,
                'medication_name': line.stock.medication_name if line.stock else '',
                'exists_at_dest': exists,
                'dest_stock_id': dest_stock_id,
                'quantity_at_dest': qty_at_dest,
                'quantity_sent': line.quantity,
            })
        return Response({
            'dest_branch_id': transfer.dest_branch_id,
            'dest_branch_name': transfer.dest_branch.name,
            'lines': lines_data,
        })

    def _receipt_lots(self, line, qty_received: int, override: dict) -> list:
        """Lots to create at the destination for one received line.

        The source lots were recorded on the line at approval, so the receiving
        warehouse keeps each lot's real batch number, expiry, supplier and unit
        cost. A partial receipt is distributed over those lots in the order they
        were drained (FEFO), which is the order a picker would have used.

        Older transfers have no snapshot; they fall back to the line's pinned
        batch (or the item's most recent batch) exactly as before.
        """
        from datetime import date as _date
        from decimal import Decimal as _Decimal

        def _as_date(value):
            if not value:
                return None
            try:
                return _date.fromisoformat(str(value)[:10])
            except (TypeError, ValueError):
                return None

        default_expiry = timezone.localdate() + timedelta(days=365)
        override_expiry = (_parse_date(override['expiry_date'])
                           if override.get('expiry_date') else None)
        override_supplier = None
        if override.get('supplier'):
            try:
                from suppliers.models import Supplier
                override_supplier = (Supplier.objects
                                     .filter(name__iexact=str(override['supplier']).strip())
                                     .first())
            except Exception:
                override_supplier = None
        override_batch_number = (override.get('batch_number') or '').strip()

        snapshot = list(line.batches_deducted or [])
        if not snapshot:
            legacy = line.batch or line.stock.batches.order_by('-expiry_date').first()
            snapshot = [{
                'batch_number': legacy.batch_number if legacy else '',
                'expiry_date': (legacy.expiry_date.isoformat()
                                if legacy and legacy.expiry_date else None),
                'cost_price_per_unit': (float(legacy.cost_price_per_unit)
                                        if legacy and legacy.cost_price_per_unit
                                        else float(line.stock.cost_price or 0)),
                'supplier_id': legacy.supplier_id if legacy else None,
            }]

        supplier_ids = {s.get('supplier_id') for s in snapshot if s.get('supplier_id')}
        suppliers = {}
        if supplier_ids:
            try:
                from suppliers.models import Supplier
                suppliers = {s.id: s for s in Supplier.objects.filter(id__in=supplier_ids)}
            except Exception:
                suppliers = {}

        lots, remaining = [], qty_received
        for lot in snapshot:
            if remaining <= 0:
                break
            declared = int(lot.get('qty') or 0)
            take = min(declared, remaining) if declared else remaining
            if take <= 0:
                continue
            lots.append({
                'batch_number': (override_batch_number
                                 or lot.get('batch_number')
                                 or f'TRF-{line.transfer.reference}'),
                'qty': take,
                'cost_price_per_unit': _Decimal(
                    str(lot.get('cost_price_per_unit') or line.stock.cost_price or 0)),
                'expiry_date': override_expiry or _as_date(lot.get('expiry_date'))
                               or default_expiry,
                'supplier': override_supplier or suppliers.get(lot.get('supplier_id')),
            })
            remaining -= take

        if remaining > 0:
            # Snapshot covered less than what physically arrived.
            lots.append({
                'batch_number': override_batch_number or f'TRF-{line.transfer.reference}',
                'qty': remaining,
                'cost_price_per_unit': _Decimal(str(line.stock.cost_price or 0)),
                'expiry_date': override_expiry or default_expiry,
                'supplier': override_supplier,
            })
        return lots

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        transfer = self.get_object()
        if transfer.status in (StockTransfer.Status.COMPLETED,
                               StockTransfer.Status.CANCELLED):
            return Response({'detail': 'Cannot cancel this transfer.'}, status=400)
        if transfer.status != StockTransfer.Status.REQUESTED and \
                transfer.status != StockTransfer.Status.DRAFT:
            # Once approved the source stock is already gone; cancelling would
            # delete the units from the ledger without putting them back.
            return Response(
                {'detail': 'This transfer has already shipped. Receive it, or '
                           'raise a return transfer to put the stock back.',
                 'status': transfer.status},
                status=status.HTTP_409_CONFLICT,
            )
        transfer.status = StockTransfer.Status.CANCELLED
        transfer.save(update_fields=['status'])
        self._notify_transfer(transfer, 'cancelled', request.user)
        return Response(self.get_serializer(transfer).data)

    @action(detail=True, methods=['get'], url_path='pdf')
    def pdf(self, request, pk=None):
        """Printable, branded transfer note (portrait A4).

        Uses the organisation logo uploaded at /ims/organization/profile and
        the brand palette configured at /ims/organization/branding.
        """
        import io as _io
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle, Image)
        from reportlab.lib.utils import ImageReader
        from datetime import datetime as _dtc
        from config.pdf_branding import resolve_branding

        transfer = self.get_object()
        tenant = getattr(request, 'tenant', None)
        # Logo uploaded at /ims/organization/profile; falls back to a bundled
        # default when the tenant has not uploaded one.
        logo_path, business_name = resolve_branding(request)

        def _brand(attr, default):
            """Brand colour configured at /ims/organization/branding."""
            val = getattr(tenant, attr, '') if tenant else ''
            if isinstance(val, str) and val.startswith('#') and len(val) == 7:
                try:
                    return HexColor(val)
                except Exception:
                    pass
            return HexColor(default)

        BRAND_PRIMARY = _brand('brand_primary', '#2f6dff')
        BRAND_SECONDARY = _brand('brand_secondary', '#143ce1')
        BRAND_ACCENT = _brand('brand_accent', '#37d6ff')

        def _tint(color, alpha):
            """Blend a brand colour toward white for soft backgrounds."""
            r = int(round(color.red * 255 * alpha + 255 * (1 - alpha)))
            g = int(round(color.green * 255 * alpha + 255 * (1 - alpha)))
            b = int(round(color.blue * 255 * alpha + 255 * (1 - alpha)))
            return HexColor('#%02X%02X%02X' % (r, g, b))

        NAVY = HexColor('#0F172A')
        SLATE = HexColor('#64748B')
        BORDER = HexColor('#E2E8F0')

        st_title = ParagraphStyle('t', fontName='Helvetica-Bold', fontSize=17,
                                 textColor=white, leading=20, alignment=TA_RIGHT)
        st_sub = ParagraphStyle('s', fontName='Helvetica', fontSize=9, textColor=white,
                                leading=12, alignment=TA_RIGHT)
        st_org_name = ParagraphStyle('on', fontName='Helvetica-Bold', fontSize=11,
                                     textColor=white, leading=14)
        st_org_meta = ParagraphStyle('om', fontName='Helvetica', fontSize=7,
                                     textColor=HexColor('#E2E8F0'), leading=10)
        st_h = ParagraphStyle('h', fontName='Helvetica-Bold', fontSize=10,
                              textColor=BRAND_SECONDARY)
        st_k = ParagraphStyle('k', fontName='Helvetica-Bold', fontSize=7,
                              textColor=SLATE, leading=9)
        st_v = ParagraphStyle('v', fontName='Helvetica', fontSize=9,
                              textColor=NAVY, leading=11)
        st_cell = ParagraphStyle('c', fontName='Helvetica', fontSize=8, leading=10)
        st_cell_r = ParagraphStyle('cr', parent=st_cell, alignment=TA_RIGHT)
        st_empty = ParagraphStyle('e', fontName='Helvetica-Oblique', fontSize=8,
                                  textColor=SLATE, alignment=TA_CENTER)

        def money(v):
            return f'KSh {float(v or 0):,.2f}'

        def stamp(d):
            try:
                return _dtc.fromisoformat(str(d)).strftime('%b %d %Y, %I:%M %p')
            except (TypeError, ValueError):
                return str(d or '—')

        tenant_name = getattr(getattr(request, 'tenant', None), 'name', '') or 'AdhereMed'
        status_display = transfer.get_status_display()

        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=A4,
            leftMargin=16 * mm, rightMargin=16 * mm, topMargin=14 * mm, bottomMargin=16 * mm,
            title=f'Transfer Note {transfer.reference}',
        )
        story = []

        # ── Header band: logo + organisation + document identity ────
        def fit_logo(path, max_h_mm, max_w_mm):
            try:
                if path and os.path.exists(path):
                    iw, ih = ImageReader(path).getSize()
                    th = max_h_mm * mm
                    tw = iw * (th / ih)
                    if tw > max_w_mm * mm:
                        tw = max_w_mm * mm
                        th = ih * (tw / iw)
                    return Image(path, width=tw, height=th)
            except Exception:
                pass
            return ''

        def _tv(attr):
            return (getattr(tenant, attr, '') or '') if tenant else ''

        org_logo = fit_logo(logo_path, 15, 36)
        org_addr = ', '.join(p for p in (_tv('address'), _tv('city')) if p)
        contact_bits = []
        if _tv('phone'):
            contact_bits.append(f'Tel: {_tv("phone")}')
        if _tv('email'):
            contact_bits.append(f'Email: {_tv("email")}')
        if _tv('website'):
            contact_bits.append(f'Web: {_tv("website")}')

        org_cell = [Paragraph(tenant_name, st_org_name)]
        meta_parts = [p for p in (org_addr, ' · '.join(contact_bits)) if p]
        if meta_parts:
            org_cell.append(Paragraph('<br/>'.join(meta_parts), st_org_meta))

        doc_cell = [
            Paragraph('Stock Transfer Note', st_title),
            Paragraph(f'{transfer.reference} · {status_display}',
                      ParagraphStyle('ref', parent=st_sub, fontSize=10,
                                     fontName='Helvetica-Bold')),
        ]

        head = Table([[org_logo, org_cell, doc_cell]],
                     colWidths=[40 * mm, 74 * mm, 68 * mm])
        head.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), BRAND_SECONDARY),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (0, 0), 5 * mm),
            ('RIGHTPADDING', (2, 0), (2, 0), 5 * mm),
            ('TOPPADDING', (0, 0), (-1, -1), 5 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5 * mm),
        ]))
        story.append(head)

        # Brand accent strip under the header
        accent = Table([['']], colWidths=[182 * mm], rowHeights=[1.8 * mm])
        accent.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), BRAND_ACCENT),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(accent)
        story.append(Spacer(1, 7 * mm))

        # ── Route + parties ─────────────────────────────────────────
        meta = [
            ('From (source)', transfer.source_branch.name if transfer.source_branch else '—'),
            ('To (destination)', transfer.dest_branch.name if transfer.dest_branch else '—'),
            ('Requested by', str(transfer.requested_by) if transfer.requested_by else '—'),
            ('Requested at', stamp(transfer.requested_at)),
            ('Approved / shipped by', str(transfer.approved_by) if transfer.approved_by else '—'),
            ('Shipped at', stamp(transfer.shipped_at)),
            ('Received by', str(transfer.received_by) if transfer.received_by else '—'),
            ('Received at', stamp(transfer.received_at)),
        ]
        meta_rows = [
            [Paragraph(k, st_k), Paragraph(v, st_v), Paragraph(k2, st_k), Paragraph(v2, st_v)]
            for (k, v), (k2, v2) in zip(meta[:4], meta[4:])
        ]
        meta_t = Table(meta_rows, colWidths=[32 * mm, 52 * mm, 32 * mm, 52 * mm])
        meta_t.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('LINEBELOW', (0, -1), (-1, -1), 0.75, BORDER),
        ]))
        story.append(meta_t)
        story.append(Spacer(1, 5 * mm))

        # ── Cargo, schedule & assignment ────────────────────────────
        def _or(value):
            return value if value not in (None, '') else '—'

        driver_label = (transfer.assigned_driver.full_name
                        if transfer.assigned_driver_id and transfer.assigned_driver else '—')
        carrier_label = (transfer.assigned_carrier.name
                         if transfer.assigned_carrier_id and transfer.assigned_carrier else '—')
        vehicle_label = (str(transfer.assigned_vehicle)
                         if transfer.assigned_vehicle_id and transfer.assigned_vehicle
                         else (getattr(transfer, 'assigned_vehicle_note', '') or '—'))
        cargo_rows = [
            ('Priority', _or(transfer.get_priority_display()),
             'Parcels / boxes', _or(transfer.parcel_count)),
            ('Weight', f'{transfer.weight_kg} kg' if transfer.weight_kg is not None else '—',
             'Vehicle', vehicle_label),
            ('Scheduled pickup', stamp(transfer.scheduled_pickup) if transfer.scheduled_pickup else '—',
             'Scheduled delivery', stamp(transfer.scheduled_delivery) if transfer.scheduled_delivery else '—'),
            ('Assigned driver', driver_label, 'Assigned carrier', carrier_label),
        ]
        story.append(Paragraph('Cargo, schedule &amp; assignment', st_h))
        story.append(Spacer(1, 2 * mm))
        cargo_t = Table(
            [[Paragraph(k, st_k), Paragraph(str(v), st_v),
              Paragraph(k2, st_k), Paragraph(str(v2), st_v)]
             for (k, v, k2, v2) in cargo_rows],
            colWidths=[32 * mm, 52 * mm, 32 * mm, 52 * mm],
        )
        cargo_t.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('BACKGROUND', (0, 0), (-1, -1), _tint(BRAND_PRIMARY, 0.06)),
            ('BOX', (0, 0), (-1, -1), 0.5, _tint(BRAND_PRIMARY, 0.35)),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
        ]))
        story.append(cargo_t)
        story.append(Spacer(1, 6 * mm))

        # ── Lines ───────────────────────────────────────────────────
        story.append(Paragraph('Items transferred', st_h))
        story.append(Spacer(1, 2 * mm))
        rows = [[Paragraph('Item', st_k), Paragraph('Unit', st_k),
                 Paragraph('Qty sent', st_k), Paragraph('Qty received', st_k),
                 Paragraph('Variance', st_k), Paragraph('Value (cost)', st_k)]]
        for line in transfer.lines.select_related('stock__unit').all():
            rows.append([
                Paragraph(line.stock.medication_name if line.stock else '—', st_cell),
                Paragraph(line.stock.unit.abbreviation if line.stock and line.stock.unit else '', st_cell),
                Paragraph(str(line.quantity), st_cell_r),
                Paragraph(str(line.quantity_received if line.quantity_received is not None else '—'), st_cell_r),
                Paragraph(f'{line.variance:+d}' if line.quantity_received is not None else '—', st_cell_r),
                Paragraph(money(float(line.stock.cost_price or 0) * line.quantity) if line.stock else '—', st_cell_r),
            ])
        if len(rows) == 1:
            rows.append([Paragraph('No line items on this transfer.', st_empty),
                         '', '', '', '', ''])
        total_value = sum(float(l.stock.cost_price or 0) * l.quantity
                          for l in transfer.lines.select_related('stock').all() if l.stock)
        rows.append([Paragraph('Totals', st_h), '',
                     Paragraph(str(transfer.total_quantity), ParagraphStyle('tv', parent=st_h, alignment=TA_RIGHT)),
                     Paragraph(str(sum(l.quantity_received or 0 for l in transfer.lines.all())),
                               ParagraphStyle('tv2', parent=st_h, alignment=TA_RIGHT)),
                     '', Paragraph(money(total_value), ParagraphStyle('tv3', parent=st_h, alignment=TA_RIGHT))])
        lines_t = Table(rows, colWidths=[74 * mm, 14 * mm, 20 * mm, 22 * mm, 18 * mm, 30 * mm],
                        repeatRows=1)
        lines_t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), _tint(BRAND_PRIMARY, 0.16)),
            ('GRID', (0, 0), (-1, -1), 0.5, BORDER),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('BACKGROUND', (0, -1), (-1, -1), _tint(BRAND_PRIMARY, 0.08)),
            ('LINEABOVE', (0, 0), (-1, 0), 1, BRAND_PRIMARY),
            ('LINEBELOW', (0, -1), (-1, -1), 1, BRAND_PRIMARY),
        ]))
        story.append(lines_t)

        if transfer.notes:
            story.append(Spacer(1, 5 * mm))
            story.append(Paragraph('Notes', st_h))
            story.append(Paragraph(transfer.notes, st_cell))

        story.append(Spacer(1, 8 * mm))
        story.append(Paragraph(
            'Received in good condition — quantities verified against this note.',
            ParagraphStyle('sig', parent=st_cell, fontSize=8)))
        story.append(Spacer(1, 6 * mm))

        # ── Digital signatures captured in the approval / receive dialogs ──
        import base64 as _b64

        def _sig_image(data_url):
            """Decode a base64 image data-URL into a ReportLab flowable."""
            if not data_url or ';base64,' not in data_url:
                return None
            try:
                raw = _b64.b64decode(data_url.split(';base64,', 1)[1])
                return Image(_io.BytesIO(raw), width=56 * mm, height=17 * mm,
                             kind='proportional')
            except Exception:
                return None

        st_sig_meta = ParagraphStyle('sigm', parent=st_cell, fontSize=7.5,
                                     textColor=NAVY, leading=9.5)
        st_sig_label = ParagraphStyle('sigl', parent=st_k, fontSize=7)

        def _sig_block(label, data_url, person, when):
            img = _sig_image(data_url)
            stack = [img] if img is not None else [
                Spacer(1, 15 * mm),
                Paragraph('Not signed', st_empty),
            ]
            meta = person or '—'
            if when:
                meta = f'{meta} · {stamp(when)}'
            stack.append(Paragraph(meta, st_sig_meta))
            stack.append(Paragraph(label, st_sig_label))
            return stack

        sig = Table(
            [[
                _sig_block('Approved &amp; shipped by', transfer.approved_signature,
                           str(transfer.approved_by) if transfer.approved_by else '',
                           transfer.shipped_at),
                _sig_block('Received by', transfer.received_signature,
                           str(transfer.received_by) if transfer.received_by else '',
                           transfer.received_at),
            ]],
            colWidths=[89 * mm, 89 * mm],
        )
        sig.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'BOTTOM'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 8),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ('LINEBELOW', (0, 0), (0, 0), 0.75, BRAND_SECONDARY),
            ('LINEBELOW', (1, 0), (1, 0), 0.75, BRAND_SECONDARY),
        ]))
        story.append(sig)

        def _page(canv, doc_):
            canv.saveState()
            # Thin brand rule above the footer text
            canv.setStrokeColor(BRAND_ACCENT)
            canv.setLineWidth(1.2)
            canv.line(16 * mm, 11.5 * mm, 194 * mm, 11.5 * mm)

            canv.setFont('Helvetica', 7)
            canv.setFillColor(SLATE)
            canv.drawString(16 * mm, 8 * mm,
                            f'{tenant_name} · Stock Transfer {transfer.reference}')
            canv.drawRightString(194 * mm, 8 * mm,
                                 f'Page {canv.getPageNumber()} · Generated {timezone.now():%b %d %Y}')

            # Centre the platform credit between the two footer strings.
            from reportlab.pdfbase.pdfmetrics import stringWidth
            p_lead = 'Powered by '
            p_brand = 'AdhereMed'
            p_tail = '  ·  www.adheremed.co'
            w_lead = stringWidth(p_lead, 'Helvetica', 6.5)
            w_brand = stringWidth(p_brand, 'Helvetica-Bold', 6.5)
            w_tail = stringWidth(p_tail, 'Helvetica', 6.5)
            x = (210 * mm - (w_lead + w_brand + w_tail)) / 2
            canv.setFont('Helvetica', 6.5)
            canv.setFillColor(SLATE)
            canv.drawString(x, 8 * mm, p_lead)
            canv.setFont('Helvetica-Bold', 6.5)
            canv.setFillColor(BRAND_PRIMARY)
            canv.drawString(x + w_lead, 8 * mm, p_brand)
            canv.setFont('Helvetica', 6.5)
            canv.setFillColor(SLATE)
            canv.drawString(x + w_lead + w_brand, 8 * mm, p_tail)
            canv.restoreState()

        doc.build(story, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={'Content-Disposition':
                     f'attachment; filename="transfer_{transfer.reference}.pdf"'},
        )

    @action(detail=False, methods=['get'])
    def export(self, request):
        """CSV export of the (filtered) transfer list."""
        qs = self.filter_queryset(self.get_queryset())

        def money(v):
            try:
                return f'{float(v or 0):.2f}'
            except (TypeError, ValueError):
                return '0.00'

        out = io.StringIO()
        writer = csv.writer(out)
        writer.writerow(['reference', 'status', 'source', 'destination',
                         'items', 'units', 'value (KSh)', 'variance',
                         'requested_by', 'requested_at', 'shipped_at', 'received_at'])
        for t in qs:
            writer.writerow([
                t.reference, t.status,
                t.source_branch.name if t.source_branch else '',
                t.dest_branch.name if t.dest_branch else '',
                t.total_items, t.total_quantity,
                money(sum(float(l.stock.cost_price or 0) * l.quantity
                          for l in t.lines.select_related('stock').all() if l.stock)),
                sum(l.variance for l in t.lines.all()),
                str(t.requested_by) if t.requested_by else '',
                t.requested_at or '', t.shipped_at or '', t.received_at or '',
            ])
        return HttpResponse(
            out.getvalue(),
            content_type='text/csv',
            headers={'Content-Disposition':
                     f'attachment; filename="stock_transfers_{timezone.now():%Y%m%d}.csv"'},
        )
