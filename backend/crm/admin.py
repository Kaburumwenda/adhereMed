from django.contrib import admin

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


@admin.register(Segment)
class SegmentAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'kind', 'is_active')
    list_filter = ('kind', 'is_active')
    search_fields = ('name', 'code')


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ('name', 'color')
    search_fields = ('name',)


@admin.register(CustomerProfile)
class CustomerProfileAdmin(admin.ModelAdmin):
    list_display = ('customer', 'lifecycle_stage', 'segment', 'health_score', 'churn_risk', 'is_vip')
    list_filter = ('lifecycle_stage', 'is_vip', 'preferred_channel', 'lead_source')
    search_fields = ('customer__name', 'customer__phone', 'company')
    filter_horizontal = ('tags',)


@admin.register(Interaction)
class InteractionAdmin(admin.ModelAdmin):
    list_display = ('customer', 'kind', 'direction', 'subject', 'occurred_at', 'outcome')
    list_filter = ('kind', 'direction', 'outcome')
    search_fields = ('subject', 'summary', 'customer__name')


@admin.register(Ticket)
class TicketAdmin(admin.ModelAdmin):
    list_display = ('reference', 'subject', 'customer', 'priority', 'status', 'assigned_to', 'opened_at')
    list_filter = ('status', 'priority', 'category')
    search_fields = ('reference', 'subject', 'customer__name')


@admin.register(Opportunity)
class OpportunityAdmin(admin.ModelAdmin):
    list_display = ('title', 'customer', 'stage', 'value', 'probability', 'expected_close_date')
    list_filter = ('stage',)
    search_fields = ('title', 'customer__name')


@admin.register(Campaign)
class CampaignAdmin(admin.ModelAdmin):
    list_display = ('name', 'channel', 'status', 'start_date', 'sent_count', 'converted_count', 'revenue')
    list_filter = ('status', 'channel')
    search_fields = ('name',)


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ('title', 'customer', 'status', 'priority', 'due_at', 'assigned_to')
    list_filter = ('status', 'priority')
    search_fields = ('title', 'customer__name')


@admin.register(Feedback)
class FeedbackAdmin(admin.ModelAdmin):
    list_display = ('customer', 'kind', 'score', 'submitted_at', 'handled')
    list_filter = ('kind', 'handled')


@admin.register(PointsEntry)
class PointsEntryAdmin(admin.ModelAdmin):
    list_display = ('customer', 'kind', 'points', 'balance_after', 'reason', 'created_at')
    list_filter = ('kind',)
    search_fields = ('customer__name', 'reason', 'reference')
