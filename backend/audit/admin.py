from django.contrib import admin

from .models import AuditEvent


@admin.register(AuditEvent)
class AuditEventAdmin(admin.ModelAdmin):
    list_display = ('created_at', 'actor_email', 'action', 'object_type',
                    'object_repr', 'method', 'status_code', 'severity')
    list_filter = ('action', 'severity', 'object_type', 'method', 'created_at')
    search_fields = ('actor_email', 'object_repr', 'description', 'path', 'ip')
    readonly_fields = [f.name for f in AuditEvent._meta.fields]
    date_hierarchy = 'created_at'

    def has_add_permission(self, request):
        # Audit trail is append-only — no manual adds via admin.
        return False

    def has_change_permission(self, request, obj=None):
        return False
