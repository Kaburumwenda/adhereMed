from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.utils import timezone

from .models import Triage
from .serializers import TriageSerializer
from clinic_sites.mixins import ClinicSiteScopedMixin


class TriageViewSet(ClinicSiteScopedMixin, viewsets.ModelViewSet):
    queryset = Triage.objects.select_related(
        'patient__user', 'nurse', 'doctor', 'clinic_site',
    ).all()
    serializer_class = TriageSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['esi_level', 'status', 'patient', 'clinic_site', 'doctor']
    search_fields = ['chief_complaint', 'patient__user__first_name', 'patient__user__last_name']
    ordering_fields = ['esi_level', 'triage_time', 'assigned_at']

    def perform_create(self, serializer):
        """Auto-assign nurse from the authenticated user if not provided."""
        if not serializer.validated_data.get('nurse'):
            serializer.save(nurse=self.request.user)
        else:
            serializer.save()

    @action(detail=True, methods=['patch'], url_path='complete')
    def complete_triage(self, request, pk=None):
        """Mark triage as completed — fires triage.completed event.

        Also advances the linked front-desk visit to `awaiting_doctor`. The
        triage workspace talks to this endpoint (not the visits app's
        `complete-triage` action), so without this the patient stayed parked in
        the front desk's "In triage" column forever even though the doctor
        queue already listed them.
        """
        obj = self.get_object()
        obj.status = Triage.TriageStatus.COMPLETED
        obj.completed_at = timezone.now()
        # Update any fields submitted with this patch
        serializer = self.get_serializer(obj, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save(status=obj.status, completed_at=obj.completed_at)

        self._sync_visit_after_completion(obj, request.user)

        # Re-serialise so callers see any visit-derived fields in one round trip.
        return Response(self.get_serializer(obj).data)

    def _sync_visit_after_completion(self, triage, actor):
        """Move the linked PatientVisit out of triage, mirroring doctor/priority.

        Skipped silently when the triage was never attached to a visit (e.g. it
        was created straight from the triage module for a walk-in that reception
        did not register).
        """
        from visits.models import PatientVisit

        # Reverse OneToOne; absent relation raises RelatedObjectDoesNotExist,
        # which subclasses AttributeError so getattr's default is returned.
        visit = getattr(triage, 'visit', None)
        if visit is None:
            return

        changed = []

        # The doctor assigned in the triage workspace is the receiving
        # clinician — carry it onto the visit so the board and the doctor queue
        # agree on who owns the patient.
        if triage.doctor_id and visit.doctor_id != triage.doctor_id:
            visit.doctor_id = triage.doctor_id
            visit.doctor_assigned_at = timezone.now()
            changed.append('doctor')

        if triage.esi_level:
            if triage.esi_level <= 2:
                priority = PatientVisit.Priority.EMERGENCY
            elif triage.esi_level == 3:
                priority = PatientVisit.Priority.URGENT
            else:
                priority = PatientVisit.Priority.ROUTINE
            if visit.priority != priority:
                visit.priority = priority
                changed.append('priority')

        if not visit.triage_completed_at:
            visit.triage_completed_at = triage.completed_at or timezone.now()
            changed.append('triage_completed_at')

        if changed:
            visit.save(update_fields=changed)

        # Only move the stage forward. A patient already with the doctor or
        # further along must not be dragged back to the waiting queue.
        up_to_triage = {
            PatientVisit.Stage.ARRIVED,
            PatientVisit.Stage.REGISTERED,
            PatientVisit.Stage.AWAITING_PAYMENT,
            PatientVisit.Stage.PAID,
            PatientVisit.Stage.TRIAGE,
        }
        if visit.stage in up_to_triage:
            visit.set_stage(
                PatientVisit.Stage.AWAITING_DOCTOR, actor=actor,
                note='Triage completed — patient queued for the doctor.',
            )

    @action(detail=False, methods=['get'], url_path='doctor-workload')
    def doctor_workload(self, request):
        """Live workload + engagement for this clinic's clinicians, for handoff.

        A clinician's queue is the set of *completed* triages assigned to them
        that have no consultation yet — i.e. patients physically waiting for
        that doctor. `in_progress` counts draft consultations, which represent
        a doctor actively seeing someone.

        Engagement is derived from the audit log rather than session state:
        JWTs mean Django sessions are empty, so `last_login` is useless here.
        A clinician counts as engaged if they produced an audited request in
        the last `ENGAGED_WINDOW_MINUTES`.

        Scoping matters more than it looks: `accounts` is a SHARED_APP, so
        `User` rows live in `public.accounts_user` and hold **every** tenant's
        users. django_tenants does not filter them for us, so without an
        explicit `tenant=` filter this endpoint hands a clinic the other
        clinics' doctors.
        """
        from datetime import timedelta
        from django.db import connection
        from django.db.models import Count, Max

        from accounts.models import User
        from audit.models import AuditEvent
        from consultations.models import Consultation
        from staff_profiles.models import StaffProfile
        from tenants.models import Tenant

        ENGAGED_WINDOW_MINUTES = 15
        since = timezone.now() - timedelta(minutes=ENGAGED_WINDOW_MINUTES)

        CLINICAL_ROLES = ['doctor', 'clinical_officer', 'dentist', 'midwife']

        # ── Resolve the active clinic ───────────────────────────────────
        # `request.tenant` is set by the tenant middleware; fall back to the
        # schema the connection is on, and finally to the caller's own tenant.
        tenant = getattr(request, 'tenant', None)
        if not tenant or getattr(tenant, 'schema_name', 'public') == 'public':
            schema = getattr(connection, 'schema_name', None)
            tenant = (
                Tenant.objects.filter(schema_name=schema).first() if schema
                else None
            )
        if not tenant:
            tenant = getattr(request.user, 'tenant', None)

        # Triage rows still waiting on a clinician, scoped to this tenant schema
        # by django_tenants. `consultation__isnull=True` means nobody has picked
        # the patient up yet.
        waiting_rows = (
            Triage.objects
            .filter(
                status=Triage.TriageStatus.COMPLETED,
                doctor__isnull=False,
                consultation__isnull=True,
            )
            .values('doctor')
            .annotate(n=Count('id'))
        )
        waiting_by_doctor = {r['doctor']: r['n'] for r in waiting_rows}

        # Draft consultations = the doctor is mid-encounter.
        active_rows = (
            Consultation.objects
            .filter(status=Consultation.ConsultationStatus.DRAFT)
            .values('doctor')
            .annotate(n=Count('id'))
        )
        active_by_doctor = {r['doctor']: r['n'] for r in active_rows}

        # Most recent audited activity per user — the presence signal.
        recent_ids = list(
            AuditEvent.objects
            .filter(actor_user_id__isnull=False, created_at__gte=since)
            .values_list('actor_user_id', flat=True)
            .distinct()
        )
        # A clinician mid-consultation is engaged by definition, even if the
        # audit log has nothing for them yet (e.g. a fresh session).
        engaged_ids = set(recent_ids) | {uid for uid, n in active_by_doctor.items() if n}

        last_seen = {}
        for row in (
            AuditEvent.objects
            .filter(actor_user_id__isnull=False)
            .values('actor_user_id')
            .annotate(last=Max('created_at'))
        ):
            last_seen[row['actor_user_id']] = row['last']

        clinicians_qs = User.objects.filter(is_active=True, role__in=CLINICAL_ROLES)
        # Hard tenant filter — `User` is a public-schema model shared by every
        # clinic, so this is what actually keeps other clinics' doctors out.
        if tenant:
            clinicians_qs = clinicians_qs.filter(tenant_id=tenant.pk)
        else:
            # No tenant could be resolved; never widen the result set.
            clinicians_qs = clinicians_qs.none()
        clinicians = clinicians_qs.order_by('first_name', 'last_name')

        # Department is a tenant-scoped detail that proves the clinician sits on
        # this clinic's roster (and reads better than a bare role label).
        clinician_ids = [u.id for u in clinicians]
        dept_by_user = {}
        if clinician_ids:
            for p in (
                StaffProfile.objects
                .filter(user_id__in=clinician_ids)
                .select_related('department')
            ):
                if p.department_id and p.department:
                    dept_by_user[p.user_id] = p.department.name

        now = timezone.now()
        out = []
        for u in clinicians:
            waiting = waiting_by_doctor.get(u.id, 0)
            in_progress = active_by_doctor.get(u.id, 0)
            last = last_seen.get(u.id)
            engaged = u.id in engaged_ids
            if in_progress:
                presence = 'in_consult'
            elif engaged:
                presence = 'active'
            elif last:
                presence = 'idle'
            else:
                presence = 'away'
            out.append({
                'id': u.id,
                'full_name': f'{u.first_name} {u.last_name}'.strip() or u.email,
                'role': u.role,
                'email': u.email,
                'department': dept_by_user.get(u.id, ''),
                'waiting': waiting,
                'in_progress': in_progress,
                'load': waiting + in_progress,
                'engaged': engaged,
                'presence': presence,
                'last_seen_minutes': (
                    int((now - last).total_seconds() // 60) if last else None
                ),
            })

        # Lightest queue wins. Engagement is only a tie-breaker — otherwise a
        # single signed-in clinician with a full queue would be recommended
        # over five idle colleagues, which defeats the point of the suggestion.
        ranked = sorted(
            out,
            key=lambda c: (
                c['load'],
                c['in_progress'],
                0 if c['engaged'] else 1,
                c['last_seen_minutes'] if c['last_seen_minutes'] is not None else 10**6,
            ),
        )
        recommended = ranked[0]['id'] if ranked else None
        for c in out:
            c['recommended'] = c['id'] == recommended

        return Response({
            'engaged_window_minutes': ENGAGED_WINDOW_MINUTES,
            'recommended': recommended,
            'count': len(out),
            'tenant': {
                'id': tenant.pk if tenant else None,
                'name': (getattr(tenant, 'name', '') or '') if tenant else '',
                'schema': (getattr(tenant, 'schema_name', '') or '') if tenant else '',
            },
            'results': out,
        })
