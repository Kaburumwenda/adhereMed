from rest_framework import viewsets, filters
from django_filters.rest_framework import DjangoFilterBackend

from .models import Triage
from .serializers import TriageSerializer


class TriageViewSet(viewsets.ModelViewSet):
    queryset = Triage.objects.select_related('patient__user', 'nurse').all()
    serializer_class = TriageSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['esi_level']
    search_fields = ['chief_complaint', 'patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['esi_level', 'triage_time']
