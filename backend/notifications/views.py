import threading

from django.db import connection
from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import Notification
from .serializers import NotificationSerializer

#: ``notifications`` lives in ``TENANT_APPS``, so its tables exist only in
#: tenant schemas. Only positive results are cached: a tenant schema can appear
#: *after* this process started (background provisioning), so caching a
#: negative would wrongly keep a brand-new tenant's inbox empty until restart.
_TABLE_READY_CACHE = {}
_TABLE_READY_LOCK = threading.Lock()


def _notifications_ready() -> bool:
    """True when ``notifications_notification`` exists in the active schema.

    Platform/superadmin traffic is served from the ``public`` schema, which has
    no notifications tables. Querying the model there raised::

        ProgrammingError: relation "notifications_notification" does not exist

    ...and turned every page load (the TopBar inbox polls this endpoint) into a
    500. Detecting it up front lets the endpoint answer with an empty list
    instead, which is semantically correct - the public schema simply has no
    notifications for anyone.
    """
    schema = getattr(connection, 'schema_name', None)
    if not schema or schema == 'public':
        # Fast path: no query needed.
        return False

    with _TABLE_READY_LOCK:
        if _TABLE_READY_CACHE.get(schema):
            return True

    try:
        ready = Notification._meta.db_table in connection.introspection.table_names()
    except Exception:
        # A diagnostics query must never be the thing that raises the 500.
        ready = False

    if ready:
        with _TABLE_READY_LOCK:
            _TABLE_READY_CACHE[schema] = True
    return ready


class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['type', 'is_read']
    search_fields = ['title', 'message']
    ordering_fields = ['created_at']

    def get_queryset(self):
        if not _notifications_ready():
            # ``none()`` short-circuits: no SQL is emitted, so it is safe even
            # though the table does not exist.
            return Notification.objects.none()
        return Notification.objects.filter(recipient=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return Response(NotificationSerializer(notification).data)

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        if not _notifications_ready():
            return Response({'status': 'ok', 'updated': 0})
        updated = self.get_queryset().filter(is_read=False).update(is_read=True)
        return Response({'status': 'ok', 'updated': updated})

    @action(detail=False, methods=['post'], url_path='scan-inventory')
    def scan_inventory(self, request):
        """Trigger the inventory alert scan in-process for the current tenant."""
        from django.core.management import call_command
        from io import StringIO

        if not _notifications_ready():
            # The scan writes to tenant-only tables; there is nothing to do in
            # the public schema. Answer cleanly instead of raising.
            return Response({
                'status': 'skipped',
                'output': '',
                'detail': 'Inventory alerts are tenant-scoped.',
            })

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

