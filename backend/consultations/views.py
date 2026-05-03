from rest_framework import viewsets, filters
from django_filters.rest_framework import DjangoFilterBackend

from .models import Consultation
from .serializers import ConsultationSerializer, ConsultationDetailSerializer


class ConsultationViewSet(viewsets.ModelViewSet):
    queryset = Consultation.objects.select_related('patient__user', 'doctor', 'appointment').all()
    serializer_class = ConsultationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'doctor']
    search_fields = ['chief_complaint', 'diagnosis']
    ordering_fields = ['created_at']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return ConsultationDetailSerializer
        return ConsultationSerializer
