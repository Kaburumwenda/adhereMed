"""Homecare DRF views."""
import json
import time
from datetime import timedelta

from django.db import connection
from django.db.models import Avg, Count, Q
from django.http import StreamingHttpResponse
from django.utils import timezone
from django.utils.dateparse import parse_datetime
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
    CarePathway, CarePathwayEnrollment,
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
)
from .permissions import IsHomecareStaff, IsHomecareStaffOrPatient, IsHomecareAdmin


# ─────────────────────────────────────────────────────────
class HomecareCompanyProfileViewSet(viewsets.ModelViewSet):
    queryset = HomecareCompanyProfile.objects.all()
    serializer_class = HomecareCompanyProfileSerializer
    permission_classes = [IsHomecareStaff]

    @action(detail=False, methods=['get'])
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
        with schema_context('public'):
            user, _ = UserModel.objects.get_or_create(
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
            user.save()
            uid = user.id
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
        return Response(self.get_serializer(patient).data, status=201)

    @action(detail=True, methods=['get'])
    def overview(self, request, pk=None):
        p = self.get_object()
        active_plan = p.treatment_plans.filter(status='active').first()
        adherence_qs = DoseEvent.objects.filter(schedule__patient=p)
        agg = adherence_qs.aggregate(
            total=Count('id'),
            taken=Count('id', filter=Q(status='taken')),
            missed=Count('id', filter=Q(status='missed')),
        )
        return Response({
            'patient': self.get_serializer(p).data,
            'active_plan': TreatmentPlanSerializer(active_plan).data if active_plan else None,
            'medication_schedules': MedicationScheduleSerializer(
                p.medication_schedules.filter(is_active=True), many=True
            ).data,
            'recent_notes': CaregiverNoteSerializer(
                p.caregiver_notes.all()[:10], many=True
            ).data,
            'open_escalations': EscalationSerializer(
                p.escalations.filter(status='open'), many=True
            ).data,
            'adherence': agg,
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
        return Response(breakdown)

    @action(detail=True, methods=['post'])
    def assign(self, request, pk=None):
        device = self.get_object()
        patient_id = request.data.get('patient')
        if not patient_id:
            return Response({'patient': ['This field is required.']}, status=400)
        try:
            patient = HomecarePatient.objects.get(pk=patient_id)
        except HomecarePatient.DoesNotExist:
            return Response({'patient': ['Patient not found.']}, status=404)
        if device.status not in (Device.Status.AVAILABLE,):
            return Response({'detail': f'Device is currently {device.get_status_display()}.'},
                            status=400)
        DeviceAssignment.objects.create(
            device=device,
            patient=patient,
            assigned_by=request.user if request.user.is_authenticated else None,
            expected_return_at=request.data.get('expected_return_at') or None,
            notes=request.data.get('notes', ''),
        )
        device.status = Device.Status.ASSIGNED
        device.assigned_to = patient
        device.save(update_fields=['status', 'assigned_to', 'updated_at'])
        return Response(self.get_serializer(device).data)

    @action(detail=True, methods=['post'])
    def return_device(self, request, pk=None):
        device = self.get_object()
        last = device.assignments.filter(returned_at__isnull=True).order_by('-assigned_at').first()
        if last:
            last.returned_at = timezone.now()
            last.return_condition = request.data.get('condition', '')
            if request.data.get('notes'):
                last.notes = (last.notes + '\n' if last.notes else '') + request.data['notes']
            last.save(update_fields=['returned_at', 'return_condition', 'notes'])
        new_status = request.data.get('status') or Device.Status.AVAILABLE
        if new_status not in dict(Device.Status.choices):
            new_status = Device.Status.AVAILABLE
        device.status = new_status
        device.assigned_to = None
        device.save(update_fields=['status', 'assigned_to', 'updated_at'])
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
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['device', 'patient']
    ordering_fields = ['assigned_at', 'returned_at']

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



