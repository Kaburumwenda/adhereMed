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
from datetime import timedelta


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
# Patient data-sharing controls
# ─────────────────────────────────────────────────────────
class PatientDataSharing(models.Model):
    """Controls which categories of a homecare patient's records are exposed
    to the patient's own portal.

    Patients do NOT log in to the homecare tenant — they sign in to their own
    patient account and only see data the homecare has chosen to share. By
    default everything is shared; homecare staff can limit categories here.
    """
    # (field_name, human label) — order drives the management UI.
    CATEGORIES = [
        ('share_profile', 'Personal & medical profile'),
        ('share_care_team', 'Care team'),
        ('share_vitals', 'Vitals & measurements'),
        ('share_medications', 'Medications & schedules'),
        ('share_treatment_plan', 'Treatment / care plan'),
        ('share_notes', 'Visit notes'),
        ('share_adherence', 'Adherence statistics'),
        ('share_escalations', 'Escalations & alerts'),
        ('share_consents', 'Consents'),
        ('share_documents', 'Documents & attachments'),
    ]

    patient = models.OneToOneField(
        HomecarePatient, on_delete=models.CASCADE, related_name='sharing',
    )
    is_shared = models.BooleanField(
        default=True,
        help_text='Master switch — turn off to hide everything from the patient.',
    )
    share_profile = models.BooleanField(default=True)
    share_care_team = models.BooleanField(default=True)
    share_vitals = models.BooleanField(default=True)
    share_medications = models.BooleanField(default=True)
    share_treatment_plan = models.BooleanField(default=True)
    share_notes = models.BooleanField(default=True)
    share_adherence = models.BooleanField(default=True)
    share_escalations = models.BooleanField(default=True)
    share_consents = models.BooleanField(default=True)
    share_documents = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)
    updated_by_user_id = models.IntegerField(null=True, blank=True)

    class Meta:
        verbose_name = 'Patient data sharing'
        verbose_name_plural = 'Patient data sharing'

    def __str__(self):
        return f'Sharing for {self.patient.medical_record_number}'

    def as_map(self):
        """Effective per-category visibility (respects the master switch)."""
        return {
            key: bool(self.is_shared and getattr(self, key))
            for key, _ in self.CATEGORIES
        }


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
        DOCTOR = 'doctor', 'Doctor Note'
        NURSE_HCA = 'nurse_hca', 'Nurse / HCA Note'

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
    unit_cost = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True,
        help_text='Optional charge per administered dose, used for patient billing.')
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

    class RatePeriod(models.TextChoices):
        HOURLY = 'hourly', 'Per Hour'
        DAILY = 'daily', 'Per Day'
        WEEKLY = 'weekly', 'Per Week'
        MONTHLY = 'monthly', 'Per Month'

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
    quantity = models.PositiveIntegerField(
        default=1, help_text='Total units of this item owned.')
    quantity_available = models.PositiveIntegerField(
        default=1, help_text='Units currently available for hire.')
    low_stock_threshold = models.PositiveIntegerField(
        default=1, help_text='Flag as "almost out" when available ≤ this.')
    assigned_to = models.ForeignKey(HomecarePatient, on_delete=models.SET_NULL,
                                    null=True, blank=True,
                                    related_name='assigned_devices')
    location = models.CharField(max_length=255, blank=True,
                                help_text='Storage location when not assigned.')
    purchase_date = models.DateField(null=True, blank=True)
    purchase_cost = models.DecimalField(max_digits=12, decimal_places=2,
                                        null=True, blank=True)
    warranty_expiry = models.DateField(null=True, blank=True)
    # ── Hire / rental pricing ──────────────────────────────
    is_rentable = models.BooleanField(
        default=True, help_text='Whether this device can be hired out to patients.')
    currency = models.CharField(max_length=8, default='KES')
    hourly_rate = models.DecimalField(max_digits=12, decimal_places=2,
                                      null=True, blank=True)
    daily_rate = models.DecimalField(max_digits=12, decimal_places=2,
                                     null=True, blank=True)
    weekly_rate = models.DecimalField(max_digits=12, decimal_places=2,
                                      null=True, blank=True)
    monthly_rate = models.DecimalField(max_digits=12, decimal_places=2,
                                       null=True, blank=True)
    deposit = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True,
        help_text='Refundable security deposit collected on hire.')
    default_hire_period = models.CharField(
        max_length=12, choices=RatePeriod.choices, default=RatePeriod.DAILY)
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

    def rate_for(self, period):
        """Return the configured hire rate for a given RatePeriod, or None."""
        return {
            self.RatePeriod.HOURLY: self.hourly_rate,
            self.RatePeriod.DAILY: self.daily_rate,
            self.RatePeriod.WEEKLY: self.weekly_rate,
            self.RatePeriod.MONTHLY: self.monthly_rate,
        }.get(period)

    @property
    def quantity_on_hire(self):
        return max((self.quantity or 0) - (self.quantity_available or 0), 0)

    @property
    def stock_status(self):
        if (self.quantity_available or 0) <= 0:
            return 'out'
        if (self.quantity_available or 0) <= (self.low_stock_threshold or 0):
            return 'low'
        return 'ok'


class DeviceAssignment(models.Model):
    """History of device assignments — hired out to patients or to external
    facilities / organisations."""

    class HireTo(models.TextChoices):
        PATIENT = 'patient', 'Patient'
        FACILITY = 'facility', 'Facility / Organisation'

    device = models.ForeignKey(Device, on_delete=models.CASCADE,
                               related_name='assignments')
    hire_to_type = models.CharField(max_length=12, choices=HireTo.choices,
                                    default=HireTo.PATIENT, db_index=True)
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                null=True, blank=True,
                                related_name='device_assignments')
    facility_name = models.CharField(
        max_length=255, blank=True,
        help_text='Name of the external homecare / facility hiring the device.')
    assigned_at = models.DateTimeField(default=timezone.now)
    assigned_by = models.ForeignKey(settings.AUTH_USER_MODEL,
                                    on_delete=models.SET_NULL, null=True, blank=True,
                                    related_name='homecare_device_assignments')
    expected_return_at = models.DateTimeField(null=True, blank=True)
    returned_at = models.DateTimeField(null=True, blank=True)
    return_condition = models.CharField(max_length=80, blank=True)
    # ── Hire billing (snapshot at assignment time) ──
    hire_period = models.CharField(
        max_length=12, choices=Device.RatePeriod.choices, blank=True)
    hire_rate = models.DecimalField(max_digits=12, decimal_places=2,
                                    null=True, blank=True)
    deposit = models.DecimalField(max_digits=12, decimal_places=2,
                                  null=True, blank=True)
    total_charged = models.DecimalField(max_digits=12, decimal_places=2,
                                        null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-assigned_at']

    def __str__(self):
        who = self.facility_name or (
            self.patient.user.full_name if self.patient and self.patient.user else 'Unknown')
        return f'{self.device} → {who}'

    def compute_charge(self, until=None):
        """Estimate the hire charge from assigned_at to `until` (or now/return)
        based on the snapshotted rate and period. Returns a Decimal or None."""
        from decimal import Decimal
        import math
        if not self.hire_rate or not self.hire_period:
            return None
        end = until or self.returned_at or timezone.now()
        seconds = max((end - self.assigned_at).total_seconds(), 0)
        per = {
            Device.RatePeriod.HOURLY: 3600,
            Device.RatePeriod.DAILY: 86400,
            Device.RatePeriod.WEEKLY: 604800,
            Device.RatePeriod.MONTHLY: 2592000,  # 30 days
        }.get(self.hire_period)
        if not per:
            return None
        units = max(math.ceil(seconds / per), 1)
        return (Decimal(self.hire_rate) * units).quantize(Decimal('0.01'))


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
# Patient Drains & Lines register (clinical, non-billed)
# Tracks invasive lines/drains inserted into a patient — urinary
# catheters, central lines, PICC lines, wound drains, peripheral IVs,
# NG tubes, chest tubes, etc. Separate from the billable equipment-hire
# register (Device / DeviceAssignment above). Drives the "Drain & Line
# Register" panel with insertion-date dwell countdowns and daily
# dressing/site checks.
# ─────────────────────────────────────────────────────────
class DrainLine(models.Model):
    """A single invasive line or drain currently (or previously) sited on
    a patient, tracked for dwell-time and site-care compliance."""

    class LineType(models.TextChoices):
        URINARY_CATHETER = 'catheter', 'Urinary Catheter'
        CENTRAL_LINE = 'central_line', 'Central Line'
        PICC = 'picc', 'PICC Line'
        VENTILATOR = 'ventilator', 'Ventilator Circuit'
        WOUND_DRAIN = 'wound_drain', 'Wound Drain'
        IV_PERIPHERAL = 'iv_peripheral', 'IV Peripheral'
        NASOGASTRIC = 'nasogastric', 'Nasogastric Tube'
        CHEST_TUBE = 'chest_tube', 'Chest Tube'
        OTHER = 'other', 'Other'

    # Recommended max dwell time per line type (days) — drives the countdown.
    MAX_DAYS_BY_TYPE = {
        LineType.URINARY_CATHETER: 14,
        LineType.CENTRAL_LINE: 7,
        LineType.PICC: 30,
        LineType.VENTILATOR: 14,
        LineType.WOUND_DRAIN: 7,
        LineType.IV_PERIPHERAL: 3,
        LineType.NASOGASTRIC: 30,
        LineType.CHEST_TUBE: 7,
        LineType.OTHER: 30,
    }

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='drains_lines')
    line_type = models.CharField(max_length=20, choices=LineType.choices,
                                 default=LineType.OTHER, db_index=True)
    name = models.CharField(max_length=255, blank=True,
                            help_text='Free-text device name / ID, e.g. "16Fr Foley".')
    site = models.CharField(max_length=255, blank=True,
                            help_text='Insertion site, e.g. Right IJ, Left forearm.')
    indication = models.TextField(blank=True)
    insert_date = models.DateTimeField(default=timezone.now)
    max_days_override = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='Override the recommended max dwell days for this line type.')
    dressing_intact = models.BooleanField(default=True)
    site_clean = models.BooleanField(default=True)
    removed_at = models.DateTimeField(null=True, blank=True)
    removal_reason = models.CharField(max_length=255, blank=True)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                   null=True, blank=True, related_name='+')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-insert_date']
        verbose_name = 'Drain / Line'
        verbose_name_plural = 'Drains & Lines'

    def __str__(self):
        who = self.patient.user.full_name if self.patient and self.patient.user else 'Unknown'
        return f'{self.get_line_type_display()} – {who}'

    @property
    def is_active(self):
        return self.removed_at is None

    @property
    def max_days(self):
        return self.max_days_override or self.MAX_DAYS_BY_TYPE.get(self.line_type, 30)

    @property
    def days_in_situ(self):
        end = self.removed_at or timezone.now()
        return max((end - self.insert_date).days, 0)

    @property
    def is_overdue(self):
        return self.is_active and self.days_in_situ >= self.max_days


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


# ─────────────────────────────────────────────────────────
# Patient care management & billing
# ─────────────────────────────────────────────────────────
class CarePlan(models.Model):
    """Per-patient payment plan. Prices are entered manually because different
    patients are charged different amounts based on condition and location."""

    class PlanType(models.TextChoices):
        HOURLY = 'hourly', 'Hourly'
        DAILY = 'daily', 'Daily'
        WEEKLY = 'weekly', 'Weekly'
        MONTHLY = 'monthly', 'Monthly'
        PER_VISIT = 'per_visit', 'Per Visit'
        DAY_TIME = 'day_time', 'Day Shift (Day-time)'
        NIGHT_TIME = 'night_time', 'Night Shift (Night-time)'

    # Time-based plans accrue by elapsed duration. Per-visit accrues by count.
    PERIOD_SECONDS = {
        PlanType.HOURLY: 3600,
        PlanType.DAILY: 86400,
        PlanType.DAY_TIME: 86400,
        PlanType.NIGHT_TIME: 86400,
        PlanType.WEEKLY: 604800,
        PlanType.MONTHLY: 2592000,  # 30 days
    }

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='care_plans')
    plan_type = models.CharField(max_length=16, choices=PlanType.choices,
                                 default=PlanType.DAILY, db_index=True)
    rate = models.DecimalField(max_digits=12, decimal_places=2,
                               help_text='Manually-set price per period / visit.')
    currency = models.CharField(max_length=8, default='KES')
    start_date = models.DateField(default=timezone.now)
    end_date = models.DateField(null=True, blank=True)
    is_active = models.BooleanField(default=True, db_index=True)
    notes = models.TextField(blank=True)
    created_by_user_id = models.IntegerField(null=True, blank=True)
    created_by_name = models.CharField(max_length=255, blank=True)
    auto_bill = models.BooleanField(
        default=True, db_index=True,
        help_text='Automatically generate a bill at the end of each period.')
    last_auto_billed_at = models.DateTimeField(
        null=True, blank=True,
        help_text='End of the last period an auto-bill has been generated for.')
    last_auto_billed_visits = models.PositiveIntegerField(
        default=0,
        help_text='Number of completed visits already covered by auto-bills '
                  '(per-visit plans only).')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_active', '-start_date']
        indexes = [models.Index(fields=['patient', 'is_active'])]

    def __str__(self):
        return f'{self.get_plan_type_display()} @ {self.rate} – {self.patient.user.full_name}'

    def _start_dt(self):
        """Plan start as an aware datetime at day-start."""
        from datetime import datetime, time
        dt = datetime.combine(self.start_date, time.min)
        return timezone.make_aware(dt) if timezone.is_naive(dt) else dt

    def accrued_units(self, until=None, visits=0):
        """Number of billable units from start to `until` (default now).
        For per-visit plans, `visits` is the completed-visit count."""
        import math
        if self.plan_type == self.PlanType.PER_VISIT:
            return max(int(visits or 0), 0)
        per = self.PERIOD_SECONDS.get(self.plan_type)
        if not per:
            return 0
        end = until or timezone.now()
        start = self._start_dt()
        # Cap at end_date if the plan has already ended.
        if self.end_date:
            from datetime import datetime, time
            end_cap = datetime.combine(self.end_date, time.max)
            if timezone.is_naive(end_cap):
                end_cap = timezone.make_aware(end_cap)
            end = min(end, end_cap)
        seconds = max((end - start).total_seconds(), 0)
        if seconds <= 0:
            return 0
        return max(math.ceil(seconds / per), 1)

    def accrued_cost(self, until=None, visits=0):
        from decimal import Decimal
        units = self.accrued_units(until=until, visits=visits)
        return (Decimal(self.rate) * units).quantize(Decimal('0.01'))

    def expected_cost(self, visits=0):
        """Projected cost for the full cycle: to end_date if set, otherwise a
        single period's rate (per-visit → one visit's rate)."""
        from decimal import Decimal
        if self.end_date:
            return self.accrued_cost(until=None, visits=visits)
        return Decimal(self.rate).quantize(Decimal('0.01'))


class MedicalSupply(models.Model):
    """Consumable medical supplies issued to a patient (feeding tubes,
    catheters, dressings, …) with pricing, expiry and in-service lifespan."""

    class Category(models.TextChoices):
        FEEDING = 'feeding', 'Feeding / Nutrition'
        CATHETER = 'catheter', 'Catheter / Urinary'
        WOUND = 'wound', 'Wound Care / Dressing'
        IV = 'iv', 'IV / Infusion'
        RESPIRATORY = 'respiratory', 'Respiratory'
        INCONTINENCE = 'incontinence', 'Incontinence'
        DIABETIC = 'diabetic', 'Diabetic'
        HYGIENE = 'hygiene', 'PPE / Hygiene'
        OTHER = 'other', 'Other'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='supplies')
    name = models.CharField(max_length=255,
                            help_text='e.g. Nasogastric feeding tube (Fr 16)')
    category = models.CharField(max_length=16, choices=Category.choices,
                                default=Category.OTHER, db_index=True)
    quantity = models.PositiveIntegerField(default=1)
    unit = models.CharField(max_length=40, blank=True, default='unit',
                            help_text='unit, pack, box, roll, …')
    unit_price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    currency = models.CharField(max_length=8, default='KES')
    supplied_at = models.DateField(default=timezone.now)
    expiry_date = models.DateField(null=True, blank=True,
                                   help_text='Manufacturer expiry of the product.')
    max_use_days = models.PositiveIntegerField(
        null=True, blank=True,
        help_text='How many days the item can safely be used once in service.')
    replace_due = models.DateField(
        null=True, blank=True,
        help_text='When the item should be replaced (auto from supplied + lifespan).')
    is_active = models.BooleanField(default=True, db_index=True)
    billable = models.BooleanField(default=True,
                                   help_text='Include in the patient bill.')
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-supplied_at', 'name']
        verbose_name = 'Medical supply'
        verbose_name_plural = 'Medical supplies'

    def __str__(self):
        return f'{self.name} ×{self.quantity} – {self.patient.user.full_name}'

    def save(self, *args, **kwargs):
        if self.max_use_days and self.supplied_at:
            self.replace_due = self.supplied_at + timedelta(days=self.max_use_days)
        elif not self.max_use_days:
            self.replace_due = None
        super().save(*args, **kwargs)

    @property
    def total_cost(self):
        from decimal import Decimal
        return (Decimal(self.unit_price) * (self.quantity or 0)).quantize(Decimal('0.01'))

    @property
    def days_remaining(self):
        ref = self.replace_due or self.expiry_date
        if not ref:
            return None
        return (ref - timezone.localdate()).days

    @property
    def usage_status(self):
        d = self.days_remaining
        if d is None:
            return 'ok'
        if d < 0:
            return 'expired'
        if d <= 3:
            return 'due_soon'
        return 'ok'


class PatientBill(models.Model):
    """A generated bill snapshot for a patient, produced on request."""

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        ISSUED = 'issued', 'Issued'
        PARTIAL = 'partial', 'Partially Paid'
        PAID = 'paid', 'Paid'
        VOID = 'void', 'Void'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='bills')
    bill_number = models.CharField(max_length=32, unique=True, editable=False)
    period_start = models.DateField(null=True, blank=True)
    as_of = models.DateTimeField(default=timezone.now,
                                 help_text='Charges computed up to this moment.')
    currency = models.CharField(max_length=8, default='KES')
    line_items = models.JSONField(default=list, blank=True,
                                  help_text='[{kind, label, qty, unit, rate, amount}]')
    care_total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    equipment_total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    supplies_total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    medication_total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(max_length=12, choices=Status.choices,
                              default=Status.ISSUED, db_index=True)
    notes = models.TextField(blank=True)
    generated_by_user_id = models.IntegerField(null=True, blank=True)
    generated_by_name = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.bill_number} – {self.patient.user.full_name}'

    def save(self, *args, **kwargs):
        if not self.bill_number:
            self.bill_number = f'HB-{uuid.uuid4().hex[:8].upper()}'
        super().save(*args, **kwargs)

    def recalc_status(self):
        """Refresh amount_paid / balance / status from linked payments."""
        from decimal import Decimal
        paid = sum((p.amount for p in self.payments.all()), Decimal('0'))
        self.amount_paid = paid
        self.balance = (Decimal(self.total) - paid).quantize(Decimal('0.01'))
        if self.status != self.Status.VOID:
            if paid <= 0:
                self.status = self.Status.ISSUED
            elif paid < Decimal(self.total):
                self.status = self.Status.PARTIAL
            else:
                self.status = self.Status.PAID


class PatientPayment(models.Model):
    """Money received from / on behalf of a patient."""

    class Method(models.TextChoices):
        CASH = 'cash', 'Cash'
        MPESA = 'mpesa', 'M-Pesa'
        CARD = 'card', 'Card'
        BANK = 'bank', 'Bank Transfer'
        INSURANCE = 'insurance', 'Insurance'
        OTHER = 'other', 'Other'

    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='payments')
    bill = models.ForeignKey(PatientBill, on_delete=models.SET_NULL,
                             null=True, blank=True, related_name='payments')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    currency = models.CharField(max_length=8, default='KES')
    method = models.CharField(max_length=12, choices=Method.choices,
                              default=Method.CASH, db_index=True)
    reference = models.CharField(max_length=120, blank=True)
    paid_at = models.DateTimeField(default=timezone.now)
    received_by_user_id = models.IntegerField(null=True, blank=True)
    received_by_name = models.CharField(max_length=255, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-paid_at']
        indexes = [models.Index(fields=['patient', 'paid_at'])]

    def __str__(self):
        return f'{self.amount} {self.currency} – {self.patient.user.full_name}'


class BillingSettings(models.Model):
    """Per-patient billing cadence settings. Controls how often that patient's
    bills are auto-generated from their active care plans (see services.py).
    One record per patient; patients without a record fall back to the default
    hourly-tick auto-billing behaviour."""

    class BillingType(models.TextChoices):
        DAILY = 'daily', 'Daily'
        WEEKLY = 'weekly', 'Weekly'
        MONTHLY = 'monthly', 'Monthly'
        QUARTERLY = 'quarterly', 'Quarterly'
        YEARLY = 'yearly', 'Yearly'
        MANUALLY = 'manually', 'Manually (no auto-generation)'

    # Seconds elapsed before the auto-generate tick runs again per cadence.
    CADENCE_SECONDS = {
        BillingType.DAILY: 86400,        # 1 day
        BillingType.WEEKLY: 604800,     # 7 days
        BillingType.MONTHLY: 2592000,   # 30 days
        BillingType.QUARTERLY: 7776000,  # 90 days
        BillingType.YEARLY: 31536000,    # 365 days
    }

    patient = models.OneToOneField(
        HomecarePatient, on_delete=models.CASCADE,
        related_name='billing_settings')
    billing_type = models.CharField(
        max_length=16, choices=BillingType.choices,
        default=BillingType.DAILY, db_index=True,
        help_text='How often this patient\'s bills are auto-generated.')
    auto_generate = models.BooleanField(
        default=True, db_index=True,
        help_text='Master switch for automatic bill generation for this patient.')
    last_run_at = models.DateTimeField(
        null=True, blank=True,
        help_text='When the auto-generate tick last ran for this patient.')
    updated_by_user_id = models.IntegerField(null=True, blank=True)
    updated_by_name = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Billing settings'
        verbose_name_plural = 'Billing settings'
        ordering = ['-created_at']

    def __str__(self):
        name = getattr(getattr(self.patient, 'user', None), 'full_name', None) or f'Patient #{self.patient_id}'
        return f'{name} · {self.get_billing_type_display()}'

    @classmethod
    def get_or_create_for(cls, patient):
        obj, _ = cls.objects.get_or_create(patient=patient)
        return obj

    @property
    def is_auto_enabled(self):
        return self.auto_generate and self.billing_type != self.BillingType.MANUALLY

    def cadence_elapsed(self, now=None):
        """True if enough time has passed since last_run_at to run again."""
        if not self.is_auto_enabled:
            return False
        now = now or timezone.now()
        per = self.CADENCE_SECONDS.get(self.billing_type)
        if not per:
            return False
        if not self.last_run_at:
            return True
        return (now - self.last_run_at).total_seconds() >= per


# ─────────────────────────────────────────────────────────────────
#  HUMAN RESOURCES (homecare HR module)
#  Full employee lifecycle: recruitment → onboarding → scheduling →
#  payroll → performance → compliance. All tenant-isolated.
# ─────────────────────────────────────────────────────────────────

class HREmployee(models.Model):
    """Central employee record for the homecare workforce."""

    class EmploymentType(models.TextChoices):
        FULL_TIME = 'full_time', 'Full-time'
        PART_TIME = 'part_time', 'Part-time'
        CONTRACT = 'contract', 'Contract'
        INTERNSHIP = 'internship', 'Internship'
        TEMPORARY = 'temporary', 'Temporary'

    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        ON_PROBATION = 'on_probation', 'On Probation'
        ON_LEAVE = 'on_leave', 'On Leave'
        SUSPENDED = 'suspended', 'Suspended'
        TERMINATED = 'terminated', 'Terminated'
        RESIGNED = 'resigned', 'Resigned'

    # Personal
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=30, blank=True)
    national_id = models.CharField(max_length=50, blank=True)
    gender = models.CharField(max_length=10, blank=True,
                             choices=[('Male', 'Male'), ('Female', 'Female'), ('Other', 'Other')])
    date_of_birth = models.DateField(null=True, blank=True)
    address = models.TextField(blank=True)

    # Employment
    department = models.CharField(max_length=100, blank=True, db_index=True)
    job_title = models.CharField(max_length=150, blank=True)
    employment_type = models.CharField(max_length=15, choices=EmploymentType.choices,
                                      default=EmploymentType.FULL_TIME, db_index=True)
    status = models.CharField(max_length=15, choices=Status.choices,
                             default=Status.ACTIVE, db_index=True)
    hire_date = models.DateField(null=True, blank=True)
    probation_end_date = models.DateField(null=True, blank=True)
    salary = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    bank_account = models.CharField(max_length=100, blank=True)
    supervisor = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name='subordinates')
    emergency_contact = models.CharField(max_length=255, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['first_name', 'last_name']
        indexes = [
            models.Index(fields=['status', 'department']),
            models.Index(fields=['employment_type']),
        ]

    def __str__(self):
        return f'{self.first_name} {self.last_name}'

    @property
    def name(self):
        return f'{self.first_name} {self.last_name}'.strip()

    @property
    def supervisor_name(self):
        return self.supervisor.name if self.supervisor else None


class LeaveRequest(models.Model):
    class LeaveType(models.TextChoices):
        ANNUAL = 'annual', 'Annual Leave'
        SICK = 'sick', 'Sick Leave'
        MATERNITY = 'maternity', 'Maternity'
        PATERNITY = 'paternity', 'Paternity'
        COMPASSIONATE = 'compassionate', 'Compassionate'
        UNPAID = 'unpaid', 'Unpaid'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        APPROVED = 'approved', 'Approved'
        REJECTED = 'rejected', 'Rejected'
        CANCELLED = 'cancelled', 'Cancelled'

    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='leave_requests')
    leave_type = models.CharField(max_length=15, choices=LeaveType.choices,
                                  default=LeaveType.ANNUAL, db_index=True)
    start_date = models.DateField()
    end_date = models.DateField()
    reason = models.TextField(blank=True)
    status = models.CharField(max_length=10, choices=Status.choices,
                             default=Status.PENDING, db_index=True)
    approver = models.ForeignKey(HREmployee, on_delete=models.SET_NULL, null=True, blank=True,
                                 related_name='approved_leaves')
    approved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['status', 'start_date'])]

    def __str__(self):
        return f'{self.employee} – {self.leave_type} ({self.start_date} to {self.end_date})'

    @property
    def days(self):
        """Calendar days inclusive of start and end."""
        if self.start_date and self.end_date:
            return max((self.end_date - self.start_date).days + 1, 0)
        return 0

    @property
    def employee_name(self):
        return self.employee.name

    @property
    def department(self):
        return self.employee.department

    @property
    def approver_name(self):
        return self.approver.name if self.approver else None


class LeaveBalance(models.Model):
    """Annual leave entitlement tracking per employee."""
    employee = models.OneToOneField(HREmployee, on_delete=models.CASCADE, related_name='leave_balance')
    annual_total = models.PositiveIntegerField(default=21)
    annual_used = models.PositiveIntegerField(default=0)
    sick_total = models.PositiveIntegerField(default=10)
    sick_used = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.employee} – annual {self.annual_used}/{self.annual_total}'


class Shift(models.Model):
    class ShiftType(models.TextChoices):
        DAY = 'day', 'Day Shift'
        NIGHT = 'night', 'Night Shift'
        EVENING = 'evening', 'Evening Shift'
        ON_CALL = 'on_call', 'On-call'
        SPLIT = 'split', 'Split Shift'

    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='shifts')
    date = models.DateField(db_index=True)
    shift_type = models.CharField(max_length=10, choices=ShiftType.choices,
                                  default=ShiftType.DAY, db_index=True)
    start_time = models.CharField(max_length=5, default='08:00')
    end_time = models.CharField(max_length=5, default='17:00')
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['date', 'start_time']
        indexes = [models.Index(fields=['date', 'employee'])]


class Attendance(models.Model):
    """Daily clock-in / clock-out record."""
    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='attendance_records')
    date = models.DateField(db_index=True)
    clock_in = models.TimeField(null=True, blank=True)
    clock_out = models.TimeField(null=True, blank=True)
    late = models.BooleanField(default=False)
    status = models.CharField(max_length=10, default='present', db_index=True,
                              choices=[('present', 'Present'), ('on_leave', 'On Leave'),
                                       ('absent', 'Absent')])
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-date']
        unique_together = ('employee', 'date')
        indexes = [models.Index(fields=['date'])]

    @property
    def employee_name(self):
        return self.employee.name

    @property
    def hours(self):
        """Hours worked if both clock-in and clock-out are set."""
        from datetime import datetime
        if self.clock_in and self.clock_out:
            ci = datetime.combine(self.date, self.clock_in)
            co = datetime.combine(self.date, self.clock_out)
            if co < ci:
                co = co.replace(day=co.day + 1)
            delta = co - ci
            return round(delta.total_seconds() / 3600, 1)
        return None


class Timesheet(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        APPROVED = 'approved', 'Approved'
        REJECTED = 'rejected', 'Rejected'

    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='timesheets')
    date = models.DateField(db_index=True)
    hours = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    shift_type = models.CharField(max_length=10, default='day')
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=10, choices=Status.choices,
                              default=Status.PENDING, db_index=True)
    submitted_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-date']
        indexes = [models.Index(fields=['status', 'date'])]

    @property
    def employee_name(self):
        return self.employee.name


class BenefitPlan(models.Model):
    class BenefitType(models.TextChoices):
        HEALTH = 'health', 'Health Insurance'
        PENSION = 'pension', 'Pension / Retirement'
        LIFE = 'life', 'Life Insurance'
        DENTAL = 'dental', 'Dental'
        TRANSPORT = 'transport', 'Transport Allowance'
        MEAL = 'meal', 'Meal Allowance'
        HOUSING = 'housing', 'Housing'
        WELLNESS = 'wellness', 'Wellness Program'

    name = models.CharField(max_length=200)
    type = models.CharField(max_length=15, choices=BenefitType.choices, default=BenefitType.HEALTH)
    description = models.TextField(blank=True)
    employer_contribution = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    employee_contribution = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    mandatory = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

    @property
    def enrolled_count(self):
        return self.enrollments.count()


class BenefitEnrollment(models.Model):
    benefit = models.ForeignKey(BenefitPlan, on_delete=models.CASCADE, related_name='enrollments')
    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='benefit_enrollments')
    enrolled_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('benefit', 'employee')


class PayrollEntry(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        PROCESSED = 'processed', 'Processed'
        PAID = 'paid', 'Paid'

    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='payroll_entries')
    period = models.CharField(max_length=7, db_index=True, help_text='YYYY-MM')
    basic_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    allowances = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    overtime_pay = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    gross = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    deductions = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    benefits_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    net = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    deduction_items = models.JSONField(default=list, blank=True,
                                       help_text='[{label, amount}]')
    status = models.CharField(max_length=10, choices=Status.choices,
                              default=Status.DRAFT, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-period']
        unique_together = ('employee', 'period')
        indexes = [models.Index(fields=['period', 'status'])]

    @property
    def employee_name(self):
        return self.employee.name

    @property
    def department(self):
        return self.employee.department


class JobOpening(models.Model):
    class EmploymentType(models.TextChoices):
        FULL_TIME = 'full_time', 'Full-time'
        PART_TIME = 'part_time', 'Part-time'
        CONTRACT = 'contract', 'Contract'
        INTERNSHIP = 'internship', 'Internship'
        TEMPORARY = 'temporary', 'Temporary'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        CLOSED = 'closed', 'Closed'
        DRAFT = 'draft', 'Draft'

    title = models.CharField(max_length=255, db_index=True)
    department = models.CharField(max_length=100, blank=True)
    employment_type = models.CharField(max_length=15, choices=EmploymentType.choices,
                                      default=EmploymentType.FULL_TIME)
    location = models.CharField(max_length=150, blank=True)
    salary_min = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    salary_max = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    closing_date = models.DateField(null=True, blank=True)
    description = models.TextField(blank=True)
    requirements = models.TextField(blank=True, help_text='One requirement per line')
    is_published = models.BooleanField(default=True)
    status = models.CharField(max_length=10, choices=Status.choices,
                              default=Status.OPEN, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.title

    @property
    def applicant_count(self):
        return self.applicants.count()


class Applicant(models.Model):
    class Stage(models.TextChoices):
        APPLIED = 'applied', 'Applied'
        SCREENING = 'screening', 'Screening'
        INTERVIEW = 'interview', 'Interview'
        OFFER = 'offer', 'Offer'
        HIRED = 'hired', 'Hired'
        DECLINED = 'declined', 'Declined'

    job = models.ForeignKey(JobOpening, on_delete=models.CASCADE, related_name='applicants')
    name = models.CharField(max_length=255, db_index=True)
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=30, blank=True)
    resume_url = models.URLField(blank=True)
    cover_letter = models.TextField(blank=True)
    stage = models.CharField(max_length=10, choices=Stage.choices,
                             default=Stage.APPLIED, db_index=True)
    rating = models.PositiveIntegerField(default=0)
    notes = models.TextField(blank=True)
    applied_date = models.DateField(auto_now_add=True)
    converted_employee = models.ForeignKey(HREmployee, on_delete=models.SET_NULL,
                                           null=True, blank=True,
                                           related_name='source_applicants')

    class Meta:
        ordering = ['-applied_date']
        indexes = [models.Index(fields=['job', 'stage'])]

    def __str__(self):
        return f'{self.name} → {self.job.title}'


class OnboardingTemplate(models.Model):
    name = models.CharField(max_length=200)
    tasks = models.JSONField(default=list, blank=True, help_text='[{title}]')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class OnboardingRecord(models.Model):
    class Status(models.TextChoices):
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'

    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='onboarding_records')
    role = models.CharField(max_length=150, blank=True)
    department = models.CharField(max_length=100, blank=True)
    start_date = models.DateField(null=True, blank=True)
    mentor = models.CharField(max_length=255, blank=True)
    status = models.CharField(max_length=15, choices=Status.choices,
                             default=Status.IN_PROGRESS, db_index=True)
    days_to_complete = models.PositiveIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def name(self):
        return self.employee.name

    @property
    def progress(self):
        total = self.tasks.count()
        if not total:
            return 0
        done = self.tasks.filter(done=True).count()
        return round(done / total * 100)


class OnboardingTask(models.Model):
    onboarding = models.ForeignKey(OnboardingRecord, on_delete=models.CASCADE, related_name='tasks')
    title = models.CharField(max_length=300)
    done = models.BooleanField(default=False)
    due_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['id']


class TrainingProgram(models.Model):
    class DeliveryMode(models.TextChoices):
        ONLINE = 'online', 'Online'
        IN_PERSON = 'in_person', 'In-person'
        HYBRID = 'hybrid', 'Hybrid'
        SELF_PACED = 'self_paced', 'Self-paced'

    title = models.CharField(max_length=255, db_index=True)
    category = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    duration_hours = models.PositiveIntegerField(default=0)
    delivery_mode = models.CharField(max_length=15, choices=DeliveryMode.choices,
                                     default=DeliveryMode.ONLINE)
    mandatory = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['title']

    def __str__(self):
        return self.title

    @property
    def enrolled_count(self):
        return self.enrollments.count()

    @property
    def certified_count(self):
        return self.enrollments.filter(completed=True).count()

    @property
    def completion_pct(self):
        total = self.enrollments.count()
        if not total:
            return 0
        return round(self.enrollments.filter(completed=True).count() / total * 100)


class TrainingEnrollment(models.Model):
    program = models.ForeignKey(TrainingProgram, on_delete=models.CASCADE, related_name='enrollments')
    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='training_enrollments')
    deadline = models.DateField(null=True, blank=True)
    completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    enrolled_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('program', 'employee')


class PerformanceReview(models.Model):
    class ReviewType(models.TextChoices):
        ANNUAL = 'annual', 'Annual'
        QUARTERLY = 'quarterly', 'Quarterly'
        PROBATION = 'probation', 'Probation'
        MID_YEAR = 'mid_year', 'Mid-year'
        THREE_SIXTY = '360', '360 Feedback'

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'
        ACKNOWLEDGED = 'acknowledged', 'Acknowledged'

    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='reviews')
    cycle_name = models.CharField(max_length=150, blank=True)
    review_date = models.DateField(null=True, blank=True)
    review_type = models.CharField(max_length=15, choices=ReviewType.choices,
                                  default=ReviewType.ANNUAL)
    rating = models.PositiveIntegerField(default=0)
    quality_of_work = models.PositiveIntegerField(default=3)
    teamwork = models.PositiveIntegerField(default=3)
    communication = models.PositiveIntegerField(default=3)
    punctuality = models.PositiveIntegerField(default=3)
    initiative = models.PositiveIntegerField(default=3)
    patient_care = models.PositiveIntegerField(default=3)
    strengths = models.TextField(blank=True)
    areas_for_improvement = models.TextField(blank=True)
    comments = models.TextField(blank=True)
    status = models.CharField(max_length=15, choices=Status.choices,
                             default=Status.DRAFT, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-review_date', '-created_at']

    @property
    def employee_name(self):
        return self.employee.name

    @property
    def job_title(self):
        return self.employee.job_title


class Goal(models.Model):
    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE, related_name='goals')
    title = models.CharField(max_length=300)
    category = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    due_date = models.DateField(null=True, blank=True)
    progress = models.PositiveIntegerField(default=0,
                                           help_text='Completion percentage 0–100')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def employee_name(self):
        return self.employee.name


class ComplianceViolation(models.Model):
    class Severity(models.TextChoices):
        HIGH = 'high', 'High'
        MEDIUM = 'medium', 'Medium'
        LOW = 'low', 'Low'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        RESOLVED = 'resolved', 'Resolved'

    class ViolationType(models.TextChoices):
        OVERTIME = 'overtime', 'Overtime'
        MAX_HOURS = 'max_hours', 'Max Hours Exceeded'
        NO_REST = 'no_rest', 'Insufficient Rest Days'
        CERT_EXPIRY = 'cert_expiry', 'Certification Expired'
        OTHER = 'other', 'Other'

    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE,
                                 related_name='compliance_violations', null=True, blank=True)
    title = models.CharField(max_length=300)
    description = models.TextField(blank=True)
    type = models.CharField(max_length=20, choices=ViolationType.choices,
                            default=ViolationType.OTHER, db_index=True)
    severity = models.CharField(max_length=10, choices=Severity.choices,
                               default=Severity.MEDIUM, db_index=True)
    status = models.CharField(max_length=10, choices=Status.choices,
                             default=Status.OPEN, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def employee_name(self):
        return self.employee.name if self.employee else None


class Certification(models.Model):
    employee = models.ForeignKey(HREmployee, on_delete=models.CASCADE,
                                 related_name='certifications')
    name = models.CharField(max_length=300)
    type = models.CharField(max_length=100, blank=True)
    issuer = models.CharField(max_length=200, blank=True)
    issue_date = models.DateField(null=True, blank=True)
    expiry_date = models.DateField(null=True, blank=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['expiry_date']

    @property
    def employee_name(self):
        return self.employee.name

    @property
    def days_left(self):
        if not self.expiry_date:
            return None
        return (self.expiry_date - timezone.localdate()).days


class ComplianceReport(models.Model):
    class ReportType(models.TextChoices):
        LABOR_HOURS = 'labor_hours', 'Labor Hours & Overtime Report'
        PAYROLL_AUDIT = 'payroll_audit', 'Payroll Audit Report'
        LEAVE_COMPLIANCE = 'leave_compliance', 'Leave Entitlement Report'
        CERTIFICATION = 'certification', 'Certification Status Report'
        WORKPLACE_SAFETY = 'workplace_safety', 'Workplace Safety Report'
        DIVERSITY = 'diversity', 'Diversity & Inclusion Report'
        TURNOVER = 'turnover', 'Employee Turnover Report'

    title = models.CharField(max_length=300)
    type = models.CharField(max_length=20, choices=ReportType.choices,
                            default=ReportType.LABOR_HOURS, db_index=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    file_url = models.URLField(blank=True)
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-generated_at']

    @property
    def type_label(self):
        return self.get_type_display()


class HRDocument(models.Model):
    class Category(models.TextChoices):
        CONTRACT = 'contract', 'Employment Contracts'
        POLICY = 'policy', 'Policies & Procedures'
        CERTIFICATION = 'certification', 'Certifications'
        ID_DOCUMENT = 'id_document', 'ID Documents'
        MEDICAL = 'medical', 'Medical Records'
        TRAINING = 'training', 'Training Records'
        PERFORMANCE = 'performance', 'Performance Docs'
        OTHER = 'other', 'Other'

    class AccessLevel(models.TextChoices):
        PUBLIC = 'public', 'All Staff'
        HR_ONLY = 'hr_only', 'HR Only'
        MANAGER = 'manager', 'Manager + HR'
        RESTRICTED = 'restricted', 'Restricted'

    name = models.CharField(max_length=300, db_index=True)
    category = models.CharField(max_length=15, choices=Category.choices,
                               default=Category.CONTRACT, db_index=True)
    employee = models.ForeignKey(HREmployee, on_delete=models.SET_NULL,
                                 null=True, blank=True, related_name='documents')
    access_level = models.CharField(max_length=15, choices=AccessLevel.choices,
                                    default=AccessLevel.HR_ONLY, db_index=True)
    description = models.TextField(blank=True)
    file = models.FileField(upload_to='homecare/hr/documents/', blank=True, null=True)
    file_type = models.CharField(max_length=20, blank=True)
    file_size = models.PositiveIntegerField(default=0)
    expiry_date = models.DateField(null=True, blank=True)
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-uploaded_at']
        indexes = [models.Index(fields=['category', 'access_level'])]

    @property
    def employee_name(self):
        return self.employee.name if self.employee else None

    @property
    def file_url(self):
        if self.file:
            return self.file.url
        return None


# ─────────────────────────────────────────────────────────────────
#  Patient documents
# ─────────────────────────────────────────────────────────────────
class PatientDocument(models.Model):
    """Documents and attachments linked to a homecare patient — insurance
    cards, ID documents, lab reports, imaging, clinical notes, prescriptions,
    consents, care plans, etc.  Supports access-level control and expiry
    tracking (e.g. insurance cards that expire)."""

    class Category(models.TextChoices):
        INSURANCE_CARD = 'insurance_card', 'Insurance Cards'
        ID_DOCUMENT = 'id_document', 'ID Documents'
        LAB_REPORT = 'lab_report', 'Lab Reports'
        IMAGING = 'imaging', 'Imaging / Radiology'
        CLINICAL_NOTE = 'clinical_note', 'Clinical Notes'
        PRESCRIPTION = 'prescription', 'Prescriptions'
        CONSENT = 'consent', 'Consents'
        CARE_PLAN = 'care_plan', 'Care Plans'
        OTHER = 'other', 'Other'

    class AccessLevel(models.TextChoices):
        CARE_TEAM = 'care_team', 'Care Team'
        DOCTOR_ONLY = 'doctor_only', 'Doctor Only'
        NURSE_ONLY = 'nurse_only', 'Nurse Only'
        RESTRICTED = 'restricted', 'Restricted'

    name = models.CharField(max_length=300, db_index=True)
    category = models.CharField(max_length=20, choices=Category.choices,
                               default=Category.OTHER, db_index=True)
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='documents')
    access_level = models.CharField(max_length=15, choices=AccessLevel.choices,
                                    default=AccessLevel.CARE_TEAM, db_index=True)
    description = models.TextField(blank=True)
    file = models.FileField(upload_to='homecare/patient-documents/', blank=True, null=True)
    file_type = models.CharField(max_length=20, blank=True)
    file_size = models.PositiveIntegerField(default=0)
    expiry_date = models.DateField(null=True, blank=True)
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-uploaded_at']
        indexes = [models.Index(fields=['category', 'access_level']),
                   models.Index(fields=['patient', 'category'])]

    @property
    def patient_name(self):
        return self.patient.user.full_name if self.patient and self.patient.user else None

    @property
    def file_url(self):
        if self.file:
            return self.file.url
        return None

    def __str__(self):
        return f'{self.name} ({self.get_category_display()})'


# ─────────────────────────────────────────────────────────────────
#  PATIENT ASSESSMENT MODULE
#  Structured nursing assessment covering the full patient journey:
#  initial arrival survey, head-to-toe baseline, validated risk scales
#  (Braden, Caprini/VTE, Morse/STEADI falls, MUST malnutrition, CAM
#  delirium, pain), device care bundles (CAUTI, VAP, CLABSI, wound)
#  and disease-specific bundles. Follows the Patient Assessment Module
#  Specification (homecare) — JSON-per-section storage with top-level
#  queryable score columns, audit trail and risk-threshold alerts.
# ─────────────────────────────────────────────────────────────────

class AssessmentSession(models.Model):
    """A single patient assessment session (visit-level).

    Stores every assessment section as a structured JSON object so the
    schema stays flexible, while mirroring the most important computed
    scores (Braden total, Caprini points, Morse score, MUST score, pain,
    CAM) as real columns for fast filtering, sorting and dashboards.
    """

    class SessionType(models.TextChoices):
        INITIAL = 'initial', 'Initial Assessment'
        HEAD_TO_TOE = 'head_to_toe', 'Head-to-Toe Baseline'
        REASSESSMENT = 'reassessment', 'Reassessment'
        ADMISSION = 'admission', 'Admission'
        DISCHARGE = 'discharge', 'Discharge Assessment'

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        COMPLETED = 'completed', 'Completed'
        SIGNED = 'signed', 'Signed Off'

    patient = models.ForeignKey(
        HomecarePatient, on_delete=models.CASCADE,
        related_name='assessment_sessions',
    )
    schedule = models.ForeignKey(
        CaregiverSchedule, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='assessment_sessions',
        help_text='Linked caregiver visit / shift, if any.',
    )
    caregiver = models.ForeignKey(
        Caregiver, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='assessment_sessions',
        help_text='Caregiver who performed the assessment.',
    )
    session_type = models.CharField(
        max_length=20, choices=SessionType.choices,
        default=SessionType.INITIAL, db_index=True,
    )
    status = models.CharField(
        max_length=16, choices=Status.choices,
        default=Status.COMPLETED, db_index=True,
    )

    # ── Structured section payloads (JSON, spec-aligned) ──
    arrival = models.JSONField(
        default=dict, blank=True,
        help_text='{arrival_timestamp, arrival_mode}',
    )
    initial_survey = models.JSONField(
        default=dict, blank=True,
        help_text='Vitals, consciousness, chief concern, pain, skin, '
                  'safety checks, allergies & meds.',
    )
    head_to_toe = models.JSONField(
        default=dict, blank=True,
        help_text='Body-system survey: neuro, eyes/ENT, cardiac, '
                  'respiratory, abdomen/GI, MSK, skin, continence, nutrition.',
    )
    catheter_bundle = models.JSONField(
        default=dict, blank=True,
        help_text='CAUTI prevention bundle (present, type, insert_date, '
                  'indication, closed_system, bag_below_bladder, …).',
    )
    ventilator_bundle = models.JSONField(
        default=dict, blank=True,
        help_text='VAP prevention bundle (HOB elevated, SBT, sedation '
                  'vacation, oral care, vent settings).',
    )
    central_line_bundle = models.JSONField(
        default=dict, blank=True,
        help_text='CLABSI prevention bundle (line type, insert date, '
                  'site, dressing, maximal barrier, hub scrub, …).',
    )
    wound_bundle = models.JSONField(
        default=dict, blank=True,
        help_text='Pressure-injury / wound bundle (wound_details, turn '
                  'schedule, special mattress, barrier cream).',
    )
    disease_bundles = models.JSONField(
        default=dict, blank=True,
        help_text='{diabetes:{…}, heart_failure:{…}, …}',
    )

    # ── Mirrored score columns (fast filter / sort / dashboards) ──
    braden_total = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    caprini_points = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    morse_score = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    must_score = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    pain_score = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    cam_positive = models.BooleanField(null=True, blank=True, db_index=True)
    gcs_total = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)

    overall_risk_level = models.CharField(
        max_length=10, choices=HomecarePatient.RiskLevel.choices,
        default=HomecarePatient.RiskLevel.LOW, db_index=True,
    )
    alerts_triggered = models.JSONField(
        default=list, blank=True,
        help_text='[{code, severity, message, …] generated by the scoring engine.',
    )
    notes = models.TextField(blank=True)

    # ── Audit ──
    assessed_by_user_id = models.IntegerField(null=True, blank=True, db_index=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    signed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        indexes = [
            models.Index(fields=['patient', '-assessed_at']),
            models.Index(fields=['session_type', '-assessed_at']),
            models.Index(fields=['overall_risk_level', '-assessed_at']),
            models.Index(fields=['status', '-assessed_at']),
        ]
        verbose_name = 'Assessment session'
        verbose_name_plural = 'Assessment sessions'

    def __str__(self):
        return f'{self.get_session_type_display()} – {self.patient.user.full_name} @ {self.assessed_at:%Y-%m-%d %H:%M}'

    @property
    def is_high_risk(self):
        return self.overall_risk_level in (
            HomecarePatient.RiskLevel.HIGH,
            HomecarePatient.RiskLevel.CRITICAL,
        )

    @property
    def alert_count(self):
        return len(self.alerts_triggered or [])


# ─────────────────────────────────────────────────────────────────
#  INDIVIDUAL ASSESSMENT SCALE MODELS
#  Each validated scale / clinical component used in the assessment
#  worklist (Braden, Caprini/VTE, Morse falls, MUST, CAM, Pain, Skin
#  Care bundle, GCS, Diabetes bundle, Heart Failure bundle) has its
#  own strictly-separate model. Every record belongs to a parent
#  AssessmentSession "episode" (Initial Assessment or Reassessment)
#  via the ``episode`` FK, and is also denormalized onto the patient
#  directly for fast patient-scoped queries/history.
# ─────────────────────────────────────────────────────────────────
class BradenAssessment(models.Model):
    """Braden Scale — pressure injury risk (6 subscales, 6–23)."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='braden_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='braden_assessments')
    sensory = models.PositiveSmallIntegerField(null=True, blank=True)
    moisture = models.PositiveSmallIntegerField(null=True, blank=True)
    activity = models.PositiveSmallIntegerField(null=True, blank=True)
    mobility = models.PositiveSmallIntegerField(null=True, blank=True)
    nutrition = models.PositiveSmallIntegerField(null=True, blank=True)
    friction = models.PositiveSmallIntegerField(null=True, blank=True)
    total = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    risk_level = models.CharField(max_length=20, blank=True)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Braden Scale assessment'

    def __str__(self):
        return f'Braden {self.total} – {self.patient.user.full_name}'


class CapriniAssessment(models.Model):
    """Caprini Score — VTE risk (factor checklist, 0–≥5)."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='caprini_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='caprini_assessments')
    age = models.PositiveSmallIntegerField(null=True, blank=True)
    factors = models.JSONField(default=dict, blank=True,
                               help_text='{factor_key: bool, …}')
    points = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    risk_level = models.CharField(max_length=20, blank=True)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Caprini Score assessment'

    def __str__(self):
        return f'Caprini {self.points} – {self.patient.user.full_name}'


class MorseAssessment(models.Model):
    """Morse Fall Scale — falls risk (6 items, 0–125)."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='morse_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='morse_assessments')
    history_of_falls = models.BooleanField(default=False)
    secondary_dx = models.BooleanField(default=False)
    ambulatory_aid = models.CharField(max_length=20, blank=True)
    iv_lock = models.BooleanField(default=False)
    gait = models.CharField(max_length=20, blank=True)
    mental_status = models.CharField(max_length=20, blank=True)
    score = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    risk_level = models.CharField(max_length=20, blank=True)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Morse Fall Scale assessment'

    def __str__(self):
        return f'Morse {self.score} – {self.patient.user.full_name}'


class MustAssessment(models.Model):
    """MUST — malnutrition screening (BAPEN, 0–≥2)."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='must_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='must_assessments')
    height_cm = models.PositiveSmallIntegerField(null=True, blank=True)
    weight_kg = models.FloatField(null=True, blank=True)
    bmi = models.FloatField(null=True, blank=True)
    bmi_score = models.PositiveSmallIntegerField(null=True, blank=True)
    weight_loss_percent = models.FloatField(null=True, blank=True)
    loss_score = models.PositiveSmallIntegerField(null=True, blank=True)
    acute_no_nutrition = models.BooleanField(default=False)
    acute_score = models.PositiveSmallIntegerField(null=True, blank=True)
    total_score = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    risk_level = models.CharField(max_length=20, blank=True)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'MUST assessment'
        verbose_name_plural = 'MUST assessments'

    def __str__(self):
        return f'MUST {self.total_score} – {self.patient.user.full_name}'


class CamAssessment(models.Model):
    """CAM — Confusion Assessment Method (delirium screening)."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='cam_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='cam_assessments')
    acute_onset = models.BooleanField(default=False)
    inattention = models.BooleanField(default=False)
    disorganized_thinking = models.BooleanField(default=False)
    altered_consciousness = models.BooleanField(default=False)
    cam_positive = models.BooleanField(null=True, blank=True, db_index=True)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'CAM assessment'

    def __str__(self):
        return f'CAM {"Positive" if self.cam_positive else "Negative"} – {self.patient.user.full_name}'


class PainAssessment(models.Model):
    """Comprehensive Pain Assessment — multi-tool support (NRS, VAS, FACES,
    FLACC, PAINAD) with full PQRST framework, functional impact assessment,
    body-map localisation, and treatment-response tracking.

    Follows the Pain Assessment Module Specification (AdhereMed)."""

    class ToolType(models.TextChoices):
        NRS = 'nrs', 'Numeric Rating Scale (0–10)'
        VAS = 'vas', 'Visual Analog Scale'
        FACES = 'faces', 'Wong-Baker FACES'
        FLACC = 'flacc', 'FLACC (Face, Legs, Activity, Cry, Consolability)'
        PAINAD = 'painad', 'PAINAD (Pain Assessment in Advanced Dementia)'

    # ── Episode & patient linkage ──
    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='pain_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='pain_assessments')

    # ── Pain screening ──
    has_pain = models.BooleanField(
        null=True, blank=True,
        help_text='Is the patient currently experiencing pain? Null = not screened.')
    tool_type = models.CharField(
        max_length=12, choices=ToolType.choices, default=ToolType.NRS,
        help_text='Selected pain assessment tool (auto-selected based on age/condition).')

    # ── NRS / VAS core scores ──
    score = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True,
                                             help_text='Current pain score (0–10).')
    score_category = models.CharField(max_length=20, blank=True,
                                      help_text='None / Mild / Moderate / Severe')
    worst_pain_24h = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Worst pain in past 24 hours (0–10).')
    least_pain_24h = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Least pain in past 24 hours (0–10).')
    average_pain = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Average pain over reporting period (0–10).')
    acceptable_pain_goal = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Patient-set acceptable pain goal (0–10).')

    # ── VAS ─
    vas_mm = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='VAS mark position in mm on a 100 mm line (converted to 0–10).')

    # ── Wong-Baker FACES ──
    faces_choice = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='Selected face 0/2/4/6/8/10.')
    faces_description = models.TextField(
        blank=True, help_text='Child verbal description of chosen face.')

    # ── FLACC subscales (0–2 each, total 0–10) ──
    flacc_face = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='FLACC Face (0–2).')
    flacc_legs = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='FLACC Legs (0–2).')
    flacc_activity = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='FLACC Activity (0–2).')
    flacc_cry = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='FLACC Cry (0–2).')
    flacc_consolability = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='FLACC Consolability (0–2).')

    # ── PAINAD subscales (0–2 each, total 0–10) ──
    painad_breathing = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='PAINAD Breathing (0–2).')
    painad_negative_vocal = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='PAINAD Negative Vocalisation (0–2).')
    painad_facial = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='PAINAD Facial Expression (0–2).')
    painad_body_language = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='PAINAD Body Language (0–2).')
    painad_consolability = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='PAINAD Consolability (0–2).')

    # ── PQRST Framework ──
    provocation_factors = models.JSONField(
        default=list, blank=True,
        help_text='List of factors that make pain worse (movement, coughing, etc.).')
    palliation_factors = models.JSONField(
        default=list, blank=True,
        help_text='List of factors that relieve pain (rest, medication, etc.).')
    quality_descriptors = models.JSONField(
        default=list, blank=True,
        help_text='Selected pain quality descriptors (sharp, dull, aching, burning, …).')
    quality_other = models.CharField(
        max_length=255, blank=True, help_text='Free-text pain quality description.')

    # Region / Radiation
    pain_locations = models.JSONField(
        default=list, blank=True,
        help_text='Selected body-map regions (head, neck, shoulder, chest, …).')
    has_radiation = models.BooleanField(
        null=True, blank=True, help_text='Does the pain radiate?')
    radiation_pathway = models.TextField(
        blank=True, help_text='Free-text or region list describing radiation path.')

    # Timing
    onset_type = models.CharField(
        max_length=20, blank=True,
        help_text='sudden / gradual')
    pain_pattern = models.CharField(
        max_length=20, blank=True,
        help_text='constant / intermittent')
    pain_duration = models.CharField(
        max_length=80, blank=True,
        help_text='How long the pain lasts (minutes / hours / days).')
    pain_frequency = models.CharField(
        max_length=80, blank=True,
        help_text='How often pain occurs (e.g. 3×/day, continuous).')
    onset_datetime = models.DateTimeField(
        null=True, blank=True, help_text='When the pain started.')

    # ── Pain history ──
    last_pain_episode = models.TextField(
        blank=True, help_text='Details of last pain episode if currently pain-free.')

    # ── Functional impact ──
    impact_sleep = models.BooleanField(
        null=True, blank=True, help_text='Does pain interfere with sleep?')
    impact_adl = models.BooleanField(
        null=True, blank=True, help_text='Does pain interfere with activities of daily living?')
    impact_mood = models.BooleanField(
        null=True, blank=True, help_text='Does pain affect mood?')
    impact_appetite = models.BooleanField(
        null=True, blank=True, help_text='Does pain affect appetite?')
    impact_other = models.CharField(
        max_length=255, blank=True, help_text='Other functional impacts.')

    # ── Treatment response ──
    pre_treatment_score = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Pain score before intervention.')
    post_treatment_score = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Pain score after intervention.')
    treatment_given = models.TextField(
        blank=True, help_text='Description of intervention (medication, repositioning, …).')
    reassessment_due_at = models.DateTimeField(
        null=True, blank=True,
        help_text='When the next pain reassessment is scheduled.')

    # ── Audit ──
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Pain assessment'
        verbose_name_plural = 'Pain assessments'

    def __str__(self):
        tool = self.get_tool_type_display() if self.tool_type else 'NRS'
        return f'Pain {self.score}/10 [{tool}] – {self.patient.user.full_name}'


class SkinCareAssessment(models.Model):
    """Skin Care Bundle — q4h pressure-care protocol completion."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='skin_care_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='skin_care_assessments')
    reposition = models.BooleanField(default=False)
    surface = models.BooleanField(default=False)
    moisture = models.BooleanField(default=False)
    nutrition = models.BooleanField(default=False)
    heels = models.BooleanField(default=False)
    inspect = models.BooleanField(default=False)
    completed_count = models.PositiveSmallIntegerField(default=0)
    completed_items = models.JSONField(default=list, blank=True)
    bundle_completed = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Skin Care Bundle assessment'

    def __str__(self):
        return f'Skin Care {self.completed_count} tasks – {self.patient.user.full_name}'


class GcsAssessment(models.Model):
    """Glasgow Coma Scale — level of consciousness (3–15)."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='gcs_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='gcs_assessments')
    eyes = models.PositiveSmallIntegerField(null=True, blank=True)
    verbal = models.PositiveSmallIntegerField(null=True, blank=True)
    motor = models.PositiveSmallIntegerField(null=True, blank=True)
    total = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'GCS assessment'

    def __str__(self):
        return f'GCS {self.total} – {self.patient.user.full_name}'


class DiabetesBundleAssessment(models.Model):
    """Diabetes bundle — glucose monitoring & insulin round."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='diabetes_bundle_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='diabetes_bundle_assessments')
    glucose = models.FloatField(null=True, blank=True)
    ketones = models.FloatField(null=True, blank=True)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Diabetes bundle assessment'

    def __str__(self):
        return f'Diabetes bundle {self.glucose} – {self.patient.user.full_name}'


class HeartFailureBundleAssessment(models.Model):
    """Heart failure bundle — fluid status, weight, SpO2 round."""

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='hf_bundle_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='hf_bundle_assessments')
    weight_kg = models.FloatField(null=True, blank=True)
    fluid_balance_ml = models.IntegerField(null=True, blank=True)
    spo2 = models.PositiveSmallIntegerField(null=True, blank=True)
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Heart Failure bundle assessment'

    def __str__(self):
        return f'HF bundle {self.weight_kg}kg – {self.patient.user.full_name}'


# ─────────────────────────────────────────────────────────────────
#  PIVC ASSESSMENT  (Visual Infusion Phlebitis — VIP Score)
#  Peripheral Intravenous Catheter assessment per RCN standards.
#  Covers VIP clinical assessment, maintenance bundle, dressing
#  assessment, complications, and removal documentation.
# ─────────────────────────────────────────────────────────────────
class PIVCAssessment(models.Model):
    """Peripheral Intravenous Catheter (PIVC) Assessment.

    Implements the Royal College of Nursing (RCN) Visual Infusion
    Phlebitis (VIP) scoring standard (0–5) with comprehensive clinical
    assessment fields, maintenance bundle compliance tracking, dressing
    assessment, complication documentation, and catheter removal records.
    """

    class AssessmentType(models.TextChoices):
        INITIAL = 'initial', 'Initial'
        ROUTINE = 'routine', 'Routine'
        PRN = 'prn', 'PRN'
        POST_MEDICATION = 'post_medication', 'Post Medication'
        REASSESSMENT = 'reassessment', 'Reassessment'

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='pivc_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='pivc_assessments')

    # ── Assessment header ──
    assessment_type = models.CharField(
        max_length=20, choices=AssessmentType.choices, default=AssessmentType.ROUTINE)
    catheter_id = models.CharField(
        max_length=80, blank=True, help_text='Identifier for the catheter being assessed.')

    # ── Catheter details (auto-populated where possible) ──
    catheter_site = models.CharField(max_length=80, blank=True,
                                     help_text='e.g. Left forearm, Right hand, Antecubital fossa')
    vein = models.CharField(max_length=80, blank=True,
                            help_text='e.g. Cephalic, Basilic, Metacarpal')
    gauge = models.CharField(max_length=8, blank=True,
                             help_text='e.g. 22G, 20G, 18G')
    insertion_date = models.DateTimeField(null=True, blank=True)
    current_infusion = models.CharField(max_length=255, blank=True,
                                        help_text='Current medication / fluid infusing')
    previous_vip_score = models.PositiveSmallIntegerField(null=True, blank=True)
    last_flush = models.DateTimeField(null=True, blank=True)
    last_dressing_change = models.DateTimeField(null=True, blank=True)

    # ── Clinical Assessment Fields ──
    # Pain
    pain_level = models.CharField(
        max_length=24, blank=True,
        help_text='none / palpation / during_infusion / constant / severe')
    pain_score_nrs = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Numeric pain score 0–10.')
    pain_quality = models.CharField(max_length=80, blank=True)
    pain_onset = models.CharField(max_length=80, blank=True)
    pain_duration = models.CharField(max_length=80, blank=True)

    # Erythema (Redness)
    erythema = models.CharField(
        max_length=24, blank=True,
        help_text='none / localized_lt_1cm / moderate_gt_1cm / along_vein / extensive')

    # Swelling
    swelling = models.CharField(
        max_length=24, blank=True,
        help_text='none / mild / moderate / severe / entire_limb')
    swelling_circumference_cm = models.FloatField(null=True, blank=True)

    # Warmth
    warmth = models.CharField(
        max_length=24, blank=True,
        help_text='normal / slightly_warm / moderately_warm / very_warm')

    # Induration (hardening)
    induration = models.CharField(
        max_length=24, blank=True,
        help_text='none / localized / along_vein / extensive')

    # Palpable Venous Cord
    palpable_cord = models.CharField(
        max_length=24, blank=True,
        help_text='no / lt_2.5cm / gt_2.5cm')

    # Drainage
    drainage_type = models.CharField(
        max_length=24, blank=True,
        help_text='none / serous / blood / purulent')
    drainage_quantity = models.CharField(max_length=40, blank=True)

    # Skin Integrity
    skin_integrity = models.CharField(
        max_length=24, blank=True,
        help_text='intact / fragile / skin_tear / blister / breakdown')

    # Leakage
    leakage = models.CharField(
        max_length=24, blank=True,
        help_text='none / mild / moderate / severe')

    # Catheter Patency
    catheter_patency = models.CharField(
        max_length=24, blank=True,
        help_text='flushes_easily / mild_resistance / moderate_resistance / unable_to_flush')
    blood_return = models.CharField(
        max_length=24, blank=True,
        help_text='present / absent / not_assessed')

    # ── Limb Assessment ──
    limb_colour = models.CharField(max_length=40, blank=True)
    limb_temperature = models.CharField(max_length=40, blank=True)
    capillary_refill = models.CharField(max_length=40, blank=True)
    distal_pulses = models.CharField(max_length=40, blank=True)
    limb_sensation = models.CharField(max_length=40, blank=True)
    limb_movement = models.CharField(max_length=40, blank=True)

    # ── Computed VIP Score (0–5, server-calculated) ──
    vip_score = models.PositiveSmallIntegerField(null=True, blank=True, db_index=True)
    vip_colour = models.CharField(max_length=20, blank=True,
                                  help_text='green / yellow / orange / red / dark_red / critical_red')
    vip_label = models.CharField(max_length=80, blank=True,
                                 help_text='Human-readable VIP stage description.')

    # ── Clinical Decision Support (auto-generated) ──
    recommendations = models.JSONField(
        default=list, blank=True,
        help_text='Auto-generated clinical recommendations based on VIP score.')

    # ── PIVC Maintenance Bundle ──
    # Each item: 'yes' / 'no' / 'na'
    bundle_hand_hygiene_before = models.CharField(max_length=4, blank=True, default='')
    bundle_hand_hygiene_after = models.CharField(max_length=4, blank=True, default='')
    bundle_gloves = models.CharField(max_length=4, blank=True, default='')
    bundle_additional_ppe = models.CharField(max_length=4, blank=True, default='')
    bundle_antt_key_parts = models.CharField(max_length=4, blank=True, default='')
    bundle_antt_sterile = models.CharField(max_length=4, blank=True, default='')
    bundle_antt_aseptic = models.CharField(max_length=4, blank=True, default='')
    bundle_catheter_necessary = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_clean = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_dry = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_intact = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_transparent = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_label = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_date_visible = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_time_visible = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_edges_secure = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_no_blood = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_no_moisture = models.CharField(max_length=4, blank=True, default='')
    bundle_securement = models.CharField(max_length=4, blank=True, default='')
    bundle_stabilization_intact = models.CharField(max_length=4, blank=True, default='')
    bundle_tubing_supported = models.CharField(max_length=4, blank=True, default='')
    bundle_no_tension = models.CharField(max_length=4, blank=True, default='')
    bundle_site_no_redness = models.CharField(max_length=4, blank=True, default='')
    bundle_site_no_swelling = models.CharField(max_length=4, blank=True, default='')
    bundle_site_no_pain = models.CharField(max_length=4, blank=True, default='')
    bundle_site_no_warmth = models.CharField(max_length=4, blank=True, default='')
    bundle_site_no_discharge = models.CharField(max_length=4, blank=True, default='')
    bundle_vip_completed = models.CharField(max_length=4, blank=True, default='')
    bundle_hub_scrubbed = models.CharField(max_length=4, blank=True, default='')
    bundle_hub_antiseptic = models.CharField(max_length=4, blank=True, default='')
    bundle_hub_contact_time = models.CharField(max_length=4, blank=True, default='')
    bundle_hub_dried = models.CharField(max_length=4, blank=True, default='')
    bundle_flush_syringe = models.CharField(max_length=4, blank=True, default='')
    bundle_flush_solution = models.CharField(max_length=4, blank=True, default='')
    bundle_flush_before = models.CharField(max_length=4, blank=True, default='')
    bundle_flush_after = models.CharField(max_length=4, blank=True, default='')
    bundle_flush_push_pause = models.CharField(max_length=4, blank=True, default='')
    bundle_flush_positive_pressure = models.CharField(max_length=4, blank=True, default='')
    bundle_med_five_rights = models.CharField(max_length=4, blank=True, default='')
    bundle_med_compatibility = models.CharField(max_length=4, blank=True, default='')
    bundle_med_flush_between = models.CharField(max_length=4, blank=True, default='')
    bundle_tubing_dated = models.CharField(max_length=4, blank=True, default='')
    bundle_tubing_interval = models.CharField(max_length=4, blank=True, default='')
    bundle_tubing_secure = models.CharField(max_length=4, blank=True, default='')
    bundle_tubing_no_air = models.CharField(max_length=4, blank=True, default='')
    bundle_tubing_no_kinks = models.CharField(max_length=4, blank=True, default='')
    bundle_compliance_pct = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='Auto-calculated percentage of "yes" in answered bundle items.')

    # ── Catheter Removal ──
    catheter_removed = models.BooleanField(default=False)
    removal_reason = models.CharField(max_length=80, blank=True,
                                      help_text='phlebitis / infiltration / dislodged / no_longer_needed / other')
    removal_date = models.DateTimeField(null=True, blank=True)
    removal_by_name = models.CharField(max_length=255, blank=True)

    # ── Audit ──
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'PIVC assessment'
        verbose_name_plural = 'PIVC assessments'

    def __str__(self):
        return f'PIVC VIP={self.vip_score} – {self.patient.user.full_name}'


# ─────────────────────────────────────────────────────────────────
#  ENTERAL FEEDING ASSESSMENT  (Device-directed Maintenance Bundle)
#  Smart, device-detection-driven enteral access device maintenance
#  per ASPEN / ESPEN / BAPEN / JCI / WHO standards.  The bundle
#  auto-selects based on the patient's active enteral device type.
# ─────────────────────────────────────────────────────────────────
class EnteralFeedingAssessment(models.Model):
    """Enteral Access Device Maintenance Bundle — device-directed.

    The clinician NEVER manually selects a bundle; the system detects
    the active enteral device (NGT, OGT, PEG, PEJ, GJ, J-Tube, etc.)
    and presents only the relevant maintenance items.

    Every item is documented as 'yes' / 'no' / 'na', and a compliance
    percentage is auto-calculated.
    """

    class DeviceType(models.TextChoices):
        NGT = 'ngt', 'Nasogastric Tube (NGT)'
        OGT = 'ogt', 'Orogastric Tube (OGT)'
        PEG = 'peg', 'Percutaneous Endoscopic Gastrostomy (PEG)'
        PEJ = 'pej', 'Percutaneous Endoscopic Jejunostomy (PEJ)'
        GJ = 'gj', 'Gastrojejunostomy (GJ) Tube'
        J_TUBE = 'j_tube', 'Jejunostomy (J-Tube)'
        NJ = 'nj', 'Nasojejunal (NJ) Tube'
        OTHER = 'other', 'Other'

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='enteral_feeding_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='enteral_feeding_assessments')

    # ── Auto-detected device information ──
    device_type = models.CharField(
        max_length=16, choices=DeviceType.choices, db_index=True,
        help_text='Auto-detected from Device Registry; determines which bundle items apply.')
    device_status = models.CharField(
        max_length=12, blank=True, default='active',
        help_text='active / removed')
    insertion_date = models.DateTimeField(null=True, blank=True)
    tube_size = models.CharField(max_length=40, blank=True,
                                 help_text='e.g. Fr 16')
    insertion_site = models.CharField(max_length=80, blank=True)
    external_length_cm = models.FloatField(null=True, blank=True,
                                           help_text='External tube length in cm (NGT/OGT).')
    manufacturer = models.CharField(max_length=255, blank=True)
    balloon_status = models.CharField(
        max_length=40, blank=True,
        help_text='Intact / deflated / ruptured / unknown (PEG/PEJ where applicable).')

    # ── Universal maintenance items (all devices) ──
    bundle_hand_hygiene = models.CharField(max_length=4, blank=True, default='')
    bundle_ppe = models.CharField(max_length=4, blank=True, default='')
    bundle_device_necessity = models.CharField(max_length=4, blank=True, default='')
    bundle_device_securement = models.CharField(max_length=4, blank=True, default='')
    bundle_tube_patency = models.CharField(max_length=4, blank=True, default='')
    bundle_water_flush_protocol = models.CharField(max_length=4, blank=True, default='')
    bundle_feeding_equipment_check = models.CharField(max_length=4, blank=True, default='')
    bundle_patient_positioning = models.CharField(max_length=4, blank=True, default='')
    bundle_oral_care = models.CharField(max_length=4, blank=True, default='')
    bundle_documentation_complete = models.CharField(max_length=4, blank=True, default='')

    # ── NGT / OGT / NJ specific ──
    bundle_position_verification = models.CharField(max_length=4, blank=True, default='')
    bundle_nare_care = models.CharField(max_length=4, blank=True, default='')
    bundle_skin_protection = models.CharField(max_length=4, blank=True, default='')
    bundle_nasal_pressure_prevention = models.CharField(max_length=4, blank=True, default='')

    # ── PEG / PEJ / GJ / J-Tube specific ──
    bundle_stoma_care = models.CharField(max_length=4, blank=True, default='')
    bundle_external_fixation_check = models.CharField(max_length=4, blank=True, default='')
    bundle_external_length_verify = models.CharField(max_length=4, blank=True, default='')
    bundle_tube_rotation = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_management = models.CharField(max_length=4, blank=True, default='')
    bundle_buried_bumper = models.CharField(max_length=4, blank=True, default='')
    bundle_peristomal_care = models.CharField(max_length=4, blank=True, default='')

    # ── Medication safety (maintenance-related only) ──
    bundle_med_safety_check = models.CharField(max_length=4, blank=True, default='')

    # ── Patient / caregiver education ──
    bundle_patient_education = models.CharField(max_length=4, blank=True, default='')

    # ── Computed compliance ──
    bundle_compliance_pct = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='Auto-calculated percentage of "yes" in applicable bundle items.')

    # ── Device removal record ──
    device_removed = models.BooleanField(default=False)
    removal_reason = models.CharField(max_length=255, blank=True)
    removal_date = models.DateTimeField(null=True, blank=True)
    removal_by_name = models.CharField(max_length=255, blank=True)

    # ── Audit ──
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Enteral feeding assessment'
        verbose_name_plural = 'Enteral feeding assessments'

    def __str__(self):
        dev = self.get_device_type_display() if self.device_type else 'Enteral'
        return f'Enteral {dev} – {self.patient.user.full_name}'


# ─────────────────────────────────────────────────────────────────
#  URINARY CATHETER MAINTENANCE BUNDLE (UCBM)
#  CAUTI-prevention maintenance bundle per CDC / SHEA / APIC /
#  JCI / WHO standards.  Covers all catheter types: indwelling
#  (Foley), three-way irrigation, suprapubic, intermittent, and
#  external urinary devices.  Full lifecycle: insertion → daily
#  assessment → maintenance → complication surveillance → removal.
# ─────────────────────────────────────────────────────────────────
class UrinaryCatheterAssessment(models.Model):
    """Urinary Catheter Maintenance Bundle — CAUTI prevention.

    Supports the full catheter lifecycle with daily necessity review,
    comprehensive catheter/site/urine assessment, maintenance bundle
    compliance tracking, complication surveillance, and clinical
    decision support alerts.
    """

    class CatheterType(models.TextChoices):
        FOLEY = 'foley', 'Indwelling Urethral (Foley)'
        THREE_WAY = 'three_way', 'Three-Way Irrigation'
        SUPRAPUBIC = 'suprapubic', 'Suprapubic Catheter'
        INTERMITTENT = 'intermittent', 'Intermittent Catheter'
        EXTERNAL = 'external', 'External Urinary Device'
        OTHER = 'other', 'Other'

    class AssessmentType(models.TextChoices):
        INITIAL = 'initial', 'Initial'
        DAILY = 'daily', 'Daily'
        PRN = 'prn', 'PRN'
        POST_INSERTION = 'post_insertion', 'Post-Insertion'
        REASSESSMENT = 'reassessment', 'Reassessment'

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='urinary_catheter_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='urinary_catheter_assessments')

    # ── Assessment header ──
    assessment_type = models.CharField(
        max_length=20, choices=AssessmentType.choices, default=AssessmentType.DAILY)
    catheter_type = models.CharField(
        max_length=20, choices=CatheterType.choices, default=CatheterType.FOLEY, db_index=True)
    catheter_day = models.PositiveSmallIntegerField(null=True, blank=True)

    # ── Catheter details ──
    catheter_size_fr = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Catheter size in French gauge.')
    balloon_volume_ml = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Balloon inflation volume in mL (Foley).')
    material = models.CharField(max_length=40, blank=True,
                                help_text='latex / silicone / hydrogel-coated')
    insertion_date = models.DateTimeField(null=True, blank=True)
    current_indication = models.CharField(max_length=255, blank=True)

    # ── Catheter Necessity Review ──
    catheter_indicated = models.BooleanField(
        null=True, blank=True,
        help_text='Is the urinary catheter still clinically indicated?')
    indication_reason = models.CharField(
        max_length=80, blank=True,
        help_text='acute_retention / output_monitoring / perioperative / '
                  'sacral_wound / end_of_life / immobilization / '
                  'chronic_urological / other / no_longer_indicated')
    indication_other = models.CharField(max_length=255, blank=True)

    # ── Catheter integrity assessment ──
    catheter_secure = models.BooleanField(null=True, blank=True)
    correct_position = models.BooleanField(null=True, blank=True)
    no_traction = models.BooleanField(null=True, blank=True)
    balloon_intact = models.BooleanField(null=True, blank=True)
    no_leakage = models.BooleanField(null=True, blank=True)
    no_obstruction = models.BooleanField(null=True, blank=True)
    tubing_patent = models.BooleanField(null=True, blank=True)
    no_dependent_loops = models.BooleanField(null=True, blank=True)
    bag_below_bladder = models.BooleanField(null=True, blank=True)
    closed_system_maintained = models.BooleanField(null=True, blank=True)

    # ── Insertion site assessment (urethral) ──
    site_redness = models.BooleanField(null=True, blank=True)
    site_swelling = models.BooleanField(null=True, blank=True)
    site_pain = models.BooleanField(null=True, blank=True)
    site_bleeding = models.BooleanField(null=True, blank=True)
    site_discharge = models.BooleanField(null=True, blank=True)
    site_meatal_irritation = models.BooleanField(null=True, blank=True)
    site_skin_breakdown = models.BooleanField(null=True, blank=True)

    # ── Suprapubic site assessment ──
    sp_stoma_condition = models.CharField(max_length=80, blank=True)
    sp_redness = models.BooleanField(null=True, blank=True)
    sp_swelling = models.BooleanField(null=True, blank=True)
    sp_discharge = models.BooleanField(null=True, blank=True)
    sp_dressing_condition = models.CharField(max_length=80, blank=True)
    sp_pain = models.BooleanField(null=True, blank=True)
    sp_bleeding = models.BooleanField(null=True, blank=True)

    # ── Urine assessment ──
    urine_colour = models.CharField(
        max_length=40, blank=True,
        help_text='straw / yellow / amber / pink / red / brown / green / cloudy / other')
    urine_clarity = models.CharField(
        max_length=40, blank=True,
        help_text='clear / slightly_cloudy / cloudy / turbid')
    urine_odour = models.CharField(
        max_length=40, blank=True,
        help_text='normal / strong / foul')
    urine_sediment = models.CharField(
        max_length=40, blank=True,
        help_text='none / mild / moderate / heavy')
    urine_blood = models.CharField(
        max_length=40, blank=True,
        help_text='none / microscopic / visible')
    urine_output_ml = models.PositiveIntegerField(null=True, blank=True)

    # ── Patient symptoms ──
    patient_fever = models.BooleanField(null=True, blank=True)
    patient_chills = models.BooleanField(null=True, blank=True)
    patient_dysuria = models.BooleanField(null=True, blank=True)
    patient_abdominal_pain = models.BooleanField(null=True, blank=True)
    patient_flank_pain = models.BooleanField(null=True, blank=True)
    patient_confusion = models.BooleanField(null=True, blank=True)
    patient_rigors = models.BooleanField(null=True, blank=True)
    patient_malaise = models.BooleanField(null=True, blank=True)

    # ── Maintenance Bundle (Yes/No/NA) ──
    bundle_necessity_reviewed = models.CharField(max_length=4, blank=True, default='')
    bundle_necessity_indicated = models.CharField(max_length=4, blank=True, default='')
    bundle_hand_hygiene_before = models.CharField(max_length=4, blank=True, default='')
    bundle_hand_hygiene_after = models.CharField(max_length=4, blank=True, default='')
    bundle_hand_hygiene_technique = models.CharField(max_length=4, blank=True, default='')
    bundle_ppe_gloves = models.CharField(max_length=4, blank=True, default='')
    bundle_ppe_additional = models.CharField(max_length=4, blank=True, default='')
    bundle_meatal_hygiene_done = models.CharField(max_length=4, blank=True, default='')
    bundle_meatal_cleansed = models.CharField(max_length=4, blank=True, default='')
    bundle_meatal_no_antiseptic = models.CharField(max_length=4, blank=True, default='')
    bundle_meatal_dried = models.CharField(max_length=4, blank=True, default='')
    bundle_meatal_skin_intact = models.CharField(max_length=4, blank=True, default='')
    bundle_securement_intact = models.CharField(max_length=4, blank=True, default='')
    bundle_securement_proper = models.CharField(max_length=4, blank=True, default='')
    bundle_securement_no_traction = models.CharField(max_length=4, blank=True, default='')
    bundle_securement_comfort = models.CharField(max_length=4, blank=True, default='')
    bundle_drain_closed = models.CharField(max_length=4, blank=True, default='')
    bundle_drain_no_disconnect = models.CharField(max_length=4, blank=True, default='')
    bundle_drain_secure = models.CharField(max_length=4, blank=True, default='')
    bundle_drain_no_leaks = models.CharField(max_length=4, blank=True, default='')
    bundle_bag_below_bladder = models.CharField(max_length=4, blank=True, default='')
    bundle_bag_not_floor = models.CharField(max_length=4, blank=True, default='')
    bundle_bag_tubing_unobstructed = models.CharField(max_length=4, blank=True, default='')
    bundle_bag_no_loops = models.CharField(max_length=4, blank=True, default='')
    bundle_bag_flow_adequate = models.CharField(max_length=4, blank=True, default='')
    bundle_empty_clean = models.CharField(max_length=4, blank=True, default='')
    bundle_empty_port_clean = models.CharField(max_length=4, blank=True, default='')
    bundle_empty_container = models.CharField(max_length=4, blank=True, default='')
    bundle_empty_output_doc = models.CharField(max_length=4, blank=True, default='')
    bundle_specimen_port = models.CharField(max_length=4, blank=True, default='')
    bundle_specimen_aseptic = models.CharField(max_length=4, blank=True, default='')
    bundle_specimen_doc = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_fever = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_chills = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_pain = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_leakage = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_low_output = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_hematuria = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_foul_urine = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_blockage = models.CharField(max_length=4, blank=True, default='')
    bundle_edu_understanding = models.CharField(max_length=4, blank=True, default='')
    bundle_hydration_encouraged = models.CharField(max_length=4, blank=True, default='')
    bundle_hydration_restriction = models.CharField(max_length=4, blank=True, default='')
    bundle_io_urine_recorded = models.CharField(max_length=4, blank=True, default='')
    bundle_io_intake_recorded = models.CharField(max_length=4, blank=True, default='')
    bundle_io_balance_reviewed = models.CharField(max_length=4, blank=True, default='')

    # ── Computed compliance ──
    bundle_compliance_pct = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='Auto-calculated bundle compliance percentage.')

    # ── Complication surveillance ──
    complication_suspected_cauti = models.BooleanField(default=False)
    complication_blockage = models.BooleanField(default=False)
    complication_leakage = models.BooleanField(default=False)
    complication_hematuria = models.BooleanField(default=False)
    complication_spasms = models.BooleanField(default=False)
    complication_dislodgement = models.BooleanField(default=False)
    complication_encrustation = models.BooleanField(default=False)
    complication_trauma = models.BooleanField(default=False)
    complication_accidental_removal = models.BooleanField(default=False)
    complication_urethral_injury = models.BooleanField(default=False)
    complication_sp_site_infection = models.BooleanField(default=False)
    complication_detail = models.TextField(
        blank=True, help_text='Signs, symptoms, actions taken, outcome.')

    # ── Catheter removal ──
    catheter_removed = models.BooleanField(default=False)
    removal_reason = models.CharField(max_length=255, blank=True)
    removal_date = models.DateTimeField(null=True, blank=True)
    removal_by_name = models.CharField(max_length=255, blank=True)

    # ── Audit ──
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Urinary catheter assessment'
        verbose_name_plural = 'Urinary catheter assessments'

    def __str__(self):
        ct = self.get_catheter_type_display() if self.catheter_type else 'Catheter'
        return f'UC {ct} Day {self.catheter_day} – {self.patient.user.full_name}'


# ─────────────────────────────────────────────────────────────────
#  ARTIFICIAL AIRWAY ASSESSMENT  (Airway Management — Assessment Engine)
#  Device-directed assessment engine for artificial airways per JCI /
#  WHO / CDC / AARC / AACN standards.  The system auto-detects the
#  active airway device and activates only the relevant assessment(s):
#     • Tracheostomy               → Tracheostomy Assessment
#     • ETT + mechanical vent      → VAP Assessment
#     • Tracheostomy + mech vent   → both
#  Conditional sub-sections (cuff, inner cannula, subglottic) render
#  only when the device supports them.  Compliance is auto-scored.
# ─────────────────────────────────────────────────────────────────
class ArtificialAirwayAssessment(models.Model):
    """Artificial Airway Assessment — Tracheostomy and/or VAP.

    Assessment-only module (no care bundles / vent settings / notes).
    Every checklist item is documented as 'yes' / 'no' / 'na'.  Two
    independent compliance percentages are auto-calculated: one for the
    Tracheostomy assessment (``trach_*`` fields) and one for the VAP
    assessment (``vap_*`` fields), plus an overall percentage.
    """

    class AirwayDevice(models.TextChoices):
        TRACHEOSTOMY = 'tracheostomy', 'Tracheostomy'
        ETT = 'ett', 'Endotracheal Tube'
        LARYNGECTOMY = 'laryngectomy', 'Laryngectomy'
        NONE = 'none', 'None'

    class AssessmentType(models.TextChoices):
        INITIAL = 'initial', 'Initial'
        ROUTINE = 'routine', 'Routine / Shift'
        PRN = 'prn', 'PRN'
        POST_PROCEDURE = 'post_procedure', 'Post-Procedure'
        REASSESSMENT = 'reassessment', 'Reassessment'

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='artificial_airway_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='artificial_airway_assessments')

    # ── Assessment header ──
    assessment_type = models.CharField(
        max_length=20, choices=AssessmentType.choices, default=AssessmentType.ROUTINE)

    # ── Auto-detected airway device information ──
    airway_device = models.CharField(
        max_length=16, choices=AirwayDevice.choices, default=AirwayDevice.TRACHEOSTOMY,
        db_index=True,
        help_text='Auto-detected from Device Registry; drives which assessment(s) activate.')
    mechanically_ventilated = models.BooleanField(
        default=False,
        help_text='If true (and device is ETT or tracheostomy), the VAP assessment activates.')
    tube_brand = models.CharField(max_length=120, blank=True,
                                  help_text='e.g. Shiley 8.0')
    tube_size = models.CharField(max_length=40, blank=True)
    is_cuffed = models.BooleanField(
        default=True, help_text='Cuffed tube — enables the cuff assessment section.')
    inner_cannula_present = models.BooleanField(
        default=True, help_text='Inner cannula present — enables that section.')
    subglottic_port_present = models.BooleanField(
        default=False, help_text='Tube supports subglottic secretion drainage.')
    insertion_date = models.DateTimeField(null=True, blank=True)
    device_day = models.PositiveSmallIntegerField(null=True, blank=True)
    location = models.CharField(max_length=80, blank=True,
                                help_text='e.g. ICU / Home / Ward')

    # ═══════════ TRACHEOSTOMY ASSESSMENT ═══════════
    # Section 1 — General infection prevention
    t_hand_hygiene_before = models.CharField(max_length=4, blank=True, default='')
    t_gloves_worn = models.CharField(max_length=4, blank=True, default='')
    t_ppe_used = models.CharField(max_length=4, blank=True, default='')
    t_hand_hygiene_after = models.CharField(max_length=4, blank=True, default='')

    # Section 2 — Tube assessment
    t_tube_position_correct = models.CharField(max_length=4, blank=True, default='')
    t_tube_patent = models.CharField(max_length=4, blank=True, default='')
    t_tube_intact = models.CharField(max_length=4, blank=True, default='')
    t_tube_unobstructed = models.CharField(max_length=4, blank=True, default='')
    t_tube_size_verified = models.CharField(max_length=4, blank=True, default='')
    t_tube_type_verified = models.CharField(max_length=4, blank=True, default='')
    t_tube_secured = models.CharField(max_length=4, blank=True, default='')
    t_tube_no_air_leak = models.CharField(max_length=4, blank=True, default='')
    t_tube_no_visible_damage = models.CharField(max_length=4, blank=True, default='')

    # Section 3 — Stoma assessment
    t_stoma_skin_clean = models.CharField(max_length=4, blank=True, default='')
    t_stoma_skin_dry = models.CharField(max_length=4, blank=True, default='')
    t_stoma_no_redness = models.CharField(max_length=4, blank=True, default='')
    t_stoma_no_swelling = models.CharField(max_length=4, blank=True, default='')
    t_stoma_no_bleeding = models.CharField(max_length=4, blank=True, default='')
    t_stoma_no_discharge = models.CharField(max_length=4, blank=True, default='')
    t_stoma_no_odor = models.CharField(max_length=4, blank=True, default='')
    t_stoma_no_granulation = models.CharField(max_length=4, blank=True, default='')
    t_stoma_no_pressure_injury = models.CharField(max_length=4, blank=True, default='')
    t_stoma_no_skin_breakdown = models.CharField(max_length=4, blank=True, default='')
    t_stoma_pain_absent = models.CharField(max_length=4, blank=True, default='')
    t_stoma_redness_severity = models.CharField(
        max_length=12, blank=True, default='',
        help_text='mild / moderate / severe — captured when redness present.')
    t_stoma_photo_url = models.URLField(blank=True)
    t_stoma_interventions = models.TextField(blank=True)

    # Section 4 — Securement
    t_secure_neck_ties_intact = models.CharField(max_length=4, blank=True, default='')
    t_secure_correct_tightness = models.CharField(max_length=4, blank=True, default='')
    t_secure_holder_intact = models.CharField(max_length=4, blank=True, default='')
    t_secure_finger_spacing = models.CharField(max_length=4, blank=True, default='')
    t_secure_no_pressure_injury = models.CharField(max_length=4, blank=True, default='')
    t_secure_no_excessive_movement = models.CharField(max_length=4, blank=True, default='')

    # Section 5 — Inner cannula (conditional: inner_cannula_present)
    t_inner_clean = models.CharField(max_length=4, blank=True, default='')
    t_inner_patent = models.CharField(max_length=4, blank=True, default='')
    t_inner_changed_today = models.CharField(max_length=4, blank=True, default='')
    t_inner_type = models.CharField(
        max_length=12, blank=True, default='',
        help_text='disposable / reusable')
    t_inner_replacement_required = models.CharField(max_length=4, blank=True, default='')

    # Section 6 — Cuff assessment (conditional: is_cuffed)
    t_cuff_inflated = models.CharField(max_length=4, blank=True, default='')
    t_cuff_pressure_measured = models.CharField(max_length=4, blank=True, default='')
    t_cuff_pressure_value = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Cuff pressure in cmH₂O (target 20–30).')
    t_cuff_pressure_in_range = models.CharField(max_length=4, blank=True, default='')
    t_cuff_air_leak_absent = models.CharField(max_length=4, blank=True, default='')
    t_cuff_pilot_balloon_intact = models.CharField(max_length=4, blank=True, default='')

    # Section 7 — Humidification
    t_humid_prescribed = models.CharField(max_length=4, blank=True, default='')
    t_humid_functioning = models.CharField(max_length=4, blank=True, default='')
    t_humid_hme_functioning = models.CharField(max_length=4, blank=True, default='')
    t_humid_heated_functioning = models.CharField(max_length=4, blank=True, default='')
    t_humid_water_chamber_adequate = models.CharField(max_length=4, blank=True, default='')
    t_humid_tubing_functioning = models.CharField(max_length=4, blank=True, default='')

    # Section 8 — Suction equipment
    t_suction_available = models.CharField(max_length=4, blank=True, default='')
    t_suction_pressure_checked = models.CharField(max_length=4, blank=True, default='')
    t_suction_catheter_available = models.CharField(max_length=4, blank=True, default='')
    t_suction_correct_size = models.CharField(max_length=4, blank=True, default='')
    t_suction_equipment_functional = models.CharField(max_length=4, blank=True, default='')

    # Section 9 — Emergency equipment (any 'no' → critical alert)
    t_emerg_same_size_tube = models.CharField(max_length=4, blank=True, default='')
    t_emerg_smaller_tube = models.CharField(max_length=4, blank=True, default='')
    t_emerg_obturator = models.CharField(max_length=4, blank=True, default='')
    t_emerg_bag_valve_mask = models.CharField(max_length=4, blank=True, default='')
    t_emerg_oxygen = models.CharField(max_length=4, blank=True, default='')
    t_emerg_call_bell = models.CharField(max_length=4, blank=True, default='')

    # Section 10 — Communication
    t_comm_method_assessed = models.CharField(max_length=4, blank=True, default='')
    t_comm_speaking_valve = models.CharField(max_length=4, blank=True, default='')
    t_comm_writing_board = models.CharField(max_length=4, blank=True, default='')
    t_comm_communication_chart = models.CharField(max_length=4, blank=True, default='')
    t_comm_interpreter = models.CharField(max_length=4, blank=True, default='')
    t_comm_caregiver_support = models.CharField(max_length=4, blank=True, default='')

    # Section 11 — Documentation
    t_doc_bundle_complete = models.CharField(max_length=4, blank=True, default='')
    t_doc_education_completed = models.CharField(max_length=4, blank=True, default='')

    # Tracheostomy computed compliance
    trach_compliance_pct = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='Auto-calculated % of "yes" across answered tracheostomy items.')

    # ═══════════ VAP PREVENTION ASSESSMENT ═══════════
    # Section 1 — Head of bed
    v_hob_30_45_maintained = models.CharField(max_length=4, blank=True, default='')
    v_hob_contraindication = models.CharField(max_length=4, blank=True, default='')

    # Section 2 — Oral care
    v_oral_care_completed = models.CharField(max_length=4, blank=True, default='')
    v_oral_teeth_cleaned = models.CharField(max_length=4, blank=True, default='')
    v_oral_tongue_cleaned = models.CharField(max_length=4, blank=True, default='')
    v_oral_mucosa_clean = models.CharField(max_length=4, blank=True, default='')
    v_oral_moisturizer_applied = models.CharField(max_length=4, blank=True, default='')
    v_oral_chlorhexidine_used = models.CharField(max_length=4, blank=True, default='')
    v_oral_secretions_removed = models.CharField(max_length=4, blank=True, default='')

    # Section 3 — Airway device
    v_airway_tube_secure = models.CharField(max_length=4, blank=True, default='')
    v_airway_position_correct = models.CharField(max_length=4, blank=True, default='')
    v_airway_cuff_pressure_target = models.CharField(max_length=4, blank=True, default='')
    v_airway_no_air_leak = models.CharField(max_length=4, blank=True, default='')
    v_airway_subglottic_functioning = models.CharField(max_length=4, blank=True, default='')

    # Section 4 — Sedation
    v_sedation_daily_review = models.CharField(max_length=4, blank=True, default='')
    v_sedation_interruption = models.CharField(max_length=4, blank=True, default='')
    v_sedation_contraindication = models.CharField(max_length=4, blank=True, default='')

    # Section 5 — Weaning
    v_weaning_readiness_assessed = models.CharField(max_length=4, blank=True, default='')
    v_weaning_sbt_considered = models.CharField(max_length=4, blank=True, default='')
    v_weaning_extubation_readiness = models.CharField(max_length=4, blank=True, default='')

    # Section 6 — Suctioning
    v_suction_need_assessed = models.CharField(max_length=4, blank=True, default='')
    v_suction_secretions_removed = models.CharField(max_length=4, blank=True, default='')
    v_suction_closed_functioning = models.CharField(max_length=4, blank=True, default='')
    v_suction_catheter_changed = models.CharField(max_length=4, blank=True, default='')

    # Section 7 — Ventilator circuit
    v_circuit_intact = models.CharField(max_length=4, blank=True, default='')
    v_circuit_no_disconnections = models.CharField(max_length=4, blank=True, default='')
    v_circuit_condensation_managed = models.CharField(max_length=4, blank=True, default='')
    v_circuit_changed_per_policy = models.CharField(max_length=4, blank=True, default='')

    # Section 8 — Aspiration prevention
    v_asp_head_elevated = models.CharField(max_length=4, blank=True, default='')
    v_asp_feeding_paused = models.CharField(max_length=4, blank=True, default='')
    v_asp_tube_position_verified = models.CharField(max_length=4, blank=True, default='')
    v_asp_regurgitation_absent = models.CharField(max_length=4, blank=True, default='')

    # Section 9 — Documentation
    v_doc_bundle_complete = models.CharField(max_length=4, blank=True, default='')

    # VAP computed compliance
    vap_compliance_pct = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='Auto-calculated % of "yes" across answered VAP items.')

    # ── Overall compliance + surveillance ──
    overall_compliance_pct = models.PositiveSmallIntegerField(null=True, blank=True)
    emergency_equipment_incomplete = models.BooleanField(
        default=False,
        help_text='True when any emergency equipment item is "no" — raises a critical alert.')
    suspected_vap = models.BooleanField(default=False)
    suspected_tube_displacement = models.BooleanField(default=False)

    # ── Device removal / decannulation / extubation ──
    device_removed = models.BooleanField(
        default=False, help_text='Decannulated (trach) or extubated (ETT).')
    removal_reason = models.CharField(max_length=255, blank=True)
    removal_date = models.DateTimeField(null=True, blank=True)
    removal_by_name = models.CharField(max_length=255, blank=True)

    # ── Audit ──
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'Artificial airway assessment'
        verbose_name_plural = 'Artificial airway assessments'

    def __str__(self):
        dev = self.get_airway_device_display() if self.airway_device else 'Airway'
        return f'Airway {dev} – {self.patient.user.full_name}'


# ─────────────────────────────────────────────────────────────────
#  CENTRAL VASCULAR ACCESS DEVICE (CVAD) CARE BUNDLE
#  Concise, evidence-based nursing bundle for CLABSI prevention &
#  vascular access care per INS Standards, CDC CLABSI Prevention,
#  SHEA / IDSA, JCI, WHO, and KDOQI / KDIGO (dialysis).  Applies to
#  CVC, PICC, midline, dialysis catheter, tunneled line, and port.
#  ~12 bundle elements, completable in 2–3 min; every item is
#  documented 'yes' / 'no' / 'na' with auto-calculated compliance.
# ─────────────────────────────────────────────────────────────────
class CVADAssessment(models.Model):
    """Central Vascular Access Device care bundle — CLABSI prevention.

    Structured findings (site signs, systemic symptoms, mechanical
    complications) drive escalation flags; the tri-state ``bundle_*``
    elements drive an auto-calculated compliance percentage.
    """

    class DeviceType(models.TextChoices):
        CVC = 'cvc', 'Central Venous Catheter (CVC)'
        PICC = 'picc', 'PICC Line'
        MIDLINE = 'midline', 'Midline'
        DIALYSIS = 'dialysis', 'Dialysis Catheter'
        TUNNELED = 'tunneled', 'Tunneled Central Line'
        PORT = 'port', 'Implanted Port'
        OTHER = 'other', 'Other'

    class AssessmentType(models.TextChoices):
        SHIFT = 'shift', 'Shiftly'
        DAILY = 'daily', 'Daily'
        BEFORE_ACCESS = 'before_access', 'Before Access'
        AFTER_ACCESS = 'after_access', 'After Access'
        PRN = 'prn', 'PRN'

    episode = models.ForeignKey(AssessmentSession, on_delete=models.CASCADE,
                                related_name='cvad_assessments')
    patient = models.ForeignKey(HomecarePatient, on_delete=models.CASCADE,
                                related_name='cvad_assessments')

    # ── Assessment header / device info ──
    assessment_type = models.CharField(
        max_length=20, choices=AssessmentType.choices, default=AssessmentType.SHIFT)
    device_type = models.CharField(
        max_length=16, choices=DeviceType.choices, default=DeviceType.CVC, db_index=True,
        help_text='Auto-detected from Device Registry; drives applicable bundle items.')
    catheter_day = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Dwell day (days since insertion).')
    num_lumens = models.PositiveSmallIntegerField(null=True, blank=True)
    insertion_site = models.CharField(
        max_length=80, blank=True,
        help_text='e.g. Right IJ / Left subclavian / Right basilic (PICC) / Right chest port')
    current_indication = models.CharField(max_length=255, blank=True)
    catheter_indicated = models.BooleanField(
        null=True, blank=True, help_text='Is the CVAD still clinically indicated?')
    external_length_cm = models.FloatField(
        null=True, blank=True, help_text='External catheter length — track for migration.')

    # ── Catheter site assessment (findings → drive alerts) ──
    site_redness = models.BooleanField(null=True, blank=True)
    site_swelling = models.BooleanField(null=True, blank=True)
    site_tenderness = models.BooleanField(null=True, blank=True)
    site_warmth = models.BooleanField(null=True, blank=True)
    site_drainage = models.BooleanField(null=True, blank=True)
    site_purulent_drainage = models.BooleanField(null=True, blank=True)
    site_bleeding = models.BooleanField(null=True, blank=True)

    # ── Dressing ──
    dressing_type = models.CharField(
        max_length=40, blank=True,
        help_text='transparent_semipermeable / gauze / chg_impregnated / other')
    last_dressing_change = models.DateTimeField(null=True, blank=True)
    dressing_change_due = models.BooleanField(null=True, blank=True)

    # ── Securement ──
    securement_type = models.CharField(
        max_length=40, blank=True,
        help_text='engineered_securement / sutureless_device / suture / adhesive / other')

    # ── Patency ──
    flushes_easily = models.BooleanField(null=True, blank=True)
    blood_return_present = models.BooleanField(null=True, blank=True)
    resistance_present = models.BooleanField(null=True, blank=True)

    # ── Systemic infection / CLABSI signs (findings → alerts) ──
    patient_fever = models.BooleanField(null=True, blank=True)
    patient_chills = models.BooleanField(null=True, blank=True)
    patient_rigors = models.BooleanField(null=True, blank=True)
    patient_hypotension = models.BooleanField(null=True, blank=True)
    patient_malaise = models.BooleanField(null=True, blank=True)

    # ── Mechanical complications (findings → alerts) ──
    complication_migration = models.BooleanField(default=False)
    complication_leakage = models.BooleanField(default=False)
    complication_occlusion = models.BooleanField(default=False)
    complication_damage = models.BooleanField(default=False)
    complication_dislodgement = models.BooleanField(default=False)
    complication_thrombosis = models.BooleanField(default=False)
    complication_detail = models.TextField(
        blank=True, help_text='Signs, actions taken, outcome.')

    # ═══════════ CARE BUNDLE ELEMENTS (yes / no / na) ═══════════
    # 1 — Daily Line Necessity Review
    bundle_necessity_reviewed = models.CharField(max_length=4, blank=True, default='')
    bundle_necessity_indicated = models.CharField(max_length=4, blank=True, default='')
    # 2 — Hand Hygiene & aseptic technique
    bundle_hand_hygiene_before = models.CharField(max_length=4, blank=True, default='')
    bundle_hand_hygiene_after = models.CharField(max_length=4, blank=True, default='')
    bundle_aseptic_technique = models.CharField(max_length=4, blank=True, default='')
    # 3 — Catheter Site Assessment
    bundle_site_assessed = models.CharField(max_length=4, blank=True, default='')
    bundle_site_no_infection = models.CharField(max_length=4, blank=True, default='')
    # 4 — Dressing Integrity & Condition
    bundle_dressing_intact = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_clean_dry = models.CharField(max_length=4, blank=True, default='')
    bundle_dressing_dated = models.CharField(max_length=4, blank=True, default='')
    # 5 — Catheter Securement
    bundle_securement_intact = models.CharField(max_length=4, blank=True, default='')
    bundle_securement_device = models.CharField(max_length=4, blank=True, default='')
    # 6 — Catheter Patency
    bundle_patency_flush = models.CharField(max_length=4, blank=True, default='')
    bundle_patency_blood_return = models.CharField(max_length=4, blank=True, default='')
    bundle_patency_no_resistance = models.CharField(max_length=4, blank=True, default='')
    # 7 — Lumen Management & Access Technique
    bundle_lumens_labeled = models.CharField(max_length=4, blank=True, default='')
    bundle_aseptic_access = models.CharField(max_length=4, blank=True, default='')
    bundle_needleless_connector = models.CharField(max_length=4, blank=True, default='')
    # 8 — Hub / Connector Disinfection
    bundle_hub_scrubbed = models.CharField(max_length=4, blank=True, default='')
    bundle_hub_scrub_duration = models.CharField(max_length=4, blank=True, default='')
    bundle_hub_dried = models.CharField(max_length=4, blank=True, default='')
    bundle_caps_changed = models.CharField(max_length=4, blank=True, default='')
    # 9 — Signs of Infection / CLABSI
    bundle_no_systemic_infection = models.CharField(max_length=4, blank=True, default='')
    # 10 — Mechanical Complication Assessment
    bundle_no_mechanical_complication = models.CharField(max_length=4, blank=True, default='')
    # 11 — Patient Education
    bundle_patient_educated = models.CharField(max_length=4, blank=True, default='')
    bundle_patient_understands = models.CharField(max_length=4, blank=True, default='')
    # 12 — Documentation & Handover
    bundle_documented = models.CharField(max_length=4, blank=True, default='')
    bundle_handover_complete = models.CharField(max_length=4, blank=True, default='')

    # ── Computed compliance ──
    bundle_compliance_pct = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text='Auto-calculated % of "yes" across answered bundle items.')

    # ── Escalation flags ──
    suspected_clabsi = models.BooleanField(
        default=False, help_text='Local + systemic infection signs — escalate.')
    escalation_required = models.BooleanField(default=False)

    # ── Catheter removal ──
    catheter_removed = models.BooleanField(default=False)
    removal_reason = models.CharField(max_length=255, blank=True)
    removal_date = models.DateTimeField(null=True, blank=True)
    removal_by_name = models.CharField(max_length=255, blank=True)

    # ── Audit ──
    notes = models.TextField(blank=True)
    assessed_by_user_id = models.IntegerField(null=True, blank=True)
    assessed_by_name = models.CharField(max_length=255, blank=True)
    assessed_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-assessed_at']
        verbose_name = 'CVAD assessment'
        verbose_name_plural = 'CVAD assessments'

    def __str__(self):
        dev = self.get_device_type_display() if self.device_type else 'CVAD'
        return f'CVAD {dev} – {self.patient.user.full_name}'


class AssessmentAlert(models.Model):
    """An individual clinical alert generated from an assessment session.

    High-risk thresholds (Braden ≤18, Caprini ≥3, Morse ≥45, MUST ≥2,
    CAM positive, severe pain ≥7) each produce an AssessmentAlert and,
    for critical thresholds, a linked Escalation record.
    """

    class Severity(models.TextChoices):
        INFO = 'info', 'Info'
        WARNING = 'warning', 'Warning'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    class Category(models.TextChoices):
        PRESSURE = 'pressure', 'Pressure Injury Risk'
        VTE = 'vte', 'VTE Risk'
        FALLS = 'falls', 'Falls Risk'
        NUTRITION = 'nutrition', 'Malnutrition Risk'
        DELIRIUM = 'delirium', 'Delirium'
        PAIN = 'pain', 'Severe Pain'
        DEVICE = 'device', 'Device Bundle'
        OTHER = 'other', 'Other'

    session = models.ForeignKey(
        AssessmentSession, on_delete=models.CASCADE,
        related_name='alerts',
    )
    code = models.CharField(max_length=40, blank=True, db_index=True,
                            help_text='Stable alert code (e.g. BRADEN_RISK) for dedup.')
    category = models.CharField(max_length=16, choices=Category.choices, db_index=True)
    severity = models.CharField(max_length=16, choices=Severity.choices,
                                default=Severity.WARNING, db_index=True)
    title = models.CharField(max_length=255)
    detail = models.TextField(blank=True)
    threshold = models.CharField(max_length=80, blank=True,
                                 help_text='e.g. "Braden ≤ 18"')
    value = models.CharField(max_length=80, blank=True,
                             help_text='e.g. "16 – Mild Risk"')
    recommendation = models.TextField(blank=True)
    escalation = models.ForeignKey(
        Escalation, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='assessment_alerts',
    )
    resolved = models.BooleanField(default=False)
    resolved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-severity', '-created_at']
        indexes = [
            models.Index(fields=['session', 'severity']),
            models.Index(fields=['category', 'resolved']),
        ]

    def __str__(self):
        return f'{self.get_category_display()} ({self.severity}) – {self.title}'

