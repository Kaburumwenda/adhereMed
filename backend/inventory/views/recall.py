"""Recall / withdrawal API and PDF report (Tier 3)."""
from __future__ import annotations

import io

from django.utils import timezone
from rest_framework import serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from ..models import RecallCase, RecallLine, StockBatch
from ..rbac import InventoryPermission, has_capability
from ..services import recall as recall_service
from ..services import traceability
from .base import _audit, _forced_branch_id


class RecallLineSerializer(serializers.ModelSerializer):
    touch_label = serializers.CharField(source='get_touch_display', read_only=True)
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True, default='')
    branch_name = serializers.CharField(source='branch.name', read_only=True, default='')
    batch_number = serializers.CharField(source='batch.batch_number', read_only=True, default='')

    class Meta:
        model = RecallLine
        fields = ['id', 'touch', 'touch_label', 'stock', 'stock_name',
                  'batch', 'batch_number', 'branch', 'branch_name',
                  'quantity_on_hand', 'quantity_downstream', 'reference',
                  'detail', 'occurred_at', 'is_confirmed']
        read_only_fields = fields


class RecallTargetBatchSerializer(serializers.ModelSerializer):
    """One physical shelf row that a recall case covers."""
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True, default='')
    medication_id = serializers.CharField(source='stock.medication_id', read_only=True, default='')
    unit = serializers.CharField(source='stock.unit.abbreviation', read_only=True, default='')
    branch_name = serializers.CharField(source='branch.name', read_only=True, default='')
    supplier_name = serializers.CharField(source='supplier.name', read_only=True, default='')
    days_to_expiry = serializers.IntegerField(read_only=True, allow_null=True)
    is_expired = serializers.BooleanField(read_only=True)

    class Meta:
        model = StockBatch
        fields = ['id', 'batch_number', 'stock', 'stock_name', 'medication_id',
                  'unit', 'branch', 'branch_name', 'supplier_name',
                  'quantity_received', 'quantity_remaining', 'expiry_date',
                  'received_date', 'days_to_expiry', 'is_expired',
                  'is_blocked', 'blocked_reason']
        read_only_fields = fields


class RecallCaseSerializer(serializers.ModelSerializer):
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    reason_label = serializers.CharField(source='get_reason_display', read_only=True)
    severity_label = serializers.CharField(source='get_severity_display', read_only=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True, default=None)
    units_on_hand = serializers.IntegerField(read_only=True)
    units_downstream = serializers.IntegerField(read_only=True)
    lines = RecallLineSerializer(many=True, read_only=True)
    impact = serializers.SerializerMethodField()

    # Write: the shelf rows hand-picked in the "Open a recall" dialog.
    target_batch_ids = serializers.ListField(
        child=serializers.IntegerField(), required=False, allow_empty=True,
        write_only=True)
    # Read: the same rows, expanded so the workspace can list what is covered.
    target_batches = serializers.SerializerMethodField()
    target_count = serializers.SerializerMethodField()
    scope_label = serializers.SerializerMethodField()
    units_blocked = serializers.SerializerMethodField()

    class Meta:
        model = RecallCase
        fields = [
            'id', 'reference', 'title', 'reason', 'reason_label',
            'severity', 'severity_label', 'status', 'status_label',
            'batch_number', 'medication_name', 'external_reference',
            'notes', 'began_at', 'completed_at',
            'created_by', 'created_by_name', 'created_at', 'updated_at',
            'units_on_hand', 'units_downstream', 'lines', 'impact',
            'target_batch_ids', 'target_batches', 'target_count', 'scope_label',
            'units_blocked',
        ]
        read_only_fields = ['id', 'reference', 'created_by', 'created_at',
                            'updated_at', 'completed_at']

    def get_impact(self, obj):
        return recall_service.recall_impact(obj)

    def get_target_batches(self, obj):
        ids = [int(i) for i in (obj.target_batch_ids or [])
               if str(i).lstrip('-').isdigit()]
        if not ids:
            return []
        rows = (StockBatch.objects
                .filter(id__in=ids)
                .select_related('stock', 'stock__unit', 'branch', 'supplier')
                .order_by('stock__medication_name', 'expiry_date'))
        return RecallTargetBatchSerializer(rows, many=True).data

    def get_target_count(self, obj):
        return len([i for i in (obj.target_batch_ids or [])
                    if str(i).lstrip('-').isdigit()])

    def get_units_blocked(self, obj):
        """Units this case has locked — the figure that proves they cannot sell."""
        return recall_service.blocked_units_for(obj)

    def get_scope_label(self, obj):
        if self.get_target_count(obj):
            return 'Selected lot rows'
        if obj.batch_number:
            return 'Entire lot'
        return 'Entire medication'

    # ── scope helpers ───────────────────────────────────────────────────
    @staticmethod
    def _clean_ids(batch_ids):
        out = []
        for raw in batch_ids or []:
            try:
                out.append(int(raw))
            except (TypeError, ValueError):
                continue
        return sorted(set(out))

    def _apply_scope(self, case, batch_ids):
        """Persist the picked rows and backfill lot / item labels.

        The lot number and medication name drive the audit trail and the PDF,
        so they are filled from the selection when the caller left them blank
        rather than forcing the UI to duplicate what it already knows.
        """
        ids = self._clean_ids(batch_ids)
        case.target_batch_ids = ids
        fields = ['target_batch_ids', 'updated_at']

        if ids:
            first = (StockBatch.objects.filter(id__in=ids)
                     .select_related('stock').first())
            if first:
                if not case.batch_number:
                    case.batch_number = first.batch_number
                    fields.append('batch_number')
                if not case.medication_name and first.stock_id:
                    case.medication_name = first.stock.medication_name
                    fields.append('medication_name')

        case.save(update_fields=fields)
        return case

    def validate(self, attrs):
        batch_ids = attrs.get('target_batch_ids')
        has_scope = bool(self._clean_ids(batch_ids)) if batch_ids is not None else False
        batch_number = (attrs.get('batch_number')
                        or getattr(self.instance, 'batch_number', '') or '').strip()
        medication = (attrs.get('medication_name')
                      or getattr(self.instance, 'medication_name', '') or '').strip()
        if not has_scope and not batch_number and not medication:
            raise serializers.ValidationError({
                'batch_number': ('Pick at least one lot row, or give a lot '
                                 'number / medication name to trace.'),
            })
        return attrs

    def create(self, validated_data):
        batch_ids = validated_data.pop('target_batch_ids', [])
        case = super().create(validated_data)
        return self._apply_scope(case, batch_ids)

    def update(self, instance, validated_data):
        batch_ids = validated_data.pop('target_batch_ids', None)
        case = super().update(instance, validated_data)
        if batch_ids is not None:
            case = self._apply_scope(case, batch_ids)
        return case


class RecallCaseViewSet(viewsets.ModelViewSet):
    """Recall / market-withdrawal workflow."""
    serializer_class = RecallCaseSerializer
    permission_classes = [InventoryPermission]
    filter_backends = []
    queryset = RecallCase.objects.select_related('created_by').all()

    def get_queryset(self):
        qs = super().get_queryset()
        status_param = self.request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param)
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(title__icontains=search) | qs.filter(
                batch_number__icontains=search) | qs.filter(
                reference__icontains=search)
        return qs

    def perform_create(self, serializer):
        case = serializer.save(
            created_by=self.request.user if self.request.user.is_authenticated else None)
        _audit(self.request, 'recall_create', case,
               description=f'Opened recall {case.reference}: {case.title}',
               severity='warning',
               payload_diff={'batch_number': case.batch_number,
                             'medication': case.medication_name,
                             'scope': ('selected batch rows'
                                       if case.target_batch_ids else 'whole lot'),
                             'batch_ids': case.target_batch_ids,
                             'reason': case.reason})

    # ── Lookup helpers used by the "Open a recall" dialog ───────────────
    def _scoped_batch_qs(self, request):
        """Batches the reader may see, mirroring the trace pages' scope."""
        from django.db.models import Q

        qs = StockBatch.objects.all()
        forced = _forced_branch_id(request.user)
        branch = request.query_params.get('branch')
        if forced:
            qs = qs.filter(Q(branch_id=forced)
                           | Q(branch__isnull=True, stock__branch_id=forced)
                           | Q(branch__isnull=True, stock__branch__isnull=True))
        elif branch and str(branch).isdigit():
            qs = qs.filter(Q(branch_id=int(branch)) | Q(branch__isnull=True))
        return qs

    @action(detail=False, methods=['get'], url_path='lot-search')
    def lot_search(self, request):
        """Searchable lot numbers for the recall dialog.

        Aggregated by lot number (the same lot routinely spans several items
        and warehouses) so the picker never offers the same lot twice.
        """
        params = request.query_params
        try:
            limit = min(max(int(params.get('limit') or 40), 1), 200)
        except (TypeError, ValueError):
            limit = 40
        search = (params.get('q') or '').strip()
        rows = traceability.batch_candidates(
            self._scoped_batch_qs(request), search=search, limit=limit)
        return Response({'results': rows, 'count': len(rows), 'search': search})

    @action(detail=False, methods=['get'], url_path='lot-items')
    def lot_items(self, request):
        """Every shelf row carrying one lot number — the recall work list."""
        lot = (request.query_params.get('lot') or '').strip()
        if not lot:
            return Response({'detail': 'A lot number is required.'}, status=400)

        rows = (self._scoped_batch_qs(request)
                .filter(batch_number__iexact=lot)
                .select_related('stock', 'stock__unit', 'branch', 'supplier')
                .order_by('stock__medication_name', 'expiry_date'))

        payload = RecallTargetBatchSerializer(rows, many=True).data
        totals = {
            'rows': len(payload),
            'items': len({r['stock'] for r in payload}),
            'branches': len({r['branch'] for r in payload if r['branch']}),
            'on_hand': sum(int(r['quantity_remaining'] or 0) for r in payload),
            'received': sum(int(r['quantity_received'] or 0) for r in payload),
            'expired': sum(1 for r in payload
                           if r['expiry_date'] and r['days_to_expiry'] is not None
                           and r['days_to_expiry'] < 0),
            'blocked': sum(1 for r in payload if r['is_blocked']),
            'depleted': sum(1 for r in payload if not r['quantity_remaining']),
        }
        return Response({'lot': lot, 'results': payload, 'totals': totals})

    @action(detail=True, methods=['post'])
    def trace(self, request, pk=None):
        """Re-run the downstream trace (on hand, transfers, POS, dispensing)."""
        case = self.get_object()
        totals = recall_service.trace_case(case)
        _audit(request, 'recall_trace', case,
               description=f'Traced {case.reference}: {totals["lines"]} location(s)',
               payload_diff=totals)
        case.refresh_from_db()
        return Response({
            **self.get_serializer(case).data,
            'trace': totals,
        })

    @action(detail=True, methods=['post'])
    def quarantine(self, request, pk=None):
        """Block every traced batch and quarantine the affected items."""
        case = self.get_object()
        if case.status in (RecallCase.Status.COMPLETED, RecallCase.Status.CANCELLED):
            return Response({'detail': 'This recall is already closed.'},
                            status=status.HTTP_409_CONFLICT)
        result = recall_service.quarantine_case(case, user=request.user)
        _audit(request, 'recall_quarant', case, severity='critical',
               description=f'Quarantined recall {case.reference}',
               payload_diff=result)
        case.refresh_from_db()
        return Response({**self.get_serializer(case).data, 'quarantine': result})

    @action(detail=True, methods=['post'])
    def close(self, request, pk=None):
        case = self.get_object()
        result = recall_service.release_case(
            case, user=request.user, note=request.data.get('note', ''))
        _audit(request, 'recall_close', case,
               description=f'Closed recall {case.reference}', payload_diff=result)
        case.refresh_from_db()
        return Response({**self.get_serializer(case).data, 'release': result})

    @action(detail=True, methods=['post'], url_path='confirm-line')
    def confirm_line(self, request, pk=None):
        """Mark a traced location as physically verified."""
        case = self.get_object()
        line_id = request.data.get('line_id')
        line = case.lines.filter(id=line_id).first()
        if not line:
            return Response({'detail': 'Line not found.'}, status=404)
        line.is_confirmed = True
        line.save(update_fields=['is_confirmed'])
        return Response(RecallLineSerializer(line).data)

    @action(detail=True, methods=['get'], url_path='pdf')
    def pdf(self, request, pk=None):
        """Printable recall notice with the full trace."""
        case = self.get_object()
        return _render_recall_pdf(request, case)


def _render_recall_pdf(request, case):
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_RIGHT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.platypus import (Paragraph, SimpleDocTemplate, Spacer,
                                    Table, TableStyle)

    from django.http import HttpResponse

    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm,
        topMargin=15 * mm, bottomMargin=15 * mm,
        title=f'Recall {case.reference}')

    ink = colors.HexColor('#0F172A')
    muted = colors.HexColor('#64748B')
    danger = colors.HexColor('#DC2626')
    rule = colors.HexColor('#E2E8F0')

    st_title = ParagraphStyle('t', fontName='Helvetica-Bold', fontSize=18,
                              textColor=ink, leading=22)
    st_sub = ParagraphStyle('s', fontName='Helvetica', fontSize=9,
                            textColor=muted, leading=13)
    st_h = ParagraphStyle('h', fontName='Helvetica-Bold', fontSize=10.5,
                          textColor=ink, leading=14, spaceBefore=10)
    st_cell = ParagraphStyle('c', fontName='Helvetica', fontSize=8, leading=10)
    st_cell_r = ParagraphStyle('cr', parent=st_cell, alignment=TA_RIGHT)

    business_name = getattr(getattr(request, 'tenant', None), 'name', '') or ''

    story = [
        Paragraph('RECALL / MARKET WITHDRAWAL', st_title),
        Paragraph(f'{case.reference} · {case.get_severity_display()} severity · '
                  f'{case.get_status_display()}', st_sub),
        Spacer(1, 6),
    ]

    header_rows = [
        ['Title', case.title],
        ['Reason', case.get_reason_display()],
        ['Medication', case.medication_name or '—'],
        ['Batch / lot', case.batch_number or '—'],
        ['Scope', (f'{len(case.target_batch_ids)} selected lot row(s)'
                   if case.target_batch_ids else 'Whole lot / medication')],
        ['External ref.', case.external_reference or '—'],
        ['Began', case.began_at.isoformat()],
        ['Organisation', business_name],
    ]
    table = Table(
        [[Paragraph(f'<b>{k}</b>', st_cell), Paragraph(str(v), st_cell)]
         for k, v in header_rows],
        colWidths=[35 * mm, 145 * mm])
    table.setStyle(TableStyle([
        ('GRID', (0, 0), (-1, -1), 0.4, rule),
        ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#F8FAFC')),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story += [table]

    impact = recall_service.recall_impact(case)
    story.append(Paragraph('Impact summary', st_h))
    summary_rows = [
        ['Units still on hand', str(impact['units_on_hand'])],
        ['Units already dispatched', str(impact['units_downstream'])],
        ['Recoverable', f'{impact["recoverable_pct"]}%'],
    ]
    st = Table(
        [[Paragraph(f'<b>{k}</b>', st_cell), Paragraph(v, st_cell_r)]
         for k, v in summary_rows],
        colWidths=[80 * mm, 100 * mm])
    st.setStyle(TableStyle([
        ('GRID', (0, 0), (-1, -1), 0.4, rule),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story += [st]

    story.append(Paragraph('Traced locations', st_h))
    head = ['Type', 'Reference', 'Item', 'Branch', 'On hand', 'Dispatched', 'Detail']
    rows = [[Paragraph(f'<b>{h}</b>', st_cell) for h in head]]
    for line in case.lines.all()[:200]:
        rows.append([
            Paragraph(line.get_touch_display(), st_cell),
            Paragraph(line.reference or '—', st_cell),
            Paragraph(line.stock.medication_name if line.stock else '—', st_cell),
            Paragraph(line.branch.name if line.branch else '—', st_cell),
            Paragraph(str(line.quantity_on_hand), st_cell_r),
            Paragraph(str(line.quantity_downstream), st_cell_r),
            Paragraph((line.detail or '')[:70], st_cell),
        ])
    if len(rows) == 1:
        rows.append([Paragraph('No traced locations yet.', st_cell)] + [''] * 6)
    detail = Table(rows, repeatRows=1,
                   colWidths=[26 * mm, 26 * mm, 42 * mm, 28 * mm, 15 * mm, 18 * mm, 25 * mm])
    detail.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#FEF2F2')),
        ('GRID', (0, 0), (-1, -1), 0.4, rule),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 3),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ]))
    story += [detail,
              Spacer(1, 10),
              Paragraph(f'Generated {timezone.localtime():%b %d %Y %I:%M %p} · '
                        f'Powered by AdhereMed', st_sub)]

    doc.build(story)
    buf.seek(0)
    response = HttpResponse(buf.getvalue(), content_type='application/pdf')
    response['Content-Disposition'] = (
        f'attachment; filename="recall_{case.reference}.pdf"')
    return response


class RecallSummaryView(viewsets.ViewSet):
    """Dashboard counters for the recall workspace."""
    permission_classes = [InventoryPermission]

    def list(self, request):
        qs = RecallCase.objects.all()
        open_cases = qs.exclude(status__in=[
            RecallCase.Status.COMPLETED, RecallCase.Status.CANCELLED])
        rows = list(open_cases.select_related().prefetch_related('lines'))

        locked = sum(recall_service.blocked_units_for(c) for c in rows)
        pending = sum(c.units_on_hand for c in rows
                      if c.status != RecallCase.Status.QUARANTINED)
        return Response({
            'open': open_cases.count(),
            'critical': open_cases.filter(severity='critical').count(),
            # Units actually blocked by a recall right now — these cannot be
            # sold, dispensed or allocated until the case is closed.
            'units_quarantined': locked,
            'units_pending': pending,
            'units_dispatched': sum(c.units_downstream for c in rows),
            'completed': qs.filter(status=RecallCase.Status.COMPLETED).count(),
            'recent': [{
                'id': c.id,
                'reference': c.reference,
                'title': c.title,
                'severity': c.severity,
                'status': c.status,
                'batch_number': c.batch_number,
                'units_on_hand': c.units_on_hand,
                'units_blocked': recall_service.blocked_units_for(c),
                'units_downstream': c.units_downstream,
                'created_at': c.created_at.isoformat(timespec='seconds'),
            } for c in qs.order_by('-created_at')[:8]],
        })
