from rest_framework import serializers
from django.contrib.auth import get_user_model

from .models import (
    HomecareCompanyProfile, Caregiver, HomecarePatient, CaregiverSchedule,
    CaregiverNote, TreatmentPlan, MedicationSchedule, DoseEvent,
    EscalationRule, Escalation, TeleconsultRoom, HomecareAppointment,
    HomecarePrescription, PharmacyStockAlert, InsurancePolicy, InsuranceClaim,
    Consent,
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

    class Meta:
        model = Caregiver
        fields = (
            'id', 'user', 'user_id', 'license_number', 'certifications',
            'specialties', 'bio', 'photo', 'hourly_rate', 'is_independent',
            'is_available', 'rating', 'total_visits', 'hire_date',
            'employment_status', 'active_patients_count', 'created_at', 'updated_at',
        )
        read_only_fields = ('rating', 'total_visits', 'created_at', 'updated_at')

    def get_active_patients_count(self, obj):
        return obj.patients.filter(is_active=True).count()


# ─────────────────────────────────────────────
class HomecarePatientSerializer(serializers.ModelSerializer):
    user = _UserMiniSerializer(read_only=True)
    user_id = serializers.PrimaryKeyRelatedField(
        source='user', queryset=User.objects.all(), write_only=True,
    )
    assigned_caregiver_name = serializers.SerializerMethodField()
    active_treatment_plan_id = serializers.SerializerMethodField()
    open_escalations = serializers.SerializerMethodField()
    adherence_rate = serializers.SerializerMethodField()

    class Meta:
        model = HomecarePatient
        fields = (
            'id', 'medical_record_number', 'user', 'user_id',
            'date_of_birth', 'gender', 'address',
            'primary_diagnosis', 'medical_history', 'allergies',
            'emergency_contacts', 'assigned_caregiver', 'assigned_caregiver_name',
            'assigned_doctor_user_id', 'risk_level', 'is_active',
            'active_treatment_plan_id', 'open_escalations', 'adherence_rate',
            'enrolled_at', 'discharged_at',
        )
        read_only_fields = ('medical_record_number', 'enrolled_at')

    def get_assigned_caregiver_name(self, obj):
        if obj.assigned_caregiver:
            return obj.assigned_caregiver.user.full_name
        return None

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


# ─────────────────────────────────────────────
class CaregiverScheduleSerializer(serializers.ModelSerializer):
    caregiver_name = serializers.CharField(source='caregiver.user.full_name', read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)

    class Meta:
        model = CaregiverSchedule
        fields = (
            'id', 'caregiver', 'caregiver_name', 'patient', 'patient_name',
            'shift_type', 'start_at', 'end_at', 'recurrence', 'status',
            'check_in_at', 'check_out_at', 'gps_check_in', 'gps_check_out',
            'notes', 'created_at',
        )
        read_only_fields = ('check_in_at', 'check_out_at', 'created_at')


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
            'instructions', 'requires_caregiver',
            'prescribed_by_doctor_id', 'source_prescription_id',
            'is_active', 'upcoming_doses', 'created_at', 'updated_at',
        )
        read_only_fields = ('created_at', 'updated_at')

    def get_upcoming_doses(self, obj):
        return obj.doses.filter(status='pending').count()


class DoseEventSerializer(serializers.ModelSerializer):
    medication_name = serializers.CharField(source='schedule.medication_name', read_only=True)
    dose = serializers.CharField(source='schedule.dose', read_only=True)
    patient_name = serializers.CharField(source='schedule.patient.user.full_name', read_only=True)
    patient_id = serializers.IntegerField(source='schedule.patient_id', read_only=True)
    administered_by_name = serializers.SerializerMethodField()

    class Meta:
        model = DoseEvent
        fields = (
            'id', 'schedule', 'medication_name', 'dose', 'patient_id', 'patient_name',
            'scheduled_at', 'status', 'administered_at', 'administered_by_caregiver',
            'administered_by_name', 'notes', 'vitals_pre', 'vitals_post',
            'patient_confirmation', 'reminded_at', 'created_at',
        )
        read_only_fields = ('reminded_at', 'created_at')

    def get_administered_by_name(self, obj):
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
            'expires_at', 'signed_document_url', 'revoked_at', 'notes',
            'is_active',
        )
        read_only_fields = ('revoked_at',)
