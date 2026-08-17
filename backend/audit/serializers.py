from rest_framework import serializers
from .models import AuditEvent


class AuditEventSerializer(serializers.ModelSerializer):
    actor_display = serializers.ReadOnlyField()
    action_label = serializers.SerializerMethodField()
    severity_label = serializers.SerializerMethodField()

    class Meta:
        model = AuditEvent
        fields = [
            'id', 'actor_user_id', 'actor_email', 'actor_role', 'actor_display',
            'action', 'action_label', 'severity', 'severity_label',
            'object_type', 'object_id', 'object_repr', 'description',
            'method', 'path', 'ip', 'user_agent', 'status_code',
            'payload_diff', 'extra', 'session_id',
            'created_at',
        ]
        read_only_fields = fields

    def get_action_label(self, obj):
        return obj.get_action_display()

    def get_severity_label(self, obj):
        return obj.get_severity_display()


class AuditEventExportSerializer(serializers.ModelSerializer):
    """Compact serializer for CSV / JSON exports."""
    actor_display = serializers.ReadOnlyField()
    action_label = serializers.SerializerMethodField()
    severity_label = serializers.SerializerMethodField()

    class Meta:
        model = AuditEvent
        fields = [
            'created_at', 'actor_display', 'actor_role', 'action', 'action_label',
            'severity', 'severity_label', 'object_type', 'object_id',
            'object_repr', 'description', 'method', 'path', 'ip',
            'status_code',
        ]

    def get_action_label(self, obj):
        return obj.get_action_display()

    def get_severity_label(self, obj):
        return obj.get_severity_display()
