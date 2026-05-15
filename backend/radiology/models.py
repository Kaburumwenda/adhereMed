from django.db import models
from django.conf import settings


# ── Equipment / Modality ──────────────────────────────────────────────

class ImagingModality(models.Model):
    class ModalityType(models.TextChoices):
        XRAY = 'xray', 'X-Ray'
        CT = 'ct', 'CT Scan'
        MRI = 'mri', 'MRI'
        ULTRASOUND = 'ultrasound', 'Ultrasound'
        MAMMOGRAM = 'mammogram', 'Mammography'
        FLUOROSCOPY = 'fluoroscopy', 'Fluoroscopy'
        PET_CT = 'pet_ct', 'PET-CT'
        DEXA = 'dexa', 'DEXA'
        OTHER = 'other', 'Other'

    name = models.CharField(max_length=255, help_text='e.g. Siemens SOMATOM go.Top')
    modality_type = models.CharField(max_length=20, choices=ModalityType.choices)
    manufacturer = models.CharField(max_length=255, blank=True)
    model_name = models.CharField(max_length=255, blank=True)
    serial_number = models.CharField(max_length=100, blank=True)
    room_location = models.CharField(max_length=100, blank=True)
    installation_date = models.DateField(null=True, blank=True)
    last_service_date = models.DateField(null=True, blank=True)
    next_service_date = models.DateField(null=True, blank=True)
    max_daily_slots = models.PositiveIntegerField(default=20)
    is_active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'imaging modalities'

    def __str__(self):
        return f'{self.name} ({self.get_modality_type_display()})'


# ── Exam Catalog ──────────────────────────────────────────────────────

class ExamCatalog(models.Model):
    code = models.CharField(max_length=50, unique=True, help_text='CPT or internal code')
    name = models.CharField(max_length=255)
    modality_type = models.CharField(max_length=20, choices=ImagingModality.ModalityType.choices)
    body_region = models.CharField(max_length=100, blank=True)
    default_protocol = models.TextField(blank=True)
    prep_instructions = models.TextField(blank=True, help_text='Patient preparation instructions')
    estimated_duration_minutes = models.PositiveIntegerField(default=30)
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    contrast_required = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f'{self.code} - {self.name}'


class ExamPanel(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    exams = models.ManyToManyField(ExamCatalog, related_name='panels')
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0, help_text='Override price for bundle')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


# ── Referring ─────────────────────────────────────────────────────────

class ReferringFacility(models.Model):
    name = models.CharField(max_length=255)
    address = models.TextField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    contact_person = models.CharField(max_length=255, blank=True)
    discount_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'referring facilities'

    def __str__(self):
        return self.name


class ReferringDoctor(models.Model):
    name = models.CharField(max_length=255)
    specialty = models.CharField(max_length=100, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    license_number = models.CharField(max_length=50, blank=True)
    facility = models.ForeignKey(
        ReferringFacility, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='doctors',
    )
    commission_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


# ── Orders ────────────────────────────────────────────────────────────

class RadiologyOrder(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        SCHEDULED = 'scheduled', 'Scheduled'
        CHECKED_IN = 'checked_in', 'Checked In'
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class Priority(models.TextChoices):
        ROUTINE = 'routine', 'Routine'
        URGENT = 'urgent', 'Urgent'
        STAT = 'stat', 'STAT'

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
    exams = models.ManyToManyField(ExamCatalog, blank=True, related_name='orders')
    imaging_type = models.CharField(max_length=20, choices=ImagingType.choices)
    body_part = models.CharField(max_length=255)
    clinical_indication = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    priority = models.CharField(max_length=10, choices=Priority.choices, default=Priority.ROUTINE)
    modality = models.ForeignKey(
        ImagingModality, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='orders',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.get_imaging_type_display()} - {self.body_part} ({self.patient})'


class RadiologyOrderExtra(models.Model):
    class PayerType(models.TextChoices):
        SELF = 'self', 'Self-pay'
        INSURANCE = 'insurance', 'Insurance'
        FACILITY = 'facility', 'Referring Facility'
        CORPORATE = 'corporate', 'Corporate'

    order = models.OneToOneField(RadiologyOrder, on_delete=models.CASCADE, related_name='extra')
    accession_number = models.CharField(max_length=50, blank=True, unique=True, null=True)
    referring_doctor = models.ForeignKey(
        ReferringDoctor, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='order_extras',
    )
    referring_facility = models.ForeignKey(
        ReferringFacility, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='order_extras',
    )
    panels = models.ManyToManyField(ExamPanel, blank=True, related_name='order_extras')
    payer_type = models.CharField(max_length=20, choices=PayerType.choices, default=PayerType.SELF)
    clinical_history = models.TextField(blank=True)
    pregnancy_status = models.CharField(max_length=20, blank=True)
    allergies_contrast = models.TextField(blank=True, help_text='Known contrast allergies')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Extra for Order #{self.order_id}'


# ── Scheduling ────────────────────────────────────────────────────────

class RadiologySchedule(models.Model):
    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        CHECKED_IN = 'checked_in', 'Checked In'
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'
        NO_SHOW = 'no_show', 'No Show'
        CANCELLED = 'cancelled', 'Cancelled'

    order = models.ForeignKey(RadiologyOrder, on_delete=models.CASCADE, related_name='schedules')
    modality = models.ForeignKey(ImagingModality, on_delete=models.CASCADE, related_name='schedules')
    scheduled_datetime = models.DateTimeField()
    duration_minutes = models.PositiveIntegerField(default=30)
    technologist = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='radiology_schedules',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SCHEDULED)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['scheduled_datetime']

    def __str__(self):
        return f'{self.order} @ {self.scheduled_datetime:%Y-%m-%d %H:%M}'


# ── Contrast ──────────────────────────────────────────────────────────

class ContrastAdministration(models.Model):
    order = models.ForeignKey(RadiologyOrder, on_delete=models.CASCADE, related_name='contrast_records')
    contrast_agent = models.CharField(max_length=255)
    dose_ml = models.DecimalField(max_digits=6, decimal_places=2)
    route = models.CharField(max_length=50, default='IV')
    lot_number = models.CharField(max_length=100, blank=True)
    expiry_date = models.DateField(null=True, blank=True)
    administered_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='contrast_administered',
    )
    administered_at = models.DateTimeField(auto_now_add=True)
    reaction_noted = models.BooleanField(default=False)
    reaction_details = models.TextField(blank=True)

    class Meta:
        ordering = ['-administered_at']

    def __str__(self):
        return f'{self.contrast_agent} {self.dose_ml}ml for Order #{self.order_id}'


# ── Dose Tracking ─────────────────────────────────────────────────────

class DoseRecord(models.Model):
    order = models.ForeignKey(RadiologyOrder, on_delete=models.CASCADE, related_name='dose_records')
    modality = models.ForeignKey(ImagingModality, on_delete=models.SET_NULL, null=True, related_name='dose_records')
    ctdi_vol = models.DecimalField(max_digits=8, decimal_places=3, null=True, blank=True, help_text='CTDIvol in mGy')
    dlp = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True, help_text='Dose-Length Product in mGy·cm')
    effective_dose_msv = models.DecimalField(max_digits=8, decimal_places=3, null=True, blank=True, help_text='Effective dose in mSv')
    kvp = models.PositiveIntegerField(null=True, blank=True)
    mas = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    fluoroscopy_time_seconds = models.PositiveIntegerField(null=True, blank=True)
    notes = models.TextField(blank=True)
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='dose_records',
    )
    recorded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-recorded_at']

    def __str__(self):
        return f'Dose for Order #{self.order_id}'


# ── Reporting ─────────────────────────────────────────────────────────

class RadiologyResult(models.Model):
    """Legacy result model retained for hospital consultation compatibility."""
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


class ReportTemplate(models.Model):
    name = models.CharField(max_length=255)
    modality_type = models.CharField(max_length=20, choices=ImagingModality.ModalityType.choices, blank=True)
    body_region = models.CharField(max_length=100, blank=True)
    template_body = models.TextField(help_text='Default findings/impression template text')
    header_html = models.TextField(blank=True)
    footer_html = models.TextField(blank=True)
    signatory_name = models.CharField(max_length=255, blank=True)
    signatory_title = models.CharField(max_length=255, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class RadiologyReport(models.Model):
    class ReportStatus(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        PRELIMINARY = 'preliminary', 'Preliminary'
        FINAL = 'final', 'Final'
        AMENDED = 'amended', 'Amended'
        ADDENDUM = 'addendum', 'Addendum'

    order = models.OneToOneField(RadiologyOrder, on_delete=models.CASCADE, related_name='report')
    template = models.ForeignKey(
        ReportTemplate, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='reports',
    )
    findings = models.TextField(blank=True)
    impression = models.TextField(blank=True)
    recommendation = models.TextField(blank=True)
    radiologist = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='radiology_reports',
    )
    report_status = models.CharField(max_length=20, choices=ReportStatus.choices, default=ReportStatus.DRAFT)
    signed_at = models.DateTimeField(null=True, blank=True)
    transcribed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='radiology_reports_transcribed',
    )
    critical_finding = models.BooleanField(default=False)
    critical_finding_communicated_to = models.CharField(max_length=255, blank=True)
    critical_finding_communicated_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Report for Order #{self.order_id} ({self.get_report_status_display()})'


class CriticalFindingAlert(models.Model):
    class Severity(models.TextChoices):
        CRITICAL = 'critical', 'Critical'
        URGENT = 'urgent', 'Urgent'

    class Method(models.TextChoices):
        PHONE = 'phone', 'Phone'
        IN_PERSON = 'in_person', 'In Person'
        SECURE_MESSAGE = 'secure_message', 'Secure Message'

    report = models.ForeignKey(RadiologyReport, on_delete=models.CASCADE, related_name='critical_alerts')
    finding_description = models.TextField()
    severity = models.CharField(max_length=20, choices=Severity.choices, default=Severity.CRITICAL)
    communicated_to = models.CharField(max_length=255)
    communicated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='critical_alerts_sent',
    )
    communicated_at = models.DateTimeField(auto_now_add=True)
    method = models.CharField(max_length=20, choices=Method.choices)
    acknowledged = models.BooleanField(default=False)
    acknowledged_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-communicated_at']

    def __str__(self):
        return f'Critical alert for Report #{self.report_id}'


# ── Quality Control ───────────────────────────────────────────────────

class QualityControlRecord(models.Model):
    class QCStatus(models.TextChoices):
        PASS = 'pass', 'Pass'
        WARN = 'warn', 'Warning'
        FAIL = 'fail', 'Fail'

    modality = models.ForeignKey(ImagingModality, on_delete=models.CASCADE, related_name='qc_records')
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='radiology_qc_performed',
    )
    qc_date = models.DateField()
    status = models.CharField(max_length=10, choices=QCStatus.choices)
    dose_output = models.DecimalField(max_digits=8, decimal_places=3, null=True, blank=True)
    image_quality_score = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-qc_date']

    def __str__(self):
        return f'QC {self.modality} on {self.qc_date} — {self.get_status_display()}'


# ── Billing ───────────────────────────────────────────────────────────

class RadiologyInvoice(models.Model):
    class PayerType(models.TextChoices):
        SELF = 'self', 'Self-pay'
        INSURANCE = 'insurance', 'Insurance'
        FACILITY = 'facility', 'Referring Facility'
        CORPORATE = 'corporate', 'Corporate'

    class InvoiceStatus(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        ISSUED = 'issued', 'Issued'
        PARTIAL = 'partial', 'Partially Paid'
        PAID = 'paid', 'Paid'
        VOID = 'void', 'Void'

    invoice_number = models.CharField(max_length=50, unique=True, blank=True)
    order = models.ForeignKey(RadiologyOrder, on_delete=models.CASCADE, related_name='invoices')
    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='radiology_invoices')
    payer_type = models.CharField(max_length=20, choices=PayerType.choices, default=PayerType.SELF)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=InvoiceStatus.choices, default=InvoiceStatus.DRAFT)
    due_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Invoice {self.invoice_number or self.id}'

    def save(self, *args, **kwargs):
        if not self.invoice_number:
            from django.utils import timezone
            today = timezone.now().strftime('%y%m%d')
            last = RadiologyInvoice.objects.filter(
                invoice_number__startswith=f'RI{today}'
            ).order_by('-invoice_number').first()
            seq = 1
            if last and last.invoice_number:
                try:
                    seq = int(last.invoice_number[-4:]) + 1
                except ValueError:
                    pass
            self.invoice_number = f'RI{today}{seq:04d}'
        super().save(*args, **kwargs)


class RadiologyInvoiceItem(models.Model):
    invoice = models.ForeignKey(RadiologyInvoice, on_delete=models.CASCADE, related_name='items')
    exam = models.ForeignKey(ExamCatalog, on_delete=models.SET_NULL, null=True, blank=True, related_name='invoice_items')
    panel = models.ForeignKey(ExamPanel, on_delete=models.SET_NULL, null=True, blank=True, related_name='invoice_items')
    description = models.CharField(max_length=255, blank=True)
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    def save(self, *args, **kwargs):
        self.total = (self.unit_price * self.quantity) - self.discount
        super().save(*args, **kwargs)

    def __str__(self):
        return f'Item: {self.description or self.exam or self.panel}'


class RadiologyPayment(models.Model):
    class PaymentMethod(models.TextChoices):
        CASH = 'cash', 'Cash'
        MPESA = 'mpesa', 'M-Pesa'
        CARD = 'card', 'Card'
        BANK = 'bank', 'Bank Transfer'
        INSURANCE = 'insurance', 'Insurance'

    invoice = models.ForeignKey(RadiologyInvoice, on_delete=models.CASCADE, related_name='payments')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    method = models.CharField(max_length=20, choices=PaymentMethod.choices)
    reference = models.CharField(max_length=100, blank=True)
    received_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='radiology_payments_received',
    )
    payment_date = models.DateTimeField(auto_now_add=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-payment_date']

    def __str__(self):
        return f'{self.get_method_display()} {self.amount} for Invoice {self.invoice_id}'
