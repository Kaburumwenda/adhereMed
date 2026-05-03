from django.contrib import admin
from .models import LabTestCatalog, LabOrder, LabResult, HomeSampleVisit


@admin.register(LabTestCatalog)
class LabTestCatalogAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'specimen_type', 'price', 'is_active')
    search_fields = ('code', 'name')


@admin.register(LabOrder)
class LabOrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient', 'ordered_by', 'status', 'priority', 'is_home_collection', 'created_at')
    list_filter = ('status', 'priority', 'is_home_collection')


@admin.register(LabResult)
class LabResultAdmin(admin.ModelAdmin):
    list_display = ('order', 'test', 'result_value', 'is_abnormal', 'result_date')
    list_filter = ('is_abnormal',)


@admin.register(HomeSampleVisit)
class HomeSampleVisitAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient', 'assigned_lab_tech', 'scheduled_date', 'scheduled_time', 'status')
    list_filter = ('status', 'scheduled_date')
