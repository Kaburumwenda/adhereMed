from django.db.models import Q
from rest_framework import viewsets, generics, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from accounts.models import User
from doctors.models import DoctorProfile
from .models import Conversation, Message
from .serializers import (
    ConversationSerializer,
    MessageSerializer,
    StartConversationSerializer,
)


class ConversationViewSet(viewsets.ModelViewSet):
    """List conversations for the current user (patient or doctor)."""
    serializer_class = ConversationSerializer
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        user = self.request.user
        return Conversation.objects.filter(
            Q(patient=user) | Q(doctor=user)
        ).select_related('patient', 'doctor').prefetch_related('messages')

    def create(self, request, *args, **kwargs):
        """Start a new conversation with a doctor."""
        serializer = StartConversationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        doctor_user = User.objects.filter(
            id=serializer.validated_data['doctor_id'],
            role=User.Role.DOCTOR,
        ).first()
        if not doctor_user:
            return Response(
                {'detail': 'Doctor not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Get or create conversation
        conversation, created = Conversation.objects.get_or_create(
            patient=request.user,
            doctor=doctor_user,
            defaults={'subject': serializer.validated_data.get('subject', '')},
        )

        # Create the first message
        Message.objects.create(
            conversation=conversation,
            sender=request.user,
            content=serializer.validated_data['message'],
        )
        conversation.save()  # update updated_at

        return Response(
            ConversationSerializer(conversation, context={'request': request}).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    @action(detail=True, methods=['get', 'post'], url_path='messages')
    def messages(self, request, pk=None):
        """List or send messages in a conversation."""
        conversation = self.get_object()

        if request.method == 'GET':
            # Mark messages as read
            conversation.messages.filter(is_read=False).exclude(
                sender=request.user
            ).update(is_read=True)

            msgs = conversation.messages.select_related('sender').all()
            page = self.paginate_queryset(msgs)
            if page is not None:
                return self.get_paginated_response(
                    MessageSerializer(page, many=True).data
                )
            return Response(MessageSerializer(msgs, many=True).data)

        # POST - send a message
        content = request.data.get('content', '').strip()
        if not content:
            return Response(
                {'content': ['This field is required.']},
                status=status.HTTP_400_BAD_REQUEST,
            )
        msg = Message.objects.create(
            conversation=conversation,
            sender=request.user,
            content=content,
        )
        conversation.save()  # update updated_at
        return Response(
            MessageSerializer(msg).data,
            status=status.HTTP_201_CREATED,
        )
