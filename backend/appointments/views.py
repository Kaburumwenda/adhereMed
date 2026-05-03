from rest_framework import viewsets, filters
from django_filters.rest_framework import DjangoFilterBackend

from .models import Appointment
from .serializers import AppointmentSerializer


class AppointmentViewSet(viewsets.ModelViewSet):
    queryset = Appointment.objects.select_related('patient__user', 'staff', 'department').all()
    serializer_class = AppointmentSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'appointment_date', 'staff', 'patient', 'department']
    search_fields = ['reason']
    ordering_fields = ['appointment_date', 'appointment_time', 'created_at']
