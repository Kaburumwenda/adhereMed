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

    class Category(models.TextChoices):
        NURSE = 'nurse', 'Nurse'
        HCA = 'hca', 'Health Care Assistant'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='caregiver_profile',
    )
    category = models.CharField(
        max_length=10, choices=Category.choices, default=Category.NURSE,
        db_index=True,
        help_text='Caregiver tier: registered Nurse or Health Care Assistant.',
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
    visit_pin = models.CharField(
        max_length=10, blank=True, default='',
        help_text='Numeric PIN entered by caregiver to confirm check-in / check-out.',
    )
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
    address_lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    address_lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    id_type = models.CharField(
        max_length=30, blank=True,
        help_text='national_id | alien_id | passport | driving_license | birth_cert | military_id | other',
    )
    id_number = models.CharField(max_length=80, blank=True)
    nationality = models.CharField(
        max_length=10, blank=True, default='KE',
        help_text='ISO-3166-1 alpha-2 country code (e.g. KE, UG, US).',
    )
    primary_diagnosis = models.CharField(max_length=255, blank=True)
    medical_history = models.TextField(blank=True)
    allergies = models.TextField(blank=True)
    emergency_contacts = models.JSONField(default=list, blank=True,
                                          help_text='[{name, relationship, phone, email}]')
    assigned_caregiver = models.ForeignKey(
        Caregiver, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='patients',
    )
    additional_caregivers = models.ManyToManyField(
        Caregiver, blank=True, related_name='secondary_patients',
        help_text='Additional caregivers / nurses assigned to this patient.',
    )
    assigned_doctor_user_id = models.IntegerField(
        null=True, blank=True,
        help_text='ID of the responsible doctor User (shared schema).',
    )
    assigned_doctor_info = models.JSONField(
        default=dict, blank=True,
        help_text='Free-form doctor info when no system user exists '
                  '(name, specialization, qualification, phone, email, hospital, …).',
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
    acknowledged_at = models.DateTimeField(null=True, blank=True,
                                           help_text='When caregiver acknowledged the shift at check-in.')
    reassignment_requested = models.BooleanField(default=False)
    reassignment_reason = models.CharField(max_length=255, blank=True, default='')
    reassigned_to = models.ForeignKey(
        'self', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='reassigned_from',
        help_text='New schedule that replaced this missed shift, if any.',
    )
    auto_missed_at = models.DateTimeField(null=True, blank=True,
                                          help_text='Set when system auto-marked this shift as Missed.')
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
    last_generation_at = models.DateTimeField(null=True, blank=True)
    last_generation_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='+',
    )
    last_generation_by_name = models.CharField(max_length=255, blank=True)
    last_generation_by_role = models.CharField(max_length=64, blank=True)
    last_generation_count = models.PositiveIntegerField(default=0)
    last_generation_days = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-start_date']

    def __str__(self):
        return f'{self.medication_name} {self.dose} – {self.patient.user.full_name}'


class DoseEvent(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        TAKEN = 'taken', 'Documented'
        MISSED = 'missed', 'Missed'
        SKIPPED = 'skipped', 'Skipped'
        REFUSED = 'refused', 'Refused'
        NOT_GIVEN = 'not_given', 'Not given'

    schedule = models.ForeignKey(MedicationSchedule, on_delete=models.CASCADE,
                                 related_name='doses')
    scheduled_at = models.DateTimeField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    administered_at = models.DateTimeField(null=True, blank=True)
    administered_by_caregiver = models.ForeignKey(
        Caregiver, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='administered_doses',
    )
    administered_by_user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='+',
    )
    administered_by_name = models.CharField(max_length=255, blank=True)
    administered_by_role = models.CharField(max_length=64, blank=True)
    reason = models.TextField(blank=True,
                              help_text='Reason for skip / not given / edit.')
    notes = models.TextField(blank=True)
    vitals_pre = models.JSONField(default=dict, blank=True)
    vitals_post = models.JSONField(default=dict, blank=True)
    patient_confirmation = models.TextField(blank=True,
                                            help_text='Patient confirmation note or photo URL.')
    reminded_at = models.DateTimeField(null=True, blank=True)
    auto_missed = models.BooleanField(default=False,
                                      help_text='Set when system auto-marks as missed.')
    audit_log = models.JSONField(default=list, blank=True,
                                 help_text='History of status changes with actor & reason.')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

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
    signature_data_url = models.TextField(
        blank=True,
        help_text='Base64 data-URL of the captured signature image (PNG).',
    )
    signed_by_name = models.CharField(max_length=255, blank=True)
    signed_by_relationship = models.CharField(
        max_length=80, blank=True,
        help_text='self / parent / guardian / next-of-kin etc.',
    )
    signed_at = models.DateTimeField(null=True, blank=True)
    signed_ip = models.GenericIPAddressField(null=True, blank=True)
    signed_user_agent = models.CharField(max_length=512, blank=True)
    signature_hash = models.CharField(
        max_length=128, blank=True,
        help_text='SHA-256 of (scope|patient|signature_data_url|signed_at) for tamper detection.',
    )
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


# ─────────────────────────────────────────────────────────
# Tenant-scoped clinical catalog (Diagnoses & Allergies)
# ─────────────────────────────────────────────────────────
class HomecareDiagnosis(models.Model):
    """Per-tenant diagnosis catalog. Seeded from the global clinical_catalog
    by superadmin and editable by the tenant's homecare admin."""

    class Source(models.TextChoices):
        SEED = 'seed', 'Seeded'
        CUSTOM = 'custom', 'Custom'

    name = models.CharField(max_length=255, db_index=True)
    category = models.CharField(max_length=40, blank=True, db_index=True)
    icd_code = models.CharField(max_length=20, blank=True, db_index=True)
    description = models.TextField(blank=True)
    source = models.CharField(max_length=10, choices=Source.choices,
                              default=Source.CUSTOM, db_index=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'name']
        verbose_name = 'Homecare diagnosis'
        verbose_name_plural = 'Homecare diagnoses'
        constraints = [
            models.UniqueConstraint(fields=['name'], name='uniq_homecare_diagnosis_name'),
        ]

    def __str__(self):
        return f'{self.name}{" [" + self.icd_code + "]" if self.icd_code else ""}'


class HomecareAllergy(models.Model):
    """Per-tenant allergy catalog. Seeded from clinical_catalog and editable
    by the tenant's homecare admin."""

    class Source(models.TextChoices):
        SEED = 'seed', 'Seeded'
        CUSTOM = 'custom', 'Custom'

    name = models.CharField(max_length=255, db_index=True)
    category = models.CharField(max_length=40, blank=True, db_index=True)
    description = models.TextField(blank=True)
    common_symptoms = models.TextField(blank=True)
    source = models.CharField(max_length=10, choices=Source.choices,
                              default=Source.CUSTOM, db_index=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'name']
        verbose_name = 'Homecare allergy'
        verbose_name_plural = 'Homecare allergies'
        constraints = [
            models.UniqueConstraint(fields=['name'], name='uniq_homecare_allergy_name'),
        ]

    def __str__(self):
        return self.name


# ─────────────────────────────────────────────────────────
# Equipment / Devices
# ─────────────────────────────────────────────────────────
class Device(models.Model):
    """Medical devices and equipment (oximeters, BP monitors, oxygen
    concentrators, hospital beds, etc.) managed by the homecare provider
    and assigned to patients."""

    class DeviceType(models.TextChoices):
        OXIMETER = 'oximeter', 'Pulse Oximeter'
        BP_MONITOR = 'bp_monitor', 'Blood Pressure Monitor'
        GLUCOMETER = 'glucometer', 'Glucometer'
        THERMOMETER = 'thermometer', 'Thermometer'
        OXYGEN_CONCENTRATOR = 'oxygen', 'Oxygen Concentrator'
        NEBULIZER = 'nebulizer', 'Nebulizer'
        BED = 'bed', 'Hospital Bed'
        WHEELCHAIR = 'wheelchair', 'Wheelchair'
        WALKER = 'walker', 'Walker / Crutches'
        SUCTION = 'suction', 'Suction Machine'
        VENTILATOR = 'ventilator', 'Ventilator'
        INFUSION_PUMP = 'infusion_pump', 'Infusion Pump'
        ECG = 'ecg', 'ECG Monitor'
        OTHER = 'other', 'Other'

    class Status(models.TextChoices):
        AVAILABLE = 'available', 'Available'
        ASSIGNED = 'assigned', 'Assigned to Patient'
        MAINTENANCE = 'maintenance', 'In Maintenance'
        REPAIR = 'repair', 'Needs Repair'
        RETIRED = 'retired', 'Retired'
        LOST = 'lost', 'Lost / Missing'

    name = models.CharField(max_length=255)
    device_type = models.CharField(max_length=24, choices=DeviceType.choices,
                                   default=DeviceType.OTHER, db_index=True)
    serial_number = models.CharField(max_length=100, blank=True, db_index=True)
    asset_tag = models.CharField(max_length=64, blank=True, db_index=True,
                                 help_text='Internal asset tag / barcode.')
    qr_code = models.CharField(max_length=255, blank=True,
                               help_text='QR payload for scanning.')
    manufacturer = models.CharField(max_length=255, blank=True)
    model_number = models.CharField(max_length=100, blank=True)
    status = models.CharField(max_length=16, choices=Status.choices,
                              default=Status.AVAILABLE, db_index=True)
    assigned_to = models.ForeignKey(HomecarePatient, on_delete=models.SET_NULL,
                                    null=True, blank=True,
                                    related_name='assigned_devices')
    location = models.CharField(max_length=255, blank=True,
                                help_text='Storage location when not assigned.')
    purchase_date = models.DateField(null=True, blank=True)
    purchase_cost = models.DecimalField(max_digits=12, decimal_places=2,
                                        null=True, blank=True)
    warranty_expiry = models.DateField(null=True, blank=True)
    last_maintenance_at = models.DateTimeField(null=True, blank=True)
    next_maintenance_due = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    photo = models.ImageField(upload_to='homecare/devices/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        verbose_name = 'Device'
        verbose_name_plural = 'Devices'

    def __str__(self):
        tag = self.serial_number or self.asset_tag or ''
        return f'{self.name}{" (" + tag + ")" if tag else ""}'


class DeviceAssignment(models.Model):
    """History of device assignments to patients."""

    device = models.ForeignKey(Device, on_delete=models.CASCADE,
                               related_name='assignments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='device_assignments')
    assigned_at = models.DateTimeField(default=timezone.now)
    assigned_by = models.ForeignKey(settings.AUTH_USER_MODEL,
                                    on_delete=models.SET_NULL, null=True, blank=True,
                                    related_name='homecare_device_assignments')
    expected_return_at = models.DateTimeField(null=True, blank=True)
    returned_at = models.DateTimeField(null=True, blank=True)
    return_condition = models.CharField(max_length=80, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-assigned_at']

    def __str__(self):
        return f'{self.device} → {self.patient.user.full_name}'


class DeviceMaintenance(models.Model):
    """Scheduled and completed maintenance events for devices."""

    class Kind(models.TextChoices):
        ROUTINE = 'routine', 'Routine Service'
        CALIBRATION = 'calibration', 'Calibration'
        REPAIR = 'repair', 'Repair'
        INSPECTION = 'inspection', 'Safety Inspection'

    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    device = models.ForeignKey(Device, on_delete=models.CASCADE,
                               related_name='maintenance_events')
    kind = models.CharField(max_length=16, choices=Kind.choices,
                            default=Kind.ROUTINE)
    status = models.CharField(max_length=16, choices=Status.choices,
                              default=Status.SCHEDULED, db_index=True)
    scheduled_at = models.DateTimeField()
    performed_at = models.DateTimeField(null=True, blank=True)
    performed_by_name = models.CharField(max_length=255, blank=True)
    performed_by_user = models.ForeignKey(settings.AUTH_USER_MODEL,
                                          on_delete=models.SET_NULL, null=True, blank=True,
                                          related_name='homecare_maintenance_events')
    cost = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    notes = models.TextField(blank=True)
    next_due_at = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-scheduled_at']

    def __str__(self):
        return f'{self.get_kind_display()} – {self.device}'


# ─────────────────────────────────────────────────────────
# Drug-drug interactions (tenant-curated)
# ─────────────────────────────────────────────────────────
class DrugInteraction(models.Model):
    """Pairwise drug-drug interaction rules. Names are stored lower-case
    and order-independent (drug_a <= drug_b) to make lookups deterministic."""

    class Severity(models.TextChoices):
        MINOR = 'minor', 'Minor'
        MODERATE = 'moderate', 'Moderate'
        MAJOR = 'major', 'Major'
        CONTRAINDICATED = 'contraindicated', 'Contraindicated'

    drug_a = models.CharField(max_length=120, db_index=True)
    drug_b = models.CharField(max_length=120, db_index=True)
    severity = models.CharField(max_length=20, choices=Severity.choices,
                                default=Severity.MODERATE, db_index=True)
    summary = models.CharField(max_length=255)
    detail = models.TextField(blank=True)
    references = models.JSONField(default=list, blank=True,
                                  help_text='[{label, url}]')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['drug_a', 'drug_b']
        constraints = [
            models.UniqueConstraint(fields=['drug_a', 'drug_b'],
                                    name='uniq_drug_interaction_pair'),
        ]
        indexes = [
            models.Index(fields=['drug_a', 'drug_b']),
        ]

    def save(self, *args, **kwargs):
        a = (self.drug_a or '').strip().lower()
        b = (self.drug_b or '').strip().lower()
        if a > b:
            a, b = b, a
        self.drug_a = a
        self.drug_b = b
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.drug_a} ⇄ {self.drug_b} ({self.severity})'


# ─────────────────────────────────────────────────────────
# Prescription safety alerts (audit of clinical warnings)
# ─────────────────────────────────────────────────────────
class PrescriptionSafetyAlert(models.Model):
    class Kind(models.TextChoices):
        ALLERGY = 'allergy', 'Allergy Conflict'
        INTERACTION = 'interaction', 'Drug Interaction'
        DUPLICATE = 'duplicate', 'Duplicate Therapy'

    class Severity(models.TextChoices):
        INFO = 'info', 'Info'
        MINOR = 'minor', 'Minor'
        MODERATE = 'moderate', 'Moderate'
        MAJOR = 'major', 'Major'
        CONTRAINDICATED = 'contraindicated', 'Contraindicated'

    prescription = models.ForeignKey(HomecarePrescription, on_delete=models.CASCADE,
                                     related_name='safety_alerts')
    kind = models.CharField(max_length=20, choices=Kind.choices, db_index=True)
    severity = models.CharField(max_length=20, choices=Severity.choices,
                                default=Severity.MODERATE, db_index=True)
    message = models.CharField(max_length=255)
    detail = models.TextField(blank=True)
    drugs = models.JSONField(default=list, blank=True,
                             help_text='Drug names involved.')
    overridden = models.BooleanField(default=False)
    overridden_by = models.ForeignKey(settings.AUTH_USER_MODEL,
                                      on_delete=models.SET_NULL, null=True, blank=True,
                                      related_name='homecare_overridden_alerts')
    overridden_at = models.DateTimeField(null=True, blank=True)
    override_reason = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.kind}/{self.severity} on Rx#{self.prescription_id}'


# ─────────────────────────────────────────────────────────
# Care pathways (protocol bundles)
# ─────────────────────────────────────────────────────────
class CarePathway(models.Model):
    """A reusable care-protocol bundle (e.g. Sepsis, Post-op hip, Palliative)."""
    name = models.CharField(max_length=255, unique=True)
    code = models.CharField(
        max_length=64, blank=True,
        help_text='SNOMED CT or local code identifying the condition / pathway.',
    )
    code_system = models.CharField(
        max_length=64, default='http://snomed.info/sct', blank=True,
    )
    condition_label = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)
    default_duration_days = models.PositiveIntegerField(default=14)
    goals = models.JSONField(
        default=list, blank=True,
        help_text='List of plain-text goals.',
    )
    medication_orders = models.JSONField(
        default=list, blank=True,
        help_text='[{medication_name, dose, route, times_of_day, '
                  'frequency_cron, duration_days, instructions, requires_caregiver}]',
    )
    vital_targets = models.JSONField(
        default=dict, blank=True,
        help_text='{spo2_min: 94, hr_max: 110, ...} for monitoring/alerting.',
    )
    tasks = models.JSONField(
        default=list, blank=True,
        help_text='[{title, day_offset, category}] standing tasks.',
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class CarePathwayEnrollment(models.Model):
    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        COMPLETED = 'completed', 'Completed'
        WITHDRAWN = 'withdrawn', 'Withdrawn'

    pathway = models.ForeignKey(CarePathway, on_delete=models.PROTECT,
                                related_name='enrollments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='pathway_enrollments')
    treatment_plan = models.ForeignKey(TreatmentPlan, on_delete=models.SET_NULL,
                                       null=True, blank=True,
                                       related_name='pathway_enrollments')
    status = models.CharField(max_length=16, choices=Status.choices,
                              default=Status.ACTIVE)
    started_at = models.DateTimeField(default=timezone.now)
    started_by_user_id = models.IntegerField(null=True, blank=True)
    target_end_date = models.DateField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    outcome_notes = models.TextField(blank=True)
    meta = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-started_at']
        indexes = [models.Index(fields=['patient', 'status'])]

    def __str__(self):
        return f'{self.pathway.name} → {self.patient.user.full_name}'


# ─────────────────────────────────────────────────────────
# Audit log (PHI-safe, append-only)
# ─────────────────────────────────────────────────────────
class AuditEvent(models.Model):
    """Append-only audit trail for PHI-touching operations.

    Captures *who* did *what* to *which object* and *when*, plus a small
    payload diff. Designed for compliance review (HIPAA / Kenya DPA)."""

    class Action(models.TextChoices):
        CREATE = 'create', 'Create'
        UPDATE = 'update', 'Update'
        DELETE = 'delete', 'Delete'
        VIEW = 'view', 'View'
        LOGIN = 'login', 'Login'
        LOGOUT = 'logout', 'Logout'
        EXPORT = 'export', 'Export'
        ACTION = 'action', 'Custom Action'

    actor_user_id = models.IntegerField(null=True, blank=True, db_index=True)
    actor_email = models.CharField(max_length=255, blank=True, db_index=True)
    actor_role = models.CharField(max_length=64, blank=True)
    action = models.CharField(max_length=16, choices=Action.choices, db_index=True)
    object_type = models.CharField(max_length=120, db_index=True)
    object_id = models.CharField(max_length=64, blank=True, db_index=True)
    object_repr = models.CharField(max_length=255, blank=True)
    method = models.CharField(max_length=10, blank=True)
    path = models.CharField(max_length=512, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=512, blank=True)
    payload_diff = models.JSONField(default=dict, blank=True)
    extra = models.JSONField(default=dict, blank=True)
    status_code = models.PositiveSmallIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Audit event'
        verbose_name_plural = 'Audit events'
        indexes = [
            models.Index(fields=['object_type', 'object_id']),
            models.Index(fields=['actor_user_id', '-created_at']),
        ]

    def __str__(self):
        return f'{self.action} {self.object_type}#{self.object_id} by {self.actor_email or self.actor_user_id}'


# ---------------------------------------------------------
# Mail account (per-tenant SMTP/IMAP override) � singleton
# ---------------------------------------------------------
class MailAccount(models.Model):
    """Per-tenant mailbox configuration. When marked active, the homecare
    mail endpoints use these credentials instead of the global defaults.
    Singleton: there should be at most one row per tenant schema.
    """
    display_name = models.CharField(max_length=120, blank=True,
        help_text='Optional friendly From name. Defaults to the tenant name.')
    email = models.EmailField(help_text='Mailbox address used as From / login.')
    imap_host = models.CharField(max_length=255)
    imap_port = models.PositiveIntegerField(default=993)
    imap_use_ssl = models.BooleanField(default=True)
    smtp_host = models.CharField(max_length=255)
    smtp_port = models.PositiveIntegerField(default=465)
    smtp_use_ssl = models.BooleanField(default=True)
    username = models.CharField(max_length=255, help_text='IMAP/SMTP username.')
    password = models.CharField(max_length=512, blank=True,
        help_text='Plain-text mailbox password. Stored at rest in the tenant DB.')
    is_active = models.BooleanField(default=True,
        help_text='If false, the global default mail config is used.')
    last_verified_at = models.DateTimeField(null=True, blank=True)
    last_verified_ok = models.BooleanField(default=False)
    last_error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Mail account'
        verbose_name_plural = 'Mail account'

    def __str__(self):
        return self.email or 'Mail account'

