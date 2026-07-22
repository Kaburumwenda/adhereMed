from django.db import models
from django.conf import settings


def generate_patient_id():
    """Generate the next incremental AdhereMed patient id: AD01, AD02, ...

    Numbers are zero-padded to a minimum of two digits and grow as needed
    (AD99 -> AD100). Scoped to the current database schema (tenant).
    """
    max_n = 0
    for pid in Patient.objects.filter(patient_id__startswith='AD').values_list('patient_id', flat=True):
        try:
            n = int(pid[2:])
        except (TypeError, ValueError):
            continue
        if n > max_n:
            max_n = n
    return f'AD{max_n + 1:02d}'


class Patient(models.Model):
    class Gender(models.TextChoices):
        MALE = 'male', 'Male'
        FEMALE = 'female', 'Female'
        OTHER = 'other', 'Other'

    class BloodType(models.TextChoices):
        A_POS = 'A+', 'A+'
        A_NEG = 'A-', 'A-'
        B_POS = 'B+', 'B+'
        B_NEG = 'B-', 'B-'
        AB_POS = 'AB+', 'AB+'
        AB_NEG = 'AB-', 'AB-'
        O_POS = 'O+', 'O+'
        O_NEG = 'O-', 'O-'

    class RegistrationSource(models.TextChoices):
        SELF = 'self', 'Self registration'
        HOMECARE = 'homecare', 'Homecare'
        HOSPITAL = 'hospital', 'Hospital'
        CLINIC = 'clinic', 'Clinic'
        PHARMACY = 'pharmacy', 'Pharmacy'
        RADIOLOGY = 'radiology', 'Radiology'
        LAB = 'lab', 'Laboratory'
        DOCTOR = 'doctor', 'Doctor'
        OTHER = 'other', 'Other'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='patient_profile',
    )
    patient_id = models.CharField(
        max_length=20, unique=True, db_index=True, blank=True,
        help_text='Auto-generated AdhereMed patient identifier (AD01, AD02, ...).',
    )
    patient_number = models.CharField(max_length=20, unique=True, db_index=True)
    registration_source = models.CharField(
        max_length=20, choices=RegistrationSource.choices,
        default=RegistrationSource.SELF, db_index=True,
        help_text='How the patient first got registered on AdhereMed.',
    )
    date_of_birth = models.DateField()
    gender = models.CharField(max_length=10, choices=Gender.choices)
    blood_type = models.CharField(max_length=5, choices=BloodType.choices, blank=True)
    national_id = models.CharField(max_length=30, unique=True, null=True, blank=True)
    address = models.TextField(blank=True)
    allergies = models.JSONField(default=list, blank=True)
    chronic_conditions = models.JSONField(default=list, blank=True)
    emergency_contact_name = models.CharField(max_length=255, blank=True)
    emergency_contact_phone = models.CharField(max_length=20, blank=True)
    emergency_contact_relation = models.CharField(max_length=50, blank=True)
    insurance_provider = models.CharField(max_length=255, blank=True)
    insurance_number = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.patient_id:
            self.patient_id = generate_patient_id()
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.user.full_name} ({self.patient_id or self.patient_number})'
