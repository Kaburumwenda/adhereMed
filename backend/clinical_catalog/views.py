from rest_framework import generics, permissions, filters
from django.db.models import Q
from django_filters.rest_framework import DjangoFilterBackend
from .models import Allergy, ChronicCondition
from .serializers import AllergySerializer, ChronicConditionSerializer


class AllergyListCreateView(generics.ListCreateAPIView):
    serializer_class = AllergySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'is_active']
    search_fields = ['name', 'description', 'common_symptoms']
    ordering_fields = ['name', 'category']

    def get_queryset(self):
        return Allergy.objects.filter(is_active=True)

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]


class AllergyDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Allergy.objects.all()
    serializer_class = AllergySerializer
    permission_classes = [permissions.IsAdminUser]


class AllergySearchView(generics.ListAPIView):
    serializer_class = AllergySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        q = self.request.query_params.get('q', '')
        if len(q) < 1:
            return Allergy.objects.none()
        return Allergy.objects.filter(is_active=True, name__icontains=q)[:30]


class ChronicConditionListCreateView(generics.ListCreateAPIView):
    serializer_class = ChronicConditionSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'is_active']
    search_fields = ['name', 'icd_code', 'description']
    ordering_fields = ['name', 'category', 'icd_code']

    def get_queryset(self):
        return ChronicCondition.objects.filter(is_active=True)

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]


class ChronicConditionDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = ChronicCondition.objects.all()
    serializer_class = ChronicConditionSerializer
    permission_classes = [permissions.IsAdminUser]


class ChronicConditionSearchView(generics.ListAPIView):
    serializer_class = ChronicConditionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        q = self.request.query_params.get('q', '')
        if len(q) < 1:
            return ChronicCondition.objects.none()
        return ChronicCondition.objects.filter(
            is_active=True,
        ).filter(
            Q(name__icontains=q) | Q(icd_code__icontains=q)
        )[:30]
