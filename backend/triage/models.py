from django.db import models
from django.conf import settings


class Triage(models.Model):
    class ESILevel(models.IntegerChoices):
        RESUSCITATION = 1, 'Level 1 - Resuscitation'
        EMERGENT = 2, 'Level 2 - Emergent'
        URGENT = 3, 'Level 3 - Urgent'
        LESS_URGENT = 4, 'Level 4 - Less Urgent'
        NON_URGENT = 5, 'Level 5 - Non-Urgent'

    class ArrivalMode(models.TextChoices):
        WALK_IN = 'walk_in', 'Walk-in'
        AMBULANCE = 'ambulance', 'Ambulance'
        REFERRAL = 'referral', 'Referral'
        POLICE = 'police', 'Police'

    class AVPU(models.TextChoices):
        ALERT = 'alert', 'Alert'
        VOICE = 'voice', 'Responds to Voice'
        PAIN = 'pain', 'Responds to Pain'
        UNRESPONSIVE = 'unresponsive', 'Unresponsive'

    class TriageStatus(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        COMPLETED = 'completed', 'Completed'

    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='triages')
    nurse = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='triages_performed')
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='triages_assigned',
        help_text='Doctor assigned to receive this patient after triage',
    )
    esi_level = models.IntegerField(choices=ESILevel.choices, null=True, blank=True)
    suggested_esi = models.IntegerField(choices=ESILevel.choices, null=True, blank=True,
                                        help_text='System-suggested ESI based on NEWS2')
    esi_override_reason = models.TextField(blank=True, help_text='Reason if nurse overrode system suggestion')
    chief_complaint = models.TextField(blank=True)
    vital_signs = models.JSONField(default=dict, help_text='BP, temp, pulse, resp rate, O2 sat, weight, height, blood_sugar')
    arrival_mode = models.CharField(max_length=20, choices=ArrivalMode.choices, default=ArrivalMode.WALK_IN)
    pain_scale = models.IntegerField(default=0, help_text='0-10 scale')
    avpu = models.CharField(max_length=20, choices=AVPU.choices, default=AVPU.ALERT)
    news2_score = models.IntegerField(default=0, help_text='Auto-calculated NEWS2 score')
    bmi = models.FloatField(null=True, blank=True, help_text='Auto-calculated from height/weight')
    allergies_confirmed = models.BooleanField(default=False)
    allergies_updated = models.JSONField(default=list, blank=True, help_text='Confirmed/updated allergies list')
    medication_history = models.JSONField(default=list, blank=True, help_text='Confirmed medication list')
    pregnancy_status = models.CharField(max_length=20, blank=True, default='')
    mental_health_screen = models.JSONField(default=dict, blank=True, help_text='Mental health screening notes')
    smoking_status = models.CharField(max_length=20, blank=True, default='')
    alcohol_use = models.CharField(max_length=20, blank=True, default='')
    substance_use = models.CharField(max_length=20, blank=True, default='')
    nutrition_screen = models.JSONField(default=dict, blank=True)
    fall_risk = models.CharField(max_length=20, blank=True, default='')
    infection_risk = models.JSONField(default=dict, blank=True)
    nursing_assessment = models.TextField(blank=True)
    interventions = models.TextField(blank=True)
    patient_education = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=TriageStatus.choices, default=TriageStatus.DRAFT)
    triage_time = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['esi_level', 'triage_time']

    def __str__(self):
        return f'{self.patient} - ESI {self.esi_level or "?"}'
