from django.db import models


# ─────────────────────────────────────────────────────────
# Tenant-scoped clinic catalog (Allergies & Chronic Conditions)
# ─────────────────────────────────────────────────────────
class ClinicAllergy(models.Model):
    """Per-tenant allergy catalog. Seeded from the global clinical_catalog
    (public schema) and editable by the tenant's clinic admin."""

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
        verbose_name = 'Clinic allergy'
        verbose_name_plural = 'Clinic allergies'
        constraints = [
            models.UniqueConstraint(fields=['name'], name='uniq_clinic_allergy_name'),
        ]

    def __str__(self):
        return self.name


class ClinicChronicCondition(models.Model):
    """Per-tenant chronic-condition catalog. Seeded from the global
    clinical_catalog and editable by the tenant's clinic admin."""

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
        verbose_name = 'Clinic chronic condition'
        verbose_name_plural = 'Clinic chronic conditions'
        constraints = [
            models.UniqueConstraint(fields=['name'], name='uniq_clinic_condition_name'),
        ]

    def __str__(self):
        return f'{self.name}{" [" + self.icd_code + "]" if self.icd_code else ""}'
