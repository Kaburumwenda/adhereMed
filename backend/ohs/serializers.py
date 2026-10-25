"""Serializers for the OHSMS API (``/api/ohs/``)."""
from rest_framework import serializers

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
)


# ─────────────────────────────────────────────────────────────────────────
#  Sites
# ─────────────────────────────────────────────────────────────────────────
class SiteSerializer(serializers.ModelSerializer):
    site_type_display = serializers.CharField(source='get_site_type_display', read_only=True)
    risk_profile_display = serializers.CharField(source='get_risk_profile_display', read_only=True)
    hours_worked = serializers.IntegerField(read_only=True)
    open_hazards = serializers.SerializerMethodField()
    open_incidents = serializers.SerializerMethodField()

    class Meta:
        model = Site
        fields = '__all__'

    def get_open_hazards(self, obj):
        return obj.hazards.exclude(status='closed').count()

    def get_open_incidents(self, obj):
        return obj.incidents.exclude(status='closed').count()


class HazardCategorySerializer(serializers.ModelSerializer):
    hazard_count = serializers.SerializerMethodField()

    class Meta:
        model = HazardCategory
        fields = '__all__'

    def get_hazard_count(self, obj):
        return obj.hazards.count()


# ─────────────────────────────────────────────────────────────────────────
#  Hazards & controls
# ─────────────────────────────────────────────────────────────────────────
class ControlMeasureSerializer(serializers.ModelSerializer):
    hierarchy_display = serializers.CharField(source='get_hierarchy_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)

    class Meta:
        model = ControlMeasure
        fields = '__all__'


class HazardSerializer(serializers.ModelSerializer):
    hazard_type_display = serializers.CharField(source='get_hazard_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_color = serializers.CharField(source='category.color', read_only=True)
    risk_score = serializers.IntegerField(read_only=True)
    risk_level = serializers.CharField(read_only=True)
    residual_score = serializers.IntegerField(read_only=True)
    residual_level = serializers.CharField(read_only=True)
    controls = ControlMeasureSerializer(many=True, read_only=True)
    control_count = serializers.SerializerMethodField()
    overdue_controls = serializers.SerializerMethodField()

    class Meta:
        model = Hazard
        fields = '__all__'
        read_only_fields = ['reference']

    def get_control_count(self, obj):
        return obj.controls.count()

    def get_overdue_controls(self, obj):
        return sum(1 for c in obj.controls.all() if c.is_overdue)


class HazardListSerializer(serializers.ModelSerializer):
    """Lightweight payload for register tables."""

    hazard_type_display = serializers.CharField(source='get_hazard_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    risk_score = serializers.IntegerField(read_only=True)
    risk_level = serializers.CharField(read_only=True)
    residual_score = serializers.IntegerField(read_only=True)
    residual_level = serializers.CharField(read_only=True)
    control_count = serializers.SerializerMethodField()
    overdue_controls = serializers.SerializerMethodField()

    class Meta:
        model = Hazard
        fields = [
            'id', 'reference', 'title', 'hazard_type', 'hazard_type_display',
            'site', 'site_name', 'area', 'activity', 'category', 'category_name',
            'severity', 'likelihood', 'risk_score', 'risk_level',
            'residual_score', 'residual_level', 'status', 'status_display',
            'owner_name', 'identified_on', 'next_review_on',
            'control_count', 'overdue_controls', 'updated_at',
        ]

    def get_control_count(self, obj):
        return obj.controls.count()

    def get_overdue_controls(self, obj):
        return sum(1 for c in obj.controls.all() if c.is_overdue)


# ─────────────────────────────────────────────────────────────────────────
#  Risk assessments
# ─────────────────────────────────────────────────────────────────────────
class RiskAssessmentItemSerializer(serializers.ModelSerializer):
    risk_score = serializers.IntegerField(read_only=True)
    risk_level = serializers.CharField(read_only=True)
    residual_score = serializers.IntegerField(read_only=True)
    residual_level = serializers.CharField(read_only=True)

    class Meta:
        model = RiskAssessmentItem
        fields = '__all__'


class RiskAssessmentSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    methodology_display = serializers.CharField(source='get_methodology_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    items = RiskAssessmentItemSerializer(many=True, read_only=True)
    item_count = serializers.SerializerMethodField()
    highest_score = serializers.IntegerField(read_only=True)
    is_review_due = serializers.BooleanField(read_only=True)

    class Meta:
        model = RiskAssessment
        fields = '__all__'
        read_only_fields = ['reference']

    def get_item_count(self, obj):
        return obj.items.count()


# ─────────────────────────────────────────────────────────────────────────
#  Incidents
# ─────────────────────────────────────────────────────────────────────────
class IncidentActionSerializer(serializers.ModelSerializer):
    action_type_display = serializers.CharField(source='get_action_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)

    class Meta:
        model = IncidentAction
        fields = '__all__'


class IncidentSerializer(serializers.ModelSerializer):
    incident_type_display = serializers.CharField(source='get_incident_type_display', read_only=True)
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    cause_category_display = serializers.CharField(
        source='get_cause_category_display', read_only=True,
    )
    site_name = serializers.CharField(source='site.name', read_only=True)
    days_open = serializers.IntegerField(read_only=True)
    actions = IncidentActionSerializer(many=True, read_only=True)
    open_actions = serializers.SerializerMethodField()

    class Meta:
        model = Incident
        fields = '__all__'
        read_only_fields = ['reference']

    def get_open_actions(self, obj):
        return obj.actions.exclude(status__in=['done', 'verified']).count()


class IncidentListSerializer(serializers.ModelSerializer):
    incident_type_display = serializers.CharField(source='get_incident_type_display', read_only=True)
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    days_open = serializers.IntegerField(read_only=True)
    open_actions = serializers.SerializerMethodField()

    class Meta:
        model = Incident
        fields = [
            'id', 'reference', 'title', 'incident_type', 'incident_type_display',
            'severity', 'severity_display', 'site', 'site_name', 'location',
            'department', 'occurred_at', 'reported_at', 'person_involved',
            'is_recordable', 'is_lost_time', 'lost_days', 'days_away',
            'cost_estimate', 'status', 'status_display', 'reported_by',
            'investigator', 'closed_at', 'days_open', 'open_actions',
        ]

    def get_open_actions(self, obj):
        return obj.actions.exclude(status__in=['done', 'verified']).count()


# ─────────────────────────────────────────────────────────────────────────
#  Inspections
# ─────────────────────────────────────────────────────────────────────────
class InspectionItemSerializer(serializers.ModelSerializer):
    result_display = serializers.CharField(source='get_result_display', read_only=True)
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)

    class Meta:
        model = InspectionItem
        fields = '__all__'


class InspectionSerializer(serializers.ModelSerializer):
    inspection_type_display = serializers.CharField(
        source='get_inspection_type_display', read_only=True,
    )
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    items = InspectionItemSerializer(many=True, read_only=True)
    findings_count = serializers.IntegerField(read_only=True)
    critical_findings = serializers.IntegerField(read_only=True)

    class Meta:
        model = Inspection
        fields = '__all__'
        read_only_fields = ['reference']


# ─────────────────────────────────────────────────────────────────────────
#  Permits
# ─────────────────────────────────────────────────────────────────────────
class PermitToWorkSerializer(serializers.ModelSerializer):
    permit_type_display = serializers.CharField(source='get_permit_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    risk_level_display = serializers.CharField(source='get_risk_level_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    is_expired = serializers.BooleanField(read_only=True)

    class Meta:
        model = PermitToWork
        fields = '__all__'
        read_only_fields = ['reference']


# ─────────────────────────────────────────────────────────────────────────
#  Training
# ─────────────────────────────────────────────────────────────────────────
class TrainingCourseSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    record_count = serializers.SerializerMethodField()

    class Meta:
        model = TrainingCourse
        fields = '__all__'

    def get_record_count(self, obj):
        return obj.records.count()


class TrainingRecordSerializer(serializers.ModelSerializer):
    course_name = serializers.CharField(source='course.name', read_only=True)
    course_category = serializers.CharField(source='course.category', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    result_display = serializers.CharField(source='get_result_display', read_only=True)
    is_expired = serializers.BooleanField(read_only=True)
    days_to_expiry = serializers.IntegerField(read_only=True)

    class Meta:
        model = TrainingRecord
        fields = '__all__'


# ─────────────────────────────────────────────────────────────────────────
#  PPE
# ─────────────────────────────────────────────────────────────────────────
class PpeItemSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    is_low_stock = serializers.BooleanField(read_only=True)
    issued_count = serializers.SerializerMethodField()

    class Meta:
        model = PpeItem
        fields = '__all__'

    def get_issued_count(self, obj):
        return obj.issues.count()


class PpeIssueSerializer(serializers.ModelSerializer):
    ppe_name = serializers.CharField(source='ppe_item.name', read_only=True)
    ppe_category = serializers.CharField(source='ppe_item.category', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)

    class Meta:
        model = PpeIssue
        fields = '__all__'


# ─────────────────────────────────────────────────────────────────────────
#  Health surveillance
# ─────────────────────────────────────────────────────────────────────────
class HealthSurveillanceSerializer(serializers.ModelSerializer):
    programme_display = serializers.CharField(source='get_programme_display', read_only=True)
    result_display = serializers.CharField(source='get_result_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)

    class Meta:
        model = HealthSurveillance
        fields = '__all__'


# ─────────────────────────────────────────────────────────────────────────
#  Pre-employment & post-employment assessment
# ─────────────────────────────────────────────────────────────────────────
class JobDemandProfileSerializer(serializers.ModelSerializer):
    site_name = serializers.CharField(source='site.name', read_only=True)
    physical_demand_display = serializers.CharField(
        source='get_physical_demand_display', read_only=True,
    )
    vision_standard_display = serializers.CharField(
        source='get_vision_standard_display', read_only=True,
    )
    hearing_standard_display = serializers.CharField(
        source='get_hearing_standard_display', read_only=True,
    )
    surveillance_tier_display = serializers.CharField(
        source='get_surveillance_tier_display', read_only=True,
    )
    review_interval_months = serializers.IntegerField(read_only=True)
    assessment_count = serializers.SerializerMethodField()

    class Meta:
        model = JobDemandProfile
        fields = '__all__'

    def get_assessment_count(self, obj):
        return obj.assessments.count()


class AssessmentFindingSerializer(serializers.ModelSerializer):
    system_display = serializers.CharField(source='get_system_display', read_only=True)
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)

    class Meta:
        model = AssessmentFinding
        fields = '__all__'


class AssessmentLabResultSerializer(serializers.ModelSerializer):
    flag_display = serializers.CharField(source='get_flag_display', read_only=True)
    reference_range = serializers.SerializerMethodField()

    class Meta:
        model = AssessmentLabResult
        fields = '__all__'

    def get_reference_range(self, obj):
        lo, hi = obj.reference_low, obj.reference_high
        if lo is None and hi is None:
            return ''
        if lo is None:
            return f'< {hi:g}'
        if hi is None:
            return f'> {lo:g}'
        return f'{lo:g} – {hi:g}'


class HealthAssessmentListSerializer(serializers.ModelSerializer):
    """Lightweight payload for the assessment register."""

    kind_display = serializers.CharField(source='get_kind_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    fitness_display = serializers.CharField(source='get_fitness_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    job_demand_title = serializers.CharField(source='job_demand.job_title', read_only=True)
    bmi = serializers.FloatField(read_only=True)
    bmi_band = serializers.CharField(read_only=True)
    blood_pressure = serializers.CharField(read_only=True)
    bp_band = serializers.CharField(read_only=True)
    is_certified = serializers.BooleanField(read_only=True)
    is_certificate_expired = serializers.BooleanField(read_only=True)
    days_to_expiry = serializers.IntegerField(read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    abnormal_labs = serializers.IntegerField(read_only=True)
    critical_findings = serializers.IntegerField(read_only=True)

    class Meta:
        model = HealthAssessment
        fields = [
            'id', 'reference', 'kind', 'kind_display', 'status', 'status_display',
            'employee_name', 'employee_ref', 'job_title', 'department',
            'site', 'site_name', 'job_demand', 'job_demand_title',
            'scheduled_on', 'examined_on', 'examiner_name', 'provider',
            'fitness', 'fitness_display',
            'bmi', 'bmi_band', 'blood_pressure', 'bp_band',
            'work_related', 'compensation_claim', 'exit_reason',
            'certificate_no', 'issued_on', 'valid_until', 'next_due',
            'is_certified', 'is_certificate_expired', 'days_to_expiry',
            'is_overdue', 'abnormal_labs', 'critical_findings',
            'baseline', 'updated_at',
        ]


class HealthAssessmentSerializer(serializers.ModelSerializer):
    kind_display = serializers.CharField(source='get_kind_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    fitness_display = serializers.CharField(source='get_fitness_display', read_only=True)
    exit_reason_display = serializers.CharField(
        source='get_exit_reason_display', read_only=True,
    )
    site_name = serializers.CharField(source='site.name', read_only=True)
    job_demand_title = serializers.CharField(source='job_demand.job_title', read_only=True)
    # The drawer shows the role's standards next to the measured values, so the
    # whole profile travels with the record instead of needing a second call.
    job_demand_detail = JobDemandProfileSerializer(source='job_demand', read_only=True)
    baseline_reference = serializers.CharField(source='baseline.reference', read_only=True)
    findings = AssessmentFindingSerializer(many=True, read_only=True)
    lab_results = AssessmentLabResultSerializer(many=True, read_only=True)

    bmi = serializers.FloatField(read_only=True)
    bmi_band = serializers.CharField(read_only=True)
    blood_pressure = serializers.CharField(read_only=True)
    bp_band = serializers.CharField(read_only=True)
    is_certified = serializers.BooleanField(read_only=True)
    is_certificate_expired = serializers.BooleanField(read_only=True)
    days_to_expiry = serializers.IntegerField(read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    abnormal_labs = serializers.IntegerField(read_only=True)
    critical_findings = serializers.IntegerField(read_only=True)

    class Meta:
        model = HealthAssessment
        fields = '__all__'
        read_only_fields = ['reference']


# ─────────────────────────────────────────────────────────────────────────
#  Observations
# ─────────────────────────────────────────────────────────────────────────
class ObservationSerializer(serializers.ModelSerializer):
    kind_display = serializers.CharField(source='get_kind_display', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)

    class Meta:
        model = Observation
        fields = '__all__'


# ─────────────────────────────────────────────────────────────────────────
#  Exposure monitoring
# ─────────────────────────────────────────────────────────────────────────
class ExposureMonitoringSerializer(serializers.ModelSerializer):
    agent_display = serializers.CharField(source='get_agent_display', read_only=True)
    result_display = serializers.CharField(source='get_result_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    pct_of_limit = serializers.FloatField(read_only=True)

    class Meta:
        model = ExposureMonitoring
        fields = '__all__'


# ─────────────────────────────────────────────────────────────────────────
#  Emergency drills
# ─────────────────────────────────────────────────────────────────────────
class EmergencyDrillSerializer(serializers.ModelSerializer):
    drill_type_display = serializers.CharField(source='get_drill_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)

    class Meta:
        model = EmergencyDrill
        fields = '__all__'


# ─────────────────────────────────────────────────────────────────────────
#  Compliance
# ─────────────────────────────────────────────────────────────────────────
class LegalRequirementSerializer(serializers.ModelSerializer):
    compliance_status_display = serializers.CharField(
        source='get_compliance_status_display', read_only=True,
    )
    is_review_due = serializers.BooleanField(read_only=True)

    class Meta:
        model = LegalRequirement
        fields = '__all__'


class ComplianceAuditSerializer(serializers.ModelSerializer):
    audit_type_display = serializers.CharField(source='get_audit_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)

    class Meta:
        model = ComplianceAudit
        fields = '__all__'
        read_only_fields = ['reference']


# ─────────────────────────────────────────────────────────────────────────
#  Objectives
# ─────────────────────────────────────────────────────────────────────────
class SafetyObjectiveSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    progress_pct = serializers.FloatField(read_only=True)

    class Meta:
        model = SafetyObjective
        fields = '__all__'


# ─────────────────────────────────────────────────────────────────────────
#  Document control & SDS
# ─────────────────────────────────────────────────────────────────────────
class DocumentRevisionSerializer(serializers.ModelSerializer):
    class Meta:
        model = DocumentRevision
        fields = '__all__'


class DocumentAcknowledgementSerializer(serializers.ModelSerializer):
    site_name = serializers.CharField(source='site.name', read_only=True)

    class Meta:
        model = DocumentAcknowledgement
        fields = '__all__'


class DocumentSerializer(serializers.ModelSerializer):
    doc_type_display = serializers.CharField(source='get_doc_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    classification_display = serializers.CharField(
        source='get_classification_display', read_only=True,
    )
    site_name = serializers.CharField(source='site.name', read_only=True)
    is_review_overdue = serializers.BooleanField(read_only=True)
    days_to_review = serializers.IntegerField(read_only=True)
    revisions = DocumentRevisionSerializer(many=True, read_only=True)
    acknowledged_count = serializers.SerializerMethodField()
    acknowledgement_pct = serializers.SerializerMethodField()

    class Meta:
        model = Document
        fields = '__all__'
        read_only_fields = ['reference', 'revision_count']

    def get_acknowledged_count(self, obj):
        return obj.acknowledgements.count()

    def get_acknowledgement_pct(self, obj):
        if not obj.requires_acknowledgement:
            return None
        total = max(obj.site.headcount if obj.site_id else 0, obj.acknowledgements.count())
        if not total:
            return 0
        return round(obj.acknowledgements.count() / total * 100)


class DocumentListSerializer(serializers.ModelSerializer):
    doc_type_display = serializers.CharField(source='get_doc_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    is_review_overdue = serializers.BooleanField(read_only=True)
    days_to_review = serializers.IntegerField(read_only=True)
    acknowledged_count = serializers.SerializerMethodField()

    class Meta:
        model = Document
        fields = [
            'id', 'reference', 'title', 'doc_type', 'doc_type_display', 'classification',
            'site', 'site_name', 'version', 'status', 'status_display', 'owner_name',
            'effective_date', 'review_due', 'is_review_overdue', 'days_to_review',
            'requires_acknowledgement', 'acknowledged_count', 'chemical_name',
            'hazard_class', 'tags', 'updated_at',
        ]

    def get_acknowledged_count(self, obj):
        return obj.acknowledgements.count()


# ─────────────────────────────────────────────────────────────────────────
#  Contractors
# ─────────────────────────────────────────────────────────────────────────
class ContractorEngagementSerializer(serializers.ModelSerializer):
    site_name = serializers.CharField(source='site.name', read_only=True)
    contractor_name = serializers.CharField(source='contractor.name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    is_overrun = serializers.BooleanField(read_only=True)

    class Meta:
        model = ContractorEngagement
        fields = '__all__'


class ContractorSerializer(serializers.ModelSerializer):
    trade_display = serializers.CharField(source='get_trade_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    risk_rating_display = serializers.CharField(source='get_risk_rating_display', read_only=True)
    compliance_pct = serializers.IntegerField(read_only=True)
    expired_documents = serializers.IntegerField(read_only=True)
    expiring_documents = serializers.IntegerField(read_only=True)
    insurance_days = serializers.IntegerField(read_only=True)
    safety_file_days = serializers.IntegerField(read_only=True)
    induction_days = serializers.IntegerField(read_only=True)
    licence_days = serializers.IntegerField(read_only=True)
    engagements = ContractorEngagementSerializer(many=True, read_only=True)
    active_engagements = serializers.SerializerMethodField()

    class Meta:
        model = Contractor
        fields = '__all__'

    def get_active_engagements(self, obj):
        return obj.engagements.filter(status='active').count()


class ContractorListSerializer(serializers.ModelSerializer):
    trade_display = serializers.CharField(source='get_trade_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    risk_rating_display = serializers.CharField(source='get_risk_rating_display', read_only=True)
    compliance_pct = serializers.IntegerField(read_only=True)
    expired_documents = serializers.IntegerField(read_only=True)
    expiring_documents = serializers.IntegerField(read_only=True)
    insurance_days = serializers.IntegerField(read_only=True)
    safety_file_days = serializers.IntegerField(read_only=True)
    induction_days = serializers.IntegerField(read_only=True)
    licence_days = serializers.IntegerField(read_only=True)
    active_engagements = serializers.SerializerMethodField()

    class Meta:
        model = Contractor
        fields = [
            'id', 'name', 'registration_no', 'trade', 'trade_display', 'status',
            'status_display', 'risk_rating', 'risk_rating_display', 'contact_person',
            'phone', 'email', 'prequalified_on', 'insurance_expiry', 'safety_file_expiry',
            'induction_valid_until', 'licence_expiry', 'performance_score',
            'incidents_attributed', 'observations_logged', 'workers_count',
            'compliance_pct', 'expired_documents', 'expiring_documents',
            'insurance_days', 'safety_file_days', 'induction_days', 'licence_days',
            'active_engagements',
        ]

    def get_active_engagements(self, obj):
        return obj.engagements.filter(status='active').count()


# ─────────────────────────────────────────────────────────────────────────
#  Safety meetings
# ─────────────────────────────────────────────────────────────────────────
class MeetingAttendanceSerializer(serializers.ModelSerializer):
    class Meta:
        model = MeetingAttendance
        fields = '__all__'


class SafetyMeetingSerializer(serializers.ModelSerializer):
    meeting_type_display = serializers.CharField(source='get_meeting_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    attendance_pct = serializers.IntegerField(read_only=True)
    attendance = MeetingAttendanceSerializer(many=True, read_only=True)

    class Meta:
        model = SafetyMeeting
        fields = '__all__'


class SafetyMeetingListSerializer(serializers.ModelSerializer):
    meeting_type_display = serializers.CharField(source='get_meeting_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    attendance_pct = serializers.IntegerField(read_only=True)

    class Meta:
        model = SafetyMeeting
        fields = [
            'id', 'title', 'meeting_type', 'meeting_type_display', 'site', 'site_name',
            'meeting_date', 'start_time', 'duration_minutes', 'chairperson', 'location',
            'topics_covered', 'attendees_count', 'attendance_pct', 'status',
            'status_display', 'is_overdue', 'next_meeting_on', 'updated_at',
        ]


# ─────────────────────────────────────────────────────────────────────────
#  Management reviews
# ─────────────────────────────────────────────────────────────────────────
class ManagementReviewSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    outcome_display = serializers.CharField(source='get_outcome_display', read_only=True)

    class Meta:
        model = ManagementReview
        fields = '__all__'
        read_only_fields = ['reference']


# ─────────────────────────────────────────────────────────────────────────
#  Certifications
# ─────────────────────────────────────────────────────────────────────────
class CertificationSerializer(serializers.ModelSerializer):
    cert_type_display = serializers.CharField(source='get_cert_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    days_to_expiry = serializers.IntegerField(read_only=True)
    is_expired = serializers.BooleanField(read_only=True)
    is_expiring = serializers.BooleanField(read_only=True)

    class Meta:
        model = Certification
        fields = '__all__'


# ─────────────────────────────────────────────────────────────────────────
#  Safety equipment
# ─────────────────────────────────────────────────────────────────────────
class EquipmentInspectionSerializer(serializers.ModelSerializer):
    inspection_type_display = serializers.CharField(
        source='get_inspection_type_display', read_only=True,
    )
    result_display = serializers.CharField(source='get_result_display', read_only=True)
    is_failed = serializers.BooleanField(read_only=True)
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    equipment_reference = serializers.CharField(source='equipment.reference', read_only=True)

    class Meta:
        model = EquipmentInspection
        fields = '__all__'


class EquipmentDefectSerializer(serializers.ModelSerializer):
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    is_open = serializers.BooleanField(read_only=True)
    days_open = serializers.IntegerField(read_only=True)
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    equipment_reference = serializers.CharField(source='equipment.reference', read_only=True)

    class Meta:
        model = EquipmentDefect
        fields = '__all__'


class SafetyEquipmentSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    criticality_display = serializers.CharField(source='get_criticality_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    days_to_inspection = serializers.IntegerField(read_only=True)
    days_to_calibration = serializers.IntegerField(read_only=True)
    is_inspection_overdue = serializers.BooleanField(read_only=True)
    is_inspection_due_soon = serializers.BooleanField(read_only=True)
    is_calibration_overdue = serializers.BooleanField(read_only=True)
    is_calibration_due_soon = serializers.BooleanField(read_only=True)
    inspection_currency_pct = serializers.IntegerField(read_only=True)
    compliance_state = serializers.CharField(read_only=True)
    health_score = serializers.IntegerField(read_only=True)
    age_years = serializers.FloatField(read_only=True)
    is_end_of_life = serializers.BooleanField(read_only=True)
    open_defects = serializers.IntegerField(read_only=True)
    inspections = EquipmentInspectionSerializer(many=True, read_only=True)
    defects = EquipmentDefectSerializer(many=True, read_only=True)

    class Meta:
        model = SafetyEquipment
        fields = '__all__'
        read_only_fields = ['reference']


class SafetyEquipmentListSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    criticality_display = serializers.CharField(source='get_criticality_display', read_only=True)
    site_name = serializers.CharField(source='site.name', read_only=True)
    days_to_inspection = serializers.IntegerField(read_only=True)
    days_to_calibration = serializers.IntegerField(read_only=True)
    is_inspection_overdue = serializers.BooleanField(read_only=True)
    is_inspection_due_soon = serializers.BooleanField(read_only=True)
    is_calibration_overdue = serializers.BooleanField(read_only=True)
    is_calibration_due_soon = serializers.BooleanField(read_only=True)
    inspection_currency_pct = serializers.IntegerField(read_only=True)
    compliance_state = serializers.CharField(read_only=True)
    health_score = serializers.IntegerField(read_only=True)
    age_years = serializers.FloatField(read_only=True)
    is_end_of_life = serializers.BooleanField(read_only=True)
    open_defects = serializers.IntegerField(read_only=True)

    class Meta:
        model = SafetyEquipment
        fields = [
            'id', 'reference', 'name', 'category', 'category_display', 'status',
            'status_display', 'criticality', 'criticality_display', 'asset_tag',
            'serial_number', 'manufacturer', 'model', 'standard', 'site', 'site_name',
            'location', 'department', 'custodian', 'supplier', 'acquired_on', 'unit_cost',
            'useful_life_years', 'quantity', 'requires_inspection',
            'inspection_interval_days', 'last_inspected_on', 'next_inspection_on',
            'requires_calibration', 'calibration_interval_days', 'last_calibrated_on',
            'next_calibration_on', 'certificate_url', 'notes', 'days_to_inspection',
            'days_to_calibration', 'is_inspection_overdue', 'is_inspection_due_soon',
            'is_calibration_overdue', 'is_calibration_due_soon',
            'inspection_currency_pct', 'compliance_state', 'health_score', 'age_years',
            'is_end_of_life', 'open_defects', 'updated_at',
        ]
