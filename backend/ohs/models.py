"""Occupational Health & Safety Management System (OHSMS) models.

Implements an ISO 45001-aligned safety management system inside the tenant
schema. The model graph mirrors the standard's clauses:

    Clause 6  Planning ............ Site, HazardCategory, Hazard, RiskAssessment,
                                   RiskAssessmentItem, ControlMeasure, LegalRequirement
    Clause 7  Support ............. TrainingCourse, TrainingRecord, PpeItem, PpeIssue,
                                   HealthSurveillance
    Clause 8  Operation ........... Inspection, InspectionItem, PermitToWork,
                                   Observation, ExposureMonitoring, EmergencyDrill
    Clause 9  Evaluation .......... Incident, IncidentAction, ComplianceAudit,
                                   SafetyObjective

Every model is tenant-scoped (django-tenants) so each business has an isolated
safety register.
"""
from datetime import date, timedelta
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


# ─────────────────────────────────────────────────────────────────────────
#  RBAC: tenant-managed role definitions (Roles & Access page)
# ─────────────────────────────────────────────────────────────────────────
class OhsRoleDefinition(TimeStampedModel):
    """A tenant-managed role definition for the OHSMS module.

    * custom roles (``is_system=False``): tenant-created roles with an
      explicit capability list;
    * built-in overrides (``is_system=True``): a tenant's customized
      capability list for a built-in role (e.g. a trimmed Safety Officer
      scope). ``key`` matches the built-in role key on ``User.role``.
      Deleting the row restores the platform defaults in ``ohs/rbac.py``.

    ``key`` is stored on ``User.role`` so it must stay short (max 20 chars)
    and cannot collide with the reserved keys enforced in ``ohs.rbac``.
    """

    key = models.SlugField(max_length=20, unique=True)
    label = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    icon = models.CharField(
        max_length=60, default='mdi-badge-account-horizontal-outline',
    )
    capabilities = models.JSONField(
        default=list, help_text='List of capability keys (see ohs/rbac.py)',
    )
    is_system = models.BooleanField(
        default=False, help_text='True = capability override for a built-in role',
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['label']
        verbose_name = 'OHS role definition'
        verbose_name_plural = 'OHS role definitions'

    def __str__(self):
        return f'{self.label} ({len(self.capabilities or [])} capabilities)'


# ─────────────────────────────────────────────────────────────────────────
#  5-×-5 risk scoring helpers
# ─────────────────────────────────────────────────────────────────────────
def risk_band(score):
    """Map a 1-25 risk score onto an ISO-style band."""
    if score is None:
        return 'unrated'
    if score >= 20:
        return 'critical'
    if score >= 15:
        return 'high'
    if score >= 8:
        return 'medium'
    if score >= 4:
        return 'low'
    return 'negligible'


RISK_BAND_CHOICES = [
    ('negligible', 'Negligible'),
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
    ('critical', 'Critical'),
    ('unrated', 'Unrated'),
]


class RiskScoredMixin(models.Model):
    """Shared severity × likelihood scoring for hazards and assessment lines."""

    severity = models.PositiveSmallIntegerField(default=3, help_text='1 (negligible) – 5 (catastrophic)')
    likelihood = models.PositiveSmallIntegerField(default=3, help_text='1 (rare) – 5 (almost certain)')

    residual_severity = models.PositiveSmallIntegerField(null=True, blank=True)
    residual_likelihood = models.PositiveSmallIntegerField(null=True, blank=True)

    class Meta:
        abstract = True

    @staticmethod
    def _score(sev, lik):
        if not sev or not lik:
            return None
        return int(sev) * int(lik)

    @property
    def risk_score(self):
        return self._score(self.severity, self.likelihood)

    @property
    def risk_level(self):
        return risk_band(self.risk_score)

    @property
    def residual_score(self):
        return self._score(self.residual_severity, self.residual_likelihood)

    @property
    def residual_level(self):
        return risk_band(self.residual_score)


# ─────────────────────────────────────────────────────────────────────────
#  Sites (organisational context)
# ─────────────────────────────────────────────────────────────────────────
class Site(TimeStampedModel):
    class SiteType(models.TextChoices):
        OFFICE = 'office', 'Office'
        WAREHOUSE = 'warehouse', 'Warehouse'
        FACTORY = 'factory', 'Factory / Plant'
        CONSTRUCTION = 'construction', 'Construction site'
        LABORATORY = 'laboratory', 'Laboratory'
        CLINIC = 'clinic', 'Clinic'
        FUEL_STATION = 'fuel_station', 'Fuel station'
        FARM = 'farm', 'Farm'
        MINE = 'mine', 'Mine / Quarry'
        OTHER = 'other', 'Other'

    class RiskProfile(models.TextChoices):
        LOW = 'low', 'Low hazard'
        MEDIUM = 'medium', 'Medium hazard'
        HIGH = 'high', 'High hazard'
        SEVERE = 'severe', 'Severe hazard'

    name = models.CharField(max_length=160, unique=True)
    code = models.CharField(max_length=24, blank=True)
    site_type = models.CharField(max_length=24, choices=SiteType.choices, default=SiteType.OFFICE)
    risk_profile = models.CharField(
        max_length=10, choices=RiskProfile.choices, default=RiskProfile.MEDIUM,
    )
    address = models.TextField(blank=True)
    county = models.CharField(max_length=80, blank=True)
    site_manager = models.CharField(max_length=160, blank=True)
    manager_phone = models.CharField(max_length=30, blank=True)
    headcount = models.PositiveIntegerField(default=0)
    annual_hours_worked = models.PositiveIntegerField(
        default=0,
        help_text='Total person-hours worked per year. 0 = derive from headcount × 2,000 h.',
    )
    emergency_assembly_point = models.CharField(max_length=160, blank=True)
    first_aider_count = models.PositiveSmallIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

    @property
    def hours_worked(self):
        return self.annual_hours_worked or (self.headcount * 2000)


# ─────────────────────────────────────────────────────────────────────────
#  Hazards & risk register
# ─────────────────────────────────────────────────────────────────────────
class HazardCategory(TimeStampedModel):
    name = models.CharField(max_length=120, unique=True)
    code = models.CharField(max_length=16, blank=True)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=60, default='mdi-alert-outline')
    color = models.CharField(max_length=20, default='#f97316')
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['sort_order', 'name']
        verbose_name_plural = 'Hazard categories'

    def __str__(self):
        return self.name


class Hazard(RiskScoredMixin, TimeStampedModel):
    class HazardType(models.TextChoices):
        PHYSICAL = 'physical', 'Physical'
        CHEMICAL = 'chemical', 'Chemical'
        BIOLOGICAL = 'biological', 'Biological'
        ERGONOMIC = 'ergonomic', 'Ergonomic'
        PSYCHOSOCIAL = 'psychosocial', 'Psychosocial'
        ELECTRICAL = 'electrical', 'Electrical'
        MECHANICAL = 'mechanical', 'Mechanical'
        FIRE = 'fire', 'Fire & explosion'
        ENVIRONMENTAL = 'environmental', 'Environmental'
        WORK_AT_HEIGHT = 'work_at_height', 'Work at height'
        CONFINED_SPACE = 'confined_space', 'Confined space'
        VEHICLE = 'vehicle', 'Vehicle & traffic'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        CONTROLLED = 'controlled', 'Controlled'
        MONITORING = 'monitoring', 'Monitoring'
        CLOSED = 'closed', 'Closed'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    title = models.CharField(max_length=220)
    description = models.TextField(blank=True)
    hazard_type = models.CharField(
        max_length=24, choices=HazardType.choices, default=HazardType.PHYSICAL,
    )
    category = models.ForeignKey(
        HazardCategory, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='hazards',
    )
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='hazards')
    area = models.CharField(max_length=160, blank=True, help_text='Work area / process')
    activity = models.CharField(max_length=220, blank=True, help_text='Task or activity where it arises')
    exposed_persons = models.CharField(max_length=220, blank=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.OPEN)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='owned_hazards',
    )
    owner_name = models.CharField(max_length=160, blank=True)
    identified_on = models.DateField(default=date.today)
    next_review_on = models.DateField(null=True, blank=True)
    legal_reference = models.CharField(max_length=220, blank=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f'{self.reference or "HAZ"} · {self.title}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'HAZ-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'


class ControlMeasure(TimeStampedModel):
    class Hierarchy(models.TextChoices):
        ELIMINATION = 'elimination', 'Elimination'
        SUBSTITUTION = 'substitution', 'Substitution'
        ENGINEERING = 'engineering', 'Engineering control'
        ADMINISTRATIVE = 'administrative', 'Administrative control'
        PPE = 'ppe', 'PPE'

    class Status(models.TextChoices):
        PLANNED = 'planned', 'Planned'
        IN_PROGRESS = 'in_progress', 'In progress'
        IMPLEMENTED = 'implemented', 'Implemented'
        VERIFIED = 'verified', 'Verified'
        OVERDUE = 'overdue', 'Overdue'

    hazard = models.ForeignKey(Hazard, on_delete=models.CASCADE, related_name='controls')
    hierarchy = models.CharField(
        max_length=20, choices=Hierarchy.choices, default=Hierarchy.ENGINEERING,
    )
    description = models.TextField()
    owner_name = models.CharField(max_length=160, blank=True)
    due_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PLANNED)
    effectiveness = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='1 (ineffective) – 5 (fully effective)',
    )
    verified_on = models.DateField(null=True, blank=True)
    verified_by = models.CharField(max_length=160, blank=True)

    class Meta:
        ordering = ['due_date', 'id']

    def __str__(self):
        return f'{self.get_hierarchy_display()} · {self.hazard_id}'

    @property
    def is_overdue(self):
        if not self.due_date:
            return False
        if self.status in (self.Status.IMPLEMENTED, self.Status.VERIFIED):
            return False
        return self.due_date < date.today()


class RiskAssessment(TimeStampedModel):
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        IN_REVIEW = 'in_review', 'In review'
        APPROVED = 'approved', 'Approved'
        EXPIRED = 'expired', 'Expired'
        ARCHIVED = 'archived', 'Archived'

    class Methodology(models.TextChoices):
        FIVE_BY_FIVE = '5x5', '5 × 5 matrix'
        HAZOP = 'hazop', 'HAZOP'
        HIRA = 'hira', 'HIRA'
        JSA = 'jsa', 'Job safety analysis'
        FMEA = 'fmea', 'FMEA'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    title = models.CharField(max_length=220)
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='risk_assessments')
    scope = models.TextField(blank=True)
    methodology = models.CharField(
        max_length=12, choices=Methodology.choices, default=Methodology.FIVE_BY_FIVE,
    )
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.DRAFT)
    assessor_name = models.CharField(max_length=160, blank=True)
    assessor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='risk_assessments',
    )
    assessment_date = models.DateField(default=date.today)
    review_date = models.DateField(null=True, blank=True)
    approved_by = models.CharField(max_length=160, blank=True)
    approved_at = models.DateTimeField(null=True, blank=True)
    summary = models.TextField(blank=True)

    class Meta:
        ordering = ['-assessment_date', '-id']

    def __str__(self):
        return f'{self.reference or "RA"} · {self.title}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'RA-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'

    @property
    def highest_score(self):
        agg = self.items.aggregate(m=models.Max(models.F('severity') * models.F('likelihood')))
        return agg['m'] or 0

    @property
    def is_review_due(self):
        return bool(self.review_date and self.review_date <= date.today())


class RiskAssessmentItem(RiskScoredMixin, TimeStampedModel):
    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        IN_PROGRESS = 'in_progress', 'In progress'
        CLOSED = 'closed', 'Closed'

    assessment = models.ForeignKey(
        RiskAssessment, on_delete=models.CASCADE, related_name='items',
    )
    hazard_text = models.CharField(max_length=220)
    activity = models.CharField(max_length=220, blank=True)
    consequence = models.CharField(max_length=220, blank=True)
    existing_controls = models.TextField(blank=True)
    additional_controls = models.TextField(blank=True)
    responsible = models.CharField(max_length=160, blank=True)
    due_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.OPEN)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['sort_order', 'id']

    def __str__(self):
        return self.hazard_text


# ─────────────────────────────────────────────────────────────────────────
#  Incidents & CAPA
# ─────────────────────────────────────────────────────────────────────────
class Incident(TimeStampedModel):
    class IncidentType(models.TextChoices):
        INJURY = 'injury', 'Injury'
        ILLNESS = 'illness', 'Occupational illness'
        NEAR_MISS = 'near_miss', 'Near miss'
        PROPERTY_DAMAGE = 'property_damage', 'Property damage'
        ENVIRONMENTAL = 'environmental', 'Environmental release'
        FIRE = 'fire', 'Fire / explosion'
        SECURITY = 'security', 'Security'
        VEHICLE = 'vehicle', 'Vehicle incident'

    class Severity(models.TextChoices):
        FIRST_AID = 'first_aid', 'First aid only'
        MINOR = 'minor', 'Minor'
        MODERATE = 'moderate', 'Moderate'
        MAJOR = 'major', 'Major'
        CRITICAL = 'critical', 'Critical'
        FATALITY = 'fatality', 'Fatality'

    class Status(models.TextChoices):
        REPORTED = 'reported', 'Reported'
        INVESTIGATING = 'investigating', 'Investigating'
        ACTIONS = 'actions', 'Actions open'
        CLOSED = 'closed', 'Closed'

    class CauseCategory(models.TextChoices):
        UNSAFE_ACT = 'unsafe_act', 'Unsafe act'
        UNSAFE_CONDITION = 'unsafe_condition', 'Unsafe condition'
        PROCEDURE = 'procedure', 'Procedure gap'
        TRAINING = 'training', 'Training gap'
        EQUIPMENT = 'equipment', 'Equipment failure'
        SUPERVISION = 'supervision', 'Supervision'
        HOUSEKEEPING = 'housekeeping', 'Housekeeping'
        OTHER = 'other', 'Other'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    title = models.CharField(max_length=220)
    incident_type = models.CharField(
        max_length=20, choices=IncidentType.choices, default=IncidentType.INJURY,
    )
    severity = models.CharField(max_length=12, choices=Severity.choices, default=Severity.MINOR)
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='incidents')
    location = models.CharField(max_length=180, blank=True)
    department = models.CharField(max_length=120, blank=True)
    occurred_at = models.DateTimeField(default=timezone.now)
    reported_at = models.DateTimeField(default=timezone.now)
    person_involved = models.CharField(max_length=160, blank=True)
    person_role = models.CharField(max_length=120, blank=True)
    description = models.TextField(blank=True)
    immediate_action = models.TextField(blank=True)
    root_cause = models.TextField(blank=True)
    cause_category = models.CharField(
        max_length=20, choices=CauseCategory.choices, blank=True,
    )
    is_recordable = models.BooleanField(
        default=False, help_text='Recordable / reportable to the regulator.',
    )
    is_lost_time = models.BooleanField(default=False, help_text='Resulted in lost work days.')
    lost_days = models.PositiveSmallIntegerField(default=0)
    days_away = models.PositiveSmallIntegerField(default=0)
    cost_estimate = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(max_length=14, choices=Status.choices, default=Status.REPORTED)
    reported_by = models.CharField(max_length=160, blank=True)
    investigator = models.CharField(max_length=160, blank=True)
    regulator_notified = models.BooleanField(default=False)
    closed_at = models.DateTimeField(null=True, blank=True)
    witness_statements = models.TextField(blank=True)

    class Meta:
        ordering = ['-occurred_at']

    def __str__(self):
        return f'{self.reference or "INC"} · {self.title}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'INC-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'

    @property
    def days_open(self):
        end = self.closed_at or timezone.now()
        return max((end - self.occurred_at).days, 0)


class IncidentAction(TimeStampedModel):
    class ActionType(models.TextChoices):
        CONTAINMENT = 'containment', 'Containment'
        CORRECTIVE = 'corrective', 'Corrective'
        PREVENTIVE = 'preventive', 'Preventive'
        TRAINING = 'training', 'Training'
        ENGINEERING = 'engineering', 'Engineering change'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        IN_PROGRESS = 'in_progress', 'In progress'
        DONE = 'done', 'Done'
        VERIFIED = 'verified', 'Verified'

    incident = models.ForeignKey(Incident, on_delete=models.CASCADE, related_name='actions')
    action_type = models.CharField(
        max_length=14, choices=ActionType.choices, default=ActionType.CORRECTIVE,
    )
    description = models.TextField()
    owner_name = models.CharField(max_length=160, blank=True)
    due_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=14, choices=Status.choices, default=Status.OPEN)
    completed_at = models.DateField(null=True, blank=True)
    verification_note = models.TextField(blank=True)

    class Meta:
        ordering = ['due_date', 'id']

    def __str__(self):
        return self.description[:60]

    @property
    def is_overdue(self):
        if not self.due_date or self.status in (self.Status.DONE, self.Status.VERIFIED):
            return False
        return self.due_date < date.today()


# ─────────────────────────────────────────────────────────────────────────
#  Inspections
# ─────────────────────────────────────────────────────────────────────────
class Inspection(TimeStampedModel):
    class InspectionType(models.TextChoices):
        ROUTINE = 'routine', 'Routine walkdown'
        PLANNED = 'planned', 'Planned inspection'
        SURPRISE = 'surprise', 'Surprise / spot check'
        STATUTORY = 'statutory', 'Statutory inspection'
        AUDIT = 'audit', 'Audit'

    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        IN_PROGRESS = 'in_progress', 'In progress'
        COMPLETED = 'completed', 'Completed'
        OVERDUE = 'overdue', 'Overdue'
        CANCELLED = 'cancelled', 'Cancelled'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    title = models.CharField(max_length=220)
    inspection_type = models.CharField(
        max_length=14, choices=InspectionType.choices, default=InspectionType.ROUTINE,
    )
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='inspections')
    area = models.CharField(max_length=180, blank=True)
    inspector_name = models.CharField(max_length=160, blank=True)
    scheduled_for = models.DateField(default=date.today)
    completed_on = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=14, choices=Status.choices, default=Status.SCHEDULED)
    score = models.PositiveSmallIntegerField(null=True, blank=True, help_text='0 – 100 compliance score')
    summary = models.TextField(blank=True)

    class Meta:
        ordering = ['-scheduled_for', '-id']

    def __str__(self):
        return f'{self.reference or "INS"} · {self.title}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'INS-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'

    @property
    def findings_count(self):
        return self.items.exclude(result='pass').count()

    @property
    def critical_findings(self):
        return self.items.filter(result='fail', severity='critical').count()


class InspectionItem(TimeStampedModel):
    class Result(models.TextChoices):
        PASS = 'pass', 'Pass'
        FAIL = 'fail', 'Fail'
        OBSERVATION = 'observation', 'Observation'
        NA = 'na', 'N/A'

    class Severity(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    inspection = models.ForeignKey(
        Inspection, on_delete=models.CASCADE, related_name='items',
    )
    checklist_item = models.CharField(max_length=260)
    category = models.CharField(max_length=120, blank=True)
    result = models.CharField(max_length=12, choices=Result.choices, default=Result.PASS)
    severity = models.CharField(max_length=10, choices=Severity.choices, default=Severity.LOW)
    notes = models.TextField(blank=True)
    corrective_action = models.TextField(blank=True)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['sort_order', 'id']

    def __str__(self):
        return self.checklist_item[:60]


# ─────────────────────────────────────────────────────────────────────────
#  Permits to work
# ─────────────────────────────────────────────────────────────────────────
class PermitToWork(TimeStampedModel):
    class PermitType(models.TextChoices):
        HOT_WORK = 'hot_work', 'Hot work'
        CONFINED_SPACE = 'confined_space', 'Confined space entry'
        HEIGHT = 'height', 'Work at height'
        ELECTRICAL = 'electrical', 'Electrical / LOTO'
        LIFTING = 'lifting', 'Lifting operations'
        EXCAVATION = 'excavation', 'Excavation'
        CHEMICAL = 'chemical', 'Chemical handling'
        GENERAL = 'general', 'General work'

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        PENDING = 'pending', 'Pending approval'
        APPROVED = 'approved', 'Approved'
        ACTIVE = 'active', 'Active'
        SUSPENDED = 'suspended', 'Suspended'
        CLOSED = 'closed', 'Closed'
        EXPIRED = 'expired', 'Expired'
        REJECTED = 'rejected', 'Rejected'

    class RiskLevel(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    permit_type = models.CharField(
        max_length=16, choices=PermitType.choices, default=PermitType.GENERAL,
    )
    title = models.CharField(max_length=220)
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='permits')
    area = models.CharField(max_length=180, blank=True)
    description = models.TextField(blank=True)
    requested_by = models.CharField(max_length=160, blank=True)
    issued_by = models.CharField(max_length=160, blank=True)
    approved_by = models.CharField(max_length=160, blank=True)
    valid_from = models.DateTimeField(default=timezone.now)
    valid_to = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.DRAFT)
    risk_level = models.CharField(
        max_length=10, choices=RiskLevel.choices, default=RiskLevel.MEDIUM,
    )
    precautions = models.TextField(blank=True)
    ppe_required = models.CharField(max_length=260, blank=True)
    isolations = models.TextField(blank=True)
    gas_test_required = models.BooleanField(default=False)
    workers_count = models.PositiveSmallIntegerField(default=1)
    closed_at = models.DateTimeField(null=True, blank=True)
    closure_note = models.TextField(blank=True)

    class Meta:
        ordering = ['-valid_from']

    def __str__(self):
        return f'{self.reference or "PTW"} · {self.title}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'PTW-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'

    @property
    def is_expired(self):
        return bool(self.valid_to and self.valid_to < timezone.now()
                    and self.status in (self.Status.ACTIVE, self.Status.APPROVED))


# ─────────────────────────────────────────────────────────────────────────
#  Training & competence
# ─────────────────────────────────────────────────────────────────────────
class TrainingCourse(TimeStampedModel):
    class Category(models.TextChoices):
        INDUCTION = 'induction', 'Induction'
        TECHNICAL = 'technical', 'Technical / task'
        LEGAL = 'legal', 'Statutory / legal'
        EMERGENCY = 'emergency', 'Emergency response'
        SOFT = 'soft', 'Safety leadership'

    name = models.CharField(max_length=200, unique=True)
    code = models.CharField(max_length=24, blank=True)
    category = models.CharField(
        max_length=12, choices=Category.choices, default=Category.TECHNICAL,
    )
    description = models.TextField(blank=True)
    is_mandatory = models.BooleanField(default=False)
    validity_months = models.PositiveSmallIntegerField(
        default=0, help_text='0 = no expiry',
    )
    provider = models.CharField(max_length=200, blank=True)
    duration_hours = models.DecimalField(max_digits=5, decimal_places=1, default=0)
    cost_per_person = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class TrainingRecord(TimeStampedModel):
    class Result(models.TextChoices):
        PASS = 'pass', 'Pass'
        FAIL = 'fail', 'Fail'
        PENDING = 'pending', 'Pending'

    course = models.ForeignKey(
        TrainingCourse, on_delete=models.CASCADE, related_name='records',
    )
    employee_name = models.CharField(max_length=160)
    employee_ref = models.CharField(max_length=60, blank=True)
    site = models.ForeignKey(
        Site, on_delete=models.CASCADE, null=True, blank=True, related_name='training_records',
    )
    completed_on = models.DateField(null=True, blank=True)
    expires_on = models.DateField(null=True, blank=True)
    result = models.CharField(max_length=10, choices=Result.choices, default=Result.PASS)
    score = models.PositiveSmallIntegerField(null=True, blank=True)
    certificate_ref = models.CharField(max_length=80, blank=True)
    trainer = models.CharField(max_length=160, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-completed_on', '-id']

    def __str__(self):
        return f'{self.employee_name} · {self.course_id}'

    @property
    def is_expired(self):
        return bool(self.expires_on and self.expires_on < date.today())

    @property
    def days_to_expiry(self):
        if not self.expires_on:
            return None
        return (self.expires_on - date.today()).days


# ─────────────────────────────────────────────────────────────────────────
#  PPE
# ─────────────────────────────────────────────────────────────────────────
class PpeItem(TimeStampedModel):
    class Category(models.TextChoices):
        HEAD = 'head', 'Head protection'
        EYE = 'eye', 'Eye & face'
        HEARING = 'hearing', 'Hearing'
        RESPIRATORY = 'respiratory', 'Respiratory'
        HAND = 'hand', 'Hand protection'
        FOOT = 'foot', 'Foot protection'
        BODY = 'body', 'Body protection'
        FALL = 'fall', 'Fall protection'
        HI_VIS = 'hi_vis', 'High visibility'

    name = models.CharField(max_length=180, unique=True)
    category = models.CharField(
        max_length=12, choices=Category.choices, default=Category.HEAD,
    )
    code = models.CharField(max_length=24, blank=True)
    sizes = models.CharField(max_length=120, blank=True, help_text='Comma separated sizes')
    unit = models.CharField(max_length=24, default='piece')
    stock_on_hand = models.PositiveIntegerField(default=0)
    reorder_level = models.PositiveIntegerField(default=10)
    unit_cost = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    replacement_months = models.PositiveSmallIntegerField(default=12)
    standard = models.CharField(max_length=80, blank=True, help_text='e.g. EN 397 / ANSI Z89.1')

    class Meta:
        ordering = ['name']
        verbose_name = 'PPE item'

    def __str__(self):
        return self.name

    @property
    def is_low_stock(self):
        return self.stock_on_hand <= self.reorder_level


class PpeIssue(TimeStampedModel):
    ppe_item = models.ForeignKey(PpeItem, on_delete=models.CASCADE, related_name='issues')
    employee_name = models.CharField(max_length=160)
    employee_ref = models.CharField(max_length=60, blank=True)
    site = models.ForeignKey(
        Site, on_delete=models.CASCADE, null=True, blank=True, related_name='ppe_issues',
    )
    quantity = models.PositiveSmallIntegerField(default=1)
    size = models.CharField(max_length=24, blank=True)
    issued_on = models.DateField(default=date.today)
    replacement_due = models.DateField(null=True, blank=True)
    returned_on = models.DateField(null=True, blank=True)
    condition = models.CharField(max_length=40, blank=True)
    acknowledged = models.BooleanField(default=False)

    class Meta:
        ordering = ['-issued_on', '-id']

    def __str__(self):
        return f'{self.employee_name} · {self.ppe_item_id}'


# ─────────────────────────────────────────────────────────────────────────
#  Occupational health surveillance
# ─────────────────────────────────────────────────────────────────────────
class HealthSurveillance(TimeStampedModel):
    class Programme(models.TextChoices):
        AUDIOMETRY = 'audiometry', 'Audiometry'
        SPIROMETRY = 'spirometry', 'Lung function'
        VISION = 'vision', 'Vision screening'
        BLOOD_LEAD = 'blood_lead', 'Biological monitoring'
        HAZMAT = 'hazmat', 'Hazardous substance'
        ERGONOMIC = 'ergonomic', 'Ergonomic assessment'
        GENERAL = 'general', 'General medical'

    class Result(models.TextChoices):
        FIT = 'fit', 'Fit for duty'
        CONDITIONAL = 'conditional', 'Fit with restrictions'
        UNFIT = 'unfit', 'Unfit'
        PENDING = 'pending', 'Pending'

    programme = models.CharField(
        max_length=14, choices=Programme.choices, default=Programme.GENERAL,
    )
    employee_name = models.CharField(max_length=160)
    employee_ref = models.CharField(max_length=60, blank=True)
    job_title = models.CharField(max_length=120, blank=True)
    site = models.ForeignKey(
        Site, on_delete=models.CASCADE, null=True, blank=True,
        related_name='health_surveillance',
    )
    scheduled_on = models.DateField(default=date.today)
    completed_on = models.DateField(null=True, blank=True)
    result = models.CharField(max_length=12, choices=Result.choices, default=Result.PENDING)
    restrictions = models.TextField(blank=True)
    provider = models.CharField(max_length=180, blank=True)
    next_due = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-scheduled_on']
        verbose_name_plural = 'Health surveillance'

    def __str__(self):
        return f'{self.employee_name} · {self.get_programme_display()}'

    @property
    def is_overdue(self):
        return self.result == self.Result.PENDING and self.scheduled_on < date.today()


# ─────────────────────────────────────────────────────────────────────────
#  Behaviour observations (safety culture)
# ─────────────────────────────────────────────────────────────────────────
class Observation(TimeStampedModel):
    class Kind(models.TextChoices):
        SAFE = 'safe', 'Safe behaviour'
        AT_RISK = 'at_risk', 'At-risk behaviour'
        CONDITION = 'condition', 'Unsafe condition'
        POSITIVE = 'positive', 'Positive practice'

    class Category(models.TextChoices):
        PPE = 'ppe', 'PPE use'
        POSITION = 'position', 'Body position'
        TOOLS = 'tools', 'Tools & equipment'
        PROCEDURE = 'procedure', 'Procedure adherence'
        HOUSEKEEPING = 'housekeeping', 'Housekeeping'
        LIFTING = 'lifting', 'Manual handling'
        DRIVING = 'driving', 'Driving'
        CHEMICAL = 'chemical', 'Chemical handling'

    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='observations')
    observer_name = models.CharField(max_length=160, blank=True)
    observed_person = models.CharField(max_length=160, blank=True)
    department = models.CharField(max_length=120, blank=True)
    kind = models.CharField(max_length=12, choices=Kind.choices, default=Kind.AT_RISK)
    category = models.CharField(max_length=16, choices=Category.choices, default=Category.PPE)
    description = models.TextField(blank=True)
    feedback_given = models.BooleanField(default=True)
    action_taken = models.TextField(blank=True)
    observed_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['-observed_at']

    def __str__(self):
        return f'{self.get_kind_display()} · {self.get_category_display()}'


# ─────────────────────────────────────────────────────────────────────────
#  Exposure monitoring
# ─────────────────────────────────────────────────────────────────────────
class ExposureMonitoring(TimeStampedModel):
    class Agent(models.TextChoices):
        NOISE = 'noise', 'Noise'
        DUST = 'dust', 'Respirable dust'
        VAPOUR = 'vapour', 'Organic vapour'
        HEAT = 'heat', 'Heat stress'
        VIBRATION = 'vibration', 'Hand-arm vibration'
        RADIATION = 'radiation', 'Ionising radiation'
        LIGHTING = 'lighting', 'Illumination'
        ERGONOMIC = 'ergonomic', 'Ergonomic load'

    class Result(models.TextChoices):
        COMPLIANT = 'compliant', 'Compliant'
        ACTION = 'action', 'Action level reached'
        EXCEEDED = 'exceeded', 'Limit exceeded'

    agent = models.CharField(max_length=14, choices=Agent.choices, default=Agent.NOISE)
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='exposure_readings')
    area = models.CharField(max_length=180, blank=True)
    measured_value = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    unit = models.CharField(max_length=24, default='dB(A)')
    oel_limit = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    measured_on = models.DateField(default=date.today)
    method = models.CharField(max_length=120, blank=True)
    result = models.CharField(max_length=12, choices=Result.choices, default=Result.COMPLIANT)
    lab_reference = models.CharField(max_length=80, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-measured_on']

    def __str__(self):
        return f'{self.get_agent_display()} · {self.measured_value} {self.unit}'

    @property
    def pct_of_limit(self):
        if not self.oel_limit:
            return None
        return round(float(self.measured_value) / float(self.oel_limit) * 100, 1)


# ─────────────────────────────────────────────────────────────────────────
#  Emergency preparedness
# ─────────────────────────────────────────────────────────────────────────
class EmergencyDrill(TimeStampedModel):
    class DrillType(models.TextChoices):
        FIRE = 'fire', 'Fire evacuation'
        CHEMICAL = 'chemical', 'Chemical spill'
        MEDICAL = 'medical', 'Medical emergency'
        EARTHQUAKE = 'earthquake', 'Earthquake'
        CONFINED_SPACE = 'confined_space', 'Confined space rescue'
        SECURITY = 'security', 'Security incident'
        POWER = 'power', 'Power failure'

    class Status(models.TextChoices):
        PLANNED = 'planned', 'Planned'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    drill_type = models.CharField(
        max_length=16, choices=DrillType.choices, default=DrillType.FIRE,
    )
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='drills')
    scheduled_on = models.DateField(default=date.today)
    conducted_on = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.PLANNED)
    participants = models.PositiveSmallIntegerField(default=0)
    duration_minutes = models.PositiveSmallIntegerField(default=0)
    evacuation_seconds = models.PositiveIntegerField(null=True, blank=True)
    scenario = models.TextField(blank=True)
    findings = models.TextField(blank=True)
    score = models.PositiveSmallIntegerField(null=True, blank=True)
    coordinator = models.CharField(max_length=160, blank=True)

    class Meta:
        ordering = ['-scheduled_on']

    def __str__(self):
        return f'{self.get_drill_type_display()} · {self.scheduled_on}'


# ─────────────────────────────────────────────────────────────────────────
#  Legal register & compliance
# ─────────────────────────────────────────────────────────────────────────
class LegalRequirement(TimeStampedModel):
    class Status(models.TextChoices):
        COMPLIANT = 'compliant', 'Compliant'
        PARTIAL = 'partial', 'Partially compliant'
        NON_COMPLIANT = 'non_compliant', 'Non-compliant'
        NOT_ASSESSED = 'not_assessed', 'Not assessed'

    reference = models.CharField(max_length=40, blank=True)
    standard = models.CharField(
        max_length=80, blank=True, help_text='e.g. ISO 45001, OSHA 2007, Factories Act',
    )
    clause = models.CharField(max_length=60, blank=True)
    title = models.CharField(max_length=260)
    description = models.TextField(blank=True)
    applies_to = models.CharField(max_length=180, blank=True)
    compliance_status = models.CharField(
        max_length=14, choices=Status.choices, default=Status.NOT_ASSESSED,
    )
    owner_name = models.CharField(max_length=160, blank=True)
    last_assessed_on = models.DateField(null=True, blank=True)
    next_review_on = models.DateField(null=True, blank=True)
    evidence = models.TextField(blank=True)
    gap_description = models.TextField(blank=True)

    class Meta:
        ordering = ['standard', 'clause', 'title']

    def __str__(self):
        return self.title

    @property
    def is_review_due(self):
        return bool(self.next_review_on and self.next_review_on <= date.today())


class ComplianceAudit(TimeStampedModel):
    class AuditType(models.TextChoices):
        INTERNAL = 'internal', 'Internal'
        EXTERNAL = 'external', 'External'
        CERTIFICATION = 'certification', 'Certification'
        SUPPLIER = 'supplier', 'Supplier'

    class Status(models.TextChoices):
        PLANNED = 'planned', 'Planned'
        IN_PROGRESS = 'in_progress', 'In progress'
        COMPLETED = 'completed', 'Completed'
        CLOSED = 'closed', 'Closed with actions'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    title = models.CharField(max_length=220)
    audit_type = models.CharField(
        max_length=16, choices=AuditType.choices, default=AuditType.INTERNAL,
    )
    standard = models.CharField(max_length=80, blank=True, default='ISO 45001:2018')
    site = models.ForeignKey(
        Site, on_delete=models.CASCADE, null=True, blank=True, related_name='audits',
    )
    scope = models.TextField(blank=True)
    auditor = models.CharField(max_length=180, blank=True)
    scheduled_on = models.DateField(default=date.today)
    completed_on = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=14, choices=Status.choices, default=Status.PLANNED)
    score = models.PositiveSmallIntegerField(null=True, blank=True)
    findings_major = models.PositiveSmallIntegerField(default=0)
    findings_minor = models.PositiveSmallIntegerField(default=0)
    observations = models.TextField(blank=True)
    summary = models.TextField(blank=True)

    class Meta:
        ordering = ['-scheduled_on']

    def __str__(self):
        return f'{self.reference or "AUD"} · {self.title}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'AUD-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'


# ─────────────────────────────────────────────────────────────────────────
#  Objectives & targets (clause 6.2)
# ─────────────────────────────────────────────────────────────────────────
class SafetyObjective(TimeStampedModel):
    class Status(models.TextChoices):
        ON_TRACK = 'on_track', 'On track'
        AT_RISK = 'at_risk', 'At risk'
        OFF_TRACK = 'off_track', 'Off track'
        ACHIEVED = 'achieved', 'Achieved'

    class Category(models.TextChoices):
        INCIDENT_REDUCTION = 'incident_reduction', 'Incident reduction'
        COMPLIANCE = 'compliance', 'Compliance'
        TRAINING = 'training', 'Training & competence'
        RISK = 'risk', 'Risk reduction'
        CULTURE = 'culture', 'Safety culture'
        HEALTH = 'health', 'Occupational health'

    title = models.CharField(max_length=220)
    description = models.TextField(blank=True)
    category = models.CharField(
        max_length=20, choices=Category.choices, default=Category.INCIDENT_REDUCTION,
    )
    site = models.ForeignKey(
        Site, on_delete=models.CASCADE, null=True, blank=True, related_name='objectives',
    )
    baseline_value = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    target_value = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    current_value = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    unit = models.CharField(max_length=24, blank=True)
    owner_name = models.CharField(max_length=160, blank=True)
    start_date = models.DateField(default=date.today)
    due_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.ON_TRACK)
    actions_plan = models.TextField(blank=True)

    class Meta:
        ordering = ['due_date', 'title']

    def __str__(self):
        return self.title

    @property
    def progress_pct(self):
        base = float(self.baseline_value or 0)
        target = float(self.target_value or 0)
        current = float(self.current_value or 0)
        span = target - base
        if span == 0:
            return 100.0 if current == target else 0.0
        pct = (current - base) / span * 100
        return max(0.0, min(round(pct, 1), 100.0))


# ─────────────────────────────────────────────────────────────────────────
#  Document control (ISO 45001 cl. 7.5) & SDS library
# ─────────────────────────────────────────────────────────────────────────
class Document(TimeStampedModel):
    class DocType(models.TextChoices):
        POLICY = 'policy', 'Policy'
        PROCEDURE = 'procedure', 'Procedure'
        WORK_INSTRUCTION = 'work_instruction', 'Work instruction'
        SDS = 'sds', 'Safety data sheet'
        FORM = 'form', 'Form'
        MANUAL = 'manual', 'Manual'
        EMERGENCY_PLAN = 'emergency_plan', 'Emergency plan'
        LEGAL = 'legal', 'Legal / licence'
        OTHER = 'other', 'Other'

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        IN_REVIEW = 'in_review', 'In review'
        APPROVED = 'approved', 'Approved'
        OBSOLETE = 'obsolete', 'Obsolete'

    class Classification(models.TextChoices):
        PUBLIC = 'public', 'Public'
        INTERNAL = 'internal', 'Internal'
        RESTRICTED = 'restricted', 'Restricted'
        CONFIDENTIAL = 'confidential', 'Confidential'

    reference = models.CharField(max_length=48, unique=True, blank=True)
    title = models.CharField(max_length=260)
    doc_type = models.CharField(max_length=20, choices=DocType.choices, default=DocType.PROCEDURE)
    classification = models.CharField(
        max_length=14, choices=Classification.choices, default=Classification.INTERNAL,
    )
    site = models.ForeignKey(
        Site, on_delete=models.SET_NULL, null=True, blank=True, related_name='documents',
    )
    version = models.CharField(max_length=20, default='1.0')
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.DRAFT)
    owner_name = models.CharField(max_length=160, blank=True)
    summary = models.TextField(blank=True)
    effective_date = models.DateField(null=True, blank=True)
    review_due = models.DateField(null=True, blank=True)
    file_url = models.URLField(blank=True, max_length=600)
    requires_acknowledgement = models.BooleanField(
        default=False, help_text='Workers must acknowledge they have read it.',
    )
    approved_by = models.CharField(max_length=160, blank=True)
    approved_at = models.DateTimeField(null=True, blank=True)
    tags = models.CharField(max_length=260, blank=True, help_text='Comma separated')
    # ── SDS-specific ──
    chemical_name = models.CharField(max_length=200, blank=True)
    hazard_class = models.CharField(max_length=200, blank=True)
    # ── Version control bookkeeping ──
    revision_count = models.PositiveSmallIntegerField(default=1)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f'{self.reference or "DOC"} · {self.title}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'DOC-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'

    @property
    def is_review_overdue(self):
        return bool(self.review_due and self.review_due <= date.today()
                    and self.status not in (self.Status.OBSOLETE, self.Status.DRAFT))

    @property
    def days_to_review(self):
        if not self.review_due:
            return None
        return (self.review_due - date.today()).days


class DocumentRevision(TimeStampedModel):
    document = models.ForeignKey(
        Document, on_delete=models.CASCADE, related_name='revisions',
    )
    version = models.CharField(max_length=20)
    change_summary = models.TextField(blank=True)
    revised_by = models.CharField(max_length=160, blank=True)
    revised_on = models.DateField(default=date.today)
    approved_by = models.CharField(max_length=160, blank=True)
    file_url = models.URLField(blank=True, max_length=600)

    class Meta:
        ordering = ['-revised_on', '-id']

    def __str__(self):
        return f'{self.document_id} v{self.version}'


class DocumentAcknowledgement(TimeStampedModel):
    document = models.ForeignKey(
        Document, on_delete=models.CASCADE, related_name='acknowledgements',
    )
    employee_name = models.CharField(max_length=160)
    employee_ref = models.CharField(max_length=60, blank=True)
    site = models.ForeignKey(
        Site, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='document_acknowledgements',
    )
    acknowledged_on = models.DateField(default=date.today)
    version_read = models.CharField(max_length=20, blank=True)

    class Meta:
        ordering = ['-acknowledged_on']

    def __str__(self):
        return f'{self.employee_name} · {self.document_id}'


# ─────────────────────────────────────────────────────────────────────────
#  Contractor safety management
# ─────────────────────────────────────────────────────────────────────────
class Contractor(TimeStampedModel):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending pre-qualification'
        APPROVED = 'approved', 'Approved'
        SUSPENDED = 'suspended', 'Suspended'
        EXPIRED = 'expired', 'Documents expired'
        BLACKLISTED = 'blacklisted', 'Blacklisted'

    class Trade(models.TextChoices):
        CIVIL = 'civil', 'Civil / construction'
        ELECTRICAL = 'electrical', 'Electrical'
        MECHANICAL = 'mechanical', 'Mechanical'
        SCAFFOLDING = 'scaffolding', 'Scaffolding'
        CLEANING = 'cleaning', 'Cleaning & waste'
        LOGISTICS = 'logistics', 'Logistics'
        CATERING = 'catering', 'Catering'
        SECURITY = 'security', 'Security'
        IT = 'it', 'IT & telecoms'
        OTHER = 'other', 'Other'

    class RiskRating(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'

    name = models.CharField(max_length=220, unique=True)
    registration_no = models.CharField(max_length=80, blank=True)
    trade = models.CharField(max_length=20, choices=Trade.choices, default=Trade.OTHER)
    status = models.CharField(max_length=14, choices=Status.choices, default=Status.PENDING)
    risk_rating = models.CharField(
        max_length=10, choices=RiskRating.choices, default=RiskRating.MEDIUM,
    )
    contact_person = models.CharField(max_length=160, blank=True)
    phone = models.CharField(max_length=40, blank=True)
    email = models.EmailField(blank=True)
    # Compliance documents
    prequalified_on = models.DateField(null=True, blank=True)
    insurance_expiry = models.DateField(null=True, blank=True)
    safety_file_expiry = models.DateField(null=True, blank=True)
    induction_valid_until = models.DateField(null=True, blank=True)
    licence_expiry = models.DateField(null=True, blank=True)
    # Performance
    performance_score = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='0 – 100 safety performance score',
    )
    incidents_attributed = models.PositiveSmallIntegerField(default=0)
    observations_logged = models.PositiveSmallIntegerField(default=0)
    workers_count = models.PositiveSmallIntegerField(default=0)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

    def _days_to(self, target):
        if not target:
            return None
        return (target - date.today()).days

    @property
    def insurance_days(self):
        return self._days_to(self.insurance_expiry)

    @property
    def safety_file_days(self):
        return self._days_to(self.safety_file_expiry)

    @property
    def induction_days(self):
        return self._days_to(self.induction_valid_until)

    @property
    def licence_days(self):
        return self._days_to(self.licence_expiry)

    @property
    def expired_documents(self):
        checks = [
            self.insurance_expiry, self.safety_file_expiry,
            self.induction_valid_until, self.licence_expiry,
        ]
        return sum(1 for d in checks if d and d < date.today())

    @property
    def expiring_documents(self):
        today = date.today()
        checks = [
            self.insurance_expiry, self.safety_file_expiry,
            self.induction_valid_until, self.licence_expiry,
        ]
        return sum(1 for d in checks if d and today <= d <= today + timedelta(days=30))

    @property
    def compliance_pct(self):
        checks = [
            self.insurance_expiry, self.safety_file_expiry,
            self.induction_valid_until, self.licence_expiry,
        ]
        present = [d for d in checks if d]
        if not present:
            return 100
        valid = sum(1 for d in present if d >= date.today())
        return round(valid / len(present) * 100)


class ContractorEngagement(TimeStampedModel):
    class Status(models.TextChoices):
        PLANNED = 'planned', 'Planned'
        ACTIVE = 'active', 'Active on site'
        COMPLETED = 'completed', 'Completed'
        TERMINATED = 'terminated', 'Terminated'

    contractor = models.ForeignKey(
        Contractor, on_delete=models.CASCADE, related_name='engagements',
    )
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name='contractor_engagements')
    scope = models.CharField(max_length=260, blank=True)
    supervisor_name = models.CharField(max_length=160, blank=True)
    start_date = models.DateField(default=date.today)
    end_date = models.DateField(null=True, blank=True)
    workers_on_site = models.PositiveSmallIntegerField(default=0)
    hours_worked = models.PositiveIntegerField(default=0)
    induction_completed = models.BooleanField(default=False)
    permit_required = models.BooleanField(default=False)
    ppe_provided = models.BooleanField(default=False)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.PLANNED)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-start_date']

    def __str__(self):
        return f'{self.contractor_id} @ {self.site_id}'

    @property
    def is_overrun(self):
        return bool(self.end_date and self.end_date < date.today()
                    and self.status == self.Status.ACTIVE)


# ─────────────────────────────────────────────────────────────────────────
#  Safety committee, toolbox talks & inductions
# ─────────────────────────────────────────────────────────────────────────
class SafetyMeeting(TimeStampedModel):
    class MeetingType(models.TextChoices):
        COMMITTEE = 'committee', 'Safety committee'
        TOOLBOX = 'toolbox', 'Toolbox talk'
        INDUCTION = 'induction', 'Site induction'
        PRE_JOB = 'pre_job', 'Pre-job briefing'
        MANAGEMENT = 'management', 'Management meeting'

    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    title = models.CharField(max_length=260)
    meeting_type = models.CharField(
        max_length=14, choices=MeetingType.choices, default=MeetingType.TOOLBOX,
    )
    site = models.ForeignKey(
        Site, on_delete=models.CASCADE, null=True, blank=True, related_name='meetings',
    )
    meeting_date = models.DateField(default=date.today)
    start_time = models.TimeField(null=True, blank=True)
    duration_minutes = models.PositiveSmallIntegerField(default=30)
    chairperson = models.CharField(max_length=160, blank=True)
    location = models.CharField(max_length=180, blank=True)
    agenda = models.TextField(blank=True)
    topics_covered = models.CharField(max_length=400, blank=True)
    minutes = models.TextField(blank=True)
    decisions = models.TextField(blank=True)
    attendees_count = models.PositiveSmallIntegerField(default=0)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.SCHEDULED)
    next_meeting_on = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ['-meeting_date', '-id']

    def __str__(self):
        return self.title

    @property
    def is_overdue(self):
        return self.status == self.Status.SCHEDULED and self.meeting_date < date.today()

    @property
    def attendance_pct(self):
        rows = list(self.attendance.all())
        if not rows:
            return 0
        return round(sum(1 for r in rows if r.present) / len(rows) * 100)


class MeetingAttendance(TimeStampedModel):
    meeting = models.ForeignKey(
        SafetyMeeting, on_delete=models.CASCADE, related_name='attendance',
    )
    employee_name = models.CharField(max_length=160)
    employee_ref = models.CharField(max_length=60, blank=True)
    role = models.CharField(max_length=120, blank=True)
    present = models.BooleanField(default=True)
    signed = models.BooleanField(default=False)

    class Meta:
        ordering = ['employee_name']

    def __str__(self):
        return self.employee_name


# ─────────────────────────────────────────────────────────────────────────
#  Management review (ISO 45001 cl. 9.3)
# ─────────────────────────────────────────────────────────────────────────
class ManagementReview(TimeStampedModel):
    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        IN_PROGRESS = 'in_progress', 'In progress'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class Outcome(models.TextChoices):
        EFFECTIVE = 'effective', 'System effective'
        IMPROVEMENT = 'improvement', 'Improvements required'
        INADEQUATE = 'inadequate', 'Not adequate'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    title = models.CharField(max_length=260)
    review_date = models.DateField(default=date.today)
    period_from = models.DateField(null=True, blank=True)
    period_to = models.DateField(null=True, blank=True)
    chairperson = models.CharField(max_length=160, blank=True)
    participants = models.TextField(blank=True, help_text='Comma separated attendees')
    agenda = models.TextField(blank=True)
    inputs = models.TextField(blank=True, help_text='Clause 9.3.2 inputs considered')
    outputs = models.TextField(blank=True, help_text='Clause 9.3.3 decisions & actions')
    decisions = models.TextField(blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.SCHEDULED)
    outcome = models.CharField(max_length=12, choices=Outcome.choices, blank=True)
    next_review_on = models.DateField(null=True, blank=True)
    kpi_snapshot = models.JSONField(
        default=dict, blank=True, help_text='KPI values captured at review time',
    )

    class Meta:
        ordering = ['-review_date']
        verbose_name = 'Management review'

    def __str__(self):
        return f'{self.reference or "MR"} · {self.title}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'MR-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'


# ─────────────────────────────────────────────────────────────────────────
#  Certifications & licences register
# ─────────────────────────────────────────────────────────────────────────
class Certification(TimeStampedModel):
    class CertType(models.TextChoices):
        ISO = 'iso', 'ISO certification'
        LICENSE = 'license', 'Operating licence'
        STATUTORY = 'statutory', 'Statutory approval'
        EQUIPMENT = 'equipment', 'Equipment inspection'
        PERSONNEL = 'personnel', 'Personnel certification'
        INSURANCE = 'insurance', 'Insurance / cover'
        MEMBERSHIP = 'membership', 'Professional membership'

    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        EXPIRING = 'expiring', 'Expiring soon'
        EXPIRED = 'expired', 'Expired'
        SUSPENDED = 'suspended', 'Suspended'
        PENDING = 'pending', 'Pending renewal'

    name = models.CharField(max_length=260)
    cert_type = models.CharField(max_length=14, choices=CertType.choices, default=CertType.LICENSE)
    reference_no = models.CharField(max_length=120, blank=True)
    issuing_body = models.CharField(max_length=220, blank=True)
    holder_name = models.CharField(max_length=200, blank=True)
    site = models.ForeignKey(
        Site, on_delete=models.SET_NULL, null=True, blank=True, related_name='certifications',
    )
    issued_on = models.DateField(null=True, blank=True)
    expires_on = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.ACTIVE)
    document_url = models.URLField(blank=True, max_length=600)
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    renewal_lead_days = models.PositiveSmallIntegerField(
        default=60, help_text='Alert this many days before expiry',
    )
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['expires_on', 'name']

    def __str__(self):
        return self.name

    @property
    def days_to_expiry(self):
        if not self.expires_on:
            return None
        return (self.expires_on - date.today()).days

    @property
    def is_expired(self):
        return bool(self.expires_on and self.expires_on < date.today())

    @property
    def is_expiring(self):
        if not self.expires_on:
            return False
        days = self.days_to_expiry
        return 0 <= days <= (self.renewal_lead_days or 60)


# ─────────────────────────────────────────────────────────────────────────
#  Safety equipment management
#  (Clause 8.1 — physical controls: fire fighting, respiratory, fall arrest,
#   gas detection, lifting gear, LOTO, first aid … with statutory inspection
#   and calibration registers plus a defect / work-order log.)
# ─────────────────────────────────────────────────────────────────────────
class SafetyEquipment(TimeStampedModel):
    class Category(models.TextChoices):
        FIRE = 'fire', 'Fire fighting'
        DETECTION = 'detection', 'Detection & alarm'
        RESPIRATORY = 'respiratory', 'Respiratory / SCBA'
        FALL = 'fall', 'Fall protection'
        GAS = 'gas', 'Gas detection'
        FIRST_AID = 'first_aid', 'First aid & AED'
        EYEWASH = 'eyewash', 'Eyewash & safety shower'
        SPILL = 'spill', 'Spill containment'
        LOTO = 'loto', 'Lock-out / tag-out'
        LIFTING = 'lifting', 'Lifting & rigging'
        PRESSURE = 'pressure', 'Pressure equipment'
        ELECTRICAL = 'electrical', 'Electrical safety'
        RESCUE = 'rescue', 'Rescue & evacuation'
        MONITORING = 'monitoring', 'Monitoring instruments'
        OTHER = 'other', 'Other'

    class Status(models.TextChoices):
        IN_SERVICE = 'in_service', 'In service'
        MAINTENANCE = 'maintenance', 'Under maintenance'
        QUARANTINE = 'quarantine', 'Quarantined'
        OUT_OF_SERVICE = 'out_of_service', 'Out of service'
        DECOMMISSIONED = 'decommissioned', 'Decommissioned'

    class Criticality(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    name = models.CharField(max_length=220)
    category = models.CharField(
        max_length=14, choices=Category.choices, default=Category.OTHER,
    )
    status = models.CharField(
        max_length=16, choices=Status.choices, default=Status.IN_SERVICE,
    )
    criticality = models.CharField(
        max_length=10, choices=Criticality.choices, default=Criticality.MEDIUM,
    )
    asset_tag = models.CharField(max_length=80, blank=True)
    serial_number = models.CharField(max_length=120, blank=True)
    manufacturer = models.CharField(max_length=160, blank=True)
    model = models.CharField(max_length=160, blank=True)
    standard = models.CharField(max_length=120, blank=True, help_text='e.g. EN 3-7 / EN 137')
    site = models.ForeignKey(
        Site, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='safety_equipment',
    )
    location = models.CharField(max_length=200, blank=True, help_text='Area / bay / floor')
    department = models.CharField(max_length=120, blank=True)
    custodian = models.CharField(max_length=160, blank=True)
    supplier = models.CharField(max_length=180, blank=True)
    acquired_on = models.DateField(null=True, blank=True)
    unit_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    useful_life_years = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text='Expected service life before replacement',
    )
    quantity = models.PositiveSmallIntegerField(default=1)
    # Inspection regime
    requires_inspection = models.BooleanField(default=True)
    inspection_interval_days = models.PositiveSmallIntegerField(default=30)
    last_inspected_on = models.DateField(null=True, blank=True)
    next_inspection_on = models.DateField(null=True, blank=True)
    # Calibration regime
    requires_calibration = models.BooleanField(default=False)
    calibration_interval_days = models.PositiveSmallIntegerField(default=365)
    last_calibrated_on = models.DateField(null=True, blank=True)
    next_calibration_on = models.DateField(null=True, blank=True)
    certificate_url = models.URLField(blank=True, max_length=600)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['name']
        verbose_name = 'Safety equipment'
        verbose_name_plural = 'Safety equipment'

    def __str__(self):
        return f'{self.reference or "EQ"} · {self.name}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        if self.requires_inspection and not self.next_inspection_on:
            last = self.last_inspected_on or date.today()
            self.next_inspection_on = last + timedelta(days=self.inspection_interval_days or 30)
        if self.requires_calibration and not self.next_calibration_on:
            last = self.last_calibrated_on or date.today()
            self.next_calibration_on = last + timedelta(days=self.calibration_interval_days or 365)
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'EQ-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'

    @staticmethod
    def _days(target):
        if not target:
            return None
        return (target - date.today()).days

    # ── Inspection currency ──────────────────────────────────────────
    @property
    def days_to_inspection(self):
        return self._days(self.next_inspection_on)

    @property
    def is_inspection_overdue(self):
        return bool(
            self.requires_inspection and self.next_inspection_on
            and self.next_inspection_on < date.today()
            and self.status not in (self.Status.DECOMMISSIONED,)
        )

    @property
    def is_inspection_due_soon(self):
        days = self.days_to_inspection
        return bool(self.requires_inspection and days is not None and 0 <= days <= 14)

    @property
    def inspection_currency_pct(self):
        if not self.requires_inspection:
            return 100
        days = self.days_to_inspection
        if days is None:
            return 0
        if days < 0:
            return 0
        window = max(self.inspection_interval_days or 30, 1)
        return round(min(days, window) / window * 100)

    # ── Calibration currency ─────────────────────────────────────────
    @property
    def days_to_calibration(self):
        return self._days(self.next_calibration_on)

    @property
    def is_calibration_overdue(self):
        return bool(
            self.requires_calibration and self.next_calibration_on
            and self.next_calibration_on < date.today()
        )

    @property
    def is_calibration_due_soon(self):
        days = self.days_to_calibration
        return bool(self.requires_calibration and days is not None and 0 <= days <= 14)

    # ── Lifecycle & health ───────────────────────────────────────────
    @property
    def age_years(self):
        if not self.acquired_on:
            return None
        return round((date.today() - self.acquired_on).days / 365.25, 1)

    @property
    def is_end_of_life(self):
        if not self.useful_life_years or not self.acquired_on:
            return False
        return (date.today() - self.acquired_on).days > self.useful_life_years * 365.25

    @property
    def open_defects(self):
        return self.defects.exclude(
            status__in=[EquipmentDefect.Status.RESOLVED, EquipmentDefect.Status.WRITTEN_OFF],
        ).count()

    @property
    def compliance_state(self):
        if self.status in (self.Status.OUT_OF_SERVICE, self.Status.DECOMMISSIONED):
            return 'out_of_service'
        if self.is_inspection_overdue or self.is_calibration_overdue:
            return 'overdue'
        if self.is_inspection_due_soon or self.is_calibration_due_soon:
            return 'due'
        if not self.requires_inspection and not self.requires_calibration:
            return 'unmonitored'
        return 'ok'

    @property
    def health_score(self):
        score = 100
        if self.is_inspection_overdue:
            score -= 40
        elif self.is_inspection_due_soon:
            score -= 15
        if self.is_calibration_overdue:
            score -= 25
        elif self.is_calibration_due_soon:
            score -= 10
        score -= min(self.open_defects * 10, 30)
        if self.status == self.Status.OUT_OF_SERVICE:
            score -= 25
        elif self.status == self.Status.QUARANTINE:
            score -= 12
        elif self.status == self.Status.MAINTENANCE:
            score -= 6
        if self.is_end_of_life:
            score -= 10
        return max(0, min(100, score))


class EquipmentInspection(TimeStampedModel):
    """Inspection, maintenance or calibration event for a piece of equipment."""

    class InspectionType(models.TextChoices):
        PRE_USE = 'pre_use', 'Pre-use check'
        ROUTINE = 'routine', 'Routine inspection'
        STATUTORY = 'statutory', 'Statutory examination'
        FUNCTIONAL = 'functional', 'Functional test'
        CALIBRATION = 'calibration', 'Calibration'
        MAINTENANCE = 'maintenance', 'Preventive maintenance'
        REPAIR = 'repair', 'Repair'

    class Result(models.TextChoices):
        PASS = 'pass', 'Pass'
        PASS_NOTES = 'pass_notes', 'Pass with observations'
        FAIL = 'fail', 'Fail — removed from service'

    equipment = models.ForeignKey(
        SafetyEquipment, on_delete=models.CASCADE, related_name='inspections',
    )
    inspection_type = models.CharField(
        max_length=14, choices=InspectionType.choices, default=InspectionType.ROUTINE,
    )
    performed_on = models.DateField(default=date.today)
    performed_by = models.CharField(max_length=160, blank=True)
    provider = models.CharField(max_length=180, blank=True)
    result = models.CharField(max_length=12, choices=Result.choices, default=Result.PASS)
    findings = models.TextField(blank=True)
    action_taken = models.TextField(blank=True)
    next_due = models.DateField(null=True, blank=True)
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    downtime_hours = models.PositiveSmallIntegerField(default=0)
    certificate_url = models.URLField(blank=True, max_length=600)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-performed_on', '-id']
        verbose_name = 'Equipment inspection'

    def __str__(self):
        return f'{self.equipment_id} · {self.get_inspection_type_display()} · {self.performed_on}'

    @property
    def is_failed(self):
        return self.result == self.Result.FAIL

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self._sync_equipment()

    def _sync_equipment(self):
        """Roll the latest successful event onto the parent asset."""
        if self.result == self.Result.FAIL:
            return
        eq = self.equipment
        fields = []
        is_cal = self.inspection_type == self.InspectionType.CALIBRATION
        if is_cal:
            if not eq.last_calibrated_on or self.performed_on >= eq.last_calibrated_on:
                eq.last_calibrated_on = self.performed_on
                eq.next_calibration_on = self.next_due or (
                    self.performed_on + timedelta(days=eq.calibration_interval_days or 365)
                )
                fields += ['last_calibrated_on', 'next_calibration_on']
        elif not eq.last_inspected_on or self.performed_on >= eq.last_inspected_on:
            eq.last_inspected_on = self.performed_on
            eq.next_inspection_on = self.next_due or (
                self.performed_on + timedelta(days=eq.inspection_interval_days or 30)
            )
            fields += ['last_inspected_on', 'next_inspection_on']
        if fields:
            eq.save(update_fields=list(dict.fromkeys(fields)) + ['updated_at'])


class EquipmentDefect(TimeStampedModel):
    """A fault, damage report or work order raised against an asset."""

    class Severity(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        IN_PROGRESS = 'in_progress', 'Repair in progress'
        AWAITING_PARTS = 'awaiting_parts', 'Awaiting parts'
        RESOLVED = 'resolved', 'Resolved'
        WRITTEN_OFF = 'written_off', 'Written off'

    equipment = models.ForeignKey(
        SafetyEquipment, on_delete=models.CASCADE, related_name='defects',
    )
    work_order = models.CharField(max_length=60, blank=True)
    reported_on = models.DateField(default=date.today)
    reported_by = models.CharField(max_length=160, blank=True)
    severity = models.CharField(max_length=10, choices=Severity.choices, default=Severity.MEDIUM)
    description = models.TextField()
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.OPEN)
    resolved_on = models.DateField(null=True, blank=True)
    resolved_by = models.CharField(max_length=160, blank=True)
    resolution = models.TextField(blank=True)
    downtime_hours = models.PositiveSmallIntegerField(default=0)
    repair_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    class Meta:
        ordering = ['-reported_on', '-id']
        verbose_name = 'Equipment defect'

    def __str__(self):
        return f'{self.equipment_id} · {self.description[:40]}'

    @property
    def is_open(self):
        return self.status not in (self.Status.RESOLVED, self.Status.WRITTEN_OFF)

    @property
    def days_open(self):
        if not self.reported_on:
            return None
        end = self.resolved_on or date.today()
        return (end - self.reported_on).days


# ─────────────────────────────────────────────────────────────────────────
#  Pre-employment & post-employment medical assessment
#
#  A statutory medical is only defensible if it is measured against something.
#  `JobDemandProfile` records the inherent requirements of a role (physical
#  demand, hazard exposures, sensory standards, mandatory immunisations), and
#  every `HealthAssessment` is scored against the profile for the job the
#  person is entering — or leaving.
#
#  Linking an exit assessment to its pre-employment baseline is what turns
#  "a medical" into an attributable record: it lets a clinician show whether a
#  measured loss (hearing shift, lung function, blood lead) happened during
#  this employment, which is the question a compensation claim actually asks.
# ─────────────────────────────────────────────────────────────────────────
class JobDemandProfile(TimeStampedModel):
    """Inherent requirements of a role — the yardstick for a fitness decision."""

    class PhysicalDemand(models.TextChoices):
        SEDENTARY = 'sedentary', 'Sedentary'
        LIGHT = 'light', 'Light'
        MEDIUM = 'medium', 'Medium'
        HEAVY = 'heavy', 'Heavy'
        VERY_HEAVY = 'very_heavy', 'Very heavy'

    class SensoryStandard(models.TextChoices):
        NONE = 'none', 'Not required'
        BASIC = 'basic', 'Basic'
        STANDARD = 'standard', 'Standard'
        STRICT = 'strict', 'Strict (safety critical)'

    class SurveillanceTier(models.TextChoices):
        NONE = 'none', 'Baseline only'
        ANNUAL = 'annual', 'Annual'
        SIX_MONTHLY = 'six_monthly', 'Six-monthly'
        QUARTERLY = 'quarterly', 'Quarterly'
        HAZARD_DRIVEN = 'hazard_driven', 'Driven by exposure monitoring'

    code = models.CharField(max_length=32, blank=True, help_text='e.g. OPS-FORKLIFT')
    job_title = models.CharField(max_length=160)
    department = models.CharField(max_length=120, blank=True)
    site = models.ForeignKey(
        Site, on_delete=models.CASCADE, null=True, blank=True,
        related_name='job_demands',
    )
    physical_demand = models.CharField(
        max_length=12, choices=PhysicalDemand.choices, default=PhysicalDemand.LIGHT,
    )
    vision_standard = models.CharField(
        max_length=10, choices=SensoryStandard.choices, default=SensoryStandard.BASIC,
    )
    hearing_standard = models.CharField(
        max_length=10, choices=SensoryStandard.choices, default=SensoryStandard.NONE,
    )
    min_vision_left = models.CharField(
        max_length=20, blank=True, default='6/12',
        help_text='Minimum corrected acuity, left eye',
    )
    min_vision_right = models.CharField(max_length=20, blank=True, default='6/12')
    max_hearing_loss_db = models.PositiveSmallIntegerField(
        null=True, blank=True, default=30,
        help_text='Maximum acceptable hearing threshold, better ear (dB)',
    )
    hazard_exposures = models.JSONField(
        default=list, blank=True,
        help_text='Agents this role is exposed to, e.g. ["noise", "respirable dust"]',
    )
    required_ppe = models.JSONField(default=list, blank=True)
    mandatory_immunisations = models.JSONField(default=list, blank=True)
    mandatory_tests = models.JSONField(
        default=list, blank=True,
        help_text='Investigations required for this role, e.g. ["audiometry", "spirometry"]',
    )
    surveillance_tier = models.CharField(
        max_length=16, choices=SurveillanceTier.choices, default=SurveillanceTier.ANNUAL,
    )
    inherent_requirements = models.TextField(
        blank=True, help_text='Plain-language list of the role’s essential demands',
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['job_title']
        verbose_name = 'Job demand profile'

    def __str__(self):
        return f'{self.job_title} ({self.get_physical_demand_display()})'

    @property
    def review_interval_months(self):
        return {
            self.SurveillanceTier.QUARTERLY: 3,
            self.SurveillanceTier.SIX_MONTHLY: 6,
            self.SurveillanceTier.ANNUAL: 12,
            self.SurveillanceTier.HAZARD_DRIVEN: 12,
            self.SurveillanceTier.NONE: None,
        }.get(self.surveillance_tier)


class HealthAssessment(TimeStampedModel):
    """A pre-employment, periodic, exit or return-to-work medical assessment.

    Clinical data is split between three places on purpose:

    * ``vital_signs`` / ``vision`` / ``hearing`` / ``spirometry`` — fixed-shape
      measurement blocks, compared numerically against the baseline.
    * ``history`` — free-form anamnesis, never aggregated.
    * ``AssessmentFinding`` / ``AssessmentLabResult`` — normalised rows so the
      register can flag, count and trend individual abnormalities.
    """

    class Kind(models.TextChoices):
        PRE_EMPLOYMENT = 'pre_employment', 'Pre-employment'
        PERIODIC = 'periodic', 'Periodic / statutory'
        EXIT = 'exit', 'Post-employment (exit)'
        RETURN_TO_WORK = 'return_to_work', 'Return to work'
        TRANSFER = 'transfer', 'Transfer / redeployment'

    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        IN_PROGRESS = 'in_progress', 'In progress'
        COMPLETED = 'completed', 'Completed'
        CERTIFIED = 'certified', 'Certificate issued'
        CANCELLED = 'cancelled', 'Cancelled'
        DECLINED = 'declined', 'Declined by employee'

    class Fitness(models.TextChoices):
        PENDING = 'pending', 'Pending'
        FIT = 'fit', 'Fit for duty'
        FIT_WITH_RESTRICTIONS = 'fit_with_restrictions', 'Fit with restrictions'
        TEMPORARILY_UNFIT = 'temporarily_unfit', 'Temporarily unfit'
        UNFIT = 'unfit', 'Unfit'

    class ExitReason(models.TextChoices):
        RESIGNATION = 'resignation', 'Resignation'
        RETIREMENT = 'retirement', 'Retirement'
        REDUNDANCY = 'redundancy', 'Redundancy'
        CONTRACT_END = 'contract_end', 'Contract end'
        MEDICAL = 'medical', 'Medical grounds'
        DISMISSAL = 'dismissal', 'Dismissal'
        TRANSFER_OUT = 'transfer_out', 'Transfer to another employer'

    reference = models.CharField(max_length=32, unique=True, blank=True)
    kind = models.CharField(max_length=16, choices=Kind.choices, default=Kind.PRE_EMPLOYMENT)
    status = models.CharField(max_length=14, choices=Status.choices, default=Status.SCHEDULED)

    # ── Candidate / employee ──
    employee_name = models.CharField(max_length=160)
    employee_ref = models.CharField(max_length=60, blank=True, help_text='Payroll / staff number')
    national_id = models.CharField(max_length=40, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=16, blank=True)
    phone = models.CharField(max_length=40, blank=True)
    job_title = models.CharField(max_length=160, blank=True)
    department = models.CharField(max_length=120, blank=True)
    site = models.ForeignKey(
        Site, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='health_assessments',
    )
    job_demand = models.ForeignKey(
        JobDemandProfile, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='assessments',
    )

    # ── Scheduling & provider ──
    scheduled_on = models.DateField(default=date.today)
    examined_on = models.DateField(null=True, blank=True)
    examiner_name = models.CharField(max_length=160, blank=True)
    provider = models.CharField(max_length=180, blank=True, help_text='Clinic / hospital')
    provider_ref = models.CharField(max_length=80, blank=True)

    # ── Measurements (fixed shape, comparable to baseline) ──
    vital_signs = models.JSONField(
        default=dict, blank=True,
        help_text='height_cm, weight_kg, bp_systolic, bp_diastolic, pulse, '
                  'resp_rate, temperature_c, spo2, waist_cm',
    )
    vision = models.JSONField(
        default=dict, blank=True,
        help_text='left_unaided, right_unaided, left_corrected, right_corrected, '
                  'colour_vision, near_vision',
    )
    hearing = models.JSONField(
        default=dict, blank=True,
        help_text='left_db, right_db, audiogram_shape, noise_induced',
    )
    spirometry = models.JSONField(
        default=dict, blank=True,
        help_text='fev1_l, fvc_l, fev1_fvc_pct, predicted_pct',
    )
    history = models.JSONField(
        default=dict, blank=True,
        help_text='past_medical, surgical, medications, allergies, family, '
                  'occupational, smoker, alcohol, exercise',
    )
    immunisations = models.JSONField(
        default=list, blank=True,
        help_text='[{name, status, given_on}]',
    )

    # ── Outcome ──
    fitness = models.CharField(max_length=22, choices=Fitness.choices, default=Fitness.PENDING)
    restrictions = models.TextField(
        blank=True, help_text='Restrictions that must be honoured on the job',
    )
    recommendations = models.TextField(blank=True)
    work_related = models.BooleanField(
        default=False,
        help_text='Findings are attributable to this employment',
    )
    attributable_condition = models.TextField(blank=True)
    compensation_claim = models.BooleanField(
        default=False, help_text='Referred for statutory compensation (e.g. WIBA)',
    )
    exit_reason = models.CharField(
        max_length=16, choices=ExitReason.choices, blank=True,
    )
    clearance_notes = models.TextField(
        blank=True, help_text='Handover / clearance remarks for an exit assessment',
    )

    # ── Certificate ──
    certificate_no = models.CharField(max_length=60, blank=True)
    issued_on = models.DateField(null=True, blank=True)
    valid_until = models.DateField(null=True, blank=True)
    next_due = models.DateField(null=True, blank=True)

    # ── Baseline linkage ──
    baseline = models.ForeignKey(
        'self', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='follow_ups',
        help_text='The pre-employment assessment this one is measured against',
    )

    reviewed_by = models.CharField(max_length=160, blank=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-scheduled_on', '-id']
        verbose_name = 'Health assessment'

    def __str__(self):
        return f'{self.reference or "MDA"} · {self.employee_name}'

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self._next_reference()
        super().save(*args, **kwargs)

    @classmethod
    def _next_reference(cls):
        year = timezone.now().year
        prefix = f'MDA-{year}-'
        last = (
            cls.objects.filter(reference__startswith=prefix)
            .order_by('-reference').values_list('reference', flat=True).first()
        )
        seq = int(last.rsplit('-', 1)[-1]) + 1 if last else 1
        return f'{prefix}{seq:04d}'

    # ── Derived values ──
    @property
    def bmi(self):
        v = self.vital_signs or {}
        try:
            h = float(v.get('height_cm') or 0) / 100
            w = float(v.get('weight_kg') or 0)
        except (TypeError, ValueError):
            return None
        if h <= 0 or w <= 0:
            return None
        return round(w / (h * h), 1)

    @property
    def bmi_band(self):
        bmi = self.bmi
        if bmi is None:
            return ''
        if bmi < 18.5:
            return 'underweight'
        if bmi < 25:
            return 'normal'
        if bmi < 30:
            return 'overweight'
        if bmi < 35:
            return 'obese_1'
        if bmi < 40:
            return 'obese_2'
        return 'obese_3'

    @property
    def blood_pressure(self):
        v = self.vital_signs or {}
        sys, dia = v.get('bp_systolic'), v.get('bp_diastolic')
        if not sys or not dia:
            return ''
        return f'{sys}/{dia}'

    @property
    def bp_band(self):
        v = self.vital_signs or {}
        try:
            s = int(v.get('bp_systolic') or 0)
            d = int(v.get('bp_diastolic') or 0)
        except (TypeError, ValueError):
            return ''
        if not s or not d:
            return ''
        if s >= 180 or d >= 110:
            return 'crisis'
        if s >= 140 or d >= 90:
            return 'high'
        if s >= 130 or d >= 85:
            return 'elevated'
        if s < 90 or d < 60:
            return 'low'
        return 'normal'

    @property
    def is_certified(self):
        return bool(self.certificate_no) and self.issued_on is not None

    @property
    def is_certificate_expired(self):
        return bool(self.valid_until) and self.valid_until < date.today()

    @property
    def days_to_expiry(self):
        if not self.valid_until:
            return None
        return (self.valid_until - date.today()).days

    @property
    def is_overdue(self):
        """Scheduled but past its date and not yet examined."""
        if self.status in (self.Status.COMPLETED, self.Status.CERTIFIED, self.Status.CANCELLED):
            return False
        return self.scheduled_on < date.today()

    @property
    def abnormal_labs(self):
        return self.lab_results.exclude(flag='normal').count()

    @property
    def critical_findings(self):
        return self.findings.filter(severity='critical').count()


class AssessmentFinding(TimeStampedModel):
    """A single clinical finding, normalised so it can be flagged and counted."""

    class System(models.TextChoices):
        GENERAL = 'general', 'General'
        CARDIOVASCULAR = 'cardiovascular', 'Cardiovascular'
        RESPIRATORY = 'respiratory', 'Respiratory'
        MUSCULOSKELETAL = 'musculoskeletal', 'Musculoskeletal'
        NEUROLOGICAL = 'neurological', 'Neurological'
        AUDIOLOGY = 'audiology', 'Hearing'
        OPHTHALMOLOGY = 'ophthalmology', 'Vision'
        DERMATOLOGY = 'dermatology', 'Skin'
        ABDOMINAL = 'abdominal', 'Abdominal'
        ENDOCRINE = 'endocrine', 'Endocrine'
        MENTAL_HEALTH = 'mental_health', 'Mental health'
        LABORATORY = 'laboratory', 'Laboratory'

    class Severity(models.TextChoices):
        NORMAL = 'normal', 'Normal'
        MINOR = 'minor', 'Minor'
        MAJOR = 'major', 'Significant'
        CRITICAL = 'critical', 'Critical'

    assessment = models.ForeignKey(
        HealthAssessment, on_delete=models.CASCADE, related_name='findings',
    )
    system = models.CharField(max_length=18, choices=System.choices, default=System.GENERAL)
    finding = models.CharField(max_length=220)
    severity = models.CharField(max_length=10, choices=Severity.choices, default=Severity.NORMAL)
    work_related = models.BooleanField(default=False)
    fit_impact = models.CharField(
        max_length=12, blank=True,
        help_text='none | restrict | unfit — how this finding drove the outcome',
    )
    recommendation = models.TextField(blank=True)

    class Meta:
        ordering = ['system', 'id']
        verbose_name = 'Assessment finding'

    def __str__(self):
        return f'{self.get_system_display()} · {self.finding}'


class AssessmentLabResult(TimeStampedModel):
    """An analyte measured during the assessment, with its reference range."""

    class Flag(models.TextChoices):
        NORMAL = 'normal', 'Normal'
        LOW = 'low', 'Low'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    assessment = models.ForeignKey(
        HealthAssessment, on_delete=models.CASCADE, related_name='lab_results',
    )
    analyte = models.CharField(max_length=120)
    value = models.CharField(max_length=60)
    unit = models.CharField(max_length=30, blank=True)
    reference_low = models.FloatField(null=True, blank=True)
    reference_high = models.FloatField(null=True, blank=True)
    flag = models.CharField(max_length=10, choices=Flag.choices, default=Flag.NORMAL)
    notes = models.CharField(max_length=220, blank=True)

    class Meta:
        ordering = ['analyte']
        verbose_name = 'Assessment lab result'

    def __str__(self):
        return f'{self.analyte}: {self.value} {self.unit}'.strip()

    def save(self, *args, **kwargs):
        # Derive the flag from the numeric value when the lab did not say.
        if self.flag == self.Flag.NORMAL and self.reference_low is not None \
                and self.reference_high is not None:
            try:
                n = float(self.value)
            except (TypeError, ValueError):
                n = None
            if n is not None:
                if n < self.reference_low:
                    self.flag = self.Flag.LOW
                elif n > self.reference_high:
                    self.flag = self.Flag.HIGH
        super().save(*args, **kwargs)


# ─────────────────────────────────────────────────────────────────────────
#  Demo data (SECURITY & SETTINGS → Demo data)
#
#  A production tenant may want to explore OHSMS with realistic records
#  before entering real data. Every object a demo run creates is recorded in
#  DemoDataRecord so the tenant can later remove *only* the demo rows without
#  touching anything their team has entered.
# ─────────────────────────────────────────────────────────────────────────
class DemoDataRun(TimeStampedModel):
    """One execution of the demo-data seeder."""

    class Status(models.TextChoices):
        COMPLETE = 'complete', 'Complete'
        PARTIAL = 'partial', 'Partially seeded'
        FAILED = 'failed', 'Failed'

    run_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    datasets = models.JSONField(
        default=list, help_text='Dataset keys that were requested',
    )
    summary = models.JSONField(
        default=dict, help_text='{dataset_key: {model_label: count}}',
    )
    objects_created = models.IntegerField(default=0)
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.COMPLETE,
    )
    error = models.TextField(blank=True)
    duration_ms = models.PositiveIntegerField(default=0)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name='ohs_demo_runs',
    )
    created_by_name = models.CharField(max_length=160, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Demo data run'
        verbose_name_plural = 'Demo data runs'

    def __str__(self):
        return f'{self.run_id} - {len(self.datasets or [])} dataset(s)'

    @property
    def is_cleared(self):
        return not self.records.exists()


class DemoDataRecord(models.Model):
    """A single object created by a demo run (used for precise rollback)."""

    run = models.ForeignKey(
        DemoDataRun, on_delete=models.CASCADE, related_name='records',
    )
    dataset = models.CharField(max_length=40, db_index=True)
    model_label = models.CharField(max_length=80)
    object_id = models.PositiveBigIntegerField()

    class Meta:
        ordering = ['id']
        verbose_name = 'Demo data record'
        verbose_name_plural = 'Demo data records'
        indexes = [
            models.Index(fields=['model_label', 'object_id']),
        ]

    def __str__(self):
        return f'{self.model_label}#{self.object_id}'

