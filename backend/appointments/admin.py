from django.contrib import admin
from .models import Appointment


@admin.register(Appointment)
class AppointmentAdmin(admin.ModelAdmin):
    list_display = ('patient', 'staff', 'department', 'appointment_date', 'appointment_time', 'status')
    list_filter = ('status', 'department', 'appointment_date')
