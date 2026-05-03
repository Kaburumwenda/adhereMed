from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    recipient_name = serializers.CharField(source='recipient.full_name', read_only=True)

    class Meta:
        model = Notification
        fields = [
            'id', 'recipient', 'recipient_name',
            'type', 'title', 'message', 'data',
            'is_read', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']
