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

    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='triages')
    nurse = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='triages_performed')
    esi_level = models.IntegerField(choices=ESILevel.choices)
    chief_complaint = models.TextField()
    vital_signs = models.JSONField(default=dict, help_text='BP, temp, pulse, resp rate, O2 sat, weight')
    arrival_mode = models.CharField(max_length=20, choices=ArrivalMode.choices, default=ArrivalMode.WALK_IN)
    pain_scale = models.IntegerField(default=0, help_text='0-10 scale')
    notes = models.TextField(blank=True)
    triage_time = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['esi_level', 'triage_time']

    def __str__(self):
        return f'{self.patient} - ESI {self.esi_level}'
