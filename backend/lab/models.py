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
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SCHEDULED)
    notes = models.TextField(blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['scheduled_date', 'scheduled_time']

    def __str__(self):
        return f'Home Visit #{self.id} - {self.patient} on {self.scheduled_date}'
