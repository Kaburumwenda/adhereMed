from django.contrib import admin

from .models import (
    LabTestCatalog, LabOrder, LabResult, HomeSampleVisit,
    LabPanel, ReferringFacility, ReferringDoctor, Instrument,
    Specimen, QualityControlRun,
    LabInvoice, LabInvoiceItem, LabInvoicePayment,
    ReportTemplate, LabOrderExtra, LabResultAudit,
    LabReagent, ReagentLot, ReagentTransaction,
)


@admin.register(LabTestCatalog)
class LabTestCatalogAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'specimen_type', 'department', 'price', 'is_active')
    list_filter = ('is_active', 'department')
    search_fields = ('code', 'name')


@admin.register(LabPanel)
class LabPanelAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'department', 'price', 'is_active')
    list_filter = ('is_active', 'department')
    search_fields = ('code', 'name')
    filter_horizontal = ('tests',)


@admin.register(LabOrder)
class LabOrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient', 'ordered_by', 'status', 'priority', 'is_home_collection', 'created_at')
    list_filter = ('status', 'priority', 'is_home_collection')
    search_fields = ('patient__user__first_name', 'patient__user__last_name')
    filter_horizontal = ('tests',)


@admin.register(LabResult)
class LabResultAdmin(admin.ModelAdmin):
    list_display = ('order', 'test', 'result_value', 'is_abnormal', 'performed_by', 'verified_by', 'result_date')
    list_filter = ('is_abnormal',)
    search_fields = ('test__name',)


@admin.register(HomeSampleVisit)
class HomeSampleVisitAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient', 'assigned_lab_tech', 'scheduled_date', 'scheduled_time', 'status')
    list_filter = ('status', 'scheduled_date')
    search_fields = ('patient__user__first_name', 'patient__user__last_name')


@admin.register(ReferringFacility)
class ReferringFacilityAdmin(admin.ModelAdmin):
    list_display = ('name', 'contact_person', 'phone', 'discount_percent', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name', 'contact_person', 'phone')


@admin.register(ReferringDoctor)
class ReferringDoctorAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'facility', 'specialty', 'license_no', 'commission_percent')
    list_filter = ('is_active', 'facility')
    search_fields = ('full_name', 'license_no', 'specialty')


@admin.register(Instrument)
class InstrumentAdmin(admin.ModelAdmin):
    list_display = ('name', 'serial_no', 'manufacturer', 'department', 'status', 'is_active')
    list_filter = ('status', 'department', 'is_active')
    search_fields = ('name', 'serial_no', 'manufacturer')


@admin.register(Specimen)
class SpecimenAdmin(admin.ModelAdmin):
    list_display = ('accession_number', 'lab_order', 'specimen_type', 'container_type', 'status', 'collected_at')
    list_filter = ('status', 'container_type')
    search_fields = ('accession_number', 'barcode')


@admin.register(QualityControlRun)
class QualityControlRunAdmin(admin.ModelAdmin):
    list_display = ('instrument', 'test', 'qc_level', 'result', 'performed_by', 'run_at')
    list_filter = ('result',)


class LabInvoiceItemInline(admin.TabularInline):
    model = LabInvoiceItem
    extra = 1


class LabInvoicePaymentInline(admin.TabularInline):
    model = LabInvoicePayment
    extra = 0
    readonly_fields = ('received_at',)


@admin.register(LabInvoice)
class LabInvoiceAdmin(admin.ModelAdmin):
    list_display = ('invoice_number', 'lab_order', 'patient', 'payer_type', 'total', 'amount_paid', 'status')
    list_filter = ('status', 'payer_type')
    search_fields = ('invoice_number',)
    inlines = [LabInvoiceItemInline, LabInvoicePaymentInline]
    readonly_fields = ('balance',)


@admin.register(LabInvoiceItem)
class LabInvoiceItemAdmin(admin.ModelAdmin):
    list_display = ('invoice', 'description', 'qty', 'unit_price', 'amount')


@admin.register(LabInvoicePayment)
class LabInvoicePaymentAdmin(admin.ModelAdmin):
    list_display = ('invoice', 'method', 'amount', 'reference', 'received_by', 'received_at')
    list_filter = ('method',)


@admin.register(ReportTemplate)
class ReportTemplateAdmin(admin.ModelAdmin):
    list_display = ('name', 'department', 'signatory_name', 'is_default', 'is_active')
    list_filter = ('is_default', 'is_active', 'department')


@admin.register(LabOrderExtra)
class LabOrderExtraAdmin(admin.ModelAdmin):
    list_display = ('lab_order', 'accession_number', 'referring_doctor', 'referring_facility', 'payer_type')
    list_filter = ('payer_type',)
    search_fields = ('accession_number',)
    filter_horizontal = ('panels',)


@admin.register(LabResultAudit)
class LabResultAuditAdmin(admin.ModelAdmin):
    list_display = ('result', 'changed_by', 'reason', 'changed_at')
    list_filter = ('changed_at',)
    readonly_fields = ('changed_at',)


@admin.register(LabReagent)
class LabReagentAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'category', 'storage', 'department', 'is_active')
    list_filter = ('category', 'storage', 'department', 'is_active')
    search_fields = ('name', 'code', 'catalog_no', 'manufacturer')


class ReagentTransactionInline(admin.TabularInline):
    model = ReagentTransaction
    extra = 0
    readonly_fields = ('performed_at',)


@admin.register(ReagentLot)
class ReagentLotAdmin(admin.ModelAdmin):
    list_display = ('reagent', 'lot_number', 'expiry_date', 'quantity_on_hand', 'status')
    list_filter = ('status',)
    search_fields = ('lot_number', 'reagent__name')
    inlines = [ReagentTransactionInline]


@admin.register(ReagentTransaction)
class ReagentTransactionAdmin(admin.ModelAdmin):
    list_display = ('lot', 'txn_type', 'quantity', 'performed_by', 'performed_at')
    list_filter = ('txn_type',)
