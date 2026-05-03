from rest_framework import viewsets, filters
from django_filters.rest_framework import DjangoFilterBackend

from .models import RadiologyOrder, RadiologyResult
from .serializers import RadiologyOrderSerializer, RadiologyResultSerializer


class RadiologyOrderViewSet(viewsets.ModelViewSet):
    queryset = RadiologyOrder.objects.select_related('patient__user', 'ordered_by', 'consultation').all()
    serializer_class = RadiologyOrderSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'imaging_type', 'patient', 'priority']
    search_fields = ['body_part', 'clinical_indication']
    ordering_fields = ['created_at', 'priority']


class RadiologyResultViewSet(viewsets.ModelViewSet):
    queryset = RadiologyResult.objects.select_related('order', 'radiologist').all()
    serializer_class = RadiologyResultSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['order']
    search_fields = ['findings', 'impression']
    ordering_fields = ['result_date']
