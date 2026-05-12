from django.db import models
from django.conf import settings


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
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='lab_results_performed',
    )
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='lab_results_verified',
    )
    result_date = models.DateTimeField(auto_now_add=True)

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
