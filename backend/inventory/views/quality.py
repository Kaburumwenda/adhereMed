"""Quality & compliance API (Tier 3): cold chain, certificates, audit export."""
from __future__ import annotations

import csv
import io
from datetime import timedelta

from django.http import HttpResponse
from django.utils import timezone
from rest_framework import serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import StockBatch, SupplierCertificate, TemperatureExcursion
from ..rbac import InventoryPermission
from ..services import quality
from .base import _audit


class TemperatureExcursionSerializer(serializers.ModelSerializer):
    zone_name = serializers.CharField(source='zone.name', read_only=True, default='')
    batch_number = serializers.CharField(
        source='batch.batch_number', read_only=True, default='')
    stock_name = serializers.CharField(
        source='batch.stock.medication_name', read_only=True, default='')
    severity_label = serializers.CharField(
        source='get_severity_display', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    recorded_by_name = serializers.CharField(
        source='recorded_by.full_name', read_only=True, default='')

    class Meta:
        model = TemperatureExcursion
        fields = ['id', 'zone', 'zone_name', 'batch', 'batch_number', 'stock_name',
                  'recorded_temp_c', 'allowed_min_c', 'allowed_max_c',
                  'started_at', 'ended_at', 'severity', 'severity_label',
                  'status', 'status_label', 'action_taken', 'auto_quarantined',
                  'recorded_by', 'recorded_by_name', 'created_at']
        read_only_fields = ['id', 'severity', 'auto_quarantined',
                            'recorded_by', 'created_at']


class TemperatureExcursionViewSet(viewsets.ModelViewSet):
    serializer_class = TemperatureExcursionSerializer
    permission_classes = [InventoryPermission]

    def get_queryset(self):
        qs = TemperatureExcursion.objects.select_related(
            'zone', 'batch', 'batch__stock', 'recorded_by')
        if self.request.query_params.get('status'):
            qs = qs.filter(status=self.request.query_params['status'])
        if self.request.query_params.get('severity'):
            qs = qs.filter(severity=self.request.query_params['severity'])
        return qs

    def create(self, request, *args, **kwargs):
        """Record a reading through the service so grading/quarantine apply."""
        from ..models import StorageZone

        zone = None
        if request.data.get('zone'):
            zone = StorageZone.objects.filter(id=request.data['zone']).first()
        batch = None
        if request.data.get('batch'):
            batch = StockBatch.objects.filter(id=request.data['batch']).first()

        excursion = quality.log_excursion(
            recorded_temp_c=request.data.get('recorded_temp_c'),
            zone=zone,
            batch=batch,
            started_at=request.data.get('started_at') or timezone.now(),
            ended_at=request.data.get('ended_at'),
            user=request.user,
            notes=request.data.get('action_taken', ''),
        )
        _audit(request, 'coldchain_event', excursion,
               severity='critical' if excursion.severity == 'critical' else 'warning',
               description=f'Temperature {excursion.recorded_temp_c} °C '
                           f'({excursion.severity})',
               payload_diff={'batch_id': excursion.batch_id,
                             'auto_quarantined': excursion.auto_quarantined})
        return Response(self.get_serializer(excursion).data,
                        status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def resolve(self, request, pk=None):
        excursion = self.get_object()
        excursion.status = TemperatureExcursion.Status.RESOLVED
        excursion.ended_at = request.data.get('ended_at') or timezone.now()
        excursion.action_taken = (request.data.get('action_taken')
                                  or excursion.action_taken)
        excursion.save(update_fields=['status', 'ended_at', 'action_taken'])
        return Response(self.get_serializer(excursion).data)


class SupplierCertificateSerializer(serializers.ModelSerializer):
    supplier_name = serializers.CharField(
        source='supplier.name', read_only=True, default='')
    stock_name = serializers.CharField(
        source='stock.medication_name', read_only=True, default='')
    kind_label = serializers.CharField(source='get_kind_display', read_only=True)
    is_expired = serializers.BooleanField(read_only=True)

    class Meta:
        model = SupplierCertificate
        fields = ['id', 'supplier', 'supplier_name', 'stock', 'stock_name',
                  'kind', 'kind_label', 'reference', 'issued_on', 'expires_on',
                  'file', 'file_name', 'notes', 'uploaded_by',
                  'is_expired', 'created_at']
        read_only_fields = ['id', 'uploaded_by', 'created_at']


class SupplierCertificateViewSet(viewsets.ModelViewSet):
    serializer_class = SupplierCertificateSerializer
    permission_classes = [InventoryPermission]

    def get_queryset(self):
        qs = SupplierCertificate.objects.select_related('supplier', 'stock')
        if self.request.query_params.get('supplier'):
            qs = qs.filter(supplier_id=self.request.query_params['supplier'])
        if self.request.query_params.get('expired') in ('1', 'true'):
            qs = qs.filter(expires_on__lt=timezone.localdate())
        return qs

    def perform_create(self, serializer):
        file = serializer.validated_data.get('file')
        serializer.save(
            uploaded_by=self.request.user if self.request.user.is_authenticated else None,
            file_name=(getattr(file, 'name', '') or '')[:255],
        )


class QualityDashboardView(APIView):
    """Cold-chain + certification health for the quality workspace."""
    permission_classes = [InventoryPermission]

    def get(self, request):
        today = timezone.localdate()
        excursions = TemperatureExcursion.objects.all()
        open_cases = excursions.filter(status=TemperatureExcursion.Status.OPEN)
        certs = SupplierCertificate.objects.all()

        return Response({
            'excursions': {
                'open': open_cases.count(),
                'critical': open_cases.filter(severity='critical').count(),
                'last_30d': excursions.filter(
                    started_at__date__gte=today - timedelta(days=30)).count(),
                'auto_quarantined': excursions.filter(auto_quarantined=True).count(),
            },
            'certificates': {
                'total': certs.count(),
                'expired': certs.filter(expires_on__lt=today).count(),
                'expiring_30d': certs.filter(
                    expires_on__gte=today,
                    expires_on__lte=today + timedelta(days=30)).count(),
            },
            'uncertified_batches': quality.uncertified_batches(limit=20),
            'pending_writeoffs': quality.pending_writeoffs(limit=20),
            'recent_excursions': TemperatureExcursionSerializer(
                open_cases.order_by('-started_at')[:5], many=True).data,
        })


class BatchCertificationView(APIView):
    """Check whether a batch may be released for sale."""
    permission_classes = [InventoryPermission]

    def get(self, request, batch_id=None):
        batch = StockBatch.objects.filter(id=batch_id).select_related(
            'stock', 'supplier').first()
        if not batch:
            return Response({'detail': 'Batch not found.'}, status=404)
        return Response({
            'batch_id': batch.id,
            'batch_number': batch.batch_number,
            'stock_name': batch.stock.medication_name if batch.stock else '',
            **quality.batch_certified(batch),
        })


class ComplianceExportView(APIView):
    """Immutable-style CSV export of the audit trail for a period."""
    permission_classes = [InventoryPermission]

    def get(self, request):
        from audit.models import AuditEvent

        days = int(request.query_params.get('days', 30) or 30)
        start = timezone.now() - timedelta(days=days)
        qs = (AuditEvent.objects
              .filter(created_at__gte=start, object_type__in=[
                  'inventory', 'stock', 'transfers', 'recalls', 'quality',
                  'purchase-orders'])
              .order_by('created_at'))

        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = (
            f'attachment; filename="inventory_audit_{timezone.now():%Y%m%d}.csv"')
        writer = csv.writer(response)
        writer.writerow(['timestamp', 'action', 'severity', 'object_type',
                         'object_id', 'object_repr', 'actor_email', 'actor_role',
                         'description', 'path'])

        for event in qs.iterator():
            writer.writerow([
                event.created_at.isoformat(timespec='seconds'),
                event.action,
                event.severity,
                event.object_type,
                event.object_id,
                event.object_repr,
                event.actor_email,
                event.actor_role,
                event.description,
                event.path,
            ])
        _audit(request, 'audit_export', 'compliance',
               description=f'Exported {days} days of inventory audit events')
        return response
