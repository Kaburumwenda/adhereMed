"""Homecare app — tenant-isolated facility for in-home patient care.

Models cover the full lifecycle: company profile, caregivers, patients,
treatment plans, medication schedules and per-dose tracking, escalations,
teleconsult rooms, prescriptions forwarded to pharmacies, insurance
policies & claims, and patient consents.
"""
import uuid
from django.conf import settings
from django.db import models
from django.utils import timezone


# ─────────────────────────────────────────────────────────
# Company profile (singleton-per-tenant)
# ─────────────────────────────────────────────────────────
class HomecareCompanyProfile(models.Model):
    legal_name = models.CharField(max_length=255)
    registration_number = models.CharField(max_length=100, blank=True)
    license_url = models.URLField(blank=True)
    address = models.TextField(blank=True)
    city = models.CharField(max_length=100, blank=True)
    country = models.CharField(max_length=100, default='Kenya')
    contact_phone = models.CharField(max_length=30, blank=True)
    contact_email = models.EmailField(blank=True)
    accreditations = models.JSONField(default=list, blank=True)
    service_areas = models.JSONField(default=list, blank=True,
                                     help_text='List of neighbourhoods / cities served')
    about = models.TextField(blank=True)
    logo = models.ImageField(upload_to='homecare/logos/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Homecare company profile'
        verbose_name_plural = 'Homecare company profile'

    def __str__(self):
        return self.legal_name


# ─────────────────────────────────────────────────────────
# Caregivers
# ─────────────────────────────────────────────────────────
class Caregiver(models.Model):
    class EmploymentStatus(models.TextChoices):
        ACTIVE = 'active', 'Active'
        SUSPENDED = 'suspended', 'Suspended'
        TERMINATED = 'terminated', 'Terminated'
        ON_LEAVE = 'on_leave', 'On Leave'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='caregiver_profile',
    )
    license_number = models.CharField(max_length=100, blank=True)
    certifications = models.JSONField(default=list, blank=True,
                                      help_text='[{name, issuer, year, url}]')
    specialties = models.JSONField(default=list, blank=True,
                                   help_text='e.g. ["elderly", "post-op", "pediatric"]')
    bio = models.TextField(blank=True)
    photo = models.ImageField(upload_to='homecare/caregivers/', blank=True, null=True)
    hourly_rate = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_independent = models.BooleanField(default=False,
                                         help_text='True if caregiver operates as a single-person tenant')
    is_available = models.BooleanField(default=True)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)
    total_visits = models.PositiveIntegerField(default=0)
    hire_date = models.DateField(null=True, blank=True)
    employment_status = models.CharField(
        max_length=20, choices=EmploymentStatus.choices, default=EmploymentStatus.ACTIVE,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_available', '-rating', 'user__first_name']

    def __str__(self):
        return f'Caregiver: {self.user.full_name}'


# ─────────────────────────────────────────────────────────
# Patients
# ─────────────────────────────────────────────────────────
class HomecarePatient(models.Model):
    class RiskLevel(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        related_name='homecare_patients',
        help_text='Shared user account (role=patient).',
    )
    medical_record_number = models.CharField(max_length=40, unique=True, editable=False)
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=20, blank=True)
    address = models.TextField(blank=True)
    primary_diagnosis = models.CharField(max_length=255, blank=True)
    medical_history = models.TextField(blank=True)
    allergies = models.TextField(blank=True)
    emergency_contacts = models.JSONField(default=list, blank=True,
                                          help_text='[{name, relationship, phone, email}]')
    assigned_caregiver = models.ForeignKey(
        Caregiver, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='patients',
    )
    assigned_doctor_user_id = models.IntegerField(
        null=True, blank=True,
        help_text='ID of the responsible doctor User (shared schema).',
    )
    risk_level = models.CharField(
        max_length=10, choices=RiskLevel.choices, default=RiskLevel.LOW,
    )
    is_active = models.BooleanField(default=True)
    enrolled_at = models.DateTimeField(auto_now_add=True)
    discharged_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-enrolled_at']

    def __str__(self):
        return f'{self.user.full_name} ({self.medical_record_number})'

    def save(self, *args, **kwargs):
        if not self.medical_record_number:
            self.medical_record_number = f'HC-{uuid.uuid4().hex[:8].upper()}'
        super().save(*args, **kwargs)


# ─────────────────────────────────────────────────────────
# Caregiver schedule + visits
# ─────────────────────────────────────────────────────────
class CaregiverSchedule(models.Model):
    class ShiftType(models.TextChoices):
        VISIT = 'visit', 'Single Visit'
        LIVE_IN = 'live_in', 'Live-in'
        ON_CALL = 'on_call', 'On Call'

    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        CHECKED_IN = 'checked_in', 'Checked In'
        COMPLETED = 'completed', 'Completed'
        MISSED = 'missed', 'Missed'
        CANCELLED = 'cancelled', 'Cancelled'

    caregiver = models.ForeignKey(Caregiver, on_delete=models.CASCADE, related_name='schedules')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE, related_name='schedules')
    shift_type = models.CharField(max_length=20, choices=ShiftType.choices, default=ShiftType.VISIT)
    start_at = models.DateTimeField()
    end_at = models.DateTimeField()
    recurrence = models.JSONField(default=dict, blank=True,
                                  help_text='{freq: daily|weekly, byday: [...], until: ISO}')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SCHEDULED)
    check_in_at = models.DateTimeField(null=True, blank=True)
    check_out_at = models.DateTimeField(null=True, blank=True)
    gps_check_in = models.JSONField(default=dict, blank=True, help_text='{lat, lng, accuracy}')
    gps_check_out = models.JSONField(default=dict, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-start_at']
        indexes = [models.Index(fields=['caregiver', 'start_at']),
                   models.Index(fields=['patient', 'start_at']),
                   models.Index(fields=['status', 'start_at'])]

    def __str__(self):
        return f'{self.caregiver.user.full_name} → {self.patient.user.full_name} @ {self.start_at:%Y-%m-%d %H:%M}'


class CaregiverNote(models.Model):
    class Category(models.TextChoices):
        DIET = 'diet', 'Diet'
        ACTIVITY = 'activity', 'Activity'
        OBSERVATION = 'observation', 'Observation'
        VITALS = 'vitals', 'Vitals'
        INCIDENT = 'incident', 'Incident'
        MEDICATION = 'medication', 'Medication'

    caregiver = models.ForeignKey(Caregiver, on_delete=models.CASCADE, related_name='notes')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE, related_name='caregiver_notes')
    schedule = models.ForeignKey(CaregiverSchedule, on_delete=models.SET_NULL,
                                 null=True, blank=True, related_name='caregiver_notes')
    category = models.CharField(max_length=20, choices=Category.choices)
    content = models.TextField()
    vitals = models.JSONField(default=dict, blank=True,
                              help_text='{bp, hr, temp, spo2, glucose, weight}')
    attached_files = models.JSONField(default=list, blank=True)
    recorded_at = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-recorded_at']

    def __str__(self):
        return f'{self.get_category_display()} note for {self.patient.user.full_name}'


# ─────────────────────────────────────────────────────────
# Treatment plans + medication schedules + dose events
# ─────────────────────────────────────────────────────────
class TreatmentPlan(models.Model):
    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        PAUSED = 'paused', 'Paused'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='treatment_plans')
    created_by_doctor_id = models.IntegerField(null=True, blank=True)
    title = models.CharField(max_length=255)
    diagnosis = models.CharField(max_length=255, blank=True)
    goals = models.JSONField(default=list, blank=True)
    start_date = models.DateField(default=timezone.now)
    end_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-start_date']

    def __str__(self):
        return f'{self.title} – {self.patient.user.full_name}'


class MedicationSchedule(models.Model):
    class Route(models.TextChoices):
        ORAL = 'oral', 'Oral'
        IV = 'iv', 'IV'
        IM = 'im', 'Intramuscular'
        SC = 'sc', 'Subcutaneous'
        TOPICAL = 'topical', 'Topical'
        INHALED = 'inhaled', 'Inhaled'
        OTHER = 'other', 'Other'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='medication_schedules')
    treatment_plan = models.ForeignKey(TreatmentPlan, on_delete=models.SET_NULL,
                                       null=True, blank=True, related_name='medication_schedules')
    medication_id = models.IntegerField(null=True, blank=True,
                                        help_text='FK to shared medications.Medication (id only)')
    medication_name = models.CharField(max_length=255)
    dose = models.CharField(max_length=100)
    route = models.CharField(max_length=20, choices=Route.choices, default=Route.ORAL)
    frequency_cron = models.CharField(
        max_length=100, blank=True,
        help_text='Optional cron-style schedule (m h dom mon dow)',
    )
    times_of_day = models.JSONField(
        default=list, blank=True,
        help_text='Simple list of times like ["08:00","20:00"]; used if frequency_cron empty.',
    )
    start_date = models.DateField(default=timezone.now)
    end_date = models.DateField(null=True, blank=True)
    instructions = models.TextField(blank=True)
    requires_caregiver = models.BooleanField(default=False)
    prescribed_by_doctor_id = models.IntegerField(null=True, blank=True)
    source_prescription_id = models.IntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-start_date']

    def __str__(self):
        return f'{self.medication_name} {self.dose} – {self.patient.user.full_name}'


class DoseEvent(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        TAKEN = 'taken', 'Taken'
        MISSED = 'missed', 'Missed'
        SKIPPED = 'skipped', 'Skipped'
        REFUSED = 'refused', 'Refused'

    schedule = models.ForeignKey(MedicationSchedule, on_delete=models.CASCADE,
                                 related_name='doses')
    scheduled_at = models.DateTimeField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    administered_at = models.DateTimeField(null=True, blank=True)
    administered_by_caregiver = models.ForeignKey(
        Caregiver, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='administered_doses',
    )
    notes = models.TextField(blank=True)
    vitals_pre = models.JSONField(default=dict, blank=True)
    vitals_post = models.JSONField(default=dict, blank=True)
    patient_confirmation = models.TextField(blank=True,
                                            help_text='Patient confirmation note or photo URL.')
    reminded_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['scheduled_at']
        indexes = [models.Index(fields=['scheduled_at', 'status']),
                   models.Index(fields=['schedule', 'scheduled_at'])]
        constraints = [models.UniqueConstraint(fields=['schedule', 'scheduled_at'],
                                               name='unique_dose_per_schedule_time')]

    def __str__(self):
        return f'Dose @ {self.scheduled_at:%Y-%m-%d %H:%M} ({self.status})'


# ─────────────────────────────────────────────────────────
# Escalations
# ─────────────────────────────────────────────────────────
class EscalationRule(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    missed_doses_window_hours = models.PositiveIntegerField(default=72)
    missed_count_threshold = models.PositiveIntegerField(default=1)
    risk_level_filter = models.CharField(max_length=10, blank=True,
                                         help_text='Apply only to this risk level (blank = all)')
    notify_caregiver = models.BooleanField(default=True)
    notify_doctor = models.BooleanField(default=True)
    notify_family = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class Escalation(models.Model):
    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        ACKNOWLEDGED = 'acknowledged', 'Acknowledged'
        RESOLVED = 'resolved', 'Resolved'

    class Severity(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='escalations')
    rule = models.ForeignKey(EscalationRule, on_delete=models.SET_NULL, null=True, blank=True)
    triggered_at = models.DateTimeField(default=timezone.now)
    reason = models.CharField(max_length=255)
    detail = models.TextField(blank=True)
    severity = models.CharField(max_length=10, choices=Severity.choices, default=Severity.MEDIUM)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.OPEN)
    acknowledged_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='homecare_escalations_ack',
    )
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolution_notes = models.TextField(blank=True)
    related_dose_ids = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ['-triggered_at']

    def __str__(self):
        return f'Escalation: {self.reason} ({self.patient.user.full_name})'


# ─────────────────────────────────────────────────────────
# Teleconsult & appointments
# ─────────────────────────────────────────────────────────
class TeleconsultRoom(models.Model):
    class Provider(models.TextChoices):
        JITSI = 'jitsi', 'Jitsi'
        TWILIO = 'twilio', 'Twilio'
        INTERNAL = 'internal_webrtc', 'Internal WebRTC'

    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        IN_PROGRESS = 'in_progress', 'In Progress'
        ENDED = 'ended', 'Ended'
        CANCELLED = 'cancelled', 'Cancelled'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='teleconsult_rooms')
    doctor_user_id = models.IntegerField()
    scheduled_at = models.DateTimeField()
    duration_minutes = models.PositiveIntegerField(default=30)
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    room_token = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    provider = models.CharField(max_length=20, choices=Provider.choices, default=Provider.JITSI)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SCHEDULED)
    join_urls = models.JSONField(default=dict, blank=True,
                                 help_text='{patient: url, doctor: url}')
    recording_url = models.URLField(blank=True)
    summary = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-scheduled_at']

    def __str__(self):
        return f'Teleconsult {self.room_token} ({self.status})'


class HomecareAppointment(models.Model):
    class AppointmentType(models.TextChoices):
        IN_HOME = 'in_home', 'In-home Visit'
        TELECONSULT = 'teleconsult', 'Teleconsult'
        CLINIC = 'clinic', 'Clinic Visit'

    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        CONFIRMED = 'confirmed', 'Confirmed'
        COMPLETED = 'completed', 'Completed'
        NO_SHOW = 'no_show', 'No Show'
        CANCELLED = 'cancelled', 'Cancelled'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='appointments')
    doctor_user_id = models.IntegerField(null=True, blank=True)
    doctor_name = models.CharField(max_length=255, blank=True)
    appointment_type = models.CharField(max_length=20, choices=AppointmentType.choices,
                                        default=AppointmentType.IN_HOME)
    scheduled_at = models.DateTimeField()
    duration_minutes = models.PositiveIntegerField(default=30)
    location = models.JSONField(default=dict, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SCHEDULED)
    notes = models.TextField(blank=True)
    teleconsult_room = models.ForeignKey(TeleconsultRoom, on_delete=models.SET_NULL,
                                         null=True, blank=True, related_name='appointments')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-scheduled_at']

    def __str__(self):
        return f'{self.get_appointment_type_display()} – {self.patient.user.full_name}'


# ─────────────────────────────────────────────────────────
# Pharmacy + prescriptions
# ─────────────────────────────────────────────────────────
class HomecarePrescription(models.Model):
    class PharmacyStatus(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        PENDING = 'pending', 'Pending'
        ACCEPTED = 'accepted', 'Accepted'
        SUBSTITUTED = 'substituted', 'Substituted'
        DECLINED = 'declined', 'Declined'
        DISPENSED = 'dispensed', 'Dispensed'
        CANCELLED = 'cancelled', 'Cancelled'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='prescriptions')
    treatment_plan = models.ForeignKey(TreatmentPlan, on_delete=models.SET_NULL,
                                       null=True, blank=True, related_name='prescriptions')
    prescribed_by_doctor_id = models.IntegerField(null=True, blank=True)
    prescribed_by_name = models.CharField(max_length=255, blank=True)
    items = models.JSONField(
        default=list,
        help_text='[{medication_id, name, dose, qty, instructions}]',
    )
    forwarded_to_pharmacy_tenant_id = models.IntegerField(null=True, blank=True)
    forwarded_pharmacy_name = models.CharField(max_length=255, blank=True)
    forwarded_at = models.DateTimeField(null=True, blank=True)
    pharmacy_status = models.CharField(
        max_length=20, choices=PharmacyStatus.choices, default=PharmacyStatus.DRAFT,
    )
    substitution_proposed = models.JSONField(default=list, blank=True)
    patient_approved_substitution = models.BooleanField(null=True, blank=True)
    exchange_ref = models.CharField(max_length=100, blank=True,
                                    help_text='ID of PrescriptionExchange in public schema.')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Rx #{self.id} – {self.patient.user.full_name}'


class PharmacyStockAlert(models.Model):
    class StockStatus(models.TextChoices):
        IN = 'in', 'In Stock'
        LOW = 'low', 'Low Stock'
        OUT = 'out', 'Out of Stock'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='stock_alerts')
    prescription = models.ForeignKey(HomecarePrescription, on_delete=models.SET_NULL,
                                     null=True, blank=True, related_name='stock_alerts')
    medication_name = models.CharField(max_length=255)
    pharmacy_tenant_id = models.IntegerField(null=True, blank=True)
    pharmacy_name = models.CharField(max_length=255, blank=True)
    stock_status = models.CharField(max_length=10, choices=StockStatus.choices)
    substitutions = models.JSONField(default=list, blank=True)
    resolved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.medication_name} – {self.get_stock_status_display()}'


# ─────────────────────────────────────────────────────────
# Insurance
# ─────────────────────────────────────────────────────────
class InsurancePolicy(models.Model):
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='insurance_policies')
    provider_name = models.CharField(max_length=255)
    policy_number = models.CharField(max_length=100)
    member_id = models.CharField(max_length=100, blank=True)
    valid_from = models.DateField(null=True, blank=True)
    valid_to = models.DateField(null=True, blank=True)
    coverage = models.JSONField(default=dict, blank=True,
                                help_text='{visits: %, medication: %, teleconsult: %, ...}')
    is_primary = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_primary', 'provider_name']

    def __str__(self):
        return f'{self.provider_name} – {self.policy_number}'


class InsuranceClaim(models.Model):
    class ClaimType(models.TextChoices):
        VISIT = 'visit', 'Caregiver Visit'
        MEDICATION = 'medication', 'Medication'
        TELECONSULT = 'teleconsult', 'Teleconsult'
        PROCEDURE = 'procedure', 'Procedure'
        OTHER = 'other', 'Other'

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        SUBMITTED = 'submitted', 'Submitted'
        APPROVED = 'approved', 'Approved'
        DENIED = 'denied', 'Denied'
        PARTIAL = 'partial', 'Partially Approved'
        PAID = 'paid', 'Paid'

    claim_number = models.CharField(max_length=30, unique=True, editable=False)
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='insurance_claims')
    policy = models.ForeignKey(InsurancePolicy, on_delete=models.PROTECT,
                               related_name='claims')
    claim_type = models.CharField(max_length=20, choices=ClaimType.choices)
    service_start = models.DateField()
    service_end = models.DateField()
    amount_requested = models.DecimalField(max_digits=12, decimal_places=2)
    breakdown = models.JSONField(default=list, blank=True,
                                 help_text='[{description, qty, unit_price, total}]')
    submitted_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    approved_amount = models.DecimalField(max_digits=12, decimal_places=2,
                                          null=True, blank=True)
    denial_reason = models.TextField(blank=True)
    payer_response = models.JSONField(default=dict, blank=True)
    attachments = models.JSONField(default=list, blank=True,
                                   help_text='[{name, url, type}]')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Claim {self.claim_number} – {self.get_status_display()}'

    def save(self, *args, **kwargs):
        if not self.claim_number:
            self.claim_number = f'CLM-{uuid.uuid4().hex[:8].upper()}'
        super().save(*args, **kwargs)


# ─────────────────────────────────────────────────────────
# Patient consents
# ─────────────────────────────────────────────────────────
class Consent(models.Model):
    class Scope(models.TextChoices):
        RECORDS = 'records', 'Medical Records'
        MEDICATION = 'medication', 'Medication Plan'
        INSURANCE = 'insurance', 'Insurance Sharing'
        TELECONSULT = 'teleconsult', 'Teleconsult'
        DATA_ANALYTICS = 'data_analytics', 'Data Analytics'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='consents')
    scope = models.CharField(max_length=20, choices=Scope.choices)
    granted_to = models.CharField(max_length=255, blank=True,
                                  help_text='Doctor, pharmacy or insurer identifier.')
    granted_to_user_id = models.IntegerField(null=True, blank=True)
    granted_to_tenant_id = models.IntegerField(null=True, blank=True)
    granted_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField(null=True, blank=True)
    signed_document_url = models.URLField(blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-granted_at']

    def __str__(self):
        return f'{self.get_scope_display()} – {self.patient.user.full_name}'

    @property
    def is_active(self):
        if self.revoked_at:
            return False
        if self.expires_at and self.expires_at < timezone.now():
            return False
        return True
