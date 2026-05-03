from rest_framework import viewsets, filters
from django_filters.rest_framework import DjangoFilterBackend

from .models import DispensingRecord
from .serializers import DispensingRecordSerializer


class DispensingRecordViewSet(viewsets.ModelViewSet):
    queryset = DispensingRecord.objects.select_related('dispensed_by').all()
    serializer_class = DispensingRecordSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['dispensed_by']
    search_fields = ['patient_name']
    ordering_fields = ['dispensed_at', 'total']
