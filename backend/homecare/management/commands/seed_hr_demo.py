"""Seed demo HR data for the homecare tenant.

Usage:
    python manage.py tenant_command seed_hr_demo --schema=homecare_demo
"""
import random
from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from homecare.models import (
    HREmployee, LeaveRequest, LeaveBalance, Shift, Attendance, Timesheet,
    BenefitPlan, BenefitEnrollment, PayrollEntry, JobOpening, Applicant,
    OnboardingTemplate, OnboardingRecord, OnboardingTask,
    TrainingProgram, TrainingEnrollment,
    PerformanceReview, Goal,
    ComplianceViolation, Certification, ComplianceReport,
    HRDocument,
)

NAMES = [
    ('Wanjiru', 'Kamau', 'Nursing', 'Registered Nurse', 'full_time', 85000),
    ('Grace', 'Mutiso', 'Caregiving', 'Senior Caregiver', 'full_time', 55000),
    ('Peter', 'Otieno', 'Caregiving', 'Caregiver', 'full_time', 48000),
    ('Mary', 'Wambui', 'Nursing', 'Enrolled Nurse', 'full_time', 62000),
    ('James', 'Mwangi', 'Administration', 'Operations Manager', 'full_time', 120000),
    ('Faith', 'Njeri', 'Administration', 'HR Officer', 'full_time', 75000),
    ('David', 'Kiprop', 'Pharmacy', 'Pharmacist', 'full_time', 95000),
    ('Sarah', 'Chebet', 'Laboratory', 'Lab Technologist', 'full_time', 70000),
    ('Daniel', 'Ochieng', 'Operations', 'Logistics Officer', 'part_time', 45000),
    ('Ruth', 'Achieng', 'Caregiving', 'Caregiver', 'part_time', 38000),
    ('Samuel', 'Kariuki', 'Finance', 'Accountant', 'full_time', 88000),
    ('Esther', 'Wekesa', 'IT', 'IT Support', 'contract', 60000),
    ('Brian', 'Omondi', 'Caregiving', 'Junior Caregiver', 'internship', 25000),
    ('Janet', 'Korir', 'Nursing', 'Midwife', 'full_time', 72000),
    ('Eric', 'Maina', 'Operations', 'Driver', 'full_time', 42000),
]

DEPARTMENTS = ['Nursing', 'Caregiving', 'Administration', 'Pharmacy',
               'Laboratory', 'Finance', 'IT', 'Operations']


class Command(BaseCommand):
    help = 'Seed demo HR data inside the current tenant schema.'

    def handle(self, *args, **options):
        today = timezone.localdate()
        run_id = random.randint(1000, 9999)
        self.stdout.write(self.style.MIGRATE_HEADING('Seeding HR demo data...'))

        # ── Employees ──
        employees = []
        for i, (fn, ln, dept, title, etype, salary) in enumerate(NAMES):
            status = 'active'
            if i == 13:
                status = 'on_probation'
            elif i == 14:
                status = 'on_leave'
            emp, created = HREmployee.objects.get_or_create(
                email=f'{fn.lower()}.{ln.lower()}@demohomecare.local',
                defaults={
                    'first_name': fn,
                    'last_name': ln,
                    'phone': f'+2547{random.randint(10, 29)}{random.randint(100000, 999999)}',
                    'national_id': f'{random.randint(1000000, 9999999)}',
                    'gender': random.choice(['Male', 'Female']),
                    'department': dept,
                    'job_title': title,
                    'employment_type': etype,
                    'status': status,
                    'hire_date': today - timedelta(days=random.randint(30, 900)),
                    'salary': Decimal(salary),
                    'bank_account': f'KCB-{random.randint(10000000, 99999999)}',
                    'emergency_contact': f'{random.choice(["Spouse","Parent","Sibling"])}: +2547{random.randint(10,29)}{random.randint(100000,999999)}',
                },
            )
            LeaveBalance.objects.get_or_create(
                employee=emp,
                defaults={
                    'annual_total': 21,
                    'annual_used': random.randint(0, 8),
                    'sick_total': 10,
                    'sick_used': random.randint(0, 3),
                },
            )
            employees.append(emp)
        self.stdout.write(f'  Employees: {len(employees)}')

        # ── Supervisors ──
        for emp in employees:
            if emp.department == 'Administration' and 'Manager' in emp.job_title:
                continue
            mgr = next((e for e in employees if e.department == emp.department and 'Manager' in e.job_title), None)
            if mgr and mgr.id != emp.id:
                emp.supervisor = mgr
                emp.save(update_fields=['supervisor'])

        # ── Leave requests ──
        leave_types = ['annual', 'sick', 'maternity', 'paternity', 'compassionate', 'unpaid']
        for emp in random.sample(employees, min(8, len(employees))):
            start = today + timedelta(days=random.randint(-20, 30))
            end = start + timedelta(days=random.randint(1, 5))
            LeaveRequest.objects.get_or_create(
                employee=emp, start_date=start, end_date=end,
                defaults={
                    'leave_type': random.choice(leave_types),
                    'reason': random.choice(['Family event', 'Medical appointment', 'Personal matter', 'Rest']),
                    'status': random.choice(['pending', 'approved', 'approved', 'rejected']),
                    'approver': employees[4] if employees[4] != emp else employees[5],
                    'approved_at': timezone.now() - timedelta(days=random.randint(1, 10)),
                },
            )
        self.stdout.write(f'  Leave requests: {LeaveRequest.objects.count()}')

        # ── Shifts (this week) ──
        week_start = today - timedelta(days=today.weekday())
        shift_types = ['day', 'night', 'evening', 'on_call']
        shift_times = {
            'day': ('07:00', '15:00'),
            'night': ('19:00', '07:00'),
            'evening': ('15:00', '23:00'),
            'on_call': ('00:00', '23:59'),
        }
        for emp in employees[:10]:
            for d in range(5):
                st = random.choice(shift_types)
                s, e = shift_times[st]
                Shift.objects.get_or_create(
                    employee=emp, date=week_start + timedelta(days=d),
                    defaults={'shift_type': st, 'start_time': s, 'end_time': e},
                )
        self.stdout.write(f'  Shifts: {Shift.objects.count()}')

        # ── Attendance today ──
        for emp in employees[:12]:
            if emp.status == 'on_leave':
                Attendance.objects.update_or_create(
                    employee=emp, date=today,
                    defaults={'status': 'on_leave'},
                )
            else:
                clock_in = timezone.datetime.strptime(f'{random.randint(7,9)}:{random.choice(["00","15","30","45"])}', '%H:%M').time()
                Attendance.objects.update_or_create(
                    employee=emp, date=today,
                    defaults={'clock_in': clock_in, 'status': 'present', 'late': clock_in.hour > 9},
                )
        self.stdout.write(f'  Attendance: {Attendance.objects.count()}')

        # ── Timesheets ──
        for emp in employees[:10]:
            for d in range(7):
                Timesheet.objects.get_or_create(
                    employee=emp, date=today - timedelta(days=d),
                    defaults={
                        'hours': Decimal(str(random.uniform(6, 10))),
                        'shift_type': random.choice(['day', 'night', 'evening']),
                        'status': random.choice(['pending', 'approved', 'approved']),
                    },
                )
        self.stdout.write(f'  Timesheets: {Timesheet.objects.count()}')

        # ── Benefit plans ──
        benefits = [
            ('Staff Medical Cover', 'health', 5000, 1000, True),
            ('Pension Scheme', 'pension', 3000, 3000, True),
            ('Life Insurance', 'life', 1500, 0, True),
            ('Transport Allowance', 'transport', 2000, 0, False),
            ('Meal Subsidy', 'meal', 1500, 500, False),
        ]
        for name, btype, emp_con, staff_con, mand in benefits:
            bp, _ = BenefitPlan.objects.get_or_create(
                name=name,
                defaults={
                    'type': btype,
                    'description': f'{name} for all eligible staff.',
                    'employer_contribution': Decimal(emp_con),
                    'employee_contribution': Decimal(staff_con),
                    'mandatory': mand,
                },
            )
            for emp in random.sample(employees, min(8, len(employees))):
                BenefitEnrollment.objects.get_or_create(benefit=bp, employee=emp)
        self.stdout.write(f'  Benefit plans: {BenefitPlan.objects.count()}')

        # ── Job openings ──
        jobs_data = [
            ('Registered Nurse', 'Nursing', 'full_time', 70000, 95000),
            ('Senior Caregiver', 'Caregiving', 'full_time', 45000, 65000),
            ('Clinical Officer', 'Nursing', 'full_time', 80000, 110000),
            ('Part-time Caregiver', 'Caregiving', 'part_time', 30000, 40000),
            ('HR Assistant', 'Administration', 'contract', 50000, 60000),
        ]
        jobs = []
        for title, dept, etype, smin, smax in jobs_data:
            job, _ = JobOpening.objects.get_or_create(
                title=title,
                defaults={
                    'department': dept,
                    'employment_type': etype,
                    'location': 'Nairobi',
                    'salary_min': Decimal(smin),
                    'salary_max': Decimal(smax),
                    'closing_date': today + timedelta(days=random.randint(7, 30)),
                    'description': f'We are hiring a {title} to join our {dept} team.',
                    'requirements': 'Relevant qualification\nMinimum 2 years experience\nRegistration with professional body',
                    'is_published': True,
                    'status': 'open',
                },
            )
            jobs.append(job)
        self.stdout.write(f'  Job openings: {len(jobs)}')

        # ── Applicants ──
        applicant_names = [
            ('Alice', 'Muthoni'), ('Brian', 'Kiptoo'), ('Caroline', 'Atieno'),
            ('Dennis', 'Njoroge'), ('Evelyn', 'Kones'), ('Felix', 'Barasa'),
            ('Gloria', 'Achieng'), ('Henry', 'Mutua'), ('Irene', 'Wanjiku'),
            ('Joseph', 'Langat'),
        ]
        stages = ['applied', 'screening', 'interview', 'offer', 'hired', 'declined']
        for fn, ln in applicant_names:
            job = random.choice(jobs)
            Applicant.objects.get_or_create(
                name=f'{fn} {ln}', job=job,
                defaults={
                    'email': f'{fn.lower()}.{ln.lower()}@gmail.com',
                    'phone': f'+2547{random.randint(10,29)}{random.randint(100000,999999)}',
                    'resume_url': f'https://example.com/resumes/{fn.lower()}_{ln.lower()}.pdf',
                    'cover_letter': f'I am excited to apply for the {job.title} position.',
                    'stage': random.choice(stages),
                    'rating': random.randint(0, 5),
                    'notes': random.choice(['', 'Strong candidate', 'Needs follow-up', 'Excellent experience']),
                },
            )
        self.stdout.write(f'  Applicants: {Applicant.objects.count()}')

        # ── Onboarding ──
        onboarding_tasks = [
            'Sign employment contract', 'Complete tax forms (PIN, NSSF, NHIF, SHIF)',
            'Issue ID badge & uniform', 'IT account setup (email, system access)',
            'Health & safety briefing', 'Patient privacy (HIPAA) training',
            'Shadow senior caregiver (3 shifts)', 'First aid certification check',
            'Emergency protocols walkthrough', 'Probation review scheduling',
        ]
        template, _ = OnboardingTemplate.objects.get_or_create(
            name='Standard Homecare Onboarding',
            defaults={'tasks': [{'title': t} for t in onboarding_tasks]},
        )
        for emp in employees[-3:]:
            rec, _ = OnboardingRecord.objects.get_or_create(
                employee=emp,
                defaults={
                    'role': emp.job_title,
                    'department': emp.department,
                    'start_date': today - timedelta(days=random.randint(5, 20)),
                    'mentor': employees[0].name,
                    'status': 'in_progress',
                },
            )
            if not rec.tasks.exists():
                for t in onboarding_tasks:
                    OnboardingTask.objects.create(
                        onboarding=rec, title=t,
                        done=random.random() > 0.6,
                        due_date=today + timedelta(days=random.randint(0, 14)),
                    )
        self.stdout.write(f'  Onboarding records: {OnboardingRecord.objects.count()}')

        # ── Training programs ──
        programs = [
            ('Basic Life Support (BLS)', 'First Aid', 8, True),
            ('Infection Prevention & Control', 'Infection Control', 4, True),
            ('Patient Handling & Mobility', 'Patient Care', 6, False),
            ('Medication Administration Safety', 'Clinical Skills', 5, True),
            ('Effective Communication in Care', 'Soft Skills', 3, False),
            ('Dementia & Elderly Care', 'Patient Care', 10, False),
            ('Fire Safety & Emergency Evacuation', 'Compliance & Safety', 2, True),
        ]
        for title, cat, hrs, mand in programs:
            prog, _ = TrainingProgram.objects.get_or_create(
                title=title,
                defaults={
                    'category': cat,
                    'description': f'{title} — comprehensive training program.',
                    'duration_hours': hrs,
                    'delivery_mode': random.choice(['online', 'hybrid', 'in_person']),
                    'mandatory': mand,
                },
            )
            for emp in random.sample(employees, min(6, len(employees))):
                TrainingEnrollment.objects.get_or_create(
                    program=prog, employee=emp,
                    defaults={
                        'deadline': today + timedelta(days=random.randint(14, 60)),
                        'completed': random.random() > 0.5,
                    },
                )
        self.stdout.write(f'  Training programs: {TrainingProgram.objects.count()}')

        # ── Performance reviews ──
        review_types = ['annual', 'quarterly', 'probation', 'mid_year']
        for emp in employees[:10]:
            PerformanceReview.objects.get_or_create(
                employee=emp, cycle_name=f'{today.year} Annual Review',
                defaults={
                    'review_date': today - timedelta(days=random.randint(10, 60)),
                    'review_type': random.choice(review_types),
                    'rating': random.randint(2, 5),
                    'quality_of_work': random.randint(3, 5),
                    'teamwork': random.randint(3, 5),
                    'communication': random.randint(2, 5),
                    'punctuality': random.randint(3, 5),
                    'initiative': random.randint(2, 5),
                    'patient_care': random.randint(3, 5),
                    'strengths': random.choice(['Excellent patient rapport', 'Reliable and punctual', 'Strong clinical skills']),
                    'areas_for_improvement': random.choice(['Time management', 'Documentation accuracy', 'Delegation']),
                    'status': random.choice(['draft', 'in_progress', 'completed', 'acknowledged']),
                },
            )
        self.stdout.write(f'  Performance reviews: {PerformanceReview.objects.count()}')

        # ── Goals ──
        goal_data = [
            ('Reduce medication errors by 50%', 'Clinical Excellence'),
            ('Complete BLS certification', 'Learning & Development'),
            ('Improve patient satisfaction scores', 'Patient Satisfaction'),
            ('Mentor 2 junior staff', 'Leadership'),
            ('Achieve 95% on-time visits', 'Operational'),
            ('Complete infection control audit', 'Compliance'),
        ]
        for emp in employees[:8]:
            title, cat = random.choice(goal_data)
            Goal.objects.get_or_create(
                employee=emp, title=title,
                defaults={
                    'category': cat,
                    'description': f'{title} for the current review cycle.',
                    'due_date': today + timedelta(days=random.randint(30, 120)),
                    'progress': random.choice([0, 25, 50, 75, 100]),
                },
            )
        self.stdout.write(f'  Goals: {Goal.objects.count()}')

        # ── Certifications ──
        cert_names = [
            ('Kenya Nursing Council License', 'license'),
            ('First Aid & CPR Certificate', 'cert_expiry'),
            ('BLS Certification', 'training'),
            ('Infection Control Certificate', 'training'),
            ('Defensive Driving Certificate', 'other'),
        ]
        for emp in employees[:10]:
            cname, ctype = random.choice(cert_names)
            expiry = today + timedelta(days=random.randint(-30, 180))
            Certification.objects.get_or_create(
                employee=emp, name=cname,
                defaults={
                    'type': ctype,
                    'issuer': random.choice(['Kenya Medical Training College', 'Red Cross Kenya', 'Ministry of Health']),
                    'issue_date': today - timedelta(days=random.randint(100, 700)),
                    'expiry_date': expiry,
                },
            )
        self.stdout.write(f'  Certifications: {Certification.objects.count()}')

        # ── Compliance violations ──
        violations = [
            ('Exceeded 48h weekly limit', 'max_hours', 'medium'),
            ('Overtime without authorization', 'overtime', 'low'),
            ('Insufficient rest day', 'no_rest', 'medium'),
            ('Certification expired', 'cert_expiry', 'high'),
        ]
        for vtitle, vtype, vsev in violations[:2]:
            emp = random.choice(employees[:10])
            ComplianceViolation.objects.get_or_create(
                employee=emp, title=vtitle,
                defaults={
                    'description': f'{vtitle} — flagged during compliance review.',
                    'type': vtype,
                    'severity': vsev,
                    'status': random.choice(['open', 'open', 'resolved']),
                },
            )
        self.stdout.write(f'  Compliance violations: {ComplianceViolation.objects.count()}')

        # ── Compliance reports ──
        report_types = ['labor_hours', 'payroll_audit', 'leave_compliance', 'certification']
        for rt in report_types:
            ComplianceReport.objects.get_or_create(
                type=rt, start_date=today - timedelta(days=30),
                defaults={
                    'title': dict(ComplianceReport.ReportType.choices)[rt],
                    'end_date': today,
                    'notes': 'Auto-generated quarterly compliance review.',
                },
            )
        self.stdout.write(f'  Compliance reports: {ComplianceReport.objects.count()}')

        # ── Payroll (current month) ──
        period = today.strftime('%Y-%m')
        for emp in employees:
            if emp.status in ['active', 'on_probation', 'on_leave'] and emp.salary:
                salary = emp.salary
                allowances = (salary * Decimal('0.15')).quantize(Decimal('0.01'))
                gross = salary + allowances
                paye = max((gross - Decimal('24000')) * Decimal('0.10'), Decimal(0)).quantize(Decimal('0.01'))
                nssf = min(gross * Decimal('0.06'), Decimal('1080'))
                nhif = Decimal('850')
                deductions = paye + nssf + nhif
                PayrollEntry.objects.update_or_create(
                    employee=emp, period=period,
                    defaults={
                        'basic_salary': salary,
                        'allowances': allowances,
                        'overtime_pay': Decimal('0'),
                        'gross': gross,
                        'deductions': deductions,
                        'benefits_cost': Decimal('5000'),
                        'net': (gross - deductions).quantize(Decimal('0.01')),
                        'deduction_items': [
                            {'label': 'PAYE', 'amount': float(paye)},
                            {'label': 'NSSF', 'amount': float(nssf)},
                            {'label': 'NHIF', 'amount': float(nhif)},
                        ],
                        'status': 'processed',
                    },
                )
        self.stdout.write(f'  Payroll entries: {PayrollEntry.objects.count()}')

        self.stdout.write(self.style.SUCCESS(f'HR demo data seeded successfully (run #{run_id}).'))
