from django.db import models
from django.conf import settings
from django.utils import timezone


class CorporateClient(models.Model):
    """A company that contracts the clinic for staff treatment (payer)."""

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending verification'
        ACTIVE = 'active', 'Active'
        SUSPENDED = 'suspended', 'Suspended'
        EXPIRED = 'expired', 'Contract expired'

    name = models.CharField(max_length=200, unique=True)
    code = models.CharField(max_length=30, blank=True, help_text='Short code used on invoices, e.g. ACME')
    registration_number = models.CharField(max_length=60, blank=True)
    industry = models.CharField(max_length=120, blank=True)

    contact_person = models.CharField(max_length=150, blank=True)
    contact_phone = models.CharField(max_length=30, blank=True)
    contact_email = models.EmailField(blank=True)
    address = models.TextField(blank=True)

    discount_rate = models.DecimalField(
        max_digits=5, decimal_places=2, default=0,
        help_text='Contractual discount % off list price for covered staff',
    )
    payment_terms_days = models.PositiveIntegerField(default=30)
    credit_limit = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    annual_limit_per_staff = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Default yearly cover per employee (0 = no cap)',
    )

    contract_start = models.DateField(null=True, blank=True)
    contract_end = models.DateField(null=True, blank=True)

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING, db_index=True)
    is_active = models.BooleanField(default=True)

    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='corporates_verified',
    )

    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        indexes = [models.Index(fields=['status', 'is_active'])]

    def __str__(self):
        return self.name

    @property
    def contract_valid(self):
        """True when the contract window covers today."""
        today = timezone.localdate()
        if self.contract_start and today < self.contract_start:
            return False
        if self.contract_end and today > self.contract_end:
            return False
        return True

    @property
    def is_verified(self):
        return self.status == self.Status.ACTIVE and self.verified_at is not None

    @property
    def can_cover_treatment(self):
        return self.is_active and self.status == self.Status.ACTIVE and self.contract_valid

    @property
    def active_staff_count(self):
        today = timezone.localdate()
        return self.staff.filter(
            status=CorporateStaff.Status.ACTIVE,
            verification_status=CorporateStaff.Verification.VERIFIED,
        ).filter(
            models.Q(valid_from__isnull=True) | models.Q(valid_from__lte=today),
        ).filter(
            models.Q(valid_to__isnull=True) | models.Q(valid_to__gte=today),
        ).count()

    @property
    def pending_document_count(self):
        return self.documents.filter(status=CorporateDocument.Status.PENDING).count()


class CorporateStaff(models.Model):
    """An employee (or dependant) of a corporate client, eligible for treatment.

    The corporate dashboard uploads/maintains this roster; reception verifies a
    visiting patient against it before billing the company.
    """

    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        SUSPENDED = 'suspended', 'Suspended'
        EXITED = 'exited', 'Left the company'

    class Verification(models.TextChoices):
        PENDING = 'pending', 'Pending verification'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'

    class Relationship(models.TextChoices):
        EMPLOYEE = 'employee', 'Employee'
        SPOUSE = 'spouse', 'Spouse'
        CHILD = 'child', 'Child'
        DEPENDANT = 'dependant', 'Dependant'

    corporate = models.ForeignKey(
        CorporateClient, on_delete=models.CASCADE, related_name='staff',
    )
    # Linked once the person is registered as a clinic patient.
    patient = models.ForeignKey(
        'patients.Patient', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='corporate_enrolments',
    )

    staff_number = models.CharField(
        max_length=60, help_text='Employee / payroll number on the job card',
    )
    full_name = models.CharField(max_length=200)
    relationship = models.CharField(
        max_length=20, choices=Relationship.choices, default=Relationship.EMPLOYEE,
    )
    job_title = models.CharField(max_length=120, blank=True)
    department = models.CharField(max_length=120, blank=True)

    phone = models.CharField(max_length=30, blank=True)
    email = models.EmailField(blank=True)
    national_id = models.CharField(max_length=30, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, blank=True)

    annual_limit = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Yearly cover for this member (0 = use the corporate default)',
    )
    valid_from = models.DateField(null=True, blank=True)
    valid_to = models.DateField(null=True, blank=True)

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE, db_index=True)
    verification_status = models.CharField(
        max_length=20, choices=Verification.choices, default=Verification.PENDING, db_index=True,
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='corporate_staff_verified',
    )
    rejection_reason = models.CharField(max_length=255, blank=True)

    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['full_name']
        constraints = [
            models.UniqueConstraint(
                fields=['corporate', 'staff_number'], name='uniq_corporate_staff_number',
            ),
        ]
        indexes = [
            models.Index(fields=['corporate', 'status']),
            models.Index(fields=['staff_number']),
        ]

    def __str__(self):
        return f'{self.full_name} ({self.staff_number})'

    @property
    def is_eligible(self):
        """Active, verified and inside the cover window."""
        if self.status != self.Status.ACTIVE:
            return False
        if self.verification_status != self.Verification.VERIFIED:
            return False
        today = timezone.localdate()
        if self.valid_from and today < self.valid_from:
            return False
        if self.valid_to and today > self.valid_to:
            return False
        return True

    @property
    def ineligibility_reason(self):
        if self.status != self.Status.ACTIVE:
            return f'Staff record is {self.get_status_display().lower()}.'
        if self.verification_status != self.Verification.VERIFIED:
            return f'Staff record is {self.get_verification_display().lower()}.'
        today = timezone.localdate()
        if self.valid_from and today < self.valid_from:
            return f'Cover starts {self.valid_from:%d %b %Y}.'
        if self.valid_to and today > self.valid_to:
            return f'Cover expired {self.valid_to:%d %b %Y}.'
        return ''


class CorporateDocument(models.Model):
    """Verification paperwork (job card, contract, authorisation letter…)."""

    class DocType(models.TextChoices):
        JOB_CARD = 'job_card', 'Job card'
        CONTRACT = 'contract', 'Service contract'
        AUTH_LETTER = 'authorisation_letter', 'Authorisation letter'
        STAFF_LIST = 'staff_list', 'Staff list'
        TAX_CERT = 'tax_certificate', 'Tax certificate'
        OTHER = 'other', 'Other'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending verification'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'

    corporate = models.ForeignKey(
        CorporateClient, on_delete=models.CASCADE, related_name='documents',
    )
    staff = models.ForeignKey(
        CorporateStaff, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='documents',
    )

    doc_type = models.CharField(max_length=30, choices=DocType.choices, default=DocType.JOB_CARD, db_index=True)
    title = models.CharField(max_length=200, blank=True)
    file = models.FileField(upload_to='corporate/documents/', blank=True, null=True)
    reference = models.CharField(max_length=120, blank=True)

    issued_at = models.DateField(null=True, blank=True)
    expires_at = models.DateField(null=True, blank=True)

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING, db_index=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='corporate_documents_verified',
    )
    rejection_reason = models.CharField(max_length=255, blank=True)

    notes = models.TextField(blank=True)
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='corporate_documents_uploaded',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['corporate', 'doc_type', 'status'])]

    def __str__(self):
        return self.title or f'{self.get_doc_type_display()} — {self.corporate.name}'

    @property
    def is_expired(self):
        return bool(self.expires_at and self.expires_at < timezone.localdate())

    def save(self, *args, **kwargs):
        if not self.title:
            self.title = self.get_doc_type_display()
        super().save(*args, **kwargs)
