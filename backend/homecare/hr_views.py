"""DRF views for the homecare HR module.

All endpoints are mounted under ``/api/homecare/hr/`` and follow the
exact contract expected by the Nuxt frontend pages in
``pages/homecare/hr/``.
"""
from datetime import timedelta
from decimal import Decimal

from django.db.models import Avg, Count, F, Q, Sum
from django.utils import timezone
from rest_framework import viewsets, status, filters
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import (
    HREmployee, LeaveRequest, LeaveBalance, Shift, Attendance, Timesheet,
    BenefitPlan, BenefitEnrollment, PayrollEntry, JobOpening, Applicant,
    OnboardingTemplate, OnboardingRecord, OnboardingTask,
    TrainingProgram, TrainingEnrollment,
    PerformanceReview, Goal,
    ComplianceViolation, Certification, ComplianceReport,
    HRDocument,
)
from .hr_serializers import (
    HREmployeeSerializer, HREmployeeSelfServiceSerializer,
    LeaveRequestSerializer, LeaveBalanceSerializer,
    ShiftSerializer, AttendanceSerializer, TimesheetSerializer,
    PayrollEntrySerializer, BenefitPlanSerializer,
    JobOpeningSerializer, ApplicantSerializer,
    OnboardingRecordSerializer, OnboardingTemplateSerializer,
    OnboardingTaskSerializer, TrainingProgramSerializer,
    PerformanceReviewSerializer, GoalSerializer,
    ComplianceViolationSerializer, CertificationSerializer,
    ComplianceReportSerializer, HRDocumentSerializer,
)
from .permissions import IsHomecareStaff, IsHomecareAdmin


# ─────────────────────────────────────────────────────────────────
#  Employees
# ─────────────────────────────────────────────────────────────────
class HREmployeeViewSet(viewsets.ModelViewSet):
    queryset = HREmployee.objects.select_related('supervisor').all()
    serializer_class = HREmployeeSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'department', 'employment_type', 'supervisor']
    search_fields = ['first_name', 'last_name', 'email', 'phone', 'job_title', 'national_id']
    ordering_fields = ['hire_date', 'salary', 'first_name', 'last_name', 'created_at']

    def perform_create(self, serializer):
        emp = serializer.save()
        LeaveBalance.objects.get_or_create(employee=emp)

    @action(detail=True, methods=['patch'], url_path='self-service')
    def self_service(self, request, pk=None):
        emp = self.get_object()
        serializer = HREmployeeSelfServiceSerializer(emp, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(HREmployeeSerializer(emp).data)



# ─────────────────────────────────────────────────────────────────
#  Leave
# ─────────────────────────────────────────────────────────────────
class LeaveRequestViewSet(viewsets.ModelViewSet):
    queryset = LeaveRequest.objects.select_related('employee', 'approver').all()
    serializer_class = LeaveRequestSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'leave_type', 'employee']
    search_fields = ['employee__first_name', 'employee__last_name', 'reason']
    ordering_fields = ['start_date', 'created_at', 'status']

    def perform_create(self, serializer):
        lr = serializer.save()
        _sync_leave_balance(lr)

    @action(detail=True, methods=['post'], url_path='approve')
    def approve(self, request, pk=None):
        lr = self.get_object()
        if lr.status != 'pending':
            return Response({'detail': 'Only pending requests can be approved.'},
                            status=status.HTTP_400_BAD_REQUEST)
        lr.status = 'approved'
        lr.approver = _resolve_approver(request)
        lr.approved_at = timezone.now()
        lr.save(update_fields=['status', 'approver', 'approved_at'])
        _sync_leave_balance(lr)
        return Response(self.get_serializer(lr).data)

    @action(detail=True, methods=['post'], url_path='reject')
    def reject(self, request, pk=None):
        lr = self.get_object()
        if lr.status != 'pending':
            return Response({'detail': 'Only pending requests can be rejected.'},
                            status=status.HTTP_400_BAD_REQUEST)
        lr.status = 'rejected'
        lr.approver = _resolve_approver(request)
        lr.approved_at = timezone.now()
        lr.save(update_fields=['status', 'approver', 'approved_at'])
        return Response(self.get_serializer(lr).data)


class LeaveBalanceViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = LeaveBalance.objects.select_related('employee').all()
    serializer_class = LeaveBalanceSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['employee']
    search_fields = ['employee__first_name', 'employee__last_name']


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def leave_calendar(request):
    """Upcoming & currently-active approved leave."""
    today = timezone.localdate()
    items = LeaveRequest.objects.filter(
        status='approved', end_date__gte=today,
    ).select_related('employee').order_by('start_date')[:50]
    return Response(LeaveRequestSerializer(items, many=True).data)


# ─────────────────────────────────────────────────────────────────
#  Scheduling — Shifts
# ─────────────────────────────────────────────────────────────────
class ShiftViewSet(viewsets.ModelViewSet):
    queryset = Shift.objects.select_related('employee').all()
    serializer_class = ShiftSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['employee', 'shift_type', 'date']
    ordering_fields = ['date', 'start_time']

    def get_queryset(self):
        qs = super().get_queryset()
        start = self.request.query_params.get('start')
        end = self.request.query_params.get('end')
        if start:
            qs = qs.filter(date__gte=start)
        if end:
            qs = qs.filter(date__lte=end)
        return qs


# ─────────────────────────────────────────────────────────────────
#  Scheduling — Attendance
# ─────────────────────────────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def attendance_today(request):
    """Today's attendance snapshot for every active employee."""
    today = timezone.localdate()
    rows = []
    for emp in HREmployee.objects.filter(status__in=['active', 'on_probation', 'on_leave']):
        att, _ = Attendance.objects.get_or_create(employee=emp, date=today)
        if emp.status == 'on_leave':
            att.status = 'on_leave'
            att.save(update_fields=['status'])
        rows.append(att)
    return Response(AttendanceSerializer(rows, many=True).data)


@api_view(['POST'])
@permission_classes([IsHomecareStaff])
def attendance_clock(request):
    """Clock in / clock out for an employee.

    Body: ``{employee: id, direction: 'in'|'out'}``
    """
    emp_id = request.data.get('employee')
    direction = (request.data.get('direction') or '').lower()
    if direction not in ('in', 'out'):
        return Response({'detail': 'direction must be "in" or "out".'}, status=400)
    try:
        emp = HREmployee.objects.get(pk=emp_id)
    except (HREmployee.DoesNotExist, (TypeError, ValueError)):
        return Response({'detail': 'Employee not found.'}, status=404)

    today = timezone.localdate()
    now = timezone.localtime().time()
    att, _ = Attendance.objects.get_or_create(employee=emp, date=today)
    if direction == 'in':
        att.clock_in = now
        att.status = 'present'
        # Late if after 09:00
        att.late = now.hour > 9 or (now.hour == 9 and now.minute > 0)
    else:
        att.clock_out = now
    att.save()
    return Response(AttendanceSerializer(att).data)


# ─────────────────────────────────────────────────────────────────
#  Timesheets
# ─────────────────────────────────────────────────────────────────
class TimesheetViewSet(viewsets.ModelViewSet):
    queryset = Timesheet.objects.select_related('employee').all()
    serializer_class = TimesheetSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['employee', 'status', 'shift_type', 'date']
    search_fields = ['employee__first_name', 'employee__last_name', 'notes']
    ordering_fields = ['date', 'submitted_at']

    def perform_update(self, serializer):
        ts = serializer.save()
        if ts.status in ('approved', 'rejected'):
            ts.reviewed_at = timezone.now()
            ts.save(update_fields=['reviewed_at'])


# ─────────────────────────────────────────────────────────────────
#  Payroll
# ─────────────────────────────────────────────────────────────────
class PayrollEntryViewSet(viewsets.ModelViewSet):
    queryset = PayrollEntry.objects.select_related('employee').all()
    serializer_class = PayrollEntrySerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['period', 'status', 'employee']
    ordering_fields = ['period', 'created_at']

    @action(detail=False, methods=['post'], url_path='run')
    def run(self, request):
        """Generate / refresh payroll entries for a given period (YYYY-MM).

        Iterates every active employee and computes basic salary,
        allowances, overtime, statutory deductions (PAYE, NSSF, NHIF),
        and net pay.
        """
        period = request.data.get('period') or timezone.localtime().strftime('%Y-%m')
        employees = HREmployee.objects.filter(
            status__in=['active', 'on_probation', 'on_leave'],
        ).exclude(salary__isnull=True)
        created_count = 0
        for emp in employees:
            salary = Decimal(emp.salary or 0)
            # Overtime from approved timesheets in the period
            month_start = timezone.datetime.strptime(period + '-01', '%Y-%m-%d').date()
            if month_start.month == 12:
                month_end = month_start.replace(year=month_start.year + 1, month=1) - timedelta(days=1)
            else:
                month_end = month_start.replace(month=month_start.month + 1) - timedelta(days=1)
            ts = Timesheet.objects.filter(
                employee=emp, status='approved',
                date__gte=month_start, date__lte=month_end,
            )
            total_hours = sum(float(t.hours or 0) for t in ts)
            overtime_hours = max(total_hours - 208, 0)  # 208 = 26 days * 8h
            hourly_rate = salary / Decimal('208') if salary else Decimal(0)
            overtime_pay = (hourly_rate * Decimal(overtime_hours) * Decimal('1.5')).quantize(Decimal('0.01'))
            allowances = (salary * Decimal('0.15')).quantize(Decimal('0.01'))
            gross = salary + allowances + overtime_pay

            # Statutory deductions (Kenya simplified)
            deduction_items = []
            paye = _paye(gross)
            nssf = min(gross * Decimal('0.06'), Decimal('1080'))
            nhif = _nhif(gross)
            for label, amt in [('PAYE', paye), ('NSSF', nssf), ('NHIF', nhif)]:
                if amt > 0:
                    deduction_items.append({'label': label, 'amount': float(amt)})
            total_deductions = paye + nssf + nhif

            benefits_cost = Decimal(0)
            for enr in BenefitEnrollment.objects.filter(employee=emp):
                benefits_cost += enr.benefit.employer_contribution

            net = (gross - total_deductions).quantize(Decimal('0.01'))

            obj, created = PayrollEntry.objects.update_or_create(
                employee=emp, period=period,
                defaults={
                    'basic_salary': salary,
                    'allowances': allowances,
                    'overtime_pay': overtime_pay,
                    'gross': gross,
                    'deductions': total_deductions,
                    'benefits_cost': benefits_cost,
                    'net': net,
                    'deduction_items': deduction_items,
                    'status': 'processed',
                },
            )
            created_count += 1
        return Response({'period': period, 'employees': created_count})


class BenefitPlanViewSet(viewsets.ModelViewSet):
    queryset = BenefitPlan.objects.all()
    serializer_class = BenefitPlanSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['type', 'mandatory', 'is_active']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at']


# ─────────────────────────────────────────────────────────────────
#  Recruitment
# ─────────────────────────────────────────────────────────────────
class JobOpeningViewSet(viewsets.ModelViewSet):
    queryset = JobOpening.objects.all()
    serializer_class = JobOpeningSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'department', 'employment_type', 'is_published']
    search_fields = ['title', 'description', 'department']
    ordering_fields = ['created_at', 'closing_date', 'title']


class ApplicantViewSet(viewsets.ModelViewSet):
    queryset = Applicant.objects.select_related('job', 'converted_employee').all()
    serializer_class = ApplicantSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['job', 'stage', 'rating']
    search_fields = ['name', 'email', 'phone', 'cover_letter']
    ordering_fields = ['applied_date', 'rating', 'name']

    @action(detail=True, methods=['post'], url_path='convert')
    def convert(self, request, pk=None):
        """Convert a hired applicant into an HREmployee record."""
        app = self.get_object()
        if app.converted_employee_id:
            return Response({'detail': 'Applicant already converted.'}, status=400)
        emp = HREmployee.objects.create(
            first_name=app.name.split(' ')[0] if app.name else '',
            last_name=' '.join(app.name.split(' ')[1:]) if app.name and ' ' in app.name else '',
            email=app.email,
            phone=app.phone,
            department=app.job.department,
            job_title=app.job.title,
            employment_type=app.job.employment_type,
            status='on_probation',
            hire_date=timezone.localdate(),
        )
        LeaveBalance.objects.get_or_create(employee=emp)
        app.converted_employee = emp
        app.stage = 'hired'
        app.save(update_fields=['converted_employee', 'stage'])
        return Response({
            'detail': 'Converted.',
            'employee_id': emp.id,
        })


# ─────────────────────────────────────────────────────────────────
#  Onboarding
# ─────────────────────────────────────────────────────────────────
class OnboardingRecordViewSet(viewsets.ModelViewSet):
    queryset = OnboardingRecord.objects.select_related('employee').all()
    serializer_class = OnboardingRecordSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['status', 'employee', 'department']
    ordering_fields = ['created_at', 'start_date']

    @action(detail=True, methods=['patch'], url_path='tasks/(?P<task_id>[0-9]+)')
    def toggle_task(self, request, pk=None, task_id=None):
        record = self.get_object()
        try:
            task = record.tasks.get(pk=task_id)
        except OnboardingTask.DoesNotExist:
            return Response({'detail': 'Task not found.'}, status=404)
        task.done = bool(request.data.get('done', not task.done))
        task.save(update_fields=['done'])
        # Auto-complete record if all tasks done
        total = record.tasks.count()
        done = record.tasks.filter(done=True).count()
        if total and done == total:
            record.status = 'completed'
            record.completed_at = timezone.now()
            if record.start_date:
                record.days_to_complete = (timezone.localdate() - record.start_date).days
            record.save(update_fields=['status', 'completed_at', 'days_to_complete'])
        elif record.status == 'completed':
            record.status = 'in_progress'
            record.completed_at = None
            record.days_to_complete = None
            record.save(update_fields=['status', 'completed_at', 'days_to_complete'])
        return Response(OnboardingTaskSerializer(task).data)


class OnboardingTemplateViewSet(viewsets.ModelViewSet):
    queryset = OnboardingTemplate.objects.all()
    serializer_class = OnboardingTemplateSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [filters.SearchFilter]
    search_fields = ['name']


# ─────────────────────────────────────────────────────────────────
#  Training
# ─────────────────────────────────────────────────────────────────
class TrainingProgramViewSet(viewsets.ModelViewSet):
    queryset = TrainingProgram.objects.all()
    serializer_class = TrainingProgramSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'mandatory', 'is_active', 'delivery_mode']
    search_fields = ['title', 'description', 'category']
    ordering_fields = ['title', 'created_at']

    @action(detail=True, methods=['post'], url_path='enroll')
    def enroll(self, request, pk=None):
        program = self.get_object()
        emp_ids = request.data.get('employees') or []
        deadline = request.data.get('deadline')
        if not isinstance(emp_ids, list) or not emp_ids:
            return Response({'employees': ['Select at least one employee.']}, status=400)
        created = 0
        for eid in emp_ids:
            try:
                emp = HREmployee.objects.get(pk=int(eid))
            except (HREmployee.DoesNotExist, (TypeError, ValueError)):
                continue
            _, c = TrainingEnrollment.objects.get_or_create(
                program=program, employee=emp,
                defaults={'deadline': deadline} if deadline else {},
            )
            if c:
                created += 1
        return Response({'enrolled': created, 'program': program.id})


# ─────────────────────────────────────────────────────────────────
#  Performance
# ─────────────────────────────────────────────────────────────────
class PerformanceReviewViewSet(viewsets.ModelViewSet):
    queryset = PerformanceReview.objects.select_related('employee').all()
    serializer_class = PerformanceReviewSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'review_type', 'employee']
    search_fields = ['employee__first_name', 'employee__last_name', 'cycle_name']
    ordering_fields = ['review_date', 'rating', 'created_at']


class GoalViewSet(viewsets.ModelViewSet):
    queryset = Goal.objects.select_related('employee').all()
    serializer_class = GoalSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['employee', 'category']
    search_fields = ['title', 'description', 'employee__first_name', 'employee__last_name']
    ordering_fields = ['due_date', 'progress', 'created_at']


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def performance_leaderboard(request):
    """Top performers ranked by average review rating."""
    qs = (
        PerformanceReview.objects.filter(rating__gt=0)
        .values('employee__id', 'employee__first_name', 'employee__last_name',
                'employee__job_title', 'employee__department')
        .annotate(
            avg_rating=Avg('rating'),
            reviews=Count('id'),
        )
        .order_by('-avg_rating')[:20]
    )
    results = []
    for row in qs:
        goals_completed = Goal.objects.filter(
            employee_id=row['employee__id'], progress=100,
        ).count()
        results.append({
            'id': row['employee__id'],
            'name': f"{row['employee__first_name']} {row['employee__last_name']}".strip(),
            'job_title': row['employee__job_title'],
            'department': row['employee__department'],
            'avg_rating': round(row['avg_rating'], 2),
            'reviews': row['reviews'],
            'goals_completed': goals_completed,
        })
    return Response(results)


# ─────────────────────────────────────────────────────────────────
#  Compliance
# ─────────────────────────────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def compliance_working_hours(request):
    """Weekly hours / overtime / rest-day compliance per active employee."""
    today = timezone.localdate()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)
    rows = []
    for emp in HREmployee.objects.filter(status__in=['active', 'on_probation', 'on_leave']):
        ts = Timesheet.objects.filter(
            employee=emp, date__gte=week_start, date__lte=week_end,
        )
        weekly_hours = sum(float(t.hours or 0) for t in ts)
        overtime_hours = max(weekly_hours - 48, 0)
        # Rest days = days in the week with no timesheet
        worked_days = set(t.date for t in ts)
        rest_days = 7 - len(worked_days)
        rows.append({
            'id': emp.id,
            'name': emp.name,
            'weekly_hours': round(weekly_hours, 1),
            'overtime_hours': round(overtime_hours, 1),
            'rest_days': rest_days,
        })
    return Response(rows)


class ComplianceViolationViewSet(viewsets.ModelViewSet):
    queryset = ComplianceViolation.objects.select_related('employee').all()
    serializer_class = ComplianceViolationSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'severity', 'type', 'employee']
    search_fields = ['title', 'description', 'employee__first_name', 'employee__last_name']
    ordering_fields = ['created_at', 'severity']

    def perform_update(self, serializer):
        v = serializer.save()
        if v.status == 'resolved' and not v.resolved_at:
            v.resolved_at = timezone.now()
            v.save(update_fields=['resolved_at'])


class CertificationViewSet(viewsets.ModelViewSet):
    queryset = Certification.objects.select_related('employee').all()
    serializer_class = CertificationSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['employee', 'type']
    search_fields = ['name', 'issuer', 'employee__first_name', 'employee__last_name']
    ordering_fields = ['expiry_date', 'name']


class ComplianceReportViewSet(viewsets.ModelViewSet):
    queryset = ComplianceReport.objects.all()
    serializer_class = ComplianceReportSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['type']
    ordering_fields = ['-generated_at']

    def perform_create(self, serializer):
        report = serializer.save()
        report.title = report.title or report.get_type_display()
        report.save(update_fields=['title'])


# ─────────────────────────────────────────────────────────────────
#  Documents
# ─────────────────────────────────────────────────────────────────
class HRDocumentViewSet(viewsets.ModelViewSet):
    queryset = HRDocument.objects.select_related('employee', 'uploaded_by').all()
    serializer_class = HRDocumentSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'access_level', 'employee']
    search_fields = ['name', 'description', 'employee__first_name', 'employee__last_name']
    ordering_fields = ['uploaded_at', 'name', 'expiry_date']

    def perform_create(self, serializer):
        serializer.save()


# ─────────────────────────────────────────────────────────────────
#  HR Dashboard
# ─────────────────────────────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def hr_dashboard(request):
    """Aggregated KPIs for the HR landing page."""
    today = timezone.localdate()
    week_ago = today - timedelta(days=7)
    month_start = today.replace(day=1)

    employees = HREmployee.objects.all()
    total_staff = employees.filter(status='active').count()
    full_time = employees.filter(employment_type='full_time', status='active').count()
    part_time = employees.filter(employment_type='part_time', status='active').count()
    onboarding = OnboardingRecord.objects.filter(status='in_progress').count()

    open_positions = JobOpening.objects.filter(status='open').count()
    applicants_total = Applicant.objects.count()
    new_applicants = Applicant.objects.filter(applied_date__gte=week_ago).count()

    on_leave = LeaveRequest.objects.filter(
        status='approved', start_date__lte=today, end_date__gte=today,
    ).count()
    pending_leaves = LeaveRequest.objects.filter(status='pending').count()

    monthly_payroll = (
        PayrollEntry.objects.filter(period=today.strftime('%Y-%m'))
        .aggregate(total=Sum('net'))['total'] or 0
    )

    # Department headcount
    dept_qs = (
        employees.filter(status='active')
        .values('department')
        .annotate(count=Count('id'))
        .order_by('-count')
    )
    dept_icons = {
        'Nursing': 'mdi-stethoscope', 'Caregiving': 'mdi-hand-heart',
        'Administration': 'mdi-desk', 'Pharmacy': 'mdi-pill',
        'Laboratory': 'mdi-test-tube', 'Radiology': 'mdi-radiology',
        'Finance': 'mdi-finance', 'IT': 'mdi-laptop', 'Operations': 'mdi-cog',
    }
    dept_colors = {
        'Nursing': 'pink', 'Caregiving': 'teal', 'Administration': 'indigo',
        'Pharmacy': 'green', 'Laboratory': 'purple', 'Radiology': 'cyan',
        'Finance': 'amber', 'IT': 'blue', 'Operations': 'orange',
    }
    max_dept = max((d['count'] for d in dept_qs), default=1) or 1
    departments = [
        {
            'name': d['department'] or 'Unassigned',
            'count': d['count'],
            'pct': round(d['count'] / max_dept * 100),
            'icon': dept_icons.get(d['department'], 'mdi-account-group'),
            'color': dept_colors.get(d['department'], 'teal'),
        }
        for d in dept_qs
    ]

    # Recruitment funnel
    funnel = {}
    for choice in Applicant.Stage.choices:
        funnel[choice[0]] = Applicant.objects.filter(stage=choice[0]).count()

    # Recent hires
    recent_hires = [
        {
            'id': e.id,
            'name': e.name,
            'role': e.job_title,
            'department': e.department,
            'start_date': e.hire_date,
            'status': e.status,
        }
        for e in employees.exclude(hire_date__isnull=True)
        .order_by('-hire_date')[:8]
    ]

    # Compliance items (expiring certs)
    certs = Certification.objects.filter(
        expiry_date__lte=today + timedelta(days=60),
    ).select_related('employee').order_by('expiry_date')[:10]
    cert_icons = {
        'cert_expiry': 'mdi-certificate', 'license': 'mdi-shield-account',
        'training': 'mdi-school', 'other': 'mdi-gavel',
    }
    compliance = []
    for c in certs:
        dl = c.days_left
        compliance.append({
            'id': c.id,
            'name': c.name,
            'type': c.type or 'Certification',
            'employee': c.employee.name,
            'days_left': dl if dl is not None else 999,
            'icon': cert_icons.get(c.type, 'mdi-certificate'),
        })

    # Compliance score
    total_certs = Certification.objects.count()
    overdue_certs = Certification.objects.filter(
        expiry_date__lt=today,
    ).count()
    compliance_score = 100
    if total_certs:
        compliance_score = round((total_certs - overdue_certs) / total_certs * 100)

    return Response({
        'total_staff': total_staff,
        'full_time': full_time,
        'part_time': part_time,
        'open_positions': open_positions,
        'applicants': applicants_total,
        'new_applicants': new_applicants,
        'onboarding': onboarding,
        'on_leave': on_leave,
        'pending_leaves': pending_leaves,
        'monthly_payroll': float(monthly_payroll),
        'compliance_score': compliance_score,
        'compliance_trend': 0,
        'departments': departments,
        'funnel': funnel,
        'recent_hires': recent_hires,
        'compliance': compliance,
    })


# ─────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────
def _resolve_approver(request):
    """Try to match the current user to an HREmployee record."""
    user = getattr(request, 'user', None)
    if not user or not user.is_authenticated:
        return None
    return HREmployee.objects.filter(email=user.email).first()


def _sync_leave_balance(leave_request):
    """Update the employee's leave balance when a request is approved."""
    if leave_request.status != 'approved':
        return
    balance, _ = LeaveBalance.objects.get_or_create(employee=leave_request.employee)
    if leave_request.leave_type == 'annual':
        balance.annual_used += leave_request.days
    elif leave_request.leave_type == 'sick':
        balance.sick_used += leave_request.days
    balance.save()


def _paye(gross):
    """Simplified Kenya PAYE calculation."""
    taxable = gross - Decimal('24000')  # personal relief
    if taxable <= 0:
        return Decimal(0)
    tax = Decimal(0)
    brackets = [
        (Decimal('0'), Decimal('0.10')),
        (Decimal('288000'), Decimal('0.25')),
        (Decimal('388000'), Decimal('0.30')),
    ]
    # Monthly bands (annual/12 approximated)
    bands = [
        (Decimal('24000'), Decimal('0.10')),
        (Decimal('8333'), Decimal('0.25')),
        (Decimal('28923'), Decimal('0.30')),
    ]
    remaining = taxable
    for width, rate in bands:
        chunk = min(remaining, width)
        tax += chunk * rate
        remaining -= chunk
        if remaining <= 0:
            break
    return max(tax, Decimal(0)).quantize(Decimal('0.01'))


def _nhif(gross):
    """Simplified Kenya SHIF/NHIF contribution (employer + employee combined band)."""
    bands = [
        (Decimal('5999'), Decimal('150')),
        (Decimal('7999'), Decimal('300')),
        (Decimal('11999'), Decimal('400')),
        (Decimal('14999'), Decimal('500')),
        (Decimal('19999'), Decimal('600')),
        (Decimal('24999'), Decimal('750')),
        (Decimal('29999'), Decimal('850')),
        (Decimal('34999'), Decimal('900')),
        (Decimal('39999'), Decimal('950')),
        (Decimal('44999'), Decimal('1000')),
        (Decimal('49999'), Decimal('1100')),
        (Decimal('59999'), Decimal('1200')),
        (Decimal('69999'), Decimal('1300')),
        (Decimal('79999'), Decimal('1400')),
        (Decimal('89999'), Decimal('1500')),
        (Decimal('99999'), Decimal('1600')),
    ]
    for ceiling, rate in bands:
        if gross <= ceiling:
            return rate
    return Decimal('1700')
