from django.db import models


class Medication(models.Model):
    class DosageForm(models.TextChoices):
        TABLET = 'tablet', 'Tablet'
        CAPSULE = 'capsule', 'Capsule'
        SYRUP = 'syrup', 'Syrup'
        INJECTION = 'injection', 'Injection'
        CREAM = 'cream', 'Cream'
        OINTMENT = 'ointment', 'Ointment'
        DROPS = 'drops', 'Drops'
        INHALER = 'inhaler', 'Inhaler'
        SUPPOSITORY = 'suppository', 'Suppository'
        SUSPENSION = 'suspension', 'Suspension'
        POWDER = 'powder', 'Powder'
        GEL = 'gel', 'Gel'
        PATCH = 'patch', 'Patch'
        LOZENGE = 'lozenge', 'Lozenge'
        SPRAY = 'spray', 'Spray'
        SOLUTION = 'solution', 'Solution'
        OTHER = 'other', 'Other'

    class Category(models.TextChoices):
        ANALGESIC = 'analgesic', 'Analgesic / Pain Reliever'
        ANTIBIOTIC = 'antibiotic', 'Antibiotic'
        ANTIFUNGAL = 'antifungal', 'Antifungal'
        ANTIVIRAL = 'antiviral', 'Antiviral'
        ANTIPARASITIC = 'antiparasitic', 'Antiparasitic'
        ANTIMALARIAL = 'antimalarial', 'Antimalarial'
        ANTIHYPERTENSIVE = 'antihypertensive', 'Antihypertensive'
        ANTIDIABETIC = 'antidiabetic', 'Antidiabetic'
        ANTIHISTAMINE = 'antihistamine', 'Antihistamine'
        ANTACID = 'antacid', 'Antacid / GI'
        CARDIOVASCULAR = 'cardiovascular', 'Cardiovascular'
        RESPIRATORY = 'respiratory', 'Respiratory'
        CNS = 'cns', 'Central Nervous System'
        HORMONE = 'hormone', 'Hormonal'
        VITAMIN = 'vitamin', 'Vitamin / Supplement'
        VACCINE = 'vaccine', 'Vaccine'
        DERMATOLOGICAL = 'dermatological', 'Dermatological'
        OPHTHALMIC = 'ophthalmic', 'Ophthalmic'
        ONCOLOGY = 'oncology', 'Oncology'
        IMMUNOSUPPRESSANT = 'immunosuppressant', 'Immunosuppressant'
        NSAID = 'nsaid', 'NSAID'
        OTHER = 'other', 'Other'

    generic_name = models.CharField(max_length=255, db_index=True)
    abbreviation = models.CharField(max_length=20, blank=True, db_index=True,
                                    help_text='Short code/abbreviation, e.g. PCM, AMOX, RHZE')
    brand_names = models.JSONField(default=list, blank=True)
    category = models.CharField(max_length=30, choices=Category.choices, db_index=True)
    subcategory = models.CharField(max_length=100, blank=True)
    dosage_form = models.CharField(max_length=20, choices=DosageForm.choices)
    strength = models.CharField(max_length=100, blank=True)
    unit = models.CharField(max_length=50, blank=True)
    description = models.TextField(blank=True)
    requires_prescription = models.BooleanField(default=True)
    controlled_substance_class = models.CharField(max_length=20, blank=True, help_text='e.g. Schedule II')
    side_effects = models.TextField(blank=True)
    contraindications = models.TextField(blank=True)
    interactions = models.TextField(blank=True, help_text='Free-text interaction notes')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['generic_name']
        indexes = [
            models.Index(fields=['generic_name', 'category']),
        ]

    def __str__(self):
        strength = f' {self.strength}' if self.strength else ''
        return f'{self.generic_name}{strength} ({self.get_dosage_form_display()})'


class DrugInteraction(models.Model):
    """Pairwise drug-drug interaction database. Lookups are bidirectional."""
    class Severity(models.TextChoices):
        MINOR = 'minor', 'Minor'
        MODERATE = 'moderate', 'Moderate'
        MAJOR = 'major', 'Major'
        CONTRAINDICATED = 'contraindicated', 'Contraindicated'

    drug_a = models.ForeignKey(
        Medication, on_delete=models.CASCADE, related_name='interactions_a',
    )
    drug_b = models.ForeignKey(
        Medication, on_delete=models.CASCADE, related_name='interactions_b',
    )
    severity = models.CharField(max_length=20, choices=Severity.choices, default=Severity.MODERATE)
    description = models.TextField(help_text='What happens when these drugs interact')
    clinical_advice = models.TextField(blank=True, help_text='Recommended action / monitoring')
    source = models.CharField(max_length=255, blank=True, help_text='Reference / citation')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-severity', 'drug_a__generic_name']
        indexes = [
            models.Index(fields=['drug_a', 'drug_b']),
            models.Index(fields=['severity']),
        ]
        constraints = [
            models.UniqueConstraint(fields=['drug_a', 'drug_b'], name='uniq_drug_pair'),
        ]

    def __str__(self):
        return f'{self.drug_a} ↔ {self.drug_b} ({self.severity})'
