from django.db import models
from django.conf import settings


class Consultation(models.Model):
    appointment = models.OneToOneField(
        'appointments.Appointment', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='consultation',
    )
    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='consultations')
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='consultations_as_doctor',
    )
    chief_complaint = models.TextField()
    history_present_illness = models.TextField(blank=True)
    examination_findings = models.TextField(blank=True)
    diagnosis = models.JSONField(default=list, blank=True, help_text='ICD-10 codes and descriptions')
    treatment_plan = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    vital_signs = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Consultation #{self.id} - {self.patient}'
