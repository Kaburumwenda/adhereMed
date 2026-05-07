from django.contrib import admin
from .models import Allergy, ChronicCondition


@admin.register(Allergy)
class AllergyAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'is_active', 'created_at')
    list_filter = ('category', 'is_active')
    search_fields = ('name', 'description', 'common_symptoms')
    list_editable = ('is_active',)
    ordering = ('category', 'name')


@admin.register(ChronicCondition)
class ChronicConditionAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'icd_code', 'is_active', 'created_at')
    list_filter = ('category', 'is_active')
    search_fields = ('name', 'icd_code', 'description')
    list_editable = ('is_active',)
    ordering = ('category', 'name')
