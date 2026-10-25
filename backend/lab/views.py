from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.core.files.base import ContentFile
from django_filters.rest_framework import DjangoFilterBackend
from django.db import connection, transaction
from django.db.models import Q
from django.utils import timezone

from clinic_sites.mixins import ClinicSiteScopedMixin
from .models import (
    LabTestCatalog, LabOrder, LabResult, HomeSampleVisit,
    LabPanel, ReferringFacility, ReferringDoctor, Instrument,
    Specimen, QualityControlRun,
    LabInvoice, LabInvoiceItem, LabInvoicePayment,
    ReportTemplate, LabOrderExtra, LabResultAudit,
    LabReagent, ReagentLot, ReagentTransaction,
    LabStaffProfile, LabOrderAuthorization, LabAuthorizationEvent,
    PERFORM_ROLES, VERIFY_ROLES,
)
from .serializers import (
    LabTestCatalogSerializer,
    SeedApplySerializer,
    LabOrderSerializer,
    LabResultSerializer,
    HomeSampleVisitSerializer,
    LabPanelSerializer,
    ReferringFacilitySerializer,
    ReferringDoctorSerializer,
    InstrumentSerializer,
    SpecimenSerializer,
    QualityControlRunSerializer,
    LabInvoiceSerializer,
    LabInvoiceItemSerializer,
    LabInvoicePaymentSerializer,
    ReportTemplateSerializer,
    LabOrderExtraSerializer,
    LabResultAuditSerializer,
    LabReagentSerializer,
    ReagentLotSerializer,
    ReagentTransactionSerializer,
    LabStaffProfileSerializer,
    LabOrderAuthorizationSerializer,
    LabAuthorizationEventSerializer,
)
from .authorisation import (
    AuthorisationError, decode_signature, resolve_signer, apply_signoff,
    revoke_signoff as revoke_order_signoff, signer_roster,
)
from .patient_share import refresh_order_snapshot, sync_order_to_patient


def _truthy(value):
    """Multipart sends booleans as strings — normalise them."""
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {'1', 'true', 'yes', 'on'}


class LabStaffViewSet(viewsets.ViewSet):
    """Roster of lab-bench staff who can sign results.

    The laboratory often shares one workstation, so the sign-off dialog lists
    these people and asks the chosen one for their own password.
    """

    def list(self, request):
        role = (request.query_params.get('role') or 'verified').strip()
        if role not in {'performed', 'verified'}:
            role = 'verified'
        roster = signer_roster(request, role)
        data = LabStaffProfileSerializer(
            roster, many=True, context={'request': request},
        ).data
        return Response({
            'role': role,
            'count': len(data),
            'results': data,
        })

    @action(detail=False, methods=['get'])
    def me(self, request):
        """The caller's own bench profile, so the dialog can pre-select them."""
        profile, _ = LabStaffProfile.objects.get_or_create(user=request.user)
        return Response(
            LabStaffProfileSerializer(profile, context={'request': request}).data
        )


class LabTestCatalogViewSet(viewsets.ModelViewSet):
    queryset = LabTestCatalog.objects.all()
    serializer_class = LabTestCatalogSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'department']
    search_fields = ['name', 'code']
    ordering_fields = ['name', 'code']

    @action(detail=False, methods=['get'], url_path='seed-preview')
    def seed_preview(self, request):
        """The demo catalogue merged with this clinic's own edits.

        Nothing is written — this is the page the clinic reviews before adding
        anything to its lab.
        """
        from .seed_service import build_seed_preview
        return Response(build_seed_preview())

    @action(detail=False, methods=['post'], url_path='seed-apply')
    def seed_apply(self, request):
        """Add/refresh the selected demo entries in this clinic's catalogue."""
        serializer = SeedApplySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        from .seed_service import apply_seed
        result = apply_seed(
            tests=serializer.validated_data.get('tests') or [],
            panels=serializer.validated_data.get('panels') or [],
            user=request.user,
        )
        return Response(result, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='seed-reset')
    def seed_reset(self, request):
        """Forget this clinic's seed edits (all, or a single entry)."""
        from .seed_service import reset_customization
        code = (request.data.get('code') or '').strip() or None
        kind = (request.data.get('kind') or '').strip() or None
        removed = reset_customization(code=code, kind=kind)
        return Response({
            'detail': f'{removed} entr{"y" if removed == 1 else "ies"} reset to the template.',
            'removed': removed,
        })

    @action(detail=False, methods=['post'])
    def seed_demo(self, request):
        """Add every demo test and panel (kept for backwards compatibility)."""
        from .seed_data import seed_lab_catalog
        result = seed_lab_catalog()
        return Response({
            'detail': 'Lab catalog seeded successfully.',
            **result,
        }, status=status.HTTP_200_OK)


class LabOrderViewSet(ClinicSiteScopedMixin, viewsets.ModelViewSet):
    queryset = LabOrder.objects.select_related('patient__user', 'ordered_by', 'consultation', 'clinic_site').prefetch_related('tests', 'results').all()
    serializer_class = LabOrderSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'patient', 'priority', 'is_home_collection', 'ordered_by', 'clinic_site']
    search_fields = ['patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['created_at', 'priority']

    def get_queryset(self):
        queryset = super().get_queryset().select_related(
            'authorization__performed_by', 'authorization__verified_by',
        )
        # `?authorization=verified|unverified|signed|awaiting` powers the
        # Authorisation tab on the lab orders page.
        state = (self.request.query_params.get('authorization') or '').strip().lower()
        if state in {'verified', 'signed'}:
            queryset = queryset.filter(authorization__verified_at__isnull=False)
        elif state in {'unverified', 'awaiting', 'pending'}:
            # Anything that has no verifier signature yet (including no row at all).
            queryset = queryset.filter(
                Q(authorization__isnull=True) | Q(authorization__verified_at__isnull=True),
            )
        elif state == 'performed':
            queryset = queryset.filter(authorization__performed_at__isnull=False)
        return queryset

    def perform_create(self, serializer):
        lab_order = serializer.save(ordered_by=self.request.user)
        # Tell the patient portal a test has been requested.
        sync_order_to_patient(lab_order)

    def perform_update(self, serializer):
        lab_order = serializer.save()
        # A PATCH can change status/priority/notes — refresh what the patient sees.
        refresh_order_snapshot(lab_order.pk)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """Cancel a lab order that is not yet completed."""
        lab_order = self.get_object()
        if lab_order.status == LabOrder.Status.COMPLETED:
            return Response(
                {'detail': 'Cannot cancel a completed order.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        lab_order.status = LabOrder.Status.CANCELLED
        lab_order.save(update_fields=['status', 'updated_at'])
        refresh_order_snapshot(lab_order.pk)
        return Response(LabOrderSerializer(lab_order).data)

    @action(detail=True, methods=['post'])
    def advance_status(self, request, pk=None):
        """Advance the order to the next status in the workflow."""
        lab_order = self.get_object()
        flow = {
            LabOrder.Status.PENDING: LabOrder.Status.SAMPLE_COLLECTED,
            LabOrder.Status.SAMPLE_COLLECTED: LabOrder.Status.PROCESSING,
            LabOrder.Status.PROCESSING: LabOrder.Status.COMPLETED,
        }
        if lab_order.status not in flow:
            return Response(
                {'detail': f'No next status for {lab_order.status}.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        lab_order.status = flow[lab_order.status]
        lab_order.save(update_fields=['status', 'updated_at'])
        # Keep the patient's pipeline view in step with the bench.
        refresh_order_snapshot(lab_order.pk)
        return Response(LabOrderSerializer(lab_order).data)

    @action(detail=True, methods=['post'])
    def add_result(self, request, pk=None):
        """Add a result for a single test on this order.

        Accepts JSON or multipart. Multipart lets the client attach an
        optional scanned report (`attachment`) alongside the typed value.
        """
        lab_order = self.get_object()
        test_id = request.data.get('test')
        if not test_id:
            return Response({'detail': 'test is required.'}, status=status.HTTP_400_BAD_REQUEST)

        upload = request.FILES.get('attachment')

        payload = {
            'order': lab_order.pk,
            'test': test_id,
            'result_value': request.data.get('result_value', ''),
            'unit': request.data.get('unit', ''),
            'is_abnormal': _truthy(request.data.get('is_abnormal', False)),
            'comments': request.data.get('comments', ''),
            'performed_by': request.user.pk,
        }
        if upload:
            payload['attachment'] = upload

        serializer = LabResultSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        refresh_order_snapshot(lab_order.pk)
        return Response(LabResultSerializer(result).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def sign(self, request, pk=None):
        """Record a bench sign-off (performer or verifier) for this order.

        Body (JSON)::

            {
              "role": "performed" | "verified",
              "user_id": 12,                  # picked from the roster
              "password": "…",                # that user's own password
              "signature": "data:image/png;base64,…",   # optional if on file
              "title": "Senior Medical Laboratory Scientist",
              "notes": "…",
              "save_signature": true          # keep this signature on file
            }
        """
        lab_order = self.get_object()
        role = (request.data.get('role') or '').strip()

        # Only a completed order can be verified — a report that is still being
        # processed has no results worth releasing.
        if role == 'verified' and lab_order.status != LabOrder.Status.COMPLETED:
            return Response({
                'detail': (
                    'Complete the order before verification. Only completed '
                    'orders can be authorised.'
                ),
                'code': 'order_not_completed',
                'field': 'status',
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            upload = decode_signature(request.data.get('signature'))
            user, profile, identity = resolve_signer(
                request,
                role=role,
                user_id=request.data.get('user_id'),
                password=request.data.get('password') or '',
            )
            # No fresh signature: fall back to the one already on file.
            if upload is None:
                if not (profile and profile.signature):
                    raise AuthorisationError(
                        'Draw or upload your signature before signing.',
                        field='signature',
                    )
                profile.signature.open('rb')
                upload = ContentFile(profile.signature.read(), name='signature-on-file.png')
                profile.signature.close()

            authorization = apply_signoff(
                request, lab_order, role=role, user=user, profile=profile,
                signature_upload=upload,
                title=request.data.get('title') or '',
                notes=request.data.get('notes') or '',
                save_signature=_truthy(request.data.get('save_signature')),
                identity=identity,
            )
        except AuthorisationError as exc:
            return Response(
                {'detail': exc.message, 'code': exc.code, 'field': exc.field},
                status=status.HTTP_400_BAD_REQUEST,
            )

        lab_order.refresh_from_db()
        # A verifier signature releases the report to the patient; a performer
        # signature alone keeps it hidden.
        refresh_order_snapshot(lab_order.pk)
        return Response({
            'detail': (
                'Result signed as performed.' if role == 'performed'
                else 'Result authorised and signed as verified.'
            ),
            'authorization': LabOrderAuthorizationSerializer(
                authorization, context={'request': request},
            ).data,
            'order': LabOrderSerializer(lab_order, context={'request': request}).data,
        })

    @action(detail=True, methods=['post'], url_path='revoke-signoff')
    def revoke_signoff(self, request, pk=None):
        """Withdraw a performer/verifier signature from this order."""
        lab_order = self.get_object()
        role = (request.data.get('role') or '').strip()
        if role not in {'performed', 'verified'}:
            return Response(
                {'detail': 'role must be "performed" or "verified".'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            authorization = revoke_order_signoff(
                request, lab_order, role=role, actor=request.user,
                notes=request.data.get('notes') or '',
            )
        except AuthorisationError as exc:
            return Response({'detail': exc.message}, status=status.HTTP_400_BAD_REQUEST)

        lab_order.refresh_from_db()
        # Withdrawing the verifier signature pulls the report back in.
        refresh_order_snapshot(lab_order.pk)
        return Response({
            'detail': 'Signature withdrawn.',
            'authorization': LabOrderAuthorizationSerializer(
                authorization, context={'request': request},
            ).data,
            'order': LabOrderSerializer(lab_order, context={'request': request}).data,
        })

    @action(detail=True, methods=['get'], url_path='report-pdf')
    def report_pdf(self, request, pk=None):
        """Render a premium A4 laboratory report for this order.

        Includes analyte-level results with reference ranges and flags, the
        specimen trail, clinical notes and an authorisation block. Orders with
        unverified results come out watermarked ``PRELIMINARY``.
        """
        from django.http import HttpResponse

        try:
            from .pdf_reports import build_lab_order_report
        except ImportError:
            return Response({'detail': 'reportlab not installed.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        lab_order = (
            LabOrder.objects
            .select_related(
                'patient__user', 'ordered_by', 'consultation', 'clinic_site',
                'authorization',
            )
            .prefetch_related(
                'tests',
                'specimens',
                'results__test',
                'results__performed_by',
                'results__verified_by',
            )
            .filter(pk=self.get_object().pk)
            .first()
        )
        pdf = build_lab_order_report(lab_order, request=request)
        filename = f'lab_report_{lab_order.id:05d}.pdf'
        return HttpResponse(
            pdf,
            content_type='application/pdf',
            headers={'Content-Disposition': f'inline; filename="{filename}"'},
        )

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

    def _audit(self, result, new_value, reason):
        LabResultAudit.objects.create(
            result=result, changed_by=self.request.user,
            previous_value=result.result_value or '', new_value=new_value,
            reason=reason or 'Amendment',
        )

    def perform_update(self, serializer):
        old_value = serializer.instance.result_value or ''
        old_attachment = serializer.instance.attachment.name if serializer.instance.attachment else ''
        serializer.save()
        instance = serializer.instance
        if instance.result_value != old_value:
            self._audit(instance, instance.result_value, 'Edited')
        new_attachment = instance.attachment.name if instance.attachment else ''
        if new_attachment != old_attachment:
            self._audit(
                instance, instance.result_value,
                'Attachment replaced' if new_attachment else 'Attachment removed',
            )

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        """Pathologist / supervisor verifies a result."""
        result = self.get_object()
        result.verified_by = request.user
        result.save(update_fields=['verified_by'])
        return Response(LabResultSerializer(result).data)

    @action(detail=True, methods=['post'])
    def unverify(self, request, pk=None):
        """Remove verification (e.g., needs correction)."""
        result = self.get_object()
        result.verified_by = None
        result.save(update_fields=['verified_by'])
        self._audit(result, result.result_value, 'Unverified')
        return Response(LabResultSerializer(result).data)


class HomeSampleVisitViewSet(viewsets.ModelViewSet):
    queryset = HomeSampleVisit.objects.select_related('lab_order', 'patient__user', 'assigned_lab_tech', 'scheduled_by').all()
    serializer_class = HomeSampleVisitSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'scheduled_date', 'assigned_lab_tech', 'lab_order']
    search_fields = ['patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['scheduled_date', 'scheduled_time']


# ===================== Lab Tenant viewsets =====================


def _next_accession_number():
    today = timezone.now()
    prefix = f'A{today.strftime("%y%m%d")}'
    last = (
        Specimen.objects.filter(accession_number__startswith=prefix)
        .order_by('-accession_number').first()
    )
    seq = 1
    if last and last.accession_number:
        try:
            seq = int(last.accession_number.replace(prefix, '')) + 1
        except ValueError:
            seq = 1
    return f'{prefix}{seq:04d}'


def _next_invoice_number():
    today = timezone.now()
    prefix = f'INV{today.strftime("%y%m%d")}'
    last = (
        LabInvoice.objects.filter(invoice_number__startswith=prefix)
        .order_by('-invoice_number').first()
    )
    seq = 1
    if last and last.invoice_number:
        try:
            seq = int(last.invoice_number.replace(prefix, '')) + 1
        except ValueError:
            seq = 1
    return f'{prefix}{seq:04d}'


class LabPanelViewSet(viewsets.ModelViewSet):
    queryset = LabPanel.objects.prefetch_related('tests').all()
    serializer_class = LabPanelSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'department']
    search_fields = ['name', 'code']
    ordering_fields = ['name', 'code', 'created_at']


class ReferringFacilityViewSet(viewsets.ModelViewSet):
    queryset = ReferringFacility.objects.all()
    serializer_class = ReferringFacilitySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active']
    search_fields = ['name', 'contact_person', 'phone']
    ordering_fields = ['name', 'created_at']


class ReferringDoctorViewSet(viewsets.ModelViewSet):
    queryset = ReferringDoctor.objects.select_related('facility').all()
    serializer_class = ReferringDoctorSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'facility']
    search_fields = ['full_name', 'license_no', 'specialty']
    ordering_fields = ['full_name', 'created_at']


class InstrumentViewSet(viewsets.ModelViewSet):
    queryset = Instrument.objects.all()
    serializer_class = InstrumentSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'department', 'is_active']
    search_fields = ['name', 'serial_no', 'manufacturer']
    ordering_fields = ['name', 'next_service_date']


class SpecimenViewSet(viewsets.ModelViewSet):
    queryset = Specimen.objects.select_related(
        'lab_order__patient__user', 'collected_by', 'received_by',
    ).all()
    serializer_class = SpecimenSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'container_type', 'lab_order']
    search_fields = ['accession_number', 'barcode']
    ordering_fields = ['created_at', 'collected_at']

    def perform_create(self, serializer):
        accession = serializer.validated_data.get('accession_number')
        if not accession:
            serializer.save(accession_number=_next_accession_number())
        else:
            serializer.save()

    @action(detail=True, methods=['post'])
    def receive(self, request, pk=None):
        specimen = self.get_object()
        specimen.status = Specimen.Status.RECEIVED
        specimen.received_at = timezone.now()
        specimen.received_by = request.user
        specimen.save()
        return Response(SpecimenSerializer(specimen).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        specimen = self.get_object()
        specimen.status = Specimen.Status.REJECTED
        specimen.rejection_reason = request.data.get('reason', '')
        specimen.save()
        return Response(SpecimenSerializer(specimen).data)


class QualityControlRunViewSet(viewsets.ModelViewSet):
    queryset = QualityControlRun.objects.select_related(
        'instrument', 'test', 'performed_by',
    ).all()
    serializer_class = QualityControlRunSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['result', 'instrument', 'test']
    search_fields = ['lot_number', 'qc_level']
    ordering_fields = ['run_at']

    def perform_create(self, serializer):
        serializer.save(performed_by=self.request.user)


class LabInvoiceViewSet(viewsets.ModelViewSet):
    queryset = LabInvoice.objects.select_related(
        'patient__user', 'referring_facility', 'lab_order', 'created_by',
    ).prefetch_related('items', 'payments').all()
    serializer_class = LabInvoiceSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'payer_type', 'patient', 'lab_order']
    search_fields = ['invoice_number', 'patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['created_at', 'total']

    def perform_create(self, serializer):
        number = serializer.validated_data.get('invoice_number') or _next_invoice_number()
        serializer.save(created_by=self.request.user, invoice_number=number)

    @action(detail=True, methods=['post'])
    def add_payment(self, request, pk=None):
        invoice = self.get_object()
        with transaction.atomic():
            payment = LabInvoicePayment.objects.create(
                invoice=invoice,
                method=request.data.get('method', LabInvoicePayment.Method.CASH),
                amount=request.data.get('amount', 0),
                reference=request.data.get('reference', ''),
                received_by=request.user,
                notes=request.data.get('notes', ''),
            )
            invoice.amount_paid = sum(p.amount for p in invoice.payments.all())
            if invoice.amount_paid >= invoice.total and invoice.total > 0:
                invoice.status = LabInvoice.Status.PAID
            elif invoice.amount_paid > 0:
                invoice.status = LabInvoice.Status.PARTIAL
            invoice.save()
        return Response(LabInvoicePaymentSerializer(payment).data)


class LabInvoiceItemViewSet(viewsets.ModelViewSet):
    queryset = LabInvoiceItem.objects.all()
    serializer_class = LabInvoiceItemSerializer
    filterset_fields = ['invoice']


class LabInvoicePaymentViewSet(viewsets.ModelViewSet):
    queryset = LabInvoicePayment.objects.all()
    serializer_class = LabInvoicePaymentSerializer
    filterset_fields = ['invoice', 'method']


class ReportTemplateViewSet(viewsets.ModelViewSet):
    queryset = ReportTemplate.objects.all()
    serializer_class = ReportTemplateSerializer
    filterset_fields = ['is_default', 'is_active', 'department']
    search_fields = ['name']


class LabOrderExtraViewSet(viewsets.ModelViewSet):
    queryset = LabOrderExtra.objects.select_related(
        'lab_order', 'referring_doctor', 'referring_facility',
    ).all()
    serializer_class = LabOrderExtraSerializer
    filterset_fields = ['lab_order', 'referring_doctor', 'referring_facility']


class LabResultAuditViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = LabResultAudit.objects.select_related('result', 'changed_by').all()
    serializer_class = LabResultAuditSerializer
    filterset_fields = ['result']


class LabReagentViewSet(viewsets.ModelViewSet):
    queryset = LabReagent.objects.select_related('instrument').prefetch_related(
        'lots', 'lots__received_by',
    ).all()
    serializer_class = LabReagentSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'storage', 'department', 'instrument', 'is_active', 'is_controlled']
    search_fields = ['name', 'code', 'catalog_no', 'manufacturer', 'supplier']
    ordering_fields = ['name', 'created_at']

    @action(detail=True, methods=['post'])
    def receive_lot(self, request, pk=None):
        """Receive a new lot or top up an existing one (creates lot + RECEIVE txn)."""
        from decimal import Decimal
        reagent = self.get_object()
        data = request.data or {}
        lot_number = data.get('lot_number') or ''
        qty = Decimal(str(data.get('quantity') or 0))
        if not lot_number or qty <= 0:
            return Response({'detail': 'lot_number and positive quantity required'}, status=400)
        lot, created = ReagentLot.objects.get_or_create(
            reagent=reagent, lot_number=lot_number,
            defaults={
                'received_date': data.get('received_date') or timezone.now().date(),
                'expiry_date': data.get('expiry_date') or None,
                'open_stability_days': data.get('open_stability_days') or None,
                'initial_quantity': qty,
                'quantity_on_hand': qty,
                'location': data.get('location') or '',
                'received_by': request.user if request.user.is_authenticated else None,
            },
        )
        if not created:
            lot.quantity_on_hand = (lot.quantity_on_hand or Decimal('0')) + qty
            lot.initial_quantity = (lot.initial_quantity or Decimal('0')) + qty
            lot.save()
        ReagentTransaction.objects.create(
            lot=lot, txn_type=ReagentTransaction.Type.RECEIVE,
            quantity=qty, reason=data.get('reason') or '',
            reference=data.get('reference') or '',
            performed_by=request.user if request.user.is_authenticated else None,
        )
        return Response(LabReagentSerializer(reagent).data)

    @action(detail=False, methods=['get'])
    def alerts(self, request):
        """Quick summary of low-stock and near-expiry alerts."""
        from datetime import date, timedelta
        from decimal import Decimal
        soon = date.today() + timedelta(days=30)
        low, expired, expiring = [], [], []
        for r in self.get_queryset():
            if not r.is_active:
                continue
            on_hand = sum(
                (l.quantity_on_hand or Decimal('0'))
                for l in r.lots.all()
                if l.status in ('active', 'quarantine')
            )
            if r.reorder_level and on_hand <= r.reorder_level:
                low.append({'id': r.id, 'name': r.name, 'on_hand': str(on_hand),
                            'reorder_level': str(r.reorder_level)})
            for lot in r.lots.all():
                if lot.status not in ('active', 'quarantine'):
                    continue
                if lot.expiry_date and lot.expiry_date < date.today():
                    expired.append({'id': lot.id, 'reagent': r.name, 'lot': lot.lot_number,
                                    'expiry': lot.expiry_date.isoformat()})
                elif lot.expiry_date and lot.expiry_date <= soon:
                    expiring.append({'id': lot.id, 'reagent': r.name, 'lot': lot.lot_number,
                                     'expiry': lot.expiry_date.isoformat()})
        return Response({'low_stock': low, 'expired': expired, 'expiring_soon': expiring})


class ReagentLotViewSet(viewsets.ModelViewSet):
    queryset = ReagentLot.objects.select_related('reagent', 'received_by').all()
    serializer_class = ReagentLotSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['reagent', 'status']
    search_fields = ['lot_number', 'reagent__name', 'location']
    ordering_fields = ['expiry_date', 'received_date', 'created_at']

    def perform_create(self, serializer):
        from decimal import Decimal
        lot = serializer.save(
            received_by=self.request.user if self.request.user.is_authenticated else None,
        )
        if (lot.initial_quantity or 0) > 0:
            ReagentTransaction.objects.create(
                lot=lot, txn_type=ReagentTransaction.Type.RECEIVE,
                quantity=lot.initial_quantity, reason='Initial receipt',
                performed_by=self.request.user if self.request.user.is_authenticated else None,
            )

    @action(detail=True, methods=['post'])
    def consume(self, request, pk=None):
        from decimal import Decimal
        lot = self.get_object()
        qty = Decimal(str(request.data.get('quantity') or 0))
        if qty <= 0:
            return Response({'detail': 'positive quantity required'}, status=400)
        lot.quantity_on_hand = max(Decimal('0'), (lot.quantity_on_hand or Decimal('0')) - qty)
        if lot.quantity_on_hand <= 0:
            lot.status = ReagentLot.Status.DEPLETED
        lot.save()
        ReagentTransaction.objects.create(
            lot=lot, txn_type=ReagentTransaction.Type.CONSUME,
            quantity=-qty, reason=request.data.get('reason') or '',
            reference=request.data.get('reference') or '',
            performed_by=request.user if request.user.is_authenticated else None,
        )
        return Response(ReagentLotSerializer(lot).data)

    @action(detail=True, methods=['post'])
    def adjust(self, request, pk=None):
        from decimal import Decimal
        lot = self.get_object()
        qty = Decimal(str(request.data.get('quantity') or 0))
        lot.quantity_on_hand = max(Decimal('0'), (lot.quantity_on_hand or Decimal('0')) + qty)
        lot.save()
        ReagentTransaction.objects.create(
            lot=lot, txn_type=ReagentTransaction.Type.ADJUST,
            quantity=qty, reason=request.data.get('reason') or '',
            performed_by=request.user if request.user.is_authenticated else None,
        )
        return Response(ReagentLotSerializer(lot).data)

    @action(detail=True, methods=['post'])
    def discard(self, request, pk=None):
        from decimal import Decimal
        lot = self.get_object()
        qty = lot.quantity_on_hand or Decimal('0')
        lot.status = ReagentLot.Status.DISCARDED
        lot.quantity_on_hand = Decimal('0')
        lot.save()
        ReagentTransaction.objects.create(
            lot=lot, txn_type=ReagentTransaction.Type.DISCARD,
            quantity=-qty, reason=request.data.get('reason') or '',
            performed_by=request.user if request.user.is_authenticated else None,
        )
        return Response(ReagentLotSerializer(lot).data)

    @action(detail=True, methods=['post'])
    def open_lot(self, request, pk=None):
        lot = self.get_object()
        if not lot.opened_date:
            lot.opened_date = timezone.now().date()
            lot.save()
        return Response(ReagentLotSerializer(lot).data)


class ReagentTransactionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = ReagentTransaction.objects.select_related(
        'lot', 'lot__reagent', 'performed_by',
    ).all()
    serializer_class = ReagentTransactionSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['lot', 'txn_type']
    ordering_fields = ['performed_at']
