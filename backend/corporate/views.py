from datetime import timedelta

from django.db.models import Count, Q, Sum
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from visits.models import PatientVisit

from .models import CorporateClient, CorporateDocument, CorporateStaff
from .serializers import (
    CorporateClientSerializer,
    CorporateDocumentSerializer,
    CorporateStaffSerializer,
    CorporateVerificationSerializer,
    verify_corporate_patient,
)


class CorporateClientViewSet(viewsets.ModelViewSet):
    queryset = CorporateClient.objects.all()
    serializer_class = CorporateClientSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'is_active', 'industry']
    search_fields = ['name', 'code', 'registration_number', 'contact_person', 'contact_email']
    ordering_fields = ['name', 'created_at', 'contract_end']
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    @action(detail=True, methods=['post'], url_path='verify-status')
    def verify_status(self, request, pk=None):
        """Mark the corporate contract as verified (or suspend it)."""
        corporate = self.get_object()
        approved = request.data.get('approved', True)
        if approved:
            corporate.status = CorporateClient.Status.ACTIVE
            corporate.verified_at = timezone.now()
            corporate.verified_by = request.user
            corporate.save(update_fields=['status', 'verified_at', 'verified_by'])
        else:
            corporate.status = CorporateClient.Status.SUSPENDED
            corporate.verified_at = None
            corporate.save(update_fields=['status', 'verified_at'])
        return Response(self.get_serializer(corporate).data)

    @action(detail=True, methods=['post'], url_path='verify-patient')
    def verify_patient(self, request, pk=None):
        """Match a visiting patient against this corporate's staff roster."""
        corporate = self.get_object()
        payload = CorporateVerificationSerializer(data=request.data)
        payload.is_valid(raise_exception=True)
        data = dict(payload.validated_data)

        # When a patient id is supplied, pull the name/DOB from the record so
        # reception only has to provide the job card number.
        patient_id = data.get('patient')
        if patient_id:
            try:
                from patients.models import Patient
                patient = Patient.objects.select_related('user').get(pk=patient_id)
                data.setdefault('first_name', patient.user.first_name)
                data.setdefault('last_name', patient.user.last_name)
                data.setdefault('date_of_birth', patient.date_of_birth)
                data.setdefault('national_id', patient.national_id or '')
                data.setdefault('phone', patient.user.phone or '')
                data.setdefault(
                    'full_name',
                    f'{patient.user.first_name} {patient.user.last_name}'.strip(),
                )
            except Exception:
                pass

        result = verify_corporate_patient(corporate, data)
        return Response(result)

    @action(detail=True, methods=['get'], url_path='roster')
    def roster(self, request, pk=None):
        corporate = self.get_object()
        rows = corporate.staff.all()
        status_filter = request.query_params.get('status')
        if status_filter:
            rows = rows.filter(status=status_filter)
        eligible = request.query_params.get('eligible')
        if eligible in ('1', 'true', 'True'):
            today = timezone.localdate()
            rows = rows.filter(
                status=CorporateStaff.Status.ACTIVE,
                verification_status=CorporateStaff.Verification.VERIFIED,
            ).filter(
                Q(valid_from__isnull=True) | Q(valid_from__lte=today),
            ).filter(
                Q(valid_to__isnull=True) | Q(valid_to__gte=today),
            )
        return Response(CorporateStaffSerializer(rows, many=True).data)

    @action(detail=True, methods=['post'], url_path='sync-visits')
    def sync_visits(self, request, pk=None):
        """Attach previously unlinked corporate visits to their staff records."""
        corporate = self.get_object()
        staff_number = str(request.data.get('staff_number') or '').strip()
        visit_numbers = request.data.get('visits') or []
        staff = corporate.staff.filter(staff_number__iexact=staff_number).first() if staff_number else None
        updated = 0
        for visit in PatientVisit.objects.filter(
            visit_number__in=visit_numbers, corporate=corporate,
        ):
            visit.corporate_staff = staff
            visit.save(update_fields=['corporate_staff'])
            updated += 1
        return Response({'updated': updated, 'staff': staff.id if staff else None})


class CorporateStaffViewSet(viewsets.ModelViewSet):
    queryset = CorporateStaff.objects.select_related('corporate', 'patient__user').all()
    serializer_class = CorporateStaffSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['corporate', 'status', 'verification_status', 'relationship']
    search_fields = ['full_name', 'staff_number', 'national_id', 'phone', 'job_title', 'department']
    ordering_fields = ['full_name', 'staff_number', 'created_at']

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        staff = self.get_object()
        staff.verification_status = CorporateStaff.Verification.VERIFIED
        staff.verified_at = timezone.now()
        staff.verified_by = request.user
        staff.rejection_reason = ''
        staff.save(update_fields=['verification_status', 'verified_at', 'verified_by', 'rejection_reason'])
        return Response(self.get_serializer(staff).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        staff = self.get_object()
        staff.verification_status = CorporateStaff.Verification.REJECTED
        staff.verified_at = None
        staff.rejection_reason = request.data.get('reason', '')
        staff.save(update_fields=['verification_status', 'verified_at', 'rejection_reason'])
        return Response(self.get_serializer(staff).data)

    @action(detail=False, methods=['post'], url_path='bulk-upload')
    def bulk_upload(self, request):
        """Create or update roster rows from an uploaded staff list.

        Body: ``{ corporate, rows: [{staff_number, full_name, ...}] }``
        Existing staff numbers are updated rather than duplicated.
        """
        corporate_id = request.data.get('corporate')
        rows = request.data.get('rows') or []
        if not corporate_id:
            return Response({'detail': 'corporate is required.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            corporate = CorporateClient.objects.get(pk=corporate_id)
        except CorporateClient.DoesNotExist:
            return Response({'detail': 'Corporate not found.'}, status=status.HTTP_404_NOT_FOUND)

        created, updated, skipped = 0, 0, 0
        for row in rows:
            staff_number = str(row.get('staff_number') or '').strip()
            full_name = str(row.get('full_name') or '').strip()
            if not staff_number or not full_name:
                skipped += 1
                continue
            obj, was_created = CorporateStaff.objects.update_or_create(
                corporate=corporate,
                staff_number=staff_number,
                defaults={
                    'full_name': full_name,
                    'job_title': row.get('job_title', ''),
                    'department': row.get('department', ''),
                    'phone': row.get('phone', ''),
                    'email': row.get('email', ''),
                    'national_id': row.get('national_id', ''),
                    'status': row.get('status') or CorporateStaff.Status.ACTIVE,
                },
            )
            if was_created:
                created += 1
            else:
                updated += 1
        return Response({'created': created, 'updated': updated, 'skipped': skipped})


class CorporateDocumentViewSet(viewsets.ModelViewSet):
    queryset = CorporateDocument.objects.select_related('corporate', 'staff').all()
    serializer_class = CorporateDocumentSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['corporate', 'staff', 'doc_type', 'status']
    search_fields = ['title', 'reference', 'corporate__name', 'staff__full_name']
    ordering_fields = ['created_at', 'expires_at']
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def perform_create(self, serializer):
        serializer.save(uploaded_by=self.request.user)

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        doc = self.get_object()
        doc.status = CorporateDocument.Status.VERIFIED
        doc.verified_at = timezone.now()
        doc.verified_by = request.user
        doc.rejection_reason = ''
        doc.save(update_fields=['status', 'verified_at', 'verified_by', 'rejection_reason'])
        return Response(self.get_serializer(doc).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        doc = self.get_object()
        doc.status = CorporateDocument.Status.REJECTED
        doc.verified_at = None
        doc.rejection_reason = request.data.get('reason', '')
        doc.save(update_fields=['status', 'verified_at', 'rejection_reason'])
        return Response(self.get_serializer(doc).data)


class CorporateDashboardViewSet(viewsets.ViewSet):
    """Aggregated numbers for the corporate dashboard page."""

    ADMIN_ROLES = {
        'super_admin', 'tenant_admin', 'clinic_admin', 'hospital_admin',
        'branch_admin', 'admin',
    }

    @action(detail=False, methods=['post'], url_path='seed-demo')
    def seed_demo(self, request):
        """Load the demo corporate accounts into the current tenant."""
        role = getattr(request.user, 'role', '')
        if role not in self.ADMIN_ROLES:
            return Response(
                {'detail': 'Only a clinic administrator can load demo corporate data.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        from django.core.management import call_command
        try:
            call_command('seed_corporate')
        except Exception as exc:  # pragma: no cover - surfaced to the UI
            return Response(
                {'detail': f'Could not load demo corporate data: {exc}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        return Response({'detail': 'Demo corporate accounts loaded.'})

    def list(self, request):
        today = timezone.localdate()
        month_start = today.replace(day=1)

        corporates = CorporateClient.objects.all()
        staff = CorporateStaff.objects.all()
        documents = CorporateDocument.objects.all()

        active_corporates = corporates.filter(
            status=CorporateClient.Status.ACTIVE, is_active=True,
        ).count()

        eligible_staff = staff.filter(
            status=CorporateStaff.Status.ACTIVE,
            verification_status=CorporateStaff.Verification.VERIFIED,
        ).filter(
            Q(valid_from__isnull=True) | Q(valid_from__lte=today),
        ).filter(
            Q(valid_to__isnull=True) | Q(valid_to__gte=today),
        ).count()

        corporate_visits = PatientVisit.objects.filter(corporate__isnull=False)
        visits_month = corporate_visits.filter(arrived_at__date__gte=month_start)

        billed = visits_month.aggregate(total=Sum('consultation_fee'))['total'] or 0

        # Expiring staff cover in the next 30 days.
        soon = today + timedelta(days=30)
        expiring = staff.filter(
            status=CorporateStaff.Status.ACTIVE,
            valid_to__isnull=False,
            valid_to__gte=today,
            valid_to__lte=soon,
        ).count()

        rows = corporates.annotate(
            staff_count=Count('staff', distinct=True),
            eligible_count=Count(
                'staff',
                filter=Q(
                    staff__status=CorporateStaff.Status.ACTIVE,
                    staff__verification_status=CorporateStaff.Verification.VERIFIED,
                ),
                distinct=True,
            ),
            pending_docs=Count(
                'documents',
                filter=Q(documents__status=CorporateDocument.Status.PENDING),
                distinct=True,
            ),
        ).order_by('name')

        return Response({
            'generated_at': timezone.now(),
            'kpis': {
                'corporates_total': corporates.count(),
                'corporates_active': active_corporates,
                'corporates_pending': corporates.filter(
                    status=CorporateClient.Status.PENDING).count(),
                'staff_total': staff.count(),
                'staff_eligible': eligible_staff,
                'staff_pending': staff.filter(
                    verification_status=CorporateStaff.Verification.PENDING).count(),
                'documents_pending': documents.filter(
                    status=CorporateDocument.Status.PENDING).count(),
                'documents_verified': documents.filter(
                    status=CorporateDocument.Status.VERIFIED).count(),
                'expiring_staff': expiring,
                'visits_this_month': visits_month.count(),
                'billed_this_month': float(billed),
            },
            'corporates': [
                {
                    'id': c.id,
                    'name': c.name,
                    'code': c.code,
                    'status': c.status,
                    'status_label': c.get_status_display(),
                    'contract_end': c.contract_end,
                    'discount_rate': str(c.discount_rate or 0),
                    'staff_count': c.staff_count,
                    'eligible_count': c.eligible_count,
                    'pending_docs': c.pending_docs,
                }
                for c in rows
            ],
            'pending_documents': CorporateDocumentSerializer(
                documents.filter(status=CorporateDocument.Status.PENDING)
                .select_related('corporate', 'staff')[:12],
                many=True,
                context={'request': request},
            ).data,
            'expiring_cover': CorporateStaffSerializer(
                staff.filter(
                    status=CorporateStaff.Status.ACTIVE,
                    valid_to__isnull=False,
                    valid_to__gte=today,
                    valid_to__lte=soon,
                ).order_by('valid_to')[:10],
                many=True,
            ).data,
        })
