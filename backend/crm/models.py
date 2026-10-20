"""Customer Relationship Management models.

The CRM layers *around* ``pos.Customer`` (the transactional identity used by
POS / sales orders) rather than duplicating it:

    Customer            (pos)  — name, phone, email, loyalty points/tier
      └─ CustomerProfile (crm) — lifecycle, segment, owner, health, credit…
      └─ Interaction           — calls, emails, meetings, notes
      └─ Ticket                — support desk
      └─ Opportunity           — sales pipeline / deals
      └─ Task                  — follow-ups to do
      └─ Feedback              — NPS / satisfaction
      └─ PointsEntry           — loyalty points ledger

All models live in the tenant schema so each business has an isolated CRM.
"""
from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


# ─────────────────────────────────────────────────────────────────────────
#  Segmentation & tagging
# ─────────────────────────────────────────────────────────────────────────
class Segment(TimeStampedModel):
    """A named customer cohort (static or rule-driven)."""

    class Kind(models.TextChoices):
        STATIC = 'static', 'Static list'
        DYNAMIC = 'dynamic', 'Rule based'

    name = models.CharField(max_length=120, unique=True)
    code = models.CharField(max_length=30, blank=True)
    description = models.TextField(blank=True)
    kind = models.CharField(max_length=10, choices=Kind.choices, default=Kind.STATIC)
    color = models.CharField(max_length=20, default='#0d9488')
    icon = models.CharField(max_length=60, default='mdi-account-group-outline')
    criteria = models.JSONField(
        default=dict, blank=True,
        help_text='Rule payload, e.g. {"min_spend": 50000, "tier": "gold"}',
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class Tag(TimeStampedModel):
    name = models.CharField(max_length=60, unique=True)
    color = models.CharField(max_length=20, default='#64748b')

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


# ─────────────────────────────────────────────────────────────────────────
#  Core profile (one row per pos.Customer)
# ─────────────────────────────────────────────────────────────────────────
class CustomerProfile(TimeStampedModel):
    class Lifecycle(models.TextChoices):
        LEAD = 'lead', 'Lead'
        PROSPECT = 'prospect', 'Prospect'
        ACTIVE = 'active', 'Active'
        AT_RISK = 'at_risk', 'At risk'
        DORMANT = 'dormant', 'Dormant'
        CHURNED = 'churned', 'Churned'

    class LeadSource(models.TextChoices):
        WALK_IN = 'walk_in', 'Walk-in'
        REFERRAL = 'referral', 'Referral'
        WEBSITE = 'website', 'Website'
        SOCIAL = 'social', 'Social media'
        CAMPAIGN = 'campaign', 'Campaign'
        PARTNER = 'partner', 'Partner'
        OUTBOUND = 'outbound', 'Outbound'
        OTHER = 'other', 'Other'

    class Channel(models.TextChoices):
        PHONE = 'phone', 'Phone'
        SMS = 'sms', 'SMS'
        EMAIL = 'email', 'Email'
        WHATSAPP = 'whatsapp', 'WhatsApp'
        IN_PERSON = 'in_person', 'In person'

    customer = models.OneToOneField(
        'pos.Customer', on_delete=models.CASCADE, related_name='crm_profile',
    )

    lifecycle_stage = models.CharField(
        max_length=20, choices=Lifecycle.choices, default=Lifecycle.ACTIVE,
    )
    lead_source = models.CharField(
        max_length=20, choices=LeadSource.choices, default=LeadSource.WALK_IN,
    )
    preferred_channel = models.CharField(
        max_length=20, choices=Channel.choices, default=Channel.PHONE,
    )

    segment = models.ForeignKey(
        Segment, on_delete=models.SET_NULL, null=True, blank=True, related_name='members',
    )
    tags = models.ManyToManyField(Tag, blank=True, related_name='customers')
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='crm_owned_customers',
    )

    company = models.CharField(max_length=255, blank=True)
    job_title = models.CharField(max_length=120, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    national_id = models.CharField(max_length=40, blank=True)
    tax_pin = models.CharField(max_length=40, blank=True)
    website = models.CharField(max_length=255, blank=True)

    credit_limit = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    payment_terms_days = models.PositiveIntegerField(default=0)
    outstanding_balance = models.DecimalField(max_digits=14, decimal_places=2, default=0)

    # Scores (0-100)
    health_score = models.PositiveSmallIntegerField(default=70)
    churn_risk = models.PositiveSmallIntegerField(default=20)
    nps_score = models.SmallIntegerField(null=True, blank=True)
    lifetime_value = models.DecimalField(max_digits=14, decimal_places=2, default=0)

    first_contact_at = models.DateTimeField(null=True, blank=True)
    last_contact_at = models.DateTimeField(null=True, blank=True)
    last_purchase_at = models.DateTimeField(null=True, blank=True)
    next_follow_up_at = models.DateTimeField(null=True, blank=True)
    last_activity_summary = models.CharField(max_length=255, blank=True)

    is_vip = models.BooleanField(default=False)
    do_not_contact = models.BooleanField(default=False)
    marketing_opt_in = models.BooleanField(default=True)

    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f'{self.customer.name} — {self.get_lifecycle_stage_display()}'


# ─────────────────────────────────────────────────────────────────────────
#  Interactions (engagement timeline)
# ─────────────────────────────────────────────────────────────────────────
class Interaction(TimeStampedModel):
    class Kind(models.TextChoices):
        CALL = 'call', 'Phone call'
        EMAIL = 'email', 'Email'
        SMS = 'sms', 'SMS'
        WHATSAPP = 'whatsapp', 'WhatsApp'
        MEETING = 'meeting', 'Meeting'
        VISIT = 'visit', 'Site visit'
        NOTE = 'note', 'Note'
        COMPLAINT = 'complaint', 'Complaint'

    class Direction(models.TextChoices):
        INBOUND = 'inbound', 'Inbound'
        OUTBOUND = 'outbound', 'Outbound'
        INTERNAL = 'internal', 'Internal'

    class Outcome(models.TextChoices):
        CONNECTED = 'connected', 'Connected'
        NO_ANSWER = 'no_answer', 'No answer'
        LEFT_MESSAGE = 'left_message', 'Left message'
        RESOLVED = 'resolved', 'Resolved'
        FOLLOW_UP = 'follow_up', 'Follow-up required'
        NO_ACTION = 'no_action', 'No action'

    customer = models.ForeignKey(
        'pos.Customer', on_delete=models.CASCADE, related_name='crm_interactions',
    )
    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.NOTE)
    direction = models.CharField(
        max_length=12, choices=Direction.choices, default=Direction.OUTBOUND,
    )
    subject = models.CharField(max_length=255)
    summary = models.TextField(blank=True)
    outcome = models.CharField(
        max_length=20, choices=Outcome.choices, default=Outcome.CONNECTED,
    )
    occurred_at = models.DateTimeField(default=timezone.now)
    duration_minutes = models.PositiveIntegerField(default=0)
    follow_up_required = models.BooleanField(default=False)
    follow_up_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='crm_interactions',
    )

    class Meta:
        ordering = ['-occurred_at', '-id']
        indexes = [models.Index(fields=['customer', '-occurred_at'])]

    def __str__(self):
        return f'{self.customer.name} · {self.get_kind_display()}'


# ─────────────────────────────────────────────────────────────────────────
#  Support desk
# ─────────────────────────────────────────────────────────────────────────
class Ticket(TimeStampedModel):
    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        IN_PROGRESS = 'in_progress', 'In progress'
        WAITING = 'waiting', 'Waiting on customer'
        RESOLVED = 'resolved', 'Resolved'
        CLOSED = 'closed', 'Closed'

    class Priority(models.TextChoices):
        LOW = 'low', 'Low'
        NORMAL = 'normal', 'Normal'
        HIGH = 'high', 'High'
        URGENT = 'urgent', 'Urgent'

    class Category(models.TextChoices):
        ORDER = 'order', 'Order issue'
        DELIVERY = 'delivery', 'Delivery'
        BILLING = 'billing', 'Billing'
        PRODUCT = 'product', 'Product quality'
        ACCOUNT = 'account', 'Account'
        OTHER = 'other', 'Other'

    reference = models.CharField(max_length=30, unique=True, blank=True)
    customer = models.ForeignKey(
        'pos.Customer', on_delete=models.CASCADE, related_name='crm_tickets',
    )
    subject = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    category = models.CharField(max_length=20, choices=Category.choices, default=Category.OTHER)
    priority = models.CharField(max_length=10, choices=Priority.choices, default=Priority.NORMAL)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.OPEN)
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='crm_tickets',
    )
    opened_at = models.DateTimeField(default=timezone.now)
    first_response_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolution_notes = models.TextField(blank=True)
    satisfaction = models.PositiveSmallIntegerField(null=True, blank=True, help_text='1-5')
    sla_due_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.reference:
            super().save(*args, **kwargs)
            self.reference = f'TKT-{self.pk:05d}'
            kwargs['force_insert'] = False
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.reference} · {self.subject}'

    @property
    def is_overdue(self):
        if self.status in (self.Status.RESOLVED, self.Status.CLOSED):
            return False
        return bool(self.sla_due_at and timezone.now() > self.sla_due_at)


# ─────────────────────────────────────────────────────────────────────────
#  Sales pipeline
# ─────────────────────────────────────────────────────────────────────────
class Opportunity(TimeStampedModel):
    class Stage(models.TextChoices):
        NEW = 'new', 'New'
        QUALIFIED = 'qualified', 'Qualified'
        PROPOSAL = 'proposal', 'Proposal'
        NEGOTIATION = 'negotiation', 'Negotiation'
        WON = 'won', 'Won'
        LOST = 'lost', 'Lost'

    customer = models.ForeignKey(
        'pos.Customer', on_delete=models.CASCADE, related_name='crm_opportunities',
    )
    title = models.CharField(max_length=255)
    stage = models.CharField(max_length=20, choices=Stage.choices, default=Stage.NEW)
    value = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    probability = models.PositiveSmallIntegerField(default=20, help_text='Percent 0-100')
    expected_close_date = models.DateField(null=True, blank=True)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='crm_opportunities',
    )
    source = models.CharField(max_length=60, blank=True)
    lost_reason = models.CharField(max_length=255, blank=True)
    won_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.title} · {self.get_stage_display()}'

    @property
    def weighted_value(self):
        return (self.value or Decimal('0')) * (self.probability or 0) / 100


# ─────────────────────────────────────────────────────────────────────────
#  Campaigns
# ─────────────────────────────────────────────────────────────────────────
class Campaign(TimeStampedModel):
    class Channel(models.TextChoices):
        EMAIL = 'email', 'Email'
        SMS = 'sms', 'SMS'
        WHATSAPP = 'whatsapp', 'WhatsApp'
        CALL = 'call', 'Call round'
        IN_STORE = 'in_store', 'In-store'
        SOCIAL = 'social', 'Social'

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        SCHEDULED = 'scheduled', 'Scheduled'
        RUNNING = 'running', 'Running'
        COMPLETED = 'completed', 'Completed'
        PAUSED = 'paused', 'Paused'
        CANCELLED = 'cancelled', 'Cancelled'

    name = models.CharField(max_length=200)
    channel = models.CharField(max_length=20, choices=Channel.choices, default=Channel.EMAIL)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    segment = models.ForeignKey(
        Segment, on_delete=models.SET_NULL, null=True, blank=True, related_name='campaigns',
    )
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    budget = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    actual_cost = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    target_count = models.PositiveIntegerField(default=0)
    sent_count = models.PositiveIntegerField(default=0)
    opened_count = models.PositiveIntegerField(default=0)
    clicked_count = models.PositiveIntegerField(default=0)
    converted_count = models.PositiveIntegerField(default=0)
    revenue = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='crm_campaigns',
    )
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.name

    @property
    def conversion_rate(self):
        sent = self.sent_count or 0
        if not sent:
            return 0
        return round((self.converted_count or 0) / sent * 100, 1)

    @property
    def roi(self):
        cost = self.actual_cost or Decimal('0')
        if not cost:
            return 0
        return round(float((self.revenue or Decimal('0')) - cost) / float(cost) * 100, 1)


# ─────────────────────────────────────────────────────────────────────────
#  Tasks & feedback
# ─────────────────────────────────────────────────────────────────────────
class Task(TimeStampedModel):
    class Status(models.TextChoices):
        TODO = 'todo', 'To do'
        IN_PROGRESS = 'in_progress', 'In progress'
        DONE = 'done', 'Done'
        CANCELLED = 'cancelled', 'Cancelled'

    class Priority(models.TextChoices):
        LOW = 'low', 'Low'
        NORMAL = 'normal', 'Normal'
        HIGH = 'high', 'High'
        URGENT = 'urgent', 'Urgent'

    customer = models.ForeignKey(
        'pos.Customer', on_delete=models.CASCADE, null=True, blank=True,
        related_name='crm_tasks',
    )
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.TODO)
    priority = models.CharField(max_length=10, choices=Priority.choices, default=Priority.NORMAL)
    due_at = models.DateTimeField(null=True, blank=True)
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='crm_tasks',
    )
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['status', 'due_at', '-created_at']

    def __str__(self):
        return self.title


class Feedback(TimeStampedModel):
    class Kind(models.TextChoices):
        NPS = 'nps', 'NPS survey'
        CSAT = 'csat', 'Satisfaction (CSAT)'
        REVIEW = 'review', 'Review'
        COMPLAINT = 'complaint', 'Complaint'
        COMPLIMENT = 'compliment', 'Compliment'

    customer = models.ForeignKey(
        'pos.Customer', on_delete=models.CASCADE, null=True, blank=True,
        related_name='crm_feedback',
    )
    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.NPS)
    score = models.PositiveSmallIntegerField(help_text='0-10 for NPS, 1-5 for CSAT')
    comment = models.TextField(blank=True)
    channel = models.CharField(max_length=40, blank=True)
    submitted_at = models.DateTimeField(default=timezone.now)
    handled = models.BooleanField(default=False)
    handled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='crm_feedback_handled',
    )

    class Meta:
        ordering = ['-submitted_at']

    def __str__(self):
        return f'{self.get_kind_display()} · {self.score}'


# ─────────────────────────────────────────────────────────────────────────
#  Loyalty ledger
# ─────────────────────────────────────────────────────────────────────────
class PointsEntry(TimeStampedModel):
    class Kind(models.TextChoices):
        EARN = 'earn', 'Earned'
        REDEEM = 'redeem', 'Redeemed'
        ADJUST = 'adjust', 'Adjustment'
        EXPIRE = 'expire', 'Expired'
        BONUS = 'bonus', 'Bonus'

    customer = models.ForeignKey(
        'pos.Customer', on_delete=models.CASCADE, related_name='crm_points',
    )
    kind = models.CharField(max_length=10, choices=Kind.choices, default=Kind.EARN)
    points = models.IntegerField(help_text='Positive to add, negative to deduct')
    reason = models.CharField(max_length=255, blank=True)
    reference = models.CharField(max_length=60, blank=True)
    balance_after = models.IntegerField(default=0)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='crm_points_entries',
    )

    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = 'points entries'

    def __str__(self):
        return f'{self.customer.name} {self.points:+d}'
