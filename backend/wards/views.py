from rest_framework import viewsets, filters, status
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import Ward, Bed, Admission
from .serializers import WardSerializer, BedSerializer, AdmissionSerializer


class WardViewSet(viewsets.ModelViewSet):
    queryset = Ward.objects.prefetch_related('beds').all()
    serializer_class = WardSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['type', 'is_active']
    search_fields = ['name']
    ordering_fields = ['name', 'capacity']

    # ------------------------------------------------------------------
    # Bed sync helpers
    # ------------------------------------------------------------------
    def _sync_beds(self, ward, available_beds=None):
        """
        Ensure bed records match the ward's capacity.
        If available_beds is given, mark that many beds as 'available'
        and the rest as 'occupied'. Otherwise keep existing statuses.
        """
        capacity = ward.capacity
        existing = list(ward.beds.order_by('bed_number'))
        existing_count = len(existing)

        # Add beds if capacity grew
        if existing_count < capacity:
            existing_numbers = {b.bed_number for b in existing}
            new_beds = []
            n, added = 1, 0
            while added < (capacity - existing_count):
                bn = str(n)
                if bn not in existing_numbers:
                    new_beds.append(Bed(ward=ward, bed_number=bn, status='available'))
                    added += 1
                n += 1
            Bed.objects.bulk_create(new_beds)
            existing = list(ward.beds.order_by('bed_number'))

        # Remove beds if capacity shrank (remove available first, then occupied)
        elif existing_count > capacity:
            excess = existing_count - capacity
            avail_ids = [b.id for b in existing if b.status == 'available']
            occ_ids   = [b.id for b in existing if b.status != 'available']
            to_delete = (avail_ids + occ_ids)[:excess]
            Bed.objects.filter(id__in=to_delete).delete()
            existing = list(ward.beds.order_by('bed_number'))

        # Update statuses when available_beds explicitly provided
        if available_beds is not None:
            avail = max(0, min(int(available_beds), capacity))
            all_beds = list(ward.beds.order_by('bed_number'))
            avail_ids = [b.id for b in all_beds[:avail]]
            occ_ids   = [b.id for b in all_beds[avail:]]
            if avail_ids:
                Bed.objects.filter(id__in=avail_ids).update(status='available')
            if occ_ids:
                Bed.objects.filter(id__in=occ_ids).update(status='occupied')

    def create(self, request, *args, **kwargs):
        # available_beds is read_only in the serializer; grab it from raw data
        available_beds = request.data.get('available_beds')
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ward = serializer.save()
        # Default: create all beds as available
        avail = int(available_beds) if available_beds is not None else ward.capacity
        self._sync_beds(ward, available_beds=avail)
        headers = self.get_success_headers(serializer.data)
        return Response(self.get_serializer(ward).data, status=status.HTTP_201_CREATED, headers=headers)

    def update(self, request, *args, **kwargs):
        available_beds = request.data.get('available_beds')
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        ward = serializer.save()
        self._sync_beds(ward, available_beds=available_beds)
        return Response(self.get_serializer(ward).data)


class BedViewSet(viewsets.ModelViewSet):
    queryset = Bed.objects.select_related('ward').all()
    serializer_class = BedSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'ward']
    search_fields = ['bed_number']
    ordering_fields = ['bed_number']


class AdmissionViewSet(viewsets.ModelViewSet):
    queryset = Admission.objects.select_related('patient__user', 'bed__ward', 'admitting_doctor').all()
    serializer_class = AdmissionSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'patient']
    search_fields = ['patient__user__first_name', 'patient__user__last_name', 'reason']
    ordering_fields = ['admission_date', 'created_at']
