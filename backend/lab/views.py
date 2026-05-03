from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.db import connection

from .models import LabTestCatalog, LabOrder, LabResult, HomeSampleVisit
from .serializers import (
    LabTestCatalogSerializer,
    LabOrderSerializer,
    LabResultSerializer,
    HomeSampleVisitSerializer,
)


class LabTestCatalogViewSet(viewsets.ModelViewSet):
    queryset = LabTestCatalog.objects.all()
    serializer_class = LabTestCatalogSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'department']
    search_fields = ['name', 'code']
    ordering_fields = ['name', 'code']


class LabOrderViewSet(viewsets.ModelViewSet):
    queryset = LabOrder.objects.select_related('patient__user', 'ordered_by', 'consultation').prefetch_related('tests', 'results').all()
    serializer_class = LabOrderSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'patient', 'priority', 'is_home_collection']
    search_fields = ['patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['created_at', 'priority']

    def perform_create(self, serializer):
        serializer.save(ordered_by=self.request.user)

    @action(detail=True, methods=['post'])
    def send_to_lab(self, request, pk=None):
        """Send a lab order to the lab exchange so independent labs can accept it."""
        lab_order = self.get_object()

        if lab_order.status == 'cancelled':
            return Response(
                {'detail': 'Cannot send a cancelled order to lab.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Build tests payload
        tests_data = []
        for test in lab_order.tests.all():
            tests_data.append({
                'test_name': test.name,
                'code': test.code,
                'specimen_type': test.specimen_type,
                'instructions': test.instructions,
            })

        # Create exchange in public schema
        from exchange.models import LabOrderExchange

        current_schema = connection.schema_name
        with connection.cursor() as cursor:
            cursor.execute('SET search_path TO "public"')

        try:
            patient_name = ''
            if lab_order.patient and lab_order.patient.user:
                u = lab_order.patient.user
                patient_name = f'{u.first_name} {u.last_name}'.strip()

            doctor_name = ''
            if lab_order.ordered_by:
                doctor_name = f'{lab_order.ordered_by.first_name} {lab_order.ordered_by.last_name}'.strip()

            LabOrderExchange.objects.create(
                source_tenant_id=request.tenant.id if hasattr(request, 'tenant') else 0,
                source_tenant_name=request.tenant.name if hasattr(request, 'tenant') else '',
                ordering_doctor_user_id=lab_order.ordered_by_id,
                ordering_doctor_name=doctor_name,
                patient_user_id=lab_order.patient.user_id if lab_order.patient else 0,
                patient_name=patient_name,
                tests=tests_data,
                priority=lab_order.priority,
                clinical_notes=lab_order.clinical_notes or '',
                is_home_collection=lab_order.is_home_collection,
            )
        finally:
            with connection.cursor() as cursor:
                cursor.execute(f'SET search_path TO "{current_schema}"')

        return Response({'detail': 'Lab order sent to lab exchange successfully.'})


class LabResultViewSet(viewsets.ModelViewSet):
    queryset = LabResult.objects.select_related('order', 'test', 'performed_by', 'verified_by').all()
    serializer_class = LabResultSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['order', 'test', 'is_abnormal']
    search_fields = ['test__name']
    ordering_fields = ['result_date']


class HomeSampleVisitViewSet(viewsets.ModelViewSet):
    queryset = HomeSampleVisit.objects.select_related('lab_order', 'patient__user', 'assigned_lab_tech', 'scheduled_by').all()
    serializer_class = HomeSampleVisitSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'scheduled_date', 'assigned_lab_tech']
    search_fields = ['patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['scheduled_date', 'scheduled_time']
