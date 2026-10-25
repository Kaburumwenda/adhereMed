"""Seed demo corporate clients, staff rosters and verification documents.

Runs inside a tenant schema. Idempotent: existing corporate codes are reused
and their roster is topped up rather than duplicated.

    python manage.py seed_corporate
    python manage.py seed_corporate --reset
"""
from datetime import date, timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from corporate.models import CorporateClient, CorporateDocument, CorporateStaff
from patients.models import Patient

DEMO_CORPORATES = [
    {
        'code': 'ACM-001',
        'name': 'Acme Manufacturing Ltd',
        'registration_number': 'CPR/2014/001234',
        'industry': 'Manufacturing',
        'contact_person': 'Grace Wanjiku',
        'contact_phone': '+254 722 100 200',
        'contact_email': 'hr@acmemfg.co.ke',
        'address': 'Industrial Area, Enterprise Road, Nairobi',
        'discount_rate': Decimal('10.00'),
        'payment_terms_days': 30,
        'credit_limit': Decimal('500000.00'),
        'annual_limit_per_staff': Decimal('150000.00'),
        'status': CorporateClient.Status.ACTIVE,
        'contract_start': date(2026, 1, 1),
        'contract_end': date(2026, 12, 31),
        'staff': [
            ('ACM-1001', 'Peter Mwangi', 'Machine Operator', 'Production', 'employee', 'verified'),
            ('ACM-1002', 'Mary Achieng', 'Quality Controller', 'Quality', 'employee', 'verified'),
            ('ACM-1003', 'John Kamau', 'Shift Supervisor', 'Production', 'employee', 'verified'),
            ('ACM-1004', 'Faith Njeri', 'Accountant', 'Finance', 'employee', 'pending'),
            ('ACM-1005', 'Susan Mwangi', 'Spouse', '—', 'spouse', 'verified'),
            ('ACM-1006', 'Kevin Otieno', 'Forklift Driver', 'Logistics', 'employee', 'verified'),
        ],
    },
    {
        'code': 'KCB-002',
        'name': 'Kenya Commercial Bank',
        'registration_number': 'CPR/1998/009876',
        'industry': 'Banking',
        'contact_person': 'Daniel Kiptoo',
        'contact_phone': '+254 733 555 111',
        'contact_email': 'wellness@kcbgroup.com',
        'address': 'KCB Towers, Upper Hill, Nairobi',
        'discount_rate': Decimal('15.00'),
        'payment_terms_days': 45,
        'credit_limit': Decimal('1200000.00'),
        'annual_limit_per_staff': Decimal('250000.00'),
        'status': CorporateClient.Status.ACTIVE,
        'contract_start': date(2026, 3, 1),
        'contract_end': date(2027, 2, 28),
        'staff': [
            ('KCB-2101', 'Alice Wambui', 'Branch Manager', 'Retail', 'employee', 'verified'),
            ('KCB-2102', 'Brian Ochieng', 'Credit Analyst', 'Credit', 'employee', 'verified'),
            ('KCB-2103', 'Caroline Mutua', 'Teller', 'Operations', 'employee', 'verified'),
            ('KCB-2104', 'Dennis Barasa', 'IT Support', 'Technology', 'employee', 'pending'),
            ('KCB-2105', 'Esther Wanjala', 'Child', '—', 'child', 'verified'),
        ],
    },
    {
        'code': 'TCH-003',
        'name': 'TechHub Africa',
        'registration_number': 'CPR/2019/445566',
        'industry': 'Technology',
        'contact_person': 'Linet Achieng',
        'contact_phone': '+254 711 909 090',
        'contact_email': 'people@techhub.africa',
        'address': 'Nairobi Garage, Westlands, Nairobi',
        'discount_rate': Decimal('8.00'),
        'payment_terms_days': 20,
        'credit_limit': Decimal('300000.00'),
        'annual_limit_per_staff': Decimal('100000.00'),
        'status': CorporateClient.Status.ACTIVE,
        'contract_start': date(2025, 10, 1),
        'contract_end': date(2026, 9, 30),  # expiring soon on purpose
        'staff': [
            ('TCH-3101', 'Allan Kibe', 'Software Engineer', 'Engineering', 'employee', 'verified'),
            ('TCH-3102', 'Mercy Wairimu', 'Product Designer', 'Design', 'employee', 'verified'),
            ('TCH-3103', 'Samson Kiptanui', 'DevOps Engineer', 'Engineering', 'employee', 'verified'),
            ('TCH-3104', 'Joy Muthoni', 'People Partner', 'People', 'employee', 'verified'),
        ],
    },
    {
        'code': 'AGR-004',
        'name': 'AgriFresh Processors',
        'registration_number': 'CPR/2021/778899',
        'industry': 'Agriculture',
        'contact_person': 'Moses Kimani',
        'contact_phone': '+254 700 333 444',
        'contact_email': 'admin@agrifresh.co.ke',
        'address': 'Thika Road, Ruiru',
        'discount_rate': Decimal('5.00'),
        'payment_terms_days': 30,
        'credit_limit': Decimal('0.00'),
        'annual_limit_per_staff': Decimal('80000.00'),
        'status': CorporateClient.Status.PENDING,
        'contract_start': date(2026, 11, 1),
        'contract_end': date(2027, 10, 31),
        'staff': [
            ('AGR-4101', 'Nancy Chebet', 'Packhouse Lead', 'Production', 'employee', 'pending'),
            ('AGR-4102', 'Elijah Mwenda', 'Agronomist', 'Field', 'employee', 'pending'),
            ('AGR-4103', 'Rose Atieno', 'Store Keeper', 'Stores', 'employee', 'pending'),
        ],
    },
]

DOC_PLAN = [
    ('contract', 'Master service agreement', 'verified'),
    ('job_card', 'Sample job card — Peter Mwangi', 'verified'),
    ('job_card', 'Sample job card — Faith Njeri', 'pending'),
    ('authorisation_letter', 'Treatment authorisation letter', 'verified'),
]


class Command(BaseCommand):
    help = 'Seed demo corporate clients, staff rosters and verification documents.'

    def add_arguments(self, parser):
        parser.add_argument('--reset', action='store_true',
                            help='Delete the demo corporates (by code) before seeding.')

    def handle(self, *args, **options):
        if options['reset']:
            codes = [c['code'] for c in DEMO_CORPORATES]
            deleted, _ = CorporateClient.objects.filter(code__in=codes).delete()
            self.stdout.write(self.style.WARNING(f'Reset: removed {deleted} demo rows.'))

        today = timezone.localdate()
        patients = list(Patient.objects.select_related('user').all()[:40])
        patient_cursor = 0

        created_corp = 0
        created_staff = 0
        created_docs = 0

        for raw_spec in DEMO_CORPORATES:
            spec = dict(raw_spec)
            staff_rows = spec.pop('staff')

            corporate, made = CorporateClient.objects.update_or_create(
                code=spec['code'],
                defaults={
                    **spec,
                    'is_active': spec['status'] != CorporateClient.Status.EXPIRED,
                    'verified_at': timezone.now()
                    if spec['status'] == CorporateClient.Status.ACTIVE else None,
                    'notes': 'Demo corporate seeded for the clinic dashboard.',
                },
            )
            if made:
                created_corp += 1

            for idx, (staff_no, name, title, dept, rel, verification) in enumerate(staff_rows):
                patient = None
                if verification == 'verified' and patients:
                    patient = patients[patient_cursor % len(patients)]
                    patient_cursor += 1

                valid_to = spec['contract_end']
                if spec['code'] == 'TCH-003' and idx == 0:
                    valid_to = today + timedelta(days=21)  # expiring cover

                obj, staff_made = CorporateStaff.objects.update_or_create(
                    corporate=corporate,
                    staff_number=staff_no,
                    defaults={
                        'full_name': name,
                        'job_title': '' if title == '—' else title,
                        'department': '' if dept == '—' else dept,
                        'relationship': rel,
                        'patient': patient,
                        'phone': f'+2547{idx:02d}{abs(hash(staff_no)) % 1000000:06d}'[:16],
                        'email': f'{staff_no.lower()}@example.co.ke',
                        'national_id': f'{20000000 + abs(hash(staff_no)) % 9999999}',
                        'date_of_birth': date(1985 + idx % 12, (idx % 12) + 1, (idx % 27) + 1),
                        'gender': 'female' if idx % 2 else 'male',
                        'annual_limit': corporate.annual_limit_per_staff,
                        'valid_from': spec['contract_start'],
                        'valid_to': valid_to,
                        'status': CorporateStaff.Status.ACTIVE,
                        'verification_status': verification,
                        'verified_at': timezone.now() if verification == 'verified' else None,
                    },
                )
                if staff_made:
                    created_staff += 1

            # Verification documents (no actual file — reference only, which is
            # enough for the dashboard to exercise the verify/reject flow).
            for doc_type, title, doc_status in DOC_PLAN:
                doc, doc_made = CorporateDocument.objects.get_or_create(
                    corporate=corporate,
                    doc_type=doc_type,
                    title=title,
                    defaults={
                        'reference': f'{corporate.code}-{doc_type.upper()[:6]}',
                        'status': doc_status,
                        'issued_at': spec['contract_start'],
                        'expires_at': spec['contract_end'],
                        'verified_at': timezone.now() if doc_status == 'verified' else None,
                        'notes': 'Demo verification document.',
                    },
                )
                if doc_made:
                    created_docs += 1

        self.stdout.write(self.style.SUCCESS(
            f'Corporate seed complete — {created_corp} companies, '
            f'{created_staff} staff, {created_docs} documents created '
            f'({CorporateClient.objects.count()} companies total).'
        ))
