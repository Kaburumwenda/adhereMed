from rest_framework import generics, permissions
from .models import Medication
from .serializers import MedicationSerializer, MedicationSearchSerializer


class MedicationListCreateView(generics.ListCreateAPIView):
    queryset = Medication.objects.filter(is_active=True)
    serializer_class = MedicationSerializer
    search_fields = ['generic_name', 'brand_names', 'category']
    filterset_fields = ['category', 'dosage_form', 'requires_prescription']


class MedicationDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Medication.objects.all()
    serializer_class = MedicationSerializer


class MedicationSearchView(generics.ListAPIView):
    serializer_class = MedicationSearchSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        q = self.request.query_params.get('q', '')
        if len(q) < 2:
            return Medication.objects.none()
        return Medication.objects.filter(
            is_active=True,
            generic_name__icontains=q,
        )[:20]
