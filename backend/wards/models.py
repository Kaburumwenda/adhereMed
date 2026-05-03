from django.db import models
from django.conf import settings


class Ward(models.Model):
    class WardType(models.TextChoices):
        GENERAL = 'general', 'General'
        ICU = 'icu', 'ICU'
        MATERNITY = 'maternity', 'Maternity'
        PEDIATRIC = 'pediatric', 'Pediatric'
        SURGICAL = 'surgical', 'Surgical'
        EMERGENCY = 'emergency', 'Emergency'
        PRIVATE = 'private', 'Private'

    name = models.CharField(max_length=255)
    type = models.CharField(max_length=20, choices=WardType.choices)
    floor = models.CharField(max_length=50, blank=True)
    capacity = models.PositiveIntegerField()
    daily_rate = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f'{self.name} ({self.get_type_display()})'

    @property
    def available_beds(self):
        return self.beds.filter(status='available').count()


class Bed(models.Model):
    class Status(models.TextChoices):
        AVAILABLE = 'available', 'Available'
        OCCUPIED = 'occupied', 'Occupied'
        MAINTENANCE = 'maintenance', 'Maintenance'
        RESERVED = 'reserved', 'Reserved'

    ward = models.ForeignKey(Ward, on_delete=models.CASCADE, related_name='beds')
    bed_number = models.CharField(max_length=20)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.AVAILABLE)

    class Meta:
        unique_together = ('ward', 'bed_number')
        ordering = ['ward', 'bed_number']

    def __str__(self):
        return f'{self.ward.name} - Bed {self.bed_number}'


class Admission(models.Model):
    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        DISCHARGED = 'discharged', 'Discharged'
        TRANSFERRED = 'transferred', 'Transferred'

    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='admissions')
    bed = models.ForeignKey(Bed, on_delete=models.SET_NULL, null=True, related_name='admissions')
    admitting_doctor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='admissions_made',
    )
    admission_date = models.DateTimeField()
    discharge_date = models.DateTimeField(null=True, blank=True)
    reason = models.TextField()
    discharge_summary = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-admission_date']

    def __str__(self):
        return f'{self.patient} - {self.bed}'
