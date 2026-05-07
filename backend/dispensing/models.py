from django.db import models
from django.conf import settings


class DispensingRecord(models.Model):
    STATUS_CHOICES = [
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    PAYMENT_CHOICES = [
        ('cash', 'Cash'),
        ('mpesa', 'M-Pesa'),
        ('card', 'Card'),
        ('insurance', 'Insurance'),
        ('credit', 'Credit / On Account'),
    ]

    receipt_number = models.CharField(max_length=30, unique=True, blank=True)
    prescription_exchange_id = models.IntegerField(
        null=True, blank=True, help_text='FK to PrescriptionExchange (public schema)',
    )
    patient_user_id = models.IntegerField(null=True, blank=True, help_text='FK to User (public schema)')
    patient_name = models.CharField(max_length=255)
    patient_phone = models.CharField(max_length=30, blank=True)
    items_dispensed = models.JSONField(
        default=list,
        help_text='[{stock_id, medication_name, qty, unit_price, line_total, batch_number}]',
    )
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_method = models.CharField(max_length=20, choices=PAYMENT_CHOICES, default='cash')
    paid_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='completed')
    dispensed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='dispensing_records',
    )
    notes = models.TextField(blank=True)
    dispensed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-dispensed_at']

    def save(self, *args, **kwargs):
        if not self.receipt_number:
            super().save(*args, **kwargs)
            self.receipt_number = f'RCP-{self.pk:06d}'
            kwargs['force_insert'] = False
        super().save(*args, **kwargs)

    @property
    def change_due(self):
        try:
            return max(0, float(self.paid_amount or 0) - float(self.total or 0))
        except Exception:
            return 0

    @property
    def item_count(self):
        try:
            return sum(int(i.get('qty', 0) or 0) for i in (self.items_dispensed or []))
        except Exception:
            return 0

    def __str__(self):
        return f'{self.receipt_number or self.pk} · {self.patient_name} · KSh {self.total}'


class DispenseReturn(models.Model):
    REASON_CHOICES = [
        ('damaged', 'Damaged / faulty'),
        ('wrong_item', 'Wrong item dispensed'),
        ('patient_request', 'Patient changed mind'),
        ('expired', 'Expired'),
        ('adverse_reaction', 'Adverse reaction'),
        ('other', 'Other'),
    ]

    reference = models.CharField(max_length=30, unique=True, blank=True)
    original = models.ForeignKey(
        DispensingRecord, on_delete=models.CASCADE, related_name='returns',
    )
    items_returned = models.JSONField(
        default=list,
        help_text='[{stock_id, medication_name, qty, unit_price, line_total, reason}]',
    )
    refund_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    refund_method = models.CharField(max_length=20, blank=True)
    reason = models.CharField(max_length=30, choices=REASON_CHOICES, default='other')
    notes = models.TextField(blank=True)
    restock = models.BooleanField(default=True, help_text='Add returned items back into stock')
    processed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='dispense_returns',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.reference:
            super().save(*args, **kwargs)
            self.reference = f'RET-{self.pk:06d}'
            kwargs['force_insert'] = False
        super().save(*args, **kwargs)

    @property
    def item_count(self):
        try:
            return sum(int(i.get('qty', 0) or 0) for i in (self.items_returned or []))
        except Exception:
            return 0

    def __str__(self):
        return f'{self.reference} · refund KSh {self.refund_amount}'
