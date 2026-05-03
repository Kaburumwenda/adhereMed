from django.db import models
from django.conf import settings


class DispensingRecord(models.Model):
    prescription_exchange_id = models.IntegerField(
        null=True, blank=True, help_text='FK to PrescriptionExchange (public schema)',
    )
    patient_user_id = models.IntegerField(help_text='FK to User (public schema)')
    patient_name = models.CharField(max_length=255)
    items_dispensed = models.JSONField(default=list, help_text='[{medication, qty, batch, price}]')
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    dispensed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='dispensing_records',
    )
    notes = models.TextField(blank=True)
    dispensed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-dispensed_at']

    def __str__(self):
        return f'Dispensed to {self.patient_name} - KSh {self.total}'
