from rest_framework import serializers

from .models import ClinicSettings, PatientVisit, VisitEvent


class ClinicSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClinicSettings
        fields = [
            'id', 'consultation_fee', 'currency',
            'require_payment_before_triage', 'require_triage_before_doctor',
            'auto_invoice_lab_tests', 'allow_fee_waiver',
            'visit_number_prefix', 'updated_at',
        ]
        read_only_fields = ['id', 'updated_at']


class VisitEventSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.full_name', read_only=True)
    stage_label = serializers.CharField(source='get_stage_display', read_only=True)
    action_label = serializers.SerializerMethodField()

    class Meta:
        model = VisitEvent
        fields = [
            'id', 'visit', 'stage', 'stage_label', 'action', 'action_label',
            'note', 'actor', 'actor_name', 'created_at',
        ]
        read_only_fields = fields

    def get_action_label(self, obj):
        return (obj.action or '').replace('_', ' ').strip().capitalize()


class PatientVisitSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    patient_number = serializers.CharField(source='patient.patient_number', read_only=True)
    patient_id_code = serializers.CharField(source='patient.patient_id', read_only=True)
    patient_phone = serializers.CharField(source='patient.user.phone', read_only=True, default='')
    patient_gender = serializers.CharField(source='patient.gender', read_only=True)
    patient_dob = serializers.DateField(source='patient.date_of_birth', read_only=True)
    patient_allergies = serializers.JSONField(source='patient.allergies', read_only=True, default=list)

    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True, default='')
    stage_label = serializers.CharField(source='get_stage_display', read_only=True)
    payment_status_label = serializers.CharField(source='get_payment_status_display', read_only=True)
    outcome_label = serializers.CharField(source='get_outcome_display', read_only=True)
    waiting_minutes = serializers.IntegerField(read_only=True)
    is_open = serializers.BooleanField(read_only=True)

    triage_esi = serializers.IntegerField(source='triage.esi_level', read_only=True, allow_null=True)
    triage_news2 = serializers.IntegerField(source='triage.news2_score', read_only=True, allow_null=True)
    triage_vitals = serializers.JSONField(source='triage.vital_signs', read_only=True, default=dict)

    invoice_number = serializers.CharField(source='invoice.invoice_number', read_only=True, default='')
    invoice_total = serializers.SerializerMethodField()
    invoice_balance = serializers.SerializerMethodField()

    lab_orders = serializers.SerializerMethodField()
    prescriptions = serializers.SerializerMethodField()
    lab_report_url = serializers.SerializerMethodField()

    events = VisitEventSerializer(many=True, read_only=True)

    corporate_name = serializers.CharField(source='corporate.name', read_only=True, default='')
    corporate_staff_name = serializers.CharField(
        source='corporate_staff.full_name', read_only=True, default='',
    )
    corporate_staff_number = serializers.CharField(
        source='corporate_staff.staff_number', read_only=True, default='',
    )

    class Meta:
        model = PatientVisit
        fields = [
            'id', 'visit_number', 'queue_number',
            'patient', 'patient_name', 'patient_number', 'patient_id_code',
            'patient_phone', 'patient_gender', 'patient_dob', 'patient_allergies',
            'appointment', 'doctor', 'doctor_name',
            'stage', 'stage_label', 'priority',
            'triage', 'triage_esi', 'triage_news2', 'triage_vitals',
            'consultation', 'invoice', 'invoice_number',
            'invoice_total', 'invoice_balance',
            'consultation_fee', 'payment_status', 'payment_status_label',
            'payer', 'payment_method', 'waiver_reason',
            'corporate', 'corporate_name', 'corporate_staff', 'corporate_staff_name',
            'corporate_staff_number', 'corporate_verified', 'corporate_verified_at',
            'corporate_authorisation', 'corporate_document', 'corporate_note',
            'chief_complaint', 'notes',
            'lab_report', 'lab_report_url', 'lab_orders', 'prescriptions',
            'discharge_summary', 'follow_up_date', 'outcome', 'outcome_label',
            'arrived_at', 'registered_at', 'charged_at', 'paid_at',
            'triage_started_at', 'triage_completed_at', 'doctor_assigned_at',
            'consultation_started_at', 'lab_ordered_at', 'lab_completed_at',
            'review_started_at', 'prescribed_at', 'discharged_at',
            'waiting_minutes', 'is_open', 'events',
            'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'visit_number', 'queue_number', 'stage', 'payment_status',
            'invoice', 'triage', 'consultation',
            'corporate_verified_at',
            'arrived_at', 'registered_at', 'charged_at', 'paid_at',
            'triage_started_at', 'triage_completed_at', 'doctor_assigned_at',
            'consultation_started_at', 'lab_ordered_at', 'lab_completed_at',
            'review_started_at', 'prescribed_at', 'discharged_at',
            'created_at', 'updated_at',
        ]
        extra_kwargs = {
            'patient': {'required': True},
            'consultation_fee': {'required': False},
        }

    def get_invoice_total(self, obj):
        return str(obj.invoice.total) if obj.invoice else None

    def get_invoice_balance(self, obj):
        return str(obj.invoice.balance) if obj.invoice else None

    def get_lab_orders(self, obj):
        if not obj.consultation_id:
            return []
        from lab.models import LabOrder
        from lab.serializers import LabOrderSerializer
        # Query explicitly: the prefetch cache on the visit would be stale
        # right after an order is raised by the same request.
        orders = (
            LabOrder.objects
            .filter(consultation_id=obj.consultation_id)
            .select_related('patient__user', 'ordered_by')
            .prefetch_related('tests', 'results__test')
            .order_by('-created_at')
        )
        return LabOrderSerializer(orders, many=True).data

    def get_prescriptions(self, obj):
        if not obj.consultation_id:
            return []
        from prescriptions.models import Prescription
        from prescriptions.serializers import PrescriptionSerializer
        rows = (
            Prescription.objects
            .filter(consultation_id=obj.consultation_id)
            .select_related('doctor', 'patient__user')
            .prefetch_related('items')
            .order_by('-created_at')
        )
        return PrescriptionSerializer(rows, many=True).data

    def get_lab_report_url(self, obj):
        if not obj.lab_report:
            return None
        request = self.context.get('request')
        try:
            url = obj.lab_report.url
        except Exception:
            return None
        return request.build_absolute_uri(url) if request else url


class PatientVisitListSerializer(PatientVisitSerializer):
    """Lighter payload for the board — drops events and nested clinical data."""

    class Meta(PatientVisitSerializer.Meta):
        fields = [
            'id', 'visit_number', 'queue_number',
            'patient', 'patient_name', 'patient_number', 'patient_id_code',
            'patient_phone', 'patient_gender', 'patient_dob',
            'doctor', 'doctor_name',
            'stage', 'stage_label', 'priority',
            'triage', 'triage_esi', 'triage_news2',
            'consultation', 'invoice', 'invoice_number',
            'invoice_total', 'invoice_balance',
            'consultation_fee', 'payment_status', 'payment_status_label',
            'payer', 'payment_method',
            'chief_complaint',
            'arrived_at', 'registered_at', 'paid_at', 'triage_completed_at',
            'consultation_started_at', 'lab_ordered_at', 'lab_completed_at',
            'prescribed_at', 'discharged_at',
            'waiting_minutes', 'is_open', 'created_at',
        ]
        read_only_fields = fields
