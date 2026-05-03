from django.contrib import admin
from .models import Triage


@admin.register(Triage)
class TriageAdmin(admin.ModelAdmin):
    list_display = ('patient', 'nurse', 'esi_level', 'arrival_mode', 'triage_time')
    list_filter = ('esi_level', 'arrival_mode')
