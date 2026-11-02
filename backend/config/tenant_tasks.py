"""Tenant-aware Celery task helpers.

Shared by any app that needs to run work inside a tenant schema. Beat
tasks run in the ``public`` schema, so they fan out per tenant by calling
``task.delay(_schema=<schema>)``.

(``homecare/tasks_base.py`` predates this and keeps its own copy; new
apps should use this module.)
"""
from functools import wraps

from celery import shared_task
from django.db import connection
from django_tenants.utils import get_tenant_model, schema_context


def tenant_task(*task_args, **task_kwargs):
    """Register a Celery task that switches schema before running its body."""
    def decorator(func):
        @shared_task(*task_args, **task_kwargs)
        @wraps(func)
        def wrapper(*args, **kwargs):
            schema = kwargs.pop('_schema', None) or connection.schema_name
            with schema_context(schema):
                return func(*args, **kwargs)
        return wrapper
    return decorator


def tenants_of_type(*tenant_types):
    """Schema names for active, ready tenants of the given types."""
    Tenant = get_tenant_model()
    qs = (Tenant.objects
          .filter(type__in=tenant_types, is_active=True)
          .exclude(schema_name='public'))
    # Never dispatch work into a schema that is still being built.
    status_field = getattr(Tenant, 'provisioning_status', None)
    if status_field is not None:
        qs = qs.exclude(provisioning_status__in=('pending', 'provisioning', 'failed'))
    return list(qs.values_list('schema_name', flat=True))
