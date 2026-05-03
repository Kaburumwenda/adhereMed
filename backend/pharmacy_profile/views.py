from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import PharmacyDetail, Delivery, Branch
from .serializers import PharmacyDetailSerializer, DeliverySerializer, BranchSerializer


class BranchViewSet(viewsets.ModelViewSet):
    queryset = Branch.objects.all()
    serializer_class = BranchSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'is_main']
    search_fields = ['name', 'address']
    ordering_fields = ['name', 'created_at']


class PharmacyDetailViewSet(viewsets.ModelViewSet):
    queryset = PharmacyDetail.objects.all()
    serializer_class = PharmacyDetailSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']

    @action(detail=True, methods=['post'], parser_classes=[MultiPartParser, FormParser], url_path='upload-logo')
    def upload_logo(self, request, pk=None):
        instance = self.get_object()
        logo = request.FILES.get('logo')
        if not logo:
            return Response({'error': 'No logo file provided.'}, status=status.HTTP_400_BAD_REQUEST)
        # Basic validation: image only
        if not logo.content_type.startswith('image/'):
            return Response({'error': 'File must be an image.'}, status=status.HTTP_400_BAD_REQUEST)
        # Remove old logo if exists
        if instance.logo:
            instance.logo.delete(save=False)
        instance.logo = logo
        instance.save(update_fields=['logo'])
        serializer = self.get_serializer(instance, context={'request': request})
        return Response(serializer.data)


class DeliveryViewSet(viewsets.ModelViewSet):
    queryset = Delivery.objects.select_related('transaction', 'assigned_to').all()
    serializer_class = DeliverySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'assigned_to']
    search_fields = ['recipient_name', 'recipient_phone', 'delivery_address']
    ordering_fields = ['created_at', 'scheduled_at', 'status']
    ordering = ['-created_at']

    @action(detail=True, methods=['post'])
    def update_status(self, request, pk=None):
        delivery = self.get_object()
        new_status = request.data.get('status')
        valid_statuses = [c[0] for c in Delivery.Status.choices]
        if new_status not in valid_statuses:
            return Response(
                {'error': f'Invalid status. Must be one of: {valid_statuses}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        delivery.status = new_status
        if new_status == 'delivered':
            from django.utils import timezone
            delivery.delivered_at = timezone.now()
        delivery.save()
        return Response(DeliverySerializer(delivery).data)
