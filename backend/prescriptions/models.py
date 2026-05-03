from django.db import models
from django.conf import settings


class Prescription(models.Model):
    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        SENT_TO_EXCHANGE = 'sent_to_exchange', 'Sent to Exchange'
        DISPENSED = 'dispensed', 'Dispensed'
        CANCELLED = 'cancelled', 'Cancelled'

    consultation = models.ForeignKey(
        'consultations.Consultation', on_delete=models.CASCADE, related_name='prescriptions',
        null=True, blank=True,
    )
    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='prescriptions')
    doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='prescriptions_written',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Rx #{self.id} - {self.patient}'


class PrescriptionItem(models.Model):
    prescription = models.ForeignKey(Prescription, on_delete=models.CASCADE, related_name='items')
    medication_id = models.IntegerField(
        null=True, blank=True, help_text='FK to global Medication (public schema)',
    )
    medication_name = models.CharField(max_length=255, help_text='Cached or custom medication name')
    custom_medication_name = models.CharField(max_length=255, blank=True, help_text='If medication not in pool')
    is_custom = models.BooleanField(default=False)
    dosage = models.CharField(max_length=100)
    frequency = models.CharField(max_length=100, help_text='e.g., 3 times daily')
    duration = models.CharField(max_length=100, help_text='e.g., 7 days')
    quantity = models.PositiveIntegerField(default=1)
    instructions = models.TextField(blank=True, help_text='e.g., Take after meals')

    def __str__(self):
        name = self.custom_medication_name if self.is_custom else self.medication_name
        return f'{name} - {self.dosage} x {self.frequency}'


# ─── Pharmacy Prescription (walk-in / manual patient) ─────────────────────────

class PharmacyPrescription(models.Model):
    """Prescription issued by a pharmacist for a walk-in patient (no registered patient FK)."""

    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        DISPENSED = 'dispensed', 'Dispensed'
        CANCELLED = 'cancelled', 'Cancelled'

    patient_name = models.CharField(max_length=255)
    patient_phone = models.CharField(max_length=30, blank=True)
    pharmacist = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='pharmacy_prescriptions_written',
    )
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Pharmacy Rx #{self.id} - {self.patient_name}'


class PharmacyPrescriptionItem(models.Model):
    prescription = models.ForeignKey(
        PharmacyPrescription, on_delete=models.CASCADE, related_name='items',
    )
    medication_name = models.CharField(max_length=255, help_text='Free-text or selected from inventory')
    stock_id = models.IntegerField(null=True, blank=True, help_text='FK to tenant inventory MedicationStock')
    dosage = models.CharField(max_length=100, blank=True)
    frequency = models.CharField(max_length=100, blank=True, help_text='e.g., 3 times daily')
    duration = models.CharField(max_length=100, blank=True, help_text='e.g., 7 days')
    quantity = models.PositiveIntegerField(default=1)
    instructions = models.TextField(blank=True, help_text='e.g., Take after meals, avoid alcohol')

    def __str__(self):
        return f'{self.medication_name} - {self.dosage}'
