"""Tenant-aware Celery task base. Switches schema before running the body."""
from functools import wraps

from celery import shared_task
from django.db import connection
from django_tenants.utils import schema_context, get_tenant_model


def tenant_task(*task_args, **task_kwargs):
    """Decorator: register a Celery task that runs inside a tenant schema.

    Call site: ``my_task.delay(_schema='homecare_demo', ...)`` — the wrapper
    pops ``_schema`` and runs the body inside ``schema_context(_schema)``.
    """
    def decorator(func):
        @shared_task(*task_args, **task_kwargs)
        @wraps(func)
        def wrapper(*args, **kwargs):
            schema = kwargs.pop('_schema', None) or connection.schema_name
            with schema_context(schema):
                return func(*args, **kwargs)
        return wrapper
    return decorator


def homecare_tenants():
    """Yield homecare tenant schema names."""
    Tenant = get_tenant_model()
    return list(
        Tenant.objects.filter(type='homecare', is_active=True)
        .exclude(schema_name='public')
        .values_list('schema_name', flat=True)
    )
