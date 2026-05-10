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
    CarePathway, CarePathwayEnrollment,
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
    assigned_caregiver_name = serializers.SerializerMethodField()
    additional_caregivers_detail = serializers.SerializerMethodField()
    active_treatment_plan_id = serializers.SerializerMethodField()
    open_escalations = serializers.SerializerMethodField()
    adherence_rate = serializers.SerializerMethodField()
    age = serializers.SerializerMethodField()

    class Meta:
        model = HomecarePatient
        fields = (
            'id', 'medical_record_number', 'user', 'user_id',
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
            'instructions', 'requires_caregiver',
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

    class Meta:
        model = Device
        fields = (
            'id', 'name', 'device_type', 'device_type_label', 'serial_number',
            'asset_tag', 'qr_code', 'manufacturer', 'model_number',
            'status', 'status_label', 'assigned_to', 'assigned_to_name',
            'location', 'purchase_date', 'purchase_cost', 'warranty_expiry',
            'last_maintenance_at', 'next_maintenance_due', 'notes', 'photo',
            'created_at', 'updated_at',
        )
        read_only_fields = ('last_maintenance_at', 'created_at', 'updated_at')


class DeviceAssignmentSerializer(serializers.ModelSerializer):
    device_name = serializers.CharField(source='device.name', read_only=True)
    patient_name = serializers.CharField(
        source='patient.user.full_name', read_only=True)
    assigned_by_name = serializers.SerializerMethodField()

    class Meta:
        model = DeviceAssignment
        fields = (
            'id', 'device', 'device_name', 'patient', 'patient_name',
            'assigned_at', 'assigned_by', 'assigned_by_name',
            'expected_return_at', 'returned_at', 'return_condition', 'notes',
        )
        read_only_fields = ('assigned_by',)

    def get_assigned_by_name(self, obj):
        return obj.assigned_by.full_name if obj.assigned_by else None


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
