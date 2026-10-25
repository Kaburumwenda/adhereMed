"""Clinic equipment / biomedical asset management.

Covers the full asset lifecycle for a clinic network:

* ``EquipmentCategory``  — grouping (diagnostic, surgical, imaging, …)
* ``Equipment``          — the physical asset, bound to a clinic branch
* ``EquipmentMaintenance`` — preventive, corrective, calibration, inspection
* ``EquipmentFault``     — fault reports raised by staff, with resolution
* ``EquipmentTransfer``  — movement / custody change between branches

Everything is scoped to a ``clinic_sites.ClinicSite`` so admins can see the
whole network while staff only see their own branch.
"""

from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone


def _today():
    return timezone.localdate()


class EquipmentCategory(models.Model):
    """A class of equipment that shares servicing rules."""

    name = models.CharField(max_length=120, unique=True)
    code = models.CharField(
        max_length=20, blank=True, db_index=True,
        help_text='Short code used on asset tags, e.g. IMG, LAB, SUR.',
    )
    description = models.TextField(blank=True)
    icon = models.CharField(
        max_length=40, blank=True, default='mdi-medical-bag',
        help_text='Material Design icon name for this category.',
    )
    maintenance_interval_days = models.PositiveIntegerField(
        default=180,
        help_text='Default preventive-maintenance interval in days.',
    )
    requires_calibration = models.BooleanField(
        default=False,
        help_text='Measuring devices (scales, monitors, analyzers) require calibration.',
    )
    calibration_interval_days = models.PositiveIntegerField(default=365)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'Equipment categories'

    def __str__(self):
        return self.name


class Equipment(models.Model):
    """A single piece of clinic equipment."""

    class Status(models.TextChoices):
        OPERATIONAL = 'operational', 'Operational'
        UNDER_MAINTENANCE = 'under_maintenance', 'Under maintenance'
        OUT_OF_SERVICE = 'out_of_service', 'Out of service'
        IN_STORAGE = 'in_storage', 'In storage'
        RETIRED = 'retired', 'Retired'

    class Condition(models.TextChoices):
        EXCELLENT = 'excellent', 'Excellent'
        GOOD = 'good', 'Good'
        FAIR = 'fair', 'Fair'
        POOR = 'poor', 'Poor'
        UNUSABLE = 'unusable', 'Unusable'

    class Criticality(models.TextChoices):
        LIFE_SUPPORT = 'life_support', 'Life support'
        CRITICAL = 'critical', 'Critical'
        ESSENTIAL = 'essential', 'Essential'
        OPTIONAL = 'optional', 'Optional'

    class Ownership(models.TextChoices):
        OWNED = 'owned', 'Owned'
        LEASED = 'leased', 'Leased'
        DONATED = 'donated', 'Donated'
        GRANT = 'grant', 'Grant / programme'

    # ── Identity ──
    asset_tag = models.CharField(
        max_length=40, unique=True, db_index=True,
        help_text='Sticker / barcode identifier, e.g. EQ-IMG-0007.',
    )
    name = models.CharField(max_length=255, db_index=True)
    category = models.ForeignKey(
        EquipmentCategory, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='items',
    )
    manufacturer = models.CharField(max_length=160, blank=True)
    model_number = models.CharField(max_length=120, blank=True)
    serial_number = models.CharField(max_length=120, blank=True, db_index=True)
    description = models.TextField(blank=True)

    # ── Where it lives ──
    # ``db_constraint=False`` — clinic_sites is also created in the public schema.
    site = models.ForeignKey(
        'clinic_sites.ClinicSite', on_delete=models.SET_NULL,
        null=True, blank=True, db_constraint=False,
        related_name='equipment',
        help_text='Clinic branch this asset belongs to.',
    )
    department = models.ForeignKey(
        'departments.Department', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='equipment',
    )
    location = models.CharField(
        max_length=160, blank=True,
        help_text='Room / theatre / lab bench, e.g. "Radiology Room 2".',
    )
    custodian = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='custodied_equipment',
        help_text='Staff member accountable for this asset.',
    )

    # ── State ──
    status = models.CharField(max_length=24, choices=Status.choices, default=Status.OPERATIONAL, db_index=True)
    condition = models.CharField(max_length=16, choices=Condition.choices, default=Condition.GOOD)
    criticality = models.CharField(
        max_length=20, choices=Criticality.choices,
        default=Criticality.ESSENTIAL, db_index=True,
    )
    is_active = models.BooleanField(default=True)

    # ── Acquisition ──
    ownership = models.CharField(max_length=12, choices=Ownership.choices, default=Ownership.OWNED)
    purchase_date = models.DateField(null=True, blank=True)
    purchase_price = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    supplier_name = models.CharField(max_length=200, blank=True)
    invoice_number = models.CharField(max_length=80, blank=True)
    warranty_expiry = models.DateField(null=True, blank=True)
    lease_end = models.DateField(null=True, blank=True)
    commissioned_on = models.DateField(null=True, blank=True)
    expected_life_years = models.PositiveIntegerField(
        default=0, help_text='Useful life in years, for depreciation planning.',
    )

    # ── Servicing ──
    maintenance_interval_days = models.PositiveIntegerField(
        default=0,
        help_text='Override the category interval. 0 = use the category default.',
    )
    last_maintenance = models.DateField(null=True, blank=True)
    next_maintenance = models.DateField(null=True, blank=True, db_index=True)
    calibration_required = models.BooleanField(default=False)
    calibration_interval_days = models.PositiveIntegerField(default=0)
    last_calibration = models.DateField(null=True, blank=True)
    next_calibration = models.DateField(null=True, blank=True, db_index=True)

    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'Equipment'
        indexes = [
            models.Index(fields=['site', 'status']),
            models.Index(fields=['next_maintenance']),
        ]

    def __str__(self):
        return f'{self.name} ({self.asset_tag})'

    # ── Effective intervals ──
    @property
    def effective_maintenance_interval(self):
        if self.maintenance_interval_days:
            return self.maintenance_interval_days
        if self.category_id and self.category.maintenance_interval_days:
            return self.category.maintenance_interval_days
        return 180

    @property
    def effective_calibration_interval(self):
        if self.calibration_interval_days:
            return self.calibration_interval_days
        if self.category_id and self.category.calibration_interval_days:
            return self.category.calibration_interval_days
        return 365

    # ── Time-based health ──
    @property
    def days_to_maintenance(self):
        if not self.next_maintenance:
            return None
        return (self.next_maintenance - _today()).days

    @property
    def maintenance_overdue(self):
        days = self.days_to_maintenance
        return days is not None and days < 0

    @property
    def maintenance_due_soon(self):
        days = self.days_to_maintenance
        return days is not None and 0 <= days <= 14

    @property
    def days_to_calibration(self):
        if not self.next_calibration:
            return None
        return (self.next_calibration - _today()).days

    @property
    def calibration_overdue(self):
        days = self.days_to_calibration
        return days is not None and days < 0

    @property
    def warranty_expired(self):
        if not self.warranty_expiry:
            return False
        return self.warranty_expiry < _today()

    @property
    def days_to_warranty_expiry(self):
        if not self.warranty_expiry:
            return None
        return (self.warranty_expiry - _today()).days

    @property
    def open_faults(self):
        """Open fault count. Uses the viewset annotation when available."""
        cached = getattr(self, 'open_fault_count', None)
        if cached is not None:
            return cached
        return self.faults.filter(
            status__in=[EquipmentFault.Status.OPEN, EquipmentFault.Status.INVESTIGATING],
        ).count()

    @property
    def age_years(self):
        base = self.commissioned_on or self.purchase_date
        if not base:
            return None
        return round((_today() - base).days / 365.25, 1)

    @property
    def health_score(self):
        """0–100 indicator used by the dashboard.

        Starts at 100 and loses points for every risk signal: status, condition,
        overdue servicing, calibration and open faults.
        """
        score = 100
        score -= {
            self.Status.OPERATIONAL: 0,
            self.Status.UNDER_MAINTENANCE: 25,
            self.Status.OUT_OF_SERVICE: 55,
            self.Status.IN_STORAGE: 15,
            self.Status.RETIRED: 90,
        }.get(self.status, 0)

        score -= {
            self.Condition.EXCELLENT: 0,
            self.Condition.GOOD: 5,
            self.Condition.FAIR: 20,
            self.Condition.POOR: 38,
            self.Condition.UNUSABLE: 55,
        }.get(self.condition, 0)

        if self.maintenance_overdue:
            score -= 18
        elif self.maintenance_due_soon:
            score -= 6

        if self.calibration_overdue:
            score -= 15

        score -= min(20, self.open_faults * 8)

        if self.warranty_expired and self.condition in (self.Condition.POOR, self.Condition.FAIR):
            score -= 5

        return max(0, min(100, score))

    @property
    def health_label(self):
        score = self.health_score
        if score >= 85:
            return 'healthy'
        if score >= 65:
            return 'watch'
        if score >= 45:
            return 'at_risk'
        return 'critical'

    def save(self, *args, **kwargs):
        # Auto-generate an asset tag when one was not supplied.
        if not self.asset_tag:
            prefix = ''
            if self.category_id and getattr(self.category, 'code', ''):
                prefix = self.category.code.strip().upper()
            # Avoid "EQ-EQ-0001" for uncategorised assets.
            if not prefix or prefix == 'EQ':
                prefix = 'GEN'
            prefix = prefix[:8]

            last = (
                Equipment.objects
                .filter(asset_tag__startswith=f'EQ-{prefix}-')
                .order_by('-id')
                .values_list('asset_tag', flat=True)
                .first()
            )
            seq = 1
            if last:
                try:
                    seq = int(last.rsplit('-', 1)[1]) + 1
                except (IndexError, ValueError):
                    seq = Equipment.objects.count() + 1
            self.asset_tag = f'EQ-{prefix}-{seq:04d}'
        self.asset_tag = self.asset_tag.strip().upper()[:40]
        super().save(*args, **kwargs)


class EquipmentMaintenance(models.Model):
    """A servicing job — preventive, corrective, calibration or inspection."""

    class Kind(models.TextChoices):
        PREVENTIVE = 'preventive', 'Preventive service'
        CORRECTIVE = 'corrective', 'Corrective repair'
        CALIBRATION = 'calibration', 'Calibration'
        INSPECTION = 'inspection', 'Safety inspection'
        UPGRADE = 'upgrade', 'Upgrade / modification'

    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        IN_PROGRESS = 'in_progress', 'In progress'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class PerformedBy(models.TextChoices):
        INTERNAL = 'internal', 'Biomedical team'
        VENDOR = 'vendor', 'External vendor'
        MANUFACTURER = 'manufacturer', 'Manufacturer'

    equipment = models.ForeignKey(
        Equipment, on_delete=models.CASCADE, related_name='maintenance_jobs',
    )
    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.PREVENTIVE, db_index=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.SCHEDULED, db_index=True)

    scheduled_date = models.DateField(db_index=True)
    completed_date = models.DateField(null=True, blank=True)

    performed_by = models.CharField(max_length=16, choices=PerformedBy.choices, default=PerformedBy.INTERNAL)
    vendor_name = models.CharField(max_length=200, blank=True)
    technician = models.CharField(max_length=160, blank=True)

    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    downtime_hours = models.DecimalField(
        max_digits=6, decimal_places=1, default=0,
        help_text='Hours the asset was unavailable while being serviced.',
    )

    description = models.TextField(blank=True)
    findings = models.TextField(blank=True)
    next_due_date = models.DateField(null=True, blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='equipment_maintenance_created',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-scheduled_date']
        verbose_name_plural = 'Equipment maintenance'

    def __str__(self):
        return f'{self.get_kind_display()} — {self.equipment.name} ({self.scheduled_date})'

    @property
    def is_overdue(self):
        if self.status in (self.Status.COMPLETED, self.Status.CANCELLED):
            return False
        return self.scheduled_date < _today()

    @property
    def days_until_due(self):
        return (self.scheduled_date - _today()).days


class EquipmentFault(models.Model):
    """A fault reported against a piece of equipment."""

    class Severity(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical — patient safety'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        INVESTIGATING = 'investigating', 'Investigating'
        RESOLVED = 'resolved', 'Resolved'
        DISMISSED = 'dismissed', 'Dismissed'

    equipment = models.ForeignKey(
        Equipment, on_delete=models.CASCADE, related_name='faults',
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    severity = models.CharField(max_length=12, choices=Severity.choices, default=Severity.MEDIUM, db_index=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.OPEN, db_index=True)

    reported_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='equipment_faults_reported',
    )
    reported_at = models.DateTimeField(default=timezone.now, db_index=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='equipment_faults_resolved',
    )
    resolution = models.TextField(blank=True)
    downtime_hours = models.DecimalField(max_digits=6, decimal_places=1, default=0)

    maintenance = models.ForeignKey(
        EquipmentMaintenance, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='faults',
        help_text='Repair job raised to fix this fault.',
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-reported_at']
        verbose_name_plural = 'Equipment faults'

    def __str__(self):
        return f'{self.title} — {self.equipment.name}'

    @property
    def is_open(self):
        return self.status in (self.Status.OPEN, self.Status.INVESTIGATING)

    @property
    def days_open(self):
        if not self.is_open:
            return 0
        return max(0, (timezone.now() - self.reported_at).days)


class EquipmentTransfer(models.Model):
    """Movement of an asset between branches / departments."""

    equipment = models.ForeignKey(
        Equipment, on_delete=models.CASCADE, related_name='transfers',
    )
    from_site = models.ForeignKey(
        'clinic_sites.ClinicSite', on_delete=models.SET_NULL,
        null=True, blank=True, db_constraint=False, related_name='equipment_transfers_out',
    )
    to_site = models.ForeignKey(
        'clinic_sites.ClinicSite', on_delete=models.SET_NULL,
        null=True, blank=True, db_constraint=False, related_name='equipment_transfers_in',
    )
    from_department = models.ForeignKey(
        'departments.Department', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='equipment_transfers_out',
    )
    to_department = models.ForeignKey(
        'departments.Department', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='equipment_transfers_in',
    )
    reason = models.CharField(max_length=255, blank=True)
    notes = models.TextField(blank=True)
    transferred_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='equipment_transfers_made',
    )
    transferred_at = models.DateTimeField(default=timezone.now, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-transferred_at']

    def __str__(self):
        return f'{self.equipment.name}: {self.from_site} → {self.to_site}'


class EquipmentSeedRun(models.Model):
    """Audit trail for equipment seed runs.

    Production clinics need a durable record of who seeded what, when, and
    whether it worked — the seed panel is destructive enough that "it ran once"
    should be provable after the page is reloaded.
    """

    class Status(models.TextChoices):
        SUCCESS = 'success', 'Success'
        FAILED = 'failed', 'Failed'

    pack_key = models.CharField(max_length=40, db_index=True)
    label = models.CharField(max_length=120)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.SUCCESS, db_index=True)
    detail = models.TextField(blank=True)

    categories_created = models.PositiveIntegerField(default=0)
    assets_created = models.PositiveIntegerField(default=0)
    jobs_created = models.PositiveIntegerField(default=0)
    faults_created = models.PositiveIntegerField(default=0)
    transfers_created = models.PositiveIntegerField(default=0)
    duration_ms = models.PositiveIntegerField(default=0)

    run_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='equipment_seed_runs',
    )
    run_by_label = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Equipment seed run'
        verbose_name_plural = 'Equipment seed runs'

    def __str__(self):
        return f'{self.label} — {self.status} ({self.created_at:%Y-%m-%d %H:%M})'

    @property
    def records_created(self):
        return (
            self.categories_created + self.assets_created
            + self.jobs_created + self.faults_created + self.transfers_created
        )

