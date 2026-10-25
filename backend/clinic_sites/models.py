from django.conf import settings
from django.db import models
from django.db.models import Q


class ClinicSite(models.Model):
    """One physical clinic inside a clinic tenant.

    Exactly one site per tenant is flagged ``is_hq``. The HQ is the fallback
    owner for every record that does not carry an explicit site, which is what
    makes a single-clinic tenant behave exactly as it did before multi-clinic
    support existed.
    """

    class Kind(models.TextChoices):
        HQ = 'hq', 'Headquarters'
        BRANCH = 'branch', 'Branch clinic'
        SATELLITE = 'satellite', 'Satellite clinic'
        OUTREACH = 'outreach', 'Outreach / mobile'

    # Link back to the legacy facility profile (only the HQ has one).
    # ``db_constraint=False`` because ``pharmacy_profile`` is a tenant-only app
    # while this model is also created in the public schema (see settings).
    profile = models.OneToOneField(
        'pharmacy_profile.PharmacyDetail',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        db_constraint=False,
        related_name='clinic_site',
        help_text='Facility profile this site was bootstrapped from.',
    )

    name = models.CharField(max_length=255, db_index=True)
    code = models.CharField(
        max_length=24, blank=True, db_index=True,
        help_text='Short code used on bills and patient numbers (e.g. HQ, WST).',
    )
    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.BRANCH)
    is_hq = models.BooleanField(default=False, db_index=True)
    is_active = models.BooleanField(default=True, db_index=True)

    address = models.TextField(blank=True)
    place_name = models.CharField(max_length=255, blank=True)
    city = models.CharField(max_length=120, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    email = models.EmailField(blank=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)

    license_number = models.CharField(max_length=100, blank=True)
    bed_capacity = models.PositiveIntegerField(default=0)
    opening_hours = models.JSONField(
        default=dict, blank=True,
        help_text='Day-wise open/close hours, same shape as PharmacyDetail.operating_hours.',
    )
    services = models.JSONField(default=list, blank=True)
    manager = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='managed_clinic_sites',
    )
    notes = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_hq', 'name']
        verbose_name = 'Clinic Site'
        verbose_name_plural = 'Clinic Sites'
        constraints = [
            models.UniqueConstraint(
                fields=['is_hq'],
                condition=Q(is_hq=True),
                name='clinic_sites_single_hq_per_tenant',
            ),
        ]

    def __str__(self):
        return f'{self.name}{" (HQ)" if self.is_hq else ""}'

    def save(self, *args, **kwargs):
        if self.is_hq:
            # Demote any other HQ in this schema so the partial unique index
            # never fires and the tenant always has exactly one HQ.
            (
                ClinicSite.objects
                .filter(is_hq=True)
                .exclude(pk=self.pk)
                .update(is_hq=False)
            )
        if not self.code:
            self.code = self._suggest_code()
        super().save(*args, **kwargs)

    def _suggest_code(self) -> str:
        base = ''.join(ch for ch in (self.name or '').upper() if ch.isalnum())
        base = (base[:6] or 'CLIN')
        candidate = base
        n = 1
        while ClinicSite.objects.filter(code=candidate).exclude(pk=self.pk).exists():
            n += 1
            candidate = f'{base}{n}'
        return candidate

    @property
    def display_name(self) -> str:
        return f'{self.name} (HQ)' if self.is_hq else self.name
