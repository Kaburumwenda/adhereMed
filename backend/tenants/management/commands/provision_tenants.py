"""Finish provisioning for tenants whose schema is not ready yet.

This is the safety net for the asynchronous tenant-creation flow: if a
background job (Celery task or fallback thread) is lost — worker restart,
broker outage, deploy — the tenant simply stays ``pending`` and this command
completes it. Provisioning is idempotent, so running it is always safe.

Usage::

    # Resume every pending/failed tenant
    python manage.py provision_tenants

    # Only pending tenants (leave failures alone)
    python manage.py provision_tenants --pending-only

    # A specific tenant by schema name
    python manage.py provision_tenants --schema response_med

    # Seed during a deploy, without stopping on the first error
    python manage.py provision_tenants --continue-on-error
"""
from django.core.management.base import BaseCommand
from django.db import connection
from django_tenants.utils import get_tenant_model

from tenants.provisioning import provision_tenant, schema_exists


class Command(BaseCommand):
    help = "Create + migrate the schema for tenants that are not ready yet."

    def add_arguments(self, parser):
        parser.add_argument(
            '--schema',
            type=str,
            help='Only provision this tenant schema_name.',
        )
        parser.add_argument(
            '--pending-only',
            action='store_true',
            default=False,
            help='Only tenants in "pending"/"provisioning" state (skip "failed").',
        )
        parser.add_argument(
            '--all',
            action='store_true',
            default=False,
            help='Also re-check tenants already marked "ready" '
                 '(repairs a schema that was dropped behind our back).',
        )
        parser.add_argument(
            '--continue-on-error',
            action='store_true',
            default=False,
            help='Keep going and report a summary instead of stopping on the '
                 'first failure.',
        )

    def handle(self, *args, **options):
        Tenant = get_tenant_model()
        verbosity = int(options.get('verbosity', 1) or 0)
        schema = options.get('schema')
        pending_only = options.get('pending_only')
        include_all = options.get('all')
        continue_on_error = options.get('continue_on_error')

        connection.set_schema_to_public()

        if schema:
            tenants = list(Tenant.objects.filter(schema_name=schema))
            if not tenants:
                self.stderr.write(
                    self.style.ERROR(f'No tenant with schema_name="{schema}".')
                )
                return
        else:
            statuses = ['pending', 'provisioning']
            if not pending_only:
                statuses.append('failed')
            if include_all:
                tenants = list(
                    Tenant.objects.exclude(schema_name='public').order_by('name')
                )
            else:
                tenants = list(
                    Tenant.objects.filter(
                        provisioning_status__in=statuses
                    ).exclude(schema_name='public').order_by('name')
                )

        if not tenants:
            self.stdout.write(self.style.SUCCESS('Nothing to provision.'))
            self._schema_sanity_report()
            return

        self.stdout.write(f'Provisioning {len(tenants)} tenant(s)…\n')

        ok, failed = [], []
        for tenant in tenants:
            label = f'{tenant.name} ({tenant.schema_name})'
            if verbosity >= 1:
                self.stdout.write(f'  -> {label} [{tenant.provisioning_status}]')

            try:
                result = provision_tenant(tenant.pk, verbosity=max(verbosity - 1, 0))
            except Exception as exc:  # defensive: provision_tenant shouldn't raise
                if not continue_on_error:
                    raise
                failed.append((label, str(exc)))
                self.stderr.write(self.style.ERROR(f'    FAIL {exc}'))
                continue

            if result['ok']:
                created = 'schema created' if result['created_schema'] else 'schema existed'
                seeded = f", seeded {len(result['seeded'])}" if result['seeded'] else ''
                self.stdout.write(
                    self.style.SUCCESS(f'    OK ready ({created}{seeded})')
                )
                ok.append(label)
            else:
                failed.append((label, result['error']))
                self.stderr.write(self.style.ERROR(f'    FAIL {result["error"]}'))
                if not continue_on_error:
                    self.stdout.write(self.style.ERROR('\nStopping (use --continue-on-error to keep going).'))
                    break

        connection.set_schema_to_public()

        self.stdout.write('')
        self.stdout.write(
            self.style.SUCCESS(f'Done. succeeded={len(ok)} failed={len(failed)}')
        )
        for label, error in failed:
            self.stdout.write(self.style.ERROR(f'  failed: {label} — {error[:160]}'))

        # ── Sanity report: any tenant whose schema is missing ──
        self._schema_sanity_report()

    def _schema_sanity_report(self):
        """Warn about tenants whose schema is gone.

        Runs even when there is nothing to provision: a schema can be dropped
        behind the app's back (a failed rollback, a manual DROP) while the
        tenant still reads ``ready``. Those tenants 500 on every request with
        ``relation "..." does not exist``, so surface them loudly.
        """
        Tenant = get_tenant_model()
        connection.set_schema_to_public()

        suspicious = []
        for tenant in Tenant.objects.exclude(schema_name='public').order_by('name'):
            if tenant.schema_name and not schema_exists(tenant.schema_name):
                suspicious.append(tenant)

        if not suspicious:
            return

        self.stdout.write('')
        self.stderr.write(
            self.style.WARNING(
                f'{len(suspicious)} tenant(s) have NO schema in the database:'
            )
        )
        for tenant in suspicious:
            self.stderr.write(
                self.style.WARNING(
                    f'  {tenant.name} (id={tenant.pk}, schema={tenant.schema_name}, '
                    f'status={tenant.provisioning_status})'
                )
            )
        self.stderr.write(
            '  Repair with: python manage.py provision_tenants '
            '--schema <schema>   (or --all for every tenant)'
        )
