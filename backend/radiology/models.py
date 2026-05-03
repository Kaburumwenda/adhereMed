from django.db import models
from django.conf import settings


class RadiologyOrder(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class ImagingType(models.TextChoices):
        XRAY = 'xray', 'X-Ray'
        CT = 'ct', 'CT Scan'
        MRI = 'mri', 'MRI'
        ULTRASOUND = 'ultrasound', 'Ultrasound'
        MAMMOGRAM = 'mammogram', 'Mammogram'
        FLUOROSCOPY = 'fluoroscopy', 'Fluoroscopy'
        OTHER = 'other', 'Other'

    consultation = models.ForeignKey(
        'consultations.Consultation', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='radiology_orders',
    )
    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='radiology_orders')
    ordered_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='radiology_orders_created')
    imaging_type = models.CharField(max_length=20, choices=ImagingType.choices)
    body_part = models.CharField(max_length=255)
    clinical_indication = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    priority = models.CharField(max_length=10, default='routine')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.get_imaging_type_display()} - {self.body_part} ({self.patient})'


class RadiologyResult(models.Model):
    order = models.OneToOneField(RadiologyOrder, on_delete=models.CASCADE, related_name='result')
    findings = models.TextField()
    impression = models.TextField(blank=True)
    radiologist = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='radiology_results',
    )
    image_url = models.URLField(blank=True)
    result_date = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Result for {self.order}'
