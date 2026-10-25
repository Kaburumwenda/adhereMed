"""Seed a realistic clinic equipment estate.

Usage:
    python manage.py tenant_command seed_equipment --schema=citycare_clinic
    python manage.py tenant_command seed_equipment --schema=citycare_clinic --reset

Idempotent: assets are matched on ``asset_tag`` so re-running only tops up what
is missing.
"""

import random
from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from clinic_equipment.models import (
    Equipment,
    EquipmentCategory,
    EquipmentFault,
    EquipmentMaintenance,
    EquipmentTransfer,
)

TODAY = timezone.localdate()


CATEGORIES = [
    # name, code, icon, maint interval, calibration?, cal interval
    ('Diagnostic imaging', 'IMG', 'mdi-radiology-box-outline', 120, True, 365),
    ('Patient monitoring', 'MON', 'mdi-heart-pulse', 180, True, 365),
    ('Laboratory', 'LAB', 'mdi-flask-outline', 90, True, 180),
    ('Surgical & theatre', 'SUR', 'mdi-medical-bag', 180, False, 365),
    ('Life support', 'LSP', 'mdi-ambulance', 60, False, 365),
    ('Examination room', 'EXM', 'mdi-stethoscope', 365, False, 365),
    ('Dental', 'DEN', 'mdi-tooth-outline', 180, True, 365),
    ('Sterilisation', 'STR', 'mdi-autoclock', 90, True, 180),
    ('Physiotherapy', 'PHY', 'mdi-human-handsup', 180, False, 365),
    ('IT & telemedicine', 'ITC', 'mdi-laptop', 365, False, 365),
    ('Maternity & neonatal', 'MAT', 'mdi-baby-carriage', 120, True, 365),
    ('Mortuary & cold chain', 'MCC', 'mdi-snowflake', 90, True, 180),
]

# name, category code, manufacturer, model, price, criticality, condition, status
ASSETS = [
    ('Digital X-Ray System', 'IMG', 'Siemens', 'Multix Impact', 4_850_000, 'critical', 'good', 'operational'),
    ('Ultrasound Scanner', 'IMG', 'Mindray', 'DC-40', 1_250_000, 'critical', 'excellent', 'operational'),
    ('Portable Ultrasound', 'IMG', 'GE Healthcare', 'Vscan Air', 780_000, 'essential', 'good', 'operational'),
    ('CT Scanner 16-Slice', 'IMG', 'Canon', 'Aquilion Lightning', 14_500_000, 'critical', 'fair', 'under_maintenance'),

    ('Patient Monitor 5-Parameter', 'MON', 'Mindray', 'uMEC 12', 185_000, 'critical', 'good', 'operational'),
    ('Patient Monitor 5-Parameter', 'MON', 'Mindray', 'uMEC 12', 185_000, 'critical', 'excellent', 'operational'),
    ('ECG Machine 12-Lead', 'MON', 'Edan', 'SE-1200 Express', 240_000, 'essential', 'good', 'operational'),
    ('Pulse Oximeter', 'MON', 'Contec', 'CMS50D', 12_500, 'essential', 'good', 'operational'),
    ('Infusion Pump', 'MON', 'B. Braun', 'Infusomat Space', 165_000, 'critical', 'fair', 'operational'),
    ('Syringe Pump', 'MON', 'B. Braun', 'Perfusor Space', 158_000, 'critical', 'good', 'operational'),

    ('Haematology Analyzer', 'LAB', 'Sysmex', 'XN-550', 2_950_000, 'critical', 'good', 'operational'),
    ('Biochemistry Analyzer', 'LAB', 'Mindray', 'BS-240', 1_680_000, 'critical', 'fair', 'under_maintenance'),
    ('Microscope (Binocular)', 'LAB', 'Olympus', 'CX23', 145_000, 'essential', 'good', 'operational'),
    ('Centrifuge', 'LAB', 'Hettich', 'EBA 200', 78_000, 'essential', 'good', 'operational'),
    ('Blood Bank Refrigerator', 'LAB', 'Vestfrost', 'MBR-300', 420_000, 'critical', 'good', 'operational'),

    ('Anaesthesia Machine', 'SUR', 'Mindray', 'WATO EX-35', 1_950_000, 'life_support', 'good', 'operational'),
    ('Surgical Diathermy', 'SUR', 'Erbe', 'VIO 100C', 640_000, 'critical', 'good', 'operational'),
    ('Operating Light (LED)', 'SUR', 'Maquet', 'PowerLED', 520_000, 'critical', 'excellent', 'operational'),
    ('Operating Table', 'SUR', 'Maquet', 'Alphastar', 1_100_000, 'critical', 'good', 'operational'),
    ('Electrosurgical Generator', 'SUR', 'ValleyLab', 'ForceTriad', 720_000, 'critical', 'poor', 'out_of_service'),

    ('Ventilator ICU', 'LSP', 'Dräger', 'Savina 300', 2_400_000, 'life_support', 'good', 'operational'),
    ('Ventilator ICU', 'LSP', 'Dräger', 'Savina 300', 2_400_000, 'life_support', 'fair', 'operational'),
    ('Defibrillator', 'LSP', 'Zoll', 'R Series', 890_000, 'life_support', 'excellent', 'operational'),
    ('Defibrillator', 'LSP', 'Zoll', 'R Series', 890_000, 'life_support', 'good', 'operational'),
    ('Oxygen Concentrator', 'LSP', 'DeVilbiss', '1025KS', 195_000, 'critical', 'good', 'operational'),

    ('Examination Couch', 'EXM', 'Generic', 'EC-200', 32_000, 'optional', 'good', 'operational'),
    ('Examination Couch', 'EXM', 'Generic', 'EC-200', 32_000, 'optional', 'fair', 'operational'),
    ('Digital Thermometer', 'EXM', 'Braun', 'ThermoScan 7', 8_500, 'essential', 'excellent', 'operational'),
    ('Weighing Scale (Adult)', 'EXM', 'Seca', '813', 26_000, 'essential', 'good', 'operational'),
    ('Weighing Scale (Infant)', 'EXM', 'Seca', '334', 21_000, 'essential', 'good', 'operational'),
    ('Blood Pressure Monitor', 'EXM', 'Omron', 'HBP-1320', 24_500, 'essential', 'excellent', 'operational'),
    ('Otoscope / Ophthalmoscope Set', 'EXM', 'Heine', 'K180', 46_000, 'essential', 'good', 'in_storage'),

    ('Dental Chair Unit', 'DEN', 'Belmont', 'Eurus S1', 720_000, 'critical', 'good', 'operational'),
    ('Dental X-Ray (Intraoral)', 'DEN', 'Dexis', 'Titan', 480_000, 'essential', 'good', 'operational'),
    ('Autoclave (Dental)', 'DEN', 'Melag', 'Vacuklav 23', 330_000, 'essential', 'good', 'operational'),

    ('Autoclave (CSSD)', 'STR', 'Getinge', 'HS66', 1_450_000, 'critical', 'good', 'operational'),
    ('Instrument Washer', 'STR', 'Getinge', 'WD15', 980_000, 'essential', 'fair', 'operational'),
    ('Ultrasonic Cleaner', 'STR', 'Elmasonic', 'E60H', 68_000, 'optional', 'good', 'operational'),

    ('Physiotherapy TENS Unit', 'PHY', 'Chattanooga', 'Intelect', 92_000, 'optional', 'good', 'operational'),
    ('Treatment Plinth', 'PHY', 'Generic', 'TP-300', 44_000, 'optional', 'good', 'operational'),
    ('Shortwave Diathermy', 'PHY', 'Chattanooga', 'Megapulse', 185_000, 'optional', 'fair', 'in_storage'),

    ('Telemedicine Cart', 'ITC', 'Advantech', 'POC-6', 210_000, 'optional', 'good', 'operational'),
    ('Clinic Workstations (x8)', 'ITC', 'Dell', 'OptiPlex 7010', 640_000, 'optional', 'good', 'operational'),
    ('Network UPS 10kVA', 'ITC', 'APC', 'Smart-UPS SRT', 380_000, 'critical', 'good', 'operational'),
]

FAULTS = [
    ('Intermittent image artefact', 'critical', 'open', 'Streaking appears on lateral views after 30 minutes of use.'),
    ('Pump occlusion alarm recurring', 'high', 'investigating', 'Alarm triggers mid-infusion even with a clear line.'),
    ('Monitor screen flicker', 'medium', 'open', 'Display flickers when the backlight warms up.'),
    ('Analyzer probe clogging', 'high', 'investigating', 'Sample probe clogs every ~40 runs, requiring manual clearing.'),
    ('Diathermy power fluctuation', 'critical', 'open', 'Output drops during coagulation mode — withdrawn from theatre.'),
    ('Caster wheel broken', 'low', 'open', 'Front-right castor seized; unit is difficult to move.'),
    ('Calibration drift', 'medium', 'resolved', 'Readings drifted 4% low; recalibrated and verified.'),
    ('Door seal leak', 'medium', 'resolved', 'Autoclave door seal perished; replaced and validated.'),
]

TRANSFERS = [
    ('Moved to main theatre for the afternoon list', 'Scheduled expansion of surgical capacity'),
    ('Returned to storage after outreach clinic', 'Outreach programme concluded'),
    ('Relocated to satellite branch', 'New branch opening'),
]


class Command(BaseCommand):
    help = 'Seed clinic equipment, maintenance history, faults and transfers.'

    def add_arguments(self, parser):
        parser.add_argument('--reset', action='store_true', help='Delete existing equipment data first.')
        parser.add_argument('--assets', type=int, default=len(ASSETS), help='How many assets to create.')
        parser.add_argument(
            '--categories-only', action='store_true',
            help='Seed only the equipment category reference data (safe for production).',
        )
        parser.add_argument(
            '--demo', action='store_true',
            help='Explicitly acknowledge that demo assets, faults and transfers will be created.',
        )

    def handle(self, *args, **options):
        random.seed(42)

        categories_only = options['categories_only']

        if options['reset'] and not categories_only:
            EquipmentTransfer.objects.all().delete()
            EquipmentFault.objects.all().delete()
            EquipmentMaintenance.objects.all().delete()
            Equipment.objects.all().delete()
            self.stdout.write(self.style.WARNING('Existing equipment data cleared.'))

        # ── Categories (idempotent, production-safe) ──
        cat_map = {}
        cats_created = 0
        for name, code, icon, interval, needs_cal, cal_interval in CATEGORIES:
            cat, was_created = EquipmentCategory.objects.get_or_create(
                code=code,
                defaults={
                    'name': name,
                    'icon': icon,
                    'maintenance_interval_days': interval,
                    'requires_calibration': needs_cal,
                    'calibration_interval_days': cal_interval,
                },
            )
            if was_created:
                cats_created += 1
            cat_map[code] = cat

        if categories_only:
            self.stdout.write(self.style.SUCCESS(
                f'Equipment categories seeded — {cats_created} new '
                f'({EquipmentCategory.objects.count()} total).'
            ))
            return

    def handle(self, *args, **options):
        random.seed(42)

        categories_only = options['categories_only']
        demo = options['demo']

        # Guard FIRST — a refused run must be a true no-op, not a partial write.
        if not categories_only and not demo:
            self.stdout.write(self.style.WARNING(
                'Refusing to create demo assets without --demo. '
                'Use --categories-only for production reference data, '
                'or --demo to acknowledge demo records will be created.'
            ))
            return

        if options['reset'] and not categories_only:
            EquipmentTransfer.objects.all().delete()
            EquipmentFault.objects.all().delete()
            EquipmentMaintenance.objects.all().delete()
            Equipment.objects.all().delete()
            self.stdout.write(self.style.WARNING('Existing equipment data cleared.'))

        # ── Categories (idempotent, production-safe) ──
        cat_map = {}
        cats_created = 0
        for name, code, icon, interval, needs_cal, cal_interval in CATEGORIES:
            cat, was_created = EquipmentCategory.objects.get_or_create(
                code=code,
                defaults={
                    'name': name,
                    'icon': icon,
                    'maintenance_interval_days': interval,
                    'requires_calibration': needs_cal,
                    'calibration_interval_days': cal_interval,
                },
            )
            if was_created:
                cats_created += 1
            cat_map[code] = cat

        if categories_only:
            self.stdout.write(self.style.SUCCESS(
                f'Equipment categories seeded — {cats_created} new '
                f'({EquipmentCategory.objects.count()} total).'
            ))
            return

        # ── Site + department context ──
        site = None
        try:
            from clinic_sites.models import ClinicSite
            site = ClinicSite.objects.filter(is_active=True).order_by('-is_hq').first()
        except Exception:
            site = None

        dept = None
        try:
            from departments.models import Department
            dept = Department.objects.filter(is_active=True).order_by('name').first()
        except Exception:
            dept = None

        locations = [
            'Radiology Room 1', 'Radiology Room 2', 'Main Theatre', 'Theatre 2',
            'ICU Bay A', 'ICU Bay B', 'OPD Room 3', 'OPD Room 5', 'Laboratory',
            'CSSD', 'Dental Suite', 'Physiotherapy Gym', 'Server Room', 'Store Room',
        ]

        created = 0
        assets = []
        for idx, (name, code, mfr, model, price, criticality, condition, status) in enumerate(ASSETS[:options['assets']]):
            category = cat_map.get(code)
            purchase = TODAY - timedelta(days=random.randint(180, 2200))
            life = random.choice([5, 7, 8, 10])
            commissioned = purchase + timedelta(days=random.randint(5, 45))

            maint_interval = random.choice([90, 120, 180, 365])
            last_maint = TODAY - timedelta(days=random.randint(10, maint_interval + 60))
            next_maint = last_maint + timedelta(days=maint_interval)

            needs_cal = bool(category and category.requires_calibration)
            last_cal = TODAY - timedelta(days=random.randint(10, 420)) if needs_cal else None
            next_cal = (last_cal + timedelta(days=365)) if needs_cal else None

            warranty = purchase + timedelta(days=random.choice([365, 730, 1095]))

            obj, was_created = Equipment.objects.get_or_create(
                asset_tag=f'EQ-{code}-{idx + 1:04d}',
                defaults={
                    'name': name,
                    'category': category,
                    'manufacturer': mfr,
                    'model_number': model,
                    'serial_number': f'{code}{random.randint(100000, 999999)}',
                    'site': site,
                    'department': dept,
                    'location': random.choice(locations),
                    'status': status,
                    'condition': condition,
                    'criticality': criticality,
                    'ownership': 'owned',
                    'purchase_date': purchase,
                    'purchase_price': Decimal(str(price)),
                    'supplier_name': random.choice([
                        'Surgipharm Ltd', 'Meditec Kenya', 'Diagnostics Africa',
                        'Hospital Equipment Co.', 'BioMed Supplies',
                    ]),
                    'warranty_expiry': warranty,
                    'commissioned_on': commissioned,
                    'expected_life_years': life,
                    'maintenance_interval_days': maint_interval,
                    'last_maintenance': last_maint,
                    'next_maintenance': next_maint,
                    'calibration_required': needs_cal,
                    'calibration_interval_days': 365,
                    'last_calibration': last_cal,
                    'next_calibration': next_cal,
                    'description': f'{mfr} {model} deployed at {random.choice(locations)}.',
                },
            )
            assets.append(obj)
            if was_created:
                created += 1

        # ── Maintenance history + schedule ──
        jobs_created = 0
        for equipment in assets:
            # Two completed jobs in the past year
            for k in range(random.randint(1, 2)):
                done = TODAY - timedelta(days=random.randint(20, 330))
                if EquipmentMaintenance.objects.filter(
                    equipment=equipment, completed_date=done,
                ).exists():
                    continue
                EquipmentMaintenance.objects.create(
                    equipment=equipment,
                    kind=random.choice(['preventive', 'calibration', 'inspection']),
                    status='completed',
                    scheduled_date=done - timedelta(days=7),
                    completed_date=done,
                    performed_by=random.choice(['internal', 'vendor']),
                    vendor_name=random.choice(['Meditec Kenya', 'BioMed Supplies', '']),
                    technician=random.choice(['J. Otieno', 'M. Wanjiru', 'S. Kipchoge']),
                    cost=Decimal(str(random.randint(4, 90) * 1000)),
                    downtime_hours=Decimal(str(round(random.uniform(0.5, 12), 1))),
                    description='Routine service and safety checks.',
                    findings=random.choice([
                        'All parameters within tolerance.',
                        'Replaced worn seals; device verified.',
                        'Firmware updated, no faults found.',
                    ]),
                    next_due_date=done + timedelta(days=equipment.effective_maintenance_interval),
                )
                jobs_created += 1

            # One upcoming / overdue job for a subset
            if random.random() < 0.45:
                offset = random.choice([-25, -6, 4, 11, 21, 45])
                sched = TODAY + timedelta(days=offset)
                EquipmentMaintenance.objects.create(
                    equipment=equipment,
                    kind=random.choice(['preventive', 'calibration']),
                    status='scheduled',
                    scheduled_date=sched,
                    performed_by=random.choice(['internal', 'vendor']),
                    vendor_name='Meditec Kenya',
                    description='Scheduled preventive maintenance.',
                )
                jobs_created += 1

        # ── Faults ──
        faults_created = 0
        critical_assets = [a for a in assets if a.criticality in ('life_support', 'critical')]
        for idx, (title, severity, st, desc) in enumerate(FAULTS):
            if not critical_assets:
                break
            equipment = critical_assets[idx % len(critical_assets)]
            if EquipmentFault.objects.filter(equipment=equipment, title=title).exists():
                continue
            reported = timezone.now() - timedelta(days=random.randint(1, 26))
            fault = EquipmentFault(
                equipment=equipment,
                title=title,
                description=desc,
                severity=severity,
                status=st,
                reported_at=reported,
                downtime_hours=Decimal(str(round(random.uniform(0, 40), 1))),
            )
            if st == 'resolved':
                fault.resolved_at = reported + timedelta(days=random.randint(1, 5))
                fault.resolution = 'Repaired and returned to service after verification.'
            fault.save()
            faults_created += 1

        # ── Transfers ──
        transfers_created = 0
        if site:
            others = []
            try:
                from clinic_sites.models import ClinicSite
                others = list(ClinicSite.objects.filter(is_active=True).exclude(pk=site.pk)[:2])
            except Exception:
                others = []
            for idx, asset in enumerate(assets[:6]):
                reason, notes = TRANSFERS[idx % len(TRANSFERS)]
                if EquipmentTransfer.objects.filter(equipment=asset, reason=reason).exists():
                    continue
                target = others[idx % len(others)] if others else site
                EquipmentTransfer.objects.create(
                    equipment=asset,
                    from_site=site,
                    to_site=target,
                    reason=reason,
                    notes=notes,
                    transferred_at=timezone.now() - timedelta(days=random.randint(3, 120)),
                )
                transfers_created += 1

        self.stdout.write(self.style.SUCCESS(
            f'Equipment seeded — {cats_created} new categor'
            f'{"y" if cats_created == 1 else "ies"}, '
            f'{created} new asset(s) ({Equipment.objects.count()} total), '
            f'{jobs_created} maintenance job(s), '
            f'{faults_created} fault(s), '
            f'{transfers_created} transfer(s).'
        ))
