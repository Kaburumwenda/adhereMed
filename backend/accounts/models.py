from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
import secrets
from .managers import UserManager


def _generate_unique_pin(length: int = 6) -> str:
    """Generate a numeric PIN that doesn't collide with any existing user."""
    for _ in range(50):
        candidate = ''.join(str(secrets.randbelow(10)) for _ in range(length))
        if not User.objects.filter(pin=candidate).exists():
            return candidate
    # extreme fallback: longer pin
    return ''.join(str(secrets.randbelow(10)) for _ in range(length + 2))


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        SUPER_ADMIN = 'super_admin', 'Super Admin'
        TENANT_ADMIN = 'tenant_admin', 'Tenant Admin'
        DOCTOR = 'doctor', 'Doctor'
        CLINICAL_OFFICER = 'clinical_officer', 'Clinical Officer'
        DENTIST = 'dentist', 'Dentist'
        NURSE = 'nurse', 'Nurse'
        MIDWIFE = 'midwife', 'Midwife'
        LAB_TECH = 'lab_tech', 'Lab Technologist'
        RADIOLOGIST = 'radiologist', 'Radiologist'
        PHARMACIST = 'pharmacist', 'Pharmacist'
        PHARMACY_TECH = 'pharmacy_tech', 'Pharmacy Technician'
        CASHIER = 'cashier', 'Cashier'
        RECEPTIONIST = 'receptionist', 'Receptionist'
        HOMECARE_ADMIN = 'homecare_admin', 'Homecare Admin'
        CAREGIVER = 'caregiver', 'Caregiver'
        PATIENT = 'patient', 'Patient'

    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=20, blank=True)
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.PATIENT)
    tenant = models.ForeignKey(
        'tenants.Tenant',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='users',
    )
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    pin = models.CharField(
        max_length=12,
        unique=True,
        null=True,
        blank=True,
        help_text='Unique 6-digit PIN used to acknowledge sensitive actions.',
    )
    date_joined = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    class Meta:
        ordering = ['first_name', 'last_name']

    def __str__(self):
        return f'{self.first_name} {self.last_name}'

    @property
    def full_name(self):
        return f'{self.first_name} {self.last_name}'

    def save(self, *args, **kwargs):
        if not self.pin:
            self.pin = _generate_unique_pin()
        super().save(*args, **kwargs)
