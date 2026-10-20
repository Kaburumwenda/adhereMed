from rest_framework import serializers

from pos.models import Customer

from .models import (
    Campaign,
    CustomerProfile,
    Feedback,
    Interaction,
    Opportunity,
    PointsEntry,
    Segment,
    Tag,
    Task,
    Ticket,
)


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = '__all__'


class SegmentSerializer(serializers.ModelSerializer):
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Segment
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_member_count(self, obj):
        return obj.members.count()


class CustomerProfileSerializer(serializers.ModelSerializer):
    segment_name = serializers.CharField(source='segment.name', read_only=True)
    segment_color = serializers.CharField(source='segment.color', read_only=True)
    owner_name = serializers.SerializerMethodField()
    tags = TagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Tag.objects.all(), source='tags', write_only=True, required=False,
    )

    # Flattened customer fields for convenience
    name = serializers.CharField(source='customer.name', read_only=True)
    phone = serializers.CharField(source='customer.phone', read_only=True)
    email = serializers.CharField(source='customer.email', read_only=True)
    address = serializers.CharField(source='customer.address', read_only=True)
    branch = serializers.IntegerField(source='customer.branch_id', read_only=True)
    branch_name = serializers.CharField(source='customer.branch.name', read_only=True)
    is_active = serializers.BooleanField(source='customer.is_active', read_only=True)
    loyalty_points = serializers.IntegerField(source='customer.loyalty_points', read_only=True)
    loyalty_tier = serializers.CharField(source='customer.loyalty_tier', read_only=True)
    total_purchases = serializers.DecimalField(
        source='customer.total_purchases', max_digits=12, decimal_places=2, read_only=True,
    )
    visit_count = serializers.IntegerField(source='customer.visit_count', read_only=True)

    class Meta:
        model = CustomerProfile
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_owner_name(self, obj):
        if not obj.owner:
            return ''
        return getattr(obj.owner, 'full_name', '') or obj.owner.get_username()


class InteractionSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    created_by_name = serializers.SerializerMethodField()

    class Meta:
        model = Interaction
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return ''
        return getattr(obj.created_by, 'full_name', '') or obj.created_by.get_username()


class TicketSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_phone = serializers.CharField(source='customer.phone', read_only=True)
    assigned_to_name = serializers.SerializerMethodField()
    is_overdue = serializers.BooleanField(read_only=True)

    class Meta:
        model = Ticket
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at', 'reference']

    def get_assigned_to_name(self, obj):
        if not obj.assigned_to:
            return ''
        return getattr(obj.assigned_to, 'full_name', '') or obj.assigned_to.get_username()


class OpportunitySerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    owner_name = serializers.SerializerMethodField()
    weighted_value = serializers.DecimalField(max_digits=14, decimal_places=2, read_only=True)

    class Meta:
        model = Opportunity
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_owner_name(self, obj):
        if not obj.owner:
            return ''
        return getattr(obj.owner, 'full_name', '') or obj.owner.get_username()


class CampaignSerializer(serializers.ModelSerializer):
    segment_name = serializers.CharField(source='segment.name', read_only=True)
    owner_name = serializers.SerializerMethodField()
    conversion_rate = serializers.FloatField(read_only=True)
    roi = serializers.FloatField(read_only=True)

    class Meta:
        model = Campaign
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_owner_name(self, obj):
        if not obj.owner:
            return ''
        return getattr(obj.owner, 'full_name', '') or obj.owner.get_username()


class TaskSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    assigned_to_name = serializers.SerializerMethodField()

    class Meta:
        model = Task
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_assigned_to_name(self, obj):
        if not obj.assigned_to:
            return ''
        return getattr(obj.assigned_to, 'full_name', '') or obj.assigned_to.get_username()


class FeedbackSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)

    class Meta:
        model = Feedback
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class PointsEntrySerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)

    class Meta:
        model = PointsEntry
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class CustomerCRMSerializer(serializers.ModelSerializer):
    """Rich list row for the CRM customer table (joins profile + pos.Customer)."""

    profile_id = serializers.SerializerMethodField()
    lifecycle_stage = serializers.SerializerMethodField()
    segment_name = serializers.SerializerMethodField()
    segment_color = serializers.SerializerMethodField()
    owner_name = serializers.SerializerMethodField()
    health_score = serializers.SerializerMethodField()
    churn_risk = serializers.SerializerMethodField()
    lifetime_value = serializers.SerializerMethodField()
    outstanding_balance = serializers.SerializerMethodField()
    last_contact_at = serializers.SerializerMethodField()
    next_follow_up_at = serializers.SerializerMethodField()
    open_tickets = serializers.SerializerMethodField()
    open_opportunities = serializers.SerializerMethodField()
    is_vip = serializers.SerializerMethodField()
    tags = serializers.SerializerMethodField()

    class Meta:
        model = Customer
        fields = [
            'id', 'name', 'phone', 'email', 'address', 'branch', 'is_active',
            'loyalty_points', 'loyalty_tier', 'total_purchases', 'visit_count',
            'created_at', 'updated_at',
            'profile_id', 'lifecycle_stage', 'segment_name', 'segment_color',
            'owner_name', 'health_score', 'churn_risk', 'lifetime_value',
            'outstanding_balance', 'last_contact_at', 'next_follow_up_at',
            'open_tickets', 'open_opportunities', 'is_vip', 'tags',
        ]

    def _profile(self, obj):
        return getattr(obj, 'crm_profile', None)

    def get_profile_id(self, obj):
        p = self._profile(obj)
        return p.id if p else None

    def get_lifecycle_stage(self, obj):
        p = self._profile(obj)
        return p.lifecycle_stage if p else 'active'

    def get_segment_name(self, obj):
        p = self._profile(obj)
        return p.segment.name if p and p.segment else ''

    def get_segment_color(self, obj):
        p = self._profile(obj)
        return p.segment.color if p and p.segment else ''

    def get_owner_name(self, obj):
        p = self._profile(obj)
        if not p or not p.owner:
            return ''
        return getattr(p.owner, 'full_name', '') or p.owner.get_username()

    def get_health_score(self, obj):
        p = self._profile(obj)
        return p.health_score if p else 70

    def get_churn_risk(self, obj):
        p = self._profile(obj)
        return p.churn_risk if p else 20

    def get_lifetime_value(self, obj):
        p = self._profile(obj)
        return str(p.lifetime_value) if p else str(obj.total_purchases or 0)

    def get_outstanding_balance(self, obj):
        p = self._profile(obj)
        return str(p.outstanding_balance) if p else '0.00'

    def get_last_contact_at(self, obj):
        p = self._profile(obj)
        return p.last_contact_at if p else None

    def get_next_follow_up_at(self, obj):
        p = self._profile(obj)
        return p.next_follow_up_at if p else None

    def get_open_tickets(self, obj):
        return obj.crm_tickets.exclude(status__in=['resolved', 'closed']).count()

    def get_open_opportunities(self, obj):
        return obj.crm_opportunities.exclude(stage__in=['won', 'lost']).count()

    def get_is_vip(self, obj):
        p = self._profile(obj)
        return p.is_vip if p else False

    def get_tags(self, obj):
        p = self._profile(obj)
        if not p:
            return []
        return [{'id': t.id, 'name': t.name, 'color': t.color} for t in p.tags.all()]
