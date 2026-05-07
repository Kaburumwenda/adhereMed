from django.db import models


class Allergy(models.Model):
    class Category(models.TextChoices):
        DRUG = 'drug', 'Drug / Medication'
        FOOD = 'food', 'Food'
        ENVIRONMENTAL = 'environmental', 'Environmental'
        INSECT = 'insect', 'Insect / Venom'
        LATEX = 'latex', 'Latex'
        CONTRAST = 'contrast', 'Contrast / Dye'
        CHEMICAL = 'chemical', 'Chemical'
        OTHER = 'other', 'Other'

    name = models.CharField(max_length=255, unique=True, db_index=True)
    category = models.CharField(max_length=20, choices=Category.choices, db_index=True)
    description = models.TextField(blank=True)
    common_symptoms = models.TextField(
        blank=True,
        help_text='Comma-separated list of common symptoms',
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'name']
        verbose_name = 'Allergy'
        verbose_name_plural = 'Allergies'

    def __str__(self):
        return f'{self.name} ({self.get_category_display()})'


class ChronicCondition(models.Model):
    class Category(models.TextChoices):
        CARDIOVASCULAR = 'cardiovascular', 'Cardiovascular'
        ENDOCRINE = 'endocrine', 'Endocrine / Metabolic'
        RESPIRATORY = 'respiratory', 'Respiratory'
        NEUROLOGICAL = 'neurological', 'Neurological'
        MUSCULOSKELETAL = 'musculoskeletal', 'Musculoskeletal'
        GASTROINTESTINAL = 'gastrointestinal', 'Gastrointestinal'
        RENAL = 'renal', 'Renal / Urological'
        HEMATOLOGICAL = 'hematological', 'Hematological'
        IMMUNOLOGICAL = 'immunological', 'Immunological / Infectious'
        MENTAL_HEALTH = 'mental_health', 'Mental Health'
        ONCOLOGICAL = 'oncological', 'Oncological'
        DERMATOLOGICAL = 'dermatological', 'Dermatological'
        OPHTHALMOLOGICAL = 'ophthalmological', 'Ophthalmological'
        OTHER = 'other', 'Other'

    name = models.CharField(max_length=255, unique=True, db_index=True)
    category = models.CharField(max_length=20, choices=Category.choices, db_index=True)
    icd_code = models.CharField(
        max_length=20, blank=True, db_index=True,
        help_text='ICD-10 code, e.g. E11 for Type 2 Diabetes',
    )
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'name']
        verbose_name = 'Chronic Condition'
        verbose_name_plural = 'Chronic Conditions'

    def __str__(self):
        label = f' [{self.icd_code}]' if self.icd_code else ''
        return f'{self.name}{label}'
