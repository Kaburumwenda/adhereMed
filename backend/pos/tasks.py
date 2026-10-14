"""Celery tasks for the POS app."""
from datetime import timedelta
from celery import shared_task
from django.utils import timezone
from django_tenants.utils import schema_context, get_tenant_model


@shared_task(name='pos.tasks.cleanup_expired_parked_sales')
def cleanup_expired_parked_sales():
    """Delete all ParkedSale records older than 48 hours across every tenant schema.

    Scheduled by Celery Beat every 15 minutes. The viewset also excludes
    expired records at read-time, but this task physically removes them so
    the table doesn't grow indefinitely.
    """
    cutoff = timezone.now() - timedelta(hours=48)
    Tenant = get_tenant_model()
    total_deleted = 0
    for tenant in Tenant.objects.exclude(schema_name='public'):
        with schema_context(tenant.schema_name):
            from .models import ParkedSale
            qs = ParkedSale.objects.filter(created_at__lt=cutoff)
            count = qs.count()
            if count:
                qs.delete()
                total_deleted += count
    return f'Deleted {total_deleted} expired parked sales'
