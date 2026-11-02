"""Warehouse execution API (Tier 4): bins, putaway, pick, scans, labels."""
from __future__ import annotations

from django.http import HttpResponse
from rest_framework import serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import (MedicationStock, ScanVerification, StockPlacement,
                      WarehouseBin)
from ..rbac import InventoryPermission
from ..services import bins as bin_service
from ..services import labels as label_service
from ..services import scanning
from .base import _forced_branch_id


class WarehouseBinSerializer(serializers.ModelSerializer):
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    zone_name = serializers.CharField(
        source='storage_zone.name', read_only=True, default='')
    code = serializers.CharField(source='canonical', read_only=True)
    used_units = serializers.IntegerField(read_only=True)
    free_units = serializers.IntegerField(read_only=True)
    fill_pct = serializers.IntegerField(read_only=True)
    skus = serializers.SerializerMethodField()

    class Meta:
        model = WarehouseBin
        fields = ['id', 'branch', 'branch_name', 'zone', 'aisle', 'rack',
                  'bin_code', 'name', 'code', 'capacity_units', 'storage_zone',
                  'zone_name', 'is_active', 'used_units', 'free_units',
                  'fill_pct', 'skus', 'created_at']
        read_only_fields = ['id', 'code', 'used_units', 'free_units',
                            'fill_pct', 'skus', 'created_at']

    def get_skus(self, obj):
        return obj.placements.values('stock_id').distinct().count()


class StockPlacementSerializer(serializers.ModelSerializer):
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    bin_code = serializers.CharField(source='bin.canonical', read_only=True)
    batch_number = serializers.CharField(
        source='batch.batch_number', read_only=True, default='')

    class Meta:
        model = StockPlacement
        fields = ['id', 'bin', 'bin_code', 'stock', 'stock_name', 'batch',
                  'batch_number', 'quantity', 'updated_at']
        read_only_fields = ['id', 'updated_at']


class WarehouseBinViewSet(viewsets.ModelViewSet):
    serializer_class = WarehouseBinSerializer
    permission_classes = [InventoryPermission]

    def get_queryset(self):
        qs = WarehouseBin.objects.select_related('branch', 'storage_zone')
        branch = self.request.query_params.get('branch')
        if branch:
            qs = qs.filter(branch_id=branch)
        if self.request.query_params.get('active') in ('1', 'true'):
            qs = qs.filter(is_active=True)
        return qs

    @action(detail=False, methods=['get'])
    def utilisation(self, request):
        return Response({'results': bin_service.bin_utilisation(
            branch_id=request.query_params.get('branch'))})

    @action(detail=False, methods=['get'])
    def unplaced(self, request):
        return Response({'results': bin_service.unplaced_stock(
            branch_id=request.query_params.get('branch'))})

    @action(detail=False, methods=['get'])
    def pick_list(self, request):
        return Response({'results': bin_service.pick_list(
            branch_id=request.query_params.get('branch'),
            limit=int(request.query_params.get('limit', 50) or 50))})

    @action(detail=False, methods=['post'])
    def putaway(self, request):
        """Suggest (and optionally apply) a bin for a stock item."""
        stock = MedicationStock.objects.filter(
            id=request.data.get('stock')).first()
        if not stock:
            return Response({'detail': 'Stock item not found.'}, status=404)
        quantity = int(request.data.get('quantity') or 0)

        suggestion = bin_service.suggest_putaway(stock, quantity)
        if not suggestion:
            return Response({'detail': 'No compatible bin available.'}, status=400)

        applied = None
        if request.data.get('apply'):
            bin_obj = suggestion['bin']
            batch = None
            if request.data.get('batch'):
                batch = stock.batches.filter(id=request.data['batch']).first()
            placement = bin_service.place_stock(stock, bin_obj, quantity, batch=batch)
            applied = StockPlacementSerializer(placement).data

        free = suggestion['bin'].free_units
        return Response({
            'suggestion': {
                'bin_id': suggestion['bin'].id,
                'code': suggestion['bin'].canonical,
                'name': suggestion['bin'].name,
                'free_units': free,
                'quantity': quantity,
                # Explicit flag so the UI can warn before over-filling a bin:
                # the service falls back to "least bad" when nothing fits.
                'over_capacity': bool(free is not None and quantity > free),
                'reason': suggestion['reason'],
            },
            'placement': applied,
        })


class StockPlacementViewSet(viewsets.ModelViewSet):
    serializer_class = StockPlacementSerializer
    permission_classes = [InventoryPermission]

    def get_queryset(self):
        qs = StockPlacement.objects.select_related('bin', 'stock', 'batch')
        if self.request.query_params.get('bin'):
            qs = qs.filter(bin_id=self.request.query_params['bin'])
        if self.request.query_params.get('stock'):
            qs = qs.filter(stock_id=self.request.query_params['stock'])
        return qs

    @action(detail=True, methods=['post'])
    def move(self, request, pk=None):
        placement = self.get_object()
        target = WarehouseBin.objects.filter(id=request.data.get('bin')).first()
        if not target:
            return Response({'detail': 'Target bin not found.'}, status=404)
        moved = bin_service.move_placement(placement, target)
        return Response(StockPlacementSerializer(moved).data)


class ScanVerifyView(APIView):
    """Scan-to-verify: resolve a code, audit the result, and report the picture.

    ``GET`` serves both the history and the headline figures the page needs, so
    the screen renders from one request instead of three. Everything reported is
    derived from the audit trail rather than recomputed, so the tiles can never
    disagree with the list beneath them.
    """
    permission_classes = [InventoryPermission]

    def post(self, request):
        code = request.data.get('code')
        context = request.data.get('context', 'receive')
        expected = None
        if request.data.get('expected_stock'):
            expected = MedicationStock.objects.filter(
                id=request.data['expected_stock']).first()

        result = scanning.verify_scan(
            code=code,
            context=context,
            expected_stock=expected,
            user=request.user,
            reference=request.data.get('reference', ''),
            quantity=int(request.data.get('quantity') or 0),
            branch_id=request.data.get('branch'),
        )
        status_code = 200 if result['is_match'] else status.HTTP_409_CONFLICT
        return Response(result, status=status_code)

    def get(self, request):
        params = request.query_params
        try:
            days = min(max(int(params.get('days') or 30), 1), 365)
        except (TypeError, ValueError):
            days = 30
        try:
            limit = min(max(int(params.get('limit') or 100), 1), 500)
        except (TypeError, ValueError):
            limit = 100

        branch_id = _forced_branch_id(request.user) or params.get('branch')
        try:
            branch_id = int(branch_id) if branch_id else None
        except (TypeError, ValueError):
            branch_id = None

        return Response({
            'results': scanning.scan_history(
                context=params.get('context') or None,
                only_mismatches=params.get('mismatches') in ('1', 'true'),
                limit=limit,
                search=(params.get('search') or '').strip(),
                branch_id=branch_id,
                days=days,
            ),
            'analytics': scanning.scan_analytics(branch_id=branch_id, days=days),
            'contexts': [{'value': value, 'label': label}
                         for value, label in ScanVerification.Context.choices],
            'resolution_steps': scanning.RESOLUTION_STEPS,
            'branch_scope': {
                'locked': bool(_forced_branch_id(request.user)),
                'branch_id': branch_id,
            },
            'expiry_warn_days': scanning.EXPIRY_WARN_DAYS,
        })


class LabelPrintView(APIView):
    """Printable GS1-style lot label sheet."""
    permission_classes = [InventoryPermission]

    def get(self, request):
        ids = request.query_params.get('stocks', '')
        branch = request.query_params.get('branch')
        category = request.query_params.get('category')
        classification = request.query_params.get('classification')
        search = (request.query_params.get('search') or '').strip()

        qs = MedicationStock.objects.select_related('branch', 'category',
                                                    'classification')

        if ids:
            # An explicit selection always wins — the filters only shape the
            # "print everything that matches" path.
            try:
                wanted = [int(v) for v in ids.split(',') if v.strip()]
            except ValueError:
                return Response({'detail': 'stocks must be a comma-separated list of ids.'},
                                status=400)
            qs = qs.filter(id__in=wanted)
        else:
            qs = qs.filter(is_active=True)
            if branch:
                qs = qs.filter(branch_id=branch)
            if category:
                qs = qs.filter(category_id=category)
            if classification:
                qs = qs.filter(classification_id=classification)
            if search:
                qs = qs.filter(medication_name__icontains=search)

        stocks = list(qs[:200])
        if not stocks:
            return Response({'detail': 'No stock items selected.'}, status=400)

        rows = label_service.stock_label_rows(stocks)

        # ── Letterhead: tenant logo + the details from
        # /ims/organization/profile (i.e. Tenant.name / address / city /
        # country / phone / email / website + tenant.logo) ────────────────
        tenant = getattr(request, 'tenant', None)
        try:
            from config.pdf_branding import resolve_branding, resolve_palette
            logo_path, business_name = resolve_branding(request)
            palette = resolve_palette(request)
        except Exception:
            logo_path, business_name = None, ''
            palette = None

        org = {
            'name': (getattr(tenant, 'name', '') or business_name or ''),
            'address': getattr(tenant, 'address', '') or '',
            'city': getattr(tenant, 'city', '') or '',
            'country': getattr(tenant, 'country', '') or '',
            'phone': getattr(tenant, 'phone', '') or '',
            'email': getattr(tenant, 'email', '') or '',
            'website': getattr(tenant, 'website', '') or '',
        }

        # Name the scope on the sheet so a filtered print is self-documenting.
        meta_extra = []
        branch_names = sorted({s.branch.name for s in stocks if s.branch_id})
        if branch and branch_names:
            meta_extra.append('Warehouse: ' + ', '.join(branch_names))
        elif len(branch_names) > 1:
            meta_extra.append(f'{len(branch_names)} warehouses')

        category_names = sorted({s.category.name for s in stocks if s.category_id})
        if category and category_names:
            meta_extra.append('Category: ' + ', '.join(category_names))
        if classification:
            class_names = sorted({s.classification.name
                                  for s in stocks if s.classification_id})
            if class_names:
                meta_extra.append('Type: ' + ', '.join(class_names))
        if search:
            meta_extra.append(f'Search: "{search}"')

        pdf = label_service.build_label_pdf(
            rows,
            title='Stock labels',
            business_name=org['name'],
            logo_path=logo_path,
            org=org,
            meta_extra=meta_extra,
            palette=palette,
        )
        response = HttpResponse(pdf, content_type='application/pdf')
        response['Content-Disposition'] = (
            f'inline; filename="stock_labels_{len(rows)}.pdf"')
        return response
