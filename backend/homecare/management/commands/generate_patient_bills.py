"""Auto-generate patient bills based on each patient's active care plan.

Usage:
    # Run for all homecare tenants:
    python manage.py generate_patient_bills

    # Run for a specific tenant schema:
    python manage.py generate_patient_bills --schema=homecare_demo
"""
from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context, get_tenant_model

from homecare.services import auto_generate_bills_for_tenant


class Command(BaseCommand):
    help = 'Generate PatientBill entries for care plans whose next billing period has elapsed.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--schema', dest='schema', default=None,
            help='Only run for this tenant schema (default: every active homecare tenant).')

    def handle(self, *args, **options):
        schema = options.get('schema')
        Tenant = get_tenant_model()

        if schema:
            schemas = [schema]
        else:
            schemas = list(
                Tenant.objects.filter(type='homecare', is_active=True)
                .exclude(schema_name='public')
                .values_list('schema_name', flat=True)
            )

        total = 0
        for name in schemas:
            with schema_context(name):
                created = auto_generate_bills_for_tenant()
                total += created
                self.stdout.write(
                    self.style.SUCCESS(f'[{name}] Generated {created} bill(s).'))
        self.stdout.write(self.style.SUCCESS(
            f'Done — {total} bill(s) created across {len(schemas)} tenant(s).'))
