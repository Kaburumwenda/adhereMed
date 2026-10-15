"""Check which tenant schemas are missing inventory tables.

Usage:
    python manage.py check_inventory_tables
"""

from django.core.management.base import BaseCommand
from django.db import connection
from tenants.models import Tenant


class Command(BaseCommand):
    help = "Check which tenant schemas are missing inventory tables (Classification, etc.)"

    def handle(self, *args, **options):
        tenants = list(
            Tenant.objects.filter(is_active=True).exclude(schema_name='public')
        )

        if not tenants:
            self.stdout.write("No active tenants found.")
            return

        # Tables we expect in every tenant schema (inventory app)
        expected_inventory_tables = [
            'inventory_classification',
            'inventory_category',
            'inventory_unit',
            'inventory_medicationstock',
        ]

        self.stdout.write(
            self.style.HTTP_INFO(
                f"Checking {len(tenants)} active tenant schemas...\n"
            )
        )

        for tenant in tenants:
            connection.set_schema(tenant.schema_name)
            try:
                with connection.cursor() as cursor:
                    cursor.execute("""
                        SELECT tablename
                        FROM pg_tables
                        WHERE schemaname = %s
                    """, [tenant.schema_name])
                    existing = {r[0] for r in cursor.fetchall()}

                missing = [
                    t for t in expected_inventory_tables
                    if t not in existing
                ]

                status = (
                    self.style.ERROR(f"  MISSING: {', '.join(missing)}")
                    if missing
                    else self.style.SUCCESS("  ✓ all inventory tables present")
                )
                self.stdout.write(
                    f"  {tenant.schema_name:20s} — {status}"
                )

                if missing:
                    # Also show migration state for this schema
                    with connection.cursor() as cursor:
                        cursor.execute("""
                            SELECT app, name
                            FROM django_migrations
                            WHERE app = 'inventory'
                            ORDER BY id
                        """)
                    applied = cursor.fetchall()
                    applied_names = [r[1] for r in applied]
                    self.stdout.write(
                        f"    Applied inventory migrations: "
                        f"{', '.join(applied_names) if applied_names else 'NONE'}"
                    )

            except Exception as exc:
                self.stderr.write(
                    self.style.ERROR(
                        f"  {tenant.schema_name}: error checking tables: {exc}"
                    )
                )
            finally:
                connection.set_schema_to_public()

        self.stdout.write("")
