from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.db import connection

from .models import Prescription, PharmacyPrescription
from .serializers import (
    PrescriptionSerializer, PrescriptionCreateSerializer,
    PharmacyPrescriptionSerializer,
)


class PrescriptionViewSet(viewsets.ModelViewSet):
    queryset = Prescription.objects.select_related('patient__user', 'doctor', 'consultation').prefetch_related('items').all()
    serializer_class = PrescriptionSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'patient', 'doctor']
    search_fields = ['patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['created_at']

    def get_serializer_class(self):
        if self.action == 'create':
            return PrescriptionCreateSerializer
        return PrescriptionSerializer

    def perform_create(self, serializer):
        serializer.save(doctor=self.request.user)

    @action(detail=True, methods=['post'])
    def send_to_exchange(self, request, pk=None):
        prescription = self.get_object()

        if prescription.status != Prescription.Status.ACTIVE:
            return Response(
                {'detail': 'Only active prescriptions can be sent to exchange.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Build items payload for exchange
        items = []
        for item in prescription.items.all():
            items.append({
                'medication_id': item.medication_id,
                'medication_name': item.medication_name if not item.is_custom else item.custom_medication_name,
                'is_custom': item.is_custom,
                'dosage': item.dosage,
                'frequency': item.frequency,
                'duration': item.duration,
                'quantity': item.quantity,
                'instructions': item.instructions,
            })

        # Create exchange in public schema
        from exchange.models import PrescriptionExchange
        from exchange.views import _generate_quotes_for_exchange

        current_schema = connection.schema_name
        with connection.cursor() as cursor:
            cursor.execute('SET search_path TO "public"')

        try:
            exchange = PrescriptionExchange.objects.create(
                hospital_tenant_id=request.tenant.id if hasattr(request, 'tenant') else 0,
                patient_user_id=prescription.patient.user_id,
                prescription_ref=f'RX-{prescription.id}',
                items=items,
            )
            _generate_quotes_for_exchange(exchange)
        finally:
            with connection.cursor() as cursor:
                cursor.execute(f'SET search_path TO "{current_schema}"')

        prescription.status = Prescription.Status.SENT_TO_EXCHANGE
        prescription.save(update_fields=['status'])
        serializer = PrescriptionSerializer(prescription)
        return Response(serializer.data)


# ─── Pharmacy Prescription ViewSet ────────────────────────────────────────────

class PharmacyPrescriptionViewSet(viewsets.ModelViewSet):
    serializer_class = PharmacyPrescriptionSerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['patient_name', 'patient_phone']
    ordering_fields = ['created_at']

    def get_queryset(self):
        qs = PharmacyPrescription.objects.prefetch_related('items').filter(
            pharmacist__isnull=False
        ).order_by('-created_at')

        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)

        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')
        if date_from:
            qs = qs.filter(created_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(created_at__date__lte=date_to)

        return qs

    def perform_create(self, serializer):
        serializer.save(pharmacist=self.request.user)
