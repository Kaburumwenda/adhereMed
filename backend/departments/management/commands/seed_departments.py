"""
Seed demo departments for a given hospital tenant.

Usage:
    python manage.py seed_departments --schema yusra_hospital
"""

from django.core.management.base import BaseCommand
from django.db import transaction
from django_tenants.utils import tenant_context

from tenants.models import Tenant
from departments.models import Department


DEPARTMENTS = [
    "General Medicine",
    "Cardiology",
    "Pediatrics",
    "Orthopedics",
    "Obstetrics & Gynecology",
    "Dermatology",
    "Ophthalmology",
    "ENT",
    "Psychiatry",
    "Emergency",
]


class Command(BaseCommand):
    help = "Seed demo departments for a hospital tenant schema"

    def add_arguments(self, parser):
        parser.add_argument(
            '--schema', default=None,
            help='Tenant schema_name to seed (default: all hospital tenants)',
        )
        parser.add_argument(
            '--clear', action='store_true',
            help='Delete existing departments before seeding',
        )

    def handle(self, *args, **opts):
        schema = opts['schema']
        clear = opts['clear']

        if schema:
            tenants = Tenant.objects.filter(schema_name=schema)
        else:
            tenants = Tenant.objects.filter(type='hospital').exclude(schema_name='public')

        for tenant in tenants:
            self.stdout.write(f"\n=== Seeding departments for {tenant.name} ({tenant.schema_name}) ===")
            with tenant_context(tenant):
                try:
                    existing = Department.objects.count()
                except Exception:
                    existing = 0

                if existing > 0 and not clear:
                    self.stdout.write(f"  Already has {existing} departments — skipping (use --clear to reseed)")
                    continue

                if clear:
                    try:
                        Department.objects.all().delete()
                    except Exception:
                        pass

                created = 0
                for name in DEPARTMENTS:
                    try:
                        Department.objects.create(name=name)
                        created += 1
                    except Exception:
                        pass

                self.stdout.write(self.style.SUCCESS(f"  ✓ Created {created} departments"))

            # Print summary
            with tenant_context(tenant):
                try:
                    for d in Department.objects.all():
                        self.stdout.write(f"    {d.id}: {d.name}")
                except Exception:
                    pass
