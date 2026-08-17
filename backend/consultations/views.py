from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.utils import timezone

from .models import Consultation, ConsultationAddendum
from .serializers import ConsultationSerializer, ConsultationDetailSerializer, ConsultationAddendumSerializer


class ConsultationViewSet(viewsets.ModelViewSet):
    queryset = Consultation.objects.select_related('patient__user', 'doctor', 'appointment', 'triage', 'draft_owner').all()
    serializer_class = ConsultationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'doctor', 'status', 'disposition']
    search_fields = ['chief_complaint', 'diagnosis']
    ordering_fields = ['created_at', 'status']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return ConsultationDetailSerializer
        return ConsultationSerializer

    @action(detail=True, methods=['patch'], url_path='sign')
    def sign_encounter(self, request, pk=None):
        """Sign and lock a consultation. Sets status to SIGNED then LOCKED."""
        obj = self.get_object()
        if obj.status == Consultation.ConsultationStatus.LOCKED:
            return Response({'detail': 'Encounter is already locked.'}, status=status.HTTP_400_BAD_REQUEST)
        obj.status = Consultation.ConsultationStatus.LOCKED
        obj.signed_at = timezone.now()
        if 'disposition' in request.data:
            obj.disposition = request.data['disposition']
        obj.save(update_fields=['status', 'signed_at', 'disposition', 'updated_at'])
        return Response(ConsultationDetailSerializer(obj).data)

    @action(detail=True, methods=['post'], url_path='addendum')
    def add_addendum(self, request, pk=None):
        """Add an addendum to a locked consultation."""
        obj = self.get_object()
        if obj.status != Consultation.ConsultationStatus.LOCKED:
            return Response({'detail': 'Can only add addenda to locked encounters.'}, status=status.HTTP_400_BAD_REQUEST)
        addendum = ConsultationAddendum.objects.create(
            consultation=obj,
            author=request.user,
            content=request.data.get('content', ''),
        )
        return Response(ConsultationAddendumSerializer(addendum).data, status=status.HTTP_201_CREATED)


class ConsultationAddendumViewSet(viewsets.ModelViewSet):
    queryset = ConsultationAddendum.objects.select_related('consultation', 'author').all()
    serializer_class = ConsultationAddendumSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['consultation']
