from rest_framework import viewsets, filters, status
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import StaffProfile, Specialization
from .serializers import (
    StaffProfileSerializer, StaffCreateSerializer, StaffUpdateSerializer,
    SpecializationSerializer,
)


class SpecializationViewSet(viewsets.ModelViewSet):
    queryset = Specialization.objects.all()
    serializer_class = SpecializationSerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']


class StaffProfileViewSet(viewsets.ModelViewSet):
    queryset = StaffProfile.objects.select_related('user', 'department', 'specialization').all()
    serializer_class = StaffProfileSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['department', 'is_available', 'specialization', 'branch']
    search_fields = ['user__first_name', 'user__last_name', 'specialization__name']
    ordering_fields = ['created_at', 'specialization__name']

    def get_serializer_class(self):
        if self.action == 'create':
            return StaffCreateSerializer
        if self.action in ('update', 'partial_update'):
            return StaffUpdateSerializer
        return StaffProfileSerializer

    def create(self, request, *args, **kwargs):
        serializer = StaffCreateSerializer(
            data=request.data, context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()
        return Response(
            StaffProfileSerializer(profile).data,
            status=status.HTTP_201_CREATED,
        )

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        partial = kwargs.pop('partial', False)
        serializer = StaffUpdateSerializer(
            data=request.data, partial=partial,
        )
        serializer.is_valid(raise_exception=True)
        profile = serializer.update(instance, serializer.validated_data)
        return Response(StaffProfileSerializer(profile).data)

    def partial_update(self, request, *args, **kwargs):
        kwargs['partial'] = True
        return self.update(request, *args, **kwargs)
