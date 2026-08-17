from django.core.management.base import BaseCommand
from django_tenants.utils import tenant_context
from tenants.models import Tenant

from lab.seed_data import seed_lab_catalog


class Command(BaseCommand):
    help = 'Seed the lab test catalog with common tests and panels'

    def add_arguments(self, parser):
        parser.add_argument('--schema', default=None,
                            help='Tenant schema_name to seed (default: all hospital, clinic, and lab tenants)')

    def handle(self, *args, **options):
        schema = options['schema']
        if schema:
            tenants = Tenant.objects.filter(schema_name=schema)
        else:
            tenants = Tenant.objects.filter(type__in=['hospital', 'clinic', 'lab']).exclude(schema_name='public')

        if not tenants.exists():
            self.stdout.write(self.style.WARNING(
                'No matching tenants found. Use --schema to specify a tenant, or ensure hospital/clinic tenants exist.'
            ))
            return

        for tenant in tenants:
            self.stdout.write(f"\n=== Seeding {tenant.name} ({tenant.schema_name}) ===")
            self._seed_tenant(tenant)

    def _seed_tenant(self, tenant):
        with tenant_context(tenant):
            result = seed_lab_catalog()
            self.stdout.write(self.style.SUCCESS(
                f'  Tests: {result["tests_created"]} created, {result["tests_updated"]} updated, '
                f'{result["tests_skipped"]} already current.\n'
                f'  Panels: {result["panels_created"]} created, {result["panels_duped"]} already existed.'
            ))

