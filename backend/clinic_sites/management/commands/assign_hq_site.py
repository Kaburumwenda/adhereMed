"""Create the HQ Clinic site and attribute every existing record to it.

Run once after deploying multi-clinic support:

    python manage.py assign_hq_site                     # every clinic tenant
    python manage.py assign_hq_site --schema citycare_clinic
    python manage.py assign_hq_site --schema citycare_clinic --dry-run

The command is idempotent: it creates the HQ only when one is missing and only
touches rows whose ``clinic_site`` is still NULL.
"""
from django.core.management.base import BaseCommand
from django.db import transaction
from django_tenants.utils import get_tenant_model, schema_context, tenant_context

from clinic_sites.utils import ensure_hq_site

# (app label, model name, related field name)
SCOPED_MODELS = [
    ('patients', 'Patient', 'patients'),
    ('appointments', 'Appointment', 'appointments'),
    ('consultations', 'Consultation', 'consultations'),
    ('triage', 'Triage', 'triages'),
    ('billing', 'Invoice', 'invoices'),
    ('lab', 'LabOrder', 'lab_orders'),
    ('prescriptions', 'Prescription', 'prescriptions'),
    ('wards', 'Admission', 'admissions'),
]


class Command(BaseCommand):
    help = 'Bootstrap the HQ Clinic and attribute existing clinic records to it.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--schema', dest='schema', default=None,
            help='Only process this tenant schema (default: every clinic tenant).',
        )
        parser.add_argument(
            '--all-types', action='store_true',
            help='Process every tenant type, not only clinic tenants.',
        )
        parser.add_argument(
            '--dry-run', action='store_true',
            help='Report what would change without writing anything.',
        )

    def handle(self, *args, **options):
        schema = options['schema']
        dry_run = options['dry_run']
        Tenant = get_tenant_model()

        if schema:
            tenant = Tenant.objects.filter(schema_name=schema).first()
            targets = [tenant] if tenant else []
            if not targets:
                self.stderr.write(self.style.ERROR(f'No tenant with schema "{schema}".'))
                return
        else:
            qs = Tenant.objects.exclude(schema_name='public')
            if not options['all_types']:
                qs = qs.filter(type='clinic')
            targets = list(qs.order_by('schema_name'))

        if not targets:
            self.stdout.write('No matching tenants.')
            return

        for tenant in targets:
            self.stdout.write(f'\n── {tenant.schema_name} ({tenant.name})')
            if dry_run:
                with schema_context(tenant.schema_name):
                    self._process(dry_run=True)
            else:
                with tenant_context(tenant):
                    self._process(dry_run=False)

    # ── internals ───────────────────────────────────────────────────
    def _process(self, dry_run: bool):
        if dry_run:
            from clinic_sites.models import ClinicSite
            existing = ClinicSite.objects.filter(is_hq=True).first()
            self.stdout.write(
                '   HQ: ' + (existing.name if existing else 'would be created from profile'))
        else:
            with transaction.atomic():
                site = ensure_hq_site()
            self.stdout.write(self.style.SUCCESS(f'   HQ: {site.name} (code {site.code})'))

        total = 0
        for app_label, model_name, field in SCOPED_MODELS:
            try:
                model = self._model(app_label, model_name)
            except Exception as exc:  # noqa: BLE001 - app may not be installed
                self.stdout.write(f'   · {model_name}: skipped ({exc})')
                continue

            pending = model.objects.filter(clinic_site__isnull=True)
            count = pending.count()
            total += count
            if dry_run or not count:
                self.stdout.write(f'   · {model_name}: {count} unattributed')
                continue
            from clinic_sites.models import ClinicSite
            hq = ClinicSite.objects.filter(is_hq=True).first()
            if hq is None:
                self.stdout.write(f'   · {model_name}: no HQ — skipped')
                continue
            updated = pending.update(clinic_site=hq)
            self.stdout.write(f'   · {model_name}: {updated} → {hq.name}')

        if total == 0:
            self.stdout.write('   Nothing to attribute — already up to date.')

    @staticmethod
    def _model(app_label: str, model_name: str):
        from django.apps import apps
        return apps.get_model(app_label, model_name)
