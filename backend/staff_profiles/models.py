from django.db import models
from django.conf import settings


class Specialization(models.Model):
    name = models.CharField(max_length=255, unique=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class StaffProfile(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='staff_profile',
    )
    department = models.ForeignKey(
        'departments.Department', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='staff',
    )
    specialization = models.ForeignKey(
        Specialization, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='staff_profiles',
    )
    license_number = models.CharField(max_length=100, blank=True)
    qualification = models.CharField(max_length=255, blank=True)
    years_of_experience = models.PositiveIntegerField(default=0)
    bio = models.TextField(blank=True)
    schedule = models.JSONField(default=dict, blank=True, help_text='Weekly schedule config')
    is_available = models.BooleanField(default=True)
    branch = models.ForeignKey(
        'pharmacy_profile.Branch',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='staff',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        spec = self.specialization.name if self.specialization else 'No specialization'
        return f'{self.user.full_name} - {spec}'
