from django.utils import timezone
from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import (
    ImagingModality, ExamCatalog, ExamPanel,
    ReferringFacility, ReferringDoctor,
    RadiologyOrder, RadiologyOrderExtra, RadiologySchedule,
    ContrastAdministration, DoseRecord,
    RadiologyResult, ReportTemplate, RadiologyReport, CriticalFindingAlert,
    QualityControlRecord,
    RadiologyInvoice, RadiologyInvoiceItem, RadiologyPayment,
)
from .serializers import (
    ImagingModalitySerializer, ExamCatalogSerializer, ExamPanelSerializer,
    ReferringFacilitySerializer, ReferringDoctorSerializer,
    RadiologyOrderSerializer, RadiologyOrderExtraSerializer, RadiologyScheduleSerializer,
    ContrastAdministrationSerializer, DoseRecordSerializer,
    RadiologyResultSerializer, ReportTemplateSerializer,
    RadiologyReportSerializer, CriticalFindingAlertSerializer,
    QualityControlRecordSerializer,
    RadiologyInvoiceSerializer, RadiologyInvoiceItemSerializer, RadiologyPaymentSerializer,
)


class ImagingModalityViewSet(viewsets.ModelViewSet):
    queryset = ImagingModality.objects.all()
    serializer_class = ImagingModalitySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['modality_type', 'is_active']
    search_fields = ['name', 'manufacturer', 'model_name', 'room_location']
    ordering_fields = ['name', 'created_at']


class ExamCatalogViewSet(viewsets.ModelViewSet):
    queryset = ExamCatalog.objects.all()
    serializer_class = ExamCatalogSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['modality_type', 'is_active', 'contrast_required']
    search_fields = ['code', 'name', 'body_region']
    ordering_fields = ['name', 'price', 'created_at']


class ExamPanelViewSet(viewsets.ModelViewSet):
    queryset = ExamPanel.objects.prefetch_related('exams').all()
    serializer_class = ExamPanelSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['is_active']
    search_fields = ['name', 'description']


class ReferringFacilityViewSet(viewsets.ModelViewSet):
    queryset = ReferringFacility.objects.all()
    serializer_class = ReferringFacilitySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['is_active']
    search_fields = ['name', 'contact_person', 'email']


class ReferringDoctorViewSet(viewsets.ModelViewSet):
    queryset = ReferringDoctor.objects.select_related('facility').all()
    serializer_class = ReferringDoctorSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['facility', 'is_active']
    search_fields = ['name', 'specialty', 'license_number']


# ── Orders ────────────────────────────────────────────────────────────

class RadiologyOrderViewSet(viewsets.ModelViewSet):
    queryset = RadiologyOrder.objects.select_related(
        'patient', 'ordered_by', 'consultation', 'modality',
    ).prefetch_related('exams').all()
    serializer_class = RadiologyOrderSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'imaging_type', 'patient', 'priority', 'modality']
    search_fields = ['body_part', 'clinical_indication', 'patient__first_name', 'patient__last_name']
    ordering_fields = ['created_at', 'priority', 'status']


class RadiologyOrderExtraViewSet(viewsets.ModelViewSet):
    queryset = RadiologyOrderExtra.objects.select_related(
        'order', 'referring_doctor', 'referring_facility',
    ).all()
    serializer_class = RadiologyOrderExtraSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['order', 'payer_type']
    search_fields = ['accession_number']


# ── Scheduling ────────────────────────────────────────────────────────

class RadiologyScheduleViewSet(viewsets.ModelViewSet):
    queryset = RadiologySchedule.objects.select_related(
        'order__patient', 'modality', 'technologist',
    ).all()
    serializer_class = RadiologyScheduleSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'modality', 'technologist', 'order']
    search_fields = ['order__body_part', 'notes']
    ordering_fields = ['scheduled_datetime', 'status']

    @action(detail=True, methods=['post'])
    def check_in(self, request, pk=None):
        schedule = self.get_object()
        schedule.status = RadiologySchedule.Status.CHECKED_IN
        schedule.save(update_fields=['status'])
        schedule.order.status = RadiologyOrder.Status.CHECKED_IN
        schedule.order.save(update_fields=['status'])
        return Response(self.get_serializer(schedule).data)

    @action(detail=True, methods=['post'])
    def start(self, request, pk=None):
        schedule = self.get_object()
        schedule.status = RadiologySchedule.Status.IN_PROGRESS
        schedule.save(update_fields=['status'])
        schedule.order.status = RadiologyOrder.Status.IN_PROGRESS
        schedule.order.save(update_fields=['status'])
        return Response(self.get_serializer(schedule).data)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        schedule = self.get_object()
        schedule.status = RadiologySchedule.Status.COMPLETED
        schedule.save(update_fields=['status'])
        schedule.order.status = RadiologyOrder.Status.COMPLETED
        schedule.order.save(update_fields=['status'])
        return Response(self.get_serializer(schedule).data)


# ── Contrast / Dose ───────────────────────────────────────────────────

class ContrastAdministrationViewSet(viewsets.ModelViewSet):
    queryset = ContrastAdministration.objects.select_related('order', 'administered_by').all()
    serializer_class = ContrastAdministrationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['order', 'reaction_noted']
    search_fields = ['contrast_agent', 'lot_number']


class DoseRecordViewSet(viewsets.ModelViewSet):
    queryset = DoseRecord.objects.select_related('order', 'modality', 'recorded_by').all()
    serializer_class = DoseRecordSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['order', 'modality']


# ── Reporting ─────────────────────────────────────────────────────────

class RadiologyResultViewSet(viewsets.ModelViewSet):
    queryset = RadiologyResult.objects.select_related('order', 'radiologist').all()
    serializer_class = RadiologyResultSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['order']
    search_fields = ['findings', 'impression']


class ReportTemplateViewSet(viewsets.ModelViewSet):
    queryset = ReportTemplate.objects.all()
    serializer_class = ReportTemplateSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['modality_type', 'is_active']
    search_fields = ['name', 'body_region']


class RadiologyReportViewSet(viewsets.ModelViewSet):
    queryset = RadiologyReport.objects.select_related(
        'order__patient', 'radiologist', 'template', 'transcribed_by',
    ).all()
    serializer_class = RadiologyReportSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['report_status', 'radiologist', 'critical_finding', 'order']
    search_fields = ['findings', 'impression', 'order__body_part']
    ordering_fields = ['created_at', 'signed_at']

    @action(detail=True, methods=['post'])
    def sign(self, request, pk=None):
        report = self.get_object()
        report.report_status = RadiologyReport.ReportStatus.FINAL
        report.signed_at = timezone.now()
        if not report.radiologist:
            report.radiologist = request.user
        report.save(update_fields=['report_status', 'signed_at', 'radiologist'])
        return Response(self.get_serializer(report).data)

    @action(detail=True, methods=['post'])
    def amend(self, request, pk=None):
        report = self.get_object()
        report.report_status = RadiologyReport.ReportStatus.AMENDED
        report.findings = request.data.get('findings', report.findings)
        report.impression = request.data.get('impression', report.impression)
        report.recommendation = request.data.get('recommendation', report.recommendation)
        report.save()
        return Response(self.get_serializer(report).data)


class CriticalFindingAlertViewSet(viewsets.ModelViewSet):
    queryset = CriticalFindingAlert.objects.select_related('report', 'communicated_by').all()
    serializer_class = CriticalFindingAlertSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['severity', 'acknowledged', 'report']
    search_fields = ['finding_description', 'communicated_to']
    ordering_fields = ['communicated_at']


# ── QC ────────────────────────────────────────────────────────────────

class QualityControlRecordViewSet(viewsets.ModelViewSet):
    queryset = QualityControlRecord.objects.select_related('modality', 'performed_by').all()
    serializer_class = QualityControlRecordSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['modality', 'status', 'performed_by']
    search_fields = ['notes']
    ordering_fields = ['qc_date']

    @action(detail=False, methods=['get'])
    def daily_summary(self, request):
        today = timezone.now().date()
        records = self.queryset.filter(qc_date=today)
        return Response(self.get_serializer(records, many=True).data)


# ── Billing ───────────────────────────────────────────────────────────

class RadiologyInvoiceViewSet(viewsets.ModelViewSet):
    queryset = RadiologyInvoice.objects.select_related('order', 'patient').prefetch_related('items', 'payments').all()
    serializer_class = RadiologyInvoiceSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'payer_type', 'patient', 'order']
    search_fields = ['invoice_number', 'patient__first_name', 'patient__last_name']
    ordering_fields = ['created_at', 'due_date', 'total']

    @action(detail=True, methods=['post'])
    def add_payment(self, request, pk=None):
        invoice = self.get_object()
        ser = RadiologyPaymentSerializer(data={**request.data, 'invoice': invoice.id})
        ser.is_valid(raise_exception=True)
        ser.save()
        invoice.amount_paid = sum(p.amount for p in invoice.payments.all())
        if invoice.amount_paid >= invoice.total:
            invoice.status = RadiologyInvoice.InvoiceStatus.PAID
        elif invoice.amount_paid > 0:
            invoice.status = RadiologyInvoice.InvoiceStatus.PARTIAL
        invoice.save(update_fields=['amount_paid', 'status'])
        return Response(self.get_serializer(invoice).data)


class RadiologyInvoiceItemViewSet(viewsets.ModelViewSet):
    queryset = RadiologyInvoiceItem.objects.select_related('invoice', 'exam', 'panel').all()
    serializer_class = RadiologyInvoiceItemSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['invoice']


class RadiologyPaymentViewSet(viewsets.ModelViewSet):
    queryset = RadiologyPayment.objects.select_related('invoice', 'received_by').all()
    serializer_class = RadiologyPaymentSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['invoice', 'method']
