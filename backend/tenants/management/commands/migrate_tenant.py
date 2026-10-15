"""Apply missing migrations to one or all tenant schemas.

Usage:
    # Migrate ALL active tenants
    python manage.py migrate_tenant

    # Migrate a specific tenant by schema name
    python manage.py migrate_tenant --schema response_med

    # Migrate only a specific app for a tenant
    python manage.py migrate_tenant --schema response_med --app inventory

    # Also migrate the public (shared) schema
    python manage.py migrate_tenant --include-public

    # Create the schema first if it is missing (repair a "schema-less" tenant
    # whose Tenant/Domain rows survived but whose schema was dropped)
    python manage.py migrate_tenant --schema response_med --create-missing
"""

from django.core.management.base import BaseCommand
from django.core.management import call_command
from django.db import connection
from tenants.models import Tenant


class Command(BaseCommand):
    help = "Run Django migrations for one or all tenant schemas."

    def add_arguments(self, parser):
        parser.add_argument(
            '--schema',
            type=str,
            help='Tenant schema_name to migrate (default: all active tenants)',
        )
        parser.add_argument(
            '--app',
            type=str,
            help='Specific app label to migrate (default: all apps)',
        )
        parser.add_argument(
            '--include-public',
            action='store_true',
            default=False,
            help='Also migrate the public (shared) schema',
        )
        parser.add_argument(
            '--fake',
            action='store_true',
            default=False,
            help='Mark migrations as applied without actually running them',
        )
        parser.add_argument(
            '--create-missing',
            action='store_true',
            default=False,
            help=(
                'Create the Postgres schema first if it does not exist, then '
                'migrate it. Use this to recover a tenant whose schema was '
                'dropped (e.g. by a failed creation rollback) while its '
                'Tenant/Domain rows survived.'
            ),
        )

    def handle(self, *args, **options):
        schema = options.get('schema')
        app_label = options.get('app')
        include_public = options.get('include_public')
        fake = options.get('fake')
        create_missing = options.get('create_missing')

        tenants = []
        if schema:
            try:
                tenants = [Tenant.objects.get(schema_name=schema, is_active=True)]
            except Tenant.DoesNotExist:
                self.stderr.write(
                    self.style.ERROR(
                        f"No active tenant with schema_name='{schema}' found."
                    )
                )
                return
        else:
            tenants = list(Tenant.objects.filter(is_active=True).exclude(schema_name='public'))

        # ── Public schema ──
        if include_public or (schema == 'public'):
            self.stdout.write(self.style.HTTP_INFO("\n=== Migrating PUBLIC schema ==="))
            self._migrate_schema('public', app_label, fake)

        # ── Tenant schemas ──
        for tenant in tenants:
            self.stdout.write(
                self.style.HTTP_INFO(
                    f"\n=== Migrating '{tenant.name}' (schema={tenant.schema_name}) ==="
                )
            )
            self._migrate_schema(tenant.schema_name, app_label, fake, tenant, create_missing)

        self.stdout.write(self.style.SUCCESS("\n✓ Migration complete."))

    def _schema_exists(self, schema_name):
        """Return True if a Postgres schema with this name exists."""
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT COUNT(*) FROM pg_namespace WHERE nspname = %s",
                [schema_name],
            )
            return cursor.fetchone()[0] > 0

    def _migrate_schema(self, schema_name, app_label, fake, tenant=None, create_missing=False):
        """Set the search path to *schema_name* and call Django's migrate."""
        try:
            if create_missing and not self._schema_exists(schema_name):
                if tenant is None:
                    self.stderr.write(
                        self.style.ERROR(
                            f"  ✗ Schema '{schema_name}' is missing and cannot be "
                            f"created without a Tenant record."
                        )
                    )
                    return
                self.stdout.write(
                    self.style.WARNING(
                        f"  Schema '{schema_name}' is missing — creating it "
                        f"(this also runs all migrations)."
                    )
                )
                tenant.create_schema(check_if_exists=True, sync_schema=True, verbosity=0)
                if self._schema_exists(schema_name):
                    self.stdout.write(
                        self.style.SUCCESS(f"  ✓ Created schema '{schema_name}'.")
                    )
                else:
                    self.stderr.write(
                        self.style.ERROR(f"  ✗ Schema '{schema_name}' was not created.")
                    )
                return

            connection.set_schema(schema_name)
            self.stdout.write(f"  Search path → {connection.schema_name}")

            migrate_args = []
            if app_label:
                migrate_args.append(app_label)

            call_command(
                'migrate',
                *migrate_args,
                fake=fake,
                stdout=self.stdout,
                stderr=self.stderr,
                verbosity=2,
            )

            # Show applied migrations for this schema
            self._show_applied(app_label)

        except Exception as exc:
            self.stderr.write(
                self.style.ERROR(f"  ✗ Error migrating {schema_name}: {exc}")
            )
            raise
        finally:
            connection.set_schema_to_public()

    def _show_applied(self, app_label):
        """Print the latest applied migration for the current schema."""
        from django.db.migrations.recorder import MigrationRecorder
        recorder = MigrationRecorder(connection)
        applied = recorder.applied_migrations()

        if app_label:
            applied = {
                k: v for k, v in applied.items()
                if k[0] == app_label
            }

        if not applied:
            self.stdout.write("  No migrations applied.")
            return

        # Group by app
        apps = {}
        for (a, m) in sorted(applied.keys()):
            apps.setdefault(a, []).append(m)

        for a, ms in apps.items():
            self.stdout.write(f"  {a}: {len(ms)} migration(s) applied (latest: {ms[-1]})")
