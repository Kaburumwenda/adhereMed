from django.db import models
from django.conf import settings
from django.utils import timezone

from datetime import date as dt_date


def generate_patient_id():
    """Generate the next incremental AdhereMed patient id: AD01, AD02, ...

    Numbers are zero-padded to a minimum of two digits and grow as needed
    (AD99 -> AD100). Scoped to the current database schema (tenant).
    """
    max_n = 0
    for pid in Patient.objects.filter(patient_id__startswith='AD').values_list('patient_id', flat=True):
        try:
            n = int(pid[2:])
        except (TypeError, ValueError):
            continue
        if n > max_n:
            max_n = n
    return f'AD{max_n + 1:02d}'


class Patient(models.Model):
    class Gender(models.TextChoices):
        MALE = 'male', 'Male'
        FEMALE = 'female', 'Female'
        OTHER = 'other', 'Other'

    class BloodType(models.TextChoices):
        A_POS = 'A+', 'A+'
        A_NEG = 'A-', 'A-'
        B_POS = 'B+', 'B+'
        B_NEG = 'B-', 'B-'
        AB_POS = 'AB+', 'AB+'
        AB_NEG = 'AB-', 'AB-'
        O_POS = 'O+', 'O+'
        O_NEG = 'O-', 'O-'

    class RegistrationSource(models.TextChoices):
        SELF = 'self', 'Self registration'
        HOMECARE = 'homecare', 'Homecare'
        HOSPITAL = 'hospital', 'Hospital'
        CLINIC = 'clinic', 'Clinic'
        PHARMACY = 'pharmacy', 'Pharmacy'
        RADIOLOGY = 'radiology', 'Radiology'
        LAB = 'lab', 'Laboratory'
        DOCTOR = 'doctor', 'Doctor'
        OTHER = 'other', 'Other'

    class Category(models.TextChoices):
        """Clinical stream the patient is registered under.

        Registration is the only place this is chosen: a paediatric record is
        a child seen under a parent/guardian, so the guardian block on the
        record is what the front desk needs at check-in.
        """
        GENERAL = 'general', 'General'
        PAEDIATRIC = 'paediatric', 'Paediatrics'

    class ImmunisationStatus(models.TextChoices):
        UNKNOWN = '', 'Not recorded'
        UP_TO_DATE = 'up_to_date', 'Up to date'
        DUE = 'due', 'Due / partial'
        OVERDUE = 'overdue', 'Overdue'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='patient_profile',
    )
    patient_id = models.CharField(
        max_length=20, unique=True, db_index=True, blank=True,
        help_text='Auto-generated AdhereMed patient identifier (AD01, AD02, ...).',
    )
    patient_number = models.CharField(max_length=20, unique=True, db_index=True)
    # ``db_constraint=False``: the ``clinic_sites`` table only exists inside a
    # tenant schema, while ``patients`` is also migrated into ``public`` (shared
    # app). A real FK there would make every tenant's schema depend on a
    # public-schema table that does not exist.
    clinic_site = models.ForeignKey(
        'clinic_sites.ClinicSite', on_delete=models.SET_NULL, null=True, blank=True,
        db_constraint=False,
        related_name='patients',
        help_text='Clinic location where the patient was first registered (null = HQ).',
    )
    registration_source = models.CharField(
        max_length=20, choices=RegistrationSource.choices,
        default=RegistrationSource.SELF, db_index=True,
        help_text='How the patient first got registered on AdhereMed.',
    )
    patient_category = models.CharField(
        max_length=20, choices=Category.choices,
        default=Category.GENERAL, db_index=True,
        help_text='Clinical stream: general or paediatrics. Chosen at registration.',
    )
    # ── Paediatrics ──────────────────────────────────────────────────
    guardian_name = models.CharField(
        max_length=255, blank=True,
        help_text='Parent / guardian responsible for a paediatric patient.',
    )
    guardian_phone = models.CharField(max_length=20, blank=True)
    guardian_relationship = models.CharField(
        max_length=50, blank=True,
        help_text='e.g. Mother, Father, Grandparent, Legal guardian.',
    )
    immunisation_status = models.CharField(
        max_length=20, choices=ImmunisationStatus.choices, blank=True, default='',
        help_text='Immunisation state captured at paediatric registration.',
    )
    date_of_birth = models.DateField()
    gender = models.CharField(max_length=10, choices=Gender.choices)
    blood_type = models.CharField(max_length=5, choices=BloodType.choices, blank=True)
    national_id = models.CharField(max_length=30, unique=True, null=True, blank=True)
    address = models.TextField(blank=True)
    # Geocoded home address — captured from Google Places at registration so
    # homecare routing and outreach can place the patient on a map.
    latitude = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True,
        help_text='Latitude of the patient home address (Google Places).',
    )
    longitude = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True,
        help_text='Longitude of the patient home address (Google Places).',
    )
    address_place_id = models.CharField(
        max_length=255, blank=True, default='',
        help_text='Google Places place_id for the saved address (re-resolution).',
    )
    allergies = models.JSONField(default=list, blank=True)
    chronic_conditions = models.JSONField(default=list, blank=True)
    emergency_contact_name = models.CharField(max_length=255, blank=True)
    emergency_contact_phone = models.CharField(max_length=20, blank=True)
    emergency_contact_relation = models.CharField(max_length=50, blank=True)
    insurance_provider = models.CharField(max_length=255, blank=True)
    insurance_number = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    has_portal_access = models.BooleanField(
        default=False,
        help_text='True when the patient was given a password to log into their '
                  'patient dashboard (as opposed to a clinic-only walk-in record).',
    )
    shared_fields = models.JSONField(
        default=list, blank=True,
        help_text='Categories of clinical data visible on the patient dashboard '
                  '(e.g. ["profile","medications","vitals"]).',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def age_years(self):
        """Whole years since ``date_of_birth`` (None when it is not set)."""
        if not self.date_of_birth:
            return None
        today = dt_date.today()
        return (
            today.year - self.date_of_birth.year
            - ((today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day))
        )

    @property
    def is_paediatric(self):
        """True for a paediatrics record, or any patient still under 18.

        The age check keeps records registered before the category existed
        behaving correctly on the clinical side.
        """
        if self.patient_category == self.Category.PAEDIATRIC:
            return True
        age = self.age_years
        return age is not None and age < 18

    def save(self, *args, **kwargs):
        if not self.patient_id:
            self.patient_id = generate_patient_id()
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.user.full_name} ({self.patient_id or self.patient_number})'


class CareNote(models.Model):
    """Clinical progress / care note written against a clinic patient.

    Distinct from ``homecare.CaregiverNote``: that one is a home-visit note owned
    by a homecare caregiver and keyed to a ``homecare.HomecarePatient``. Clinic
    tenants have neither caregivers nor homecare patients, so the clinic module
    needs its own note store keyed to ``patients.Patient``.

    ``author_name`` / ``author_role`` are denormalised snapshots. ``accounts`` is
    a SHARED app, so ``User`` rows live in ``public.accounts_user`` and are
    shared by every tenant; if a staff account is later deleted or renamed the
    note must still show who wrote it. Never join-depend on ``author`` for
    display.
    """

    class Category(models.TextChoices):
        OBSERVATION = 'observation', 'Observation'
        ASSESSMENT = 'assessment', 'Assessment'
        NURSING = 'nursing', 'Nursing care'
        MEDICATION = 'medication', 'Medication'
        PROCEDURE = 'procedure', 'Procedure'
        HANDOVER = 'handover', 'Handover'
        INCIDENT = 'incident', 'Incident'
        DIET = 'diet', 'Diet & nutrition'
        ACTIVITY = 'activity', 'Activity & mobility'
        FOLLOW_UP = 'follow_up', 'Follow-up'
        GENERAL = 'general', 'General'

    class Priority(models.TextChoices):
        ROUTINE = 'routine', 'Routine'
        IMPORTANT = 'important', 'Important'
        URGENT = 'urgent', 'Urgent'

    patient = models.ForeignKey(
        Patient, on_delete=models.CASCADE, related_name='care_notes',
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='care_notes_authored',
    )
    author_name = models.CharField(max_length=255, blank=True)
    author_role = models.CharField(max_length=40, blank=True)

    category = models.CharField(
        max_length=20, choices=Category.choices,
        default=Category.OBSERVATION, db_index=True,
    )
    priority = models.CharField(
        max_length=20, choices=Priority.choices,
        default=Priority.ROUTINE, db_index=True,
    )
    title = models.CharField(max_length=140, blank=True)
    content = models.TextField()
    vitals = models.JSONField(
        default=dict, blank=True,
        help_text='Optional snapshot taken with the note: {temp, pulse, resp, '
                  'systolic, diastolic, spo2, glucose, weight}.',
    )
    tags = models.JSONField(default=list, blank=True)
    follow_up_at = models.DateTimeField(null=True, blank=True)
    is_pinned = models.BooleanField(default=False)
    recorded_at = models.DateTimeField(
        default=timezone.now, db_index=True,
        help_text='Clinical time of the note (editable) — not the row insert time.',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_pinned', '-recorded_at']

    def __str__(self):
        return f'{self.get_category_display()} note · {self.patient}'


class VitalObservation(models.Model):
    """A clinic-recorded set of vital signs.

    Why a dedicated model instead of the old "vitals live inside a Triage row"
    approach: triage vitals are a by-product of the triage workflow and are
    locked to that encounter, consultation vitals are locked to a consultation,
    and both store a free-form JSON blob that cannot be queried. Ward rounds,
    follow-up checks and ad-hoc observations had nowhere to go at all.

    The vitals list endpoint still *merges* triage and consultation vitals in
    (read-only, tagged with their source) so the clinical timeline is complete
    from day one without a data migration.
    """

    class Consciousness(models.TextChoices):
        ALERT = 'A', 'Alert'
        NEW_CONFUSION = 'CVPU', 'New confusion'
        VOICE = 'V', 'Responds to voice'
        PAIN = 'P', 'Responds to pain'
        UNRESPONSIVE = 'U', 'Unresponsive'

    patient = models.ForeignKey(
        Patient, on_delete=models.CASCADE, related_name='vital_observations',
    )
    recorded_at = models.DateTimeField(
        default=timezone.now, db_index=True,
        help_text='Clinical time of the observation (editable).',
    )
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='vital_observations_recorded',
    )
    recorded_by_name = models.CharField(max_length=255, blank=True)
    recorded_by_role = models.CharField(max_length=40, blank=True)

    # ── Measurements (all optional — partial sets are clinically normal) ──
    temperature = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    bp_systolic = models.PositiveSmallIntegerField(null=True, blank=True)
    bp_diastolic = models.PositiveSmallIntegerField(null=True, blank=True)
    heart_rate = models.PositiveSmallIntegerField(null=True, blank=True)
    respiratory_rate = models.PositiveSmallIntegerField(null=True, blank=True)
    oxygen_saturation = models.PositiveSmallIntegerField(null=True, blank=True)
    blood_sugar = models.DecimalField(
        max_digits=5, decimal_places=1, null=True, blank=True,
        help_text='Capillary glucose, mmol/L.',
    )
    weight = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    height = models.DecimalField(max_digits=6, decimal_places=1, null=True, blank=True)
    pain_score = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='0-10 numeric rating scale.',
    )

    # ── NEWS2 modifiers ──
    spo2_scale = models.PositiveSmallIntegerField(
        default=1, choices=[(1, 'Scale 1'), (2, 'Scale 2 (target 88-92 %)')],
    )
    on_oxygen = models.BooleanField(default=False)
    consciousness = models.CharField(
        max_length=4, choices=Consciousness.choices, default=Consciousness.ALERT,
    )

    # ── Derived (written on save, never trusted from the client) ──
    news2_score = models.IntegerField(default=0, db_index=True)
    news2_breakdown = models.JSONField(default=dict, blank=True)

    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-recorded_at']
        indexes = [
            models.Index(fields=['patient', '-recorded_at']),
        ]

    def __str__(self):
        return f'Vitals · {self.patient} · {self.recorded_at:%Y-%m-%d %H:%M}'

    # The canonical shape the frontend reads. Legacy triage/consultation rows are
    # normalised into this same dict by the viewset so one renderer handles all.
    def as_vital_signs(self):
        return {
            'temperature': float(self.temperature) if self.temperature is not None else None,
            'bp_systolic': self.bp_systolic,
            'bp_diastolic': self.bp_diastolic,
            'heart_rate': self.heart_rate,
            'respiratory_rate': self.respiratory_rate,
            'oxygen_saturation': self.oxygen_saturation,
            'blood_sugar': float(self.blood_sugar) if self.blood_sugar is not None else None,
            'weight': float(self.weight) if self.weight is not None else None,
            'height': float(self.height) if self.height is not None else None,
            'pain_score': self.pain_score,
            'spo2_scale': self.spo2_scale,
            'on_oxygen': self.on_oxygen,
            'consciousness': self.consciousness,
        }

    def save(self, *args, **kwargs):
        from .vitals import score_news2

        total, breakdown = score_news2(self.as_vital_signs())
        self.news2_score = total
        self.news2_breakdown = breakdown
        super().save(*args, **kwargs)
