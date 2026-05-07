from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q
from rest_framework import filters, generics, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Medication, DrugInteraction
from .serializers import MedicationSerializer, MedicationSearchSerializer, DrugInteractionSerializer


class MedicationListCreateView(generics.ListCreateAPIView):
    queryset = Medication.objects.all()
    serializer_class = MedicationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['generic_name', 'brand_names', 'abbreviation', 'category', 'subcategory', 'strength']
    filterset_fields = ['category', 'dosage_form', 'requires_prescription', 'is_active']
    ordering_fields = ['generic_name', 'category', 'dosage_form', 'strength', 'created_at']
    ordering = ['generic_name']


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


class DrugInteractionViewSet(viewsets.ModelViewSet):
    queryset = (DrugInteraction.objects
                .select_related('drug_a', 'drug_b')
                .filter(is_active=True))
    serializer_class = DrugInteractionSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['severity', 'drug_a', 'drug_b']
    search_fields = ['drug_a__generic_name', 'drug_b__generic_name', 'description']
    ordering = ['-severity']


class CheckInteractionsView(APIView):
    """POST {medication_ids: [...], names: [...]} → list of matched interactions.

    Resolves each name to a Medication by case-insensitive generic_name match
    so it works for both prescription and dispensing flows that pass names.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        ids = list(request.data.get('medication_ids') or [])
        names = list(request.data.get('names') or [])
        med_qs = Medication.objects.none()
        if ids:
            med_qs = Medication.objects.filter(id__in=ids)
        if names:
            name_q = Q()
            for n in names:
                if n:
                    name_q |= Q(generic_name__iexact=n)
            if name_q:
                med_qs = (med_qs | Medication.objects.filter(name_q)).distinct()
        med_ids = list(med_qs.values_list('id', flat=True))
        if len(med_ids) < 2:
            return Response({'count': 0, 'interactions': [], 'unresolved_names': []})

        # Find pairwise interactions among the resolved set.
        inter = (DrugInteraction.objects
                 .select_related('drug_a', 'drug_b')
                 .filter(is_active=True, drug_a_id__in=med_ids, drug_b_id__in=med_ids))
        # filter pairs entirely within set already; serialize
        results = DrugInteractionSerializer(inter, many=True).data

        # severity ranking for client convenience
        rank = {'minor': 1, 'moderate': 2, 'major': 3, 'contraindicated': 4}
        max_sev = max((rank.get(r['severity'], 0) for r in results), default=0)

        resolved_names = set(med_qs.values_list('generic_name', flat=True))
        unresolved = [n for n in names if n and n.lower() not in {r.lower() for r in resolved_names}]

        return Response({
            'count': len(results),
            'highest_severity': next((k for k, v in rank.items() if v == max_sev), None),
            'interactions': results,
            'resolved_count': len(med_ids),
            'unresolved_names': unresolved,
        })

