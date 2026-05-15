from django.contrib import admin
from .models import (
    ImagingModality, ExamCatalog, ExamPanel,
    ReferringFacility, ReferringDoctor,
    RadiologyOrder, RadiologyOrderExtra, RadiologySchedule,
    ContrastAdministration, DoseRecord,
    RadiologyResult, ReportTemplate, RadiologyReport, CriticalFindingAlert,
    QualityControlRecord,
    RadiologyInvoice, RadiologyInvoiceItem, RadiologyPayment,
)


@admin.register(ImagingModality)
class ImagingModalityAdmin(admin.ModelAdmin):
    list_display = ('name', 'modality_type', 'room_location', 'is_active')
    list_filter = ('modality_type', 'is_active')


@admin.register(ExamCatalog)
class ExamCatalogAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'modality_type', 'price', 'is_active')
    list_filter = ('modality_type', 'is_active', 'contrast_required')
    search_fields = ('code', 'name')


@admin.register(ExamPanel)
class ExamPanelAdmin(admin.ModelAdmin):
    list_display = ('name', 'price', 'is_active')


@admin.register(ReferringFacility)
class ReferringFacilityAdmin(admin.ModelAdmin):
    list_display = ('name', 'phone', 'email', 'is_active')
    search_fields = ('name',)


@admin.register(ReferringDoctor)
class ReferringDoctorAdmin(admin.ModelAdmin):
    list_display = ('name', 'specialty', 'facility', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name', 'specialty')


@admin.register(RadiologyOrder)
class RadiologyOrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient', 'imaging_type', 'body_part', 'status', 'priority', 'created_at')
    list_filter = ('status', 'imaging_type', 'priority')
    search_fields = ('body_part', 'clinical_indication')


@admin.register(RadiologyOrderExtra)
class RadiologyOrderExtraAdmin(admin.ModelAdmin):
    list_display = ('order', 'accession_number', 'payer_type')


@admin.register(RadiologySchedule)
class RadiologyScheduleAdmin(admin.ModelAdmin):
    list_display = ('order', 'modality', 'scheduled_datetime', 'technologist', 'status')
    list_filter = ('status', 'modality')


@admin.register(ContrastAdministration)
class ContrastAdministrationAdmin(admin.ModelAdmin):
    list_display = ('order', 'contrast_agent', 'dose_ml', 'reaction_noted')


@admin.register(DoseRecord)
class DoseRecordAdmin(admin.ModelAdmin):
    list_display = ('order', 'modality', 'ctdi_vol', 'dlp', 'effective_dose_msv')


@admin.register(RadiologyResult)
class RadiologyResultAdmin(admin.ModelAdmin):
    list_display = ('order', 'radiologist', 'result_date')


@admin.register(ReportTemplate)
class ReportTemplateAdmin(admin.ModelAdmin):
    list_display = ('name', 'modality_type', 'body_region', 'is_active')
    list_filter = ('modality_type', 'is_active')


@admin.register(RadiologyReport)
class RadiologyReportAdmin(admin.ModelAdmin):
    list_display = ('order', 'radiologist', 'report_status', 'critical_finding', 'signed_at')
    list_filter = ('report_status', 'critical_finding')


@admin.register(CriticalFindingAlert)
class CriticalFindingAlertAdmin(admin.ModelAdmin):
    list_display = ('report', 'severity', 'communicated_to', 'acknowledged')
    list_filter = ('severity', 'acknowledged')


@admin.register(QualityControlRecord)
class QualityControlRecordAdmin(admin.ModelAdmin):
    list_display = ('modality', 'qc_date', 'status', 'performed_by')
    list_filter = ('status', 'modality')


@admin.register(RadiologyInvoice)
class RadiologyInvoiceAdmin(admin.ModelAdmin):
    list_display = ('invoice_number', 'patient', 'total', 'amount_paid', 'status')
    list_filter = ('status', 'payer_type')
    search_fields = ('invoice_number',)


@admin.register(RadiologyInvoiceItem)
class RadiologyInvoiceItemAdmin(admin.ModelAdmin):
    list_display = ('invoice', 'description', 'quantity', 'unit_price', 'total')


@admin.register(RadiologyPayment)
class RadiologyPaymentAdmin(admin.ModelAdmin):
    list_display = ('invoice', 'amount', 'method', 'payment_date')
    list_filter = ('method',)
