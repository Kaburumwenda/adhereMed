"""Idempotent, resumable tenant schema provisioning.

Why this module exists
----------------------
Tenant creation used to run the tenant's entire migration set *synchronously*
inside the HTTP request (``Tenant.save()`` -> ``create_schema()`` -> ~25 apps'
migrations, 30s+). If the browser/proxy/worker timed out mid-migration the
request was killed **after** the ``tenants_tenant`` row had already been
committed, leaving an orphan tenant whose schema, domain and admin user did not
exist. Every later request to that tenant failed with::

    ProgrammingError: relation "inventory_classification" does not exist

The shape of tenant creation is now::

    create public rows (one fast atomic transaction)  ->  provision (background)

``provision_tenant`` is deliberately **idempotent and resumable**:

* it creates the schema only when missing (``check_if_exists=True``);
* it then runs ``migrate``, which is a no-op on a fresh schema and the resume
  path for a half-migrated one;
* failures are recorded on the tenant (``provisioning_status='failed'`` plus
  ``provisioning_error``) rather than raised, so a retry can pick up where it
  stopped.

Because of that, a lost background job is never fatal: the tenant simply stays
``pending`` and the ``provision_tenants`` management command (or the retry API)
completes it later.
"""
from __future__ import annotations

import logging

from django.core.management import call_command
from django.db import connection
from django.db.migrations.exceptions import NodeNotFoundError
from django.utils import timezone
from django_tenants.utils import get_tenant_model, schema_context

logger = logging.getLogger(__name__)

#: Statuses meaning "the schema is not usable yet".
UNREADY_STATUSES = ('pending', 'provisioning', 'failed')

#: Truncate stored failure messages so a huge traceback can't bloat the row.
MAX_ERROR_LEN = 2000


def _set_status(tenant_id, **fields):
    """Update provisioning bookkeeping without going through ``save()``.

    ``Tenant.save()`` may itself trigger schema creation (``auto_create_schema``),
    so all status bookkeeping uses ``QuerySet.update()`` which never calls
    ``save()``.
    """
    Tenant = get_tenant_model()
    Tenant.objects.filter(pk=tenant_id).update(**fields)


def schema_exists(schema_name) -> bool:
    """Return True if the Postgres schema exists.

    Uses ``pg_namespace`` rather than ``information_schema.schemata`` because
    the latter is privilege-filtered and can hide schemas the app user owns.
    """
    if not schema_name:
        return False
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT COUNT(*) FROM pg_namespace WHERE nspname = %s", [schema_name]
        )
        return cursor.fetchone()[0] > 0


def _run_migrations(schema_name, verbosity=0):
    """Apply outstanding migrations inside ``schema_name``."""
    with schema_context(schema_name):
        call_command('migrate', interactive=False, verbosity=verbosity)


def _run_migrations_subprocess(schema_name, verbosity=0):
    """Apply migrations from a *fresh* interpreter.

    Long-lived processes (notably the Celery worker) keep the Django app
    registry they built at start-up. If a deploy adds a new app — or a
    migration that depends on one — the worker's ``MigrationLoader`` cannot see
    the new nodes and raises::

        NodeNotFoundError: Migration inventory.0020_... dependencies reference
        nonexistent parent node ('logistics', '0001_initial')

    even though that migration file is on disk and ``manage.py`` run by hand
    works fine. A subprocess re-imports everything from disk, so it always sees
    the deployed migration graph. This makes provisioning self-healing instead
    of requiring the operator to notice a stale worker.
    """
    import subprocess
    import sys

    from django.conf import settings

    code = (
        'import os\n'
        'os.environ.setdefault("DJANGO_SETTINGS_MODULE", %r)\n'
        'import django\n'
        'django.setup()\n'
        'from django.core.management import call_command\n'
        'from django_tenants.utils import schema_context\n'
        'with schema_context(%r):\n'
        '    call_command("migrate", interactive=False, verbosity=%d)\n'
    ) % (
        settings.SETTINGS_MODULE, schema_name, verbosity,
    )

    proc = subprocess.run(
        [sys.executable, '-c', code],
        cwd=str(settings.BASE_DIR),
        capture_output=True,
        text=True,
        timeout=1800,
    )
    if proc.stdout:
        logger.info('subprocess migrate %s stdout:\n%s', schema_name, proc.stdout)
    if proc.returncode != 0:
        raise RuntimeError(
            'Subprocess migration failed for schema %s: %s'
            % (schema_name, (proc.stderr or proc.stdout or '')[-MAX_ERROR_LEN:])
        )


def _seed_defaults(schema_name, verbosity=0):
    """Create the rows every tenant needs. Best-effort — never fatal.

    Migration ``inventory.0016_classification`` already seeds the default
    "Routine" classification; this is a safety net for schemas that were
    migrated in an unusual order, and the place to add further seeds.
    """
    created = []
    try:
        with schema_context(schema_name):
            from inventory.models import Classification
            obj, was_created = Classification.objects.get_or_create(
                name='Routine',
                defaults={
                    'description': 'Default classification for routine stock items.'
                },
            )
            if was_created:
                created.append(f'inventory.Classification:{obj.pk}')
    except Exception:
        # Seeding must never fail the provisioning run — the schema is already
        # usable at this point.
        logger.warning(
            'Seeding defaults failed for schema %s', schema_name, exc_info=True
        )
    return created


def provision_tenant(tenant_id, *, verbosity=0, seed=True):
    """Create + migrate a tenant's schema. Idempotent, resumable, non-raising.

    Returns a dict describing the outcome::

        {'ok': bool, 'status': 'ready'|'failed'|'missing',
         'error': str, 'schema': str, 'created_schema': bool,
         'migrated': bool, 'seeded': list[str]}
    """
    Tenant = get_tenant_model()

    try:
        tenant = Tenant.objects.get(pk=tenant_id)
    except Tenant.DoesNotExist:
        logger.warning('provision_tenant: tenant %s no longer exists', tenant_id)
        return {
            'ok': False,
            'status': 'missing',
            'error': f'Tenant {tenant_id} not found',
            'schema': '',
            'created_schema': False,
            'migrated': False,
            'seeded': [],
        }

    schema_name = tenant.schema_name
    result = {
        'ok': False,
        'status': 'failed',
        'error': '',
        'schema': schema_name,
        'created_schema': False,
        'migrated': False,
        'seeded': [],
    }

    if not schema_name or schema_name == 'public':
        error = f'Tenant {tenant_id} has no usable schema_name'
        logger.error('provision_tenant: %s', error)
        _set_status(
            tenant_id,
            provisioning_status=Tenant.ProvisioningStatus.FAILED,
            provisioning_error=error,
            provisioning_completed_at=timezone.now(),
        )
        result['error'] = error
        return result

    # Schema DDL must run from the public schema.
    connection.set_schema_to_public()
    _set_status(
        tenant_id,
        provisioning_status=Tenant.ProvisioningStatus.PROVISIONING,
        provisioning_error='',
        provisioning_started_at=timezone.now(),
        provisioning_completed_at=None,
    )

    try:
        if not schema_exists(schema_name):
            # create_schema() also runs the migrations for the new schema.
            # check_if_exists=True keeps this safe to re-run.
            try:
                tenant.create_schema(
                    check_if_exists=True, sync_schema=True, verbosity=verbosity
                )
            except NodeNotFoundError:
                # A stale in-process migration graph must not abort the run:
                # the schema may already exist (empty) and the subprocess
                # fallback below will build its tables.
                logger.warning(
                    'Stale migration graph while creating schema %s; falling '
                    'back to a subprocess migration', schema_name,
                )
                if not schema_exists(schema_name):
                    with connection.cursor() as cursor:
                        cursor.execute(
                            'CREATE SCHEMA IF NOT EXISTS %s'
                            % connection.ops.quote_name(schema_name)
                        )
            result['created_schema'] = True

        if not schema_exists(schema_name):
            raise RuntimeError(f'Schema "{schema_name}" was not created')

        # No-op for a freshly synced schema; the resume path for a partially
        # migrated one.
        try:
            _run_migrations(schema_name, verbosity=verbosity)
        except NodeNotFoundError:
            logger.warning(
                'Stale migration graph in-process for schema %s; re-running '
                'migrations from a fresh interpreter', schema_name,
            )
            _run_migrations_subprocess(schema_name, verbosity=verbosity)
        result['migrated'] = True

        if seed:
            result['seeded'] = _seed_defaults(schema_name, verbosity=verbosity)

        result.update(ok=True, status='ready')
        _set_status(
            tenant_id,
            provisioning_status=Tenant.ProvisioningStatus.READY,
            provisioning_error='',
            provisioning_completed_at=timezone.now(),
        )
        logger.info(
            'Tenant %s (%s) provisioned (created_schema=%s)',
            tenant_id, schema_name, result['created_schema'],
        )
        return result

    except Exception as exc:
        error = str(exc)[:MAX_ERROR_LEN]
        logger.exception(
            'Provisioning failed for tenant %s (%s)', tenant_id, schema_name
        )
        try:
            _set_status(
                tenant_id,
                provisioning_status=Tenant.ProvisioningStatus.FAILED,
                provisioning_error=error,
                provisioning_completed_at=timezone.now(),
            )
        except Exception:
            logger.exception(
                'Could not record provisioning failure for tenant %s', tenant_id
            )
        result['error'] = error
        return result

    finally:
        try:
            connection.set_schema_to_public()
        except Exception:
            pass


def _broker_reachable(timeout=1.0) -> bool:
    """Fast TCP probe of the Celery broker.

    Publishing to an unreachable broker can block for a long time inside
    kombu's connect-retry loop (observed ~110s against a refused Redis). A
    pre-flight socket check costs ~1ms when the broker is up and lets us go
    straight to the thread fallback when it is down — which matters because
    this runs inside the tenant-creation request.

    Returns True when the broker looks reachable *or* when the URL scheme is
    not one we can probe (in which case we let the normal publish path decide).
    """
    import socket
    from urllib.parse import urlparse

    from django.conf import settings

    url = getattr(settings, 'CELERY_BROKER_URL', '') or ''
    try:
        parsed = urlparse(url)
    except Exception:
        return True

    if parsed.scheme not in ('redis', 'rediss'):
        # Not a scheme we can cheaply probe — let the publish attempt decide.
        return True

    host = parsed.hostname
    if not host:
        return True
    port = parsed.port or (6379 if parsed.scheme == 'redis' else 6379)

    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        logger.warning(
            'Celery broker %s:%s unreachable; provisioning will use a thread',
            host, port,
        )
        return False


def _worker_alive(timeout=1.0) -> bool:
    """Return True if at least one Celery **worker** answers a ping.

    A reachable broker is not enough. If no worker is consuming the default
    queue, ``apply_async`` still succeeds and the task sits in Redis forever —
    the tenant stays ``pending`` and the UI shows "Queued" indefinitely
    (exactly the production symptom this guards against). ``control.ping``
    round-trips to the workers, so it detects that case.

    ``limit=1`` makes the broadcast return as soon as the first worker replies
    instead of always blocking for the full ``timeout``.
    """
    try:
        from config.celery import app as celery_app
        replies = celery_app.control.ping(timeout=timeout, limit=1)
        return bool(replies)
    except Exception:
        logger.warning(
            'Celery worker ping failed; assuming no worker is available',
            exc_info=True,
        )
        return False


def dispatch_provisioning(tenant_id) -> str:
    """Kick off provisioning in the background. Returns how it was dispatched.

    Prefers Celery **only when a worker is actually listening** (a reachable
    broker alone is not enough — see ``_worker_alive``); otherwise falls back to
    a daemon thread so provisioning runs even when no worker is deployed. Either
    way the tenant is already persisted and marked ``pending``, so a lost
    dispatch is recoverable via the retry endpoint or the ``provision_tenants``
    sweeper command.
    """
    if _broker_reachable() and _worker_alive():
        try:
            from .tasks import provision_tenant_task
            # retry=False keeps a flaky broker from blocking on kombu's
            # connect-retry loop.
            provision_tenant_task.apply_async(args=[tenant_id], retry=False)
            return 'celery'
        except Exception:
            logger.warning(
                'Celery dispatch failed for tenant %s; falling back to a thread',
                tenant_id, exc_info=True,
            )
    else:
        logger.info(
            'No Celery worker available for tenant %s; provisioning in a thread',
            tenant_id,
        )

    try:
        import threading

        thread = threading.Thread(
            target=provision_tenant,
            args=(tenant_id,),
            name=f'provision-tenant-{tenant_id}',
            daemon=True,
        )
        thread.start()
        return 'thread'
    except Exception:
        logger.exception(
            'Could not dispatch provisioning for tenant %s; it stays pending '
            'and can be resumed with "manage.py provision_tenants"', tenant_id,
        )
        return 'none'
