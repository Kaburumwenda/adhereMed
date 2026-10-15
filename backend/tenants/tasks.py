"""Celery tasks for the tenant lifecycle.

``app.autodiscover_tasks()`` in ``config/celery.py`` picks this module up.
"""
from __future__ import annotations

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(name='tenants.provision_tenant', bind=True, max_retries=3, default_retry_delay=30)
def provision_tenant_task(self, tenant_id):
    """Create + migrate a tenant's schema in the background.

    ``provision_tenant`` is idempotent and records its own failures on the
    tenant row, so this task only retries on unexpected crashes.
    """
    from .provisioning import provision_tenant

    try:
        result = provision_tenant(tenant_id)
    except Exception as exc:  # defensive: provision_tenant should not raise
        logger.exception('Unexpected error provisioning tenant %s', tenant_id)
        raise self.retry(exc=exc)

    if not result.get('ok'):
        logger.warning(
            'Provisioning tenant %s did not succeed: %s',
            tenant_id, result.get('error'),
        )
    return result
