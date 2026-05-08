"""Homecare DRF views."""
import json
import time
from datetime import timedelta

from django.db import connection
from django.db.models import Avg, Count, Q
from django.http import StreamingHttpResponse
from django.utils import timezone
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
    Consent,
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
)
from .permissions import IsHomecareStaff, IsHomecareStaffOrPatient


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
    filterset_fields = ['employment_status', 'is_available', 'is_independent']
    search_fields = ['user__email', 'user__first_name', 'user__last_name', 'license_number']
    ordering_fields = ['rating', 'total_visits', 'created_at']

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
            if d.get('password'):
                user.set_password(d['password'])
            user.save()
            uid = user.id
        cg = Caregiver.objects.create(
            user_id=uid,
            license_number=d.get('license_number', ''),
            bio=d.get('bio', ''),
            specialties=d.get('specialties') or [],
            certifications=d.get('certifications') or [],
            employment_status=d.get('employment_status', 'active'),
            is_independent=bool(d.get('is_independent', False)),
            is_available=bool(d.get('is_available', True)),
            hourly_rate=d.get('hourly_rate') or 0,
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
                return qs.filter(Q(assigned_caregiver=cg) | Q(schedules__caregiver=cg)).distinct()
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
            if d.get('password'):
                user.set_password(d['password'])
            user.save()
            uid = user.id
        patient = HomecarePatient.objects.create(
            user_id=uid,
            date_of_birth=d.get('date_of_birth') or None,
            gender=d.get('gender', ''),
            address=d.get('address', ''),
            primary_diagnosis=d.get('primary_diagnosis', ''),
            allergies=d.get('allergies', ''),
            risk_level=d.get('risk_level', 'low'),
            assigned_caregiver_id=d.get('assigned_caregiver') or None,
        )
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

    @action(detail=True, methods=['post'])
    def check_in(self, request, pk=None):
        sch = self.get_object()
        sch.status = CaregiverSchedule.Status.CHECKED_IN
        sch.check_in_at = timezone.now()
        sch.gps_check_in = request.data.get('gps') or {}
        sch.save(update_fields=['status', 'check_in_at', 'gps_check_in'])
        return Response(self.get_serializer(sch).data)

    @action(detail=True, methods=['post'])
    def check_out(self, request, pk=None):
        sch = self.get_object()
        sch.status = CaregiverSchedule.Status.COMPLETED
        sch.check_out_at = timezone.now()
        sch.gps_check_out = request.data.get('gps') or {}
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
        sch.status = CaregiverSchedule.Status.MISSED
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


# ─────────────────────────────────────────────────────────
class MedicationScheduleViewSet(viewsets.ModelViewSet):
    queryset = MedicationSchedule.objects.select_related('patient__user').all()
    serializer_class = MedicationScheduleSerializer
    permission_classes = [IsHomecareStaff]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'is_active', 'requires_caregiver']
    search_fields = ['medication_name']

    @action(detail=True, methods=['post'])
    def generate_doses(self, request, pk=None):
        from .services import expand_doses_for_schedule
        sched = self.get_object()
        days = int(request.data.get('days_ahead') or 7)
        created = expand_doses_for_schedule(sched, days_ahead=days)
        return Response({'created': created})


# ─────────────────────────────────────────────────────────
class DoseEventViewSet(viewsets.ModelViewSet):
    queryset = DoseEvent.objects.select_related(
        'schedule__patient__user', 'administered_by_caregiver__user',
    ).all()
    serializer_class = DoseEventSerializer
    permission_classes = [IsHomecareStaffOrPatient]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['status', 'schedule__patient']
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
                return qs.filter(schedule__patient__assigned_caregiver=cg)
            return qs.none()
        return qs

    def _mark(self, dose: DoseEvent, status_value: str, request):
        dose.status = status_value
        dose.notes = request.data.get('notes', dose.notes)
        if status_value == DoseEvent.Status.TAKEN:
            dose.administered_at = timezone.now()
            cg = Caregiver.objects.filter(user=request.user).first()
            if cg:
                dose.administered_by_caregiver = cg
            if request.data.get('vitals_pre'):
                dose.vitals_pre = request.data['vitals_pre']
            if request.data.get('vitals_post'):
                dose.vitals_post = request.data['vitals_post']
            if request.data.get('patient_confirmation'):
                dose.patient_confirmation = request.data['patient_confirmation']
        dose.save()
        return dose

    @action(detail=True, methods=['post'])
    def mark_taken(self, request, pk=None):
        return Response(self.get_serializer(
            self._mark(self.get_object(), DoseEvent.Status.TAKEN, request)
        ).data)

    @action(detail=True, methods=['post'])
    def mark_missed(self, request, pk=None):
        return Response(self.get_serializer(
            self._mark(self.get_object(), DoseEvent.Status.MISSED, request)
        ).data)

    @action(detail=True, methods=['post'])
    def mark_skipped(self, request, pk=None):
        return Response(self.get_serializer(
            self._mark(self.get_object(), DoseEvent.Status.SKIPPED, request)
        ).data)

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
        join_url = (f'https://meet.jit.si/AfyaOne-{room.room_token}'
                    if room.provider == TeleconsultRoom.Provider.JITSI
                    else (room.join_urls.get('default') if isinstance(room.join_urls, dict) else ''))
        return Response({'room_token': str(room.room_token), 'join_url': join_url,
                         'provider': room.provider, 'status': room.status})

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
