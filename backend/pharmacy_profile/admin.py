from django.contrib import admin
from .models import PharmacyDetail, Branch


@admin.register(PharmacyDetail)
class PharmacyDetailAdmin(admin.ModelAdmin):
    list_display = ('name', 'license_number', 'accepts_insurance')


@admin.register(Branch)
class BranchAdmin(admin.ModelAdmin):
    list_display = ('name', 'phone', 'is_main', 'is_active', 'created_at')
    list_filter = ('is_main', 'is_active')
    search_fields = ('name', 'address')
