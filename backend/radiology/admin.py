from django.contrib import admin
from .models import RadiologyOrder, RadiologyResult


@admin.register(RadiologyOrder)
class RadiologyOrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient', 'imaging_type', 'body_part', 'status', 'created_at')
    list_filter = ('status', 'imaging_type')


@admin.register(RadiologyResult)
class RadiologyResultAdmin(admin.ModelAdmin):
    list_display = ('order', 'radiologist', 'result_date')
