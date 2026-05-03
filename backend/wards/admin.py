from django.contrib import admin
from .models import Ward, Bed, Admission


@admin.register(Ward)
class WardAdmin(admin.ModelAdmin):
    list_display = ('name', 'type', 'capacity', 'daily_rate', 'is_active')
    list_filter = ('type', 'is_active')


@admin.register(Bed)
class BedAdmin(admin.ModelAdmin):
    list_display = ('bed_number', 'ward', 'status')
    list_filter = ('status', 'ward')


@admin.register(Admission)
class AdmissionAdmin(admin.ModelAdmin):
    list_display = ('patient', 'bed', 'admitting_doctor', 'admission_date', 'status')
    list_filter = ('status',)
