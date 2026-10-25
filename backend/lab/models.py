import os
import uuid

from django.db import models
from django.conf import settings
from django.utils import timezone

# Scanned reports are patient data, so every upload is namespaced by tenant
# schema. All tenants share one bucket, and a bare `lab/results/<file>` would
# let one clinic's report overwrite another's on a name collision.
ALLOWED_RESULT_ATTACHMENT_TYPES = {
    'application/pdf': 'pdf',
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/tiff': 'tiff',
    'image/heic': 'heic',
}
MAX_RESULT_ATTACHMENT_BYTES = 15 * 1024 * 1024  # 15 MB


def lab_result_attachment_path(instance, filename):
    """Tenant-scoped, collision-proof storage key for a result attachment."""
    from django.db import connection

    schema = getattr(connection, 'schema_name', None) or 'public'
    ext = os.path.splitext(filename or '')[1].lower()
    if ext not in {'.pdf', '.jpg', '.jpeg', '.png', '.webp', '.tif', '.tiff', '.heic'}:
        ext = ''
    stamp = timezone.now().strftime('%Y/%m')
    return f'lab/results/{schema}/{stamp}/{uuid.uuid4().hex}{ext}'


def attachment_kind(mime_type, filename=''):
    """Normalise an upload to 'pdf', 'image' or '' (unknown)."""
    mime = (mime_type or '').split(';')[0].strip().lower()
    if mime in ALLOWED_RESULT_ATTACHMENT_TYPES:
        return 'pdf' if mime == 'application/pdf' else 'image'
    ext = os.path.splitext(filename or '')[1].lower()
    if ext == '.pdf':
        return 'pdf'
    if ext in {'.jpg', '.jpeg', '.png', '.webp', '.tif', '.tiff', '.heic'}:
        return 'image'
    return ''


# A handwritten signature is captured as a PNG data-URL from the signature pad.
# 4 MB is generous for an ink stroke yet small enough to keep the row light.
MAX_SIGNATURE_BYTES = 4 * 1024 * 1024
SIGNATURE_IMAGE_TYPES = {'image/png', 'image/jpeg', 'image/webp'}

#: Roles that may record a result as ``performed`` in a small-clinic lab.
PERFORM_ROLES = {'lab_tech', 'tenant_admin', 'branch_admin', 'super_admin'}
#: Roles that may authorise (release) a result.
VERIFY_ROLES = {'lab_tech', 'doctor', 'tenant_admin', 'branch_admin', 'super_admin'}


def _tenant_schema():
    from django.db import connection
    return getattr(connection, 'schema_name', None) or 'public'


def lab_signature_path(instance, filename):
    """Storage key for a staff member's signature *on file*."""
    ext = os.path.splitext(filename or '')[1].lower()
    if ext not in {'.png', '.jpg', '.jpeg', '.webp'}:
        ext = '.png'
    return f'lab/signatures/{_tenant_schema()}/staff/{uuid.uuid4().hex}{ext}'


def lab_signature_snapshot_path(instance, filename):
    """Immutable copy of the signature actually used on one authorisation.

    Kept separate from the staff profile so a later signature change cannot
    rewrite the history of an already-released report (ISO 15189 traceability).
    """
    ext = os.path.splitext(filename or '')[1].lower()
    if ext not in {'.png', '.jpg', '.jpeg', '.webp'}:
        ext = '.png'
    stamp = timezone.now().strftime('%Y/%m')
    return f'lab/signatures/{_tenant_schema()}/signed/{stamp}/{uuid.uuid4().hex}{ext}'


class LabTestCatalog(models.Model):
    name = models.CharField(max_length=255)
    code = models.CharField(max_length=50, unique=True)
    department = models.CharField(max_length=100, blank=True)
    specimen_type = models.CharField(max_length=100, help_text='e.g., Blood, Urine, Stool')
    reference_ranges = models.JSONField(default=dict, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    turnaround_time = models.CharField(max_length=50, blank=True, help_text='e.g., 2 hours')
    instructions = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f'{self.code} - {self.name}'


class LabOrder(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        SAMPLE_COLLECTED = 'sample_collected', 'Sample Collected'
        PROCESSING = 'processing', 'Processing'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class Priority(models.TextChoices):
        ROUTINE = 'routine', 'Routine'
        URGENT = 'urgent', 'Urgent'
        STAT = 'stat', 'STAT'

    consultation = models.ForeignKey(
        'consultations.Consultation', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='lab_orders',
    )
    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='lab_orders')
    clinic_site = models.ForeignKey(
        'clinic_sites.ClinicSite', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='lab_orders',
        help_text='Clinic location that ordered this test (null = HQ).',
    )
    ordered_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='lab_orders_created',
    )
    tests = models.ManyToManyField(LabTestCatalog, related_name='orders')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    priority = models.CharField(max_length=10, choices=Priority.choices, default=Priority.ROUTINE)
    clinical_notes = models.TextField(blank=True)
    is_home_collection = models.BooleanField(default=False)
    recurrence_frequency_days = models.PositiveIntegerField(
        null=True, blank=True, help_text='Repeat every N days',
    )
    recurrence_end_date = models.DateField(null=True, blank=True)
    next_collection_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Lab Order #{self.id} - {self.patient}'


class LabResult(models.Model):
    order = models.ForeignKey(LabOrder, on_delete=models.CASCADE, related_name='results')
    test = models.ForeignKey(LabTestCatalog, on_delete=models.CASCADE)
    result_value = models.TextField()
    unit = models.CharField(max_length=50, blank=True)
    is_abnormal = models.BooleanField(default=False)
    comments = models.TextField(blank=True)
    # Optional scanned report / analyser printout. Kept alongside the typed
    # value so a clinician can always fall back to the source document.
    attachment = models.FileField(
        upload_to=lab_result_attachment_path, null=True, blank=True,
        help_text='Optional scanned report — PDF or image.',
    )
    attachment_name = models.CharField(max_length=255, blank=True)
    attachment_type = models.CharField(max_length=100, blank=True)
    attachment_size = models.PositiveBigIntegerField(default=0)
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='lab_results_performed',
    )
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='lab_results_verified',
    )
    result_date = models.DateTimeField(auto_now_add=True)

    @property
    def attachment_kind(self):
        return attachment_kind(self.attachment_type, self.attachment_name)

    def stow_attachment(self, upload):
        """Copy upload metadata onto the row (call before save())."""
        if upload:
            self.attachment_name = os.path.basename(getattr(upload, 'name', '') or '')[:255]
            self.attachment_type = (getattr(upload, 'content_type', '') or '')[:100]
            self.attachment_size = getattr(upload, 'size', 0) or 0
        else:
            self.attachment_name = ''
            self.attachment_type = ''
            self.attachment_size = 0

    def __str__(self):
        return f'{self.test.name}: {self.result_value}'


class HomeSampleVisit(models.Model):
    class Status(models.TextChoices):
        SCHEDULED = 'scheduled', 'Scheduled'
        CONFIRMED = 'confirmed', 'Confirmed'
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'
        NO_SHOW = 'no_show', 'No Show'

    lab_order = models.ForeignKey(LabOrder, on_delete=models.CASCADE, related_name='home_visits')
    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='home_visits')
    assigned_lab_tech = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='home_visits_assigned',
    )
    scheduled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='home_visits_scheduled',
    )
    scheduled_date = models.DateField()
    scheduled_time = models.TimeField()
    patient_address = models.TextField()
    address_place_name = models.CharField(max_length=255, blank=True)
    address_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    address_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SCHEDULED)
    notes = models.TextField(blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['scheduled_date', 'scheduled_time']

    def __str__(self):
        return f'Home Visit #{self.id} - {self.patient} on {self.scheduled_date}'


# =====================================================================
# Lab Tenant — professional lab features
# =====================================================================


class LabPanel(models.Model):
    """A bundle of tests offered together (e.g., CBC, Lipid Panel, LFTs)."""
    name = models.CharField(max_length=255)
    code = models.CharField(max_length=50, unique=True)
    department = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    tests = models.ManyToManyField(LabTestCatalog, related_name='panels')
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f'{self.code} - {self.name}'


class ReferringFacility(models.Model):
    name = models.CharField(max_length=255)
    contact_person = models.CharField(max_length=150, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    discount_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class ReferringDoctor(models.Model):
    full_name = models.CharField(max_length=255)
    facility = models.ForeignKey(
        ReferringFacility, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='doctors',
    )
    license_no = models.CharField(max_length=100, blank=True)
    specialty = models.CharField(max_length=150, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    email = models.EmailField(blank=True)
    commission_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['full_name']

    def __str__(self):
        return self.full_name


class Instrument(models.Model):
    """Lab analyzer / instrument registry."""
    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        MAINTENANCE = 'maintenance', 'Under Maintenance'
        OFFLINE = 'offline', 'Offline'
        RETIRED = 'retired', 'Retired'

    name = models.CharField(max_length=255)
    serial_no = models.CharField(max_length=100, blank=True)
    manufacturer = models.CharField(max_length=150, blank=True)
    model = models.CharField(max_length=150, blank=True)
    department = models.CharField(max_length=100, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    location = models.CharField(max_length=150, blank=True)
    last_service_date = models.DateField(null=True, blank=True)
    next_service_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class Specimen(models.Model):
    """Accessioned specimen — barcoded, tracked, status-managed."""
    class Status(models.TextChoices):
        REGISTERED = 'registered', 'Registered'
        COLLECTED = 'collected', 'Collected'
        RECEIVED = 'received', 'Received in Lab'
        REJECTED = 'rejected', 'Rejected'
        IN_PROCESS = 'in_process', 'In Process'
        DISPOSED = 'disposed', 'Disposed'

    class ContainerType(models.TextChoices):
        EDTA = 'edta', 'EDTA Tube'
        SST = 'sst', 'SST / Serum'
        CITRATE = 'citrate', 'Citrate'
        FLUORIDE = 'fluoride', 'Fluoride / Oxalate'
        URINE = 'urine', 'Urine Cup'
        STOOL = 'stool', 'Stool Container'
        SWAB = 'swab', 'Swab'
        CULTURE = 'culture', 'Blood Culture'
        OTHER = 'other', 'Other'

    accession_number = models.CharField(max_length=50, unique=True, db_index=True)
    barcode = models.CharField(max_length=100, blank=True, db_index=True)
    lab_order = models.ForeignKey(
        LabOrder, on_delete=models.CASCADE, related_name='specimens',
    )
    specimen_type = models.CharField(max_length=100)
    container_type = models.CharField(
        max_length=20, choices=ContainerType.choices, default=ContainerType.OTHER,
    )
    volume_ml = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True,
    )
    collected_at = models.DateTimeField(null=True, blank=True)
    collected_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='specimens_collected',
    )
    received_at = models.DateTimeField(null=True, blank=True)
    received_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='specimens_received',
    )
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.REGISTERED,
    )
    rejection_reason = models.CharField(max_length=255, blank=True)
    storage_location = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.accession_number} ({self.specimen_type})'


class QualityControlRun(models.Model):
    """Daily QC run for an instrument / test combination."""
    class Result(models.TextChoices):
        PASS = 'pass', 'Pass'
        WARN = 'warn', 'Warning'
        FAIL = 'fail', 'Fail'

    instrument = models.ForeignKey(
        Instrument, on_delete=models.CASCADE, related_name='qc_runs',
    )
    test = models.ForeignKey(
        LabTestCatalog, on_delete=models.CASCADE, related_name='qc_runs',
    )
    qc_level = models.CharField(
        max_length=20, blank=True, help_text='e.g., Low / Normal / High',
    )
    lot_number = models.CharField(max_length=100, blank=True)
    expected_value = models.CharField(max_length=50, blank=True)
    measured_value = models.CharField(max_length=50, blank=True)
    sd = models.DecimalField(
        max_digits=10, decimal_places=4, null=True, blank=True,
        help_text='Standard deviations from mean',
    )
    result = models.CharField(max_length=10, choices=Result.choices, default=Result.PASS)
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True,
        related_name='qc_runs_performed',
    )
    comments = models.TextField(blank=True)
    run_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-run_at']

    def __str__(self):
        return f'QC {self.test.code} on {self.instrument.name} - {self.result}'


class LabInvoice(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        ISSUED = 'issued', 'Issued'
        PARTIAL = 'partial', 'Partially Paid'
        PAID = 'paid', 'Paid'
        VOID = 'void', 'Void'

    class Payer(models.TextChoices):
        SELF = 'self', 'Self / Cash'
        INSURANCE = 'insurance', 'Insurance'
        FACILITY = 'facility', 'Referring Facility'
        CORPORATE = 'corporate', 'Corporate'

    invoice_number = models.CharField(max_length=50, unique=True, db_index=True)
    lab_order = models.ForeignKey(
        LabOrder, on_delete=models.CASCADE, related_name='invoices',
    )
    patient = models.ForeignKey(
        'patients.Patient', on_delete=models.CASCADE, related_name='lab_invoices',
    )
    payer_type = models.CharField(
        max_length=20, choices=Payer.choices, default=Payer.SELF,
    )
    insurance_scheme = models.CharField(max_length=150, blank=True)
    referring_facility = models.ForeignKey(
        ReferringFacility, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='invoices',
    )
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True,
        related_name='lab_invoices_created',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def balance(self):
        return (self.total or 0) - (self.amount_paid or 0)

    def __str__(self):
        return self.invoice_number


class LabInvoiceItem(models.Model):
    invoice = models.ForeignKey(
        LabInvoice, on_delete=models.CASCADE, related_name='items',
    )
    test = models.ForeignKey(
        LabTestCatalog, on_delete=models.SET_NULL, null=True, blank=True,
    )
    panel = models.ForeignKey(
        LabPanel, on_delete=models.SET_NULL, null=True, blank=True,
    )
    description = models.CharField(max_length=255)
    qty = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    def save(self, *args, **kwargs):
        self.amount = (self.qty or 0) * (self.unit_price or 0) - (self.discount or 0)
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.description} x{self.qty}'


class LabInvoicePayment(models.Model):
    class Method(models.TextChoices):
        CASH = 'cash', 'Cash'
        MPESA = 'mpesa', 'M-Pesa'
        CARD = 'card', 'Card'
        BANK = 'bank', 'Bank Transfer'
        INSURANCE = 'insurance', 'Insurance'

    invoice = models.ForeignKey(
        LabInvoice, on_delete=models.CASCADE, related_name='payments',
    )
    method = models.CharField(max_length=20, choices=Method.choices, default=Method.CASH)
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    reference = models.CharField(max_length=100, blank=True)
    received_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True,
        related_name='lab_payments_received',
    )
    received_at = models.DateTimeField(auto_now_add=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-received_at']

    def __str__(self):
        return f'{self.method} {self.amount} on {self.invoice.invoice_number}'


class ReportTemplate(models.Model):
    """Printable report layout (header/footer, signatories)."""
    name = models.CharField(max_length=255)
    department = models.CharField(max_length=100, blank=True)
    header_html = models.TextField(blank=True)
    footer_html = models.TextField(blank=True)
    signatory_name = models.CharField(max_length=150, blank=True)
    signatory_title = models.CharField(max_length=150, blank=True)
    signatory_signature = models.ImageField(
        upload_to='lab/signatures/', null=True, blank=True,
    )
    is_default = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


# Add lab-specific extensions to existing models via separate model? Use through profile.
class LabOrderExtra(models.Model):
    """Per-lab-order extras: accession #, referring doctor/facility, billing link."""
    lab_order = models.OneToOneField(
        LabOrder, on_delete=models.CASCADE, related_name='extra',
    )
    accession_number = models.CharField(
        max_length=50, blank=True, db_index=True,
    )
    referring_doctor = models.ForeignKey(
        ReferringDoctor, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='referred_orders',
    )
    referring_facility = models.ForeignKey(
        ReferringFacility, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='referred_orders',
    )
    panels = models.ManyToManyField(LabPanel, blank=True, related_name='orders')
    payer_type = models.CharField(
        max_length=20, choices=LabInvoice.Payer.choices,
        default=LabInvoice.Payer.SELF,
    )
    notes_for_lab = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'Extra for Lab Order #{self.lab_order_id}'


class LabResultAudit(models.Model):
    """Audit trail for result amendments (HL7 / ISO 15189 traceability)."""
    result = models.ForeignKey(
        LabResult, on_delete=models.CASCADE, related_name='audit_entries',
    )
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True,
    )
    previous_value = models.TextField(blank=True)
    new_value = models.TextField(blank=True)
    reason = models.CharField(max_length=255, blank=True)
    changed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-changed_at']

    def __str__(self):
        return f'Audit on result #{self.result_id} at {self.changed_at:%Y-%m-%d %H:%M}'


class LabReagent(models.Model):
    """Lab reagent / consumable master record (chemicals, kits, controls)."""
    class Category(models.TextChoices):
        REAGENT = 'reagent', 'Reagent'
        CONTROL = 'control', 'Control'
        CALIBRATOR = 'calibrator', 'Calibrator'
        STAIN = 'stain', 'Stain / Dye'
        KIT = 'kit', 'Test Kit'
        CONSUMABLE = 'consumable', 'Consumable'
        BUFFER = 'buffer', 'Buffer / Diluent'
        MEDIA = 'media', 'Culture Media'
        OTHER = 'other', 'Other'

    class Storage(models.TextChoices):
        ROOM = 'room', 'Room (15-25°C)'
        FRIDGE = 'fridge', 'Refrigerated (2-8°C)'
        FREEZER = 'freezer', 'Frozen (-20°C)'
        ULTRA_FREEZER = 'ultra', 'Ultra-low (-80°C)'
        DARK = 'dark', 'Protect from light'
        OTHER = 'other', 'Other'

    name = models.CharField(max_length=255)
    code = models.CharField(max_length=50, blank=True, db_index=True)
    catalog_no = models.CharField(max_length=100, blank=True)
    manufacturer = models.CharField(max_length=150, blank=True)
    supplier = models.CharField(max_length=150, blank=True)
    category = models.CharField(
        max_length=20, choices=Category.choices, default=Category.REAGENT,
    )
    storage = models.CharField(
        max_length=20, choices=Storage.choices, default=Storage.ROOM,
    )
    department = models.CharField(max_length=100, blank=True)
    instrument = models.ForeignKey(
        Instrument, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='reagents',
    )
    unit = models.CharField(
        max_length=30, blank=True, help_text='e.g., mL, vial, test, bottle',
    )
    pack_size = models.CharField(
        max_length=50, blank=True, help_text='e.g., 100 tests, 500 mL',
    )
    unit_cost = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
    )
    reorder_level = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Trigger low-stock alert at this on-hand quantity',
    )
    reorder_qty = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Suggested replenish quantity',
    )
    msds_url = models.URLField(blank=True, help_text='Material Safety Data Sheet')
    hazard_class = models.CharField(max_length=80, blank=True)
    is_controlled = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class ReagentLot(models.Model):
    """A specific lot/batch of a reagent — tracks expiry & on-hand quantity."""
    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        QUARANTINE = 'quarantine', 'Quarantine'
        EXPIRED = 'expired', 'Expired'
        DISCARDED = 'discarded', 'Discarded'
        DEPLETED = 'depleted', 'Depleted'

    reagent = models.ForeignKey(
        LabReagent, on_delete=models.CASCADE, related_name='lots',
    )
    lot_number = models.CharField(max_length=100, db_index=True)
    received_date = models.DateField(null=True, blank=True)
    opened_date = models.DateField(null=True, blank=True)
    expiry_date = models.DateField(null=True, blank=True, db_index=True)
    open_stability_days = models.PositiveIntegerField(
        null=True, blank=True,
        help_text='Days valid after opening (overrides expiry if sooner)',
    )
    initial_quantity = models.DecimalField(max_digits=14, decimal_places=3, default=0)
    quantity_on_hand = models.DecimalField(max_digits=14, decimal_places=3, default=0)
    location = models.CharField(max_length=150, blank=True)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.ACTIVE,
    )
    received_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='reagent_lots_received',
    )
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['expiry_date', 'received_date']

    def __str__(self):
        return f'{self.reagent.name} · Lot {self.lot_number}'


class ReagentTransaction(models.Model):
    """Movement / consumption / adjustment log for reagent lots."""
    class Type(models.TextChoices):
        RECEIVE = 'receive', 'Receive'
        CONSUME = 'consume', 'Consume'
        ADJUST = 'adjust', 'Adjust'
        DISCARD = 'discard', 'Discard'
        TRANSFER = 'transfer', 'Transfer'
        RETURN = 'return', 'Return'

    lot = models.ForeignKey(
        ReagentLot, on_delete=models.CASCADE, related_name='transactions',
    )
    txn_type = models.CharField(max_length=20, choices=Type.choices)
    quantity = models.DecimalField(
        max_digits=14, decimal_places=3,
        help_text='Positive for receive / negative for consume',
    )
    reason = models.CharField(max_length=255, blank=True)
    reference = models.CharField(
        max_length=100, blank=True,
        help_text='e.g., test order #, requisition, PO number',
    )
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True,
        related_name='reagent_txns_performed',
    )
    performed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-performed_at']

    def __str__(self):
        return f'{self.txn_type} {self.quantity} of lot {self.lot_id}'


# =====================================================================
# Bench authorisation — name + password + handwritten signature
# =====================================================================
#
# In most clinics the laboratory runs off a single shared workstation, so the
# logged-in account (often a receptionist or an admin) is not the person who
# ran the test. Releasing a report therefore requires the bench technologist to
# identify themselves explicitly and prove it with their own password, then
# sign. Both signatures are snapshotted onto the order so the report keeps
# showing exactly what was signed months later.


class LabStaffProfile(models.Model):
    """Lab-bench identity: printed title and the signature kept on file."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='lab_staff_profile',
    )
    title = models.CharField(
        max_length=150, blank=True,
        help_text='Printed under the name on the report, e.g. "Senior Medical '
                  'Laboratory Scientist".',
    )
    signature = models.ImageField(
        upload_to=lab_signature_path, null=True, blank=True,
        help_text='Signature on file — reused when the staff member signs.',
    )
    signature_updated_at = models.DateTimeField(null=True, blank=True)
    can_perform = models.BooleanField(
        default=True, help_text='May be recorded as the performer of a result.',
    )
    can_verify = models.BooleanField(
        default=True, help_text='May authorise (release) a result.',
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['user__first_name', 'user__last_name']

    def __str__(self):
        return f'{self.user} — lab profile'

    @property
    def has_signature(self):
        return bool(self.signature)


class LabOrderAuthorization(models.Model):
    """The two bench sign-offs for one order (performer + verifier)."""

    class Identity(models.TextChoices):
        """How the signer's identity was proven for that half of the sign-off."""

        PASSWORD = 'password', 'Account password'
        SESSION = 'session', 'Own signed-in session'

    order = models.OneToOneField(
        LabOrder, on_delete=models.CASCADE, related_name='authorization',
    )

    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='lab_orders_performed',
    )
    performed_by_name = models.CharField(max_length=255, blank=True)
    performed_by_title = models.CharField(max_length=150, blank=True)
    performed_signature = models.ImageField(
        upload_to=lab_signature_snapshot_path, null=True, blank=True,
    )
    performed_at = models.DateTimeField(null=True, blank=True)
    performed_identity = models.CharField(
        max_length=20, choices=Identity.choices, blank=True,
    )
    performed_notes = models.TextField(blank=True)

    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='lab_orders_authorised',
    )
    verified_by_name = models.CharField(max_length=255, blank=True)
    verified_by_title = models.CharField(max_length=150, blank=True)
    verified_signature = models.ImageField(
        upload_to=lab_signature_snapshot_path, null=True, blank=True,
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_identity = models.CharField(
        max_length=20, choices=Identity.choices, blank=True,
    )
    verified_notes = models.TextField(blank=True)

    # ── Turnaround tracking (pending → verified) ───────────────────────────
    pending_at = models.DateTimeField(
        null=True, blank=True,
        help_text='When the order entered the pending queue (snapshot of order.created_at).',
    )
    turnaround_seconds = models.PositiveIntegerField(
        null=True, blank=True,
        help_text='Saved seconds from pending to verified. Set once on verification.',
    )
    turnaround_target_seconds = models.PositiveIntegerField(
        null=True, blank=True,
        help_text='Expected turnaround for the order priority at verification time.',
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'lab order authorisation'

    def __str__(self):
        return f'Authorisation for lab order #{self.order_id}'

    @property
    def is_complete(self):
        return bool(self.performed_at and self.verified_at)

    # Targets are deliberately generous: a routine panel is a next-day test,
    # urgent is same-shift, STAT is the "as soon as the analyser frees up" path.
    TURNAROUND_TARGETS = {'stat': 60 * 60, 'urgent': 6 * 60 * 60, 'routine': 24 * 60 * 60}

    def target_seconds(self):
        """Expected turnaround for this order's priority."""
        priority = getattr(self.order, 'priority', 'routine') or 'routine'
        return self.TURNAROUND_TARGETS.get(priority, self.TURNAROUND_TARGETS['routine'])

    @property
    def started_at(self):
        """Queue entry time used as the turnaround clock start."""
        return self.pending_at or getattr(self.order, 'created_at', None)

    @property
    def is_verified(self):
        return bool(self.verified_at)

    @property
    def elapsed_seconds(self):
        """Seconds pending → verified (saved) or pending → now (live)."""
        if self.is_verified:
            if self.turnaround_seconds is not None:
                return self.turnaround_seconds
            start = self.started_at
            return int((self.verified_at - start).total_seconds()) if start else 0
        start = self.started_at
        if not start:
            return 0
        return max(0, int((timezone.now() - start).total_seconds()))


class LabAuthorizationEvent(models.Model):
    """Append-only log of sign / revoke actions (who, when, from where)."""

    class Role(models.TextChoices):
        PERFORMED = 'performed', 'Performed'
        VERIFIED = 'verified', 'Verified'

    class Action(models.TextChoices):
        SIGN = 'sign', 'Signed'
        REVOKE = 'revoke', 'Revoked'

    order = models.ForeignKey(
        LabOrder, on_delete=models.CASCADE, related_name='authorization_events',
    )
    role = models.CharField(max_length=20, choices=Role.choices)
    action = models.CharField(max_length=20, choices=Action.choices)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='lab_authorization_events',
    )
    user_name = models.CharField(max_length=255, blank=True)
    user_title = models.CharField(max_length=150, blank=True)
    notes = models.CharField(max_length=255, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.action} {self.role} on order #{self.order_id}'


class LabSeedCustomization(models.Model):
    """One clinic's version of a demo catalog entry.

    The demo catalogue itself lives in ``lab/seed_data.py`` as an immutable
    template shared by every tenant. This table only records what a clinic
    changed, hid or deselected, so:

    * the shared template is never mutated by tenant edits;
    * each tenant sees only its own tweaks (lab is a TENANT_APP, so these rows
      live in the tenant schema);
    * re-opening the seed page restores the clinic's own choices.
    """

    class Kind(models.TextChoices):
        TEST = 'test', 'Test'
        PANEL = 'panel', 'Panel'

    code = models.CharField(max_length=50)
    kind = models.CharField(max_length=10, choices=Kind.choices)
    #: Should this entry be written into the clinic catalogue?
    is_selected = models.BooleanField(default=True)
    #: True once the entry has actually been written for this tenant.
    is_applied = models.BooleanField(default=False)
    #: True when the clinic changed any template field.
    is_customized = models.BooleanField(default=False)
    #: Hide an entry the clinic never wants to see again.
    is_dismissed = models.BooleanField(default=False)

    # Overrides — blank/None means "use the template value".
    name = models.CharField(max_length=255, blank=True)
    department = models.CharField(max_length=100, blank=True)
    specimen_type = models.CharField(max_length=100, blank=True)
    turnaround_time = models.CharField(max_length=50, blank=True)
    instructions = models.TextField(blank=True)
    description = models.TextField(blank=True)
    reference_ranges = models.JSONField(null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    #: Panel membership, as a list of test codes.
    test_codes = models.JSONField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['kind', 'code']
        constraints = [
            models.UniqueConstraint(
                fields=['code', 'kind'], name='uniq_lab_seed_customization',
            ),
        ]
        verbose_name = 'lab seed customization'

    def __str__(self):
        return f'{self.kind}:{self.code}'
