"""Front-desk patient journey API.

All endpoints live under ``/api/visits/``. A visit is created when reception
registers the patient, and each subsequent step (charge, pay, triage, doctor,
lab, prescribe, discharge) is an explicit action so the board can show exactly
where every patient is.
"""
import json
from datetime import date as date_cls
from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework import filters, parsers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import ClinicSettings, PatientVisit, VisitEvent, next_visit_number
from .serializers import (
    ClinicSettingsSerializer,
    PatientVisitListSerializer,
    PatientVisitSerializer,
    VisitEventSerializer,
)

# Roles allowed to move a patient through each stage.
CLINICAL_ROLES = {'doctor', 'clinical_officer', 'dentist'}
NURSE_ROLES = {'nurse', 'midwife', 'clinical_officer', 'doctor', 'dentist'}
LAB_ROLES = {'lab_tech', 'radiologist', 'doctor', 'clinical_officer', 'nurse'}
FRONT_DESK_ROLES = {
    'receptionist', 'cashier', 'tenant_admin', 'clinic_admin', 'hospital_admin',
    'admin', 'super_admin',
}


def _dec(value, default='0'):
    try:
        return Decimal(str(value))
    except Exception:
        return Decimal(default)


class ClinicSettingsView(viewsets.ViewSet):
    """GET / PATCH ``/api/visits/settings/``."""

    def list(self, request):
        return Response(ClinicSettingsSerializer(ClinicSettings.get_solo()).data)

    def create(self, request):
        return self.partial_update(request)

    def partial_update(self, request, pk=None):
        obj = ClinicSettings.get_solo()
        serializer = ClinicSettingsSerializer(obj, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class PatientVisitViewSet(viewsets.ModelViewSet):
    queryset = PatientVisit.objects.select_related(
        'patient__user', 'doctor', 'triage', 'consultation__doctor',
        'invoice', 'created_by',
    ).prefetch_related('events__actor', 'consultation__lab_orders__tests',
                       'consultation__prescriptions__items')
    serializer_class = PatientVisitSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['stage', 'patient', 'doctor', 'payment_status', 'priority', 'outcome',
                        'corporate', 'payer', 'corporate_verified']
    search_fields = [
        'visit_number', 'patient__user__first_name', 'patient__user__last_name',
        'patient__patient_number', 'patient__patient_id',
    ]
    ordering_fields = ['arrived_at', 'queue_number', 'stage']

    def get_serializer_class(self):
        if self.action == 'list':
            return PatientVisitListSerializer
        return PatientVisitSerializer

    # ── creation ────────────────────────────────────────────────────────
    def create(self, request, *args, **kwargs):
        """Register a patient at reception and open a visit.

        Pass ``start_at='arrived'`` to just log an arrival token (the patient
        is in the waiting room) and confirm registration later.
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        settings_obj = ClinicSettings.get_solo()
        start_at = str(request.data.get('start_at') or 'registered').lower()
        arrived_only = start_at == 'arrived'

        with transaction.atomic():
            number, queue = next_visit_number()
            visit = serializer.save(
                visit_number=number,
                queue_number=queue,
                stage=PatientVisit.Stage.ARRIVED if arrived_only else PatientVisit.Stage.REGISTERED,
                registered_at=None if arrived_only else timezone.now(),
                created_by=request.user,
                consultation_fee=serializer.validated_data.get(
                    'consultation_fee', settings_obj.consultation_fee,
                ) or Decimal('0.00'),
                # Stamp the verification time when reception verified the
                # company + patient details before check-in.
                corporate_verified_at=(
                    timezone.now()
                    if request.data.get('corporate_verified') and request.data.get('corporate')
                    else None
                ),
            )
            VisitEvent.objects.create(
                visit=visit, stage=visit.stage,
                action='arrived' if arrived_only else 'registered',
                note=('Patient arrived at the clinic.' if arrived_only
                      else 'Patient registered at reception.'),
                actor=request.user,
            )
        return Response(
            PatientVisitSerializer(visit, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )

    # ── helpers ─────────────────────────────────────────────────────────
    @staticmethod
    def _fail(msg, code=status.HTTP_400_BAD_REQUEST):
        return Response({'detail': msg}, status=code)

    def _ensure_invoice(self, visit, items=None):
        """Create the visit invoice (if missing) and return it."""
        from billing.models import Invoice

        items = items or []
        if visit.invoice_id:
            invoice = visit.invoice
            if items:
                invoice.items = list(invoice.items or []) + items
                invoice.subtotal = sum(_dec(i.get('total')) for i in invoice.items)
                invoice.total = invoice.subtotal + _dec(invoice.tax) - _dec(invoice.discount)
                invoice.save(update_fields=['items', 'subtotal', 'total'])
            return invoice

        fee = visit.consultation_fee or Decimal('0.00')
        if fee > 0 and not items:
            items = [{
                'description': 'Consultation fee',
                'quantity': 1,
                'unit_price': float(fee),
                'total': float(fee),
            }]
        subtotal = sum(_dec(i.get('total')) for i in items)
        invoice = Invoice.objects.create(
            invoice_number=f'INV-{visit.visit_number}',
            patient=visit.patient,
            consultation=visit.consultation,
            items=items,
            subtotal=subtotal,
            total=subtotal,
            status=Invoice.Status.SENT if subtotal > 0 else Invoice.Status.PAID,
        )
        visit.invoice = invoice
        visit.save(update_fields=['invoice'])
        return invoice

    def _require(self, visit, *stages):
        if stages and visit.stage not in stages:
            allowed = ', '.join(s.label for s in stages)
            return self._fail(
                f'This action needs the visit to be at: {allowed}. '
                f'Currently: {visit.get_stage_display()}.'
            )
        return None

    @action(detail=True, methods=['post'], url_path='register')
    def register(self, request, pk=None):
        """Confirm reception registration for a visit that is still 'arrived'."""
        visit = self.get_object()
        if visit.stage not in (PatientVisit.Stage.ARRIVED, PatientVisit.Stage.REGISTERED):
            return self._fail('This visit is already past registration.')
        if request.data.get('chief_complaint'):
            visit.chief_complaint = request.data['chief_complaint']
        if request.data.get('priority'):
            visit.priority = request.data['priority']
        visit.registered_at = visit.registered_at or timezone.now()
        visit.save(update_fields=['chief_complaint', 'priority', 'registered_at'])
        visit.set_stage(
            PatientVisit.Stage.REGISTERED, actor=request.user,
            note='Registration confirmed at reception.',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    # ── stage 3a: charge at reception / send to billing office ──────────
    @action(detail=True, methods=['post'], url_path='verify-corporate')
    def verify_corporate(self, request, pk=None):
        """Verify (or record) the corporate cover for this visit."""
        from corporate.models import CorporateClient
        from corporate.serializers import verify_corporate_patient

        visit = self.get_object()
        corporate_id = request.data.get('corporate') or (visit.corporate_id if visit.corporate_id else None)
        if not corporate_id:
            return self._fail('A corporate client is required.')

        try:
            corporate = CorporateClient.objects.get(pk=corporate_id)
        except CorporateClient.DoesNotExist:
            return self._fail('Corporate client not found.', status.HTTP_404_NOT_FOUND)

        payload = {
            'staff_number': request.data.get('staff_number', ''),
            'first_name': visit.patient.user.first_name,
            'last_name': visit.patient.user.last_name,
            'date_of_birth': visit.patient.date_of_birth,
            'national_id': visit.patient.national_id or '',
            'phone': visit.patient.user.phone or '',
            'full_name': visit.patient.user.full_name,
        }
        result = verify_corporate_patient(corporate, payload)

        visit.corporate = corporate
        visit.payer = PatientVisit.Payer.CORPORATE
        visit.corporate_verified = result['verified']
        visit.corporate_verified_at = timezone.now() if result['verified'] else None
        visit.corporate_authorisation = request.data.get('staff_number', '')
        visit.corporate_note = result['message']
        if result.get('staff_id'):
            from corporate.models import CorporateStaff
            visit.corporate_staff = CorporateStaff.objects.filter(pk=result['staff_id']).first()
        visit.save(update_fields=[
            'corporate', 'payer', 'corporate_verified', 'corporate_verified_at',
            'corporate_authorisation', 'corporate_note', 'corporate_staff',
        ])
        return Response({
            'visit': PatientVisitSerializer(visit, context={'request': request}).data,
            'verification': result,
        })

    @action(detail=True, methods=['post'], url_path='charge-fee')
    def charge_fee(self, request, pk=None):
        """Raise the consultation-fee invoice and queue the patient for payment."""
        visit = self.get_object()
        if visit.stage in (PatientVisit.Stage.DISCHARGED, PatientVisit.Stage.CANCELLED):
            return self._fail('This visit is already closed.')

        amount = request.data.get('amount')
        items = request.data.get('items') or []
        if amount is not None:
            visit.consultation_fee = _dec(amount)
            visit.save(update_fields=['consultation_fee'])
        fee = visit.consultation_fee

        if fee <= 0 and not items:
            # Nothing to charge — move straight on.
            visit.set_stage(PatientVisit.Stage.PAID, actor=request.user,
                            note='No consultation fee configured.')
            visit.payment_status = PatientVisit.PaymentStatus.WAIVED
            visit.paid_at = timezone.now()
            visit.save(update_fields=['payment_status', 'paid_at'])
            return Response(PatientVisitSerializer(visit, context={'request': request}).data)

        invoice = self._ensure_invoice(visit, items)

        # Corporate visits are invoiced to the employer — the patient is not
        # sent to the payment desk, so the stage stays at registration.
        if visit.payer == PatientVisit.Payer.CORPORATE:
            VisitEvent.objects.create(
                visit=visit, stage=visit.stage, action='charged',
                note=(f'Invoice {invoice.invoice_number} raised ({invoice.total}) — '
                      f'billed to {visit.corporate.name if visit.corporate else "corporate"}'
                      f' ({visit.corporate_staff.staff_number if visit.corporate_staff else "unverified"}).'),
                actor=request.user,
            )
            return Response(PatientVisitSerializer(visit, context={'request': request}).data)

        visit.set_stage(
            PatientVisit.Stage.AWAITING_PAYMENT, actor=request.user,
            note=f'Invoice {invoice.invoice_number} raised ({invoice.total}).',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @action(detail=True, methods=['post'], url_path='collect-payment')
    def collect_payment(self, request, pk=None):
        """Record a payment (full or partial) for this visit's invoice."""
        from billing.models import Invoice, Payment

        visit = self.get_object()
        if visit.stage in (PatientVisit.Stage.DISCHARGED, PatientVisit.Stage.CANCELLED):
            return self._fail('This visit is already closed.')

        invoice = visit.invoice or self._ensure_invoice(visit)
        method = (request.data.get('method') or 'cash').lower()
        valid_methods = {c[0] for c in Payment.Method.choices}
        if method not in valid_methods:
            return self._fail(f'Invalid payment method. Use one of: {", ".join(sorted(valid_methods))}.')

        balance = invoice.balance
        if balance <= 0:
            visit.payment_status = PatientVisit.PaymentStatus.PAID
            visit.paid_at = visit.paid_at or timezone.now()
            visit.save(update_fields=['payment_status', 'paid_at'])
            visit.set_stage(PatientVisit.Stage.PAID, actor=request.user, note='Invoice already settled.')
            return Response(PatientVisitSerializer(visit, context={'request': request}).data)

        amount = _dec(request.data.get('amount') or balance)
        if amount <= 0:
            return self._fail('Payment amount must be greater than zero.')
        if amount > balance:
            amount = balance

        payer = (request.data.get('payer') or 'self').lower()
        valid_payers = {c[0] for c in PatientVisit.Payer.choices}
        if payer not in valid_payers:
            payer = PatientVisit.Payer.SELF

        Payment.objects.create(
            invoice=invoice,
            amount=amount,
            method=method,
            reference=request.data.get('reference', ''),
            received_by=request.user,
            notes=request.data.get('notes', ''),
        )
        invoice.amount_paid = invoice.amount_paid + amount
        invoice.status = (
            Invoice.Status.PAID
            if invoice.amount_paid >= invoice.total
            else Invoice.Status.PARTIALLY_PAID
        )
        invoice.save(update_fields=['amount_paid', 'status'])

        fully_paid = invoice.amount_paid >= invoice.total
        visit.payment_status = (
            PatientVisit.PaymentStatus.PAID if fully_paid
            else PatientVisit.PaymentStatus.PARTIAL
        )
        visit.payment_method = method
        visit.payer = payer
        if fully_paid:
            visit.paid_at = timezone.now()
        visit.save(update_fields=['payment_status', 'payment_method', 'payer', 'paid_at'])

        if fully_paid:
            visit.set_stage(
                PatientVisit.Stage.PAID, actor=request.user,
                note=f'Paid {amount} via {method}.',
            )
        else:
            VisitEvent.objects.create(
                visit=visit, stage=visit.stage, action='part_payment',
                note=f'Part payment {amount} via {method}; balance {invoice.balance}.',
                actor=request.user,
            )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @action(detail=True, methods=['post'], url_path='waive-fee')
    def waive_fee(self, request, pk=None):
        """Waive the consultation fee (staff, emergency, pre-paid scheme)."""
        from billing.models import Invoice

        visit = self.get_object()
        settings_obj = ClinicSettings.get_solo()
        if not settings_obj.allow_fee_waiver:
            return self._fail('Fee waivers are disabled in clinic settings.')

        if visit.invoice_id and visit.invoice and visit.invoice.balance > 0:
            invoice = visit.invoice
            invoice.status = Invoice.Status.CANCELLED
            invoice.notes = (invoice.notes + '\n' if invoice.notes else '') + \
                f'Consultation fee waived: {request.data.get("reason", "")}'.strip()
            invoice.save(update_fields=['status', 'notes'])

        visit.payment_status = PatientVisit.PaymentStatus.WAIVED
        visit.waiver_reason = request.data.get('reason', '')
        visit.payer = PatientVisit.Payer.WAIVER
        visit.paid_at = timezone.now()
        visit.save(update_fields=['payment_status', 'waiver_reason', 'payer', 'paid_at'])
        visit.set_stage(
            PatientVisit.Stage.PAID, actor=request.user,
            note=f'Fee waived: {visit.waiver_reason or "no reason given"}.',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    # ── stage 3b: send straight to triage (fee paid at reception) ───────
    @action(detail=True, methods=['post'], url_path='skip-payment')
    def skip_payment(self, request, pk=None):
        """Move a patient past billing without a payment (e.g. pre-paid / exempt)."""
        visit = self.get_object()
        settings_obj = ClinicSettings.get_solo()
        if settings_obj.require_payment_before_triage and not request.user.role in {
            'tenant_admin', 'clinic_admin', 'admin', 'super_admin',
        }:
            return self._fail('Payment is required before triage for this clinic.')

        visit.payment_status = PatientVisit.PaymentStatus.UNPAID
        visit.save(update_fields=['payment_status'])
        visit.set_stage(
            PatientVisit.Stage.PAID, actor=request.user,
            note=request.data.get('reason', 'Payment skipped — patient cleared for triage.'),
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    # ── stage 4: triage ─────────────────────────────────────────────────
    @action(detail=True, methods=['post'], url_path='start-triage')
    def start_triage(self, request, pk=None):
        """Create the triage record and queue the patient for the nurse."""
        from triage.models import Triage

        visit = self.get_object()
        settings_obj = ClinicSettings.get_solo()
        if (
            settings_obj.require_payment_before_triage
            and visit.payment_status not in (
                PatientVisit.PaymentStatus.PAID, PatientVisit.PaymentStatus.WAIVED,
            )
        ):
            return self._fail('The consultation fee must be settled before triage.')

        triage = visit.triage
        if triage is None:
            triage = Triage.objects.create(
                patient=visit.patient,
                nurse=request.user,
                chief_complaint=request.data.get('chief_complaint') or visit.chief_complaint,
                arrival_mode=request.data.get('arrival_mode', 'walk_in'),
            )
        visit.triage = triage
        visit.save(update_fields=['triage'])
        visit.set_stage(PatientVisit.Stage.TRIAGE, actor=request.user, note='Patient sent to triage.')
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @action(detail=True, methods=['post'], url_path='complete-triage')
    def complete_triage(self, request, pk=None):
        """Save vitals/ESI, assign the doctor and queue the patient for them."""
        from triage.models import Triage

        visit = self.get_object()
        triage = visit.triage
        if triage is None:
            triage = Triage.objects.create(
                patient=visit.patient, nurse=request.user,
                chief_complaint=request.data.get('chief_complaint') or visit.chief_complaint,
            )

        editable = [
            'esi_level', 'suggested_esi', 'esi_override_reason', 'chief_complaint',
            'vital_signs', 'arrival_mode', 'pain_scale', 'avpu', 'news2_score',
            'bmi', 'allergies_confirmed', 'allergies_updated', 'medication_history',
            'pregnancy_status', 'mental_health_screen', 'smoking_status',
            'alcohol_use', 'substance_use', 'nutrition_screen', 'fall_risk',
            'infection_risk', 'nursing_assessment', 'interventions',
            'patient_education', 'notes',
        ]
        for field in editable:
            if field in request.data:
                setattr(triage, field, request.data[field])
        triage.status = Triage.TriageStatus.COMPLETED
        triage.completed_at = timezone.now()
        triage.save()

        doctor_id = request.data.get('doctor') or request.data.get('doctor_id')
        if doctor_id:
            visit.doctor_id = doctor_id
            visit.doctor_assigned_at = timezone.now()

        if triage.esi_level and triage.esi_level <= 2:
            visit.priority = PatientVisit.Priority.EMERGENCY
        elif triage.esi_level == 3:
            visit.priority = PatientVisit.Priority.URGENT

        visit.triage = triage
        visit.triage_completed_at = triage.completed_at
        visit.save(update_fields=[
            'triage', 'doctor', 'doctor_assigned_at', 'priority', 'triage_completed_at',
        ])
        visit.set_stage(
            PatientVisit.Stage.AWAITING_DOCTOR, actor=request.user,
            note='Triage completed — patient queued for the doctor.',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @action(detail=True, methods=['post'], url_path='assign-doctor')
    def assign_doctor(self, request, pk=None):
        """Assign or re-assign the doctor who will see this patient."""
        visit = self.get_object()
        doctor_id = request.data.get('doctor') or request.data.get('doctor_id')
        if not doctor_id:
            return self._fail('doctor is required.')

        visit.doctor_id = doctor_id
        visit.doctor_assigned_at = timezone.now()
        visit.save(update_fields=['doctor', 'doctor_assigned_at'])
        VisitEvent.objects.create(
            visit=visit, stage=visit.stage, action='doctor_assigned',
            note=f'Doctor assigned: {visit.doctor.full_name}.', actor=request.user,
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    # ── stage 5/6: consultation ─────────────────────────────────────────
    @action(detail=True, methods=['post'], url_path='start-consultation')
    def start_consultation(self, request, pk=None):
        """Open (or reuse) the clinical consultation with the assigned doctor."""
        from consultations.models import Consultation

        visit = self.get_object()
        settings_obj = ClinicSettings.get_solo()
        if (
            settings_obj.require_triage_before_doctor
            and (visit.triage is None or visit.triage.status != 'completed')
        ):
            return self._fail('Triage must be completed before the doctor can see this patient.')

        doctor = visit.doctor
        if doctor is None:
            if request.user.role not in CLINICAL_ROLES:
                return self._fail('Assign a doctor before starting the consultation.')
            doctor = request.user

        consultation = visit.consultation
        if consultation is None:
            consultation = Consultation.objects.create(
                patient=visit.patient,
                doctor=doctor,
                triage=visit.triage,
                appointment=visit.appointment,
                chief_complaint=visit.chief_complaint or (
                    visit.triage.chief_complaint if visit.triage else ''
                ),
                vital_signs=visit.triage.vital_signs if visit.triage else {},
                medication_history=visit.triage.medication_history if visit.triage else [],
                draft_owner=request.user,
            )
        elif consultation.doctor_id != doctor.id and request.user.role in CLINICAL_ROLES:
            consultation.doctor = doctor
            consultation.save(update_fields=['doctor', 'updated_at'])

        visit.consultation = consultation
        visit.save(update_fields=['consultation'])
        visit.set_stage(
            PatientVisit.Stage.IN_CONSULTATION, actor=request.user,
            note=f'Consultation started with Dr. {doctor.full_name}.',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    # ── stage 7: laboratory ─────────────────────────────────────────────
    @action(detail=True, methods=['post'], url_path='order-lab')
    def order_lab(self, request, pk=None):
        """Raise a lab order for this visit and send the patient to the lab."""
        from lab.models import LabOrder, LabTestCatalog

        visit = self.get_object()
        if visit.consultation_id is None:
            return self._fail('Start the consultation before ordering lab tests.')

        test_ids = request.data.get('test_ids') or request.data.get('tests') or []
        if not test_ids:
            return self._fail('Select at least one lab test.')

        tests = list(LabTestCatalog.objects.filter(id__in=test_ids, is_active=True))
        if not tests:
            return self._fail('None of the selected tests exist in the lab catalog.')

        priority = request.data.get('priority', LabOrder.Priority.ROUTINE)
        order = LabOrder.objects.create(
            consultation=visit.consultation,
            patient=visit.patient,
            ordered_by=request.user,
            status=LabOrder.Status.PENDING,
            priority=priority,
            clinical_notes=request.data.get('clinical_notes', ''),
            is_home_collection=bool(request.data.get('is_home_collection', False)),
        )
        order.tests.set(tests)

        settings_obj = ClinicSettings.get_solo()
        bill_labs = request.data.get('add_to_invoice', settings_obj.auto_invoice_lab_tests)
        if bill_labs:
            items = [{
                'description': f'Lab test · {t.name}',
                'quantity': 1,
                'unit_price': float(t.price),
                'total': float(t.price),
            } for t in tests]
            invoice = self._ensure_invoice(visit, items)
            if invoice.status == 'paid' and invoice.balance > 0:
                invoice.status = 'partially_paid'
                invoice.save(update_fields=['status'])

        visit.set_stage(
            PatientVisit.Stage.IN_LAB, actor=request.user,
            note=f'Lab order #{order.id}: ' + ', '.join(t.name for t in tests) + '.',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @action(detail=True, methods=['post'], url_path='lab-start')
    def lab_start(self, request, pk=None):
        """Lab has received the sample and started processing."""
        from lab.models import LabOrder

        visit = self.get_object()
        orders = self._visit_lab_orders(visit)
        if not orders:
            return self._fail('There is no lab order on this visit.')

        target = LabOrder.Status.PROCESSING
        if request.data.get('status') in dict(LabOrder.Status.choices):
            target = request.data['status']
        for order in orders:
            if order.status in (LabOrder.Status.CANCELLED,):
                continue
            order.status = target
            order.save(update_fields=['status', 'updated_at'])
        VisitEvent.objects.create(
            visit=visit, stage=visit.stage, action='lab_status',
            note=f'Lab order moved to {target}.', actor=request.user,
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @action(
        detail=True, methods=['post'], url_path='lab-complete',
        parser_classes=[parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser],
    )
    def lab_complete(self, request, pk=None):
        """Upload results (and optionally a scan) and notify the doctor."""
        from lab.models import LabOrder, LabResult

        visit = self.get_object()
        orders = self._visit_lab_orders(visit)
        if not orders:
            return self._fail('There is no lab order on this visit.')

        results = request.data.get('results') or []
        if isinstance(results, str):
            try:
                results = json.loads(results)
            except ValueError:
                results = []
        for row in results:
            test_id = row.get('test') or row.get('test_id')
            if not test_id:
                continue
            order = next((o for o in orders if o.tests.filter(id=test_id).exists()), orders[0])
            LabResult.objects.create(
                order=order,
                test_id=test_id,
                result_value=row.get('result_value', ''),
                unit=row.get('unit', ''),
                is_abnormal=bool(row.get('is_abnormal', False)),
                comments=row.get('comments', ''),
                performed_by=request.user,
            )

        report = request.FILES.get('lab_report') or request.FILES.get('report')
        if report:
            visit.lab_report = report
            visit.save(update_fields=['lab_report'])

        for order in orders:
            if order.status != LabOrder.Status.CANCELLED:
                order.status = LabOrder.Status.COMPLETED
                order.save(update_fields=['status', 'updated_at'])

        visit.set_stage(
            PatientVisit.Stage.LAB_READY, actor=request.user,
            note='Lab results uploaded — doctor notified.',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @staticmethod
    def _visit_lab_orders(visit):
        if not visit.consultation_id:
            return []
        return list(visit.consultation.lab_orders.all())

    @action(detail=True, methods=['post'], url_path='start-review')
    def start_review(self, request, pk=None):
        """Doctor has opened the lab results and is evaluating them."""
        visit = self.get_object()
        visit.set_stage(
            PatientVisit.Stage.REVIEW, actor=request.user,
            note='Doctor reviewing lab results.',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    # ── stage 8: prescription ───────────────────────────────────────────
    @action(detail=True, methods=['post'], url_path='prescribe')
    def prescribe(self, request, pk=None):
        """Write the prescription for this visit."""
        from prescriptions.models import Prescription, PrescriptionItem

        visit = self.get_object()
        if visit.consultation_id is None:
            return self._fail('Start the consultation before prescribing.')

        items = request.data.get('items') or []
        if not items:
            return self._fail('Add at least one medication.')

        doctor = visit.doctor or visit.consultation.doctor or request.user
        prescription = Prescription.objects.create(
            consultation=visit.consultation,
            patient=visit.patient,
            doctor=doctor,
            notes=request.data.get('notes', ''),
        )
        for item in items:
            name = item.get('medication_name') or item.get('custom_medication_name') or ''
            if not name:
                continue
            PrescriptionItem.objects.create(
                prescription=prescription,
                medication_id=item.get('medication_id'),
                medication_name=name,
                custom_medication_name=item.get('custom_medication_name', ''),
                is_custom=bool(item.get('is_custom', False)),
                dosage=item.get('dosage', ''),
                frequency=item.get('frequency', ''),
                duration=item.get('duration', ''),
                quantity=int(item.get('quantity') or 1),
                instructions=item.get('instructions', ''),
                schedule=item.get('schedule', ''),
                refills=int(item.get('refills') or 0),
            )

        visit.set_stage(
            PatientVisit.Stage.PRESCRIBED, actor=request.user,
            note=f'Prescription #{prescription.id} written ({len(items)} item(s)).',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @action(detail=True, methods=['post'], url_path='send-to-pharmacy')
    def send_to_pharmacy(self, request, pk=None):
        """Flag the latest prescription for the in-house pharmacy."""
        from prescriptions.models import Prescription

        visit = self.get_object()
        if visit.consultation_id is None:
            return self._fail('There is no consultation on this visit.')
        rx = visit.consultation.prescriptions.order_by('-created_at').first()
        if rx is None:
            return self._fail('Write a prescription before sending it to the pharmacy.')
        rx.status = Prescription.Status.ACTIVE
        rx.save(update_fields=['status'])
        VisitEvent.objects.create(
            visit=visit, stage=visit.stage, action='sent_to_pharmacy',
            note=f'Prescription #{rx.id} sent to the pharmacy.', actor=request.user,
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    # ── stage 9: discharge ──────────────────────────────────────────────
    @action(detail=True, methods=['post'])
    def discharge(self, request, pk=None):
        """Close the visit, sign the encounter and set the outcome."""
        from consultations.models import Consultation

        visit = self.get_object()
        outcome = request.data.get('outcome', PatientVisit.Outcome.DISCHARGED)
        valid = {c[0] for c in PatientVisit.Outcome.choices}
        if outcome not in valid:
            return self._fail(f'Invalid outcome. Use one of: {", ".join(sorted(valid))}.')

        visit.outcome = outcome
        visit.discharge_summary = request.data.get('discharge_summary', '')
        follow_up = request.data.get('follow_up_date')
        if follow_up:
            visit.follow_up_date = follow_up
        visit.save(update_fields=['outcome', 'discharge_summary', 'follow_up_date'])

        consultation = visit.consultation
        if consultation:
            disposition_map = {
                'discharged': Consultation.Disposition.DISCHARGE,
                'referred': Consultation.Disposition.REFERRAL,
                'admitted': Consultation.Disposition.ADMISSION,
                'observation': Consultation.Disposition.OBSERVATION,
                'left_ama': Consultation.Disposition.LEFT_AMA,
                'deceased': Consultation.Disposition.DISCHARGE,
            }
            consultation.disposition = disposition_map.get(
                outcome, Consultation.Disposition.DISCHARGE,
            )
            if request.data.get('treatment_plan'):
                consultation.treatment_plan = request.data['treatment_plan']
            if request.data.get('diagnosis'):
                consultation.diagnosis = request.data['diagnosis']
            consultation.status = Consultation.ConsultationStatus.LOCKED
            consultation.signed_at = timezone.now()
            consultation.save()

        if visit.appointment_id:
            visit.appointment.status = 'completed'
            visit.appointment.save(update_fields=['status'])

        visit.set_stage(
            PatientVisit.Stage.DISCHARGED, actor=request.user,
            note=f'Discharged — {visit.get_outcome_display()}.',
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """Cancel the visit (patient left, duplicate, etc.)."""
        visit = self.get_object()
        if visit.stage == PatientVisit.Stage.DISCHARGED:
            return self._fail('This visit is already discharged.')
        visit.set_stage(
            PatientVisit.Stage.CANCELLED, actor=request.user,
            note=request.data.get('reason', 'Visit cancelled.'),
        )
        return Response(PatientVisitSerializer(visit, context={'request': request}).data)

    # ── board ───────────────────────────────────────────────────────────
    @action(detail=False, methods=['get'])
    def board(self, request):
        """Live front-desk board: every open visit grouped by stage, plus KPIs."""
        date_param = request.query_params.get('date')
        if date_param:
            try:
                day = date_cls.fromisoformat(date_param)
            except ValueError:
                return self._fail('date must be YYYY-MM-DD.')
        else:
            day = timezone.localdate()

        qs = self.get_queryset().filter(arrived_at__date=day).order_by('queue_number')
        if request.query_params.get('mine') in ('1', 'true', 'True'):
            qs = qs.filter(doctor=request.user)
        only_open = request.query_params.get('open') not in ('0', 'false', 'False')
        rows_all = list(qs)
        rows = [
            v for v in rows_all
            if v.stage not in (PatientVisit.Stage.DISCHARGED, PatientVisit.Stage.CANCELLED)
        ] if only_open else rows_all

        payload = PatientVisitListSerializer(rows, many=True, context={'request': request}).data
        # KPIs always describe the whole day, even when the board is filtered
        # to open visits only.
        kpi_payload = (
            payload if not only_open
            else PatientVisitListSerializer(rows_all, many=True, context={'request': request}).data
        )

        stage_order = [
            PatientVisit.Stage.ARRIVED,
            PatientVisit.Stage.REGISTERED,
            PatientVisit.Stage.AWAITING_PAYMENT,
            PatientVisit.Stage.PAID,
            PatientVisit.Stage.TRIAGE,
            PatientVisit.Stage.AWAITING_DOCTOR,
            PatientVisit.Stage.IN_CONSULTATION,
            PatientVisit.Stage.IN_LAB,
            PatientVisit.Stage.LAB_READY,
            PatientVisit.Stage.REVIEW,
            PatientVisit.Stage.PRESCRIBED,
            PatientVisit.Stage.DISCHARGED,
            PatientVisit.Stage.CANCELLED,
        ]
        grouped = {stage: [] for stage in stage_order}
        for row in payload:
            grouped.setdefault(row['stage'], []).append(row)

        # Counters come from the whole day; the columns come from the filter.
        kpi_grouped = {stage: [] for stage in stage_order}
        for row in kpi_payload:
            kpi_grouped.setdefault(row['stage'], []).append(row)

        waiting = [r['waiting_minutes'] for r in kpi_payload if r['is_open']]
        longest = max(waiting) if waiting else 0
        now = timezone.localtime()

        return Response({
            'date': day.isoformat(),
            'generated_at': now.isoformat(),
            'stages': [
                {
                    'value': stage,
                    'label': PatientVisit.Stage(stage).label,
                    'visits': grouped.get(stage, []),
                }
                for stage in stage_order
            ],
            'kpis': {
                'open': sum(1 for r in kpi_payload if r['is_open']),
                'total': len(kpi_payload),
                'awaiting_payment': len(kpi_grouped.get(PatientVisit.Stage.AWAITING_PAYMENT, [])),
                'in_triage': len(kpi_grouped.get(PatientVisit.Stage.TRIAGE, [])),
                'awaiting_doctor': len(kpi_grouped.get(PatientVisit.Stage.AWAITING_DOCTOR, [])),
                'with_doctor': len(kpi_grouped.get(PatientVisit.Stage.IN_CONSULTATION, [])),
                'in_lab': len(kpi_grouped.get(PatientVisit.Stage.IN_LAB, [])),
                'lab_ready': len(kpi_grouped.get(PatientVisit.Stage.LAB_READY, [])),
                'review': len(kpi_grouped.get(PatientVisit.Stage.REVIEW, [])),
                'prescribed': len(kpi_grouped.get(PatientVisit.Stage.PRESCRIBED, [])),
                'discharged': len(kpi_grouped.get(PatientVisit.Stage.DISCHARGED, [])),
                'cancelled': len(kpi_grouped.get(PatientVisit.Stage.CANCELLED, [])),
                'critical': sum(1 for r in kpi_payload if (r.get('triage_esi') or 99) <= 2),
                'longest_wait_minutes': longest,
                'average_wait_minutes': int(sum(waiting) / len(waiting)) if waiting else 0,
            },
            'settings': ClinicSettingsSerializer(ClinicSettings.get_solo()).data,
        })

    @action(detail=False, methods=['get'])
    def today(self, request):
        """Compact list of today's visits (used by dashboards)."""
        qs = self.get_queryset().filter(arrived_at__date=timezone.localdate())
        data = PatientVisitListSerializer(qs, many=True, context={'request': request}).data
        return Response({'count': len(data), 'results': data})

    @action(detail=True, methods=['get'])
    def events(self, request, pk=None):
        visit = self.get_object()
        return Response(VisitEventSerializer(visit.events.all(), many=True).data)


class VisitEventViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = VisitEvent.objects.select_related('actor', 'visit').all()
    serializer_class = VisitEventSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['visit', 'stage', 'action']
