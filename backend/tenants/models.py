from django.db import models
from django_tenants.models import TenantMixin, DomainMixin


class Tenant(TenantMixin):
    class TenantType(models.TextChoices):
        HOSPITAL = 'hospital', 'Hospital'
        PHARMACY = 'pharmacy', 'Pharmacy'
        LAB = 'lab', 'Laboratory'

    name = models.CharField(max_length=255)
    type = models.CharField(max_length=20, choices=TenantType.choices)
    slug = models.SlugField(unique=True)
    logo = models.ImageField(upload_to='tenant_logos/', blank=True, null=True)
    address = models.TextField(blank=True)
    city = models.CharField(max_length=100, blank=True)
    country = models.CharField(max_length=100, default='Kenya')
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    website = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    auto_create_schema = True

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f'{self.name} ({self.get_type_display()})'


class Domain(DomainMixin):
    pass
