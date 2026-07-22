"""Homecare DRF views."""
import json
import time
from datetime import timedelta

from django.db import connection
from django.db.models import Avg, Count, F, Q, Sum
from django.http import StreamingHttpResponse
from django.utils import timezone
from django.utils.dateparse import parse_date, parse_datetime
from rest_framework import viewsets, status, permissions, filters
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from notifications.models import Notification

from .models import (
    HomecareCompanyProfile, Caregiver, HomecarePatient, CaregiverSchedule,
    CaregiverNote, TreatmentPlan, MedicationSchedule, DoseEvent,
    EscalationRule, Escalation, TeleconsultRoom, HomecareAppointment,
    HomecarePrescription, PharmacyStockAlert, InsurancePolicy, InsuranceClaim,
    Consent, HomecareDiagnosis, HomecareAllergy,
    Device, DeviceAssignment, DeviceMaintenance, AuditEvent,
    DrugInteraction, PrescriptionSafetyAlert,
    DrainLine,
    CarePathway, CarePathwayEnrollment, PatientDataSharing,
    CarePlan, MedicalSupply, PatientBill, PatientPayment, BillingSettings,
    AssessmentSession, AssessmentAlert,
    BradenAssessment, CapriniAssessment, MorseAssessment, MustAssessment,
    CamAssessment, PainAssessment, SkinCareAssessment, GcsAssessment,
    DiabetesBundleAssessment, HeartFailureBundleAssessment,
    PIVCAssessment, EnteralFeedingAssessment, UrinaryCatheterAssessment,
    ArtificialAirwayAssessment, CVADAssessment,
    PatientDocument,
)
from .serializers import (
    HomecareCompanyProfileSerializer, CaregiverSerializer,
    HomecarePatientSerializer, CaregiverScheduleSerializer,
    CaregiverNoteSerializer, TreatmentPlanSerializer,
    MedicationScheduleSerializer, DoseEventSerializer,
    EscalationRuleSerializer, EscalationSerializer,
    TeleconsultRoomSerializer, HomecareAppointmentSerializer,
    HomecarePrescriptionSerializer, PharmacyStockAlertSerializer,
    InsurancePolicySerializer, InsuranceClaimSerializer, ConsentSerializer,
    HomecareDiagnosisSerializer, HomecareAllergySerializer,
    DeviceSerializer, DeviceAssignmentSerializer, DeviceMaintenanceSerializer,
    AuditEventSerializer,
    DrugInteractionSerializer, PrescriptionSafetyAlertSerializer,
    DrainLineSerializer,
    PatientDataSharingSerializer,
    CarePlanSerializer, MedicalSupplySerializer,
    PatientBillSerializer, PatientPaymentSerializer, BillingSettingsSerializer,
    AssessmentSessionSerializer, AssessmentAlertSerializer,
    BradenAssessmentSerializer, CapriniAssessmentSerializer,
    MorseAssessmentSerializer, MustAssessmentSerializer,
    CamAssessmentSerializer, PainAssessmentSerializer,
    SkinCareAssessmentSerializer, GcsAssessmentSerializer,
    DiabetesBundleAssessmentSerializer, HeartFailureBundleAssessmentSerializer,
    PIVCAssessmentSerializer,
    EnteralFeedingAssessmentSerializer,
    UrinaryCatheterAssessmentSerializer,
    ArtificialAirwayAssessmentSerializer,
    CVADAssessmentSerializer,
    PatientDocumentSerializer,
)
from .permissions import IsHomecareStaff, IsHomecareStaffOrPatient, IsHomecareAdmin
from .assessments import (
    create_escalations, calc_braden, calc_caprini, calc_morse, calc_must,
    calc_cam, calc_pain, calc_gcs, calc_pivc, refresh_episode_mirrors,
    caprini_risk_label, must_risk_label,
)


def _get_or_create_sharing(patient):
    """Return the patient's data-sharing record, creating an all-shared default."""
    share, _ = PatientDataSharing.objects.get_or_create(patient=patient)
    return share


def _compute_patient_care(patient, as_of=None):
    """Build a full care & billing snapshot for a patient.

    Aggregates the active care plan, hired equipment, medical supplies,
    billable medications, caregivers and payments. All money values are
    returned as strings so the result is JSON-friendly and can also be
    persisted into a PatientBill (re-wrapped in Decimal)."""
    from decimal import Decimal
    as_of = as_of or timezone.now()
    line_items = []

    # ── Care plan (payment plan) ──
    plan = patient.care_plans.filter(is_active=True).order_by('-start_date').first()
    currency = (plan.currency if plan else None) or 'KES'
    visits = 0
    care_total = Decimal('0')
    care_block = None
    if plan:
        if plan.plan_type == CarePlan.PlanType.PER_VISIT:
            visits = CaregiverSchedule.objects.filter(
                patient=patient,
                status=CaregiverSchedule.Status.COMPLETED,
                start_at__date__gte=plan.start_date,
            ).count()
        units = plan.accrued_units(until=as_of, visits=visits)
        care_total = plan.accrued_cost(until=as_of, visits=visits)
        care_block = {
            'plan_id': plan.id,
            'plan_type': plan.plan_type,
            'plan_type_label': plan.get_plan_type_display(),
            'rate': str(plan.rate),
            'currency': currency,
            'units': units,
            'visits': visits,
            'cost': str(care_total),
            'expected_cost': str(plan.expected_cost(visits=visits)),
            'start_date': plan.start_date,
            'end_date': plan.end_date,
            'auto_bill': plan.auto_bill,
            'last_auto_billed_at': plan.last_auto_billed_at,
        }
        line_items.append({
            'kind': 'care', 'label': f'{plan.get_plan_type_display()} care',
            'qty': units, 'unit': plan.get_plan_type_display(),
            'rate': str(plan.rate), 'amount': str(care_total),
        })

    # ── Equipment hires ──
    equipment, equipment_total = [], Decimal('0')
    for a in patient.device_assignments.select_related('device').all():
        if a.returned_at:
            amount = Decimal(a.total_charged or 0)
        else:
            amount = Decimal(a.compute_charge(until=as_of) or 0)
        equipment_total += amount
        equipment.append({
            'id': a.id, 'device': a.device.name if a.device else '—',
            'hire_period': a.hire_period,
            'hire_period_label': a.get_hire_period_display() if a.hire_period else '',
            'hire_rate': str(a.hire_rate) if a.hire_rate else None,
            'deposit': str(a.deposit) if a.deposit else None,
            'assigned_at': a.assigned_at, 'returned_at': a.returned_at,
            'active': a.returned_at is None, 'amount': str(amount),
        })
        if amount:
            line_items.append({
                'kind': 'equipment', 'label': f'Equipment: {a.device.name if a.device else "device"}',
                'qty': 1, 'unit': a.get_hire_period_display() if a.hire_period else '',
                'rate': str(a.hire_rate) if a.hire_rate else None, 'amount': str(amount),
            })

    # ── Medical supplies ──
    supplies, supplies_total = [], Decimal('0')
    for s in patient.supplies.filter(is_active=True):
        cost = s.total_cost if s.billable else Decimal('0')
        supplies_total += cost
        supplies.append({
            'id': s.id, 'name': s.name, 'category': s.category,
            'category_label': s.get_category_display(),
            'quantity': s.quantity, 'unit': s.unit,
            'unit_price': str(s.unit_price), 'total_cost': str(s.total_cost),
            'supplied_at': s.supplied_at, 'expiry_date': s.expiry_date,
            'replace_due': s.replace_due, 'max_use_days': s.max_use_days,
            'days_remaining': s.days_remaining, 'usage_status': s.usage_status,
            'billable': s.billable,
        })
        if s.billable and cost:
            line_items.append({
                'kind': 'supply', 'label': f'Supply: {s.name}',
                'qty': s.quantity, 'unit': s.unit,
                'rate': str(s.unit_price), 'amount': str(cost),
            })

    # ── Medications & doses (cost optional) ──
    medications, medication_total = [], Decimal('0')
    for m in patient.medication_schedules.all():
        taken = m.doses.filter(status=DoseEvent.Status.TAKEN).count()
        pending = m.doses.filter(status=DoseEvent.Status.PENDING).count()
        missed = m.doses.filter(status=DoseEvent.Status.MISSED).count()
        cost = Decimal('0')
        if m.is_active and m.unit_cost:
            cost = (Decimal(m.unit_cost) * taken).quantize(Decimal('0.01'))
            medication_total += cost
        medications.append({
            'id': m.id, 'medication_name': m.medication_name, 'dose': m.dose,
            'route': m.route, 'route_label': m.get_route_display(),
            'requires_caregiver': m.requires_caregiver,
            'start_date': m.start_date, 'end_date': m.end_date,
            'times_of_day': m.times_of_day, 'frequency_cron': m.frequency_cron,
            'instructions': m.instructions, 'is_active': m.is_active,
            'treatment_plan': m.treatment_plan_id,
            'prescribed_by_doctor_id': m.prescribed_by_doctor_id,
            'source_prescription_id': m.source_prescription_id,
            'unit_cost': str(m.unit_cost) if m.unit_cost else None,
            'doses_taken': taken, 'doses_pending': pending, 'doses_missed': missed,
            'upcoming_doses': pending, 'amount': str(cost),
            'last_generation_at': m.last_generation_at,
            'last_generation_by_name': m.last_generation_by_name,
            'last_generation_by_role': m.last_generation_by_role,
            'last_generation_count': m.last_generation_count,
            'last_generation_days': m.last_generation_days,
            'created_at': m.created_at, 'updated_at': m.updated_at,
        })
        if cost:
            line_items.append({
                'kind': 'medication', 'label': f'Medication: {m.medication_name} ({m.dose})',
                'qty': taken, 'unit': 'dose',
                'rate': str(m.unit_cost), 'amount': str(cost),
            })

    subtotal = care_total + equipment_total + supplies_total + medication_total

    # ── Payments ──
    total_paid = patient.payments.aggregate(s=Sum('amount'))['s'] or Decimal('0')
    balance = subtotal - total_paid

    # ── Caregivers (nurse / HCA) ──
    def _cg(c):
        return {
            'id': c.id, 'name': c.user.full_name if c.user else '—',
            'category': c.category, 'category_label': c.get_category_display(),
            'hourly_rate': str(c.hourly_rate), 'phone': getattr(c.user, 'phone', ''),
        }
    caregivers = {
        'primary': _cg(patient.assigned_caregiver) if patient.assigned_caregiver else None,
        'additional': [_cg(c) for c in patient.additional_caregivers.all()],
    }

    return {
        'as_of': as_of, 'currency': currency,
        'care_plan': care_block, 'care_total': str(care_total),
        'equipment': equipment, 'equipment_total': str(equipment_total),
        'supplies': supplies, 'supplies_total': str(supplies_total),
        'medications': medications, 'medication_total': str(medication_total),
        'caregivers': caregivers,
        'subtotal': str(subtotal), 'total_paid': str(total_paid),
        'balance': str(balance), 'line_items': line_items,
    }


# ─────────────────────────────────────────────────────────
class HomecareCompanyProfileViewSet(viewsets.ModelViewSet):
    queryset = HomecareCompanyProfile.objects.all()
    serializer_class = HomecareCompanyProfileSerializer
    permission_classes = [IsHomecareStaff]

    @action(detail=False, methods=['get'],
            permission_classes=[IsHomecareStaffOrPatient])
    def current(self, request):
        obj = HomecareCompanyProfile.objects.first()
        if not obj:
            return Response({'detail': 'Company profile not configured.'},
                            status=status.HTTP_404_NOT_FOUND)
        return Response(self.get_serializer(obj).data)


# ─────────────────────────────────────────────────────────
class CaregiverViewSet(viewsets.ModelViewSet):
    queryset = Caregiver.objects.select_related('user').all()
    serializer_class = CaregiverSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['employment_status', 'is_available', 'is_independent', 'category']
    search_fields = ['user__email', 'user__first_name', 'user__last_name', 'license_number']
    ordering_fields = ['rating', 'total_visits', 'created_at', 'category']

    def list(self, request, *args, **kwargs):
        # One-time idempotent backfill: legacy caregivers were created without
        # user.tenant_id, which made /auth/me return tenant_type=None and broke
        # the caregiver dashboard / sidebar. Fix them on first admin list().
        try:
            from django_tenants.utils import schema_context
            from django.contrib.auth import get_user_model
            tid = getattr(getattr(request, 'tenant', None), 'id', None)
            if tid:
                user_ids = list(
                    Caregiver.objects.filter(user__isnull=False)
                    .values_list('user_id', flat=True)
                )
                if user_ids:
                    UserModel = get_user_model()
                    with schema_context('public'):
                        UserModel.objects.filter(
                            id__in=user_ids, tenant_id__isnull=True
                        ).update(tenant_id=tid)
        except Exception:
            pass
        return super().list(request, *args, **kwargs)

    @action(detail=True, methods=['post'])
    def toggle_availability(self, request, pk=None):
        cg = self.get_object()
        cg.is_available = not cg.is_available
        cg.save(update_fields=['is_available'])
        return Response(self.get_serializer(cg).data)

    @action(detail=True, methods=['post'])
    def set_rating(self, request, pk=None):
        cg = self.get_object()
        try:
            rating = float(request.data.get('rating', 0))
        except (TypeError, ValueError):
            return Response({'rating': ['Invalid number.']}, status=400)
        cg.rating = max(0, min(5, rating))
        cg.save(update_fields=['rating'])
        return Response(self.get_serializer(cg).data)

    @action(detail=False, methods=['get'])
    def me(self, request):
        cg = Caregiver.objects.filter(user=request.user).first()
        if not cg:
            return Response({'detail': 'No caregiver profile for this user.'}, status=404)
        return Response(self.get_serializer(cg).data)

    @action(detail=True, methods=['get'], url_path='assigned-patients')
    def assigned_patients(self, request, pk=None):
        """List all patients currently assigned to this caregiver
        (as primary OR additional)."""
        cg = self.get_object()
        from django.db.models import Q as _Q
        qs = HomecarePatient.objects.filter(
            _Q(assigned_caregiver=cg) | _Q(additional_caregivers=cg)
        ).distinct().select_related('user')
        return Response(HomecarePatientSerializer(qs, many=True).data)

    @action(detail=True, methods=['post'], url_path='set-patients')
    def set_patients(self, request, pk=None):
        """Bulk-sync the caregiver's *additional* patient assignments.

        Body: {patient_ids: [int, ...]}
        For each id in the list the caregiver is added (if missing).
        For every patient currently linked to this caregiver as an
        *additional* caregiver but NOT in the list, the caregiver is
        removed. The primary `assigned_caregiver` field is never touched
        by this endpoint.
        """
        cg = self.get_object()
        raw = request.data.get('patient_ids') or []
        if not isinstance(raw, list):
            return Response({'patient_ids': ['Must be a list.']}, status=400)
        try:
            ids = {int(x) for x in raw if x is not None}
        except (TypeError, ValueError):
            return Response({'patient_ids': ['All ids must be integers.']}, status=400)

        # Currently assigned (additional only)
        current = set(cg.secondary_patients.values_list('id', flat=True))
        to_add = ids - current
        to_remove = current - ids

        if to_add:
            cg.secondary_patients.add(*HomecarePatient.objects.filter(id__in=to_add))
        if to_remove:
            cg.secondary_patients.remove(*HomecarePatient.objects.filter(id__in=to_remove))

        return Response({
            'caregiver_id': cg.id,
            'added': sorted(to_add),
            'removed': sorted(to_remove),
            'total_assigned': cg.secondary_patients.count(),
        })

    @action(detail=True, methods=['post'], url_path='reset-password')
    def reset_password(self, request, pk=None):
        """Admin reset/update of the caregiver's login password.

        Body:
          {password: str}                  — set explicit password, OR
          {auto: true}                     — generate a 10-char password
        Returns: {ok: true, password?: str (only when auto-generated)}
        """
        from django_tenants.utils import schema_context
        from django.contrib.auth.password_validation import validate_password
        from django.core.exceptions import ValidationError
        import secrets, string

        cg = self.get_object()
        if not cg.user_id:
            return Response({'detail': 'Caregiver has no linked user account.'}, status=400)

        d = request.data or {}
        auto = bool(d.get('auto'))
        new_pw = (d.get('password') or '').strip()

        if auto:
            alphabet = string.ascii_letters + string.digits
            new_pw = ''.join(secrets.choice(alphabet) for _ in range(10))
        elif not new_pw:
            return Response({'password': ['Provide a password or set auto=true.']}, status=400)
        elif len(new_pw) < 8:
            return Response({'password': ['Must be at least 8 characters.']}, status=400)

        with schema_context('public'):
            user = cg.user.__class__.objects.get(pk=cg.user_id)
            try:
                validate_password(new_pw, user=user)
            except ValidationError as ve:
                return Response({'password': list(ve.messages)}, status=400)
            user.set_password(new_pw)
            user.save(update_fields=['password'])

        payload = {'ok': True, 'caregiver_id': cg.id}
        if auto:
            payload['password'] = new_pw
        return Response(payload)

    @action(detail=False, methods=['post'], url_path='enroll')
    def enroll(self, request):
        """Create a User (role=caregiver) + Caregiver profile in one call."""
        from django_tenants.utils import schema_context
        from django.contrib.auth import get_user_model
        UserModel = get_user_model()
        d = request.data
        email = d.get('user_email') or d.get('email')
        if not email:
            return Response({'user_email': ['Required.']}, status=400)
        # Capture current tenant id before switching to public schema.
        tenant_id = getattr(getattr(request, 'tenant', None), 'id', None)
        with schema_context('public'):
            user, _ = UserModel.objects.get_or_create(
                email=email,
                defaults={
                    'first_name': d.get('first_name', ''),
                    'last_name': d.get('last_name', ''),
                    'role': 'caregiver',
                },
            )
            if d.get('first_name'):
                user.first_name = d['first_name']
            if d.get('last_name'):
                user.last_name = d['last_name']
            if d.get('phone'):
                user.phone = d['phone']
            user.role = 'caregiver'
            # Ensure caregiver is bound to the current homecare tenant so
            # /auth/me returns tenant_type='homecare' (frontend gates on this).
            if tenant_id and not user.tenant_id:
                user.tenant_id = tenant_id
            if d.get('password'):
                user.set_password(d['password'])
            user.save()
            uid = user.id
        cg = Caregiver.objects.create(
            user_id=uid,
            category=d.get('category') or 'nurse',
            license_number=d.get('license_number', ''),
            bio=d.get('bio', ''),
            specialties=d.get('specialties') or [],
            certifications=d.get('certifications') or [],
            employment_status=d.get('employment_status', 'active'),
            is_independent=bool(d.get('is_independent', False)),
            is_available=bool(d.get('is_available', True)),
            hourly_rate=d.get('hourly_rate') or 0,
            hire_date=d.get('hire_date') or None,
        )
        return Response(self.get_serializer(cg).data, status=201)


# ─────────────────────────────────────────────────────────
class HomecarePatientViewSet(viewsets.ModelViewSet):
    queryset = HomecarePatient.objects.select_related('user', 'assigned_caregiver__user').all()
    serializer_class = HomecarePatientSerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['risk_level', 'is_active', 'assigned_caregiver']
    search_fields = ['medical_record_number', 'user__first_name', 'user__last_name', 'user__email']
    ordering_fields = ['enrolled_at', 'risk_level']

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if user.role == 'patient':
            return qs.filter(user=user)
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                return qs.filter(
                    Q(assigned_caregiver=cg)
                    | Q(additional_caregivers=cg)
                    | Q(schedules__caregiver=cg)
                ).distinct()
            return qs.none()
        return qs

    @action(detail=True, methods=['get'], url_path='care-summary',
            permission_classes=[IsHomecareStaff])
    def care_summary(self, request, pk=None):
        """Full care & billing snapshot for a patient (equipment, supplies,
        medications, caregivers, plan cost, payments, balance).

        Optional ?as_of=<ISO datetime> computes the total cost at that moment."""
        patient = self.get_object()
        as_of = None
        raw = request.query_params.get('as_of')
        if raw:
            as_of = parse_datetime(raw)
            if as_of is not None and timezone.is_naive(as_of):
                as_of = timezone.make_aware(as_of)
        data = _compute_patient_care(patient, as_of=as_of)
        data['patient'] = {
            'id': patient.id,
            'name': patient.user.full_name if patient.user else '—',
            'medical_record_number': patient.medical_record_number,
            'is_active': patient.is_active,
            'risk_level': patient.risk_level,
        }
        recent = patient.payments.all()[:20]
        data['payments'] = PatientPaymentSerializer(recent, many=True).data
        data['bills'] = PatientBillSerializer(
            patient.bills.all()[:20], many=True).data
        return Response(data)

    @action(detail=True, methods=['post'], url_path='generate-bill',
            permission_classes=[IsHomecareStaff])
    def generate_bill(self, request, pk=None):
        """Snapshot the patient's current charges into a PatientBill.

        Body: {as_of?, period_start?, discount?, tax?, notes?}"""
        from decimal import Decimal, InvalidOperation
        patient = self.get_object()
        as_of = None
        raw = request.data.get('as_of')
        if raw:
            as_of = parse_datetime(raw)
            if as_of is not None and timezone.is_naive(as_of):
                as_of = timezone.make_aware(as_of)
        as_of = as_of or timezone.now()
        data = _compute_patient_care(patient, as_of=as_of)

        def _dec(v, default='0'):
            try:
                return Decimal(str(v if v not in (None, '') else default))
            except (InvalidOperation, TypeError):
                return Decimal(default)

        care = _dec(data['care_total'])
        equip = _dec(data['equipment_total'])
        supp = _dec(data['supplies_total'])
        meds = _dec(data['medication_total'])
        subtotal = care + equip + supp + meds
        discount = _dec(request.data.get('discount'))
        tax = _dec(request.data.get('tax'))
        total = (subtotal - discount + tax).quantize(Decimal('0.01'))
        total_paid = _dec(data['total_paid'])
        bill = PatientBill.objects.create(
            patient=patient,
            period_start=request.data.get('period_start') or None,
            as_of=as_of,
            currency=data['currency'],
            line_items=data['line_items'],
            care_total=care, equipment_total=equip,
            supplies_total=supp, medication_total=meds,
            subtotal=subtotal, discount=discount, tax=tax, total=total,
            amount_paid=total_paid,
            balance=(total - total_paid).quantize(Decimal('0.01')),
            status=(PatientBill.Status.PAID if total_paid >= total and total > 0
                    else (PatientBill.Status.PARTIAL if total_paid > 0
                          else PatientBill.Status.ISSUED)),
            notes=request.data.get('notes', ''),
            generated_by_user_id=getattr(request.user, 'id', None),
            generated_by_name=getattr(request.user, 'full_name', '') or '',
        )
        return Response(PatientBillSerializer(bill).data, status=201)

    @action(detail=False, methods=['get'], url_path='search-existing',
            permission_classes=[IsHomecareStaff])
    def search_existing(self, request):
        """Search for an existing patient before enrolment.

        Matches on patient id (MRN), name, national/ID number, email and phone.
        Returns two kinds of hits:
          - `homecare` : already enrolled in THIS homecare tenant (full details,
             so staff can open the profile instead of double-enrolling).
          - `account`  : a shared patient login exists but is NOT yet enrolled
             here (basic details, so staff can prefill and enrol quickly).
        """
        from django_tenants.utils import schema_context
        from django.contrib.auth import get_user_model

        q = (request.query_params.get('q') or '').strip()
        if len(q) < 2:
            return Response([])

        results = []

        # 1) Already-enrolled homecare patients in the current tenant.
        hc_qs = (
            self.get_queryset()
            .filter(
                Q(medical_record_number__icontains=q)
                | Q(id_number__icontains=q)
                | Q(user__first_name__icontains=q)
                | Q(user__last_name__icontains=q)
                | Q(user__email__icontains=q)
                | Q(user__phone__icontains=q)
            )
            .select_related('user')[:15]
        )
        enrolled_user_ids = set()
        for p in hc_qs:
            enrolled_user_ids.add(p.user_id)
            data = self.get_serializer(p).data
            results.append({
                'type': 'homecare',
                'enrolled': True,
                'patient_id': p.id,
                'user_id': p.user_id,
                'medical_record_number': p.medical_record_number,
                'first_name': p.user.first_name,
                'last_name': p.user.last_name,
                'full_name': p.user.full_name,
                'email': p.user.email,
                'phone': p.user.phone,
                'id_type': p.id_type,
                'id_number': p.id_number,
                'nationality': p.nationality,
                'date_of_birth': p.date_of_birth,
                'gender': p.gender,
                'address': p.address,
                'risk_level': p.risk_level,
                'detail': data,
            })

        # 2) Shared patient accounts (public schema) not yet enrolled here.
        #    Prefer the demographic-rich patients.Patient profile (holds the
        #    AdhereMed patient id like "AD13", national id, DOB, gender), then
        #    fall back to plain patient User accounts without a profile.
        UserModel = get_user_model()
        account_rows = []
        seen_user_ids = set(enrolled_user_ids)
        with schema_context('public'):
            from patients.models import Patient
            profile_qs = (
                Patient.objects.select_related('user')
                .filter(
                    Q(patient_id__icontains=q)
                    | Q(patient_number__icontains=q)
                    | Q(national_id__icontains=q)
                    | Q(user__first_name__icontains=q)
                    | Q(user__last_name__icontains=q)
                    | Q(user__email__icontains=q)
                    | Q(user__phone__icontains=q)
                )
                .order_by('user__first_name', 'user__last_name')[:15]
            )
            for p in profile_qs:
                if p.user_id in seen_user_ids:
                    continue
                seen_user_ids.add(p.user_id)
                dob = p.date_of_birth
                # The default self-registration DOB placeholder shouldn't prefill.
                if dob and str(dob) == '1900-01-01':
                    dob = None
                account_rows.append({
                    'type': 'account',
                    'enrolled': False,
                    'user_id': p.user_id,
                    'patient_id': p.patient_id,
                    'first_name': p.user.first_name,
                    'last_name': p.user.last_name,
                    'full_name': p.user.full_name,
                    'email': p.user.email,
                    'phone': p.user.phone,
                    'date_of_birth': dob,
                    'gender': (p.gender or '').capitalize(),
                    'national_id': p.national_id or '',
                    'address': p.address or '',
                })

            # Patient logins without a demographic profile.
            user_qs = (
                UserModel.objects.filter(role='patient')
                .filter(
                    Q(first_name__icontains=q)
                    | Q(last_name__icontains=q)
                    | Q(email__icontains=q)
                    | Q(phone__icontains=q)
                )
                .order_by('first_name', 'last_name')[:15]
            )
            for u in user_qs:
                if u.id in seen_user_ids:
                    continue
                seen_user_ids.add(u.id)
                account_rows.append({
                    'type': 'account',
                    'enrolled': False,
                    'user_id': u.id,
                    'first_name': u.first_name,
                    'last_name': u.last_name,
                    'full_name': u.full_name,
                    'email': u.email,
                    'phone': u.phone,
                })
        results.extend(account_rows)
        return Response(results)

    @action(detail=False, methods=['post'], url_path='enroll')
    def enroll(self, request):
        """Create a User + HomecarePatient in one call from a small payload."""
        from django_tenants.utils import schema_context
        from django.contrib.auth import get_user_model
        UserModel = get_user_model()
        d = request.data
        email = d.get('user_email') or d.get('email')
        if not email:
            return Response({'user_email': ['Required.']}, status=400)
        # Capture current tenant id before switching to public schema.
        tenant_id = getattr(getattr(request, 'tenant', None), 'id', None)
        # Users live in the public schema (accounts is in SHARED_APPS)
        generated_password = None
        with schema_context('public'):
            user, created = UserModel.objects.get_or_create(
                email=email,
                defaults={
                    'first_name': d.get('first_name', ''),
                    'last_name': d.get('last_name', ''),
                    'role': 'patient',
                },
            )
            if d.get('first_name'):
                user.first_name = d['first_name']
            if d.get('last_name'):
                user.last_name = d['last_name']
            if d.get('phone'):
                user.phone = d['phone']
            user.role = 'patient'
            # Bind patient to current homecare tenant so /auth/me returns the
            # right tenant_type and the patient self-service portal works.
            if tenant_id and not user.tenant_id:
                user.tenant_id = tenant_id
            if d.get('password'):
                user.set_password(d['password'])
            elif created or not user.has_usable_password():
                # Guarantee the patient can log in to their dashboard even when
                # staff didn't set a password: generate a temporary one and
                # surface it once so it can be shared with the patient.
                from django.utils.crypto import get_random_string
                generated_password = get_random_string(10)
                user.set_password(generated_password)
            user.save()
            uid = user.id

            # Ensure a shared (public-schema) AdhereMed patient profile exists so
            # the patient gets an AD id, can log in, and is discoverable by other
            # services (doctors, hospital, radiology, lab, pharmacy).
            import uuid as _uuid
            from patients.models import Patient
            profile, profile_created = Patient.objects.get_or_create(
                user=user,
                defaults={
                    'patient_number': f'PT-{_uuid.uuid4().hex[:8].upper()}',
                    'date_of_birth': d.get('date_of_birth') or '1900-01-01',
                    'gender': (d.get('gender') or 'other').lower()[:10],
                    'national_id': (d.get('id_number') or None),
                    'address': d.get('address', '') or '',
                    'registration_source': Patient.RegistrationSource.HOMECARE,
                },
            )
            if not profile_created:
                # Backfill demographics that were previously blank / placeholder.
                changed = []
                if d.get('date_of_birth') and str(profile.date_of_birth) == '1900-01-01':
                    profile.date_of_birth = d['date_of_birth']; changed.append('date_of_birth')
                if d.get('gender') and profile.gender in ('', 'other'):
                    profile.gender = d['gender'].lower()[:10]; changed.append('gender')
                if d.get('id_number') and not profile.national_id:
                    # Respect the unique constraint — skip if taken by someone else.
                    if not Patient.objects.filter(national_id=d['id_number']).exclude(pk=profile.pk).exists():
                        profile.national_id = d['id_number']; changed.append('national_id')
                if d.get('address') and not profile.address:
                    profile.address = d['address']; changed.append('address')
                if changed:
                    profile.save(update_fields=changed)
            patient_ad_id = profile.patient_id

        # Block accidental double-enrolment in the same tenant.
        existing = HomecarePatient.objects.filter(user_id=uid).first()
        if existing:
            return Response(
                {
                    'detail': 'This patient is already enrolled in this homecare.',
                    'patient_id': existing.id,
                },
                status=400,
            )

        patient = HomecarePatient.objects.create(
            user_id=uid,
            date_of_birth=d.get('date_of_birth') or None,
            gender=d.get('gender', ''),
            address=d.get('address', ''),
            address_lat=d.get('address_lat') or None,
            address_lng=d.get('address_lng') or None,
            id_type=d.get('id_type', ''),
            id_number=d.get('id_number', ''),
            nationality=d.get('nationality', '') or 'KE',
            primary_diagnosis=d.get('primary_diagnosis', ''),
            medical_history=d.get('medical_history', ''),
            allergies=d.get('allergies', ''),
            emergency_contacts=d.get('emergency_contacts') or [],
            risk_level=d.get('risk_level', 'low'),
            assigned_caregiver_id=d.get('assigned_caregiver') or None,
            assigned_doctor_user_id=d.get('assigned_doctor_user_id') or None,
            assigned_doctor_info=d.get('assigned_doctor_info') or {},
        )
        # Optional additional caregivers (M2M)
        extra_ids = d.get('additional_caregivers') or []
        if isinstance(extra_ids, list) and extra_ids:
            try:
                clean_ids = [int(x) for x in extra_ids if x]
                patient.additional_caregivers.set(
                    Caregiver.objects.filter(id__in=clean_ids)
                )
            except (TypeError, ValueError):
                pass
        # Create default data-sharing (everything shared with the patient portal).
        _get_or_create_sharing(patient)
        resp = self.get_serializer(patient).data
        resp['login_created'] = bool(created)
        resp['login_email'] = email
        resp['adheremed_patient_id'] = patient_ad_id
        if generated_password:
            resp['temporary_password'] = generated_password

        # Welcome email with patient ID + login details (temp password only for
        # newly-created accounts). Mail config lives in the public schema.
        try:
            hc_profile = HomecareCompanyProfile.objects.first()
            hc_name = hc_profile.legal_name if hc_profile else None
            with schema_context('public'):
                welcome_user = UserModel.objects.filter(id=uid).first()
                from superadmin.mailer import send_homecare_enrollment_email
                send_homecare_enrollment_email(
                    welcome_user,
                    patient_ad_id,
                    login_email=email,
                    temporary_password=generated_password,
                    homecare_name=hc_name,
                )
        except Exception:
            pass

        return Response(resp, status=201)

    @action(detail=True, methods=['get', 'patch'], url_path='sharing',
            permission_classes=[IsHomecareStaffOrPatient])
    def sharing(self, request, pk=None):
        """Read or update what this patient can see in their own portal.

        GET  — staff or the patient themselves (patient sees the effective map).
        PATCH — homecare staff only; toggles categories / master switch.
        """
        p = self.get_object()
        share = _get_or_create_sharing(p)
        is_patient = getattr(request.user, 'role', None) == 'patient'

        if request.method == 'PATCH':
            if is_patient:
                return Response(
                    {'detail': 'Only homecare staff can change sharing settings.'},
                    status=403,
                )
            data = PatientDataSharingSerializer(share, data=request.data, partial=True)
            data.is_valid(raise_exception=True)
            data.save(updated_by_user_id=getattr(request.user, 'id', None))
            share.refresh_from_db()

        payload = PatientDataSharingSerializer(share).data
        payload['effective'] = share.as_map()
        return Response(payload)

    @action(detail=False, methods=['get'], url_path='sharing-overview',
            permission_classes=[IsHomecareStaff])
    def sharing_overview(self, request):
        """List every enrolled patient with their sharing settings (staff UI)."""
        rows = []
        for p in self.get_queryset().filter(is_active=True):
            share = _get_or_create_sharing(p)
            rows.append(PatientDataSharingSerializer(share).data)
        return Response(rows)

    @action(detail=True, methods=['get'])
    def overview(self, request, pk=None):
        p = self.get_object()
        is_patient = getattr(request.user, 'role', None) == 'patient'
        # Patients only see categories the homecare has chosen to share.
        allow = _get_or_create_sharing(p).as_map() if is_patient else None

        def shared(key):
            return allow is None or allow.get(key, False)

        active_plan = p.treatment_plans.filter(status='active').first()
        adherence_qs = DoseEvent.objects.filter(schedule__patient=p)
        agg = adherence_qs.aggregate(
            total=Count('id'),
            taken=Count('id', filter=Q(status='taken')),
            missed=Count('id', filter=Q(status='missed')),
        )
        return Response({
            'patient': self.get_serializer(p).data,
            'sharing': allow,
            'active_plan': (
                TreatmentPlanSerializer(active_plan).data
                if active_plan and shared('share_treatment_plan') else None
            ),
            'medication_schedules': (
                MedicationScheduleSerializer(
                    p.medication_schedules.filter(is_active=True), many=True
                ).data if shared('share_medications') else []
            ),
            'recent_notes': (
                CaregiverNoteSerializer(
                    p.caregiver_notes.all()[:10], many=True
                ).data if shared('share_notes') else []
            ),
            'open_escalations': (
                EscalationSerializer(
                    p.escalations.filter(status='open'), many=True
                ).data if shared('share_escalations') else []
            ),
            'adherence': agg if shared('share_adherence') else None,
        })

    @action(detail=True, methods=['get'], url_path='vital-trend')
    def vital_trend(self, request, pk=None):
        """Returns time-series for each vital field over `days` (default 14).

        Output: {metric: [{t: iso, v: number}, ...]}
        Pulls from CaregiverNote.vitals JSON. Splits BP into systolic/diastolic.
        """
        from .loinc import LOINC_VITALS, vital_display, vital_unit
        p = self.get_object()
        try:
            days = max(1, min(int(request.query_params.get('days', '14')), 365))
        except ValueError:
            days = 14
        since = timezone.now() - timedelta(days=days)
        notes = (p.caregiver_notes
                 .filter(recorded_at__gte=since)
                 .order_by('recorded_at')
                 .values('recorded_at', 'vitals'))
        series: dict[str, list] = {}
        def _push(key, t, v):
            try:
                fv = float(v)
            except (TypeError, ValueError):
                return
            series.setdefault(key, []).append({'t': t.isoformat(), 'v': fv})
        for n in notes:
            v = n.get('vitals') or {}
            if not isinstance(v, dict):
                continue
            t = n['recorded_at']
            for k, raw in v.items():
                if raw in (None, ''):
                    continue
                if k == 'bp' and isinstance(raw, str) and '/' in raw:
                    try:
                        s, d = [float(x.strip()) for x in raw.split('/')[:2]]
                    except ValueError:
                        continue
                    _push('systolic', t, s)
                    _push('diastolic', t, d)
                else:
                    _push(k, t, raw)
        meta = {k: {'display': vital_display(k), 'unit': vital_unit(k),
                    'loinc': (LOINC_VITALS.get(k) or {}).get('code', '')}
                for k in series.keys()}
        return Response({'days': days, 'metrics': meta, 'series': series})

    @action(detail=True, methods=['get'])
    def fhir(self, request, pk=None):
        """Export patient as a FHIR R4 Bundle (Patient + recent Observations + Consents)."""
        from .fhir import (patient_resource, observation_resources_from_note,
                           consent_resource, bundle)
        p = self.get_object()
        resources = [patient_resource(p)]
        notes = p.caregiver_notes.order_by('-recorded_at')[:50]
        for n in notes:
            resources.extend(observation_resources_from_note(n))
        for c in p.consents.all():
            resources.append(consent_resource(c))
        return Response(bundle(resources))

    @action(detail=True, methods=['post'], url_path='apply-pathway')
    def apply_pathway(self, request, pk=None):
        """Enroll this patient in a CarePathway. Body: {pathway: id, start_date?}"""
        from .protocols import enroll_patient
        from .serializers import CarePathwayEnrollmentSerializer
        p = self.get_object()
        pw_id = request.data.get('pathway')
        if not pw_id:
            return Response({'pathway': ['Required.']}, status=400)
        try:
            pw = CarePathway.objects.get(pk=pw_id, is_active=True)
        except CarePathway.DoesNotExist:
            return Response({'pathway': ['Not found or inactive.']}, status=404)
        start = request.data.get('start_date') or None
        enrollment = enroll_patient(
            pw, p,
            started_by_user_id=getattr(request.user, 'id', None),
            start_date=start,
        )
        return Response(CarePathwayEnrollmentSerializer(enrollment).data, status=201)


# ─────────────────────────────────────────────────────────
class CaregiverScheduleViewSet(viewsets.ModelViewSet):
    queryset = CaregiverSchedule.objects.select_related(
        'caregiver__user', 'patient__user'
    ).all()
    serializer_class = CaregiverScheduleSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['caregiver', 'patient', 'status', 'shift_type']
    ordering_fields = ['start_at']

    def get_queryset(self):
        qs = super().get_queryset()
        # Auto-mark expired scheduled shifts as missed (lazy sweep on every list).
        # A shift is considered missed when it has fully ended without check-in.
        from django.db.models import Q
        from django.utils import timezone as _tz
        now = _tz.now()
        expired = qs.filter(
            status=CaregiverSchedule.Status.SCHEDULED,
            end_at__lt=now,
        )
        if expired.exists():
            expired.update(
                status=CaregiverSchedule.Status.MISSED,
                auto_missed_at=now,
                reassignment_requested=True,
                reassignment_reason='Auto-marked: shift ended without check-in',
            )
        user = self.request.user
        start_after = self.request.query_params.get('start_after')
        end_before = self.request.query_params.get('end_before')
        if start_after:
            qs = qs.filter(start_at__gte=start_after)
        if end_before:
            qs = qs.filter(end_at__lte=end_before)
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                return qs.filter(caregiver=cg)
            return qs.none()
        return qs

    def _verify_pin(self, sch, request):
        """Verify the PIN supplied in request.data against the acting user's
        unique 6-digit staff PIN (same PIN used in the dose-administration flow)."""
        provided = (str(request.data.get('pin') or '')).strip()
        expected = (getattr(request.user, 'pin', '') or '').strip()
        if not expected:
            return False, Response(
                {'pin': ['Your account has no staff PIN configured. '
                         'Ask an admin to issue one before checking in.']},
                status=400,
            )
        if not provided:
            return False, Response({'pin': ['PIN is required.']}, status=400)
        if provided != expected:
            return False, Response({'pin': ['Incorrect PIN.']}, status=400)
        return True, None

    @action(detail=True, methods=['post'])
    def check_in(self, request, pk=None):
        sch = self.get_object()
        if sch.status not in (CaregiverSchedule.Status.SCHEDULED,):
            return Response(
                {'detail': f'Cannot check in — shift status is {sch.status}.'}, status=400,
            )
        if not request.data.get('acknowledged'):
            return Response(
                {'acknowledged': ['You must acknowledge the visit to check in.']}, status=400,
            )
        gps = request.data.get('gps') or {}
        if not gps.get('lat') or not gps.get('lng'):
            return Response({'gps': ['Live location is required to check in.']}, status=400)
        ok, err = self._verify_pin(sch, request)
        if not ok:
            return err
        sch.status = CaregiverSchedule.Status.CHECKED_IN
        sch.check_in_at = timezone.now()
        sch.acknowledged_at = sch.check_in_at
        sch.gps_check_in = gps
        sch.save(update_fields=[
            'status', 'check_in_at', 'acknowledged_at', 'gps_check_in',
        ])
        return Response(self.get_serializer(sch).data)

    @action(detail=True, methods=['post'])
    def check_out(self, request, pk=None):
        sch = self.get_object()
        if sch.status != CaregiverSchedule.Status.CHECKED_IN:
            return Response(
                {'detail': f'Cannot check out — shift status is {sch.status}.'}, status=400,
            )
        gps = request.data.get('gps') or {}
        if not gps.get('lat') or not gps.get('lng'):
            return Response({'gps': ['Live location is required to check out.']}, status=400)
        ok, err = self._verify_pin(sch, request)
        if not ok:
            return err
        sch.status = CaregiverSchedule.Status.COMPLETED
        sch.check_out_at = timezone.now()
        sch.gps_check_out = gps
        sch.save(update_fields=['status', 'check_out_at', 'gps_check_out'])
        # Bump caregiver visit count
        from django.db.models import F
        Caregiver.objects.filter(pk=sch.caregiver_id).update(
            total_visits=F('total_visits') + 1
        )
        return Response(self.get_serializer(sch).data)

    @action(detail=True, methods=['post'])
    def mark_missed(self, request, pk=None):
        sch = self.get_object()
        reason = (request.data.get('reason') or '').strip()
        if not reason:
            return Response({'reason': ['Reason is required.']}, status=400)
        ok, err = self._verify_pin(sch, request)
        if not ok:
            return err
        sch.status = CaregiverSchedule.Status.MISSED
        sch.reassignment_requested = bool(request.data.get('request_reassign', True))
        sch.reassignment_reason = reason
        sch.save(update_fields=['status', 'reassignment_requested', 'reassignment_reason'])
        return Response(self.get_serializer(sch).data)

    @action(detail=True, methods=['post'], url_path='request-reassign')
    def request_reassign(self, request, pk=None):
        sch = self.get_object()
        sch.reassignment_requested = True
        sch.reassignment_reason = (request.data.get('reason') or '').strip() \
            or 'Reassignment requested'
        sch.save(update_fields=['reassignment_requested', 'reassignment_reason'])
        return Response(self.get_serializer(sch).data)

    @action(detail=True, methods=['post'])
    def reassign(self, request, pk=None):
        """Create a replacement schedule for a missed shift and link it back.
        Body: {caregiver: id, start_at?, end_at?}"""
        sch = self.get_object()
        new_cg = request.data.get('caregiver')
        if not new_cg:
            return Response({'caregiver': ['Required.']}, status=400)
        new_sch = CaregiverSchedule.objects.create(
            caregiver_id=new_cg,
            patient=sch.patient,
            shift_type=sch.shift_type,
            start_at=request.data.get('start_at') or sch.start_at,
            end_at=request.data.get('end_at') or sch.end_at,
            notes=f'Reassigned from missed shift #{sch.id}. {sch.notes}'.strip(),
        )
        sch.reassigned_to = new_sch
        sch.reassignment_requested = False
        sch.save(update_fields=['reassigned_to', 'reassignment_requested'])
        return Response(self.get_serializer(new_sch).data, status=201)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        sch = self.get_object()
        sch.status = CaregiverSchedule.Status.CANCELLED
        reason = (request.data.get('reason') or '').strip()
        if reason:
            sch.notes = (sch.notes + '\n' if sch.notes else '') + f'[Cancelled] {reason}'
            sch.save(update_fields=['status', 'notes'])
        else:
            sch.save(update_fields=['status'])
        return Response(self.get_serializer(sch).data)


# ─────────────────────────────────────────────────────────
class CaregiverNoteViewSet(viewsets.ModelViewSet):
    queryset = CaregiverNote.objects.select_related(
        'caregiver__user', 'patient__user'
    ).all()
    serializer_class = CaregiverNoteSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'caregiver', 'category']
    search_fields = ['content']
    ordering_fields = ['recorded_at']

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=self.request.user).first()
            if cg:
                return qs.filter(caregiver=cg)
            return qs.none()
        return qs


# ─────────────────────────────────────────────────────────
class TreatmentPlanViewSet(viewsets.ModelViewSet):
    queryset = TreatmentPlan.objects.select_related('patient__user').all()
    serializer_class = TreatmentPlanSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'status']
    search_fields = ['title', 'diagnosis']

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                return qs.filter(
                    Q(patient__assigned_caregiver=cg)
                    | Q(patient__additional_caregivers=cg)
                ).distinct()
            return qs.none()
        return qs


# ─────────────────────────────────────────────────────────
class MedicationScheduleViewSet(viewsets.ModelViewSet):
    queryset = MedicationSchedule.objects.select_related('patient__user').all()
    serializer_class = MedicationScheduleSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'is_active', 'requires_caregiver']
    search_fields = ['medication_name']

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                return qs.filter(
                    Q(patient__assigned_caregiver=cg)
                    | Q(patient__additional_caregivers=cg)
                ).distinct()
            return qs.none()
        return qs

    @action(detail=True, methods=['post'])
    def generate_doses(self, request, pk=None):
        from .services import expand_doses_for_schedule
        pin = str(request.data.get('pin') or request.data.get('acknowledged_by') or '').strip()
        if not pin or not request.user.pin or pin != request.user.pin:
            return Response(
                {'detail': 'PIN missing or does not match the logged-in user.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        sched = self.get_object()
        days = int(request.data.get('days_ahead') or 7)
        created = expand_doses_for_schedule(sched, days_ahead=days)
        now = timezone.now()
        sched.last_generation_at = now
        sched.last_generation_by = request.user
        sched.last_generation_by_name = request.user.full_name or ''
        sched.last_generation_by_role = getattr(request.user, 'role', '') or ''
        sched.last_generation_count = created
        sched.last_generation_days = days
        sched.save(update_fields=[
            'last_generation_at', 'last_generation_by', 'last_generation_by_name',
            'last_generation_by_role', 'last_generation_count', 'last_generation_days',
            'updated_at',
        ])
        return Response({
            'created': created,
            'acknowledged_by': {
                'id': request.user.id,
                'full_name': request.user.full_name,
                'role': request.user.role,
            },
            'acknowledged_at': now.isoformat(),
        })


# ─────────────────────────────────────────────────────────
class DoseEventViewSet(viewsets.ModelViewSet):
    queryset = DoseEvent.objects.select_related(
        'schedule__patient__user', 'administered_by_caregiver__user',
    ).all()
    serializer_class = DoseEventSerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['status', 'schedule', 'schedule__patient']
    ordering_fields = ['scheduled_at']

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        scheduled_from = self.request.query_params.get('from')
        scheduled_to = self.request.query_params.get('to')
        if scheduled_from:
            qs = qs.filter(scheduled_at__gte=scheduled_from)
        if scheduled_to:
            qs = qs.filter(scheduled_at__lte=scheduled_to)
        if user.role == 'patient':
            return qs.filter(schedule__patient__user=user)
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                return qs.filter(
                    Q(schedule__patient__assigned_caregiver=cg)
                    | Q(schedule__patient__additional_caregivers=cg)
                ).distinct()
            return qs.none()
        return qs

    def _verify_pin(self, request):
        pin = str(request.data.get('pin') or '').strip()
        user = request.user
        if not pin or not getattr(user, 'pin', None) or pin != user.pin:
            return False
        return True

    def _audit_entry(self, request, *, action, status_from, status_to,
                     reason='', notes='', extra=None):
        u = request.user
        entry = {
            'at': timezone.now().isoformat(),
            'by_id': u.id,
            'by_name': u.full_name or u.email,
            'by_role': getattr(u, 'role', '') or '',
            'action': action,
            'status_from': status_from,
            'status_to': status_to,
            'reason': reason or '',
            'notes': notes or '',
        }
        if extra:
            entry.update(extra)
        return entry

    def _apply_status(self, dose, *, status_value, request, action,
                      administered_at=None, reason='', notes='', auto_missed=False):
        prev = dose.status
        dose.status = status_value
        if notes:
            dose.notes = notes
        if reason:
            dose.reason = reason
        if status_value == DoseEvent.Status.TAKEN:
            dose.administered_at = administered_at or timezone.now()
            cg = Caregiver.objects.filter(user=request.user).first()
            if cg:
                dose.administered_by_caregiver = cg
            dose.administered_by_user = request.user
            dose.administered_by_name = request.user.full_name or ''
            dose.administered_by_role = getattr(request.user, 'role', '') or ''
            if request.data.get('vitals_pre'):
                dose.vitals_pre = request.data['vitals_pre']
            if request.data.get('vitals_post'):
                dose.vitals_post = request.data['vitals_post']
            if request.data.get('patient_confirmation'):
                dose.patient_confirmation = request.data['patient_confirmation']
        else:
            # Track who marked it (skip / not_given / missed edits)
            dose.administered_by_user = request.user
            dose.administered_by_name = request.user.full_name or ''
            dose.administered_by_role = getattr(request.user, 'role', '') or ''
            if administered_at is not None:
                dose.administered_at = administered_at
        if auto_missed:
            dose.auto_missed = True
        log = list(dose.audit_log or [])
        log.append(self._audit_entry(
            request, action=action, status_from=prev, status_to=status_value,
            reason=reason, notes=notes,
            extra={'administered_at': dose.administered_at.isoformat()
                   if dose.administered_at else None,
                   'auto': auto_missed},
        ))
        dose.audit_log = log
        dose.save()
        return dose

    @action(detail=True, methods=['post'])
    def mark_taken(self, request, pk=None):
        """Document a dose. Requires PIN."""
        if not self._verify_pin(request):
            return Response(
                {'detail': 'PIN missing or does not match the logged-in user.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        dose = self.get_object()
        notes = request.data.get('notes', '') or ''
        admin_at_raw = request.data.get('administered_at')
        admin_at = parse_datetime(admin_at_raw) if admin_at_raw else None
        return Response(self.get_serializer(self._apply_status(
            dose, status_value=DoseEvent.Status.TAKEN, request=request,
            action='document', administered_at=admin_at, notes=notes,
        )).data)

    @action(detail=True, methods=['post'])
    def mark_missed(self, request, pk=None):
        """Manual mark as missed (rare; usually auto)."""
        if not self._verify_pin(request):
            return Response({'detail': 'PIN missing or does not match the logged-in user.'},
                            status=status.HTTP_403_FORBIDDEN)
        return Response(self.get_serializer(self._apply_status(
            self.get_object(), status_value=DoseEvent.Status.MISSED, request=request,
            action='mark_missed',
            reason=request.data.get('reason', '') or '',
            notes=request.data.get('notes', '') or '',
        )).data)

    @action(detail=True, methods=['post'])
    def mark_skipped(self, request, pk=None):
        """Skip dose. Requires reason + PIN."""
        reason = (request.data.get('reason') or '').strip()
        if not reason:
            return Response({'detail': 'A reason is required to skip a dose.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if not self._verify_pin(request):
            return Response({'detail': 'PIN missing or does not match the logged-in user.'},
                            status=status.HTTP_403_FORBIDDEN)
        return Response(self.get_serializer(self._apply_status(
            self.get_object(), status_value=DoseEvent.Status.SKIPPED, request=request,
            action='skip', reason=reason,
            notes=request.data.get('notes', '') or '',
        )).data)

    @action(detail=True, methods=['post'])
    def mark_not_given(self, request, pk=None):
        """Mark dose as not given. Requires reason + PIN."""
        reason = (request.data.get('reason') or '').strip()
        if not reason:
            return Response({'detail': 'A reason is required.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if not self._verify_pin(request):
            return Response({'detail': 'PIN missing or does not match the logged-in user.'},
                            status=status.HTTP_403_FORBIDDEN)
        return Response(self.get_serializer(self._apply_status(
            self.get_object(), status_value=DoseEvent.Status.NOT_GIVEN, request=request,
            action='not_given', reason=reason,
            notes=request.data.get('notes', '') or '',
        )).data)

    @action(detail=True, methods=['post'])
    def edit_assessment(self, request, pk=None):
        """Edit an existing assessment. Allows changing status, dose, time
        and reason. Requires PIN and a reason."""
        if not self._verify_pin(request):
            return Response({'detail': 'PIN missing or does not match the logged-in user.'},
                            status=status.HTTP_403_FORBIDDEN)
        dose = self.get_object()
        new_status = request.data.get('status') or dose.status
        if new_status not in dict(DoseEvent.Status.choices):
            return Response({'detail': 'Invalid status.'},
                            status=status.HTTP_400_BAD_REQUEST)
        admin_at_raw = request.data.get('administered_at')
        admin_at = parse_datetime(admin_at_raw) if admin_at_raw else None
        reason = (request.data.get('reason') or '').strip()
        if not reason:
            return Response({'detail': 'A reason is required to edit an assessment.'},
                            status=status.HTTP_400_BAD_REQUEST)

        # Optional dosage change (record old/new in audit extra)
        new_dose_raw = request.data.get('dose')
        dose_change = None
        if new_dose_raw is not None:
            new_dose_val = str(new_dose_raw).strip()
            if new_dose_val and new_dose_val != (dose.dose or ''):
                dose_change = {'dose_from': dose.dose or '',
                               'dose_to': new_dose_val}
                dose.dose = new_dose_val

        result = self._apply_status(
            dose, status_value=new_status, request=request,
            action='edit_assessment', administered_at=admin_at, reason=reason,
            notes=request.data.get('notes', '') or '',
        )
        if dose_change:
            log = list(result.audit_log or [])
            if log:
                log[-1].update(dose_change)
                result.audit_log = log
                result.save(update_fields=['audit_log'])
        return Response(self.get_serializer(result).data)

    @action(detail=False, methods=['post'])
    def auto_expire(self, request):
        """Auto-mark pending doses as missed if scheduled > 60 min ago."""
        cutoff = timezone.now() - timezone.timedelta(minutes=60)
        qs = self.get_queryset().filter(
            status=DoseEvent.Status.PENDING, scheduled_at__lt=cutoff,
        )
        count = 0
        for dose in qs:
            prev = dose.status
            dose.status = DoseEvent.Status.MISSED
            dose.auto_missed = True
            log = list(dose.audit_log or [])
            log.append({
                'at': timezone.now().isoformat(),
                'by_id': None, 'by_name': 'system', 'by_role': 'system',
                'action': 'auto_missed',
                'status_from': prev, 'status_to': DoseEvent.Status.MISSED,
                'reason': 'No action within 60 minutes of scheduled time.',
                'notes': '', 'auto': True,
            })
            dose.audit_log = log
            dose.save(update_fields=['status', 'auto_missed', 'audit_log', 'updated_at'])
            count += 1
        return Response({'updated': count})

    @action(detail=False, methods=['get'])
    def today(self, request):
        today = timezone.localdate()
        qs = self.get_queryset().filter(scheduled_at__date=today)
        return Response(self.get_serializer(qs, many=True).data)


# ─────────────────────────────────────────────────────────
class EscalationRuleViewSet(viewsets.ModelViewSet):
    queryset = EscalationRule.objects.all()
    serializer_class = EscalationRuleSerializer
    permission_classes = [IsHomecareStaff]


class EscalationViewSet(viewsets.ModelViewSet):
    queryset = Escalation.objects.select_related('patient__user', 'rule').all()
    serializer_class = EscalationSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['status', 'severity', 'patient']

    @action(detail=True, methods=['post'])
    def acknowledge(self, request, pk=None):
        esc = self.get_object()
        esc.status = Escalation.Status.ACKNOWLEDGED
        esc.acknowledged_by = request.user
        esc.acknowledged_at = timezone.now()
        esc.save(update_fields=['status', 'acknowledged_by', 'acknowledged_at'])
        return Response(self.get_serializer(esc).data)

    @action(detail=True, methods=['post'])
    def resolve(self, request, pk=None):
        esc = self.get_object()
        esc.status = Escalation.Status.RESOLVED
        esc.resolved_at = timezone.now()
        esc.resolution_notes = request.data.get('notes', '')
        esc.save(update_fields=['status', 'resolved_at', 'resolution_notes'])
        return Response(self.get_serializer(esc).data)

    @action(detail=False, methods=['post'])
    def evaluate_now(self, request):
        from .services import evaluate_escalations
        created = evaluate_escalations()
        return Response({'created': created})


# ─────────────────────────────────────────────────────────
def _vitals_row(note, ad_id=None):
    """Flatten a vitals CaregiverNote into the shape the frontend expects."""
    v = note.vitals or {}

    def num(x):
        try:
            if x is None or x == '':
                return None
            return float(x)
        except (TypeError, ValueError):
            return None

    systolic = diastolic = None
    bp = v.get('bp')
    if isinstance(bp, str) and '/' in bp:
        parts = bp.split('/')
        systolic, diastolic = num(parts[0]), num(parts[1])
    if systolic is None:
        systolic = num(v.get('systolic'))
    if diastolic is None:
        diastolic = num(v.get('diastolic'))

    patient = note.patient
    patient_name = ''
    mrn = ''
    try:
        mrn = patient.medical_record_number or ''
        patient_name = patient.user.full_name if patient and patient.user else ''
    except Exception:
        pass

    return {
        'id': note.id,
        'patient': note.patient_id,
        'patient_name': patient_name,
        'medical_record_number': mrn,
        'adheremed_patient_id': ad_id or mrn,
        'recorded_at': note.recorded_at,
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': num(v.get('hr') or v.get('pulse')),
        'temperature': num(v.get('temp')),
        'spo2': num(v.get('spo2')),
        'rr': num(v.get('rr')),
        'glucose': num(v.get('glucose')),
        'weight': num(v.get('weight')),
        'oxygen': v.get('oxygen') or 'Room air',
        'oxygen_delivery': v.get('oxygen_delivery') or '',
        'scale2': bool(v.get('scale2')),
        'consciousness': v.get('consciousness') or 'A',
        'news2': v.get('news2'),
        'risk': v.get('risk') or '',
        'notes': note.content or '',
    }


def _adheremed_id_map(user_ids):
    """Return {user_id: adheremed patient_id} looked up in the public schema."""
    result = {}
    ids = [uid for uid in user_ids if uid]
    if not ids:
        return result
    try:
        from django_tenants.utils import schema_context
        from patients.models import Patient
        with schema_context('public'):
            for p in Patient.objects.filter(user_id__in=ids):
                result[p.user_id] = p.patient_id
    except Exception:
        pass
    return result


def _adheremed_id(patient):
    if not patient or not patient.user_id:
        return None
    return _adheremed_id_map([patient.user_id]).get(patient.user_id)


def _parse_vitals_payload(d):
    """Parse a vitals request body into (values, vitals_dict, news2)."""
    from .ews import compute_news2

    def num(x):
        try:
            if x is None or x == '':
                return None
            return float(x)
        except (TypeError, ValueError):
            return None

    oxygen_raw = d.get('oxygen')
    on_oxygen = bool(oxygen_raw) and str(oxygen_raw).strip().lower() not in (
        'room air', 'false', '0', 'none', ''
    )
    oxygen_delivery = (d.get('oxygen_delivery') or '').strip() if on_oxygen else ''
    scale2 = bool(d.get('scale2'))
    consciousness = (d.get('consciousness') or 'A')

    systolic = num(d.get('systolic') or d.get('sbp'))
    diastolic = num(d.get('diastolic'))
    pulse = num(d.get('pulse') or d.get('hr'))
    temp = num(d.get('temperature') or d.get('temp'))
    spo2 = num(d.get('spo2'))
    rr = num(d.get('rr'))
    glucose = num(d.get('glucose'))
    weight = num(d.get('weight'))

    news2 = compute_news2(
        rr=rr, spo2=spo2, scale2=scale2, on_oxygen=on_oxygen,
        sbp=systolic, hr=pulse, temp=temp, consciousness=consciousness,
    )

    vitals = {}
    if systolic is not None and diastolic is not None:
        vitals['bp'] = f"{int(systolic)}/{int(diastolic)}"
    elif systolic is not None:
        vitals['systolic'] = systolic
    if pulse is not None:
        vitals['hr'] = pulse
    if temp is not None:
        vitals['temp'] = temp
    if spo2 is not None:
        vitals['spo2'] = spo2
    if rr is not None:
        vitals['rr'] = rr
    if glucose is not None:
        vitals['glucose'] = glucose
    if weight is not None:
        vitals['weight'] = weight
    vitals['consciousness'] = consciousness
    vitals['oxygen'] = 'Supplemental O₂' if on_oxygen else 'Room air'
    if oxygen_delivery:
        vitals['oxygen_delivery'] = oxygen_delivery
    vitals['scale2'] = scale2
    vitals['news2'] = news2['total']
    vitals['risk'] = news2['band']

    values = {
        'systolic': systolic, 'diastolic': diastolic, 'pulse': pulse,
        'temp': temp, 'spo2': spo2, 'rr': rr, 'consciousness': consciousness,
    }
    return values, vitals, news2


def _resolve_doctor_email(patient):
    """Best-effort doctor email from the patient's assigned doctor."""
    info = patient.assigned_doctor_info or {}
    if isinstance(info, dict) and info.get('email'):
        return info.get('email')
    uid = patient.assigned_doctor_user_id
    if uid:
        try:
            from django.contrib.auth import get_user_model
            from django_tenants.utils import schema_context
            with schema_context('public'):
                u = get_user_model().objects.filter(id=uid).first()
                if u and u.email:
                    return u.email
        except Exception:
            pass
    return None


def _send_vitals_escalation_emails(patient, news2, vitals):
    """Email the assigned doctor and the patient about a high vitals reading."""
    try:
        from superadmin.mailer import send_vitals_escalation_email
    except Exception:
        return
    try:
        patient_name = patient.user.full_name if patient.user else 'Patient'
        patient_email = patient.user.email if patient.user else None
    except Exception:
        patient_name, patient_email = 'Patient', None

    doctor_email = _resolve_doctor_email(patient)

    hc_name = None
    try:
        prof = HomecareCompanyProfile.objects.first()
        hc_name = prof.legal_name if prof else None
    except Exception:
        pass

    def fmt(x):
        return '—' if x in (None, '') else x

    summary = [
        ('Respiratory rate', f"{fmt(vitals.get('rr'))} /min"),
        ('SpO₂', f"{fmt(vitals.get('spo2'))} %"),
        ('Blood pressure', fmt(vitals.get('bp'))),
        ('Heart rate', f"{fmt(vitals.get('hr'))} bpm"),
        ('Temperature', f"{fmt(vitals.get('temp'))} °C"),
        ('Consciousness (ACVPU)', fmt(vitals.get('consciousness'))),
    ]
    recorded_at = timezone.now()

    if doctor_email:
        send_vitals_escalation_email(
            doctor_email, patient_name=patient_name,
            news2_total=news2['total'], band=news2['band'],
            vitals_summary=summary, recorded_at=recorded_at,
            homecare_name=hc_name, recipient_role='clinician',
        )
    if patient_email:
        send_vitals_escalation_email(
            patient_email, patient_name=patient_name,
            news2_total=news2['total'], band=news2['band'],
            vitals_summary=summary, recorded_at=recorded_at,
            homecare_name=hc_name, recipient_role='patient',
        )


class HomecareVitalsViewSet(viewsets.ViewSet):
    """Record and list patient vitals with NEWS2 scoring + auto-escalation.

    Vitals are persisted as ``CaregiverNote`` rows (category=vitals) so they
    also feed the patient portal vital-trend view. A high NEWS2 score
    automatically opens an Escalation and emails the doctor and patient.
    """
    permission_classes = [IsHomecareStaff]

    def _scope(self, qs, user):
        if getattr(user, 'role', None) == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            return qs.filter(caregiver=cg) if cg else qs.none()
        return qs

    def _get_note(self, request, pk):
        qs = CaregiverNote.objects.filter(
            category=CaregiverNote.Category.VITALS
        ).select_related('patient__user')
        qs = self._scope(qs, request.user)
        return qs.filter(pk=pk).first()

    def list(self, request):
        qs = CaregiverNote.objects.filter(
            category=CaregiverNote.Category.VITALS
        ).select_related('patient__user')
        patient_id = request.query_params.get('patient')
        if patient_id:
            qs = qs.filter(patient_id=patient_id)
        qs = self._scope(qs, request.user).order_by('-recorded_at')[:200]
        notes = list(qs)
        ad_map = _adheremed_id_map({
            n.patient.user_id for n in notes if n.patient and n.patient.user_id
        })
        rows = [
            _vitals_row(n, ad_id=ad_map.get(n.patient.user_id) if n.patient else None)
            for n in notes
        ]
        return Response(rows)

    def retrieve(self, request, pk=None):
        note = self._get_note(request, pk)
        if not note:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(_vitals_row(note, ad_id=_adheremed_id(note.patient)))

    def create(self, request):
        d = request.data
        patient_id = d.get('patient')
        if not patient_id:
            return Response({'patient': ['This field is required.']},
                            status=status.HTTP_400_BAD_REQUEST)
        patient = HomecarePatient.objects.filter(pk=patient_id).first()
        if not patient:
            return Response({'patient': ['Patient not found.']},
                            status=status.HTTP_404_NOT_FOUND)

        # Attribute the reading to a caregiver (required FK on CaregiverNote).
        caregiver = (
            Caregiver.objects.filter(user=request.user).first()
            or patient.assigned_caregiver
            or Caregiver.objects.first()
        )
        if not caregiver:
            return Response(
                {'detail': 'No caregiver is available to attribute this reading.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        values, vitals, news2 = _parse_vitals_payload(d)

        note = CaregiverNote.objects.create(
            caregiver=caregiver,
            patient=patient,
            category=CaregiverNote.Category.VITALS,
            content=(d.get('notes') or '').strip()
            or f"Vitals recorded — NEWS2 {news2['total']} ({news2['band']} risk)",
            vitals=vitals,
            recorded_at=d.get('recorded_at') or timezone.now(),
        )

        escalation = None
        if news2['should_escalate']:
            try:
                detail_lines = (
                    f"NEWS2 {news2['total']} ({news2['band']} risk). "
                    f"RR {values['rr'] or '—'}, SpO2 {values['spo2'] or '—'}%, "
                    f"BP {vitals.get('bp', values['systolic'] or '—')}, "
                    f"HR {values['pulse'] or '—'}, "
                    f"Temp {values['temp'] or '—'}°C, ACVPU {values['consciousness']}."
                )
                escalation = Escalation.objects.create(
                    patient=patient,
                    triggered_at=timezone.now(),
                    reason=f"High NEWS2 vitals ({news2['total']}, {news2['band']})",
                    detail=detail_lines,
                    severity=news2['severity'],
                    status=Escalation.Status.OPEN,
                )
            except Exception:
                escalation = None
            # Notify the doctor and patient by email (best-effort).
            try:
                _send_vitals_escalation_emails(patient, news2, vitals)
            except Exception:
                pass

        row = _vitals_row(note, ad_id=_adheremed_id(patient))
        row['news2_breakdown'] = news2
        row['escalated'] = bool(escalation)
        if escalation:
            row['escalation'] = EscalationSerializer(escalation).data
        return Response(row, status=status.HTTP_201_CREATED)

    def update(self, request, pk=None):
        return self.partial_update(request, pk)

    def partial_update(self, request, pk=None):
        note = self._get_note(request, pk)
        if not note:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Merge existing stored values with the incoming payload so partial
        # edits keep any fields the client did not resend.
        existing = _vitals_row(note)
        d = dict(request.data)

        def pick(*keys, default=None):
            for k in keys:
                if k in d and d[k] not in (None, ''):
                    return d[k]
            return default

        merged = {
            'systolic': pick('systolic', 'sbp', default=existing.get('systolic')),
            'diastolic': pick('diastolic', default=existing.get('diastolic')),
            'pulse': pick('pulse', 'hr', default=existing.get('pulse')),
            'temperature': pick('temperature', 'temp', default=existing.get('temperature')),
            'spo2': pick('spo2', default=existing.get('spo2')),
            'rr': pick('rr', default=existing.get('rr')),
            'glucose': pick('glucose', default=existing.get('glucose')),
            'weight': pick('weight', default=existing.get('weight')),
            'oxygen': pick('oxygen', default=existing.get('oxygen')),
            'oxygen_delivery': pick('oxygen_delivery', default=existing.get('oxygen_delivery')),
            'scale2': d.get('scale2', existing.get('scale2')),
            'consciousness': pick('consciousness', default=existing.get('consciousness')),
        }

        _, vitals, news2 = _parse_vitals_payload(merged)

        note.vitals = vitals
        notes_text = d.get('notes')
        if notes_text is not None:
            note.content = (notes_text or '').strip() or \
                f"Vitals recorded — NEWS2 {news2['total']} ({news2['band']} risk)"
        if d.get('recorded_at'):
            note.recorded_at = d['recorded_at']
        note.save(update_fields=['vitals', 'content', 'recorded_at'])

        row = _vitals_row(note, ad_id=_adheremed_id(note.patient))
        row['news2_breakdown'] = news2
        return Response(row)

    def destroy(self, request, pk=None):
        note = self._get_note(request, pk)
        if not note:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        note.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────────────────
class TeleconsultRoomViewSet(viewsets.ModelViewSet):
    queryset = TeleconsultRoom.objects.select_related('patient__user').all()
    serializer_class = TeleconsultRoomSerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['status', 'patient', 'doctor_user_id']

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role == 'patient':
            return qs.filter(patient__user=self.request.user)
        return qs

    @action(detail=True, methods=['post'])
    def join(self, request, pk=None):
        room = self.get_object()
        if room.status == TeleconsultRoom.Status.SCHEDULED:
            room.status = TeleconsultRoom.Status.IN_PROGRESS
            room.started_at = timezone.now()
            room.save(update_fields=['status', 'started_at'])
        # Issue a short-lived signed JWT scoped to this room. Used by the
        # provider iframe / our verify endpoint so a leaked link cannot be
        # replayed indefinitely.
        from .tokens import issue_room_token
        token, exp = issue_room_token(room=room, user=request.user)
        base_url = (f'https://meet.jit.si/AfyaOne-{room.room_token}'
                    if room.provider == TeleconsultRoom.Provider.JITSI
                    else (room.join_urls.get('default') if isinstance(room.join_urls, dict) else ''))
        # Append jwt as fragment hash (Jitsi userInfo) — servers won't see it.
        join_url = base_url
        if base_url and room.provider == TeleconsultRoom.Provider.JITSI:
            join_url = f'{base_url}#config.prejoinPageEnabled=false'
        return Response({
            'room_token': str(room.room_token),
            'join_url': join_url,
            'access_token': token,
            'expires_at': exp.isoformat(),
            'provider': room.provider,
            'status': room.status,
        })

    @action(detail=True, methods=['post'], url_path='verify-token',
            permission_classes=[permissions.AllowAny])
    def verify_token(self, request, pk=None):
        """Validate a signed room token; used by the meeting bridge."""
        from .tokens import verify_room_token
        token = (request.data.get('token') or
                 request.query_params.get('token') or '')
        try:
            payload = verify_room_token(token)
        except Exception as exc:
            return Response({'valid': False, 'detail': str(exc)}, status=400)
        # Ensure the token matches the room being verified.
        if str(payload.get('room_id')) != str(pk):
            return Response({'valid': False, 'detail': 'room mismatch'}, status=400)
        return Response({'valid': True, 'payload': payload})

    @action(detail=True, methods=['post'])
    def end(self, request, pk=None):
        room = self.get_object()
        room.status = TeleconsultRoom.Status.ENDED
        room.ended_at = timezone.now()
        room.summary = request.data.get('summary', room.summary)
        room.save(update_fields=['status', 'ended_at', 'summary'])
        return Response(self.get_serializer(room).data)


# ─────────────────────────────────────────────────────────
class HomecareAppointmentViewSet(viewsets.ModelViewSet):
    queryset = HomecareAppointment.objects.select_related('patient__user', 'teleconsult_room').all()
    serializer_class = HomecareAppointmentSerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'appointment_type', 'status']
    ordering_fields = ['scheduled_at']

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role == 'patient':
            return qs.filter(patient__user=self.request.user)
        return qs


# ─────────────────────────────────────────────────────────
class HomecarePrescriptionViewSet(viewsets.ModelViewSet):
    queryset = HomecarePrescription.objects.select_related('patient__user', 'treatment_plan').all()
    serializer_class = HomecarePrescriptionSerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'pharmacy_status']

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role == 'patient':
            return qs.filter(patient__user=self.request.user)
        return qs

    @action(detail=True, methods=['post'])
    def forward_to_pharmacy(self, request, pk=None):
        rx = self.get_object()
        pharmacy_tenant_id = request.data.get('pharmacy_tenant_id')
        pharmacy_name = request.data.get('pharmacy_name', '')
        if not pharmacy_tenant_id:
            return Response({'pharmacy_tenant_id': ['Required.']}, status=400)
        # Create cross-schema PrescriptionExchange in public schema
        from django_tenants.utils import schema_context
        from exchange.models import PrescriptionExchange
        from tenants.models import Tenant
        current_schema = connection.schema_name
        with schema_context('public'):
            tenant = Tenant.objects.filter(schema_name=current_schema).first()
            ex = PrescriptionExchange.objects.create(
                hospital_tenant_id=tenant.id if tenant else 0,
                source_tenant_type='homecare',
                patient_user_id=rx.patient.user_id,
                prescription_ref=f'HC-RX-{rx.id}',
                items=rx.items,
                selected_pharmacy_tenant_id=pharmacy_tenant_id,
            )
            ex_id = ex.id
        rx.forwarded_to_pharmacy_tenant_id = pharmacy_tenant_id
        rx.forwarded_pharmacy_name = pharmacy_name
        rx.forwarded_at = timezone.now()
        rx.pharmacy_status = HomecarePrescription.PharmacyStatus.PENDING
        rx.exchange_ref = str(ex_id)
        rx.save()
        return Response(self.get_serializer(rx).data)

    @action(detail=True, methods=['post'])
    def approve_substitution(self, request, pk=None):
        rx = self.get_object()
        rx.patient_approved_substitution = bool(request.data.get('approved', True))
        rx.pharmacy_status = (
            HomecarePrescription.PharmacyStatus.SUBSTITUTED
            if rx.patient_approved_substitution else HomecarePrescription.PharmacyStatus.DECLINED
        )
        rx.save(update_fields=['patient_approved_substitution', 'pharmacy_status'])
        return Response(self.get_serializer(rx).data)

    @action(detail=True, methods=['get'])
    def fhir(self, request, pk=None):
        from .fhir import medication_request_resources, bundle
        rx = self.get_object()
        return Response(bundle(medication_request_resources(rx)))

    @action(detail=True, methods=['get', 'post'], url_path='safety-check')
    def safety_check(self, request, pk=None):
        """Run allergy + DDI + duplicate-therapy checks against this Rx.

        GET  — evaluate without persisting (preview).
        POST — evaluate, persist alerts to ``PrescriptionSafetyAlert``,
               and refresh the audit trail.
        """
        from .safety import evaluate_prescription
        rx = self.get_object()
        results = evaluate_prescription(rx)
        if request.method == 'GET':
            return Response({'alerts': results, 'persisted': False})
        # Wipe non-overridden alerts and re-create.
        PrescriptionSafetyAlert.objects.filter(
            prescription=rx, overridden=False
        ).delete()
        created = []
        for r in results:
            obj = PrescriptionSafetyAlert.objects.create(
                prescription=rx,
                kind=r['kind'],
                severity=r['severity'],
                message=r['message'][:255],
                detail=r.get('detail', ''),
                drugs=r.get('drugs', []),
            )
            created.append(obj)
        return Response({
            'alerts': PrescriptionSafetyAlertSerializer(
                rx.safety_alerts.all(), many=True
            ).data,
            'persisted': True,
        })

    @action(detail=True, methods=['post'], url_path='alerts/(?P<alert_id>[^/.]+)/override')
    def override_alert(self, request, pk=None, alert_id=None):
        try:
            alert = PrescriptionSafetyAlert.objects.get(
                pk=alert_id, prescription_id=pk
            )
        except PrescriptionSafetyAlert.DoesNotExist:
            return Response({'detail': 'Alert not found.'}, status=404)
        reason = (request.data.get('reason') or '').strip()
        if not reason:
            return Response({'reason': ['A clinical justification is required.']},
                            status=400)
        alert.overridden = True
        alert.override_reason = reason
        alert.overridden_at = timezone.now()
        if request.user.is_authenticated:
            alert.overridden_by = request.user
        alert.save()
        return Response(PrescriptionSafetyAlertSerializer(alert).data)


class PharmacyStockAlertViewSet(viewsets.ModelViewSet):
    queryset = PharmacyStockAlert.objects.select_related('patient__user').all()
    serializer_class = PharmacyStockAlertSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['stock_status', 'resolved', 'patient']

    @action(detail=True, methods=['post'])
    def resolve(self, request, pk=None):
        a = self.get_object()
        a.resolved = True
        a.save(update_fields=['resolved'])
        return Response(self.get_serializer(a).data)


# ─────────────────────────────────────────────────────────
class InsurancePolicyViewSet(viewsets.ModelViewSet):
    queryset = InsurancePolicy.objects.select_related('patient__user').all()
    serializer_class = InsurancePolicySerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'is_active', 'is_primary']

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role == 'patient':
            return qs.filter(patient__user=self.request.user)
        return qs


class InsuranceClaimViewSet(viewsets.ModelViewSet):
    queryset = InsuranceClaim.objects.select_related('patient__user', 'policy').all()
    serializer_class = InsuranceClaimSerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'status', 'claim_type', 'policy']
    ordering_fields = ['created_at', 'submitted_at', 'amount_requested']

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role == 'patient':
            return qs.filter(patient__user=self.request.user)
        return qs

    @action(detail=True, methods=['post'])
    def submit(self, request, pk=None):
        c = self.get_object()
        c.status = InsuranceClaim.Status.SUBMITTED
        c.submitted_at = timezone.now()
        c.save(update_fields=['status', 'submitted_at'])
        Notification.objects.create(
            recipient=c.patient.user,
            type=Notification.NotificationType.INSURANCE_CLAIM,
            title=f'Claim {c.claim_number} submitted',
            message=f'Claim for {c.policy.provider_name} submitted for KSh {c.amount_requested}.',
            data={'claim_id': c.id},
        )
        return Response(self.get_serializer(c).data)

    @action(detail=True, methods=['post'])
    def record_response(self, request, pk=None):
        c = self.get_object()
        new_status = request.data.get('status')
        if new_status not in dict(InsuranceClaim.Status.choices):
            return Response({'status': ['Invalid status.']}, status=400)
        c.status = new_status
        if 'approved_amount' in request.data:
            c.approved_amount = request.data['approved_amount']
        if 'denial_reason' in request.data:
            c.denial_reason = request.data['denial_reason']
        if 'payer_response' in request.data:
            c.payer_response = request.data['payer_response']
        c.save()
        Notification.objects.create(
            recipient=c.patient.user,
            type=Notification.NotificationType.INSURANCE_CLAIM,
            title=f'Claim {c.claim_number}: {c.get_status_display()}',
            message=(c.denial_reason or
                     f'Approved KSh {c.approved_amount or 0}.'),
            data={'claim_id': c.id, 'status': c.status},
        )
        return Response(self.get_serializer(c).data)


# ─────────────────────────────────────────────────────────
class ConsentViewSet(viewsets.ModelViewSet):
    queryset = Consent.objects.select_related('patient__user').all()
    serializer_class = ConsentSerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'scope']

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role == 'patient':
            return qs.filter(patient__user=self.request.user)
        return qs

    @action(detail=True, methods=['post'])
    def revoke(self, request, pk=None):
        c = self.get_object()
        c.revoked_at = timezone.now()
        c.save(update_fields=['revoked_at'])
        return Response(self.get_serializer(c).data)

    @action(detail=True, methods=['post'])
    def sign(self, request, pk=None):
        """Capture an e-signature for this consent.

        Expects ``signature_data_url`` (base64 PNG), ``signed_by_name``,
        and optional ``signed_by_relationship``. Stores actor IP / UA and
        a SHA-256 tamper hash.
        """
        import hashlib
        c = self.get_object()
        sig = request.data.get('signature_data_url') or ''
        name = (request.data.get('signed_by_name') or '').strip()
        if not sig or not sig.startswith('data:image/'):
            return Response({'signature_data_url': ['A signature image is required.']},
                            status=400)
        if not name:
            return Response({'signed_by_name': ['Required.']}, status=400)
        c.signature_data_url = sig
        c.signed_by_name = name[:255]
        c.signed_by_relationship = (request.data.get('signed_by_relationship') or '')[:80]
        c.signed_at = timezone.now()
        xf = request.META.get('HTTP_X_FORWARDED_FOR')
        c.signed_ip = (xf.split(',')[0].strip() if xf else request.META.get('REMOTE_ADDR'))
        c.signed_user_agent = (request.META.get('HTTP_USER_AGENT') or '')[:512]
        basis = (f'{c.scope}|{c.patient_id}|{c.signed_by_name}|'
                 f'{c.signed_at.isoformat()}|{sig}')
        c.signature_hash = hashlib.sha256(basis.encode('utf-8')).hexdigest()
        c.save()
        return Response(self.get_serializer(c).data)

    @action(detail=True, methods=['get'], url_path='verify-signature')
    def verify_signature(self, request, pk=None):
        import hashlib
        c = self.get_object()
        if not c.signature_hash or not c.signed_at:
            return Response({'valid': False, 'detail': 'Not signed.'}, status=400)
        basis = (f'{c.scope}|{c.patient_id}|{c.signed_by_name}|'
                 f'{c.signed_at.isoformat()}|{c.signature_data_url}')
        expected = hashlib.sha256(basis.encode('utf-8')).hexdigest()
        return Response({
            'valid': expected == c.signature_hash,
            'signed_at': c.signed_at,
            'signed_by_name': c.signed_by_name,
        })

    @action(detail=True, methods=['get'])
    def fhir(self, request, pk=None):
        from .fhir import consent_resource
        return Response(consent_resource(self.get_object()))


# ─────────────────────────────────────────────────────────
# Dashboard summary
# ─────────────────────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def dashboard_summary(request):
    today = timezone.localdate()
    week_ago = today - timedelta(days=7)

    active_patients = HomecarePatient.objects.filter(is_active=True).count()
    caregivers_total = Caregiver.objects.filter(employment_status='active').count()
    caregivers_on_duty = CaregiverSchedule.objects.filter(
        status=CaregiverSchedule.Status.CHECKED_IN
    ).values('caregiver').distinct().count()

    today_doses = DoseEvent.objects.filter(scheduled_at__date=today)
    dose_breakdown = today_doses.aggregate(
        total=Count('id'),
        taken=Count('id', filter=Q(status='taken')),
        missed=Count('id', filter=Q(status='missed')),
        pending=Count('id', filter=Q(status='pending')),
        skipped=Count('id', filter=Q(status='skipped')),
    )
    adherence = (
        round((dose_breakdown['taken'] / dose_breakdown['total']) * 100, 1)
        if dose_breakdown['total'] else None
    )

    open_escalations = Escalation.objects.filter(status='open').count()
    open_claims = InsuranceClaim.objects.exclude(
        status__in=['draft', 'paid', 'approved', 'denied']
    ).count()

    # 7-day adherence trend
    trend = []
    for i in range(6, -1, -1):
        d = today - timedelta(days=i)
        agg = DoseEvent.objects.filter(scheduled_at__date=d).aggregate(
            total=Count('id'),
            taken=Count('id', filter=Q(status='taken')),
        )
        rate = (
            round((agg['taken'] / agg['total']) * 100, 1)
            if agg['total'] else 0
        )
        trend.append({'date': d.isoformat(), 'rate': rate, 'total': agg['total']})

    upcoming_visits = CaregiverScheduleSerializer(
        CaregiverSchedule.objects.filter(
            start_at__gte=timezone.now()
        ).order_by('start_at')[:8],
        many=True,
    ).data

    recent_escalations = EscalationSerializer(
        Escalation.objects.filter(status__in=['open', 'acknowledged']).order_by('-triggered_at')[:5],
        many=True,
    ).data

    return Response({
        'kpis': {
            'active_patients': active_patients,
            'caregivers_total': caregivers_total,
            'caregivers_on_duty': caregivers_on_duty,
            'adherence_today': adherence,
            'open_escalations': open_escalations,
            'open_claims': open_claims,
        },
        'today_doses': dose_breakdown,
        'adherence_trend': trend,
        'upcoming_visits': upcoming_visits,
        'recent_escalations': recent_escalations,
    })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def caregiver_my_day(request):
    cg = Caregiver.objects.filter(user=request.user).first()
    if not cg:
        return Response({'detail': 'No caregiver profile.'}, status=404)
    today = timezone.localdate()
    visits = CaregiverSchedule.objects.filter(
        caregiver=cg, start_at__date=today,
    ).order_by('start_at')
    upcoming_doses = DoseEvent.objects.filter(
        schedule__patient__assigned_caregiver=cg,
        scheduled_at__date=today,
        status__in=['pending', 'taken', 'missed'],
    ).order_by('scheduled_at')
    return Response({
        'caregiver': CaregiverSerializer(cg).data,
        'visits': CaregiverScheduleSerializer(visits, many=True).data,
        'doses': DoseEventSerializer(upcoming_doses, many=True).data,
    })


# ─────────────────────────────────────────────────────────────────
#  Analytics module — aggregated insights across all homecare domains
# ─────────────────────────────────────────────────────────────────
from .permissions import IsHomecareStaff


# Presets → number of days (end date is always "today" unless custom).
_RANGE_PRESETS = {
    'today': 0, 'yesterday': 0, '7d': 6, '30d': 29,
    '90d': 89, '1y': 364,
}


def _parse_date_range(request):
    """Parse date range from query params.

    Supported ``range`` values: today, yesterday, 7d, 30d, 90d, 1y, all, custom.
    For ``custom`` the ``from`` and ``to`` ISO-date params are used.

    Returns ``{'start', 'end', 'dates', 'range'}`` where ``dates`` is a list of
    ``date`` objects (inclusive) for trend iteration.  ``start`` is ``None``
    when the range is unbounded ("all").
    """
    today = timezone.localdate()
    raw = (request.query_params.get('range') or '30d').strip().lower()

    if raw == 'custom':
        from_str = request.query_params.get('from')
        to_str = request.query_params.get('to')
        try:
            start = parse_date(from_str) if from_str else today - timedelta(days=29)
        except Exception:
            start = today - timedelta(days=29)
        try:
            end = parse_date(to_str) if to_str else today
        except Exception:
            end = today
        if end > today:
            end = today
        if start > end:
            start, end = end, start
    elif raw in ('all', 'all_time'):
        start = None
        end = today
    elif raw in _RANGE_PRESETS:
        n = _RANGE_PRESETS[raw]
        if raw == 'yesterday':
            end = today - timedelta(days=1)
        else:
            end = today
        start = end - timedelta(days=n)
    else:
        start = today - timedelta(days=29)
        end = today
        raw = '30d'

    if start is None:
        # 'all' — build a 90-day trend window ending today
        dates = [today - timedelta(days=i) for i in range(89, -1, -1)]
    else:
        delta = (end - start).days
        dates = [start + timedelta(days=i) for i in range(delta + 1)]

    return {'start': start, 'end': end, 'dates': dates, 'range': raw}


def _adherence_rate(taken, total):
    return round((taken / total) * 100, 1) if total else 0


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_overview(request):
    """Cross-cutting KPIs and trends for the analytics landing page."""
    today = timezone.localdate()
    month_start = today.replace(day=1)
    dr = _parse_date_range(request)
    dates = dr['dates']
    start = dr['start'] if dr['start'] else dates[0]

    patients = HomecarePatient.objects.filter(is_active=True).count()
    all_patients = HomecarePatient.objects.count()
    caregivers = Caregiver.objects.filter(employment_status='active').count()
    on_duty = CaregiverSchedule.objects.filter(
        status=CaregiverSchedule.Status.CHECKED_IN
    ).values('caregiver').distinct().count()

    # Adherence (range)
    dose_qs = DoseEvent.objects.filter(scheduled_at__date__gte=start)
    dose_agg = dose_qs.aggregate(
        total=Count('id'),
        taken=Count('id', filter=Q(status='taken')),
        missed=Count('id', filter=Q(status='missed')),
        skipped=Count('id', filter=Q(status='skipped')),
        refused=Count('id', filter=Q(status='refused')),
    )
    adherence_30d = _adherence_rate(dose_agg['taken'], dose_agg['total'])

    # Today adherence
    today_doses = DoseEvent.objects.filter(scheduled_at__date=today).aggregate(
        total=Count('id'), taken=Count('id', filter=Q(status='taken')))
    adherence_today = _adherence_rate(today_doses['taken'], today_doses['total'])

    # Visits
    visits_30d = CaregiverSchedule.objects.filter(start_at__date__gte=start)
    visits_completed = visits_30d.filter(status='completed').count()
    visits_missed = visits_30d.filter(status='missed').count()
    visits_today = CaregiverSchedule.objects.filter(
        start_at__date=today, status='completed').count()

    # Escalations
    escalations_open = Escalation.objects.filter(status='open').count()
    escalations_30d = Escalation.objects.filter(triggered_at__date__gte=start).count()
    escalations_resolved_30d = Escalation.objects.filter(
        status='resolved', resolved_at__date__gte=start).count()

    # Financials
    bills_qs = PatientBill.objects.exclude(status='void')
    total_billed = bills_qs.aggregate(t=Sum('total'))['t'] or 0
    total_collected = PatientPayment.objects.filter(
        paid_at__date__gte=start).aggregate(t=Sum('amount'))['t'] or 0
    outstanding = bills_qs.exclude(status='paid').aggregate(
        t=Sum('balance'))['t'] or 0
    monthly_revenue = PatientPayment.objects.filter(
        paid_at__date__gte=month_start).aggregate(t=Sum('amount'))['t'] or 0

    # Insurance
    claims_open = InsuranceClaim.objects.exclude(
        status__in=['draft', 'paid', 'denied']).count()
    claims_30d = InsuranceClaim.objects.filter(
        created_at__date__gte=start).count()

    # Equipment
    devices = Device.objects.exclude(status='retired')
    devices_available = devices.filter(status='available').count()
    devices_assigned = devices.filter(status='assigned').count()
    devices_maintenance = devices.filter(status__in=['maintenance', 'repair']).count()
    total_units = devices.aggregate(t=Sum('quantity'))['t'] or 0
    hired = total_units - (devices.aggregate(t=Sum('quantity_available'))['t'] or 0)
    utilisation = round(hired / total_units * 100, 1) if total_units else 0

    # Teleconsult
    teleconsults_30d = TeleconsultRoom.objects.filter(
        scheduled_at__date__gte=start).count()

    # Vitals recorded
    vitals_30d = CaregiverNote.objects.filter(
        category='vitals', recorded_at__date__gte=start).count()

    # Adherence trend
    adherence_trend = []
    for d in dates:
        agg = DoseEvent.objects.filter(scheduled_at__date=d).aggregate(
            total=Count('id'), taken=Count('id', filter=Q(status='taken')))
        adherence_trend.append({
            'date': d.isoformat(),
            'rate': _adherence_rate(agg['taken'], agg['total']),
            'total': agg['total'],
        })

    # Visit trend
    visit_trend = []
    for d in dates:
        day_qs = CaregiverSchedule.objects.filter(start_at__date=d)
        visit_trend.append({
            'date': d.isoformat(),
            'completed': day_qs.filter(status='completed').count(),
            'missed': day_qs.filter(status='missed').count(),
            'scheduled': day_qs.count(),
        })

    # Revenue trend
    revenue_trend = []
    for d in dates:
        amt = PatientPayment.objects.filter(paid_at__date=d).aggregate(
            t=Sum('amount'))['t'] or 0
        revenue_trend.append({'date': d.isoformat(), 'amount': float(amt)})

    return Response({
        'range': dr['range'],
        'kpis': {
            'active_patients': patients,
            'total_patients': all_patients,
            'caregivers': caregivers,
            'on_duty': on_duty,
            'adherence_today': adherence_today,
            'adherence_30d': adherence_30d,
            'visits_today': visits_today,
            'visits_completed_30d': visits_completed,
            'visits_missed_30d': visits_missed,
            'escalations_open': escalations_open,
            'escalations_30d': escalations_30d,
            'escalations_resolved_30d': escalations_resolved_30d,
            'total_billed': float(total_billed),
            'total_collected_30d': float(total_collected),
            'outstanding': float(outstanding),
            'monthly_revenue': float(monthly_revenue),
            'claims_open': claims_open,
            'claims_30d': claims_30d,
            'devices_available': devices_available,
            'devices_assigned': devices_assigned,
            'devices_maintenance': devices_maintenance,
            'utilisation': utilisation,
            'teleconsults_30d': teleconsults_30d,
            'vitals_30d': vitals_30d,
        },
        'dose_breakdown': {
            'taken': dose_agg['taken'],
            'missed': dose_agg['missed'],
            'skipped': dose_agg['skipped'],
            'refused': dose_agg['refused'],
            'pending': dose_agg['total'] - dose_agg['taken'] - dose_agg['missed']
                       - dose_agg['skipped'] - dose_agg['refused'],
            'total': dose_agg['total'],
        },
        'adherence_trend': adherence_trend,
        'visit_trend': visit_trend,
        'revenue_trend': revenue_trend,
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_patients(request):
    """Patient demographics, risk distribution, enrolment trend."""
    today = timezone.localdate()
    dr = _parse_date_range(request)
    dates = dr['dates']
    start = dr['start'] if dr['start'] else dates[0]

    qs = HomecarePatient.objects.all()
    active = qs.filter(is_active=True).count()
    discharged = qs.filter(is_active=False).count()

    # New enrolments within range
    new_enrolments = qs.filter(enrolled_at__date__gte=start).count()

    # Risk distribution
    risk = {}
    for choice in HomecarePatient.RiskLevel.choices:
        risk[choice[0]] = qs.filter(risk_level=choice[0]).count()

    # Gender distribution
    gender = qs.values('gender').annotate(count=Count('id'))
    gender_map = {g['gender'] or 'unknown': g['count'] for g in gender}

    # Age groups
    age_groups = {'0-17': 0, '18-39': 0, '40-64': 0, '65+': 0, 'unknown': 0}
    for p in qs.exclude(date_of_birth__isnull=True):
        age = (today - p.date_of_birth).days / 365.25
        if age < 18:
            age_groups['0-17'] += 1
        elif age < 40:
            age_groups['18-39'] += 1
        elif age < 65:
            age_groups['40-64'] += 1
        else:
            age_groups['65+'] += 1
    age_groups['unknown'] = qs.filter(date_of_birth__isnull=True).count()

    # Enrolment trend
    enrolment_trend = []
    for d in dates:
        c = qs.filter(enrolled_at__date=d).count()
        enrolment_trend.append({'date': d.isoformat(), 'count': c})

    # Top diagnoses
    diag_qs = qs.exclude(primary_diagnosis='').values('primary_diagnosis').annotate(
        count=Count('id')).order_by('-count')[:10]
    top_diagnoses = [
        {'name': d['primary_diagnosis'], 'count': d['count']} for d in diag_qs
    ]

    # Assigned vs unassigned
    assigned = qs.exclude(assigned_caregiver__isnull=True).count()
    unassigned = qs.filter(assigned_caregiver__isnull=True).count()

    # Per-patient breakdown (for the patient analytics table)
    patients = []
    for p in qs.select_related('user', 'assigned_caregiver__user'):
        age = None
        if p.date_of_birth:
            age = int((today - p.date_of_birth).days / 365.25)
        patients.append({
            'id': p.id,
            'mrn': p.medical_record_number,
            'name': p.user.full_name if p.user else '—',
            'gender': p.gender or 'unknown',
            'age': age,
            'risk_level': p.risk_level,
            'primary_diagnosis': p.primary_diagnosis or '',
            'assigned_caregiver': (
                p.assigned_caregiver.user.full_name
                if p.assigned_caregiver and p.assigned_caregiver.user else None
            ),
            'enrolled_at': p.enrolled_at.isoformat() if p.enrolled_at else None,
            'is_active': p.is_active,
        })

    return Response({
        'range': dr['range'],
        'active': active,
        'discharged': discharged,
        'total': active + discharged,
        'new_enrolments': new_enrolments,
        'risk': risk,
        'gender': gender_map,
        'age_groups': age_groups,
        'enrolment_trend': enrolment_trend,
        'top_diagnoses': top_diagnoses,
        'assigned': assigned,
        'unassigned': unassigned,
        'patients': patients,
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_workforce(request):
    """Caregiver workforce composition, ratings, and visit performance."""
    dr = _parse_date_range(request)
    dates = dr['dates']
    start = dr['start'] if dr['start'] else dates[0]

    cg = Caregiver.objects.all()
    by_status = {}
    for choice in Caregiver.EmploymentStatus.choices:
        by_status[choice[0]] = cg.filter(employment_status=choice[0]).count()
    by_category = {}
    for choice in Caregiver.Category.choices:
        by_category[choice[0]] = cg.filter(category=choice[0]).count()

    available = cg.filter(is_available=True).count()
    avg_rating = cg.aggregate(a=Avg('rating'))['a'] or 0
    total_visits = cg.aggregate(t=Sum('total_visits'))['t'] or 0

    # Top caregivers by total visits
    top_caregivers = []
    for c in cg.order_by('-total_visits')[:10]:
        top_caregivers.append({
            'id': c.id,
            'name': c.user.full_name,
            'category': c.category,
            'rating': float(c.rating),
            'total_visits': c.total_visits,
            'is_available': c.is_available,
            'employment_status': c.employment_status,
        })

    # Visits completed in range per caregiver
    visit_by_cg = (
        CaregiverSchedule.objects.filter(
            start_at__date__gte=start, status='completed')
        .values('caregiver__user__first_name', 'caregiver__user__last_name',
                'caregiver')
        .annotate(count=Count('id'))
        .order_by('-count')[:10]
    )
    visit_leaders = [
        {
            'name': f"{v['caregiver__user__first_name'] or ''} "
                    f"{v['caregiver__user__last_name'] or ''}".strip() or '—',
            'visits': v['count'],
        }
        for v in visit_by_cg
    ]

    # On duty right now
    on_duty = CaregiverSchedule.objects.filter(
        status=CaregiverSchedule.Status.CHECKED_IN
    ).values('caregiver').distinct().count()

    return Response({
        'range': dr['range'],
        'total': cg.count(),
        'active': by_status.get('active', 0),
        'on_leave': by_status.get('on_leave', 0),
        'suspended': by_status.get('suspended', 0),
        'terminated': by_status.get('terminated', 0),
        'by_status': by_status,
        'by_category': by_category,
        'available': available,
        'avg_rating': round(float(avg_rating), 2),
        'total_visits': total_visits,
        'on_duty': on_duty,
        'top_caregivers': top_caregivers,
        'visit_leaders': visit_leaders,
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_visits(request):
    """Visit / schedule analytics — status, shift type, trends, completion rate."""
    dr = _parse_date_range(request)
    dates = dr['dates']
    start = dr['start'] if dr['start'] else dates[0]
    qs = CaregiverSchedule.objects.filter(start_at__date__gte=start)

    by_status = {}
    for choice in CaregiverSchedule.Status.choices:
        by_status[choice[0]] = qs.filter(status=choice[0]).count()

    by_shift = {}
    for choice in CaregiverSchedule.ShiftType.choices:
        by_shift[choice[0]] = qs.filter(shift_type=choice[0]).count()

    total = qs.count()
    completed = by_status.get('completed', 0)
    missed = by_status.get('missed', 0)
    cancelled = by_status.get('cancelled', 0)
    completion_rate = round(completed / total * 100, 1) if total else 0
    miss_rate = round(missed / total * 100, 1) if total else 0

    # 30-day trend
    trend = []
    for d in dates:
        day_qs = CaregiverSchedule.objects.filter(start_at__date=d)
        trend.append({
            'date': d.isoformat(),
            'scheduled': day_qs.count(),
            'completed': day_qs.filter(status='completed').count(),
            'missed': day_qs.filter(status='missed').count(),
            'cancelled': day_qs.filter(status='cancelled').count(),
        })

    # Average visit duration (completed with check-in/out)
    completed_qs = qs.filter(
        status='completed', check_in_at__isnull=False,
        check_out_at__isnull=False)
    durations = []
    for v in completed_qs[:500]:
        if v.check_in_at and v.check_out_at:
            delta = v.check_out_at - v.check_in_at
            durations.append(delta.total_seconds() / 3600)
    avg_duration = round(sum(durations) / len(durations), 1) if durations else 0

    # Reassignment requests
    reassignments = qs.filter(reassignment_requested=True).count()

    return Response({
        'range': dr['range'],
        'total_30d': total,
        'by_status': by_status,
        'by_shift_type': by_shift,
        'completed': completed,
        'missed': missed,
        'cancelled': cancelled,
        'completion_rate': completion_rate,
        'miss_rate': miss_rate,
        'avg_duration_hours': avg_duration,
        'reassignments': reassignments,
        'trend': trend,
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_adherence(request):
    """Medication adherence deep-dive — trends, dose breakdown, per-patient."""
    dr = _parse_date_range(request)
    dates = dr['dates']
    start = dr['start'] if dr['start'] else dates[0]
    qs = DoseEvent.objects.filter(scheduled_at__date__gte=start)

    # Overall breakdown
    breakdown = qs.aggregate(
        total=Count('id'),
        taken=Count('id', filter=Q(status='taken')),
        missed=Count('id', filter=Q(status='missed')),
        skipped=Count('id', filter=Q(status='skipped')),
        refused=Count('id', filter=Q(status='refused')),
        not_given=Count('id', filter=Q(status='not_given')),
        pending=Count('id', filter=Q(status='pending')),
        auto_missed=Count('id', filter=Q(auto_missed=True)),
    )
    rate = _adherence_rate(breakdown['taken'], breakdown['total'])

    # 30-day trend
    trend = []
    for d in dates:
        agg = DoseEvent.objects.filter(scheduled_at__date=d).aggregate(
            total=Count('id'),
            taken=Count('id', filter=Q(status='taken')),
            missed=Count('id', filter=Q(status='missed')),
        )
        trend.append({
            'date': d.isoformat(),
            'rate': _adherence_rate(agg['taken'], agg['total']),
            'total': agg['total'],
            'taken': agg['taken'],
            'missed': agg['missed'],
        })

    # Per-patient adherence (top + bottom 10)
    patient_ids = list(
        MedicationSchedule.objects.filter(is_active=True)
        .values_list('patient_id', flat=True).distinct()
    )
    patient_stats = []
    for pat_id in patient_ids:
        pat = HomecarePatient.objects.filter(pk=pat_id).first()
        if not pat:
            continue
        pat_doses = DoseEvent.objects.filter(
            schedule__patient=pat, scheduled_at__date__gte=start)
        agg = pat_doses.aggregate(
            total=Count('id'), taken=Count('id', filter=Q(status='taken')))
        if agg['total'] >= 5:
            patient_stats.append({
                'id': pat.id,
                'name': pat.user.full_name,
                'total': agg['total'],
                'taken': agg['taken'],
                'rate': _adherence_rate(agg['taken'], agg['total']),
            })
    patient_stats.sort(key=lambda x: x['rate'], reverse=True)
    best = patient_stats[:10]
    worst = sorted(patient_stats[-10:], key=lambda x: x['rate'])

    # Caregiver-administered doses
    cg_administered = qs.exclude(administered_by_caregiver__isnull=True).count()

    return Response({
        'range': dr['range'],
        'rate': rate,
        'breakdown': breakdown,
        'trend': trend,
        'best_patients': best,
        'worst_patients': worst,
        'caregiver_administered': cg_administered,
        'total_patients_tracked': len(patient_stats),
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_escalations(request):
    """Escalation analytics — severity, status, resolution."""
    dr = _parse_date_range(request)
    dates = dr['dates']
    start = dr['start'] if dr['start'] else dates[0]
    qs = Escalation.objects.filter(triggered_at__date__gte=start)

    by_severity = {}
    for choice in Escalation.Severity.choices:
        by_severity[choice[0]] = qs.filter(severity=choice[0]).count()

    by_status = {}
    for choice in Escalation.Status.choices:
        by_status[choice[0]] = qs.filter(status=choice[0]).count()

    # Trend
    trend = []
    for d in dates:
        c = Escalation.objects.filter(triggered_at__date=d).count()
        r = Escalation.objects.filter(resolved_at__date=d).count()
        trend.append({'date': d.isoformat(), 'triggered': c, 'resolved': r})

    # Top reasons
    reason_qs = qs.values('reason').annotate(count=Count('id')).order_by('-count')[:10]
    top_reasons = [{'reason': r['reason'], 'count': r['count']} for r in reason_qs]

    # Resolution time (hours)
    resolved = Escalation.objects.filter(
        status='resolved', resolved_at__isnull=False, triggered_at__isnull=False)
    res_times = []
    for e in resolved[:500]:
        delta = e.resolved_at - e.triggered_at
        res_times.append(delta.total_seconds() / 3600)
    avg_resolution = round(sum(res_times) / len(res_times), 1) if res_times else 0

    return Response({
        'range': dr['range'],
        'total_30d': qs.count(),
        'open': Escalation.objects.filter(status='open').count(),
        'acknowledged': Escalation.objects.filter(status='acknowledged').count(),
        'by_severity': by_severity,
        'by_status': by_status,
        'trend': trend,
        'top_reasons': top_reasons,
        'avg_resolution_hours': avg_resolution,
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_financials(request):
    """Billing & payment analytics — revenue, outstanding, payment methods."""
    dr = _parse_date_range(request)
    dates = dr['dates']
    start = dr['start'] if dr['start'] else dates[0]
    month_start = timezone.localdate().replace(day=1)

    bills = PatientBill.objects.exclude(status='void')
    by_status = {}
    for choice in PatientBill.Status.choices:
        by_status[choice[0]] = bills.filter(status=choice[0]).count()

    total_billed = bills.aggregate(t=Sum('total'))['t'] or 0
    total_collected = PatientPayment.objects.filter(
        paid_at__date__gte=start).aggregate(t=Sum('amount'))['t'] or 0
    outstanding = bills.exclude(status='paid').aggregate(t=Sum('balance'))['t'] or 0
    monthly_revenue = PatientPayment.objects.filter(
        paid_at__date__gte=month_start).aggregate(t=Sum('amount'))['t'] or 0

    # Payments by method (range)
    method_qs = PatientPayment.objects.filter(
        paid_at__date__gte=start).values('method').annotate(
        count=Count('id'), total=Sum('amount'))
    by_method = {
        (m['method'] or 'other'): {'count': m['count'], 'total': float(m['total'] or 0)}
        for m in method_qs
    }

    # 30-day revenue trend
    revenue_trend = []
    for d in dates:
        amt = PatientPayment.objects.filter(paid_at__date=d).aggregate(
            t=Sum('amount'))['t'] or 0
        billed = PatientBill.objects.filter(created_at__date=d).aggregate(
            t=Sum('total'))['t'] or 0
        revenue_trend.append({
            'date': d.isoformat(),
            'collected': float(amt),
            'billed': float(billed),
        })

    # Bills by category totals (all-time)
    cat_totals = bills.aggregate(
        care=Sum('care_total'),
        equipment=Sum('equipment_total'),
        supplies=Sum('supplies_total'),
        medication=Sum('medication_total'),
    )

    # Per-patient revenue breakdown (for the expandable revenue-analysis table)
    from decimal import Decimal
    patient_rows = []
    patients_qs = HomecarePatient.objects.select_related('user').prefetch_related(
        'bills__payments',
    )
    for p in patients_qs:
        pbills = [b for b in p.bills.all() if b.status != PatientBill.Status.VOID]
        if not pbills:
            continue
        p_billed = sum((Decimal(b.total) for b in pbills), Decimal('0'))
        p_paid = sum((Decimal(b.amount_paid) for b in pbills), Decimal('0'))
        p_outstanding = sum(
            (Decimal(b.balance) for b in pbills if b.status != PatientBill.Status.PAID),
            Decimal('0'),
        )
        overdue_count = sum(
            1 for b in pbills
            if b.status != PatientBill.Status.PAID and Decimal(b.balance) > 0
        )
        bill_rows = []
        for b in pbills:
            bill_rows.append({
                'id': b.id,
                'bill_number': b.bill_number,
                'total': float(b.total),
                'amount_paid': float(b.amount_paid),
                'balance': float(b.balance),
                'status': b.status,
                'currency': b.currency,
                'created_at': b.created_at.isoformat() if b.created_at else None,
                'line_items': b.line_items or [],
                'payments': [
                    {
                        'id': pay.id,
                        'amount': float(pay.amount),
                        'method': pay.method,
                        'reference': pay.reference,
                        'paid_at': pay.paid_at.isoformat() if pay.paid_at else None,
                    }
                    for pay in b.payments.all()
                ],
            })
        patient_rows.append({
            'id': p.id,
            'name': p.user.full_name if p.user else '—',
            'mrn': p.medical_record_number,
            'bill_count': len(pbills),
            'total_billed': float(p_billed),
            'amount_paid': float(p_paid),
            'outstanding': float(p_outstanding),
            'overdue_count': overdue_count,
            'last_bill_date': pbills[0].created_at.isoformat() if pbills[0].created_at else None,
            'bills': bill_rows,
        })
    # Highest outstanding first
    patient_rows.sort(key=lambda r: r['outstanding'], reverse=True)

    return Response({
        'range': dr['range'],
        'total_billed': float(total_billed),
        'total_collected': float(total_collected),
        'outstanding': float(outstanding),
        'monthly_revenue': float(monthly_revenue),
        'collection_rate': round(
            float(total_collected) / float(total_billed) * 100, 1
        ) if total_billed else 0,
        'by_status': by_status,
        'by_method': by_method,
        'revenue_trend': revenue_trend,
        'category_totals': {
            'care': float(cat_totals['care'] or 0),
            'equipment': float(cat_totals['equipment'] or 0),
            'supplies': float(cat_totals['supplies'] or 0),
            'medication': float(cat_totals['medication'] or 0),
        },
        'patient_revenue': patient_rows,
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_insurance(request):
    """Insurance claims analytics — status, type, amounts, approval rate."""
    dr = _parse_date_range(request)
    dates = dr['dates']
    start = dr['start'] if dr['start'] else dates[0]

    qs = InsuranceClaim.objects.all()

    # Range-scoped metrics
    range_qs = qs.filter(created_at__date__gte=start)

    by_status = {}
    for choice in InsuranceClaim.Status.choices:
        by_status[choice[0]] = range_qs.filter(status=choice[0]).count()

    by_type = {}
    for choice in InsuranceClaim.ClaimType.choices:
        by_type[choice[0]] = range_qs.filter(claim_type=choice[0]).count()

    total_requested = range_qs.aggregate(t=Sum('amount_requested'))['t'] or 0
    total_approved = range_qs.aggregate(t=Sum('approved_amount'))['t'] or 0

    decided = range_qs.filter(status__in=['approved', 'denied', 'paid', 'partial']).count()
    approved = range_qs.filter(status__in=['approved', 'paid', 'partial']).count()
    approval_rate = round(approved / decided * 100, 1) if decided else 0

    # Pending value (current state)
    pending = qs.filter(status__in=['draft', 'submitted'])
    pending_value = pending.aggregate(t=Sum('amount_requested'))['t'] or 0

    # Trend
    trend = []
    for d in dates:
        c = qs.filter(created_at__date=d).count()
        trend.append({'date': d.isoformat(), 'count': c})

    return Response({
        'range': dr['range'],
        'total': range_qs.count(),
        'by_status': by_status,
        'by_type': by_type,
        'total_requested': float(total_requested),
        'total_approved': float(total_approved or 0),
        'approval_rate': approval_rate,
        'pending_count': pending.count(),
        'pending_value': float(pending_value),
        'trend': trend,
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_equipment(request):
    """Equipment / device analytics — type, status, utilisation, maintenance."""
    qs = Device.objects.exclude(status='retired')

    by_status = {}
    for choice in Device.Status.choices:
        by_status[choice[0]] = qs.filter(status=choice[0]).count()

    by_type = {}
    for choice in Device.DeviceType.choices:
        c = qs.filter(device_type=choice[0]).count()
        if c:
            by_type[choice[0]] = c

    total_units = qs.aggregate(t=Sum('quantity'))['t'] or 0
    available_units = qs.aggregate(t=Sum('quantity_available'))['t'] or 0
    on_hire = total_units - available_units
    utilisation = round(on_hire / total_units * 100, 1) if total_units else 0

    # Low stock / out of stock
    low_stock = []
    out_of_stock = []
    for d in qs:
        if d.stock_status == 'out':
            out_of_stock.append({'name': d.name, 'type': d.device_type})
        elif d.stock_status == 'low':
            low_stock.append({'name': d.name, 'type': d.device_type})

    # Maintenance due
    today = timezone.localdate()
    maintenance_due = qs.filter(
        next_maintenance_due__isnull=False,
        next_maintenance_due__lte=today + timedelta(days=30),
    ).count()
    warranty_expired = qs.filter(
        warranty_expiry__isnull=False, warranty_expiry__lt=today).count()

    # Active assignments
    active_assignments = DeviceAssignment.objects.filter(
        returned_at__isnull=True).count()

    # Total asset value (purchase_cost × quantity per device)
    asset_value = qs.exclude(purchase_cost__isnull=True).annotate(
        total_cost=F('purchase_cost') * F('quantity')
    ).aggregate(t=Sum('total_cost'))['t'] or 0

    return Response({
        'total_devices': qs.count(),
        'total_units': total_units,
        'available_units': available_units,
        'on_hire': on_hire,
        'utilisation': utilisation,
        'by_status': by_status,
        'by_type': by_type,
        'low_stock': low_stock,
        'out_of_stock': out_of_stock,
        'maintenance_due': maintenance_due,
        'warranty_expired': warranty_expired,
        'active_assignments': active_assignments,
        'asset_value': float(asset_value),
    })


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def analytics_equipment_hire(request):
    """Equipment **hire** analytics — per-device rental performance with an
    ABC (Pareto) classification of the fleet by hire revenue.

    Query params:
      range — date-range preset (today, yesterday, 7d, 30d, 90d, 1y, all, custom)
      from / to — ISO dates when range=custom
    """
    from decimal import Decimal, InvalidOperation

    dr = _parse_date_range(request)
    start, end = dr['start'], dr['end']

    assignments = DeviceAssignment.objects.select_related('device')
    if start is not None:
        assignments = assignments.filter(assigned_at__date__gte=start)
    assignments = assignments.filter(assigned_at__date__lte=end)

    device_type_labels = dict(Device.DeviceType.choices)

    # ── Per-device aggregation (Python — fleet is small) ──
    perf = {}
    for a in assignments:
        dev = a.device
        if dev is None:
            continue
        key = dev.id
        row = perf.setdefault(key, {
            'id': dev.id,
            'name': dev.name,
            'device_type': dev.device_type,
            'device_type_label': device_type_labels.get(dev.device_type, dev.device_type),
            'hire_count': 0,
            'active_hires': 0,
            'returned_hires': 0,
            'revenue': Decimal('0'),
            'deposits_held': Decimal('0'),
        })
        row['hire_count'] += 1
        if a.returned_at is None:
            row['active_hires'] += 1
            if a.deposit is not None:
                row['deposits_held'] += Decimal(a.deposit)
        else:
            row['returned_hires'] += 1
        if a.total_charged is not None:
            row['revenue'] += Decimal(a.total_charged)
        else:
            est = a.compute_charge()
            if est is not None:
                try:
                    row['revenue'] += Decimal(est)
                except (InvalidOperation, TypeError):
                    pass

    total_revenue = sum((r['revenue'] for r in perf.values()), Decimal('0')) or Decimal('0')
    total_hires = sum(r['hire_count'] for r in perf.values())
    active_hires = sum(r['active_hires'] for r in perf.values())
    deposits_held = sum((r['deposits_held'] for r in perf.values()), Decimal('0'))

    # ── ABC / Pareto classification (by revenue) ──
    ranked = sorted(perf.values(), key=lambda r: r['revenue'], reverse=True)
    cum = Decimal('0')
    for r in ranked:
        cum += r['revenue']
        pct = float(cum / total_revenue * 100) if total_revenue else 0.0
        r['cumulative_pct'] = round(pct, 2)
        r['share'] = round(float(r['revenue'] / total_revenue * 100), 2) if total_revenue else 0.0
        if pct <= 80:
            r['grade'] = 'A'
        elif pct <= 95:
            r['grade'] = 'B'
        else:
            r['grade'] = 'C'

    abc_groups = {
        'A': {'grade': 'A', 'count': 0, 'revenue': Decimal('0')},
        'B': {'grade': 'B', 'count': 0, 'revenue': Decimal('0')},
        'C': {'grade': 'C', 'count': 0, 'revenue': Decimal('0')},
    }
    for r in ranked:
        g = abc_groups[r['grade']]
        g['count'] += 1
        g['revenue'] += r['revenue']
    abc_summary = []
    for grade in ('A', 'B', 'C'):
        g = abc_groups[grade]
        abc_summary.append({
            'grade': grade,
            'count': g['count'],
            'revenue': float(g['revenue']),
            'pct': round(float(g['revenue'] / total_revenue * 100), 1) if total_revenue else 0.0,
        })

    # ── By device type ──
    by_type = {}
    for r in ranked:
        t = r['device_type']
        slot = by_type.setdefault(t, {
            'label': r['device_type_label'],
            'devices': 0, 'hires': 0, 'revenue': Decimal('0'),
        })
        slot['devices'] += 1
        slot['hires'] += r['hire_count']
        slot['revenue'] += r['revenue']
    by_type_list = [
        {
            'type': t, 'label': v['label'], 'devices': v['devices'],
            'hires': v['hires'], 'revenue': float(v['revenue']),
        }
        for t, v in sorted(by_type.items(), key=lambda kv: kv[1]['revenue'], reverse=True)
    ]

    # ── Hire trend (daily counts in the selected window) ──
    dates = dr['dates']
    day_counts = {d: 0 for d in dates}
    for a in assignments:
        d = a.assigned_at.date()
        if d in day_counts:
            day_counts[d] += 1
    hire_trend = {
        'labels': [d.isoformat() for d in dates],
        'values': [day_counts[d] for d in dates],
    }

    # ── Top performing (serialize decimals to floats) ──
    top_equipment = [
        {
            'id': r['id'],
            'name': r['name'],
            'device_type': r['device_type'],
            'device_type_label': r['device_type_label'],
            'hire_count': r['hire_count'],
            'active_hires': r['active_hires'],
            'returned_hires': r['returned_hires'],
            'revenue': float(r['revenue']),
            'deposits_held': float(r['deposits_held']),
            'share': r['share'],
            'cumulative_pct': r['cumulative_pct'],
            'grade': r['grade'],
        }
        for r in ranked
    ]

    rentable_devices = Device.objects.filter(is_rentable=True).count()

    return Response({
        'range': dr['range'],
        'total_hire_revenue': float(total_revenue),
        'total_hires': total_hires,
        'active_hires': active_hires,
        'deposits_held': float(deposits_held),
        'avg_revenue_per_hire': round(float(total_revenue) / total_hires, 2) if total_hires else 0.0,
        'rentable_devices': rentable_devices,
        'devices_with_hires': len(perf),
        'abc_summary': abc_summary,
        'top_equipment': top_equipment,
        'by_type': by_type_list,
        'hire_trend': hire_trend,
    })


# ─────────────────────────────────────────────────────────
# Tenant mailbox (IMAP + SMTP) — homecare tenants only
# ─────────────────────────────────────────────────────────
from . import mail as _mail
from .models import MailAccount
from .serializers import MailAccountSerializer


def _is_homecare_tenant(request) -> bool:
    tenant = getattr(request, 'tenant', None) or getattr(connection, 'tenant', None)
    if tenant and getattr(tenant, 'type', None) == 'homecare':
        return True
    # Fallback: user's own tenant
    utenant = getattr(getattr(request, 'user', None), 'tenant', None)
    return bool(utenant and getattr(utenant, 'type', None) == 'homecare')


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def mail_folders(request):
    if not _is_homecare_tenant(request):
        return Response({'detail': 'Mailbox available to homecare tenants only.'},
                        status=status.HTTP_403_FORBIDDEN)
    if not _mail.is_configured():
        return Response({'detail': 'Homecare mailbox is not configured.'},
                        status=status.HTTP_503_SERVICE_UNAVAILABLE)
    try:
        return Response({'folders': _mail.list_folders()})
    except Exception as exc:
        return Response({'detail': f'Mail server error: {exc}'},
                        status=status.HTTP_502_BAD_GATEWAY)


@api_view(['GET'])
@permission_classes([IsHomecareStaff])
def mail_messages(request):
    if not _is_homecare_tenant(request):
        return Response({'detail': 'Mailbox available to homecare tenants only.'},
                        status=status.HTTP_403_FORBIDDEN)
    if not _mail.is_configured():
        return Response({'detail': 'Homecare mailbox is not configured.'},
                        status=status.HTTP_503_SERVICE_UNAVAILABLE)
    folder = request.query_params.get('folder') or 'INBOX'
    try:
        limit = int(request.query_params.get('limit') or 50)
    except ValueError:
        limit = 50
    search = request.query_params.get('search')
    try:
        return Response(_mail.list_messages(folder=folder, limit=limit, search=search))
    except Exception as exc:
        return Response({'detail': f'Mail server error: {exc}'},
                        status=status.HTTP_502_BAD_GATEWAY)


@api_view(['GET', 'DELETE'])
@permission_classes([IsHomecareStaff])
def mail_message_detail(request, uid):
    if not _is_homecare_tenant(request):
        return Response({'detail': 'Mailbox available to homecare tenants only.'},
                        status=status.HTTP_403_FORBIDDEN)
    if not _mail.is_configured():
        return Response({'detail': 'Homecare mailbox is not configured.'},
                        status=status.HTTP_503_SERVICE_UNAVAILABLE)
    folder = request.query_params.get('folder') or 'INBOX'
    try:
        if request.method == 'DELETE':
            ok = _mail.delete_message(uid, folder=folder)
            return Response({'ok': ok})
        msg = _mail.fetch_message(uid, folder=folder)
        if not msg:
            return Response({'detail': 'Message not found.'},
                            status=status.HTTP_404_NOT_FOUND)
        # Auto-mark as seen on read
        try:
            _mail.mark_seen(uid, folder=folder, seen=True)
        except Exception:
            pass
        return Response(msg)
    except Exception as exc:
        return Response({'detail': f'Mail server error: {exc}'},
                        status=status.HTTP_502_BAD_GATEWAY)


@api_view(['POST'])
@permission_classes([IsHomecareStaff])
def mail_mark_seen(request, uid):
    if not _is_homecare_tenant(request):
        return Response({'detail': 'Mailbox available to homecare tenants only.'},
                        status=status.HTTP_403_FORBIDDEN)
    folder = request.data.get('folder') or 'INBOX'
    seen = bool(request.data.get('seen', True))
    try:
        ok = _mail.mark_seen(uid, folder=folder, seen=seen)
        return Response({'ok': ok})
    except Exception as exc:
        return Response({'detail': f'Mail server error: {exc}'},
                        status=status.HTTP_502_BAD_GATEWAY)


@api_view(['POST'])
@permission_classes([IsHomecareStaff])
def mail_send(request):
    if not _is_homecare_tenant(request):
        return Response({'detail': 'Mailbox available to homecare tenants only.'},
                        status=status.HTTP_403_FORBIDDEN)
    if not _mail.is_configured():
        return Response({'detail': 'Homecare mailbox is not configured.'},
                        status=status.HTTP_503_SERVICE_UNAVAILABLE)
    payload = request.data or {}
    try:
        result = _mail.send_message(
            to=payload.get('to'),
            cc=payload.get('cc'),
            bcc=payload.get('bcc'),
            subject=payload.get('subject') or '',
            body_text=payload.get('body_text') or '',
            body_html=payload.get('body_html') or '',
            attachments=payload.get('attachments') or [],
            reply_to=payload.get('reply_to'),
            in_reply_to=payload.get('in_reply_to'),
        )
        return Response(result)
    except ValueError as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as exc:
        return Response({'detail': f'Mail server error: {exc}'},
                        status=status.HTTP_502_BAD_GATEWAY)


# ─────────────────────────────────────────────────────────
# Mail account configuration (admin only)
# ─────────────────────────────────────────────────────────
@api_view(['GET', 'PUT', 'POST', 'DELETE'])
@permission_classes([IsHomecareAdmin])
def mail_account_settings(request):
    """Singleton-per-tenant mail account override.

    GET    -> current account (or {} if not configured) merged with effective
              defaults from settings so the UI can prefill.
    PUT/POST -> create or update; password is optional on update (kept if blank).
    DELETE -> remove the override; falls back to global defaults.
    """
    if not _is_homecare_tenant(request):
        return Response({'detail': 'Mailbox available to homecare tenants only.'},
                        status=status.HTTP_403_FORBIDDEN)

    acc = MailAccount.objects.first()

    if request.method == 'GET':
        from django.conf import settings as _dj_settings
        defaults = getattr(_dj_settings, 'HOMECARE_MAIL', {}) or {}
        effective = _mail._cfg()
        data = MailAccountSerializer(acc).data if acc else {
            'id': None, 'display_name': '', 'email': defaults.get('USERNAME', ''),
            'imap_host': defaults.get('IMAP_HOST', ''),
            'imap_port': defaults.get('IMAP_PORT', 993),
            'imap_use_ssl': bool(defaults.get('IMAP_SSL', True)),
            'smtp_host': defaults.get('SMTP_HOST', ''),
            'smtp_port': defaults.get('SMTP_PORT', 465),
            'smtp_use_ssl': bool(defaults.get('SMTP_SSL', True)),
            'username': defaults.get('USERNAME', ''),
            'has_password': bool(defaults.get('PASSWORD')),
            'is_active': False,
            'last_verified_at': None, 'last_verified_ok': False, 'last_error': '',
        }
        data['effective_from_name'] = effective.get('FROM_NAME', '')
        data['effective_from_email'] = effective.get('FROM_EMAIL', '')
        data['using_override'] = bool(acc and acc.is_active)
        return Response(data)

    if request.method == 'DELETE':
        if acc:
            acc.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    # PUT / POST -> upsert
    serializer = MailAccountSerializer(acc, data=request.data, partial=bool(acc))
    serializer.is_valid(raise_exception=True)
    instance = serializer.save()
    return Response(MailAccountSerializer(instance).data)


@api_view(['POST'])
@permission_classes([IsHomecareAdmin])
def mail_account_test(request):
    """Test IMAP + SMTP credentials. Uses request body if provided,
    otherwise falls back to the saved override / global defaults."""
    if not _is_homecare_tenant(request):
        return Response({'detail': 'Mailbox available to homecare tenants only.'},
                        status=status.HTTP_403_FORBIDDEN)

    payload = request.data or {}
    if payload.get('username') and payload.get('password'):
        cfg = {
            'imap_host': payload.get('imap_host'),
            'imap_port': payload.get('imap_port') or 993,
            'imap_use_ssl': bool(payload.get('imap_use_ssl', True)),
            'smtp_host': payload.get('smtp_host'),
            'smtp_port': payload.get('smtp_port') or 465,
            'smtp_use_ssl': bool(payload.get('smtp_use_ssl', True)),
            'username': payload.get('username'),
            'password': payload.get('password'),
        }
    else:
        eff = _mail._cfg()
        cfg = {
            'imap_host': eff.get('IMAP_HOST'),
            'imap_port': eff.get('IMAP_PORT', 993),
            'imap_use_ssl': eff.get('IMAP_SSL', True),
            'smtp_host': eff.get('SMTP_HOST'),
            'smtp_port': eff.get('SMTP_PORT', 465),
            'smtp_use_ssl': eff.get('SMTP_SSL', True),
            'username': eff.get('USERNAME'),
            'password': eff.get('PASSWORD'),
        }
    if not (cfg['username'] and cfg['password'] and cfg['imap_host'] and cfg['smtp_host']):
        return Response({'ok': False, 'error': 'Incomplete credentials.'},
                        status=status.HTTP_400_BAD_REQUEST)

    result = _mail.verify_credentials(cfg)

    # Persist verification result on the saved account if we tested its config
    acc = MailAccount.objects.first()
    if acc and (not payload.get('username') or payload.get('username') == acc.username):
        acc.last_verified_at = timezone.now()
        acc.last_verified_ok = bool(result.get('ok'))
        acc.last_error = result.get('error') or ''
        acc.save(update_fields=['last_verified_at', 'last_verified_ok', 'last_error'])

    return Response(result)


# ─────────────────────────────────────────────────────────
# Server-Sent Events (SSE) for realtime alerts
# ─────────────────────────────────────────────────────────
def event_stream(request):
    """Long-polling SSE endpoint that yields new Notification rows for the user."""
    user = request.user
    # EventSource cannot set Authorization header; allow ?token=<jwt> fallback.
    if not getattr(user, 'is_authenticated', False):
        token = request.GET.get('token')
        if token:
            try:
                from rest_framework_simplejwt.authentication import JWTAuthentication
                jwt_auth = JWTAuthentication()
                validated = jwt_auth.get_validated_token(token)
                user = jwt_auth.get_user(validated)
            except Exception:
                user = None
        if not user or not getattr(user, 'is_authenticated', False):
            return StreamingHttpResponse(status=401)

    schema = connection.schema_name
    # Notifications live in tenant schemas only. EventSource requests can
    # reach us via the API host (public schema) because they cannot send
    # custom headers; fall back to the authenticated user's tenant schema.
    if not schema or schema == 'public':
        user_tenant = getattr(user, 'tenant', None)
        schema = getattr(user_tenant, 'schema_name', None)
        if not schema or schema == 'public':
            return StreamingHttpResponse(status=400)

    def gen():
        # Send the last id we've sent so client can dedupe
        last_id = int(request.GET.get('since') or 0)
        idle = 0
        # Stream up to 5 minutes per connection; client should reconnect
        deadline = time.time() + 300
        while time.time() < deadline:
            from django_tenants.utils import schema_context
            with schema_context(schema):
                qs = Notification.objects.filter(
                    recipient=user, id__gt=last_id,
                ).order_by('id')[:25]
                rows = list(qs)
            if rows:
                idle = 0
                for n in rows:
                    payload = {
                        'id': n.id, 'type': n.type, 'title': n.title,
                        'message': n.message, 'data': n.data,
                        'created_at': n.created_at.isoformat(),
                    }
                    yield f'data: {json.dumps(payload)}\n\n'
                    last_id = max(last_id, n.id)
            else:
                idle += 1
                if idle >= 6:
                    yield ': keepalive\n\n'
                    idle = 0
            time.sleep(2)

    resp = StreamingHttpResponse(gen(), content_type='text/event-stream')
    resp['Cache-Control'] = 'no-cache'
    resp['X-Accel-Buffering'] = 'no'
    return resp


# ─────────────────────────────────────────────────────────
# Tenant-scoped clinical catalog (Diagnoses & Allergies)
# ─────────────────────────────────────────────────────────
class _CatalogPermission(permissions.BasePermission):
    """Read = any homecare staff; Write = homecare admin only."""

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.method in permissions.SAFE_METHODS:
            return IsHomecareStaff().has_permission(request, view)
        return IsHomecareAdmin().has_permission(request, view)


class HomecareDiagnosisViewSet(viewsets.ModelViewSet):
    queryset = HomecareDiagnosis.objects.all()
    serializer_class = HomecareDiagnosisSerializer
    permission_classes = [_CatalogPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'source', 'is_active']
    search_fields = ['name', 'icd_code', 'description', 'category']
    ordering_fields = ['name', 'category', 'icd_code', 'created_at']

    def perform_create(self, serializer):
        serializer.save(source=HomecareDiagnosis.Source.CUSTOM)

    @action(detail=False, methods=['get'])
    def search(self, request):
        q = (request.query_params.get('q') or '').strip()
        qs = self.get_queryset().filter(is_active=True)
        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(icd_code__icontains=q))
        qs = qs[:30]
        return Response(self.get_serializer(qs, many=True).data)

    @action(detail=False, methods=['post'], url_path='seed')
    def seed(self, request):
        """Copy all global ChronicCondition rows into this tenant's catalog.
        Existing names are skipped. Restricted to homecare admin."""
        if not IsHomecareAdmin().has_permission(request, self):
            return Response({'detail': 'Admin only.'}, status=403)
        from django.core.management import call_command
        from io import StringIO
        out = StringIO()
        call_command('seed_homecare_catalog', '--diagnoses', stdout=out)
        return Response({'detail': out.getvalue().strip() or 'Seeded.',
                         'total': HomecareDiagnosis.objects.count()})


class HomecareAllergyViewSet(viewsets.ModelViewSet):
    queryset = HomecareAllergy.objects.all()
    serializer_class = HomecareAllergySerializer
    permission_classes = [_CatalogPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'source', 'is_active']
    search_fields = ['name', 'description', 'common_symptoms', 'category']
    ordering_fields = ['name', 'category', 'created_at']

    def perform_create(self, serializer):
        serializer.save(source=HomecareAllergy.Source.CUSTOM)

    @action(detail=False, methods=['get'])
    def search(self, request):
        q = (request.query_params.get('q') or '').strip()
        qs = self.get_queryset().filter(is_active=True)
        if q:
            qs = qs.filter(Q(name__icontains=q))
        qs = qs[:30]
        return Response(self.get_serializer(qs, many=True).data)

    @action(detail=False, methods=['post'], url_path='seed')
    def seed(self, request):
        if not IsHomecareAdmin().has_permission(request, self):
            return Response({'detail': 'Admin only.'}, status=403)
        from django.core.management import call_command
        from io import StringIO
        out = StringIO()
        call_command('seed_homecare_catalog', '--allergies', stdout=out)
        return Response({'detail': out.getvalue().strip() or 'Seeded.',
                         'total': HomecareAllergy.objects.count()})


# ─────────────────────────────────────────────────────────
# Equipment / Devices
# ─────────────────────────────────────────────────────────
class DeviceViewSet(viewsets.ModelViewSet):
    queryset = Device.objects.select_related('assigned_to__user').all()
    serializer_class = DeviceSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['device_type', 'status', 'assigned_to', 'manufacturer']
    search_fields = ['name', 'serial_number', 'asset_tag', 'manufacturer',
                     'model_number', 'qr_code']
    ordering_fields = ['name', 'created_at', 'next_maintenance_due', 'warranty_expiry']

    @action(detail=False, methods=['get'])
    def summary(self, request):
        today = timezone.localdate()
        soon = today + timedelta(days=30)
        qs = self.get_queryset()
        breakdown = qs.aggregate(
            total=Count('id'),
            available=Count('id', filter=Q(status=Device.Status.AVAILABLE)),
            assigned=Count('id', filter=Q(status=Device.Status.ASSIGNED)),
            maintenance=Count('id', filter=Q(status=Device.Status.MAINTENANCE)),
            repair=Count('id', filter=Q(status=Device.Status.REPAIR)),
            retired=Count('id', filter=Q(status=Device.Status.RETIRED)),
        )
        breakdown['maintenance_due_soon'] = qs.filter(
            next_maintenance_due__isnull=False,
            next_maintenance_due__lte=soon,
        ).count()
        breakdown['warranty_expiring_soon'] = qs.filter(
            warranty_expiry__isnull=False,
            warranty_expiry__lte=soon,
            warranty_expiry__gte=today,
        ).count()
        breakdown['by_type'] = list(
            qs.values('device_type').annotate(count=Count('id')).order_by('-count')
        )
        breakdown['rentable'] = qs.filter(is_rentable=True).count()
        units = qs.aggregate(
            total_units=Sum('quantity'),
            available_units=Sum('quantity_available'),
        )
        total_units = units['total_units'] or 0
        available_units = units['available_units'] or 0
        breakdown['total_units'] = total_units
        breakdown['available_units'] = available_units
        breakdown['units_on_hire'] = max(total_units - available_units, 0)
        breakdown['low_stock'] = qs.filter(
            quantity_available__gt=0,
            quantity_available__lte=F('low_stock_threshold'),
        ).count()
        breakdown['out_of_stock'] = qs.filter(quantity_available__lte=0).count()
        hire_agg = DeviceAssignment.objects.aggregate(
            active_hires=Count('id', filter=Q(returned_at__isnull=True)),
            realized_revenue=Sum('total_charged'),
            deposits_held=Sum('deposit', filter=Q(returned_at__isnull=True)),
        )
        breakdown['active_hires'] = hire_agg['active_hires'] or 0
        breakdown['realized_revenue'] = str(hire_agg['realized_revenue'] or 0)
        breakdown['deposits_held'] = str(hire_agg['deposits_held'] or 0)
        return Response(breakdown)

    @action(detail=True, methods=['get'])
    def history(self, request, pk=None):
        device = self.get_object()
        assignments = device.assignments.select_related('patient__user', 'assigned_by').all()
        maintenance = device.maintenance_events.all()
        return Response({
            'assignments': DeviceAssignmentSerializer(assignments, many=True).data,
            'maintenance': DeviceMaintenanceSerializer(maintenance, many=True).data,
        })

    @action(detail=True, methods=['post'])
    def assign(self, request, pk=None):
        device = self.get_object()
        hire_to_type = request.data.get('hire_to_type') or DeviceAssignment.HireTo.PATIENT
        facility_name = (request.data.get('facility_name') or '').strip()
        patient = None
        if hire_to_type == DeviceAssignment.HireTo.FACILITY:
            if not facility_name:
                return Response({'facility_name': ['This field is required.']}, status=400)
        else:
            patient_id = request.data.get('patient')
            if not patient_id:
                return Response({'patient': ['This field is required.']}, status=400)
            try:
                patient = HomecarePatient.objects.get(pk=patient_id)
            except HomecarePatient.DoesNotExist:
                return Response({'patient': ['Patient not found.']}, status=404)
        if device.status in (Device.Status.MAINTENANCE, Device.Status.REPAIR,
                             Device.Status.RETIRED, Device.Status.LOST):
            return Response({'detail': f'Device is currently {device.get_status_display()}.'},
                            status=400)
        if (device.quantity_available or 0) <= 0:
            return Response({'detail': 'No units available for hire.'}, status=400)
        hire_period = request.data.get('hire_period') or device.default_hire_period
        hire_rate = request.data.get('hire_rate')
        if hire_rate in (None, ''):
            hire_rate = device.rate_for(hire_period)
        deposit = request.data.get('deposit')
        if deposit in (None, ''):
            deposit = device.deposit
        DeviceAssignment.objects.create(
            device=device,
            hire_to_type=hire_to_type,
            patient=patient,
            facility_name=facility_name,
            assigned_by=request.user if request.user.is_authenticated else None,
            assigned_at=request.data.get('assigned_at') or timezone.now(),
            expected_return_at=request.data.get('expected_return_at') or None,
            hire_period=hire_period or '',
            hire_rate=hire_rate or None,
            deposit=deposit or None,
            notes=request.data.get('notes', ''),
        )
        # Deduct one unit from available stock.
        device.quantity_available = max((device.quantity_available or 0) - 1, 0)
        if device.quantity_available == 0:
            device.status = Device.Status.ASSIGNED
        if patient is not None:
            device.assigned_to = patient
        device.save(update_fields=['quantity_available', 'status',
                                   'assigned_to', 'updated_at'])
        return Response(self.get_serializer(device).data)

    @action(detail=True, methods=['post'])
    def return_device(self, request, pk=None):
        device = self.get_object()
        active = device.assignments.filter(returned_at__isnull=True)
        assignment_id = request.data.get('assignment')
        if assignment_id:
            last = active.filter(pk=assignment_id).first()
        else:
            last = active.order_by('-assigned_at').first()
        if last:
            last.returned_at = timezone.now()
            last.return_condition = request.data.get('condition', '')
            # Snapshot the final hire charge (allow override from client).
            override = request.data.get('total_charged')
            if override not in (None, ''):
                last.total_charged = override
            else:
                last.total_charged = last.compute_charge(until=last.returned_at)
            if request.data.get('notes'):
                last.notes = (last.notes + '\n' if last.notes else '') + request.data['notes']
            last.save(update_fields=['returned_at', 'return_condition',
                                     'total_charged', 'notes'])
            # Restore one unit of stock.
            device.quantity_available = min((device.quantity_available or 0) + 1,
                                            device.quantity or 1)
        new_status = request.data.get('status')
        if new_status and new_status in dict(Device.Status.choices):
            device.status = new_status
        elif device.status == Device.Status.ASSIGNED and device.quantity_available > 0:
            device.status = Device.Status.AVAILABLE
        if not device.assignments.filter(returned_at__isnull=True,
                                         hire_to_type=DeviceAssignment.HireTo.PATIENT).exists():
            device.assigned_to = None
        device.save(update_fields=['status', 'quantity_available',
                                   'assigned_to', 'updated_at'])
        return Response(self.get_serializer(device).data)

    @action(detail=True, methods=['post'])
    def schedule_maintenance(self, request, pk=None):
        device = self.get_object()
        scheduled_at = request.data.get('scheduled_at')
        if not scheduled_at:
            return Response({'scheduled_at': ['Required.']}, status=400)
        m = DeviceMaintenance.objects.create(
            device=device,
            kind=request.data.get('kind') or DeviceMaintenance.Kind.ROUTINE,
            scheduled_at=scheduled_at,
            notes=request.data.get('notes', ''),
        )
        return Response(DeviceMaintenanceSerializer(m).data, status=201)


class DeviceAssignmentViewSet(viewsets.ModelViewSet):
    queryset = DeviceAssignment.objects.select_related(
        'device', 'patient__user', 'assigned_by'
    ).all()
    serializer_class = DeviceAssignmentSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['device', 'patient']
    search_fields = ['device__name', 'device__serial_number', 'device__asset_tag',
                     'facility_name', 'patient__user__full_name', 'assigned_by__full_name']
    ordering_fields = ['assigned_at', 'returned_at']
    ordering = ['-assigned_at']

    def get_queryset(self):
        qs = super().get_queryset()
        req = self.request
        # Optional date-range filtering on assigned_at (shares the analytics
        # range presets: today, yesterday, 7d, 30d, 90d, 1y, all, custom).
        if req.query_params.get('range'):
            dr = _parse_date_range(req)
            if dr['start'] is not None:
                qs = qs.filter(assigned_at__date__gte=dr['start'])
            qs = qs.filter(assigned_at__date__lte=dr['end'])
        status = req.query_params.get('status')
        if status == 'active':
            qs = qs.filter(returned_at__isnull=True)
        elif status == 'returned':
            qs = qs.filter(returned_at__isnull=False)
        return qs

    def perform_create(self, serializer):
        serializer.save(
            assigned_by=self.request.user if self.request.user.is_authenticated else None
        )


class DeviceMaintenanceViewSet(viewsets.ModelViewSet):
    queryset = DeviceMaintenance.objects.select_related('device', 'performed_by_user').all()
    serializer_class = DeviceMaintenanceSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['device', 'status', 'kind']
    ordering_fields = ['scheduled_at', 'performed_at']

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        m = self.get_object()
        m.status = DeviceMaintenance.Status.COMPLETED
        m.performed_at = timezone.now()
        m.performed_by_name = request.data.get('performed_by_name', m.performed_by_name)
        if request.user.is_authenticated:
            m.performed_by_user = request.user
        if 'cost' in request.data:
            m.cost = request.data['cost'] or None
        if 'notes' in request.data:
            m.notes = request.data['notes']
        if 'next_due_at' in request.data:
            m.next_due_at = request.data['next_due_at'] or None
        m.save()
        # Update device side
        device = m.device
        device.last_maintenance_at = m.performed_at
        if m.next_due_at:
            device.next_maintenance_due = m.next_due_at
        if device.status == Device.Status.MAINTENANCE:
            device.status = Device.Status.AVAILABLE
        device.save(update_fields=['last_maintenance_at', 'next_maintenance_due',
                                   'status', 'updated_at'])
        return Response(self.get_serializer(m).data)


class DrainLineViewSet(viewsets.ModelViewSet):
    """Patient Drains & Lines register — invasive lines/drains tracked with
    dwell-time countdowns, separate from the billable equipment-hire
    register (Device / DeviceAssignment)."""
    queryset = DrainLine.objects.select_related('patient__user', 'created_by').all()
    serializer_class = DrainLineSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'line_type']
    ordering_fields = ['insert_date', 'created_at']

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                qs = qs.filter(
                    Q(patient__assigned_caregiver=cg)
                    | Q(patient__additional_caregivers=cg)
                ).distinct()
            else:
                return qs.none()
        active_param = self.request.query_params.get('active')
        if active_param == 'true':
            qs = qs.filter(removed_at__isnull=True)
        elif active_param == 'false':
            qs = qs.filter(removed_at__isnull=False)
        return qs

    def perform_create(self, serializer):
        serializer.save(
            created_by=self.request.user if self.request.user.is_authenticated else None
        )

    @action(detail=True, methods=['post'])
    def remove(self, request, pk=None):
        """Mark this drain/line as removed — preserves history for audit."""
        line = self.get_object()
        line.removed_at = timezone.now()
        line.removal_reason = request.data.get('removal_reason', '')
        line.save(update_fields=['removed_at', 'removal_reason', 'updated_at'])
        return Response(self.get_serializer(line).data)


# ─────────────────────────────────────────────────────────
# Patient care management & billing
# ─────────────────────────────────────────────────────────
class CarePlanViewSet(viewsets.ModelViewSet):
    queryset = CarePlan.objects.select_related('patient__user').all()
    serializer_class = CarePlanSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'is_active', 'plan_type']
    ordering_fields = ['start_date', 'created_at']

    def perform_create(self, serializer):
        plan = serializer.save(
            created_by_user_id=getattr(self.request.user, 'id', None),
            created_by_name=getattr(self.request.user, 'full_name', '') or '',
        )
        # A patient carries a single active plan — retire any previous ones.
        if plan.is_active:
            CarePlan.objects.filter(patient=plan.patient, is_active=True)\
                .exclude(pk=plan.pk).update(is_active=False)

    def perform_update(self, serializer):
        plan = serializer.save()
        if plan.is_active:
            CarePlan.objects.filter(patient=plan.patient, is_active=True)\
                .exclude(pk=plan.pk).update(is_active=False)

    @action(detail=True, methods=['post'], url_path='toggle-auto-bill')
    def toggle_auto_bill(self, request, pk=None):
        """Flip (or explicitly set) auto_bill for a single care plan.

        Body (optional): {"auto_bill": true|false}. If omitted the current
        value is inverted."""
        plan = self.get_object()
        desired = request.data.get('auto_bill', None)
        if desired is None:
            plan.auto_bill = not plan.auto_bill
        else:
            plan.auto_bill = bool(desired)
        plan.save(update_fields=['auto_bill', 'updated_at'])
        return Response(self.get_serializer(plan).data)


class MedicalSupplyViewSet(viewsets.ModelViewSet):
    queryset = MedicalSupply.objects.select_related('patient__user').all()
    serializer_class = MedicalSupplySerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'category', 'is_active', 'billable']
    search_fields = ['name', 'notes']
    ordering_fields = ['supplied_at', 'replace_due', 'name']


class PatientBillViewSet(viewsets.ModelViewSet):
    queryset = PatientBill.objects.select_related('patient__user')\
        .prefetch_related('payments').all()
    serializer_class = PatientBillSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'status']
    ordering_fields = ['created_at', 'as_of', 'total']

    def create(self, request, *args, **kwargs):
        return Response(
            {'detail': 'Generate bills via /homecare/patients/{id}/generate-bill/.'},
            status=405)

    @action(detail=True, methods=['post'])
    def void(self, request, pk=None):
        bill = self.get_object()
        bill.status = PatientBill.Status.VOID
        bill.save(update_fields=['status', 'updated_at'])
        return Response(self.get_serializer(bill).data)

    @action(detail=True, methods=['post'], url_path='record-payment')
    def record_payment(self, request, pk=None):
        bill = self.get_object()
        amount = request.data.get('amount')
        if amount in (None, ''):
            return Response({'amount': ['Required.']}, status=400)
        PatientPayment.objects.create(
            patient=bill.patient, bill=bill, amount=amount,
            currency=bill.currency,
            method=request.data.get('method') or PatientPayment.Method.CASH,
            reference=request.data.get('reference', ''),
            paid_at=request.data.get('paid_at') or timezone.now(),
            received_by_user_id=getattr(request.user, 'id', None),
            received_by_name=getattr(request.user, 'full_name', '') or '',
            notes=request.data.get('notes', ''),
        )
        bill.recalc_status()
        bill.save(update_fields=['amount_paid', 'balance', 'status', 'updated_at'])
        return Response(self.get_serializer(bill).data, status=201)


class PatientPaymentViewSet(viewsets.ModelViewSet):
    queryset = PatientPayment.objects.select_related('patient__user', 'bill').all()
    serializer_class = PatientPaymentSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['patient', 'method', 'bill']
    ordering_fields = ['paid_at', 'amount']

    def _sync_bill(self, bill):
        if bill:
            bill.recalc_status()
            bill.save(update_fields=['amount_paid', 'balance', 'status', 'updated_at'])

    def _auto_pick_bill(self, patient):
        # Oldest still-open bill for this patient.
        return (
            PatientBill.objects
            .filter(patient=patient)
            .exclude(status__in=[PatientBill.Status.VOID, PatientBill.Status.PAID])
            .order_by('created_at')
            .first()
        )

    def perform_create(self, serializer):
        bill = serializer.validated_data.get('bill')
        if not bill:
            patient = serializer.validated_data.get('patient')
            if patient is not None:
                bill = self._auto_pick_bill(patient)
        pay = serializer.save(
            bill=bill,
            received_by_user_id=getattr(self.request.user, 'id', None),
            received_by_name=getattr(self.request.user, 'full_name', '') or '',
        )
        self._sync_bill(pay.bill)

    def perform_update(self, serializer):
        previous_bill = serializer.instance.bill if serializer.instance else None
        pay = serializer.save()
        self._sync_bill(pay.bill)
        if previous_bill and previous_bill != pay.bill:
            self._sync_bill(previous_bill)

    def perform_destroy(self, instance):
        bill = instance.bill
        instance.delete()
        self._sync_bill(bill)


# ─────────────────────────────────────────────────────────
# Billing settings (per-patient cadence)
# ─────────────────────────────────────────────────────────
@api_view(['GET', 'PUT'])
@permission_classes([IsHomecareAdmin])
def billing_settings(request):
    """Retrieve or update a single patient's billing cadence settings.

    GET  /homecare/billing-settings/?patient=<id>
    PUT  /homecare/billing-settings/   body: {patient, billing_type, auto_generate}

    A ``BillingSettings`` row is created on demand for the patient (one per
    patient) via ``BillingSettings.get_or_create_for``.
    """
    patient_id = request.query_params.get('patient') if request.method == 'GET' \
        else request.data.get('patient')
    if not patient_id:
        return Response(
            {'detail': 'A "patient" id is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        patient = HomecarePatient.objects.get(pk=patient_id)
    except HomecarePatient.DoesNotExist:
        return Response(
            {'detail': 'Patient not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    obj = BillingSettings.get_or_create_for(patient)

    if request.method == 'GET':
        return Response(BillingSettingsSerializer(obj).data)

    serializer = BillingSettingsSerializer(obj, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save(
        updated_by_user_id=getattr(request.user, 'id', None),
        updated_by_name=getattr(request.user, 'full_name', '') or '',
    )
    return Response(BillingSettingsSerializer(obj).data)


# ─────────────────────────────────────────────────────────
# Audit log (read-only)
# ─────────────────────────────────────────────────────────
class AuditEventViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AuditEvent.objects.all()
    serializer_class = AuditEventSerializer
    permission_classes = [IsHomecareAdmin]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['action', 'object_type', 'actor_user_id', 'method']
    search_fields = ['actor_email', 'object_repr', 'path', 'object_id']
    ordering_fields = ['created_at']


# ─────────────────────────────────────────────────────────
# Drug interactions catalog (tenant-curated)
# ─────────────────────────────────────────────────────────
class DrugInteractionViewSet(viewsets.ModelViewSet):
    queryset = DrugInteraction.objects.all()
    serializer_class = DrugInteractionSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['severity', 'is_active']
    search_fields = ['drug_a', 'drug_b', 'summary']
    ordering_fields = ['drug_a', 'drug_b', 'severity', 'updated_at']


# ─────────────────────────────────────────────────────────
# Prescription safety alerts (read-only listing)
# ─────────────────────────────────────────────────────────
class PrescriptionSafetyAlertViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = PrescriptionSafetyAlert.objects.select_related('overridden_by').all()
    serializer_class = PrescriptionSafetyAlertSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['prescription', 'kind', 'severity', 'overridden']
    ordering_fields = ['created_at', 'severity']


# ──────────────────────────────────────────────────
# Care pathways (protocol bundles)
# ──────────────────────────────────────────────────
from .serializers import (  # noqa: E402  (placed late to avoid early-import cycles)
    CarePathwaySerializer, CarePathwayEnrollmentSerializer,
)


class CarePathwayViewSet(viewsets.ModelViewSet):
    queryset = CarePathway.objects.all()
    serializer_class = CarePathwaySerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active']
    search_fields = ['name', 'code', 'condition_label']
    ordering_fields = ['name', 'updated_at']


class CarePathwayEnrollmentViewSet(viewsets.ModelViewSet):
    queryset = CarePathwayEnrollment.objects.select_related('pathway', 'patient__user').all()
    serializer_class = CarePathwayEnrollmentSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['pathway', 'patient', 'status']
    ordering_fields = ['started_at', 'completed_at']

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        e = self.get_object()
        e.status = CarePathwayEnrollment.Status.COMPLETED
        e.completed_at = timezone.now()
        e.outcome_notes = request.data.get('outcome_notes', e.outcome_notes)
        e.save(update_fields=['status', 'completed_at', 'outcome_notes'])
        return Response(self.get_serializer(e).data)

    @action(detail=True, methods=['post'])
    def withdraw(self, request, pk=None):
        e = self.get_object()
        e.status = CarePathwayEnrollment.Status.WITHDRAWN
        e.completed_at = timezone.now()
        e.outcome_notes = request.data.get('reason', e.outcome_notes)
        e.save(update_fields=['status', 'completed_at', 'outcome_notes'])
        return Response(self.get_serializer(e).data)


# ─────────────────────────────────────────────────────────────────
#  PATIENT ASSESSMENT MODULE
#  Structured nursing assessment (initial arrival → head-to-toe →
#  validated risk scales → device/disease bundles). The scoring engine
#  in assessments.recalculate_session recomputes every scale total,
#  mirrors queryable columns, derives the overall risk band and
#  generates clinical alerts before each save. Critical alerts open
#  Escalation records (see assessments.create_escalations).
# ─────────────────────────────────────────────────────────────────
#  Patient documents
# ─────────────────────────────────────────────────────────────────
class PatientDocumentViewSet(viewsets.ModelViewSet):
    queryset = PatientDocument.objects.select_related('patient__user', 'uploaded_by').all()
    serializer_class = PatientDocumentSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'access_level', 'patient']
    search_fields = ['name', 'description', 'patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['uploaded_at', 'name', 'expiry_date']

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                return qs.filter(
                    Q(patient__assigned_caregiver=cg)
                    | Q(patient__additional_caregivers=cg)
                ).distinct()
            return qs.none()
        return qs


# ─────────────────────────────────────────────────────────────────
class AssessmentSessionViewSet(viewsets.ModelViewSet):
    """CRUD for patient assessment sessions with auto-scoring + alerts."""

    serializer_class = AssessmentSessionSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'session_type', 'status', 'overall_risk_level', 'caregiver']
    search_fields = ['patient__user__full_name', 'patient__medical_record_number', 'assessed_by_name']
    ordering_fields = ['assessed_at', 'created_at', 'braden_total', 'morse_score', 'overall_risk_level']

    def get_queryset(self):
        qs = AssessmentSession.objects.select_related(
            'patient__user', 'caregiver__user',
        ).prefetch_related('alerts')
        user = self.request.user
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                return qs.filter(
                    Q(patient__assigned_caregiver=cg)
                    | Q(patient__additional_caregivers=cg)
                    | Q(caregiver=cg)
                ).distinct()
            return qs.none()
        return qs

    def _attach_actor(self, session, user):
        """Stamp the audit fields from the authenticated user."""
        session.assessed_by_user_id = user.id
        session.assessed_by_name = (
            getattr(user, 'full_name', None)
            or f'{getattr(user, "first_name", "")} {getattr(user, "last_name", "")}'.strip()
            or user.email
        )
        if not session.caregiver_id:
            session.caregiver = Caregiver.objects.filter(user=user).first()

    def perform_create(self, serializer):
        session = serializer.save()
        self._attach_actor(session, self.request.user)
        session.save()
        # Re-fetch through the queryset so prefetched alerts serialize.
        refreshed = self.get_queryset().get(pk=session.pk)
        serializer.instance = refreshed

    def perform_update(self, serializer):
        session = serializer.save()
        refreshed = self.get_queryset().get(pk=session.pk)
        serializer.instance = refreshed

    @action(detail=True, methods=['post'], url_path='sign-off')
    def sign_off(self, request, pk=None):
        """Clinician sign-off — locks the assessment as 'signed'."""
        session = self.get_object()
        if session.status == AssessmentSession.Status.SIGNED:
            return Response({'detail': 'Assessment is already signed off.'},
                            status=status.HTTP_400_BAD_REQUEST)
        session.status = AssessmentSession.Status.SIGNED
        session.signed_at = timezone.now()
        session.save(update_fields=['status', 'signed_at'])
        return Response(self.get_serializer(session).data)

    @action(detail=True, methods=['post'], url_path='resolve-alerts')
    def resolve_alerts(self, request, pk=None):
        """Mark all open alerts on this session as resolved."""
        session = self.get_object()
        now = timezone.now()
        session.alerts.filter(resolved=False).update(resolved=True, resolved_at=now)
        return Response({'detail': 'Alerts resolved.', 'count': session.alerts.count()})

    @action(detail=False, methods=['get'], url_path='summary')
    def summary(self, request):
        """Aggregate KPIs across this tenant's assessment sessions."""
        qs = self.get_queryset()
        total = qs.count()
        by_risk = {
            'low': qs.filter(overall_risk_level='low').count(),
            'medium': qs.filter(overall_risk_level='medium').count(),
            'high': qs.filter(overall_risk_level='high').count(),
            'critical': qs.filter(overall_risk_level='critical').count(),
        }
        open_alerts = AssessmentAlert.objects.filter(
            session__in=qs, resolved=False,
        ).count()
        signed = qs.filter(status='signed').count()
        last = qs.order_by('-assessed_at').first()
        return Response({
            'total': total,
            'by_risk': by_risk,
            'open_alerts': open_alerts,
            'signed': signed,
            'last_assessed_at': last.assessed_at.isoformat() if last else None,
        })


# ─────────────────────────────────────────────────────────────────
#  Individual assessment scale ViewSets — one per strictly-separate
#  model. Each computes its validated score server-side (reusing the
#  scoring engine's calc_* pure functions), stamps the acting user,
#  then refreshes the parent episode's mirrored columns / overall
#  risk / alerts (and raises Escalations for critical alerts).
# ─────────────────────────────────────────────────────────────────
def _stamp_assessment_actor(instance, user):
    instance.assessed_by_user_id = user.id
    instance.assessed_by_name = (
        getattr(user, 'full_name', None)
        or f'{getattr(user, "first_name", "")} {getattr(user, "last_name", "")}'.strip()
        or user.email
    )


def _finish_episode_refresh(episode, actor_user):
    refresh_episode_mirrors(episode)
    episode.save()
    create_escalations(episode, actor_user=actor_user)


class _BaseAssessmentScaleViewSet(viewsets.ModelViewSet):
    """Shared plumbing for the individual assessment scale endpoints."""

    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'episode']
    ordering_fields = ['assessed_at', 'created_at']

    def get_queryset(self):
        qs = self.model.objects.select_related('patient__user', 'episode')
        user = self.request.user
        if user.role == 'caregiver':
            cg = Caregiver.objects.filter(user=user).first()
            if cg:
                return qs.filter(
                    Q(patient__assigned_caregiver=cg)
                    | Q(patient__additional_caregivers=cg)
                ).distinct()
            return qs.none()
        return qs


class BradenAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = BradenAssessment
    serializer_class = BradenAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        computed = calc_braden({
            'sensory': instance.sensory, 'moisture': instance.moisture,
            'activity': instance.activity, 'mobility': instance.mobility,
            'nutrition': instance.nutrition, 'friction': instance.friction,
        })
        instance.total = computed.get('total')
        instance.risk_level = computed.get('risk_level', '')
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class CapriniAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = CapriniAssessment
    serializer_class = CapriniAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        if instance.factors:
            # Itemized factor checklist provided — derive points from it.
            computed = calc_caprini({'age': instance.age, 'factors': instance.factors})
            instance.factors = computed.get('factors', {})
            instance.points = computed.get('points')
        # Otherwise trust the client-submitted manual total (current UI
        # collects a single Caprini point total, not itemized factors).
        instance.risk_level = caprini_risk_label(instance.points or 0)
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class MorseAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = MorseAssessment
    serializer_class = MorseAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        computed = calc_morse({
            'history_of_falls': instance.history_of_falls, 'secondary_dx': instance.secondary_dx,
            'ambulatory_aid': instance.ambulatory_aid, 'iv_lock': instance.iv_lock,
            'gait': instance.gait, 'mental_status': instance.mental_status,
        })
        instance.score = computed.get('score')
        instance.risk_level = computed.get('risk_level', '')
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class MustAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = MustAssessment
    serializer_class = MustAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        # BMI is reliably derivable from height/weight — always recompute.
        bmi = None
        if instance.height_cm and instance.weight_kg:
            bmi = round(instance.weight_kg / ((instance.height_cm / 100) ** 2), 1)
        instance.bmi = bmi
        instance.bmi_score = 0 if bmi is None else (0 if bmi > 20 else 1 if bmi >= 18.5 else 2)
        instance.acute_score = 2 if instance.acute_no_nutrition else 0
        # loss_score is trusted as submitted — current UI collects a loss
        # category directly rather than a raw weight-loss percentage.
        instance.loss_score = instance.loss_score or 0
        instance.total_score = (instance.bmi_score or 0) + instance.loss_score + instance.acute_score
        instance.risk_level = must_risk_label(instance.total_score)
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class CamAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = CamAssessment
    serializer_class = CamAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        computed = calc_cam({
            'acute_onset': instance.acute_onset, 'inattention': instance.inattention,
            'disorganized_thinking': instance.disorganized_thinking,
            'altered_consciousness': instance.altered_consciousness,
        })
        instance.acute_onset = computed.get('acute_onset', False)
        instance.inattention = computed.get('inattention', False)
        instance.disorganized_thinking = computed.get('disorganized_thinking', False)
        instance.altered_consciousness = computed.get('altered_consciousness', False)
        instance.cam_positive = computed.get('cam_positive')
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class PainAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = PainAssessment
    serializer_class = PainAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        computed = calc_pain({'score': instance.score})
        instance.score = computed.get('score')
        instance.score_category = computed.get('score_category', '')
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class SkinCareAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = SkinCareAssessment
    serializer_class = SkinCareAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        items = [
            ('reposition', 'Reposition patient (q2h)'), ('surface', 'Specialty support surface check'),
            ('moisture', 'Skin moisture management'), ('nutrition', 'Nutritional consult / intake'),
            ('heels', 'Heel protection devices'), ('inspect', 'Full skin inspection'),
        ]
        completed = [label for key, label in items if getattr(instance, key)]
        instance.completed_count = len(completed)
        instance.completed_items = completed
        instance.bundle_completed = len(completed) == len(items)
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class GcsAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = GcsAssessment
    serializer_class = GcsAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        computed = calc_gcs({'eyes': instance.eyes, 'verbal': instance.verbal, 'motor': instance.motor})
        instance.total = computed.get('total')
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class DiabetesBundleAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = DiabetesBundleAssessment
    serializer_class = DiabetesBundleAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class HeartFailureBundleAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = HeartFailureBundleAssessment
    serializer_class = HeartFailureBundleAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class PIVCAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = PIVCAssessment
    serializer_class = PIVCAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        computed = calc_pivc({
            'pain_level': instance.pain_level,
            'erythema': instance.erythema,
            'swelling': instance.swelling,
            'induration': instance.induration,
            'palpable_cord': instance.palpable_cord,
            'drainage_type': instance.drainage_type,
            **{k.lstrip('bundle_'): v for k, v in serializer.validated_data.items()
               if k.startswith('bundle_') and k != 'bundle_compliance_pct'},
        })
        instance.vip_score = computed.get('vip_score')
        instance.vip_colour = computed.get('vip_colour', '')
        instance.vip_label = computed.get('vip_label', '')
        instance.recommendations = computed.get('recommendations', [])
        instance.bundle_compliance_pct = computed.get('bundle_compliance_pct')
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class EnteralFeedingAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = EnteralFeedingAssessment
    serializer_class = EnteralFeedingAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        bundle_keys = [k for k in serializer.validated_data
                      if k.startswith('bundle_') and k != 'bundle_compliance_pct']
        answered = [k for k in bundle_keys if serializer.validated_data.get(k, '') in ('yes', 'no', 'na')]
        yes_count = sum(1 for k in bundle_keys if serializer.validated_data.get(k) == 'yes')
        if answered:
            instance.bundle_compliance_pct = round(yes_count / len(answered) * 100)
        else:
            instance.bundle_compliance_pct = None
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class CVADAssessmentViewSet(_BaseAssessmentScaleViewSet):
    """Central Vascular Access Device (CVAD) care bundle — CLABSI prevention.

    Auto-computes bundle compliance from the ``bundle_*`` yes/no/na items and
    raises escalation flags when local site infection signs coincide with
    systemic sepsis signs (suspected CLABSI) or a mechanical complication is
    recorded.
    """
    model = CVADAssessment
    serializer_class = CVADAssessmentSerializer

    _SITE_INFECTION_FIELDS = ('site_purulent_drainage', 'site_redness', 'site_swelling', 'site_warmth', 'site_tenderness')
    _SYSTEMIC_FIELDS = ('patient_fever', 'patient_chills', 'patient_rigors', 'patient_hypotension')
    _COMPLICATION_FIELDS = (
        'complication_migration', 'complication_leakage', 'complication_occlusion',
        'complication_damage', 'complication_dislodgement', 'complication_thrombosis',
    )

    def perform_create(self, serializer):
        instance = serializer.save()
        data = serializer.validated_data

        bundle_keys = [k for k in data if k.startswith('bundle_') and k != 'bundle_compliance_pct']
        answered = [k for k in bundle_keys if data.get(k) in ('yes', 'no', 'na')]
        yes_count = sum(1 for k in answered if data.get(k) == 'yes')
        instance.bundle_compliance_pct = round(yes_count / len(answered) * 100) if answered else None

        # Suspected CLABSI: local site infection sign(s) + systemic sepsis sign(s).
        has_site = any(data.get(f) for f in self._SITE_INFECTION_FIELDS)
        has_systemic = any(data.get(f) for f in self._SYSTEMIC_FIELDS)
        instance.suspected_clabsi = bool(data.get('site_purulent_drainage')) or (has_site and has_systemic)

        has_complication = any(data.get(f) for f in self._COMPLICATION_FIELDS)
        instance.escalation_required = instance.suspected_clabsi or has_complication

        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class UrinaryCatheterAssessmentViewSet(_BaseAssessmentScaleViewSet):
    model = UrinaryCatheterAssessment
    serializer_class = UrinaryCatheterAssessmentSerializer

    def perform_create(self, serializer):
        instance = serializer.save()
        bundle_keys = [k for k in serializer.validated_data
                      if k.startswith('bundle_') and k != 'bundle_compliance_pct']
        answered = [k for k in bundle_keys if serializer.validated_data.get(k, '') in ('yes', 'no', 'na')]
        yes_count = sum(1 for k in bundle_keys if serializer.validated_data.get(k) == 'yes')
        if answered:
            instance.bundle_compliance_pct = round(yes_count / len(answered) * 100)
        else:
            instance.bundle_compliance_pct = None
        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)


class ArtificialAirwayAssessmentViewSet(_BaseAssessmentScaleViewSet):
    """Airway Management assessment engine — Tracheostomy + VAP.

    Auto-computes two separate compliance percentages (tracheostomy vs VAP)
    from the ``yes/no/na`` checklist fields, plus an overall percentage, and
    flags incomplete emergency equipment for a critical alert.
    """
    model = ArtificialAirwayAssessment
    serializer_class = ArtificialAirwayAssessmentSerializer

    # Emergency-equipment fields — any "no" raises a critical safety flag.
    _EMERGENCY_FIELDS = (
        't_emerg_same_size_tube', 't_emerg_smaller_tube', 't_emerg_obturator',
        't_emerg_bag_valve_mask', 't_emerg_oxygen', 't_emerg_call_bell',
    )

    @staticmethod
    def _compliance(data, prefix):
        """Percentage of answered ``prefix*`` checklist items marked 'yes'.

        Only counts fields whose value is one of yes/no/na (the tri-state
        checklist inputs); ignores blank/unanswered and free-text fields."""
        keys = [k for k in data if k.startswith(prefix)
                and data.get(k) in ('yes', 'no', 'na')]
        if not keys:
            return None
        yes_count = sum(1 for k in keys if data.get(k) == 'yes')
        return round(yes_count / len(keys) * 100)

    def perform_create(self, serializer):
        instance = serializer.save()
        data = serializer.validated_data

        trach = self._compliance(data, 't_')
        vap = self._compliance(data, 'v_')
        instance.trach_compliance_pct = trach
        instance.vap_compliance_pct = vap

        parts = [p for p in (trach, vap) if p is not None]
        instance.overall_compliance_pct = round(sum(parts) / len(parts)) if parts else None

        # Any emergency-equipment item explicitly marked "no" is a critical gap.
        instance.emergency_equipment_incomplete = any(
            data.get(f) == 'no' for f in self._EMERGENCY_FIELDS
        )

        _stamp_assessment_actor(instance, self.request.user)
        instance.save()
        _finish_episode_refresh(instance.episode, self.request.user)
        serializer.instance = instance

    def perform_update(self, serializer):
        self.perform_create(serializer)

