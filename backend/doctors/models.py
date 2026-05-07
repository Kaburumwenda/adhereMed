from django.db import models
from django.conf import settings


class DoctorProfile(models.Model):
    """
    Public doctor profile visible to patients.
    Doctors can be independent or affiliated with a hospital tenant.
    Stored in the public (shared) schema so patients can browse all doctors.
    """
    class PracticeType(models.TextChoices):
        INDEPENDENT = 'independent', 'Independent'
        HOSPITAL = 'hospital', 'Hospital-Affiliated'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='doctor_profile',
    )
    practice_type = models.CharField(
        max_length=20, choices=PracticeType.choices, default=PracticeType.INDEPENDENT,
    )
    hospital = models.ForeignKey(
        'tenants.Tenant', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='doctors',
        help_text='Hospital tenant (if affiliated)',
    )
    specialization = models.CharField(max_length=255)
    license_number = models.CharField(max_length=100)
    qualification = models.CharField(max_length=255, blank=True)
    years_of_experience = models.PositiveIntegerField(default=0)
    bio = models.TextField(blank=True)
    consultation_fee = models.DecimalField(
        max_digits=10, decimal_places=2, default=0,
    )
    is_accepting_patients = models.BooleanField(default=True)
    is_verified = models.BooleanField(default=False)
    languages = models.JSONField(default=list, blank=True)
    available_days = models.JSONField(
        default=list, blank=True,
        help_text='e.g. ["Monday","Tuesday","Wednesday"]',
    )
    available_hours = models.JSONField(
        default=dict, blank=True,
        help_text='e.g. {"start": "08:00", "end": "17:00"}',
    )
    profile_picture = models.ImageField(
        upload_to='doctor_pictures/', blank=True, null=True,
    )
    signature = models.ImageField(
        upload_to='doctor_signatures/', blank=True, null=True,
        help_text='Doctor\'s digital signature image (PNG)',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Dr. {self.user.full_name} - {self.specialization}'
