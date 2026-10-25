from django.contrib import admin

from .models import ClinicSite


@admin.register(ClinicSite)
class ClinicSiteAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'kind', 'is_hq', 'is_active', 'city', 'created_at')
    list_filter = ('is_hq', 'is_active', 'kind')
    search_fields = ('name', 'code', 'place_name', 'city', 'phone', 'email')
    ordering = ('-is_hq', 'name')
