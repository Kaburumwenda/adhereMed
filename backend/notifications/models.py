from django.db import models
from django.conf import settings


class Notification(models.Model):
    class NotificationType(models.TextChoices):
        APPOINTMENT = 'appointment', 'Appointment'
        LAB_RESULT = 'lab_result', 'Lab Result'
        PRESCRIPTION = 'prescription', 'Prescription'
        HOME_COLLECTION = 'home_collection', 'Home Collection'
        BILLING = 'billing', 'Billing'
        SYSTEM = 'system', 'System'

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications',
    )
    type = models.CharField(max_length=20, choices=NotificationType.choices)
    title = models.CharField(max_length=255)
    message = models.TextField()
    data = models.JSONField(default=dict, blank=True, help_text='Extra context: IDs, links, etc.')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.title} → {self.recipient}'
