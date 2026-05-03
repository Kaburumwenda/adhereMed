from django.contrib import admin
from .models import Consultation


@admin.register(Consultation)
class ConsultationAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient', 'doctor', 'chief_complaint', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('patient__user__first_name', 'chief_complaint')
