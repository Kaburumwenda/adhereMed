from django.db import models
from django.conf import settings


class Consultation(models.Model):
    class ConsultationStatus(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        SIGNED = 'signed', 'Signed'
        LOCKED = 'locked', 'Locked'

    class Disposition(models.TextChoices):
        DISCHARGE = 'discharge', 'Discharge'
        REFERRAL = 'referral', 'Referral'
        ADMISSION = 'admission', 'Admission'
        OBSERVATION = 'observation', 'Observation'
        TRANSFER = 'transfer', 'Transfer'
        LEFT_AMA = 'left_ama', 'Left Against Medical Advice'
        PENDING = 'pending', 'Pending'

    appointment = models.OneToOneField(
        'appointments.Appointment', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='consultation',
    )
    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='consultations')
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='consultations_as_doctor',
    )
    triage = models.OneToOneField(
        'triage.Triage', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='consultation',
    )
    status = models.CharField(
        max_length=20, choices=ConsultationStatus.choices, default=ConsultationStatus.DRAFT,
    )
    chief_complaint = models.TextField(blank=True)
    history_present_illness = models.TextField(blank=True)
    review_of_systems = models.JSONField(default=dict, blank=True, help_text='ROS checklist by system')
    past_medical_history = models.TextField(blank=True)
    surgical_history = models.TextField(blank=True)
    family_history = models.TextField(blank=True)
    social_history = models.TextField(blank=True)
    medication_history = models.JSONField(default=list, blank=True, help_text='Reconciled medications')
    allergies_confirmed = models.JSONField(default=list, blank=True, help_text='Confirmed allergies')
    examination_findings = models.TextField(blank=True)
    assessment = models.TextField(blank=True, help_text='Clinical assessment narrative')
    differential_diagnosis = models.JSONField(default=list, blank=True)
    diagnosis = models.JSONField(default=list, blank=True, help_text='ICD-10 codes and descriptions')
    clinical_decision_making = models.TextField(blank=True)
    treatment_plan = models.TextField(blank=True)
    disposition = models.CharField(
        max_length=20, choices=Disposition.choices, default=Disposition.PENDING,
    )
    notes = models.TextField(blank=True)
    vital_signs = models.JSONField(default=dict, blank=True)
    draft_owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='consultation_drafts',
    )
    signed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Consultation #{self.id} - {self.patient}'


class ConsultationAddendum(models.Model):
    consultation = models.ForeignKey(Consultation, on_delete=models.CASCADE, related_name='addenda')
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='consultation_addenda')
    content = models.TextField()
    signed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['signed_at']

    def __str__(self):
        return f'Addendum to Consultation #{self.consultation_id} by {self.author}'
