from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.utils import timezone

from .models import Triage
from .serializers import TriageSerializer


class TriageViewSet(viewsets.ModelViewSet):
    queryset = Triage.objects.select_related('patient__user', 'nurse').all()
    serializer_class = TriageSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['esi_level', 'status', 'patient']
    search_fields = ['chief_complaint', 'patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['esi_level', 'triage_time']

    def perform_create(self, serializer):
        """Auto-assign nurse from the authenticated user if not provided."""
        if not serializer.validated_data.get('nurse'):
            serializer.save(nurse=self.request.user)
        else:
            serializer.save()

    @action(detail=True, methods=['patch'], url_path='complete')
    def complete_triage(self, request, pk=None):
        """Mark triage as completed — fires triage.completed event."""
        obj = self.get_object()
        obj.status = Triage.TriageStatus.COMPLETED
        obj.completed_at = timezone.now()
        # Update any fields submitted with this patch
        serializer = self.get_serializer(obj, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save(status=obj.status, completed_at=obj.completed_at)
        return Response(serializer.data)
