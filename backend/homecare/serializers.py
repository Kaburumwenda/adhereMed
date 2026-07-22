from rest_framework import serializers
from django.contrib.auth import get_user_model

from .models import (
    HomecareCompanyProfile, Caregiver, HomecarePatient, CaregiverSchedule,
    CaregiverNote, TreatmentPlan, MedicationSchedule, DoseEvent,
    EscalationRule, Escalation, TeleconsultRoom, HomecareAppointment,
    HomecarePrescription, PharmacyStockAlert, InsurancePolicy, InsuranceClaim,
    Consent, HomecareDiagnosis, HomecareAllergy,
    Device, DeviceAssignment, DeviceMaintenance, AuditEvent,
    DrugInteraction, PrescriptionSafetyAlert,
    DrainLine,
    CarePathway, CarePathwayEnrollment, PatientDataSharing,
    CarePlan, MedicalSupply, PatientBill, PatientPayment, BillingSettings,
    AssessmentSession, AssessmentAlert,
    BradenAssessment, CapriniAssessment, MorseAssessment, MustAssessment,
    CamAssessment, PainAssessment, SkinCareAssessment, GcsAssessment,
    DiabetesBundleAssessment, HeartFailureBundleAssessment,
    PIVCAssessment, EnteralFeedingAssessment, UrinaryCatheterAssessment,
    ArtificialAirwayAssessment, CVADAssessment,
    PatientDocument,
)

User = get_user_model()


class _UserMiniSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ('id', 'email', 'first_name', 'last_name', 'full_name', 'phone', 'role')

    def get_full_name(self, obj):
        return f'{obj.first_name} {obj.last_name}'.strip()


# ─────────────────────────────────────────────
class HomecareCompanyProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = HomecareCompanyProfile
        fields = '__all__'


# ─────────────────────────────────────────────
class CaregiverSerializer(serializers.ModelSerializer):
    user = _UserMiniSerializer(read_only=True)
    user_id = serializers.PrimaryKeyRelatedField(
        source='user', queryset=User.objects.all(), write_only=True,
    )
    active_patients_count = serializers.SerializerMethodField()
    category_label = serializers.CharField(source='get_category_display', read_only=True)
    has_visit_pin = serializers.SerializerMethodField()

    class Meta:
        model = Caregiver
        fields = (
            'id', 'user', 'user_id', 'category', 'category_label',
            'license_number', 'certifications',
            'specialties', 'bio', 'photo', 'hourly_rate', 'is_independent',
            'is_available', 'rating', 'total_visits', 'hire_date',
            'employment_status', 'active_patients_count', 'created_at', 'updated_at',
            'visit_pin', 'has_visit_pin',
        )
        read_only_fields = ('rating', 'total_visits', 'created_at', 'updated_at')
        extra_kwargs = {'visit_pin': {'write_only': True, 'required': False}}

    def get_active_patients_count(self, obj):
        return obj.patients.filter(is_active=True).count()

    def get_has_visit_pin(self, obj):
        return bool(obj.visit_pin)


# ─────────────────────────────────────────────
class HomecarePatientSerializer(serializers.ModelSerializer):
    user = _UserMiniSerializer(read_only=True)
    user_id = serializers.PrimaryKeyRelatedField(
        source='user', queryset=User.objects.all(), write_only=True,
    )
    patient_name = serializers.SerializerMethodField()
    adheremed_patient_id = serializers.SerializerMethodField()
    assigned_caregiver_name = serializers.SerializerMethodField()
    additional_caregivers_detail = serializers.SerializerMethodField()
    active_treatment_plan_id = serializers.SerializerMethodField()
    open_escalations = serializers.SerializerMethodField()
    adherence_rate = serializers.SerializerMethodField()
    age = serializers.SerializerMethodField()

    class Meta:
        model = HomecarePatient
        fields = (
            'id', 'medical_record_number', 'patient_name', 'adheremed_patient_id',
            'user', 'user_id',
            'date_of_birth', 'age', 'gender', 'address', 'address_lat', 'address_lng',
            'id_type', 'id_number', 'nationality',
            'primary_diagnosis', 'medical_history', 'allergies',
            'emergency_contacts', 'assigned_caregiver', 'assigned_caregiver_name',
            'additional_caregivers', 'additional_caregivers_detail',
            'assigned_doctor_user_id', 'assigned_doctor_info', 'risk_level', 'is_active',
            'active_treatment_plan_id', 'open_escalations', 'adherence_rate',
            'enrolled_at', 'discharged_at',
        )
        read_only_fields = ('medical_record_number', 'enrolled_at')

    def get_patient_name(self, obj):
        return obj.user.full_name if obj.user else None

    def get_adheremed_patient_id(self, obj):
        if not obj.user_id:
            return None
        try:
            from django_tenants.utils import schema_context
            from patients.models import Patient
            with schema_context('public'):
                profile = Patient.objects.filter(user_id=obj.user_id).first()
                return profile.patient_id if profile else None
        except Exception:
            return None

    def get_assigned_caregiver_name(self, obj):
        if obj.assigned_caregiver:
            return obj.assigned_caregiver.user.full_name
        return None

    def get_additional_caregivers_detail(self, obj):
        return [
            {'id': c.id, 'full_name': c.user.full_name, 'email': c.user.email}
            for c in obj.additional_caregivers.all()
        ]

    def get_age(self, obj):
        d = obj.date_of_birth
        if not d:
            return None
        from datetime import date, datetime
        if isinstance(d, str):
            try:
                d = datetime.strptime(d[:10], '%Y-%m-%d').date()
            except (ValueError, TypeError):
                return None
        today = date.today()
        return today.year - d.year - ((today.month, today.day) < (d.month, d.day))

    def get_active_treatment_plan_id(self, obj):
        plan = obj.treatment_plans.filter(status='active').first()
        return plan.id if plan else None

    def get_open_escalations(self, obj):
        return obj.escalations.filter(status='open').count()

    def get_adherence_rate(self, obj):
        from django.db.models import Count, Q
        agg = DoseEvent.objects.filter(schedule__patient=obj).aggregate(
            total=Count('id'),
            taken=Count('id', filter=Q(status='taken')),
        )
        total = agg['total'] or 0
        if not total:
            return None
        return round((agg['taken'] / total) * 100, 1)


class PatientDataSharingSerializer(serializers.ModelSerializer):
    patient_name = serializers.SerializerMethodField()
    medical_record_number = serializers.CharField(
        source='patient.medical_record_number', read_only=True,
    )

    class Meta:
        model = PatientDataSharing
        fields = (
            'id', 'patient', 'patient_name', 'medical_record_number',
            'is_shared', 'share_profile', 'share_care_team', 'share_vitals',
            'share_medications', 'share_treatment_plan', 'share_notes',
            'share_adherence', 'share_escalations', 'share_consents',
            'share_documents', 'updated_at',
        )
        read_only_fields = ('patient', 'updated_at')

    def get_patient_name(self, obj):
        return obj.patient.user.full_name


# ─────────────────────────────────────────────
class CaregiverScheduleSerializer(serializers.ModelSerializer):
    caregiver_name = serializers.CharField(source='caregiver.user.full_name', read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    patient_address = serializers.CharField(source='patient.address', read_only=True)
    patient_address_lat = serializers.DecimalField(
        source='patient.address_lat', max_digits=9, decimal_places=6, read_only=True)
    patient_address_lng = serializers.DecimalField(
        source='patient.address_lng', max_digits=9, decimal_places=6, read_only=True)

    class Meta:
        model = CaregiverSchedule
        fields = (
            'id', 'caregiver', 'caregiver_name', 'patient', 'patient_name',
            'patient_address', 'patient_address_lat', 'patient_address_lng',
            'shift_type', 'start_at', 'end_at', 'recurrence', 'status',
            'check_in_at', 'check_out_at', 'gps_check_in', 'gps_check_out',
            'acknowledged_at', 'reassignment_requested', 'reassignment_reason',
            'reassigned_to', 'auto_missed_at',
            'notes', 'created_at',
        )
        read_only_fields = (
            'check_in_at', 'check_out_at', 'acknowledged_at',
            'reassignment_requested', 'reassignment_reason',
            'reassigned_to', 'auto_missed_at', 'created_at',
        )


class CaregiverNoteSerializer(serializers.ModelSerializer):
    caregiver_name = serializers.CharField(source='caregiver.user.full_name', read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = CaregiverNote
        fields = (
            'id', 'caregiver', 'caregiver_name', 'patient', 'patient_name',
            'schedule', 'category', 'content', 'vitals', 'attached_files',
            'recorded_at', 'created_at',
        )
        read_only_fields = ('created_at',)


# ─────────────────────────────────────────────
class TreatmentPlanSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    medication_count = serializers.SerializerMethodField()

    class Meta:
        model = TreatmentPlan
        fields = (
            'id', 'patient', 'patient_name', 'created_by_doctor_id',
            'title', 'diagnosis', 'goals', 'start_date', 'end_date',
            'status', 'notes', 'medication_count', 'created_at', 'updated_at',
        )
        read_only_fields = ('created_at', 'updated_at')

    def get_medication_count(self, obj):
        return obj.medication_schedules.filter(is_active=True).count()


class MedicationScheduleSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    upcoming_doses = serializers.SerializerMethodField()

    class Meta:
        model = MedicationSchedule
        fields = (
            'id', 'patient', 'patient_name', 'treatment_plan',
            'medication_id', 'medication_name', 'dose', 'route',
            'frequency_cron', 'times_of_day', 'start_date', 'end_date',
            'instructions', 'requires_caregiver', 'unit_cost',
            'prescribed_by_doctor_id', 'source_prescription_id',
            'is_active', 'upcoming_doses',
            'last_generation_at', 'last_generation_by', 'last_generation_by_name',
            'last_generation_by_role', 'last_generation_count', 'last_generation_days',
            'created_at', 'updated_at',
        )
        read_only_fields = (
            'created_at', 'updated_at',
            'last_generation_at', 'last_generation_by', 'last_generation_by_name',
            'last_generation_by_role', 'last_generation_count', 'last_generation_days',
        )

    def get_upcoming_doses(self, obj):
        return obj.doses.filter(status='pending').count()


class DoseEventSerializer(serializers.ModelSerializer):
    medication_name = serializers.CharField(source='schedule.medication_name', read_only=True)
    dose = serializers.CharField(source='schedule.dose', read_only=True)
    patient_name = serializers.CharField(source='schedule.patient.user.full_name', read_only=True)
    patient_id = serializers.IntegerField(source='schedule.patient_id', read_only=True)
    administered_by_name = serializers.SerializerMethodField()
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = DoseEvent
        fields = (
            'id', 'schedule', 'medication_name', 'dose', 'patient_id', 'patient_name',
            'scheduled_at', 'status', 'status_label', 'administered_at',
            'administered_by_caregiver', 'administered_by_user',
            'administered_by_name', 'administered_by_role',
            'reason', 'notes', 'vitals_pre', 'vitals_post',
            'patient_confirmation', 'reminded_at',
            'auto_missed', 'audit_log',
            'created_at', 'updated_at',
        )
        read_only_fields = (
            'reminded_at', 'created_at', 'updated_at', 'auto_missed', 'audit_log',
            'administered_by_user', 'administered_by_role',
        )

    def get_administered_by_name(self, obj):
        if obj.administered_by_name:
            return obj.administered_by_name
        if obj.administered_by_caregiver:
            return obj.administered_by_caregiver.user.full_name
        return None


# ─────────────────────────────────────────────
class EscalationRuleSerializer(serializers.ModelSerializer):
    class Meta:
        model = EscalationRule
        fields = '__all__'


class EscalationSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    rule_name = serializers.CharField(source='rule.name', read_only=True)
    acknowledged_by_name = serializers.SerializerMethodField()

    class Meta:
        model = Escalation
        fields = (
            'id', 'patient', 'patient_name', 'rule', 'rule_name',
            'triggered_at', 'reason', 'detail', 'severity', 'status',
            'acknowledged_by', 'acknowledged_by_name', 'acknowledged_at',
            'resolved_at', 'resolution_notes', 'related_dose_ids',
        )
        read_only_fields = ('triggered_at', 'acknowledged_at', 'resolved_at',
                            'acknowledged_by')

    def get_acknowledged_by_name(self, obj):
        if obj.acknowledged_by:
            return obj.acknowledged_by.full_name
        return None


# ─────────────────────────────────────────────
class TeleconsultRoomSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    join_url = serializers.SerializerMethodField()

    class Meta:
        model = TeleconsultRoom
        fields = (
            'id', 'patient', 'patient_name', 'doctor_user_id',
            'scheduled_at', 'duration_minutes', 'started_at', 'ended_at',
            'room_token', 'provider', 'status', 'join_urls', 'join_url',
            'recording_url', 'summary', 'created_at',
        )
        read_only_fields = ('room_token', 'started_at', 'ended_at', 'created_at',
                            'join_urls')

    def get_join_url(self, obj):
        # Generic Jitsi join URL using the room_token
        if obj.provider == 'jitsi':
            return f'https://meet.jit.si/AfyaOne-{obj.room_token}'
        return obj.join_urls.get('default') if isinstance(obj.join_urls, dict) else None


class HomecareAppointmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = HomecareAppointment
        fields = (
            'id', 'patient', 'patient_name', 'doctor_user_id', 'doctor_name',
            'appointment_type', 'scheduled_at', 'duration_minutes',
            'location', 'status', 'notes', 'teleconsult_room', 'created_at',
        )
        read_only_fields = ('created_at',)


# ─────────────────────────────────────────────
class HomecarePrescriptionSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = HomecarePrescription
        fields = (
            'id', 'patient', 'patient_name', 'treatment_plan',
            'prescribed_by_doctor_id', 'prescribed_by_name', 'items',
            'forwarded_to_pharmacy_tenant_id', 'forwarded_pharmacy_name',
            'forwarded_at', 'pharmacy_status', 'substitution_proposed',
            'patient_approved_substitution', 'exchange_ref',
            'created_at', 'updated_at',
        )
        read_only_fields = ('forwarded_at', 'exchange_ref', 'created_at', 'updated_at')


class PharmacyStockAlertSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = PharmacyStockAlert
        fields = '__all__'


# ─────────────────────────────────────────────
class InsurancePolicySerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = InsurancePolicy
        fields = '__all__'


class InsuranceClaimSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    policy_provider = serializers.CharField(source='policy.provider_name', read_only=True)

    class Meta:
        model = InsuranceClaim
        fields = (
            'id', 'claim_number', 'patient', 'patient_name', 'policy',
            'policy_provider', 'claim_type', 'service_start', 'service_end',
            'amount_requested', 'breakdown', 'submitted_at', 'status',
            'approved_amount', 'denial_reason', 'payer_response', 'attachments',
            'created_at', 'updated_at',
        )
        read_only_fields = ('claim_number', 'submitted_at', 'created_at', 'updated_at')


# ─────────────────────────────────────────────
class ConsentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    is_active = serializers.BooleanField(read_only=True)

    class Meta:
        model = Consent
        fields = (
            'id', 'patient', 'patient_name', 'scope', 'granted_to',
            'granted_to_user_id', 'granted_to_tenant_id', 'granted_at',
            'expires_at', 'signed_document_url', 'signature_data_url',
            'signed_by_name', 'signed_by_relationship', 'signed_at',
            'signed_ip', 'signed_user_agent', 'signature_hash',
            'revoked_at', 'notes', 'is_active',
        )
        read_only_fields = ('revoked_at', 'signed_at', 'signed_ip',
                            'signed_user_agent', 'signature_hash')


# ─────────────────────────────────────────────
# Tenant catalog: diagnoses & allergies
# ─────────────────────────────────────────────
class HomecareDiagnosisSerializer(serializers.ModelSerializer):
    class Meta:
        model = HomecareDiagnosis
        fields = ('id', 'name', 'category', 'icd_code', 'description',
                  'source', 'is_active', 'created_at', 'updated_at')
        read_only_fields = ('source', 'created_at', 'updated_at')


class HomecareAllergySerializer(serializers.ModelSerializer):
    class Meta:
        model = HomecareAllergy
        fields = ('id', 'name', 'category', 'description', 'common_symptoms',
                  'source', 'is_active', 'created_at', 'updated_at')
        read_only_fields = ('source', 'created_at', 'updated_at')


# ───────────────────────────────────────────────
# Equipment / Devices
# ───────────────────────────────────────────────
class DeviceSerializer(serializers.ModelSerializer):
    assigned_to_name = serializers.CharField(
        source='assigned_to.user.full_name', read_only=True, default=None)
    device_type_label = serializers.CharField(
        source='get_device_type_display', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    default_hire_period_label = serializers.CharField(
        source='get_default_hire_period_display', read_only=True)
    quantity_on_hire = serializers.IntegerField(read_only=True)
    stock_status = serializers.CharField(read_only=True)

    class Meta:
        model = Device
        fields = (
            'id', 'name', 'device_type', 'device_type_label', 'serial_number',
            'asset_tag', 'qr_code', 'manufacturer', 'model_number',
            'status', 'status_label', 'assigned_to', 'assigned_to_name',
            'quantity', 'quantity_available', 'low_stock_threshold',
            'quantity_on_hire', 'stock_status',
            'location', 'purchase_date', 'purchase_cost', 'warranty_expiry',
            'is_rentable', 'currency', 'hourly_rate', 'daily_rate',
            'weekly_rate', 'monthly_rate', 'deposit',
            'default_hire_period', 'default_hire_period_label',
            'last_maintenance_at', 'next_maintenance_due', 'notes', 'photo',
            'created_at', 'updated_at',
        )
        read_only_fields = ('last_maintenance_at', 'created_at', 'updated_at')


class DeviceAssignmentSerializer(serializers.ModelSerializer):
    device_name = serializers.CharField(source='device.name', read_only=True)
    patient_name = serializers.CharField(
        source='patient.user.full_name', read_only=True)
    hire_to_type_label = serializers.CharField(
        source='get_hire_to_type_display', read_only=True)
    hire_to_name = serializers.SerializerMethodField()
    assigned_by_name = serializers.SerializerMethodField()
    hire_period_label = serializers.CharField(
        source='get_hire_period_display', read_only=True)
    estimated_charge = serializers.SerializerMethodField()

    class Meta:
        model = DeviceAssignment
        fields = (
            'id', 'device', 'device_name', 'hire_to_type', 'hire_to_type_label',
            'hire_to_name', 'patient', 'patient_name', 'facility_name',
            'assigned_at', 'assigned_by', 'assigned_by_name',
            'expected_return_at', 'returned_at', 'return_condition',
            'hire_period', 'hire_period_label', 'hire_rate', 'deposit',
            'total_charged', 'estimated_charge', 'notes',
        )
        read_only_fields = ('assigned_by',)

    def get_assigned_by_name(self, obj):
        return obj.assigned_by.full_name if obj.assigned_by else None

    def get_hire_to_name(self, obj):
        if obj.facility_name:
            return obj.facility_name
        return obj.patient.user.full_name if obj.patient and obj.patient.user else None

    def get_estimated_charge(self, obj):
        charge = obj.compute_charge()
        return str(charge) if charge is not None else None


class DeviceMaintenanceSerializer(serializers.ModelSerializer):
    device_name = serializers.CharField(source='device.name', read_only=True)
    kind_label = serializers.CharField(source='get_kind_display', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = DeviceMaintenance
        fields = (
            'id', 'device', 'device_name', 'kind', 'kind_label',
            'status', 'status_label', 'scheduled_at', 'performed_at',
            'performed_by_name', 'performed_by_user', 'cost', 'notes',
            'next_due_at', 'created_at', 'updated_at',
        )
        read_only_fields = ('created_at', 'updated_at')


class DrainLineSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    line_type_label = serializers.CharField(source='get_line_type_display', read_only=True)
    days_in_situ = serializers.IntegerField(read_only=True)
    max_days = serializers.IntegerField(read_only=True)
    is_active = serializers.BooleanField(read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    created_by_name = serializers.SerializerMethodField()

    class Meta:
        model = DrainLine
        fields = (
            'id', 'patient', 'patient_name', 'line_type', 'line_type_label',
            'name', 'site', 'indication', 'insert_date',
            'max_days_override', 'max_days', 'days_in_situ',
            'is_active', 'is_overdue',
            'dressing_intact', 'site_clean',
            'removed_at', 'removal_reason', 'notes',
            'created_by', 'created_by_name', 'created_at', 'updated_at',
        )
        read_only_fields = ('created_by', 'created_at', 'updated_at')

    def get_created_by_name(self, obj):
        return obj.created_by.full_name if obj.created_by else None


# ───────────────────────────────────────────────
# Audit log
# ───────────────────────────────────────────────
class AuditEventSerializer(serializers.ModelSerializer):
    action_label = serializers.CharField(source='get_action_display', read_only=True)

    class Meta:
        model = AuditEvent
        fields = (
            'id', 'actor_user_id', 'actor_email', 'actor_role',
            'action', 'action_label', 'object_type', 'object_id',
            'object_repr', 'method', 'path', 'ip', 'user_agent',
            'payload_diff', 'extra', 'status_code', 'created_at',
        )
        read_only_fields = fields


# ─────────────────────────────────────────────
# Drug interactions & prescription safety
# ─────────────────────────────────────────────
class DrugInteractionSerializer(serializers.ModelSerializer):
    severity_label = serializers.CharField(source='get_severity_display', read_only=True)

    class Meta:
        model = DrugInteraction
        fields = ('id', 'drug_a', 'drug_b', 'severity', 'severity_label',
                  'summary', 'detail', 'references', 'is_active',
                  'created_at', 'updated_at')
        read_only_fields = ('created_at', 'updated_at')


class PrescriptionSafetyAlertSerializer(serializers.ModelSerializer):
    overridden_by_name = serializers.SerializerMethodField()
    severity_label = serializers.CharField(source='get_severity_display', read_only=True)
    kind_label = serializers.CharField(source='get_kind_display', read_only=True)

    class Meta:
        model = PrescriptionSafetyAlert
        fields = ('id', 'prescription', 'kind', 'kind_label',
                  'severity', 'severity_label', 'message', 'detail', 'drugs',
                  'overridden', 'overridden_by', 'overridden_by_name',
                  'overridden_at', 'override_reason', 'created_at')
        read_only_fields = ('overridden_by', 'overridden_at', 'created_at')

    def get_overridden_by_name(self, obj):
        return obj.overridden_by.full_name if obj.overridden_by else None


# ─────────────────────────────────────────────
# Care pathways (protocol bundles)
# ─────────────────────────────────────────────
class CarePathwaySerializer(serializers.ModelSerializer):
    class Meta:
        model = CarePathway
        fields = ('id', 'name', 'code', 'code_system', 'condition_label',
                  'description', 'default_duration_days', 'goals',
                  'medication_orders', 'vital_targets', 'tasks',
                  'is_active', 'created_at', 'updated_at')
        read_only_fields = ('created_at', 'updated_at')


class CarePathwayEnrollmentSerializer(serializers.ModelSerializer):
    pathway_name = serializers.CharField(source='pathway.name', read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = CarePathwayEnrollment
        fields = ('id', 'pathway', 'pathway_name', 'patient', 'patient_name',
                  'treatment_plan', 'status', 'status_label',
                  'started_at', 'started_by_user_id', 'target_end_date',
                  'completed_at', 'outcome_notes', 'meta')
        read_only_fields = ('treatment_plan', 'started_at', 'started_by_user_id', 'meta')




class MailAccountSerializer(serializers.ModelSerializer):
    """Per-tenant mailbox configuration. Password is write-only."""
    password = serializers.CharField(write_only=True, required=False, allow_blank=True,
                                     style={'input_type': 'password'})
    has_password = serializers.SerializerMethodField()

    class Meta:
        from .models import MailAccount
        model = MailAccount
        fields = [
            'id', 'display_name', 'email',
            'imap_host', 'imap_port', 'imap_use_ssl',
            'smtp_host', 'smtp_port', 'smtp_use_ssl',
            'username', 'password', 'has_password', 'is_active',
            'last_verified_at', 'last_verified_ok', 'last_error',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'has_password', 'last_verified_at',
                            'last_verified_ok', 'last_error',
                            'created_at', 'updated_at']

    def get_has_password(self, obj):
        return bool(obj.password)

    def update(self, instance, validated_data):
        # Allow keeping the existing password by omitting / blanking it.
        pwd = validated_data.pop('password', None)
        for k, v in validated_data.items():
            setattr(instance, k, v)
        if pwd:
            instance.password = pwd
        instance.save()
        return instance


# ───────────────────────────────────────────────
# Patient care management & billing
# ───────────────────────────────────────────────
class CarePlanSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    plan_type_label = serializers.CharField(source='get_plan_type_display', read_only=True)
    accrued_cost = serializers.SerializerMethodField()
    expected_cost = serializers.SerializerMethodField()

    class Meta:
        model = CarePlan
        fields = (
            'id', 'patient', 'patient_name', 'plan_type', 'plan_type_label',
            'rate', 'currency', 'start_date', 'end_date', 'is_active', 'notes',
            'created_by_user_id', 'created_by_name', 'accrued_cost', 'expected_cost',
            'auto_bill', 'last_auto_billed_at', 'last_auto_billed_visits',
            'created_at', 'updated_at',
        )
        read_only_fields = ('created_by_user_id', 'created_by_name',
                            'last_auto_billed_at', 'last_auto_billed_visits',
                            'created_at', 'updated_at')

    def get_accrued_cost(self, obj):
        return str(obj.accrued_cost())

    def get_expected_cost(self, obj):
        return str(obj.expected_cost())


class MedicalSupplySerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    category_label = serializers.CharField(source='get_category_display', read_only=True)
    total_cost = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    days_remaining = serializers.IntegerField(read_only=True)
    usage_status = serializers.CharField(read_only=True)

    class Meta:
        model = MedicalSupply
        fields = (
            'id', 'patient', 'patient_name', 'name', 'category', 'category_label',
            'quantity', 'unit', 'unit_price', 'currency', 'total_cost',
            'supplied_at', 'expiry_date', 'max_use_days', 'replace_due',
            'days_remaining', 'usage_status', 'is_active', 'billable', 'notes',
            'created_at', 'updated_at',
        )
        read_only_fields = ('created_at', 'updated_at')


class PatientPaymentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    method_label = serializers.CharField(source='get_method_display', read_only=True)
    bill_number = serializers.CharField(source='bill.bill_number', read_only=True, default=None)

    class Meta:
        model = PatientPayment
        fields = (
            'id', 'patient', 'patient_name', 'bill', 'bill_number', 'amount', 'currency',
            'method', 'method_label', 'reference', 'paid_at',
            'received_by_user_id', 'received_by_name', 'notes', 'created_at',
        )
        read_only_fields = ('received_by_user_id', 'received_by_name', 'created_at')


class PatientBillSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    medical_record_number = serializers.CharField(
        source='patient.medical_record_number', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    payments = PatientPaymentSerializer(many=True, read_only=True)

    class Meta:
        model = PatientBill
        fields = (
            'id', 'patient', 'patient_name', 'medical_record_number', 'bill_number',
            'period_start', 'as_of',
            'currency', 'line_items', 'care_total', 'equipment_total',
            'supplies_total', 'medication_total', 'subtotal', 'discount', 'tax',
            'total', 'amount_paid', 'balance', 'status', 'status_label', 'notes',
            'generated_by_user_id', 'generated_by_name', 'payments',
            'created_at', 'updated_at',
        )
        read_only_fields = (
            'bill_number', 'line_items', 'care_total', 'equipment_total',
            'supplies_total', 'medication_total', 'subtotal', 'total',
            'amount_paid', 'balance', 'generated_by_user_id', 'generated_by_name',
            'created_at', 'updated_at',
        )


class BillingSettingsSerializer(serializers.ModelSerializer):
    billing_type_label = serializers.CharField(source='get_billing_type_display', read_only=True)
    is_auto_enabled = serializers.BooleanField(read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = BillingSettings
        fields = (
            'id', 'patient', 'patient_name', 'billing_type', 'billing_type_label',
            'auto_generate', 'last_run_at', 'is_auto_enabled',
            'updated_by_user_id', 'updated_by_name', 'created_at', 'updated_at',
        )
        read_only_fields = (
            'last_run_at', 'updated_by_user_id', 'updated_by_name',
            'created_at', 'updated_at',
        )


# ─────────────────────────────────────────────────────────
#  Patient documents
# ─────────────────────────────────────────────────────────
class PatientDocumentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = PatientDocument
        fields = (
            'id', 'name', 'category', 'patient', 'patient_name',
            'access_level', 'description', 'file', 'file_url',
            'file_type', 'file_size', 'expiry_date',
            'uploaded_by', 'uploaded_at',
        )
        read_only_fields = ('file_type', 'file_size', 'uploaded_by', 'uploaded_at')

    def get_file_url(self, obj):
        if not obj.file:
            return None
        request = self.context.get('request')
        url = obj.file.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    def _process_file(self, validated_data):
        file = validated_data.get('file')
        if file:
            validated_data['file_type'] = file.name.rsplit('.', 1)[-1].lower() if '.' in file.name else 'file'
            validated_data['file_size'] = file.size

    def create(self, validated_data):
        self._process_file(validated_data)
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['uploaded_by'] = request.user
        return super().create(validated_data)

    def update(self, instance, validated_data):
        self._process_file(validated_data)
        return super().update(instance, validated_data)


# ─────────────────────────────────────────────────────────
#  Patient Assessment Module
# ─────────────────────────────────────────────────────────
class AssessmentAlertSerializer(serializers.ModelSerializer):
    category_label = serializers.CharField(source='get_category_display', read_only=True)
    severity_label = serializers.CharField(source='get_severity_display', read_only=True)

    class Meta:
        model = AssessmentAlert
        fields = (
            'id', 'session', 'code', 'category', 'category_label',
            'severity', 'severity_label', 'title', 'detail', 'threshold',
            'value', 'recommendation', 'escalation', 'resolved', 'resolved_at',
            'created_at',
        )
        read_only_fields = (
            'code', 'title', 'detail', 'threshold', 'value', 'recommendation',
            'escalation', 'created_at',
        )


class AssessmentSessionSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    medical_record_number = serializers.CharField(
        source='patient.medical_record_number', read_only=True)
    caregiver_name = serializers.CharField(
        source='caregiver.user.full_name', read_only=True)
    session_type_label = serializers.CharField(
        source='get_session_type_display', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    overall_risk_label = serializers.CharField(
        source='get_overall_risk_level_display', read_only=True)
    alerts = AssessmentAlertSerializer(many=True, read_only=True)

    class Meta:
        model = AssessmentSession
        fields = (
            'id', 'patient', 'patient_name', 'medical_record_number',
            'schedule', 'caregiver', 'caregiver_name',
            'session_type', 'session_type_label', 'status', 'status_label',
            'arrival', 'initial_survey', 'head_to_toe',
            'catheter_bundle', 'ventilator_bundle', 'central_line_bundle',
            'wound_bundle', 'disease_bundles',
            'braden_total', 'caprini_points', 'morse_score', 'must_score',
            'pain_score', 'cam_positive', 'gcs_total',
            'overall_risk_level', 'overall_risk_label',
            'alerts_triggered', 'alerts', 'alert_count',
            'notes', 'assessed_by_user_id', 'assessed_by_name',
            'assessed_at', 'signed_at', 'created_at', 'updated_at',
        )
        read_only_fields = (
            'braden_total', 'caprini_points', 'morse_score', 'must_score',
            'pain_score', 'cam_positive', 'gcs_total', 'overall_risk_level',
            'alerts_triggered', 'alerts', 'alert_count',
            'assessed_by_user_id', 'assessed_by_name',
            'assessed_at', 'signed_at', 'created_at', 'updated_at',
        )


# ─────────────────────────────
#  Individual assessment scale serializers — one per strictly-separate
#  model, each linked to a parent AssessmentSession ``episode``.
# ─────────────────────────────
class BradenAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = BradenAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'sensory', 'moisture', 'activity', 'mobility', 'nutrition', 'friction',
            'total', 'risk_level', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('total', 'risk_level', 'assessed_by_user_id',
                           'assessed_by_name', 'created_at', 'updated_at')


class CapriniAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = CapriniAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'age', 'factors', 'points', 'risk_level', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('risk_level', 'assessed_by_user_id',
                           'assessed_by_name', 'created_at', 'updated_at')


class MorseAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = MorseAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'history_of_falls', 'secondary_dx', 'ambulatory_aid', 'iv_lock',
            'gait', 'mental_status', 'score', 'risk_level', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('score', 'risk_level', 'assessed_by_user_id',
                           'assessed_by_name', 'created_at', 'updated_at')


class MustAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = MustAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'height_cm', 'weight_kg', 'bmi', 'bmi_score',
            'weight_loss_percent', 'loss_score', 'acute_no_nutrition', 'acute_score',
            'total_score', 'risk_level', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('bmi', 'bmi_score', 'acute_score',
                           'total_score', 'risk_level', 'assessed_by_user_id',
                           'assessed_by_name', 'created_at', 'updated_at')


class CamAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = CamAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'acute_onset', 'inattention', 'disorganized_thinking', 'altered_consciousness',
            'cam_positive', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('cam_positive', 'assessed_by_user_id',
                           'assessed_by_name', 'created_at', 'updated_at')


class PainAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    flacc_total = serializers.SerializerMethodField()
    painad_total = serializers.SerializerMethodField()

    class Meta:
        model = PainAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            # Screening & tool
            'has_pain', 'tool_type',
            # NRS / VAS core
            'score', 'score_category',
            'worst_pain_24h', 'least_pain_24h', 'average_pain', 'acceptable_pain_goal',
            # VAS
            'vas_mm',
            # Wong-Baker FACES
            'faces_choice', 'faces_description',
            # FLACC subscales
            'flacc_face', 'flacc_legs', 'flacc_activity', 'flacc_cry', 'flacc_consolability',
            'flacc_total',
            # PAINAD subscales
            'painad_breathing', 'painad_negative_vocal', 'painad_facial',
            'painad_body_language', 'painad_consolability',
            'painad_total',
            # PQRST Framework
            'provocation_factors', 'palliation_factors',
            'quality_descriptors', 'quality_other',
            'pain_locations', 'has_radiation', 'radiation_pathway',
            'onset_type', 'pain_pattern', 'pain_duration', 'pain_frequency', 'onset_datetime',
            # Pain history
            'last_pain_episode',
            # Functional impact
            'impact_sleep', 'impact_adl', 'impact_mood', 'impact_appetite', 'impact_other',
            # Treatment response
            'pre_treatment_score', 'post_treatment_score', 'treatment_given', 'reassessment_due_at',
            # Audit
            'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('score_category', 'flacc_total', 'painad_total',
                           'assessed_by_user_id', 'assessed_by_name',
                           'created_at', 'updated_at')

    @staticmethod
    def get_flacc_total(obj):
        subs = [obj.flacc_face, obj.flacc_legs, obj.flacc_activity, obj.flacc_cry, obj.flacc_consolability]
        if all(s is not None for s in subs):
            return sum(subs)
        return None

    @staticmethod
    def get_painad_total(obj):
        subs = [obj.painad_breathing, obj.painad_negative_vocal, obj.painad_facial,
                obj.painad_body_language, obj.painad_consolability]
        if all(s is not None for s in subs):
            return sum(subs)
        return None


class SkinCareAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = SkinCareAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'reposition', 'surface', 'moisture', 'nutrition', 'heels', 'inspect',
            'completed_count', 'completed_items', 'bundle_completed', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('completed_count', 'completed_items', 'bundle_completed',
                           'assessed_by_user_id', 'assessed_by_name',
                           'created_at', 'updated_at')


class GcsAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = GcsAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'eyes', 'verbal', 'motor', 'total', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('total', 'assessed_by_user_id', 'assessed_by_name',
                           'created_at', 'updated_at')


class DiabetesBundleAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = DiabetesBundleAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'glucose', 'ketones', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('assessed_by_user_id', 'assessed_by_name',
                           'created_at', 'updated_at')


class HeartFailureBundleAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = HeartFailureBundleAssessment
        fields = (
            'id', 'episode', 'patient', 'patient_name',
            'weight_kg', 'fluid_balance_ml', 'spo2', 'notes',
            'assessed_by_user_id', 'assessed_by_name', 'assessed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = ('assessed_by_user_id', 'assessed_by_name',
                           'created_at', 'updated_at')


class PIVCAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = PIVCAssessment
        fields = '__all__'
        read_only_fields = (
            'vip_score', 'vip_colour', 'vip_label', 'recommendations',
            'bundle_compliance_pct', 'assessed_by_user_id', 'assessed_by_name',
            'created_at', 'updated_at',
        )


class EnteralFeedingAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = EnteralFeedingAssessment
        fields = '__all__'
        read_only_fields = (
            'bundle_compliance_pct', 'assessed_by_user_id', 'assessed_by_name',
            'created_at', 'updated_at',
        )


class UrinaryCatheterAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = UrinaryCatheterAssessment
        fields = '__all__'
        read_only_fields = (
            'bundle_compliance_pct', 'assessed_by_user_id', 'assessed_by_name',
            'created_at', 'updated_at',
        )


class ArtificialAirwayAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    airway_device_label = serializers.CharField(source='get_airway_device_display', read_only=True)
    assessment_type_label = serializers.CharField(source='get_assessment_type_display', read_only=True)

    class Meta:
        model = ArtificialAirwayAssessment
        fields = '__all__'
        read_only_fields = (
            'trach_compliance_pct', 'vap_compliance_pct', 'overall_compliance_pct',
            'emergency_equipment_incomplete',
            'assessed_by_user_id', 'assessed_by_name', 'created_at', 'updated_at',
        )


class CVADAssessmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    device_type_label = serializers.CharField(source='get_device_type_display', read_only=True)
    assessment_type_label = serializers.CharField(source='get_assessment_type_display', read_only=True)

    class Meta:
        model = CVADAssessment
        fields = '__all__'
        read_only_fields = (
            'bundle_compliance_pct', 'suspected_clabsi', 'escalation_required',
            'assessed_by_user_id', 'assessed_by_name', 'created_at', 'updated_at',
        )

