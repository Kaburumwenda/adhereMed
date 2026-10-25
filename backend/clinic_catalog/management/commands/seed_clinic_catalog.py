"""
Seed the per-tenant clinic catalog (allergies + chronic conditions) by
mirroring the global `clinical_catalog` data (which lives in the public
schema).

Usage (run from inside a tenant schema):
    python manage.py tenant_command seed_clinic_catalog --schema=<schema>
    python manage.py tenant_command seed_clinic_catalog --schema=<schema> --allergies
    python manage.py tenant_command seed_clinic_catalog --schema=<schema> --conditions
    python manage.py tenant_command seed_clinic_catalog --schema=<schema> --reset

Also invoked from the clinic Catalog → Seed Data page.
"""
from django.core.management.base import BaseCommand
from django.db import transaction
from django_tenants.utils import schema_context

from clinic_catalog.models import ClinicAllergy, ClinicChronicCondition


class Command(BaseCommand):
    help = 'Seed the clinic per-tenant catalog from clinical_catalog.'

    def add_arguments(self, parser):
        parser.add_argument('--allergies', action='store_true',
                            help='Only seed allergies.')
        parser.add_argument('--conditions', action='store_true',
                            help='Only seed chronic conditions.')
        parser.add_argument('--reset', action='store_true',
                            help='Delete existing seeded rows before importing '
                                 '(custom rows are preserved).')

    @transaction.atomic
    def handle(self, *args, **opts):
        do_alle = opts['allergies'] or not opts['conditions']
        do_cond = opts['conditions'] or not opts['allergies']

        # Pull source data from the PUBLIC schema (clinical_catalog lives there).
        with schema_context('public'):
            from clinical_catalog.models import Allergy, ChronicCondition
            allergies_src = list(Allergy.objects.filter(is_active=True).values(
                'name', 'category', 'description', 'common_symptoms'))
            conditions_src = list(ChronicCondition.objects.filter(is_active=True).values(
                'name', 'category', 'icd_code', 'description'))

        alle_added = alle_skipped = 0
        cond_added = cond_skipped = 0

        if do_alle:
            if opts['reset']:
                ClinicAllergy.objects.filter(
                    source=ClinicAllergy.Source.SEED
                ).delete()
            existing = set(ClinicAllergy.objects.values_list('name', flat=True))
            new_rows = []
            for row in allergies_src:
                if row['name'] in existing:
                    alle_skipped += 1
                    continue
                new_rows.append(ClinicAllergy(
                    name=row['name'],
                    category=row['category'] or '',
                    description=row['description'] or '',
                    common_symptoms=row['common_symptoms'] or '',
                    source=ClinicAllergy.Source.SEED,
                    is_active=True,
                ))
            ClinicAllergy.objects.bulk_create(new_rows, ignore_conflicts=True)
            alle_added = len(new_rows)

        if do_cond:
            if opts['reset']:
                ClinicChronicCondition.objects.filter(
                    source=ClinicChronicCondition.Source.SEED
                ).delete()
            existing = set(ClinicChronicCondition.objects.values_list('name', flat=True))
            new_rows = []
            for row in conditions_src:
                if row['name'] in existing:
                    cond_skipped += 1
                    continue
                new_rows.append(ClinicChronicCondition(
                    name=row['name'],
                    category=row['category'] or '',
                    icd_code=row['icd_code'] or '',
                    description=row['description'] or '',
                    source=ClinicChronicCondition.Source.SEED,
                    is_active=True,
                ))
            ClinicChronicCondition.objects.bulk_create(new_rows, ignore_conflicts=True)
            cond_added = len(new_rows)

        msg = (f'Allergies: +{alle_added} added, {alle_skipped} skipped. '
               f'Chronic conditions: +{cond_added} added, {cond_skipped} skipped.')
        self.stdout.write(self.style.SUCCESS(msg))
