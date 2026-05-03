from django.contrib import admin
from .models import StaffProfile


@admin.register(StaffProfile)
class StaffProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'department', 'specialization', 'license_number', 'is_available')
    list_filter = ('department', 'is_available')
    search_fields = ('user__first_name', 'user__last_name', 'specialization')
