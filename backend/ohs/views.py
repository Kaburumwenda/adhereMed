"""Occupational Health & Safety Management System API — ``/api/ohs/``."""
from calendar import month_abbr
from datetime import date, timedelta

from django.db.models import Count, F, Q, Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from config.cache import tenant_cache

from .models import (
    AssessmentFinding,
    AssessmentLabResult,
    Certification,
    ComplianceAudit,
    Contractor,
    ContractorEngagement,
    ControlMeasure,
    Document,
    DocumentAcknowledgement,
    DocumentRevision,
    EmergencyDrill,
    EquipmentDefect,
    EquipmentInspection,
    ExposureMonitoring,
    Hazard,
    HazardCategory,
    HealthAssessment,
    HealthSurveillance,
    Incident,
    IncidentAction,
    Inspection,
    InspectionItem,
    JobDemandProfile,
    LegalRequirement,
    ManagementReview,
    MeetingAttendance,
    Observation,
    PermitToWork,
    PpeIssue,
    PpeItem,
    RiskAssessment,
    RiskAssessmentItem,
    SafetyEquipment,
    SafetyMeeting,
    SafetyObjective,
    Site,
    TrainingCourse,
    TrainingRecord,
    risk_band,
)
from .serializers import (
    AssessmentFindingSerializer,
    AssessmentLabResultSerializer,
    CertificationSerializer,
    ComplianceAuditSerializer,
    ContractorEngagementSerializer,
    ContractorListSerializer,
    ContractorSerializer,
    ControlMeasureSerializer,
    DocumentAcknowledgementSerializer,
    DocumentListSerializer,
    DocumentRevisionSerializer,
    DocumentSerializer,
    EmergencyDrillSerializer,
    EquipmentDefectSerializer,
    EquipmentInspectionSerializer,
    ExposureMonitoringSerializer,
    HazardCategorySerializer,
    HazardListSerializer,
    HazardSerializer,
    HealthAssessmentListSerializer,
    HealthAssessmentSerializer,
    HealthSurveillanceSerializer,
    IncidentActionSerializer,
    IncidentListSerializer,
    IncidentSerializer,
    InspectionItemSerializer,
    InspectionSerializer,
    JobDemandProfileSerializer,
    LegalRequirementSerializer,
    ManagementReviewSerializer,
    MeetingAttendanceSerializer,
    ObservationSerializer,
    PermitToWorkSerializer,
    PpeIssueSerializer,
    PpeItemSerializer,
    RiskAssessmentItemSerializer,
    RiskAssessmentSerializer,
    SafetyEquipmentListSerializer,
    SafetyEquipmentSerializer,
    SafetyMeetingListSerializer,
    SafetyMeetingSerializer,
    SafetyObjectiveSerializer,
    SiteSerializer,
    TrainingCourseSerializer,
    TrainingRecordSerializer,
)

RISK_LEVELS = ['negligible', 'low', 'medium', 'high', 'critical']


def _actor_name(request):
    """Display name of the acting user (custom User model uses ``full_name``)."""
    user = getattr(request, 'user', None)
    if not user or not user.is_authenticated:
        return ''
    return getattr(user, 'full_name', '') or user.get_username()


def _as_date(value):
    """Coerce a JSON body value into a ``date``, or ``None``.

    ``request.data`` is raw on custom actions, so an ISO string arrives as a
    string. Doing date arithmetic on it raises ``TypeError`` deep inside the
    view; normalising at the boundary keeps the failure mode a 400 instead.
    """
    if not value:
        return None
    if isinstance(value, date) and not hasattr(value, 'hour'):
        return value
    try:
        return parse_date(str(value)[:10])
    except (TypeError, ValueError):
        return None


class OhsBaseViewSet(viewsets.ModelViewSet):
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    ordering = ['-id']

    def _list_serializer_class(self):
        return getattr(self, 'list_serializer_class', self.serializer_class)

    def get_serializer_class(self):
        if self.action == 'list' and self._list_serializer_class():
            return self._list_serializer_class()
        return self.serializer_class


# ─────────────────────────────────────────────────────────────────────────
#  Sites & categories
# ─────────────────────────────────────────────────────────────────────────
class SiteViewSet(OhsBaseViewSet):
    queryset = Site.objects.all()
    serializer_class = SiteSerializer
    search_fields = ['name', 'code', 'site_manager', 'address', 'county']
    filterset_fields = ['site_type', 'risk_profile', 'is_active']
    ordering_fields = ['name', 'headcount', 'created_at']


class HazardCategoryViewSet(OhsBaseViewSet):
    queryset = HazardCategory.objects.all()
    serializer_class = HazardCategorySerializer
    search_fields = ['name', 'code']
    ordering = ['sort_order', 'name']


# ─────────────────────────────────────────────────────────────────────────
#  Hazards
# ─────────────────────────────────────────────────────────────────────────
class HazardViewSet(OhsBaseViewSet):
    queryset = Hazard.objects.select_related('site', 'category').prefetch_related('controls')
    serializer_class = HazardSerializer
    list_serializer_class = HazardListSerializer
    search_fields = ['reference', 'title', 'description', 'area', 'activity', 'owner_name']
    filterset_fields = ['site', 'hazard_type', 'status', 'category']
    ordering_fields = ['reference', 'title', 'identified_on', 'next_review_on', 'updated_at']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        level = p.get('risk_level')
        if level:
            ranges = {
                'critical': (20, 25),
                'high': (15, 19),
                'medium': (8, 14),
                'low': (4, 7),
                'negligible': (1, 3),
            }
            lo, hi = ranges.get(level, (1, 25))
            qs = qs.filter(
                severity__gte=1,
                severity__lte=5,
                likelihood__gte=1,
                likelihood__lte=5,
            )
            ids = [h.id for h in qs if lo <= (h.severity * h.likelihood) <= hi]
            qs = Hazard.objects.filter(id__in=ids)
        if p.get('min_score'):
            try:
                minscore = int(p['min_score'])
            except (TypeError, ValueError):
                minscore = 0
            ids = [h.id for h in qs if (h.severity * h.likelihood) >= minscore]
            qs = Hazard.objects.filter(id__in=ids)
        if p.get('overdue_controls') in ('1', 'true'):
            qs = qs.filter(
                controls__due_date__lt=date.today(),
            ).exclude(controls__status__in=['implemented', 'verified']).distinct()
        return qs

    @action(detail=False, methods=['get'])
    def matrix(self, request):
        """5 × 5 hazard heat-map counts (likelihood rows × severity columns)."""
        cells = [[0] * 5 for _ in range(5)]
        for sev, lik, count in (
            Hazard.objects.values_list('severity', 'likelihood')
            .annotate(count=Count('id'))
        ):
            if 1 <= sev <= 5 and 1 <= lik <= 5:
                cells[lik - 1][sev - 1] = count
        by_level = {lvl: 0 for lvl in RISK_LEVELS}
        for hazard in Hazard.objects.all():
            by_level[hazard.risk_level] += 1
        return Response({'matrix': cells, 'by_level': by_level, 'total': Hazard.objects.count()})

    @action(detail=True, methods=['post'])
    def add_control(self, request, pk=None):
        hazard = self.get_object()
        payload = dict(request.data, hazard=hazard.id)
        serializer = ControlMeasureSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=201)


class ControlMeasureViewSet(OhsBaseViewSet):
    queryset = ControlMeasure.objects.select_related('hazard')
    serializer_class = ControlMeasureSerializer
    search_fields = ['description', 'owner_name']
    filterset_fields = ['hazard', 'hierarchy', 'status']
    ordering_fields = ['due_date', 'created_at']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        if p.get('overdue') in ('1', 'true'):
            qs = qs.filter(due_date__lt=date.today()).exclude(
                status__in=['implemented', 'verified']
            )
        return qs


# ─────────────────────────────────────────────────────────────────────────
#  Risk assessments
# ─────────────────────────────────────────────────────────────────────────
class RiskAssessmentViewSet(OhsBaseViewSet):
    queryset = RiskAssessment.objects.select_related('site').prefetch_related('items')
    serializer_class = RiskAssessmentSerializer
    search_fields = ['reference', 'title', 'scope', 'assessor_name']
    filterset_fields = ['site', 'status', 'methodology']
    ordering_fields = ['assessment_date', 'review_date', 'created_at']

    @action(detail=True, methods=['post'])
    def add_item(self, request, pk=None):
        assessment = self.get_object()
        payload = dict(request.data, assessment=assessment.id)
        serializer = RiskAssessmentItemSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=201)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        assessment = self.get_object()
        assessment.status = RiskAssessment.Status.APPROVED
        assessment.approved_by = request.data.get('approved_by') or request.user.get_full_name()
        assessment.approved_at = timezone.now()
        assessment.save(update_fields=['status', 'approved_by', 'approved_at', 'updated_at'])
        return Response(self.get_serializer(assessment).data)


class RiskAssessmentItemViewSet(OhsBaseViewSet):
    queryset = RiskAssessmentItem.objects.select_related('assessment')
    serializer_class = RiskAssessmentItemSerializer
    filterset_fields = ['assessment', 'status']
    search_fields = ['hazard_text', 'activity', 'responsible']


# ─────────────────────────────────────────────────────────────────────────
#  Incidents
# ─────────────────────────────────────────────────────────────────────────
class IncidentViewSet(OhsBaseViewSet):
    queryset = Incident.objects.select_related('site').prefetch_related('actions')
    serializer_class = IncidentSerializer
    list_serializer_class = IncidentListSerializer
    search_fields = ['reference', 'title', 'description', 'person_involved', 'location']
    filterset_fields = ['site', 'incident_type', 'severity', 'status']
    ordering_fields = ['occurred_at', 'severity', 'lost_days', 'created_at']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        if p.get('is_lost_time') in ('1', 'true'):
            qs = qs.filter(is_lost_time=True)
        if p.get('recordable') in ('1', 'true'):
            qs = qs.filter(is_recordable=True)
        if p.get('open') in ('1', 'true'):
            qs = qs.exclude(status='closed')
        if p.get('date_from'):
            qs = qs.filter(occurred_at__date__gte=p['date_from'])
        if p.get('date_to'):
            qs = qs.filter(occurred_at__date__lte=p['date_to'])
        return qs

    @action(detail=True, methods=['post'])
    def add_action(self, request, pk=None):
        incident = self.get_object()
        payload = dict(request.data, incident=incident.id)
        serializer = IncidentActionSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=201)

    @action(detail=True, methods=['post'])
    def close(self, request, pk=None):
        incident = self.get_object()
        incident.status = Incident.Status.CLOSED
        incident.closed_at = timezone.now()
        incident.save(update_fields=['status', 'closed_at', 'updated_at'])
        return Response(self.get_serializer(incident).data)


class IncidentActionViewSet(OhsBaseViewSet):
    queryset = IncidentAction.objects.select_related('incident')
    serializer_class = IncidentActionSerializer
    filterset_fields = ['incident', 'action_type', 'status']
    search_fields = ['description', 'owner_name']
    ordering_fields = ['due_date', 'created_at']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        if self.request.query_params.get('overdue') in ('1', 'true'):
            qs = qs.filter(due_date__lt=date.today()).exclude(status__in=['done', 'verified'])
        return qs


# ─────────────────────────────────────────────────────────────────────────
#  Inspections
# ─────────────────────────────────────────────────────────────────────────
class InspectionViewSet(OhsBaseViewSet):
    queryset = Inspection.objects.select_related('site').prefetch_related('items')
    serializer_class = InspectionSerializer
    search_fields = ['reference', 'title', 'area', 'inspector_name']
    filterset_fields = ['site', 'inspection_type', 'status']
    ordering_fields = ['scheduled_for', 'completed_on', 'score']

    @action(detail=True, methods=['post'])
    def add_item(self, request, pk=None):
        inspection = self.get_object()
        payload = dict(request.data, inspection=inspection.id)
        serializer = InspectionItemSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=201)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        inspection = self.get_object()
        inspection.status = Inspection.Status.COMPLETED
        inspection.completed_on = request.data.get('completed_on') or date.today()
        if request.data.get('score') is not None:
            inspection.score = request.data['score']
        inspection.save(update_fields=['status', 'completed_on', 'score', 'updated_at'])
        return Response(self.get_serializer(inspection).data)


class InspectionItemViewSet(OhsBaseViewSet):
    queryset = InspectionItem.objects.select_related('inspection')
    serializer_class = InspectionItemSerializer
    filterset_fields = ['inspection', 'result', 'severity']
    search_fields = ['checklist_item', 'category']


# ─────────────────────────────────────────────────────────────────────────
#  Permits
# ─────────────────────────────────────────────────────────────────────────
class PermitToWorkViewSet(OhsBaseViewSet):
    queryset = PermitToWork.objects.select_related('site')
    serializer_class = PermitToWorkSerializer
    search_fields = ['reference', 'title', 'area', 'requested_by', 'issued_by']
    filterset_fields = ['site', 'permit_type', 'status', 'risk_level']
    ordering_fields = ['valid_from', 'valid_to', 'created_at']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        if self.request.query_params.get('active') in ('1', 'true'):
            qs = qs.filter(status__in=['approved', 'active'])
        return qs

    @action(detail=True, methods=['post'])
    def set_status(self, request, pk=None):
        permit = self.get_object()
        new_status = request.data.get('status')
        if new_status not in dict(PermitToWork.Status.choices):
            return Response({'detail': 'Invalid status.'}, status=400)
        permit.status = new_status
        if new_status == PermitToWork.Status.CLOSED:
            permit.closed_at = timezone.now()
            permit.closure_note = request.data.get('closure_note', '')
        permit.save()
        return Response(self.get_serializer(permit).data)


# ─────────────────────────────────────────────────────────────────────────
#  Training
# ─────────────────────────────────────────────────────────────────────────
class TrainingCourseViewSet(OhsBaseViewSet):
    queryset = TrainingCourse.objects.all()
    serializer_class = TrainingCourseSerializer
    search_fields = ['name', 'code', 'provider']
    filterset_fields = ['category', 'is_mandatory']
    ordering = ['name']


class TrainingRecordViewSet(OhsBaseViewSet):
    queryset = TrainingRecord.objects.select_related('course', 'site')
    serializer_class = TrainingRecordSerializer
    search_fields = ['employee_name', 'employee_ref', 'certificate_ref', 'course__name']
    filterset_fields = ['course', 'site', 'result']
    ordering_fields = ['completed_on', 'expires_on']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        if p.get('expired') in ('1', 'true'):
            qs = qs.filter(expires_on__lt=date.today())
        if p.get('expiring'):
            try:
                days = int(p['expiring'])
            except (TypeError, ValueError):
                days = 60
            qs = qs.filter(
                expires_on__gte=date.today(),
                expires_on__lte=date.today() + timedelta(days=days),
            )
        return qs


# ─────────────────────────────────────────────────────────────────────────
#  PPE
# ─────────────────────────────────────────────────────────────────────────
class PpeItemViewSet(OhsBaseViewSet):
    queryset = PpeItem.objects.all()
    serializer_class = PpeItemSerializer
    search_fields = ['name', 'code', 'standard']
    filterset_fields = ['category']
    ordering_fields = ['name', 'stock_on_hand', 'reorder_level']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        if self.request.query_params.get('low_stock') in ('1', 'true'):
            qs = qs.filter(stock_on_hand__lte=F('reorder_level'))
        return qs


class PpeIssueViewSet(OhsBaseViewSet):
    queryset = PpeIssue.objects.select_related('ppe_item', 'site')
    serializer_class = PpeIssueSerializer
    search_fields = ['employee_name', 'employee_ref', 'ppe_item__name']
    filterset_fields = ['ppe_item', 'site']
    ordering_fields = ['issued_on', 'replacement_due']


# ─────────────────────────────────────────────────────────────────────────
#  Health surveillance
# ─────────────────────────────────────────────────────────────────────────
class HealthSurveillanceViewSet(OhsBaseViewSet):
    queryset = HealthSurveillance.objects.select_related('site')
    serializer_class = HealthSurveillanceSerializer
    search_fields = ['employee_name', 'employee_ref', 'job_title', 'provider']
    filterset_fields = ['site', 'programme', 'result']
    ordering_fields = ['scheduled_on', 'next_due']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        if self.request.query_params.get('due') in ('1', 'true'):
            qs = qs.filter(result='pending', scheduled_on__lte=date.today())
        return qs


# ─────────────────────────────────────────────────────────────────────────
#  Observations
# ─────────────────────────────────────────────────────────────────────────
class ObservationViewSet(OhsBaseViewSet):
    queryset = Observation.objects.select_related('site')
    serializer_class = ObservationSerializer
    search_fields = ['observer_name', 'observed_person', 'department', 'description']
    filterset_fields = ['site', 'kind', 'category']
    ordering_fields = ['observed_at']


# ─────────────────────────────────────────────────────────────────────────
#  Exposure monitoring
# ─────────────────────────────────────────────────────────────────────────
class ExposureMonitoringViewSet(OhsBaseViewSet):
    queryset = ExposureMonitoring.objects.select_related('site')
    serializer_class = ExposureMonitoringSerializer
    search_fields = ['area', 'method', 'lab_reference', 'agent']
    filterset_fields = ['site', 'agent', 'result']
    ordering_fields = ['measured_on']


# ─────────────────────────────────────────────────────────────────────────
#  Emergency drills
# ─────────────────────────────────────────────────────────────────────────
class EmergencyDrillViewSet(OhsBaseViewSet):
    queryset = EmergencyDrill.objects.select_related('site')
    serializer_class = EmergencyDrillSerializer
    search_fields = ['scenario', 'findings', 'coordinator', 'drill_type']
    filterset_fields = ['site', 'drill_type', 'status']
    ordering_fields = ['scheduled_on', 'conducted_on']


# ─────────────────────────────────────────────────────────────────────────
#  Compliance
# ─────────────────────────────────────────────────────────────────────────
class LegalRequirementViewSet(OhsBaseViewSet):
    queryset = LegalRequirement.objects.all()
    serializer_class = LegalRequirementSerializer
    search_fields = ['title', 'standard', 'clause', 'description', 'reference']
    filterset_fields = ['compliance_status', 'standard']
    ordering = ['standard', 'clause', 'title']


class ComplianceAuditViewSet(OhsBaseViewSet):
    queryset = ComplianceAudit.objects.select_related('site')
    serializer_class = ComplianceAuditSerializer
    search_fields = ['reference', 'title', 'auditor', 'standard', 'scope']
    filterset_fields = ['site', 'audit_type', 'status']
    ordering_fields = ['scheduled_on', 'completed_on', 'score']


# ─────────────────────────────────────────────────────────────────────────
#  Objectives
# ─────────────────────────────────────────────────────────────────────────
class SafetyObjectiveViewSet(OhsBaseViewSet):
    queryset = SafetyObjective.objects.select_related('site')
    serializer_class = SafetyObjectiveSerializer
    search_fields = ['title', 'description', 'owner_name']
    filterset_fields = ['site', 'category', 'status']
    ordering_fields = ['due_date', 'created_at']


# ─────────────────────────────────────────────────────────────────────────
#  Dashboard / analytics
# ─────────────────────────────────────────────────────────────────────────
def _month_key(d):
    return f'{d.year}-{d.month:02d}'


def _month_label(d):
    return f'{month_abbr[d.month]} {str(d.year)[2:]}'


def _month_windows(months=12):
    today = date.today().replace(day=1)
    out = []
    cur = today
    for _ in range(months):
        out.append(cur)
        cur = (cur - timedelta(days=1)).replace(day=1)
    return list(reversed(out))


def _pct(part, whole):
    if not whole:
        return 0.0
    return round(part / whole * 100, 1)


class OhsDashboardView(APIView):
    """Single-call OHSMS cockpit payload."""

    @tenant_cache('ohsms.dashboard', timeout=60)
    def get(self, request):
        try:
            days = int(request.query_params.get('days', 90))
        except (TypeError, ValueError):
            days = 90
        days = max(7, min(days, 730))
        today = date.today()
        since = timezone.now() - timedelta(days=days)
        prev_since = since - timedelta(days=days)

        sites = list(Site.objects.all())
        total_headcount = sum(s.headcount for s in sites)
        total_hours = sum(s.hours_worked for s in sites) or (total_headcount * 2000)

        hazards = Hazard.objects.select_related('category')
        open_hazards = hazards.exclude(status='closed')
        high_risk = [h for h in open_hazards if h.risk_score and h.risk_score >= 15]
        controls = ControlMeasure.objects.all()
        overdue_controls = [c for c in controls if c.is_overdue]

        incidents = Incident.objects.select_related('site')
        period_incidents = incidents.filter(occurred_at__gte=since)
        prev_incidents = incidents.filter(occurred_at__gte=prev_since, occurred_at__lt=since)
        open_incidents_qs = incidents.exclude(status='closed')
        recordable = incidents.filter(occurred_at__gte=since, is_recordable=True)
        lti = incidents.filter(occurred_at__gte=since, is_lost_time=True)
        lost_days = lti.aggregate(v=Sum('lost_days'))['v'] or 0

        trir = round(recordable.count() * 200000 / total_hours, 2) if total_hours else 0
        ltifr = round(lti.count() * 1000000 / total_hours, 2) if total_hours else 0
        severity_rate = round(lost_days * 1000 / total_hours, 2) if total_hours else 0

        actions = IncidentAction.objects.select_related('incident')
        open_actions = actions.exclude(status__in=['done', 'verified'])
        overdue_actions = [a for a in open_actions if a.is_overdue]

        inspections = Inspection.objects.all()
        inspections_due = inspections.filter(
            status__in=['scheduled', 'overdue'], scheduled_for__lte=today + timedelta(days=7),
        ).count()
        completed_insp = inspections.filter(status='completed', score__isnull=False)
        compliance_score = (
            round(sum(i.score for i in completed_insp) / completed_insp.count(), 1)
            if completed_insp.exists() else 0
        )

        permits = PermitToWork.objects.all()
        permits_active = permits.filter(status__in=['approved', 'active'])
        permits_expiring = permits.filter(
            status__in=['approved', 'active'],
            valid_to__isnull=False,
            valid_to__lte=timezone.now() + timedelta(hours=24),
        ).count()

        mandatory = TrainingCourse.objects.filter(is_mandatory=True)
        mandatory_records = TrainingRecord.objects.filter(
            course__is_mandatory=True,
        ).exclude(result='fail')
        valid_now = [r for r in mandatory_records if not r.is_expired]
        training_pct = _pct(len(valid_now), mandatory_records.count())
        training_expiring = TrainingRecord.objects.filter(
            expires_on__gte=today, expires_on__lte=today + timedelta(days=60),
        ).count()

        ppe_low = PpeItem.objects.filter(stock_on_hand__lte=F('reorder_level')).count()

        observations = Observation.objects.all()
        period_obs = observations.filter(observed_at__gte=since)
        safe_obs = period_obs.filter(kind__in=['safe', 'positive']).count()

        drills = EmergencyDrill.objects.all()
        drills_due = drills.filter(status='planned', scheduled_on__lte=today).count()
        completed_drills = [d for d in drills.filter(status='completed')]
        avg_evac = (
            round(sum(d.evacuation_seconds for d in completed_drills if d.evacuation_seconds)
                  / max(len([d for d in completed_drills if d.evacuation_seconds]), 1))
        )

        legal = LegalRequirement.objects.all()
        legal_non_compliant = legal.filter(compliance_status='non_compliant').count()
        legal_breakdown = {
            'compliant': legal.filter(compliance_status='compliant').count(),
            'partial': legal.filter(compliance_status='partial').count(),
            'non_compliant': legal_non_compliant,
            'not_assessed': legal.filter(compliance_status='not_assessed').count(),
        }
        legal_total = sum(legal_breakdown.values())
        legal_score = (
            round((legal_breakdown['compliant'] + legal_breakdown['partial'] * 0.5)
                  / legal_total * 100, 1) if legal_total else 0
        )

        audits = ComplianceAudit.objects.filter(score__isnull=False)
        audit_score = (
            round(sum(a.score for a in audits) / audits.count(), 1) if audits.exists() else 0
        )

        health_due = HealthSurveillance.objects.filter(
            result='pending', scheduled_on__lte=today,
        ).count()

        exposure = ExposureMonitoring.objects.all()
        exposure_exceeded = exposure.filter(result='exceeded').count()

        objectives = SafetyObjective.objects.all()
        open_objectives = objectives.exclude(status='achieved').count()
        objectives_on_track = objectives.filter(status__in=['on_track', 'achieved']).count()

        # ── Risk matrix (likelihood rows × severity cols) ──────────────
        matrix = [[0] * 5 for _ in range(5)]
        for sev, lik, count in (
            hazards.values_list('severity', 'likelihood').annotate(count=Count('id'))
        ):
            if 1 <= sev <= 5 and 1 <= lik <= 5:
                matrix[lik - 1][sev - 1] = count
        risk_by_level = {lvl: 0 for lvl in RISK_LEVELS}
        for h in hazards:
            risk_by_level[h.risk_level] += 1

        # ── Incident trend (12 months) ────────────────────────────────
        trend = []
        for start in _month_windows(12):
            end = (start + timedelta(days=32)).replace(day=1)
            bucket = incidents.filter(occurred_at__date__gte=start, occurred_at__date__lt=end)
            trend.append({
                'key': _month_key(start),
                'label': _month_label(start),
                'total': bucket.count(),
                'lti': bucket.filter(is_lost_time=True).count(),
                'near_miss': bucket.filter(incident_type='near_miss').count(),
                'recordable': bucket.filter(is_recordable=True).count(),
            })

        # ── Breakdowns ────────────────────────────────────────────────
        type_labels = dict(Incident.IncidentType.choices)
        incidents_by_type = [
            {'key': row['incident_type'], 'label': type_labels.get(row['incident_type'], row['incident_type']),
             'count': row['count']}
            for row in period_incidents.values('incident_type').annotate(count=Count('id'))
        ]
        incidents_by_type.sort(key=lambda r: -r['count'])

        hazards_by_category = []
        for cat in HazardCategory.objects.all():
            cat_hazards = [h for h in hazards if h.category_id == cat.id]
            if not cat_hazards:
                continue
            hazards_by_category.append({
                'id': cat.id, 'name': cat.name, 'color': cat.color, 'icon': cat.icon,
                'count': len(cat_hazards),
                'high': sum(1 for h in cat_hazards if (h.risk_score or 0) >= 15),
            })
        hazards_by_category.sort(key=lambda r: -r['count'])

        # ── Site scorecard ────────────────────────────────────────────
        scorecard = []
        for s in sites:
            site_hazards = [h for h in hazards if h.site_id == s.id]
            site_open = [h for h in site_hazards if h.status != 'closed']
            site_incidents = incidents.filter(site=s, occurred_at__gte=since)
            site_open_inc = incidents.filter(site=s).exclude(status='closed')
            site_overdue = [c for c in controls if c.hazard.site_id == s.id and c.is_overdue]
            site_permits = permits.filter(site=s, status__in=['approved', 'active']).count()
            tr = TrainingRecord.objects.filter(site=s).exclude(result='fail')
            site_training = _pct(len([r for r in tr if not r.is_expired]), max(s.headcount, 1))
            penalty = (
                min(len([h for h in site_open if (h.risk_score or 0) >= 15]) * 6, 30)
                + min(site_open_inc.count() * 5, 25)
                + min(len(site_overdue) * 4, 20)
            )
            scorecard.append({
                'id': s.id, 'name': s.name, 'site_type': s.site_type,
                'risk_profile': s.risk_profile, 'headcount': s.headcount,
                'open_hazards': len(site_open),
                'high_risk': len([h for h in site_open if (h.risk_score or 0) >= 15]),
                'incidents': site_incidents.count(),
                'open_incidents': site_open_inc.count(),
                'overdue_controls': len(site_overdue),
                'active_permits': site_permits,
                'training_pct': site_training,
                'score': max(0, 100 - penalty),
            })
        scorecard.sort(key=lambda r: r['score'])

        # ── Action queue (unified overdue / due-soon list) ────────────
        queue = []
        for c in overdue_controls[:12]:
            queue.append({
                'kind': 'control', 'ref': c.hazard.reference,
                'title': c.description[:120], 'owner': c.owner_name,
                'due': c.due_date.isoformat() if c.due_date else None,
                'days': (today - c.due_date).days if c.due_date else None,
                'href': '/ohs/hazards',
            })
        for a in overdue_actions[:12]:
            queue.append({
                'kind': 'capa', 'ref': a.incident.reference,
                'title': a.description[:120], 'owner': a.owner_name,
                'due': a.due_date.isoformat() if a.due_date else None,
                'days': (today - a.due_date).days if a.due_date else None,
                'href': '/ohs/incidents',
            })
        for i in inspections.filter(status='scheduled', scheduled_for__lt=today)[:10]:
            queue.append({
                'kind': 'inspection', 'ref': i.reference, 'title': i.title,
                'owner': i.inspector_name,
                'due': i.scheduled_for.isoformat(),
                'days': (today - i.scheduled_for).days,
                'href': '/ohs/inspections',
            })
        for p in permits.filter(status__in=['approved', 'active'],
                                valid_to__isnull=False,
                                valid_to__lt=timezone.now())[:8]:
            queue.append({
                'kind': 'permit', 'ref': p.reference, 'title': p.title,
                'owner': p.issued_by,
                'due': p.valid_to.date().isoformat(),
                'days': (today - p.valid_to.date()).days,
                'href': '/ohs/permits',
            })
        for r in TrainingRecord.objects.filter(expires_on__lt=today).exclude(result='fail')[:10]:
            queue.append({
                'kind': 'training', 'ref': r.course.code or r.course.name[:16],
                'title': f'{r.employee_name} — certificate expired',
                'owner': r.employee_name,
                'due': r.expires_on.isoformat(),
                'days': (today - r.expires_on).days,
                'href': '/ohs/training',
            })
        queue.sort(key=lambda r: -(r['days'] or 0))

        # ── Recent incidents ─────────────────────────────────────────
        recent_incidents = IncidentListSerializer(
            incidents.order_by('-occurred_at')[:6], many=True,
        ).data

        # ── Top risks ────────────────────────────────────────────────
        top_risks = HazardListSerializer(
            sorted(open_hazards, key=lambda h: -(h.risk_score or 0))[:8], many=True,
        ).data

        # ── Per-course compliance ────────────────────────────────────
        course_rows = []
        for course in TrainingCourse.objects.all():
            records = TrainingRecord.objects.filter(course=course).exclude(result='fail')
            valid = [r for r in records if not r.is_expired]
            course_rows.append({
                'id': course.id, 'name': course.name, 'code': course.code,
                'mandatory': course.is_mandatory,
                'trained': len(valid), 'records': records.count(),
                'pct': _pct(len(valid), records.count()),
            })
        course_rows.sort(key=lambda r: (not r['mandatory'], r['pct']))

        # ── Exposure summary ─────────────────────────────────────────
        agent_labels = dict(ExposureMonitoring.Agent.choices)
        exposure_rows = []
        for row in exposure.values('agent').annotate(
            count=Count('id'), exceeded=Count('id', filter=Q(result='exceeded')),
        ):
            worst = exposure.filter(agent=row['agent']).order_by('-measured_value').first()
            exposure_rows.append({
                'agent': row['agent'],
                'label': agent_labels.get(row['agent'], row['agent']),
                'readings': row['count'], 'exceeded': row['exceeded'],
                'unit': worst.unit if worst else '',
                'worst': float(worst.measured_value) if worst else 0,
                'limit': float(worst.oel_limit) if worst and worst.oel_limit else None,
            })

        # ── Objective progress ───────────────────────────────────────
        objective_rows = SafetyObjectiveSerializer(objectives[:6], many=True).data

        return Response({
            'generated_at': timezone.now(),
            'period_days': days,
            'sites': {
                'total': len(sites),
                'active': sum(1 for s in sites if s.is_active),
                'headcount': total_headcount,
                'hours_worked': total_hours,
            },
            'kpis': {
                'open_hazards': len(open_hazards),
                'high_risk_hazards': len(high_risk),
                'overdue_controls': len(overdue_controls),
                'incidents_period': period_incidents.count(),
                'incidents_previous': prev_incidents.count(),
                'open_incidents': open_incidents_qs.count(),
                'recordable': recordable.count(),
                'lost_time_injuries': lti.count(),
                'lost_days': lost_days,
                'trir': trir,
                'ltifr': ltifr,
                'severity_rate': severity_rate,
                'overdue_actions': len(overdue_actions),
                'open_actions': open_actions.count(),
                'inspections_due': inspections_due,
                'inspection_score': compliance_score,
                'permits_active': permits_active.count(),
                'permits_expiring': permits_expiring,
                'training_compliance_pct': training_pct,
                'training_expiring': training_expiring,
                'ppe_low_stock': ppe_low,
                'observations_period': period_obs.count(),
                'safe_ratio': _pct(safe_obs, period_obs.count()),
                'drills_due': drills_due,
                'avg_evacuation_seconds': avg_evac,
                'legal_non_compliant': legal_non_compliant,
                'legal_compliance_pct': legal_score,
                'audit_score': audit_score,
                'health_surveillance_due': health_due,
                'exposure_exceeded': exposure_exceeded,
                'open_objectives': open_objectives,
                'objectives_on_track': objectives_on_track,
            },
            'risk_matrix': {'matrix': matrix, 'by_level': risk_by_level},
            'incidents_trend': trend,
            'incidents_by_type': incidents_by_type,
            'hazards_by_category': hazards_by_category,
            'site_scorecard': scorecard,
            'action_queue': queue[:20],
            'recent_incidents': recent_incidents,
            'top_risks': top_risks,
            'training_courses': course_rows[:10],
            'compliance_breakdown': legal_breakdown,
            'exposure_summary': exposure_rows,
            'objectives': objective_rows,
        })


class OhsLookupsView(APIView):
    """Compact option lists used to populate forms across the OHS UI."""

    @tenant_cache('ohsms.dashboard', timeout=300)
    def get(self, request):
        sites = SiteSerializer(Site.objects.filter(is_active=True), many=True).data
        categories = HazardCategorySerializer(HazardCategory.objects.all(), many=True).data
        courses = TrainingCourseSerializer(TrainingCourse.objects.all(), many=True).data
        ppe = PpeItemSerializer(PpeItem.objects.all(), many=True).data
        return Response({
            'sites': sites,
            'hazard_categories': categories,
            'training_courses': courses,
            'ppe_items': ppe,
            'hazard_types': [{'value': v, 'label': l} for v, l in Hazard.HazardType.choices],
            'incident_types': [{'value': v, 'label': l} for v, l in Incident.IncidentType.choices],
            'severities': [{'value': v, 'label': l} for v, l in Incident.Severity.choices],
            'permit_types': [{'value': v, 'label': l} for v, l in PermitToWork.PermitType.choices],
            'control_hierarchy': [{'value': v, 'label': l} for v, l in ControlMeasure.Hierarchy.choices],
            'drill_types': [{'value': v, 'label': l} for v, l in EmergencyDrill.DrillType.choices],
            'agents': [{'value': v, 'label': l} for v, l in ExposureMonitoring.Agent.choices],
            'programmes': [{'value': v, 'label': l} for v, l in HealthSurveillance.Programme.choices],
            'observation_kinds': [{'value': v, 'label': l} for v, l in Observation.Kind.choices],
            'observation_categories': [{'value': v, 'label': l} for v, l in Observation.Category.choices],
            'legal_status': [{'value': v, 'label': l} for v, l in LegalRequirement.Status.choices],
            'audit_types': [{'value': v, 'label': l} for v, l in ComplianceAudit.AuditType.choices],
            'objective_categories': [{'value': v, 'label': l} for v, l in SafetyObjective.Category.choices],
            'doc_types': [{'value': v, 'label': l} for v, l in Document.DocType.choices],
            'doc_status': [{'value': v, 'label': l} for v, l in Document.Status.choices],
            'classifications': [{'value': v, 'label': l} for v, l in Document.Classification.choices],
            'trades': [{'value': v, 'label': l} for v, l in Contractor.Trade.choices],
            'contractor_status': [{'value': v, 'label': l} for v, l in Contractor.Status.choices],
            'risk_ratings': [{'value': v, 'label': l} for v, l in Contractor.RiskRating.choices],
            'meeting_types': [{'value': v, 'label': l} for v, l in SafetyMeeting.MeetingType.choices],
            'cert_types': [{'value': v, 'label': l} for v, l in Certification.CertType.choices],
            'cert_status': [{'value': v, 'label': l} for v, l in Certification.Status.choices],
            'review_outcomes': [{'value': v, 'label': l} for v, l in ManagementReview.Outcome.choices],
            'equipment_categories': [
                {'value': v, 'label': l} for v, l in SafetyEquipment.Category.choices
            ],
            'equipment_status': [
                {'value': v, 'label': l} for v, l in SafetyEquipment.Status.choices
            ],
            'equipment_criticality': [
                {'value': v, 'label': l} for v, l in SafetyEquipment.Criticality.choices
            ],
            'inspection_types': [
                {'value': v, 'label': l} for v, l in EquipmentInspection.InspectionType.choices
            ],
            'inspection_results': [
                {'value': v, 'label': l} for v, l in EquipmentInspection.Result.choices
            ],
            'defect_severities': [
                {'value': v, 'label': l} for v, l in EquipmentDefect.Severity.choices
            ],
            'defect_status': [
                {'value': v, 'label': l} for v, l in EquipmentDefect.Status.choices
            ],
            # ── Pre/post-employment assessment ──
            'assessment_kinds': [
                {'value': v, 'label': l} for v, l in HealthAssessment.Kind.choices
            ],
            'assessment_statuses': [
                {'value': v, 'label': l} for v, l in HealthAssessment.Status.choices
            ],
            'fitness_outcomes': [
                {'value': v, 'label': l} for v, l in HealthAssessment.Fitness.choices
            ],
            'exit_reasons': [
                {'value': v, 'label': l} for v, l in HealthAssessment.ExitReason.choices
            ],
            'finding_systems': [
                {'value': v, 'label': l} for v, l in AssessmentFinding.System.choices
            ],
            'finding_severities': [
                {'value': v, 'label': l} for v, l in AssessmentFinding.Severity.choices
            ],
            'lab_flags': [
                {'value': v, 'label': l} for v, l in AssessmentLabResult.Flag.choices
            ],
            'physical_demands': [
                {'value': v, 'label': l} for v, l in JobDemandProfile.PhysicalDemand.choices
            ],
            'sensory_standards': [
                {'value': v, 'label': l} for v, l in JobDemandProfile.SensoryStandard.choices
            ],
            'surveillance_tiers': [
                {'value': v, 'label': l} for v, l in JobDemandProfile.SurveillanceTier.choices
            ],
            'job_demands': JobDemandProfileSerializer(
                JobDemandProfile.objects.filter(is_active=True), many=True,
            ).data,
        })


# ─────────────────────────────────────────────────────────────────────────
#  Pre-employment & post-employment assessment
# ─────────────────────────────────────────────────────────────────────────
MEASURED_VITALS = (
    'height_cm', 'weight_kg', 'bp_systolic', 'bp_diastolic',
    'pulse', 'resp_rate', 'temperature_c', 'spo2', 'waist_cm',
)
MEASURED_HEARING = ('left_db', 'right_db')
MEASURED_SPIROMETRY = ('fev1_l', 'fvc_l', 'fev1_fvc_pct', 'predicted_pct')


class JobDemandProfileViewSet(OhsBaseViewSet):
    queryset = JobDemandProfile.objects.select_related('site')
    serializer_class = JobDemandProfileSerializer
    search_fields = ['code', 'job_title', 'department', 'inherent_requirements']
    filterset_fields = ['site', 'physical_demand', 'surveillance_tier', 'is_active']
    ordering_fields = ['job_title', 'department', 'physical_demand', 'created_at']


class AssessmentFindingViewSet(OhsBaseViewSet):
    queryset = AssessmentFinding.objects.select_related('assessment')
    serializer_class = AssessmentFindingSerializer
    search_fields = ['finding', 'recommendation']
    filterset_fields = ['assessment', 'system', 'severity', 'work_related']
    ordering_fields = ['system', 'severity', 'created_at']


class AssessmentLabResultViewSet(OhsBaseViewSet):
    queryset = AssessmentLabResult.objects.select_related('assessment')
    serializer_class = AssessmentLabResultSerializer
    search_fields = ['analyte', 'notes']
    filterset_fields = ['assessment', 'flag']
    ordering_fields = ['analyte', 'flag', 'created_at']


class HealthAssessmentViewSet(OhsBaseViewSet):
    queryset = HealthAssessment.objects.select_related(
        'site', 'job_demand', 'baseline',
    ).prefetch_related('findings', 'lab_results')
    serializer_class = HealthAssessmentSerializer
    list_serializer_class = HealthAssessmentListSerializer
    search_fields = ['reference', 'employee_name', 'employee_ref', 'job_title',
                     'department', 'examiner_name', 'provider', 'certificate_no']
    filterset_fields = ['kind', 'status', 'fitness', 'site', 'job_demand',
                        'work_related', 'compensation_claim']
    ordering_fields = ['reference', 'employee_name', 'scheduled_on', 'examined_on',
                       'valid_until', 'fitness', 'kind']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        params = self.request.query_params
        if params.get('overdue') in ('1', 'true'):
            qs = qs.filter(
                scheduled_on__lt=date.today(),
            ).exclude(status__in=['completed', 'certified', 'cancelled', 'declined'])
        if params.get('expiring') in ('1', 'true'):
            horizon = date.today() + timedelta(days=60)
            qs = qs.filter(valid_until__isnull=False, valid_until__lte=horizon)
        if params.get('needs_certificate') in ('1', 'true'):
            qs = qs.filter(status='completed', certificate_no='')
        return qs

    def perform_create(self, serializer):
        # An exit/periodic assessment defaults to the most recent
        # pre-employment record for the same employee, so the baseline
        # comparison works without the operator hunting for the reference.
        data = serializer.validated_data
        baseline = data.get('baseline')
        if not baseline and data.get('kind') in ('exit', 'periodic', 'return_to_work'):
            name = data.get('employee_name') or ''
            if name:
                baseline = (
                    HealthAssessment.objects
                    .filter(kind='pre_employment', employee_name__iexact=name)
                    .order_by('-scheduled_on').first()
                )
        serializer.save(baseline=baseline)

    # ── child rows ──
    @action(detail=True, methods=['post'], url_path='add-finding')
    def add_finding(self, request, pk=None):
        assessment = self.get_object()
        serializer = AssessmentFindingSerializer(
            data={**request.data, 'assessment': assessment.id},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        assessment.refresh_from_db()
        return Response(self.get_serializer(assessment).data, status=201)

    @action(detail=True, methods=['post'], url_path='add-lab-result')
    def add_lab_result(self, request, pk=None):
        assessment = self.get_object()
        serializer = AssessmentLabResultSerializer(
            data={**request.data, 'assessment': assessment.id},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        assessment.refresh_from_db()
        return Response(self.get_serializer(assessment).data, status=201)

    @action(detail=True, methods=['delete'], url_path=r'findings/(?P<finding_id>[^/.]+)')
    def delete_finding(self, request, pk=None, finding_id=None):
        assessment = self.get_object()
        assessment.findings.filter(id=finding_id).delete()
        return Response(self.get_serializer(assessment).data)

    @action(detail=True, methods=['delete'], url_path=r'lab-results/(?P<result_id>[^/.]+)')
    def delete_lab_result(self, request, pk=None, result_id=None):
        assessment = self.get_object()
        assessment.lab_results.filter(id=result_id).delete()
        return Response(self.get_serializer(assessment).data)

    # ── lifecycle ──
    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        """Record the clinical outcome and close the assessment.

        Sets the exam date, fitness decision and — when the role has a
        surveillance tier — the next statutory due date, so the register can
        chase it without anyone re-entering the interval.
        """
        assessment = self.get_object()
        payload = request.data or {}

        # JSON dates arrive as strings. Adding a timedelta to one raises
        # TypeError, so coerce once at the boundary instead of trusting the body.
        assessment.examined_on = (
            _as_date(payload.get('examined_on'))
            or assessment.examined_on
            or date.today()
        )
        if payload.get('fitness'):
            assessment.fitness = payload['fitness']
        if assessment.fitness == HealthAssessment.Fitness.PENDING:
            assessment.fitness = HealthAssessment.Fitness.FIT
        assessment.restrictions = payload.get('restrictions', assessment.restrictions)
        assessment.recommendations = payload.get('recommendations', assessment.recommendations)
        assessment.work_related = bool(payload.get('work_related', assessment.work_related))
        assessment.attributable_condition = payload.get(
            'attributable_condition', assessment.attributable_condition,
        )
        assessment.compensation_claim = bool(
            payload.get('compensation_claim', assessment.compensation_claim),
        )
        assessment.clearance_notes = payload.get('clearance_notes', assessment.clearance_notes)
        assessment.examiner_name = payload.get('examiner_name') or assessment.examiner_name
        assessment.status = HealthAssessment.Status.COMPLETED
        assessment.reviewed_by = payload.get('reviewed_by') or _actor_name(request)
        assessment.reviewed_at = timezone.now()

        interval = assessment.job_demand.review_interval_months if assessment.job_demand else None
        if interval:
            assessment.next_due = assessment.examined_on + timedelta(days=30 * interval)

        assessment.save()
        return Response(self.get_serializer(assessment).data)

    @action(detail=True, methods=['post'], url_path='issue-certificate')
    def issue_certificate(self, request, pk=None):
        """Issue the fitness certificate that the employee carries."""
        assessment = self.get_object()
        payload = request.data or {}
        issued = _as_date(payload.get('issued_on')) or date.today()

        months = payload.get('valid_months')
        try:
            months = int(months) if months else None
        except (TypeError, ValueError):
            months = None
        if not months and assessment.job_demand and assessment.job_demand.review_interval_months:
            months = assessment.job_demand.review_interval_months
        months = months or 12

        assessment.certificate_no = (
            payload.get('certificate_no')
            or f'{assessment.reference}/C'
        )
        assessment.issued_on = issued
        assessment.valid_until = issued + timedelta(days=30 * months)
        assessment.next_due = _as_date(payload.get('next_due')) or assessment.valid_until
        assessment.status = HealthAssessment.Status.CERTIFIED
        assessment.save()
        return Response(self.get_serializer(assessment).data)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        assessment = self.get_object()
        assessment.status = HealthAssessment.Status.CANCELLED
        assessment.notes = (request.data or {}).get('notes') or assessment.notes
        assessment.save(update_fields=['status', 'notes', 'updated_at'])
        return Response(self.get_serializer(assessment).data)

    @action(detail=True, methods=['get'])
    def baseline_comparison(self, request, pk=None):
        """Numeric drift between this assessment and its pre-employment baseline.

        This is the whole point of linking the two records: a raw exit value
        ("left ear 45 dB") only means something next to the value on the day
        the person was hired.
        """
        assessment = self.get_object()
        baseline = assessment.baseline
        if baseline is None:
            # Fall back to the earliest *other* pre-employment record for this
            # person. Excluding self matters: for a pre-employment record the
            # fallback would otherwise select the record being compared and
            # report a table of zero deltas, which reads as a clean bill of
            # health when nothing was compared at all.
            baseline = (
                HealthAssessment.objects
                .filter(kind='pre_employment', employee_name__iexact=assessment.employee_name)
                .exclude(pk=assessment.pk)
                .order_by('scheduled_on').first()
            )
        if baseline is None:
            return Response({
                'has_baseline': False,
                'assessment': self.get_serializer(assessment).data,
                'baseline': None,
                'deltas': [],
            })

        deltas = []

        def collect(group, keys, unit_map):
            current = getattr(assessment, group) or {}
            previous = getattr(baseline, group) or {}
            for key in keys:
                try:
                    now_v = float(current.get(key))
                    then_v = float(previous.get(key))
                except (TypeError, ValueError):
                    continue
                delta = round(now_v - then_v, 2)
                deltas.append({
                    'group': group,
                    'key': key,
                    'unit': unit_map.get(key, ''),
                    'baseline': then_v,
                    'current': now_v,
                    'delta': delta,
                    'direction': 'up' if delta > 0 else 'down' if delta < 0 else 'flat',
                })

        collect('vital_signs', MEASURED_VITALS, {
            'height_cm': 'cm', 'weight_kg': 'kg', 'bp_systolic': 'mmHg',
            'bp_diastolic': 'mmHg', 'pulse': 'bpm', 'resp_rate': '/min',
            'temperature_c': '°C', 'spo2': '%', 'waist_cm': 'cm',
        })
        collect('hearing', MEASURED_HEARING, {'left_db': 'dB', 'right_db': 'dB'})
        collect('spirometry', MEASURED_SPIROMETRY, {
            'fev1_l': 'L', 'fvc_l': 'L', 'fev1_fvc_pct': '%', 'predicted_pct': '%',
        })

        # Weight change is only meaningful alongside the BMI it produces.
        if assessment.bmi is not None and baseline.bmi is not None:
            deltas.append({
                'group': 'derived', 'key': 'bmi', 'unit': 'kg/m²',
                'baseline': baseline.bmi, 'current': assessment.bmi,
                'delta': round(assessment.bmi - baseline.bmi, 1),
                'direction': ('up' if assessment.bmi > baseline.bmi
                              else 'down' if assessment.bmi < baseline.bmi else 'flat'),
            })

        worsened_hearing = any(
            d['key'] in MEASURED_HEARING and d['delta'] >= 10 for d in deltas
        )

        return Response({
            'has_baseline': True,
            'baseline': {
                'id': baseline.id,
                'reference': baseline.reference,
                'examined_on': baseline.examined_on,
                'scheduled_on': baseline.scheduled_on,
                'fitness': baseline.fitness,
                'bmi': baseline.bmi,
            },
            'assessment': self.get_serializer(assessment).data,
            'deltas': deltas,
            'flags': {
                'hearing_shift': worsened_hearing,
                'bmi_change_significant': any(
                    d['key'] == 'bmi' and abs(d['delta']) >= 3 for d in deltas
                ),
            },
        })


class OhsAssessmentSummaryView(APIView):
    """KPI card + roll-ups for the assessment workspace (single call)."""

    @tenant_cache('ohsms.dashboard', timeout=60)
    def get(self, request):
        today = date.today()
        horizon = today + timedelta(days=60)
        qs = HealthAssessment.objects.all()

        by_kind = {k: 0 for k, _ in HealthAssessment.Kind.choices}
        for row in qs.values('kind').annotate(n=Count('id')):
            by_kind[row['kind']] = row['n']

        by_fitness = {f: 0 for f, _ in HealthAssessment.Fitness.choices}
        for row in qs.values('fitness').annotate(n=Count('id')):
            by_fitness[row['fitness']] = row['n']

        done_statuses = ['completed', 'certified']
        completed = qs.filter(status__in=done_statuses).count()

        overdue = qs.filter(scheduled_on__lt=today).exclude(
            status__in=['completed', 'certified', 'cancelled', 'declined'],
        ).count()

        expiring = qs.filter(
            valid_until__isnull=False,
            valid_until__gte=today,
            valid_until__lte=horizon,
        ).count()
        expired = qs.filter(valid_until__isnull=False, valid_until__lt=today).count()

        awaiting = qs.filter(status='completed', certificate_no='').count()

        work_related = qs.filter(work_related=True).count()
        claims = qs.filter(compensation_claim=True).count()

        # Site roll-up for the "where is the load" strip.
        sites = []
        for row in (qs.values('site__id', 'site__name').annotate(
                n=Count('id')).order_by('-n')[:8]):
            if not row['site__id']:
                continue
            sites.append({
                'id': row['site__id'],
                'name': row['site__name'],
                'count': row['n'],
            })

        # Fitness outcome mix restricted to assessments that reached an outcome.
        assessed = [k for k in by_fitness if k != 'pending']
        assessed_total = sum(by_fitness[k] for k in assessed) or 0
        fitness_mix = [
            {
                'value': k,
                'label': dict(HealthAssessment.Fitness.choices)[k],
                'count': by_fitness[k],
                'pct': round(by_fitness[k] / assessed_total * 100) if assessed_total else 0,
            }
            for k in assessed
        ]

        fit = by_fitness.get('fit', 0)
        restricted = by_fitness.get('fit_with_restrictions', 0)
        unfit = by_fitness.get('unfit', 0) + by_fitness.get('temporarily_unfit', 0)

        return Response({
            'total': qs.count(),
            'scheduled': qs.filter(status='scheduled').count(),
            'in_progress': qs.filter(status='in_progress').count(),
            'completed': completed,
            'overdue': overdue,
            'awaiting_certificate': awaiting,
            'expiring': expiring,
            'expired': expired,
            'work_related': work_related,
            'compensation_claims': claims,
            'fit': fit,
            'fit_with_restrictions': restricted,
            'unfit': unfit,
            'fit_rate': round(fit / assessed_total * 100) if assessed_total else 0,
            'by_kind': [{'value': k, 'label': v, 'count': by_kind[k]}
                        for k, v in HealthAssessment.Kind.choices],
            'by_fitness': fitness_mix,
            'sites': sites,
            'job_profiles': JobDemandProfile.objects.filter(is_active=True).count(),
            'generated_at': timezone.now().isoformat(),
        })


# ─────────────────────────────────────────────────────────────────────────
#  Document control & SDS
# ─────────────────────────────────────────────────────────────────────────
class DocumentViewSet(OhsBaseViewSet):
    queryset = Document.objects.select_related('site').prefetch_related(
        'revisions', 'acknowledgements',
    )
    serializer_class = DocumentSerializer
    list_serializer_class = DocumentListSerializer
    search_fields = ['reference', 'title', 'summary', 'owner_name', 'chemical_name',
                     'hazard_class', 'tags']
    filterset_fields = ['doc_type', 'status', 'classification', 'site']
    ordering_fields = ['reference', 'title', 'effective_date', 'review_due', 'updated_at']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        if p.get('review_overdue') in ('1', 'true'):
            qs = qs.filter(review_due__lt=date.today()).exclude(
                status__in=['draft', 'obsolete'],
            )
        if p.get('sds_only') in ('1', 'true'):
            qs = qs.filter(doc_type='sds')
        return qs

    @action(detail=True, methods=['post'])
    def add_revision(self, request, pk=None):
        document = self.get_object()
        payload = dict(request.data, document=document.id)
        serializer = DocumentRevisionSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        document.version = payload.get('version') or document.version
        document.revision_count = (document.revision_count or 1) + 1
        document.save(update_fields=['version', 'revision_count', 'updated_at'])
        return Response(self.get_serializer(document).data, status=201)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        document = self.get_object()
        document.status = Document.Status.APPROVED
        document.approved_by = request.data.get('approved_by') or _actor_name(request)
        document.approved_at = timezone.now()
        document.effective_date = request.data.get('effective_date') or date.today()
        document.save()
        return Response(self.get_serializer(document).data)

    @action(detail=True, methods=['post'])
    def acknowledge(self, request, pk=None):
        document = self.get_object()
        payload = dict(request.data, document=document.id)
        payload.setdefault('version_read', document.version)
        serializer = DocumentAcknowledgementSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=201)


class DocumentRevisionViewSet(OhsBaseViewSet):
    queryset = DocumentRevision.objects.select_related('document')
    serializer_class = DocumentRevisionSerializer
    filterset_fields = ['document']
    ordering = ['-revised_on']


class DocumentAcknowledgementViewSet(OhsBaseViewSet):
    queryset = DocumentAcknowledgement.objects.select_related('document', 'site')
    serializer_class = DocumentAcknowledgementSerializer
    search_fields = ['employee_name', 'employee_ref', 'document__title']
    filterset_fields = ['document', 'site']
    ordering = ['-acknowledged_on']


# ─────────────────────────────────────────────────────────────────────────
#  Contractor safety management
# ─────────────────────────────────────────────────────────────────────────
class ContractorViewSet(OhsBaseViewSet):
    queryset = Contractor.objects.prefetch_related('engagements')
    serializer_class = ContractorSerializer
    list_serializer_class = ContractorListSerializer
    search_fields = ['name', 'registration_no', 'contact_person', 'email']
    filterset_fields = ['trade', 'status', 'risk_rating']
    ordering_fields = ['name', 'performance_score', 'expired_documents']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        if p.get('non_compliant') in ('1', 'true'):
            today = date.today()
            qs = qs.filter(
                Q(insurance_expiry__lt=today)
                | Q(safety_file_expiry__lt=today)
                | Q(induction_valid_until__lt=today)
                | Q(licence_expiry__lt=today)
            )
        if p.get('expiring'):
            today = date.today()
            horizon = today + timedelta(days=30)
            qs = qs.filter(
                Q(insurance_expiry__gte=today, insurance_expiry__lte=horizon)
                | Q(safety_file_expiry__gte=today, safety_file_expiry__lte=horizon)
                | Q(induction_valid_until__gte=today, induction_valid_until__lte=horizon)
                | Q(licence_expiry__gte=today, licence_expiry__lte=horizon)
            )
        return qs


class ContractorEngagementViewSet(OhsBaseViewSet):
    queryset = ContractorEngagement.objects.select_related('contractor', 'site')
    serializer_class = ContractorEngagementSerializer
    search_fields = ['scope', 'supervisor_name', 'contractor__name']
    filterset_fields = ['contractor', 'site', 'status']
    ordering = ['-start_date']


# ─────────────────────────────────────────────────────────────────────────
#  Safety meetings
# ─────────────────────────────────────────────────────────────────────────
class SafetyMeetingViewSet(OhsBaseViewSet):
    queryset = SafetyMeeting.objects.select_related('site').prefetch_related('attendance')
    serializer_class = SafetyMeetingSerializer
    list_serializer_class = SafetyMeetingListSerializer
    search_fields = ['title', 'chairperson', 'location', 'topics_covered', 'minutes']
    filterset_fields = ['meeting_type', 'status', 'site']
    ordering_fields = ['meeting_date', 'attendees_count']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        if self.request.query_params.get('overdue') in ('1', 'true'):
            qs = qs.filter(status='scheduled', meeting_date__lt=date.today())
        return qs

    @action(detail=True, methods=['post'])
    def add_attendee(self, request, pk=None):
        meeting = self.get_object()
        payload = dict(request.data, meeting=meeting.id)
        serializer = MeetingAttendanceSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        meeting.attendees_count = meeting.attendance.count()
        meeting.save(update_fields=['attendees_count', 'updated_at'])
        return Response(self.get_serializer(meeting).data, status=201)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        meeting = self.get_object()
        meeting.status = SafetyMeeting.Status.COMPLETED
        for field in ('minutes', 'decisions', 'topics_covered'):
            if request.data.get(field):
                setattr(meeting, field, request.data[field])
        meeting.save()
        return Response(self.get_serializer(meeting).data)


class MeetingAttendanceViewSet(OhsBaseViewSet):
    queryset = MeetingAttendance.objects.select_related('meeting')
    serializer_class = MeetingAttendanceSerializer
    search_fields = ['employee_name', 'employee_ref', 'role']
    filterset_fields = ['meeting', 'present']


# ─────────────────────────────────────────────────────────────────────────
#  Management reviews
# ─────────────────────────────────────────────────────────────────────────
class ManagementReviewViewSet(OhsBaseViewSet):
    queryset = ManagementReview.objects.all()
    serializer_class = ManagementReviewSerializer
    search_fields = ['reference', 'title', 'chairperson', 'participants', 'decisions']
    filterset_fields = ['status', 'outcome']
    ordering_fields = ['review_date', 'next_review_on']

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        review = self.get_object()
        review.status = ManagementReview.Status.COMPLETED
        for field in ('outputs', 'decisions', 'outcome', 'next_review_on'):
            if request.data.get(field):
                setattr(review, field, request.data[field])
        if not review.kpi_snapshot:
            review.kpi_snapshot = _kpi_snapshot()
        review.save()
        return Response(self.get_serializer(review).data)


# ─────────────────────────────────────────────────────────────────────────
#  Certifications
# ─────────────────────────────────────────────────────────────────────────
class CertificationViewSet(OhsBaseViewSet):
    queryset = Certification.objects.select_related('site')
    serializer_class = CertificationSerializer
    search_fields = ['name', 'reference_no', 'issuing_body', 'holder_name']
    filterset_fields = ['cert_type', 'status', 'site']
    ordering_fields = ['expires_on', 'name']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        today = date.today()
        if p.get('expired') in ('1', 'true'):
            qs = qs.filter(expires_on__lt=today)
        if p.get('expiring'):
            try:
                days = int(p['expiring'])
            except (TypeError, ValueError):
                days = 60
            qs = qs.filter(expires_on__gte=today, expires_on__lte=today + timedelta(days=days))
        return qs


# ─────────────────────────────────────────────────────────────────────────
#  Safety equipment management
# ─────────────────────────────────────────────────────────────────────────
EQUIPMENT_OPEN_DEFECTS = ['open', 'in_progress', 'awaiting_parts']


class SafetyEquipmentViewSet(OhsBaseViewSet):
    queryset = SafetyEquipment.objects.select_related('site').prefetch_related(
        'inspections', 'defects',
    )
    serializer_class = SafetyEquipmentSerializer
    list_serializer_class = SafetyEquipmentListSerializer
    search_fields = ['reference', 'name', 'asset_tag', 'serial_number', 'manufacturer',
                     'model', 'location', 'department', 'custodian', 'standard']
    filterset_fields = ['category', 'status', 'criticality', 'site', 'requires_calibration']
    ordering_fields = ['reference', 'name', 'next_inspection_on', 'next_calibration_on',
                       'acquired_on', 'created_at']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        today = date.today()
        if p.get('inspection_overdue') in ('1', 'true'):
            qs = qs.filter(requires_inspection=True, next_inspection_on__lt=today).exclude(
                status='decommissioned',
            )
        if p.get('calibration_overdue') in ('1', 'true'):
            qs = qs.filter(requires_calibration=True, next_calibration_on__lt=today)
        if p.get('due') in ('1', 'true'):
            horizon = today + timedelta(days=14)
            qs = qs.filter(next_inspection_on__lte=horizon).exclude(status='decommissioned')
        if p.get('with_defects') in ('1', 'true'):
            qs = qs.filter(defects__status__in=EQUIPMENT_OPEN_DEFECTS).distinct()
        if p.get('in_service') in ('1', 'true'):
            qs = qs.filter(status='in_service')
        return qs

    @action(detail=True, methods=['post'])
    def record_inspection(self, request, pk=None):
        """Log an inspection/calibration and roll the dates onto the asset."""
        equipment = self.get_object()
        payload = dict(request.data, equipment=equipment.id)
        serializer = EquipmentInspectionSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        inspection = serializer.save()
        if inspection.result == EquipmentInspection.Result.FAIL:
            equipment.status = SafetyEquipment.Status.OUT_OF_SERVICE
            equipment.save(update_fields=['status', 'updated_at'])
        equipment.refresh_from_db()
        return Response({
            'inspection': EquipmentInspectionSerializer(inspection).data,
            'equipment': self.get_serializer(equipment).data,
        }, status=201)

    @action(detail=True, methods=['post'])
    def report_defect(self, request, pk=None):
        equipment = self.get_object()
        payload = dict(request.data, equipment=equipment.id)
        serializer = EquipmentDefectSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        defect = serializer.save()
        if defect.severity == EquipmentDefect.Severity.CRITICAL:
            equipment.status = SafetyEquipment.Status.OUT_OF_SERVICE
            equipment.save(update_fields=['status', 'updated_at'])
        equipment.refresh_from_db()   # clears the prefetched defects cache
        return Response({
            'defect': EquipmentDefectSerializer(defect).data,
            'equipment': self.get_serializer(equipment).data,
        }, status=201)

    @action(detail=True, methods=['post'])
    def set_status(self, request, pk=None):
        equipment = self.get_object()
        status = request.data.get('status')
        valid = {c[0] for c in SafetyEquipment.Status.choices}
        if status not in valid:
            return Response({'detail': f'status must be one of {sorted(valid)}'}, status=400)
        equipment.status = status
        equipment.save(update_fields=['status', 'updated_at'])
        return Response(self.get_serializer(equipment).data)


class EquipmentInspectionViewSet(OhsBaseViewSet):
    queryset = EquipmentInspection.objects.select_related('equipment')
    serializer_class = EquipmentInspectionSerializer
    search_fields = ['performed_by', 'provider', 'findings', 'action_taken',
                     'equipment__name', 'equipment__reference']
    filterset_fields = ['equipment', 'inspection_type', 'result']
    ordering_fields = ['performed_on', 'next_due', 'cost']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        if self.request.query_params.get('failed') in ('1', 'true'):
            qs = qs.filter(result='fail')
        return qs


class EquipmentDefectViewSet(OhsBaseViewSet):
    queryset = EquipmentDefect.objects.select_related('equipment')
    serializer_class = EquipmentDefectSerializer
    search_fields = ['work_order', 'description', 'reported_by', 'resolution',
                     'equipment__name', 'equipment__reference']
    filterset_fields = ['equipment', 'severity', 'status']
    ordering_fields = ['reported_on', 'severity', 'repair_cost']

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        if self.request.query_params.get('open') in ('1', 'true'):
            qs = qs.filter(status__in=EQUIPMENT_OPEN_DEFECTS)
        return qs

    @action(detail=True, methods=['post'])
    def resolve(self, request, pk=None):
        defect = self.get_object()
        defect.status = EquipmentDefect.Status.RESOLVED
        defect.resolved_on = request.data.get('resolved_on') or date.today()
        defect.resolved_by = request.data.get('resolved_by') or _actor_name(request)
        defect.resolution = request.data.get('resolution', defect.resolution)
        defect.downtime_hours = request.data.get('downtime_hours', defect.downtime_hours)
        defect.repair_cost = request.data.get('repair_cost', defect.repair_cost)
        defect.save()
        return Response(EquipmentDefectSerializer(defect).data)


class OhsEquipmentSummaryView(APIView):
    """Fleet-level KPIs and breakdowns for the equipment register page."""

    @tenant_cache('ohsms.dashboard', timeout=60)
    def get(self, request):
        today = date.today()
        qs = SafetyEquipment.objects.prefetch_related('defects')
        items = list(qs)

        def count(pred):
            return sum(1 for e in items if pred(e))

        in_service = count(lambda e: e.status == 'in_service')
        overdue = count(lambda e: e.is_inspection_overdue)
        due_soon = count(lambda e: e.is_inspection_due_soon and not e.is_inspection_overdue)
        cal_overdue = count(lambda e: e.is_calibration_overdue)
        out_of_service = count(lambda e: e.status in ('out_of_service', 'quarantine'))
        end_of_life = count(lambda e: e.is_end_of_life)
        open_defects = EquipmentDefect.objects.filter(
            status__in=EQUIPMENT_OPEN_DEFECTS,
        ).count()

        monitored = [e for e in items if e.requires_inspection or e.requires_calibration]
        compliant = count(lambda e: e.compliance_state in ('ok', 'due'))
        currency_pct = round(compliant / len(monitored) * 100) if monitored else 100
        avg_health = round(sum(e.health_score for e in items) / len(items)) if items else 100

        # Category breakdown
        by_category = []
        for key, label in SafetyEquipment.Category.choices:
            group = [e for e in items if e.category == key]
            if not group:
                continue
            by_category.append({
                'key': key, 'label': label, 'total': len(group),
                'overdue': sum(1 for e in group if e.compliance_state == 'overdue'),
                'out_of_service': sum(
                    1 for e in group if e.status in ('out_of_service', 'quarantine')
                ),
                'health': round(sum(e.health_score for e in group) / len(group)),
            })
        by_category.sort(key=lambda r: r['total'], reverse=True)

        # Site breakdown
        by_site = []
        for s in Site.objects.all():
            group = [e for e in items if e.site_id == s.id]
            if not group:
                continue
            by_site.append({
                'id': s.id, 'name': s.name, 'total': len(group),
                'overdue': sum(1 for e in group if e.compliance_state == 'overdue'),
                'defects': sum(1 for e in group if e.open_defects),
            })
        by_site.sort(key=lambda r: r['total'], reverse=True)

        # Critical items needing attention right now
        attention = sorted(
            [e for e in items if e.compliance_state in ('overdue', 'out_of_service')],
            key=lambda e: (e.health_score, e.next_inspection_on or today),
        )[:8]

        # 12-month defect trend
        trend = []
        for i in range(11, -1, -1):
            year = today.year
            month = today.month - i
            while month <= 0:
                month += 12
                year -= 1
            start = date(year, month, 1)
            end = date(year + (month == 12), (month % 12) + 1, 1)
            raised = EquipmentDefect.objects.filter(
                reported_on__gte=start, reported_on__lt=end,
            ).count()
            closed = EquipmentDefect.objects.filter(
                resolved_on__gte=start, resolved_on__lt=end,
            ).count()
            trend.append({
                'month': f'{month_abbr[month]} {str(year)[2:]}',
                'raised': raised, 'closed': closed,
            })

        return Response({
            'generated_at': timezone.now(),
            'kpis': {
                'total': len(items),
                'in_service': in_service,
                'overdue': overdue,
                'due_soon': due_soon,
                'calibration_overdue': cal_overdue,
                'out_of_service': out_of_service,
                'open_defects': open_defects,
                'end_of_life': end_of_life,
                'currency_pct': currency_pct,
                'avg_health': avg_health,
            },
            'by_category': by_category,
            'by_site': by_site,
            'attention': [
                {
                    'id': e.id, 'reference': e.reference, 'name': e.name,
                    'category': e.get_category_display(), 'site_name': e.site.name if e.site_id else '',
                    'status': e.status, 'compliance_state': e.compliance_state,
                    'health_score': e.health_score,
                    'next_inspection_on': e.next_inspection_on,
                    'days_to_inspection': e.days_to_inspection,
                }
                for e in attention
            ],
            'trend': trend,
        })


# ─────────────────────────────────────────────────────────────────────────
#  Shared KPI snapshot (used by reviews + intelligence)
# ─────────────────────────────────────────────────────────────────────────
def _kpi_snapshot():
    today = date.today()
    since = timezone.now() - timedelta(days=365)
    sites = list(Site.objects.all())
    hours = sum(s.hours_worked for s in sites) or 1
    incidents = Incident.objects.filter(occurred_at__gte=since)
    lti = incidents.filter(is_lost_time=True)
    recordable = incidents.filter(is_recordable=True)
    hazards = Hazard.objects.exclude(status='closed')
    return {
        'captured_at': timezone.now().isoformat(),
        'trir': round(recordable.count() * 200000 / hours, 2),
        'ltifr': round(lti.count() * 1000000 / hours, 2),
        'open_hazards': hazards.count(),
        'high_risk_hazards': sum(1 for h in hazards if (h.risk_score or 0) >= 15),
        'incidents_12m': incidents.count(),
        'lost_days': lti.aggregate(v=Sum('lost_days'))['v'] or 0,
        'training_compliance_pct': _training_currency(),
        'legal_compliance_pct': _legal_compliance(),
        'inspections_completed': Inspection.objects.filter(status='completed').count(),
        'permits_active': PermitToWork.objects.filter(status__in=['approved', 'active']).count(),
        'contractors_approved': Contractor.objects.filter(status='approved').count(),
        'certifications_expiring': Certification.objects.filter(
            expires_on__gte=today, expires_on__lte=today + timedelta(days=60),
        ).count(),
    }


def _training_currency():
    records = TrainingRecord.objects.filter(course__is_mandatory=True).exclude(result='fail')
    total = records.count()
    if not total:
        return 100.0
    valid = sum(1 for r in records if not r.is_expired)
    return round(valid / total * 100, 1)


def _legal_compliance():
    rows = list(LegalRequirement.objects.values_list('compliance_status', flat=True))
    if not rows:
        return 100.0
    score = sum(1 if s == 'compliant' else 0.5 if s == 'partial' else 0 for s in rows)
    return round(score / len(rows) * 100, 1)


# ─────────────────────────────────────────────────────────────────────────
#  Safety intelligence (leading/lagging indicators, cost of risk, forecast)
# ─────────────────────────────────────────────────────────────────────────
class OhsIntelligenceView(APIView):
    """Advanced analytics: leading vs lagging indicators, cost of risk,
    benchmarking, forecasting and compliance heat maps."""

    @tenant_cache('ohsms.dashboard', timeout=120)
    def get(self, request):
        today = date.today()
        since_12 = timezone.now() - timedelta(days=365)
        since_prev = since_12 - timedelta(days=365)

        sites = list(Site.objects.all())
        hours = sum(s.hours_worked for s in sites) or 1
        headcount = sum(s.headcount for s in sites) or 1

        incidents = Incident.objects.all()
        cur = incidents.filter(occurred_at__gte=since_12)
        prev = incidents.filter(occurred_at__gte=since_prev, occurred_at__lt=since_12)

        # ── Lagging indicators ────────────────────────────────────────
        def rate(qs, per=200000):
            return round(qs.count() * per / hours, 2)

        lagging = {
            'trir': rate(cur.filter(is_recordable=True)),
            'trir_prev': rate(prev.filter(is_recordable=True)),
            'ltifr': rate(cur.filter(is_lost_time=True), 1000000),
            'ltifr_prev': rate(prev.filter(is_lost_time=True), 1000000),
            'recordable': cur.filter(is_recordable=True).count(),
            'lti': cur.filter(is_lost_time=True).count(),
            'near_miss': cur.filter(incident_type='near_miss').count(),
            'lost_days': cur.filter(is_lost_time=True).aggregate(v=Sum('lost_days'))['v'] or 0,
            'total_incidents': cur.count(),
            'total_incidents_prev': prev.count(),
        }
        lagging['near_miss_ratio'] = round(
            lagging['near_miss'] / max(lagging['total_incidents'], 1) * 100, 1,
        )

        # ── Leading indicators ────────────────────────────────────────
        obs = Observation.objects.filter(observed_at__gte=since_12)
        safe_obs = obs.filter(kind__in=['safe', 'positive']).count()
        inspections = Inspection.objects.filter(status='completed', score__isnull=False)
        insp_score = (
            round(sum(i.score for i in inspections) / inspections.count(), 1)
            if inspections.exists() else 0
        )
        controls = list(ControlMeasure.objects.all())
        controls_closed = sum(1 for c in controls if c.status in ('implemented', 'verified'))
        meetings = SafetyMeeting.objects.filter(status='completed', meeting_date__gte=since_12.date())
        toolbox_count = meetings.filter(meeting_type__in=['toolbox', 'pre_job', 'induction']).count()
        contractors = list(Contractor.objects.all())
        approved_contractors = sum(1 for c in contractors if c.status == 'approved')

        leading = {
            'observations': obs.count(),
            'safe_ratio': round(safe_obs / max(obs.count(), 1) * 100, 1),
            'observations_per_100_workers': round(obs.count() / headcount * 100, 1),
            'inspections_completed': inspections.count(),
            'inspection_score': insp_score,
            'controls_implemented_pct': round(
                controls_closed / max(len(controls), 1) * 100, 1,
            ),
            'toolbox_talks': toolbox_count,
            'training_currency_pct': _training_currency(),
            'hazard_reports': Hazard.objects.count(),
            'hazard_close_rate': round(
                (Hazard.objects.count() - Hazard.objects.exclude(status='closed').count())
                / max(Hazard.objects.count(), 1) * 100, 1,
            ),
            'contractors_approved_pct': round(
                approved_contractors / max(len(contractors), 1) * 100, 1,
            ),
            'permits_closed_clean': round(
                PermitToWork.objects.filter(status='closed').count()
                / max(PermitToWork.objects.count(), 1) * 100, 1,
            ),
            'legal_compliance_pct': _legal_compliance(),
        }

        # ── Cost of risk (direct + indirect iceberg model) ────────────
        direct = float(
            cur.aggregate(v=Sum('cost_estimate'))['v'] or 0
        )
        # Indirect costs typically 3–5× direct (Heinrich/Bird). Use 4×.
        indirect = direct * 4
        avg_cost = round(direct / max(cur.count(), 1), 2)
        cost_by_type = []
        type_labels = dict(Incident.IncidentType.choices)
        for row in cur.values('incident_type').annotate(
            count=Count('id'), cost=Sum('cost_estimate'),
        ).order_by('-cost'):
            cost_by_type.append({
                'key': row['incident_type'],
                'label': type_labels.get(row['incident_type'], row['incident_type']),
                'count': row['count'],
                'direct': float(row['cost'] or 0),
                'loaded': float(row['cost'] or 0) * 5,
            })
        cost_by_site = []
        for s in sites:
            site_cost = float(
                cur.filter(site=s).aggregate(v=Sum('cost_estimate'))['v'] or 0
            )
            if not site_cost:
                continue
            cost_by_site.append({
                'id': s.id, 'name': s.name, 'headcount': s.headcount,
                'direct': site_cost, 'loaded': site_cost * 5,
                'per_worker': round(site_cost / max(s.headcount, 1), 2),
            })
        cost_by_site.sort(key=lambda r: -r['loaded'])
        cost_of_risk = {
            'direct': direct,
            'indirect': indirect,
            'loaded': direct + indirect,
            'avg_per_incident': avg_cost,
            'per_worker': round(direct / headcount, 2),
            'per_200k_hours': round(direct / hours * 200000, 2),
            'by_type': cost_by_type,
            'by_site': cost_by_site,
            'premium_saving_potential': round((direct + indirect) * 0.12, 2),
        }

        # ── 12-month trend with 3-month moving average + forecast ─────
        months = _month_windows(12)
        trend = []
        for start in months:
            end = (start + timedelta(days=32)).replace(day=1)
            bucket = incidents.filter(occurred_at__date__gte=start, occurred_at__date__lt=end)
            trend.append({
                'label': _month_label(start),
                'key': _month_key(start),
                'incidents': bucket.count(),
                'lti': bucket.filter(is_lost_time=True).count(),
                'near_miss': bucket.filter(incident_type='near_miss').count(),
                'observations': Observation.objects.filter(
                    observed_at__date__gte=start, observed_at__date__lt=end,
                ).count(),
            })
        for i, row in enumerate(trend):
            window = trend[max(0, i - 2):i + 1]
            row['ma3'] = round(sum(w['incidents'] for w in window) / len(window), 2)
        # Simple linear-regression forecast of the next 3 months
        n = len(trend)
        xs = list(range(n))
        ys = [r['incidents'] for r in trend]
        if n > 1:
            mean_x = sum(xs) / n
            mean_y = sum(ys) / n
            denom = sum((x - mean_x) ** 2 for x in xs) or 1
            slope = sum((xs[i] - mean_x) * (ys[i] - mean_y) for i in range(n)) / denom
            intercept = mean_y - slope * mean_x
        else:
            slope, intercept = 0, (ys[0] if ys else 0)
        forecast = []
        cursor = (months[-1] + timedelta(days=32)).replace(day=1) if months else today
        for k in range(1, 4):
            forecast.append({
                'label': _month_label(cursor),
                'predicted': max(0, round(intercept + slope * (n - 1 + k), 1)),
            })
            cursor = (cursor + timedelta(days=32)).replace(day=1)

        # ── Site benchmarking (normalised) ────────────────────────────
        benchmark = []
        for s in sites:
            site_inc = incidents.filter(site=s, occurred_at__gte=since_12)
            site_hours = s.hours_worked or 1
            site_hrs_inc = site_inc.filter(is_recordable=True).count()
            trir = round(site_hrs_inc * 200000 / site_hours, 2)
            benchmark.append({
                'id': s.id, 'name': s.name, 'headcount': s.headcount,
                'risk_profile': s.risk_profile,
                'trir': trir,
                'ltifr': round(site_inc.filter(is_lost_time=True).count() * 1000000 / site_hours, 2),
                'incidents': site_inc.count(),
                'observations': obs.filter(site=s).count(),
                'hazard_close_rate': round(
                    (Hazard.objects.filter(site=s).count()
                     - Hazard.objects.filter(site=s).exclude(status='closed').count())
                    / max(Hazard.objects.filter(site=s).count(), 1) * 100, 1,
                ),
                'compliance_pct': round(
                    (LegalRequirement.objects.filter(compliance_status='compliant').count()
                     + 0.5 * LegalRequirement.objects.filter(compliance_status='partial').count())
                    / max(LegalRequirement.objects.count(), 1) * 100, 1,
                ) if LegalRequirement.objects.exists() else 0,
            })
        benchmark.sort(key=lambda r: r['trir'])

        # ── Clause-level compliance heat map (ISO 45001) ──────────────
        clause_map = {
            '4. Context of the organisation': ['4.1', '4.2', '4.3', '4.4'],
            '5. Leadership & worker participation': ['5.1', '5.2', '5.3', '5.4'],
            '6. Planning': ['6.1.1', '6.1.2', '6.1.3', '6.1.4', '6.2'],
            '7. Support': ['7.1', '7.2', '7.3', '7.4', '7.5'],
            '8. Operation': ['8.1.1', '8.1.2', '8.1.3', '8.1.4', '8.2'],
            '9. Performance evaluation': ['9.1', '9.2', '9.3'],
            '10. Improvement': ['10.1', '10.2', '10.3'],
        }
        legal_rows = list(LegalRequirement.objects.values('clause', 'compliance_status'))
        clause_heat = []
        for label, prefixes in clause_map.items():
            matched = [
                r for r in legal_rows
                if any(str(r['clause'] or '').startswith(p) for p in prefixes)
            ]
            if matched:
                score = sum(
                    1 if r['compliance_status'] == 'compliant'
                    else 0.5 if r['compliance_status'] == 'partial' else 0
                    for r in matched
                ) / len(matched) * 100
            else:
                score = None
            clause_heat.append({
                'clause': label,
                'requirements': len(matched),
                'score': round(score, 1) if score is not None else None,
            })

        # ── Emerging risk signals ────────────────────────────────────
        signals = []
        hazards = Hazard.objects.exclude(status='closed')
        high = [h for h in hazards if (h.risk_score or 0) >= 15]
        if high:
            signals.append({
                'severity': 'high', 'kind': 'risk',
                'title': f'{len(high)} high/critical hazards remain open',
                'detail': 'Review control effectiveness and re-score residual risk.',
                'href': '/ohs/hazards',
            })
        overdue_controls = [c for c in controls if c.is_overdue]
        if overdue_controls:
            signals.append({
                'severity': 'high', 'kind': 'control',
                'title': f'{len(overdue_controls)} control measures are past due',
                'detail': 'Controls not implemented in time leave workers exposed.',
                'href': '/ohs/hazards',
            })
        expiring_certs = Certification.objects.filter(
            expires_on__gte=today, expires_on__lte=today + timedelta(days=60),
        ).count()
        if expiring_certs:
            signals.append({
                'severity': 'medium', 'kind': 'certification',
                'title': f'{expiring_certs} certifications expire within 60 days',
                'detail': 'Renew to avoid regulatory non-compliance.',
                'href': '/ohs/certifications',
            })
        bad_contractors = [c for c in contractors if c.expired_documents]
        if bad_contractors:
            signals.append({
                'severity': 'high', 'kind': 'contractor',
                'title': f'{len(bad_contractors)} contractors have expired documents',
                'detail': 'Suspend site access until documents are renewed.',
                'href': '/ohs/contractors',
            })
        if lagging['trir'] > lagging['trir_prev'] and lagging['trir_prev'] > 0:
            signals.append({
                'severity': 'high', 'kind': 'trend',
                'title': 'TRIR is rising year on year',
                'detail': f'{lagging["trir"]} vs {lagging["trir_prev"]} previously.',
                'href': '/ohs/incidents',
            })
        if obs.count() and safe_obs / max(obs.count(), 1) < 0.6:
            signals.append({
                'severity': 'medium', 'kind': 'culture',
                'title': 'Safe behaviour ratio below 60%',
                'detail': 'Increase positive reinforcement and coaching quality.',
                'href': '/ohs/observations',
            })
        signals.sort(key=lambda r: 0 if r['severity'] == 'high' else 1)

        # ── Maturity score (world-class index) ───────────────────────
        maturity_parts = {
            'risk_management': min(leading['hazard_close_rate'], 100),
            'compliance': leading['legal_compliance_pct'],
            'competence': leading['training_currency_pct'],
            'assurance': min(leading['inspection_score'], 100),
            'culture': leading['safe_ratio'],
            'control_implementation': leading['controls_implemented_pct'],
        }
        maturity_score = round(sum(maturity_parts.values()) / len(maturity_parts), 1)
        if maturity_score >= 90:
            maturity_level = 'World class'
        elif maturity_score >= 78:
            maturity_level = 'Proactive'
        elif maturity_score >= 62:
            maturity_level = 'Managed'
        elif maturity_score >= 45:
            maturity_level = 'Developing'
        else:
            maturity_level = 'Reactive'

        return Response({
            'generated_at': timezone.now(),
            'sites': {'total': len(sites), 'headcount': headcount, 'hours': hours},
            'lagging': lagging,
            'leading': leading,
            'cost_of_risk': cost_of_risk,
            'trend': trend,
            'forecast': forecast,
            'benchmark': benchmark,
            'clause_heatmap': clause_heat,
            'signals': signals[:8],
            'maturity': {
                'score': maturity_score,
                'level': maturity_level,
                'parts': [{'key': k, 'label': k.replace('_', ' ').title(), 'score': round(v, 1)}
                          for k, v in maturity_parts.items()],
            },
        })


# ─────────────────────────────────────────────────────────────────────────
#  Alert centre — a single derived feed of everything needing attention
# ─────────────────────────────────────────────────────────────────────────
class OhsAlertsView(APIView):
    @tenant_cache('ohsms.dashboard', timeout=60)
    def get(self, request):
        today = date.today()
        now = timezone.now()
        alerts = []

        def push(severity, category, title, detail, href, due=None, owner=''):
            alerts.append({
                'id': f'{category}-{len(alerts)}',
                'severity': severity, 'category': category,
                'title': title, 'detail': detail, 'href': href,
                'due': due.isoformat() if due else None,
                'owner': owner,
            })

        for c in ControlMeasure.objects.select_related('hazard'):
            if c.is_overdue:
                push('high', 'control', f'Control overdue — {c.hazard.reference}',
                     c.description[:140], '/ohs/hazards', c.due_date, c.owner_name)

        for a in IncidentAction.objects.select_related('incident'):
            if a.is_overdue:
                push('high', 'capa', f'CAPA overdue — {a.incident.reference}',
                     a.description[:140], '/ohs/incidents', a.due_date, a.owner_name)

        for i in Inspection.objects.filter(status__in=['scheduled', 'overdue'],
                                           scheduled_for__lt=today):
            push('medium', 'inspection', f'Inspection overdue — {i.reference}',
                 i.title, '/ohs/inspections', i.scheduled_for, i.inspector_name)

        for p in PermitToWork.objects.filter(
            status__in=['approved', 'active'], valid_to__isnull=False, valid_to__lt=now,
        ):
            push('high', 'permit', f'Permit expired — {p.reference}',
                 p.title, '/ohs/permits', p.valid_to.date(), p.issued_by)

        for r in TrainingRecord.objects.select_related('course').filter(expires_on__lt=today):
            if r.result == 'fail':
                continue
            push('medium', 'training', f'Certificate expired — {r.employee_name}',
                 f'{r.course.name} expired {r.expires_on}', '/ohs/training',
                 r.expires_on, r.employee_name)

        for c in Certification.objects.filter(expires_on__isnull=False):
            if c.is_expired:
                push('high', 'certification', f'Certification expired — {c.name}',
                     f'Expired {c.expires_on}', '/ohs/certifications', c.expires_on)
            elif c.is_expiring:
                push('medium', 'certification', f'Certification expiring — {c.name}',
                     f'Expires in {c.days_to_expiry} days', '/ohs/certifications',
                     c.expires_on, c.issuing_body)

        for c in Contractor.objects.all():
            if c.expired_documents:
                push('high', 'contractor', f'Contractor documents expired — {c.name}',
                     f'{c.expired_documents} document(s) past expiry', '/ohs/contractors')
            elif c.expiring_documents:
                push('medium', 'contractor', f'Contractor documents expiring — {c.name}',
                     f'{c.expiring_documents} document(s) expiring soon', '/ohs/contractors')

        for d in Document.objects.filter(review_due__lt=today).exclude(status__in=['draft', 'obsolete']):
            push('medium', 'document', f'Document review overdue — {d.reference}',
                 d.title, '/ohs/documents', d.review_due, d.owner_name)

        for s in SafetyMeeting.objects.filter(status='scheduled', meeting_date__lt=today):
            push('low', 'meeting', f'Meeting not held — {s.title}',
                 f'Scheduled {s.meeting_date}', '/ohs/committee', s.meeting_date, s.chairperson)

        for m in HealthSurveillance.objects.filter(result='pending', scheduled_on__lt=today):
            push('medium', 'health', f'Medical overdue — {m.employee_name}',
                 m.get_programme_display(), '/ohs/health', m.scheduled_on)

        for h in Hazard.objects.exclude(status='closed'):
            if (h.risk_score or 0) >= 20:
                push('high', 'risk', f'Critical risk open — {h.reference}',
                     h.title, '/ohs/hazards', h.next_review_on, h.owner_name)

        for e in ExposureMonitoring.objects.filter(result='exceeded'):
            push('high', 'exposure', f'Exposure limit exceeded — {e.get_agent_display()}',
                 f'{e.measured_value} {e.unit} at {e.site.name if e.site_id else "site"}',
                 '/ohs/health', e.measured_on)

        for q in SafetyEquipment.objects.select_related('site'):
            if q.is_inspection_overdue:
                push('high', 'equipment',
                     f'Inspection overdue — {q.reference} {q.name}',
                     f'{q.get_category_display()} at {q.site.name if q.site_id else "—"} '
                     f'· {abs(q.days_to_inspection or 0)}d past due',
                     '/ohs/equipment', q.next_inspection_on, q.custodian)
            elif q.is_inspection_due_soon:
                push('medium', 'equipment',
                     f'Inspection due — {q.reference} {q.name}',
                     f'Due in {q.days_to_inspection}d · {q.get_category_display()}',
                     '/ohs/equipment', q.next_inspection_on, q.custodian)
            if q.is_calibration_overdue:
                push('high', 'equipment',
                     f'Calibration overdue — {q.reference} {q.name}',
                     f'{abs(q.days_to_calibration or 0)}d past calibration due date',
                     '/ohs/equipment', q.next_calibration_on, q.custodian)
            if q.status in ('out_of_service', 'quarantine'):
                push('high', 'equipment',
                     f'Equipment {q.get_status_display().lower()} — {q.reference} {q.name}',
                     f'{q.get_category_display()} at {q.site.name if q.site_id else "—"}',
                     '/ohs/equipment')

        for d in EquipmentDefect.objects.select_related('equipment').filter(
            status__in=EQUIPMENT_OPEN_DEFECTS,
        ):
            if d.severity in ('critical', 'high'):
                push('high', 'equipment-defect',
                     f'Open defect — {d.equipment.reference} {d.equipment.name}',
                     d.description[:140], '/ohs/equipment', d.reported_on, d.reported_by)

        order = {'high': 0, 'medium': 1, 'low': 2}
        alerts.sort(key=lambda a: (order.get(a['severity'], 3), a['due'] or '9999'))
        counts = {
            'high': sum(1 for a in alerts if a['severity'] == 'high'),
            'medium': sum(1 for a in alerts if a['severity'] == 'medium'),
            'low': sum(1 for a in alerts if a['severity'] == 'low'),
            'total': len(alerts),
        }
        return Response({'counts': counts, 'alerts': alerts[:120]})


# ─────────────────────────────────────────────────────────────────────────
#  Global search across every register
# ─────────────────────────────────────────────────────────────────────────
class OhsSearchView(APIView):
    def get(self, request):
        q = (request.query_params.get('q') or '').strip()
        results = []
        if len(q) < 2:
            return Response({'query': q, 'results': []})
        limit = 5

        def add(kind, label, items, to_result):
            for obj in items[:limit]:
                results.append({'kind': kind, 'label': label, **to_result(obj)})

        add('hazard', 'Hazard', Hazard.objects.filter(
            Q(reference__icontains=q) | Q(title__icontains=q) | Q(area__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.title, 'meta': o.reference, 'href': '/ohs/hazards'})

        add('incident', 'Incident', Incident.objects.filter(
            Q(reference__icontains=q) | Q(title__icontains=q) | Q(person_involved__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.title, 'meta': o.reference, 'href': '/ohs/incidents'})

        add('inspection', 'Inspection', Inspection.objects.filter(
            Q(reference__icontains=q) | Q(title__icontains=q) | Q(area__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.title, 'meta': o.reference, 'href': '/ohs/inspections'})

        add('permit', 'Permit', PermitToWork.objects.filter(
            Q(reference__icontains=q) | Q(title__icontains=q) | Q(area__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.title, 'meta': o.reference, 'href': '/ohs/permits'})

        add('document', 'Document', Document.objects.filter(
            Q(reference__icontains=q) | Q(title__icontains=q) | Q(chemical_name__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.title, 'meta': o.reference, 'href': '/ohs/documents'})

        add('contractor', 'Contractor', Contractor.objects.filter(
            Q(name__icontains=q) | Q(registration_no__icontains=q) | Q(contact_person__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.name, 'meta': o.get_trade_display(),
                       'href': '/ohs/contractors'})

        add('site', 'Site', Site.objects.filter(
            Q(name__icontains=q) | Q(code__icontains=q) | Q(county__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.name, 'meta': o.get_site_type_display(),
                       'href': '/ohs/sites'})

        add('certification', 'Certification', Certification.objects.filter(
            Q(name__icontains=q) | Q(reference_no__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.name, 'meta': o.issuing_body,
                       'href': '/ohs/certifications'})

        add('training', 'Training', TrainingCourse.objects.filter(
            Q(name__icontains=q) | Q(code__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.name, 'meta': o.code, 'href': '/ohs/training'})

        add('ppe', 'PPE', PpeItem.objects.filter(
            Q(name__icontains=q) | Q(standard__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.name, 'meta': o.get_category_display(),
                       'href': '/ohs/ppe'})

        add('equipment', 'Safety equipment', SafetyEquipment.objects.filter(
            Q(reference__icontains=q) | Q(name__icontains=q) | Q(asset_tag__icontains=q)
            | Q(serial_number__icontains=q) | Q(location__icontains=q))[:limit],
            lambda o: {'id': o.id, 'title': o.name, 'meta': f'{o.reference} · {o.get_category_display()}',
                       'href': '/ohs/equipment'})

        return Response({'query': q, 'results': results[:40]})
