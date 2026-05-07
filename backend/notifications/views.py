from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import Notification
from .serializers import NotificationSerializer


class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['type', 'is_read']
    search_fields = ['title', 'message']
    ordering_fields = ['created_at']

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return Response(NotificationSerializer(notification).data)

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        updated = self.get_queryset().filter(is_read=False).update(is_read=True)
        return Response({'status': 'ok', 'updated': updated})

    @action(detail=False, methods=['post'], url_path='scan-inventory')
    def scan_inventory(self, request):
        """Trigger the inventory alert scan in-process for the current tenant."""
        from django.core.management import call_command
        from io import StringIO
        days = request.data.get('days') or request.query_params.get('days') or 30
        try:
            days = int(days)
        except (TypeError, ValueError):
            days = 30
        out = StringIO()
        try:
            call_command('scan_alerts', days=days, quiet=True, stdout=out)
        except Exception as exc:
            return Response({'status': 'error', 'detail': str(exc)}, status=500)
        return Response({'status': 'ok', 'output': out.getvalue().strip(), 'days': days})

