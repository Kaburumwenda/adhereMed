from django.db import models


class ClinicRoleDefinition(models.Model):
    """A clinic's own version of a role.

    Two jobs, mirroring the inventory and OHS modules:

    * **custom role** — ``is_system=False``. A role this clinic invented; the
      ``key`` is stored directly in ``User.role`` (a plain string, not an FK),
      which is why the key is short, slug-safe and globally unique.
    * **built-in override** — ``is_system=True``. The clinic decided its
      receptionists need slightly more (or less) than the platform default.
      Deleting the row restores the default.

    ``lab`` and the other clinic apps are TENANT_APPS, so these rows live in the
    clinic's own schema — one clinic can never see or influence another's roles.
    """

    key = models.SlugField(
        max_length=20, unique=True,
        help_text='Stored on User.role — short, lowercase, underscore-separated.',
    )
    label = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    icon = models.CharField(
        max_length=60, default='mdi-badge-account-horizontal-outline',
    )
    capabilities = models.JSONField(
        default=list, help_text='List of capability keys granted to this role.',
    )
    #: True when this row overrides a built-in role rather than defining a new one.
    is_system = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['label']
        verbose_name = 'clinic role definition'

    def __str__(self):
        return f'{self.label} ({self.key})'

    @property
    def capability_count(self):
        return len(self.capabilities or [])
