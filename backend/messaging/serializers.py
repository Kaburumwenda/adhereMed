from rest_framework import serializers

from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.full_name', read_only=True)

    class Meta:
        model = Message
        fields = ['id', 'conversation', 'sender', 'sender_name', 'content', 'is_read', 'created_at']
        read_only_fields = ['id', 'sender', 'sender_name', 'created_at']


class ConversationSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.full_name', read_only=True)
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True)
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id', 'patient', 'patient_name', 'doctor', 'doctor_name',
            'subject', 'is_active', 'last_message', 'unread_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        if msg:
            return {
                'content': msg.content[:100],
                'sender_name': msg.sender.full_name,
                'created_at': msg.created_at.isoformat(),
                'is_read': msg.is_read,
            }
        return None

    def get_unread_count(self, obj):
        user = self.context.get('request')
        if user:
            return obj.messages.filter(is_read=False).exclude(sender=user.user).count()
        return 0


class StartConversationSerializer(serializers.Serializer):
    doctor_id = serializers.IntegerField()
    subject = serializers.CharField(max_length=255, required=False, default='')
    message = serializers.CharField()
