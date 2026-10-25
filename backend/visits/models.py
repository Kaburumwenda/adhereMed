"""Clinic front-desk patient journey.

A ``PatientVisit`` is the single record that follows one patient through the
clinic from the moment they walk in to the moment they are discharged:

    1. arrived            — patient walked into reception
    2. registered         — reception registered / confirmed the patient
    3. awaiting_payment   — consultation fee charged, sent to billing office
    4. paid               — fee collected (or waived)
    5. triage             — nurse is capturing vitals
    6. awaiting_doctor    — triage complete, doctor assigned
    7. in_consultation    — doctor is assessing
    8. in_lab             — doctor ordered labs, lab is processing
    9. lab_ready          — results uploaded, waiting for the doctor
   10. review             — doctor is reviewing the results
   11. prescribed         — medication prescribed
   12. discharged         — visit closed

Every transition is time-stamped on the visit and appended to ``VisitEvent``
so the front desk can see how long a patient has been waiting at each stage.
"""
from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone


class ClinicSettings(models.Model):
    """Singleton per tenant schema — front-desk defaults.

    There is exactly one row per tenant (``get_solo()`` creates it lazily).
    """

    consultation_fee = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal('0.00'),
        help_text='Default fee charged at reception / billing office.',
    )
    currency = models.CharField(max_length=8, default='KES')
    require_payment_before_triage = models.BooleanField(
        default=False,
        help_text='Block the triage step until the consultation fee is settled.',
    )
    require_triage_before_doctor = models.BooleanField(
        default=True,
        help_text='A patient cannot see a doctor until triage is completed.',
    )
    auto_invoice_lab_tests = models.BooleanField(
        default=False,
        help_text='Add lab test prices to the patient invoice when a lab order is raised.',
    )
    allow_fee_waiver = models.BooleanField(
        default=True,
        help_text='Allow reception to waive the consultation fee (e.g. staff, emergencies).',
    )
    visit_number_prefix = models.CharField(max_length=8, default='VD')
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Clinic front-desk settings'
        verbose_name_plural = 'Clinic front-desk settings'

    def __str__(self):
        return f'Clinic settings ({self.currency} {self.consultation_fee})'

    @classmethod
    def get_solo(cls):
        obj = cls.objects.order_by('id').first()
        if obj is None:
            obj = cls.objects.create()
        return obj


class PatientVisit(models.Model):
    class Stage(models.TextChoices):
        ARRIVED = 'arrived', 'Arrived'
        REGISTERED = 'registered', 'Registered'
        AWAITING_PAYMENT = 'awaiting_payment', 'Awaiting payment'
        PAID = 'paid', 'Fee paid'
        TRIAGE = 'triage', 'In triage'
        AWAITING_DOCTOR = 'awaiting_doctor', 'Awaiting doctor'
        IN_CONSULTATION = 'in_consultation', 'With doctor'
        IN_LAB = 'in_lab', 'In laboratory'
        LAB_READY = 'lab_ready', 'Lab results ready'
        REVIEW = 'review', 'Doctor reviewing results'
        PRESCRIBED = 'prescribed', 'Prescribed'
        DISCHARGED = 'discharged', 'Discharged'
        CANCELLED = 'cancelled', 'Cancelled'

    class PaymentStatus(models.TextChoices):
        UNPAID = 'unpaid', 'Unpaid'
        PARTIAL = 'partial', 'Partially paid'
        PAID = 'paid', 'Paid'
        WAIVED = 'waived', 'Waived'

    class Payer(models.TextChoices):
        SELF = 'self', 'Self pay'
        INSURANCE = 'insurance', 'Insurance'
        CORPORATE = 'corporate', 'Corporate'
        WAIVER = 'waiver', 'Waiver'

    class Outcome(models.TextChoices):
        DISCHARGED = 'discharged', 'Discharged home'
        REFERRED = 'referred', 'Referred'
        ADMITTED = 'admitted', 'Admitted'
        OBSERVATION = 'observation', 'Observation'
        LEFT_AMA = 'left_ama', 'Left against advice'
        DECEASED = 'deceased', 'Deceased'

    class Priority(models.TextChoices):
        ROUTINE = 'routine', 'Routine'
        URGENT = 'urgent', 'Urgent'
        EMERGENCY = 'emergency', 'Emergency'

    # ── Identity ────────────────────────────────────────────────────────
    visit_number = models.CharField(max_length=30, unique=True, db_index=True)
    queue_number = models.PositiveIntegerField(default=0, help_text='Token shown on the waiting board')
    patient = models.ForeignKey(
        'patients.Patient', on_delete=models.CASCADE, related_name='visits',
    )
    appointment = models.ForeignKey(
        'appointments.Appointment', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visits',
    )
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='patient_visits',
    )
    stage = models.CharField(max_length=30, choices=Stage.choices, default=Stage.ARRIVED, db_index=True)
    priority = models.CharField(max_length=20, choices=Priority.choices, default=Priority.ROUTINE)

    # ── Linked clinical records ─────────────────────────────────────────
    triage = models.OneToOneField(
        'triage.Triage', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visit',
    )
    consultation = models.OneToOneField(
        'consultations.Consultation', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visit',
    )
    invoice = models.ForeignKey(
        'billing.Invoice', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visits',
    )

    # ── Payment ─────────────────────────────────────────────────────────
    consultation_fee = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'))
    payment_status = models.CharField(
        max_length=20, choices=PaymentStatus.choices, default=PaymentStatus.UNPAID,
    )
    payer = models.CharField(max_length=20, choices=Payer.choices, default=Payer.SELF)
    payment_method = models.CharField(max_length=20, blank=True, default='')
    waiver_reason = models.CharField(max_length=255, blank=True, default='')

    # ── Corporate (employer) billing ────────────────────────────────────
    corporate = models.ForeignKey(
        'corporate.CorporateClient', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visits',
        help_text='Company billed for this visit when payer is corporate.',
    )
    corporate_staff = models.ForeignKey(
        'corporate.CorporateStaff', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visits',
        help_text='Employee/dependant verified against the corporate roster.',
    )
    corporate_verified = models.BooleanField(
        default=False,
        help_text='True once the corporate contract and patient details were verified.',
    )
    corporate_verified_at = models.DateTimeField(null=True, blank=True)
    corporate_authorisation = models.CharField(
        max_length=120, blank=True, default='',
        help_text='Job card / authorisation reference supplied by the company.',
    )
    corporate_document = models.ForeignKey(
        'corporate.CorporateDocument', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visits',
        help_text='Job card or verification document captured at reception.',
    )
    corporate_note = models.CharField(
        max_length=255, blank=True, default='',
        help_text='Outcome of the corporate verification checks.',
    )

    # ── Clinical summary ────────────────────────────────────────────────
    chief_complaint = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    lab_report = models.FileField(
        upload_to='visit_lab_reports/', null=True, blank=True,
        help_text='Optional scanned / PDF lab report uploaded by the laboratory.',
    )
    discharge_summary = models.TextField(blank=True)
    follow_up_date = models.DateField(null=True, blank=True)
    outcome = models.CharField(max_length=20, choices=Outcome.choices, blank=True, default='')

    # ── Stage timestamps ────────────────────────────────────────────────
    arrived_at = models.DateTimeField(default=timezone.now)
    registered_at = models.DateTimeField(null=True, blank=True)
    charged_at = models.DateTimeField(null=True, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    triage_started_at = models.DateTimeField(null=True, blank=True)
    triage_completed_at = models.DateTimeField(null=True, blank=True)
    doctor_assigned_at = models.DateTimeField(null=True, blank=True)
    consultation_started_at = models.DateTimeField(null=True, blank=True)
    lab_ordered_at = models.DateTimeField(null=True, blank=True)
    lab_completed_at = models.DateTimeField(null=True, blank=True)
    review_started_at = models.DateTimeField(null=True, blank=True)
    prescribed_at = models.DateTimeField(null=True, blank=True)
    discharged_at = models.DateTimeField(null=True, blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visits_created',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-arrived_at']
        indexes = [
            models.Index(fields=['stage', 'arrived_at']),
            models.Index(fields=['patient', '-arrived_at']),
        ]

    def __str__(self):
        return f'{self.visit_number} · {self.patient} · {self.get_stage_display()}'

    # ── helpers ────────────────────────────────────────────────────────
    @property
    def is_open(self):
        return self.stage not in (self.Stage.DISCHARGED, self.Stage.CANCELLED)

    @property
    def waiting_minutes(self):
        """Minutes spent in the current stage (0 once closed)."""
        if not self.is_open:
            return 0
        anchor = self._stage_anchor()
        if not anchor:
            return 0
        return max(0, int((timezone.now() - anchor).total_seconds() // 60))

    def _stage_anchor(self):
        mapping = {
            self.Stage.ARRIVED: self.arrived_at,
            self.Stage.REGISTERED: self.registered_at,
            self.Stage.AWAITING_PAYMENT: self.charged_at,
            self.Stage.PAID: self.paid_at,
            self.Stage.TRIAGE: self.triage_started_at,
            self.Stage.AWAITING_DOCTOR: self.triage_completed_at,
            self.Stage.IN_CONSULTATION: self.consultation_started_at,
            self.Stage.IN_LAB: self.lab_ordered_at,
            self.Stage.LAB_READY: self.lab_completed_at,
            self.Stage.REVIEW: self.review_started_at,
            self.Stage.PRESCRIBED: self.prescribed_at,
        }
        return mapping.get(self.stage)

    def set_stage(self, stage, actor=None, note=''):
        """Move to a new stage, stamp the matching timestamp and log an event."""
        self.stage = stage
        now = timezone.now()
        stamps = {
            self.Stage.REGISTERED: 'registered_at',
            self.Stage.AWAITING_PAYMENT: 'charged_at',
            self.Stage.PAID: 'paid_at',
            self.Stage.TRIAGE: 'triage_started_at',
            self.Stage.AWAITING_DOCTOR: 'triage_completed_at',
            self.Stage.IN_CONSULTATION: 'consultation_started_at',
            self.Stage.IN_LAB: 'lab_ordered_at',
            self.Stage.LAB_READY: 'lab_completed_at',
            self.Stage.REVIEW: 'review_started_at',
            self.Stage.PRESCRIBED: 'prescribed_at',
            self.Stage.DISCHARGED: 'discharged_at',
        }
        field = stamps.get(stage)
        if field and not getattr(self, field):
            setattr(self, field, now)
        self.save()
        VisitEvent.objects.create(
            visit=self, stage=stage, action=stage,
            note=note, actor=actor,
        )
        return self


class VisitEvent(models.Model):
    """Append-only audit trail of everything that happened to a visit."""

    visit = models.ForeignKey(PatientVisit, on_delete=models.CASCADE, related_name='events')
    stage = models.CharField(max_length=30, choices=PatientVisit.Stage.choices)
    action = models.CharField(max_length=60)
    note = models.TextField(blank=True)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='visit_events',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f'{self.visit.visit_number} · {self.action}'


def next_visit_number():
    """Return ``(visit_number, queue_number)`` for today.

    Format: ``VD-20260121-007`` — the trailing counter doubles as the queue
    token shown on the front-desk board.
    """
    today = timezone.localdate()
    try:
        prefix = ClinicSettings.get_solo().visit_number_prefix or 'VD'
    except Exception:  # pragma: no cover - settings table not migrated yet
        prefix = 'VD'
    base = f'{prefix}-{today:%Y%m%d}-'
    last = (
        PatientVisit.objects
        .filter(visit_number__startswith=base)
        .order_by('-id')
        .values_list('visit_number', flat=True)
        .first()
    )
    seq = 1
    if last:
        tail = last.rsplit('-', 1)[-1]
        if tail.isdigit():
            seq = int(tail) + 1
    return f'{base}{seq:03d}', seq
