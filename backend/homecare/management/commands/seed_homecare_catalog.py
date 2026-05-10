"""
Seed the per-tenant homecare catalog (diagnoses + allergies) by mirroring the
global `clinical_catalog` data (which lives in the public schema).

Usage (run from inside a tenant schema):
    python manage.py tenant_command seed_homecare_catalog --schema=<schema>
    python manage.py tenant_command seed_homecare_catalog --schema=<schema> --diagnoses
    python manage.py tenant_command seed_homecare_catalog --schema=<schema> --allergies
    python manage.py tenant_command seed_homecare_catalog --schema=<schema> --reset

Or invoked from the superadmin "Seed catalog" UI which dispatches per-tenant.
"""
from django.core.management.base import BaseCommand
from django.db import transaction
from django_tenants.utils import schema_context

from homecare.models import HomecareAllergy, HomecareDiagnosis


class Command(BaseCommand):
    help = 'Seed the homecare per-tenant catalog from clinical_catalog.'

    def add_arguments(self, parser):
        parser.add_argument('--diagnoses', action='store_true',
                            help='Only seed diagnoses.')
        parser.add_argument('--allergies', action='store_true',
                            help='Only seed allergies.')
        parser.add_argument('--reset', action='store_true',
                            help='Delete existing seeded rows before importing '
                                 '(custom rows are preserved).')

    @transaction.atomic
    def handle(self, *args, **opts):
        do_diag = opts['diagnoses'] or not opts['allergies']
        do_alle = opts['allergies'] or not opts['diagnoses']

        # Pull source data from the PUBLIC schema (clinical_catalog lives there).
        with schema_context('public'):
            from clinical_catalog.models import Allergy, ChronicCondition
            allergies_src = list(Allergy.objects.filter(is_active=True).values(
                'name', 'category', 'description', 'common_symptoms'))
            conditions_src = list(ChronicCondition.objects.filter(is_active=True).values(
                'name', 'category', 'icd_code', 'description'))

        diag_added = diag_skipped = 0
        alle_added = alle_skipped = 0

        if do_diag:
            if opts['reset']:
                HomecareDiagnosis.objects.filter(
                    source=HomecareDiagnosis.Source.SEED
                ).delete()
            existing = set(HomecareDiagnosis.objects.values_list('name', flat=True))
            new_rows = []
            for row in conditions_src:
                if row['name'] in existing:
                    diag_skipped += 1
                    continue
                new_rows.append(HomecareDiagnosis(
                    name=row['name'],
                    category=row['category'] or '',
                    icd_code=row['icd_code'] or '',
                    description=row['description'] or '',
                    source=HomecareDiagnosis.Source.SEED,
                    is_active=True,
                ))
            HomecareDiagnosis.objects.bulk_create(new_rows, ignore_conflicts=True)
            diag_added = len(new_rows)

        if do_alle:
            if opts['reset']:
                HomecareAllergy.objects.filter(
                    source=HomecareAllergy.Source.SEED
                ).delete()
            existing = set(HomecareAllergy.objects.values_list('name', flat=True))
            new_rows = []
            for row in allergies_src:
                if row['name'] in existing:
                    alle_skipped += 1
                    continue
                new_rows.append(HomecareAllergy(
                    name=row['name'],
                    category=row['category'] or '',
                    description=row['description'] or '',
                    common_symptoms=row['common_symptoms'] or '',
                    source=HomecareAllergy.Source.SEED,
                    is_active=True,
                ))
            HomecareAllergy.objects.bulk_create(new_rows, ignore_conflicts=True)
            alle_added = len(new_rows)

        msg = (f'Diagnoses: +{diag_added} added, {diag_skipped} skipped. '
               f'Allergies: +{alle_added} added, {alle_skipped} skipped.')
        self.stdout.write(self.style.SUCCESS(msg))
