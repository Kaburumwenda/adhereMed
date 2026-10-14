from django.contrib import admin
from .models import (
    DocumentCategory, Tag, Document, DocumentVersion,
    DocumentShare, DocumentComment, DocumentActivity, SignatureRequest,
)


class DocumentCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'parent', 'color', 'is_active', 'created_at')
    list_filter = ('is_active',)
    search_fields = ('name', 'description')


class TagAdmin(admin.ModelAdmin):
    list_display = ('name', 'color', 'created_at')
    search_fields = ('name',)


class DocumentVersionInline(admin.TabularInline):
    model = DocumentVersion
    extra = 0
    readonly_fields = ('version_number', 'file_size', 'file_type', 'checksum', 'uploaded_by', 'created_at')


@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ('title', 'reference_number', 'category', 'status', 'priority',
                     'branch', 'uploaded_by', 'checked_out_by', 'is_deleted', 'updated_at')
    list_filter = ('status', 'priority', 'is_deleted', 'category')
    search_fields = ('title', 'description', 'reference_number')
    inlines = [DocumentVersionInline]


admin.site.register(DocumentCategory, DocumentCategoryAdmin)
admin.site.register(Tag, TagAdmin)
admin.site.register(DocumentVersion)
admin.site.register(DocumentShare)
admin.site.register(DocumentComment)
admin.site.register(DocumentActivity)
admin.site.register(SignatureRequest)
