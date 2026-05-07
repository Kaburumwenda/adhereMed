from django.db import models
from django.conf import settings


class InsuranceProvider(models.Model):
    name = models.CharField(max_length=200, unique=True)
    code = models.CharField(max_length=30, blank=True, help_text='Internal short code, e.g. NHIF, AAR')
    contact_person = models.CharField(max_length=120, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    claim_email = models.EmailField(blank=True, help_text='Where to email claims')
    payment_terms_days = models.PositiveIntegerField(default=30)
    discount_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0,
                                        help_text='Default contractual discount % off list price')
    notes = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class InsuranceClaim(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        SUBMITTED = 'submitted', 'Submitted'
        UNDER_REVIEW = 'under_review', 'Under Review'
        APPROVED = 'approved', 'Approved'
        PARTIALLY_APPROVED = 'partially_approved', 'Partially Approved'
        REJECTED = 'rejected', 'Rejected'
        PAID = 'paid', 'Paid'

    reference = models.CharField(max_length=30, unique=True, blank=True)
    provider = models.ForeignKey(
        InsuranceProvider, on_delete=models.PROTECT, related_name='claims',
    )
    member_name = models.CharField(max_length=200)
    member_number = models.CharField(max_length=80)
    scheme_name = models.CharField(max_length=200, blank=True)
    diagnosis = models.TextField(blank=True)

    # Source links (any one)
    pos_transaction = models.ForeignKey(
        'pos.POSTransaction', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='insurance_claims',
    )
    dispensing_record = models.ForeignKey(
        'dispensing.DispensingRecord', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='insurance_claims',
    )
    invoice_number = models.CharField(max_length=80, blank=True)

    items = models.JSONField(default=list, blank=True,
                             help_text='[{description, quantity, unit_price, total}]')

    claim_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    approved_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    paid_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    submitted_at = models.DateTimeField(null=True, blank=True)
    settled_at = models.DateTimeField(null=True, blank=True)
    payment_reference = models.CharField(max_length=120, blank=True)
    rejection_reason = models.TextField(blank=True)
    notes = models.TextField(blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='claims_created',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['provider', 'status']),
            models.Index(fields=['member_number']),
        ]

    def save(self, *args, **kwargs):
        if not self.reference:
            super().save(*args, **kwargs)
            self.reference = f'CLM-{self.pk:06d}'
            return super().save(update_fields=['reference'])
        return super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.reference or "CLM-?"} {self.provider} {self.claim_amount}'

    @property
    def outstanding(self):
        return float(self.approved_amount or 0) - float(self.paid_amount or 0)
