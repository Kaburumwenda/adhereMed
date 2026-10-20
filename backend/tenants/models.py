from django.db import models
from django_tenants.models import TenantMixin, DomainMixin


class Tenant(TenantMixin):
    class TenantType(models.TextChoices):
        HOSPITAL = 'hospital', 'Hospital'
        PHARMACY = 'pharmacy', 'Pharmacy'
        LAB = 'lab', 'Laboratory'
        HOMECARE = 'homecare', 'Homecare'
        RADIOLOGY = 'radiology_center', 'Radiology Center'
        CLINIC = 'clinic', 'Clinic'
        INVENTORY = 'inventory', 'Inventory / Warehouse'
        OHSMS = 'ohsms', 'Occupational Health & Safety'

    class ProvisioningStatus(models.TextChoices):
        """Lifecycle of a tenant's database schema.

        Tenant creation writes the public rows (Tenant/Domain/admin user) in one
        fast transaction and marks the tenant ``PENDING``; the schema is then
        built in the background (it runs ~25 apps' migrations and takes 30s+).

        Requests hitting a tenant that is not ``READY`` are answered with 503
        instead of failing with ``relation "..." does not exist``.
        """
        PENDING = 'pending', 'Pending'
        PROVISIONING = 'provisioning', 'Provisioning'
        READY = 'ready', 'Ready'
        FAILED = 'failed', 'Failed'

    name = models.CharField(max_length=255)
    type = models.CharField(max_length=20, choices=TenantType.choices)
    slug = models.SlugField(unique=True)
    logo = models.ImageField(upload_to='tenant_logos/', blank=True, null=True)
    address = models.TextField(blank=True)
    city = models.CharField(max_length=100, blank=True)
    country = models.CharField(max_length=100, default='Kenya')
    latitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    place_name = models.CharField(max_length=255, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    website = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)
    # ── Billing / API-access suspension ──
    billing_suspended = models.BooleanField(
        default=False,
        help_text='Superadmin hard-lock of API access due to unpaid/overdue bills.')
    suspension_reason = models.CharField(max_length=255, blank=True)
    billing_grace_until = models.DateField(
        null=True, blank=True,
        help_text='Access is permitted despite overdue bills until this date '
                  '(superadmin-granted grace / extended suspension).')
    # ── Branding / custom colours ──
    brand_primary = models.CharField(
        max_length=7, blank=True, default='',
        help_text='Hex colour (e.g. #2f6dff) for the primary brand colour.')
    brand_secondary = models.CharField(
        max_length=7, blank=True, default='',
        help_text='Hex colour (e.g. #143ce1) for the secondary / deep brand colour.')
    brand_accent = models.CharField(
        max_length=7, blank=True, default='',
        help_text='Hex colour (e.g. #37d6ff) for the accent / highlight colour.')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # ── Schema provisioning bookkeeping ──
    # Defaults to READY so tenants created by other code paths (which still
    # create their schema synchronously via ``auto_create_schema``) are never
    # wrongly treated as unavailable. The async creation flow sets PENDING
    # explicitly and then flips to PROVISIONING / READY / FAILED.
    provisioning_status = models.CharField(
        max_length=16,
        choices=ProvisioningStatus.choices,
        default=ProvisioningStatus.READY,
        db_index=True,
        help_text='Lifecycle of the tenant schema. Not "ready" means the schema '
                  'is still being built in the background.',
    )
    provisioning_error = models.TextField(
        blank=True,
        default='',
        help_text='Last provisioning failure, if any.',
    )
    provisioning_started_at = models.DateTimeField(null=True, blank=True)
    provisioning_completed_at = models.DateTimeField(null=True, blank=True)

    auto_create_schema = True

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f'{self.name} ({self.get_type_display()})'

    @property
    def is_ready(self) -> bool:
        """True only once the tenant's schema exists and is fully migrated."""
        return self.provisioning_status == self.ProvisioningStatus.READY


class Domain(DomainMixin):
    pass
