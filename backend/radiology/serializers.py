from rest_framework import serializers
from .models import (
    ImagingModality, ExamCatalog, ExamPanel,
    ReferringFacility, ReferringDoctor,
    RadiologyOrder, RadiologyOrderExtra, RadiologySchedule,
    ContrastAdministration, DoseRecord,
    RadiologyResult, ReportTemplate, RadiologyReport, CriticalFindingAlert,
    QualityControlRecord,
    RadiologyInvoice, RadiologyInvoiceItem, RadiologyPayment,
)


class ImagingModalitySerializer(serializers.ModelSerializer):
    modality_type_display = serializers.CharField(source='get_modality_type_display', read_only=True)

    class Meta:
        model = ImagingModality
        fields = '__all__'


class ExamCatalogSerializer(serializers.ModelSerializer):
    modality_type_display = serializers.CharField(source='get_modality_type_display', read_only=True)

    class Meta:
        model = ExamCatalog
        fields = '__all__'


class ExamPanelSerializer(serializers.ModelSerializer):
    exam_names = serializers.SerializerMethodField()
    exam_ids = serializers.PrimaryKeyRelatedField(
        queryset=ExamCatalog.objects.all(), many=True, write_only=True, source='exams', required=False,
    )

    class Meta:
        model = ExamPanel
        fields = '__all__'

    def get_exam_names(self, obj):
        return list(obj.exams.values_list('name', flat=True))


class ReferringFacilitySerializer(serializers.ModelSerializer):
    class Meta:
        model = ReferringFacility
        fields = '__all__'


class ReferringDoctorSerializer(serializers.ModelSerializer):
    facility_name = serializers.CharField(source='facility.name', read_only=True, default='')

    class Meta:
        model = ReferringDoctor
        fields = '__all__'


# ── Order ─────────────────────────────────────────────────────────────

class RadiologyResultSerializer(serializers.ModelSerializer):
    radiologist_name = serializers.SerializerMethodField()

    class Meta:
        model = RadiologyResult
        fields = '__all__'

    def get_radiologist_name(self, obj):
        u = obj.radiologist
        return f'{u.first_name} {u.last_name}'.strip() if u else ''


class RadiologyOrderExtraSerializer(serializers.ModelSerializer):
    referring_doctor_name = serializers.CharField(source='referring_doctor.name', read_only=True, default='')
    referring_facility_name = serializers.CharField(source='referring_facility.name', read_only=True, default='')
    panel_ids = serializers.PrimaryKeyRelatedField(
        queryset=ExamPanel.objects.all(), many=True, write_only=True, source='panels', required=False,
    )

    class Meta:
        model = RadiologyOrderExtra
        fields = '__all__'


class RadiologyReportSerializer(serializers.ModelSerializer):
    radiologist_name = serializers.SerializerMethodField()
    report_status_display = serializers.CharField(source='get_report_status_display', read_only=True)

    class Meta:
        model = RadiologyReport
        fields = '__all__'

    def get_radiologist_name(self, obj):
        u = obj.radiologist
        return f'{u.first_name} {u.last_name}'.strip() if u else ''


class RadiologyOrderSerializer(serializers.ModelSerializer):
    patient_name = serializers.SerializerMethodField()
    ordered_by_name = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    priority_display = serializers.CharField(source='get_priority_display', read_only=True)
    imaging_type_display = serializers.CharField(source='get_imaging_type_display', read_only=True)
    modality_name = serializers.CharField(source='modality.name', read_only=True, default='')
    result = RadiologyResultSerializer(read_only=True)
    report = RadiologyReportSerializer(read_only=True)
    exam_ids = serializers.PrimaryKeyRelatedField(
        queryset=ExamCatalog.objects.all(), many=True, write_only=True, source='exams', required=False,
    )
    exam_names = serializers.SerializerMethodField()

    class Meta:
        model = RadiologyOrder
        fields = '__all__'

    def get_patient_name(self, obj):
        p = obj.patient
        return f'{p.first_name} {p.last_name}'.strip() if p else ''

    def get_ordered_by_name(self, obj):
        u = obj.ordered_by
        return f'{u.first_name} {u.last_name}'.strip() if u else ''

    def get_exam_names(self, obj):
        return list(obj.exams.values_list('name', flat=True))


# ── Schedule ──────────────────────────────────────────────────────────

class RadiologyScheduleSerializer(serializers.ModelSerializer):
    patient_name = serializers.SerializerMethodField()
    modality_name = serializers.CharField(source='modality.name', read_only=True, default='')
    technologist_name = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    imaging_type = serializers.CharField(source='order.imaging_type', read_only=True)
    body_part = serializers.CharField(source='order.body_part', read_only=True)

    class Meta:
        model = RadiologySchedule
        fields = '__all__'

    def get_patient_name(self, obj):
        p = obj.order.patient
        return f'{p.first_name} {p.last_name}'.strip() if p else ''

    def get_technologist_name(self, obj):
        u = obj.technologist
        return f'{u.first_name} {u.last_name}'.strip() if u else ''


# ── Contrast / Dose ───────────────────────────────────────────────────

class ContrastAdministrationSerializer(serializers.ModelSerializer):
    administered_by_name = serializers.SerializerMethodField()

    class Meta:
        model = ContrastAdministration
        fields = '__all__'

    def get_administered_by_name(self, obj):
        u = obj.administered_by
        return f'{u.first_name} {u.last_name}'.strip() if u else ''


class DoseRecordSerializer(serializers.ModelSerializer):
    modality_name = serializers.CharField(source='modality.name', read_only=True, default='')
    recorded_by_name = serializers.SerializerMethodField()

    class Meta:
        model = DoseRecord
        fields = '__all__'

    def get_recorded_by_name(self, obj):
        u = obj.recorded_by
        return f'{u.first_name} {u.last_name}'.strip() if u else ''


# ── Reporting extras ──────────────────────────────────────────────────

class ReportTemplateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReportTemplate
        fields = '__all__'


class CriticalFindingAlertSerializer(serializers.ModelSerializer):
    communicated_by_name = serializers.SerializerMethodField()
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)

    class Meta:
        model = CriticalFindingAlert
        fields = '__all__'

    def get_communicated_by_name(self, obj):
        u = obj.communicated_by
        return f'{u.first_name} {u.last_name}'.strip() if u else ''


# ── QC ────────────────────────────────────────────────────────────────

class QualityControlRecordSerializer(serializers.ModelSerializer):
    modality_name = serializers.CharField(source='modality.name', read_only=True, default='')
    performed_by_name = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = QualityControlRecord
        fields = '__all__'

    def get_performed_by_name(self, obj):
        u = obj.performed_by
        return f'{u.first_name} {u.last_name}'.strip() if u else ''


# ── Billing ───────────────────────────────────────────────────────────

class RadiologyInvoiceItemSerializer(serializers.ModelSerializer):
    exam_name = serializers.CharField(source='exam.name', read_only=True, default='')
    panel_name = serializers.CharField(source='panel.name', read_only=True, default='')

    class Meta:
        model = RadiologyInvoiceItem
        fields = '__all__'


class RadiologyPaymentSerializer(serializers.ModelSerializer):
    method_display = serializers.CharField(source='get_method_display', read_only=True)
    received_by_name = serializers.SerializerMethodField()

    class Meta:
        model = RadiologyPayment
        fields = '__all__'

    def get_received_by_name(self, obj):
        u = obj.received_by
        return f'{u.first_name} {u.last_name}'.strip() if u else ''


class RadiologyInvoiceSerializer(serializers.ModelSerializer):
    patient_name = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    payer_type_display = serializers.CharField(source='get_payer_type_display', read_only=True)
    items = RadiologyInvoiceItemSerializer(many=True, read_only=True)
    payments = RadiologyPaymentSerializer(many=True, read_only=True)
    balance = serializers.SerializerMethodField()

    class Meta:
        model = RadiologyInvoice
        fields = '__all__'

    def get_patient_name(self, obj):
        p = obj.patient
        return f'{p.first_name} {p.last_name}'.strip() if p else ''

    def get_balance(self, obj):
        return float(obj.total) - float(obj.amount_paid)
