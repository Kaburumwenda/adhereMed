from django.db import models
from tenants.models import Tenant


class Organization(models.Model):
    """A parent organization that groups multiple tenants together.

    Lives in the public (shared) schema so it's accessible from any
    tenant context.  An org admin user logs in and sees the Command
    Center dashboard with aggregated stats across all linked tenants.
    """
    name = models.CharField(max_length=255)
    slug = models.SlugField(unique=True)
    logo = models.ImageField(upload_to='org_logos/', blank=True, null=True)
    motto = models.CharField(max_length=200, blank=True)
    address = models.TextField(blank=True)
    city = models.CharField(max_length=100, blank=True)
    country = models.CharField(max_length=100, default='Kenya')
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    website = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class OrganizationMembership(models.Model):
    """Through-model linking a Tenant to an Organization.

    A tenant can belong to multiple organizations (future-proof).
    ``is_active`` lets you temporarily disable a link without deleting.
    """
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE,
        related_name='memberships')
    tenant = models.ForeignKey(
        Tenant, on_delete=models.CASCADE,
        related_name='org_memberships')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [('organization', 'tenant')]
        ordering = ['organization', 'tenant']

    def __str__(self):
        return f'{self.organization.name} → {self.tenant.name}'
