"""Serializers for the homecare HR module."""
from rest_framework import serializers

from .models import (
    HREmployee, LeaveRequest, LeaveBalance, Shift, Attendance, Timesheet,
    BenefitPlan, BenefitEnrollment, PayrollEntry, JobOpening, Applicant,
    OnboardingTemplate, OnboardingRecord, OnboardingTask,
    TrainingProgram, TrainingEnrollment,
    PerformanceReview, Goal,
    ComplianceViolation, Certification, ComplianceReport,
    HRDocument,
)


# ─────────────────────────────────────────────
# Employees
# ─────────────────────────────────────────────
class HREmployeeSerializer(serializers.ModelSerializer):
    name = serializers.CharField(read_only=True)
    supervisor_name = serializers.CharField(read_only=True)
    weekly_hours = serializers.SerializerMethodField()

    class Meta:
        model = HREmployee
        fields = (
            'id', 'first_name', 'last_name', 'name', 'email', 'phone',
            'national_id', 'gender', 'date_of_birth', 'address',
            'department', 'job_title', 'employment_type', 'status',
            'hire_date', 'probation_end_date', 'salary', 'bank_account',
            'supervisor', 'supervisor_name', 'emergency_contact',
            'weekly_hours', 'created_at', 'updated_at',
        )
        read_only_fields = ('created_at', 'updated_at')

    def get_weekly_hours(self, obj):
        from datetime import timedelta
        from django.utils import timezone
        today = timezone.localdate()
        week_start = today - timedelta(days=today.weekday())
        week_end = week_start + timedelta(days=6)
        total = Timesheet.objects.filter(
            employee=obj, date__gte=week_start, date__lte=week_end,
        ).values_list('hours', flat=True)
        return round(sum(float(h or 0) for h in total), 1)


class HREmployeeSelfServiceSerializer(serializers.ModelSerializer):
    """Limited fields editable by the employee via self-service portal."""

    class Meta:
        model = HREmployee
        fields = ('id', 'phone', 'address', 'emergency_contact', 'bank_account')
        read_only_fields = ('id',)


# ─────────────────────────────────────────────
# Leave
# ─────────────────────────────────────────────
class LeaveRequestSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)
    department = serializers.CharField(read_only=True)
    approver_name = serializers.CharField(read_only=True)
    days = serializers.IntegerField(read_only=True)

    class Meta:
        model = LeaveRequest
        fields = (
            'id', 'employee', 'employee_name', 'department',
            'leave_type', 'start_date', 'end_date', 'days',
            'reason', 'status', 'approver', 'approver_name',
            'approved_at', 'created_at',
        )
        read_only_fields = ('status', 'approver', 'approved_at', 'created_at')


class LeaveBalanceSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(source='employee.name', read_only=True)
    employee_id = serializers.IntegerField(source='employee.id', read_only=True)

    class Meta:
        model = LeaveBalance
        fields = (
            'id', 'employee', 'employee_id', 'employee_name',
            'annual_total', 'annual_used', 'sick_total', 'sick_used',
        )


# ─────────────────────────────────────────────
# Scheduling
# ─────────────────────────────────────────────
class ShiftSerializer(serializers.ModelSerializer):
    class Meta:
        model = Shift
        fields = (
            'id', 'employee', 'date', 'shift_type',
            'start_time', 'end_time', 'notes', 'created_at',
        )
        read_only_fields = ('created_at',)


class AttendanceSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)
    name = serializers.CharField(source='employee.name', read_only=True)
    hours = serializers.SerializerMethodField()

    class Meta:
        model = Attendance
        fields = (
            'id', 'employee', 'employee_name', 'name',
            'date', 'clock_in', 'clock_out', 'hours', 'late', 'status',
        )
        read_only_fields = ('date', 'clock_in', 'clock_out', 'late', 'status')

    def get_hours(self, obj):
        return obj.hours


class TimesheetSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)

    class Meta:
        model = Timesheet
        fields = (
            'id', 'employee', 'employee_name', 'date', 'hours',
            'shift_type', 'notes', 'status', 'submitted_at', 'reviewed_at',
        )
        read_only_fields = ('submitted_at', 'reviewed_at')


# ─────────────────────────────────────────────
# Payroll & Benefits
# ─────────────────────────────────────────────
class PayrollEntrySerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)
    department = serializers.CharField(read_only=True)

    class Meta:
        model = PayrollEntry
        fields = (
            'id', 'employee', 'employee_name', 'department', 'period',
            'basic_salary', 'allowances', 'overtime_pay', 'gross',
            'deductions', 'benefits_cost', 'net', 'deduction_items',
            'status', 'created_at', 'updated_at',
        )
        read_only_fields = ('basic_salary', 'allowances', 'overtime_pay',
                            'gross', 'deductions', 'benefits_cost', 'net',
                            'deduction_items', 'created_at', 'updated_at')


class BenefitPlanSerializer(serializers.ModelSerializer):
    enrolled_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = BenefitPlan
        fields = (
            'id', 'name', 'type', 'description',
            'employer_contribution', 'employee_contribution',
            'mandatory', 'is_active', 'enrolled_count', 'created_at',
        )
        read_only_fields = ('created_at',)


# ─────────────────────────────────────────────
# Recruitment
# ─────────────────────────────────────────────
class JobOpeningSerializer(serializers.ModelSerializer):
    applicant_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = JobOpening
        fields = (
            'id', 'title', 'department', 'employment_type', 'location',
            'salary_min', 'salary_max', 'closing_date',
            'description', 'requirements', 'is_published', 'status',
            'applicant_count', 'created_at',
        )
        read_only_fields = ('created_at',)


class ApplicantSerializer(serializers.ModelSerializer):
    class Meta:
        model = Applicant
        fields = (
            'id', 'job', 'name', 'email', 'phone', 'resume_url',
            'cover_letter', 'stage', 'rating', 'notes',
            'applied_date', 'converted_employee',
        )
        read_only_fields = ('applied_date', 'converted_employee')


# ─────────────────────────────────────────────
# Onboarding & Training
# ─────────────────────────────────────────────
class OnboardingTaskSerializer(serializers.ModelSerializer):
    class Meta:
        model = OnboardingTask
        fields = ('id', 'title', 'done', 'due_date', 'notes', 'created_at')
        read_only_fields = ('created_at',)


class OnboardingRecordSerializer(serializers.ModelSerializer):
    name = serializers.CharField(read_only=True)
    progress = serializers.IntegerField(read_only=True)
    tasks = OnboardingTaskSerializer(many=True, read_only=True)

    class Meta:
        model = OnboardingRecord
        fields = (
            'id', 'employee', 'name', 'role', 'department',
            'start_date', 'mentor', 'status', 'progress',
            'days_to_complete', 'tasks', 'created_at', 'completed_at',
        )
        read_only_fields = ('status', 'days_to_complete', 'completed_at', 'created_at')


class OnboardingTemplateSerializer(serializers.ModelSerializer):
    tasks = serializers.ListField(
        child=serializers.JSONField(), required=False,
    )

    class Meta:
        model = OnboardingTemplate
        fields = ('id', 'name', 'tasks', 'created_at')
        read_only_fields = ('created_at',)


class TrainingProgramSerializer(serializers.ModelSerializer):
    enrolled_count = serializers.IntegerField(read_only=True)
    certified_count = serializers.IntegerField(read_only=True)
    completion_pct = serializers.IntegerField(read_only=True)

    class Meta:
        model = TrainingProgram
        fields = (
            'id', 'title', 'category', 'description', 'duration_hours',
            'delivery_mode', 'mandatory', 'is_active',
            'enrolled_count', 'certified_count', 'completion_pct',
            'created_at',
        )
        read_only_fields = ('created_at',)


# ─────────────────────────────────────────────
# Performance
# ─────────────────────────────────────────────
class PerformanceReviewSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)
    job_title = serializers.CharField(read_only=True)

    class Meta:
        model = PerformanceReview
        fields = (
            'id', 'employee', 'employee_name', 'job_title',
            'cycle_name', 'review_date', 'review_type',
            'rating', 'quality_of_work', 'teamwork', 'communication',
            'punctuality', 'initiative', 'patient_care',
            'strengths', 'areas_for_improvement', 'comments',
            'status', 'created_at',
        )
        read_only_fields = ('created_at',)


class GoalSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)

    class Meta:
        model = Goal
        fields = (
            'id', 'employee', 'employee_name', 'title', 'category',
            'description', 'due_date', 'progress', 'created_at',
        )
        read_only_fields = ('created_at',)


# ─────────────────────────────────────────────
# Compliance
# ─────────────────────────────────────────────
class ComplianceViolationSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)

    class Meta:
        model = ComplianceViolation
        fields = (
            'id', 'employee', 'employee_name', 'title', 'description',
            'type', 'severity', 'status', 'created_at', 'resolved_at',
        )
        read_only_fields = ('created_at', 'resolved_at')


class CertificationSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)
    days_left = serializers.SerializerMethodField()

    class Meta:
        model = Certification
        fields = (
            'id', 'employee', 'employee_name', 'name', 'type',
            'issuer', 'issue_date', 'expiry_date', 'days_left',
        )

    def get_days_left(self, obj):
        return obj.days_left


class ComplianceReportSerializer(serializers.ModelSerializer):
    type_label = serializers.CharField(read_only=True)

    class Meta:
        model = ComplianceReport
        fields = (
            'id', 'title', 'type', 'type_label', 'start_date', 'end_date',
            'notes', 'file_url', 'generated_at',
        )
        read_only_fields = ('generated_at', 'file_url')


# ─────────────────────────────────────────────
# Documents
# ─────────────────────────────────────────────
class HRDocumentSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(read_only=True)
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = HRDocument
        fields = (
            'id', 'name', 'category', 'employee', 'employee_name',
            'access_level', 'description', 'file', 'file_url',
            'file_type', 'file_size', 'expiry_date',
            'uploaded_at',
        )
        read_only_fields = ('file_type', 'file_size', 'uploaded_at')

    def get_file_url(self, obj):
        if not obj.file:
            return None
        request = self.context.get('request')
        url = obj.file.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    def _process_file(self, validated_data):
        file = validated_data.get('file')
        if file:
            validated_data['file_type'] = file.name.rsplit('.', 1)[-1].lower() if '.' in file.name else 'file'
            validated_data['file_size'] = file.size

    def create(self, validated_data):
        self._process_file(validated_data)
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['uploaded_by'] = request.user
        return super().create(validated_data)

    def update(self, instance, validated_data):
        self._process_file(validated_data)
        return super().update(instance, validated_data)
