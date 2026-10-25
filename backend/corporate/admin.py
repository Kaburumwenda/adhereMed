from django.contrib import admin

from .models import CorporateClient, CorporateDocument, CorporateStaff


class CorporateStaffInline(admin.TabularInline):
    model = CorporateStaff
    extra = 0
    fields = ('staff_number', 'full_name', 'job_title', 'status', 'verification_status', 'valid_to')


class CorporateDocumentInline(admin.TabularInline):
    model = CorporateDocument
    extra = 0
    fields = ('doc_type', 'title', 'reference', 'status', 'expires_at')


@admin.register(CorporateClient)
class CorporateClientAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'status', 'contract_end', 'is_active', 'active_staff_count')
    list_filter = ('status', 'is_active')
    search_fields = ('name', 'code', 'registration_number', 'contact_person')
    inlines = [CorporateStaffInline, CorporateDocumentInline]


@admin.register(CorporateStaff)
class CorporateStaffAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'staff_number', 'corporate', 'status',
                    'verification_status', 'valid_to')
    list_filter = ('status', 'verification_status', 'corporate')
    search_fields = ('full_name', 'staff_number', 'national_id', 'phone')


@admin.register(CorporateDocument)
class CorporateDocumentAdmin(admin.ModelAdmin):
    list_display = ('title', 'corporate', 'doc_type', 'status', 'expires_at', 'created_at')
    list_filter = ('doc_type', 'status')
    search_fields = ('title', 'reference', 'corporate__name')
