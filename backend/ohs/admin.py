from django.contrib import admin

from .models import (
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
    HealthSurveillance,
    Incident,
    IncidentAction,
    Inspection,
    InspectionItem,
    LegalRequirement,
    ManagementReview,
    MeetingAttendance,
    Observation,
    OhsRoleDefinition,
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


@admin.register(Site)
class SiteAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'site_type', 'risk_profile', 'headcount', 'is_active')
    list_filter = ('site_type', 'risk_profile', 'is_active')
    search_fields = ('name', 'code', 'site_manager')


@admin.register(HazardCategory)
class HazardCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'icon', 'sort_order')
    search_fields = ('name', 'code')


class ControlInline(admin.TabularInline):
    model = ControlMeasure
    extra = 0


@admin.register(Hazard)
class HazardAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'site', 'hazard_type', 'risk_score', 'status')
    list_filter = ('hazard_type', 'status', 'site')
    search_fields = ('reference', 'title', 'description', 'area')
    inlines = [ControlInline]


class RiskItemInline(admin.TabularInline):
    model = RiskAssessmentItem
    extra = 0


@admin.register(RiskAssessment)
class RiskAssessmentAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'site', 'methodology', 'status', 'assessment_date')
    list_filter = ('status', 'methodology', 'site')
    search_fields = ('reference', 'title', 'scope')
    inlines = [RiskItemInline]


class IncidentActionInline(admin.TabularInline):
    model = IncidentAction
    extra = 0


@admin.register(Incident)
class IncidentAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'site', 'incident_type', 'severity', 'status', 'occurred_at')
    list_filter = ('incident_type', 'severity', 'status', 'site', 'is_lost_time')
    search_fields = ('reference', 'title', 'description', 'person_involved')
    date_hierarchy = 'occurred_at'
    inlines = [IncidentActionInline]


class InspectionItemInline(admin.TabularInline):
    model = InspectionItem
    extra = 0


@admin.register(Inspection)
class InspectionAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'site', 'inspection_type', 'status', 'scheduled_for', 'score')
    list_filter = ('inspection_type', 'status', 'site')
    search_fields = ('reference', 'title', 'area', 'inspector_name')
    inlines = [InspectionItemInline]


@admin.register(PermitToWork)
class PermitToWorkAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'site', 'permit_type', 'status', 'valid_from', 'valid_to')
    list_filter = ('permit_type', 'status', 'risk_level', 'site')
    search_fields = ('reference', 'title', 'area', 'requested_by', 'issued_by')


@admin.register(TrainingCourse)
class TrainingCourseAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'category', 'is_mandatory', 'validity_months', 'provider')
    list_filter = ('category', 'is_mandatory')
    search_fields = ('name', 'code', 'provider')


@admin.register(TrainingRecord)
class TrainingRecordAdmin(admin.ModelAdmin):
    list_display = ('employee_name', 'course', 'site', 'completed_on', 'expires_on', 'result')
    list_filter = ('result', 'course', 'site')
    search_fields = ('employee_name', 'employee_ref', 'certificate_ref')


@admin.register(PpeItem)
class PpeItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'stock_on_hand', 'reorder_level', 'unit_cost')
    list_filter = ('category',)
    search_fields = ('name', 'code', 'standard')


@admin.register(PpeIssue)
class PpeIssueAdmin(admin.ModelAdmin):
    list_display = ('employee_name', 'ppe_item', 'site', 'quantity', 'issued_on', 'replacement_due')
    list_filter = ('site', 'ppe_item')
    search_fields = ('employee_name', 'employee_ref')


@admin.register(HealthSurveillance)
class HealthSurveillanceAdmin(admin.ModelAdmin):
    list_display = ('employee_name', 'programme', 'site', 'scheduled_on', 'completed_on', 'result')
    list_filter = ('programme', 'result', 'site')
    search_fields = ('employee_name', 'employee_ref', 'job_title')


@admin.register(Observation)
class ObservationAdmin(admin.ModelAdmin):
    list_display = ('kind', 'category', 'site', 'observer_name', 'observed_at')
    list_filter = ('kind', 'category', 'site')
    search_fields = ('observer_name', 'observed_person', 'description')


@admin.register(ExposureMonitoring)
class ExposureMonitoringAdmin(admin.ModelAdmin):
    list_display = ('agent', 'site', 'area', 'measured_value', 'unit', 'oel_limit', 'result', 'measured_on')
    list_filter = ('agent', 'result', 'site')
    search_fields = ('area', 'method', 'lab_reference')


@admin.register(EmergencyDrill)
class EmergencyDrillAdmin(admin.ModelAdmin):
    list_display = ('drill_type', 'site', 'scheduled_on', 'conducted_on', 'status', 'participants', 'score')
    list_filter = ('drill_type', 'status', 'site')
    search_fields = ('scenario', 'findings', 'coordinator')


@admin.register(LegalRequirement)
class LegalRequirementAdmin(admin.ModelAdmin):
    list_display = ('title', 'standard', 'clause', 'compliance_status', 'next_review_on')
    list_filter = ('compliance_status', 'standard')
    search_fields = ('title', 'standard', 'clause', 'description')


@admin.register(ComplianceAudit)
class ComplianceAuditAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'audit_type', 'standard', 'status', 'scheduled_on', 'score')
    list_filter = ('audit_type', 'status', 'site')
    search_fields = ('reference', 'title', 'auditor', 'scope')


@admin.register(SafetyObjective)
class SafetyObjectiveAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'site', 'target_value', 'current_value', 'status', 'due_date')
    list_filter = ('category', 'status', 'site')
    search_fields = ('title', 'description', 'owner_name')


# ── Document control ─────────────────────────────────────────────────
class DocumentRevisionInline(admin.TabularInline):
    model = DocumentRevision
    extra = 0


@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'doc_type', 'version', 'status', 'owner_name', 'review_due')
    list_filter = ('doc_type', 'status', 'classification')
    search_fields = ('reference', 'title', 'chemical_name', 'tags')
    inlines = [DocumentRevisionInline]


@admin.register(DocumentAcknowledgement)
class DocumentAcknowledgementAdmin(admin.ModelAdmin):
    list_display = ('employee_name', 'document', 'acknowledged_on', 'version_read')
    search_fields = ('employee_name', 'employee_ref')


# ── Contractors ──────────────────────────────────────────────────────
class ContractorEngagementInline(admin.TabularInline):
    model = ContractorEngagement
    extra = 0


@admin.register(Contractor)
class ContractorAdmin(admin.ModelAdmin):
    list_display = ('name', 'trade', 'status', 'risk_rating', 'performance_score',
                    'insurance_expiry', 'safety_file_expiry')
    list_filter = ('trade', 'status', 'risk_rating')
    search_fields = ('name', 'registration_no', 'contact_person')
    inlines = [ContractorEngagementInline]


@admin.register(ContractorEngagement)
class ContractorEngagementAdmin(admin.ModelAdmin):
    list_display = ('contractor', 'site', 'scope', 'start_date', 'end_date', 'status')
    list_filter = ('status', 'site')
    search_fields = ('scope', 'supervisor_name')


# ── Safety meetings ──────────────────────────────────────────────────
class MeetingAttendanceInline(admin.TabularInline):
    model = MeetingAttendance
    extra = 0


@admin.register(SafetyMeeting)
class SafetyMeetingAdmin(admin.ModelAdmin):
    list_display = ('title', 'meeting_type', 'site', 'meeting_date', 'attendees_count', 'status')
    list_filter = ('meeting_type', 'status', 'site')
    search_fields = ('title', 'chairperson', 'topics_covered')
    inlines = [MeetingAttendanceInline]


# ── Management reviews ───────────────────────────────────────────────
@admin.register(ManagementReview)
class ManagementReviewAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'review_date', 'chairperson', 'status', 'outcome')
    list_filter = ('status', 'outcome')
    search_fields = ('reference', 'title', 'chairperson')


# ── Certifications ───────────────────────────────────────────────────
@admin.register(Certification)
class CertificationAdmin(admin.ModelAdmin):
    list_display = ('name', 'cert_type', 'reference_no', 'issuing_body', 'expires_on', 'status')
    list_filter = ('cert_type', 'status')
    search_fields = ('name', 'reference_no', 'issuing_body', 'holder_name')


class EquipmentInspectionInline(admin.TabularInline):
    model = EquipmentInspection
    extra = 0
    fields = ('inspection_type', 'performed_on', 'performed_by', 'result', 'next_due')


class EquipmentDefectInline(admin.TabularInline):
    model = EquipmentDefect
    extra = 0
    fields = ('reported_on', 'severity', 'description', 'status', 'resolved_on')


# ── Safety equipment ─────────────────────────────────────────────────
@admin.register(SafetyEquipment)
class SafetyEquipmentAdmin(admin.ModelAdmin):
    list_display = ('reference', 'name', 'category', 'site', 'status', 'criticality',
                    'next_inspection_on', 'next_calibration_on')
    list_filter = ('category', 'status', 'criticality', 'requires_inspection',
                   'requires_calibration')
    search_fields = ('reference', 'name', 'asset_tag', 'serial_number', 'manufacturer',
                     'location', 'custodian')
    inlines = [EquipmentInspectionInline, EquipmentDefectInline]


@admin.register(EquipmentInspection)
class EquipmentInspectionAdmin(admin.ModelAdmin):
    list_display = ('equipment', 'inspection_type', 'performed_on', 'performed_by', 'result')
    list_filter = ('inspection_type', 'result')
    search_fields = ('equipment__name', 'equipment__reference', 'performed_by', 'provider')


@admin.register(EquipmentDefect)
class EquipmentDefectAdmin(admin.ModelAdmin):
    list_display = ('equipment', 'severity', 'reported_on', 'status', 'resolved_on')
    list_filter = ('severity', 'status')
    search_fields = ('equipment__name', 'equipment__reference', 'description', 'work_order')


# ── Roles & Access (RBAC) ────────────────────────────────────────────
@admin.register(OhsRoleDefinition)
class OhsRoleDefinitionAdmin(admin.ModelAdmin):
    list_display = ('label', 'key', 'is_system', 'is_active', 'updated_at')
    list_filter = ('is_system', 'is_active')
    search_fields = ('key', 'label', 'description')
    readonly_fields = ('created_at', 'updated_at')
