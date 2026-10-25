"""Clinic Command Center — one aggregated payload for the clinic dashboard.

The clinic landing page previously fanned out to 11 list endpoints with
``page_size=1000`` and re-aggregated everything client-side.  That made the
dashboard slow and gave every widget a slightly different idea of "today".

This view computes everything on the server, in one schema, with a single
``?range=`` switch so the KPIs, the trend series and the deltas all describe
the same window.

Query params
------------
``range``     today | 7d | 30d | 90d | all   (default ``today``)
``trend_days`` 7..30                         (default 14, chart window)

Response sections
-----------------
kpis / previous        headline numbers + the comparison window for deltas
trend                  zero-filled daily series (appointments/consultations/
                       patients/revenue) oldest → newest
pipeline               check-in → triage → consultation → pharmacy/lab → billed
revenue                billed / collected / outstanding + invoice mix
appointments           status mix, today's schedule, upcoming
triage                 acuity mix + open queue
lab / pharmacy         order status pipelines
care_team              doctor workload leaderboard
departments            per-department volume
wards                  bed occupancy (null when the clinic has no wards)
alerts                 open escalations
activity               newest audit events
quick_stats            supporting counters for the hero strip
"""
from datetime import timedelta

from django.db.models import Count, DecimalField, ExpressionWrapper, F, Sum
from django.db.models.functions import Coalesce, TruncDate
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from clinic_sites.utils import (
    resolve_site, scope_to_site, sites_snapshot,
)

RANGES = {
    'today': 1,
    '7d': 7,
    '30d': 30,
    '90d': 90,
    'all': None,
}

DEFAULT_TREND_DAYS = 14
MAX_TREND_DAYS = 30


def _tone_for(count, warn=1, danger=None):
    """Map a count to a UI tone so the frontend stays declarative."""
    if danger is not None and count >= danger:
        return 'danger'
    if count >= warn:
        return 'warn'
    return 'ok'


def _money(value):
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _series(rows, days):
    """Zero-fill a ``[(date, value), ...]`` list into ``days`` buckets."""
    today = timezone.localdate()
    start = today - timedelta(days=days - 1)
    out = [0] * days
    for day, value in rows:
        if day is None:
            continue
        idx = (day - start).days
        if 0 <= idx < days:
            out[idx] = value
    return out


def _signed_q():
    """Filter helper: consultations that carry a ``signed_at`` timestamp."""
    from django.db.models import Q
    return Q(signed_at__isnull=False)


def _has_chronic_risk(patient):
    """True when the patient carries any recorded chronic condition.

    ``chronic_conditions`` may be free text or a JSON list depending on the
    form the record was created from, so handle both shapes.
    """
    value = getattr(patient, 'chronic_conditions', None)
    if not value:
        return False
    if isinstance(value, (list, tuple, set, dict)):
        return len(value) > 0
    return bool(str(value).strip())


def _labels(days):
    today = timezone.localdate()
    start = today - timedelta(days=days - 1)
    return [
        (start + timedelta(days=i)).isoformat()
        for i in range(days)
    ]


def _delta(current, previous):
    """Percent change, or ``None`` when there is no comparable baseline."""
    if previous in (None, 0):
        return None if not current else 100.0
    return round(((current - previous) / previous) * 100, 1)


class ClinicDashboardView(APIView):
    """Aggregated payload for the clinic Command Center page."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        range_key = (request.query_params.get('range') or 'today').lower()
        if range_key not in RANGES:
            range_key = 'today'
        span = RANGES[range_key]

        try:
            trend_days = int(request.query_params.get('trend_days') or DEFAULT_TREND_DAYS)
        except (TypeError, ValueError):
            trend_days = DEFAULT_TREND_DAYS
        trend_days = max(7, min(MAX_TREND_DAYS, trend_days))

        site = resolve_site(request.query_params.get('site'))

        today = timezone.localdate()
        if span is None:
            start_date = None
            prev_start_date = None
            prev_end_date = None
        else:
            start_date = today - timedelta(days=span - 1)
            prev_end_date = start_date - timedelta(days=1)
            prev_start_date = prev_end_date - timedelta(days=span - 1)

        ctx = _ClinicContext(
            today=today,
            start_date=start_date,
            prev_start_date=prev_start_date,
            prev_end_date=prev_end_date,
            trend_days=trend_days,
            site=site,
        )

        payload = {
            'generated_at': timezone.now().isoformat(),
            'range': range_key,
            'range_days': span,
            'trend_days': trend_days,
            'currency': 'KES',
            'site': site.id if site else None,
            'site_name': site.name if site else None,
            'sites': sites_snapshot(),
        }
        payload.update(ctx.build())
        return Response(payload)


class _ClinicContext:  # noqa: PLR0904 - a builder, not a model
    """Small helper that keeps each section of the payload isolated."""

    def __init__(self, today, start_date, prev_start_date, prev_end_date, trend_days, site=None):
        self.today = today
        self.start_date = start_date
        self.prev_start_date = prev_start_date
        self.prev_end_date = prev_end_date
        self.trend_days = trend_days
        self.site = site

    # ── queryset helpers ────────────────────────────────────────────
    def _appt_qs(self, start=None, end=None):
        from appointments.models import Appointment

        qs = scope_to_site(Appointment.objects.all(), self.site)
        if start:
            qs = qs.filter(appointment_date__gte=start)
        if end:
            qs = qs.filter(appointment_date__lte=end)
        return qs

    def _consult_qs(self, start=None, end=None):
        from consultations.models import Consultation

        qs = scope_to_site(Consultation.objects.all(), self.site)
        if start:
            qs = qs.filter(created_at__date__gte=start)
        if end:
            qs = qs.filter(created_at__date__lte=end)
        return qs

    def _invoice_qs(self, start=None, end=None):
        from billing.models import Invoice

        qs = scope_to_site(Invoice.objects.all(), self.site)
        if start:
            qs = qs.filter(created_at__date__gte=start)
        if end:
            qs = qs.filter(created_at__date__lte=end)
        return qs

    def _triage_qs(self, start=None, end=None):
        from triage.models import Triage

        qs = scope_to_site(Triage.objects.all(), self.site)
        if start:
            qs = qs.filter(triage_time__date__gte=start)
        if end:
            qs = qs.filter(triage_time__date__lte=end)
        return qs

    # ── build ───────────────────────────────────────────────────────
    def build(self):
        return {
            'kpis': self.kpis(),
            'previous': self.previous(),
            'deltas': self.deltas(),
            'trend': self.trend(),
            'pipeline': self.pipeline(),
            'revenue': self.revenue(),
            'appointments': self.appointments(),
            'triage': self.triage(),
            'lab': self.lab(),
            'pharmacy': self.pharmacy(),
            'care_team': self.care_team(),
            'departments': self.departments(),
            'wards': self.wards(),
            'patients': self.patients(),
            'alerts': self.alerts(),
            'activity': self.activity(),
        }

    # ── KPIs ────────────────────────────────────────────────────────
    def kpis(self):
        appts = self._appt_qs(self.start_date)
        consults = self._consult_qs(self.start_date)
        invoices = self._invoice_qs(self.start_date)
        triage = self._triage_qs(self.start_date)

        money = invoices.aggregate(
            billed=Coalesce(Sum('total'), 0, output_field=DecimalField()),
            collected=Coalesce(Sum('amount_paid'), 0, output_field=DecimalField()),
        )
        billed = _money(money['billed'])
        collected = _money(money['collected'])

        return {
            'appointments': appts.count(),
            'appointments_today': self._appt_qs(self.today, self.today).count(),
            'consultations': consults.count(),
            'triage': triage.count(),
            'patients_total': self._patient_count(),
            'patients_new': self._patient_new_count(self.start_date),
            'revenue_billed': billed,
            'revenue_collected': collected,
            'revenue_outstanding': max(0.0, round(billed - collected, 2)),
            'collection_rate': round((collected / billed) * 100, 1) if billed else 0.0,
            'lab_pending': self._lab_pending(),
            'rx_open': self._rx_open(),
            'alerts_open': self._alerts_open(),
        }

    def previous(self):
        if self.start_date is None:
            return None
        invoices = self._invoice_qs(self.prev_start_date, self.prev_end_date)
        money = invoices.aggregate(
            billed=Coalesce(Sum('total'), 0, output_field=DecimalField()),
            collected=Coalesce(Sum('amount_paid'), 0, output_field=DecimalField()),
        )
        return {
            'appointments': self._appt_qs(
                self.prev_start_date, self.prev_end_date).count(),
            'consultations': self._consult_qs(
                self.prev_start_date, self.prev_end_date).count(),
            'triage': self._triage_qs(
                self.prev_start_date, self.prev_end_date).count(),
            'patients_new': self._patient_new_count(
                self.prev_start_date, self.prev_end_date),
            'revenue_billed': _money(money['billed']),
            'revenue_collected': _money(money['collected']),
        }

    def deltas(self):
        prev = self.previous()
        cur = self.kpis()
        if not prev:
            return {}
        return {
            key: _delta(cur.get(key), prev.get(key))
            for key in (
                'appointments', 'consultations', 'triage', 'patients_new',
                'revenue_billed', 'revenue_collected',
            )
        }

    # ── Trend series ────────────────────────────────────────────────
    def trend(self):
        days = self.trend_days
        since = self.today - timedelta(days=days - 1)

        from appointments.models import Appointment
        from consultations.models import Consultation
        from patients.models import Patient
        from billing.models import Invoice

        appt_rows = (
            scope_to_site(Appointment.objects.filter(appointment_date__gte=since), self.site)
            .values('appointment_date')
            .annotate(n=Count('id'))
        )
        appts = _series(
            [(r['appointment_date'], r['n']) for r in appt_rows], days)

        consult_rows = (
            scope_to_site(Consultation.objects.filter(created_at__date__gte=since), self.site)
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(n=Count('id'))
        )
        consults = _series([(r['day'], r['n']) for r in consult_rows], days)

        patient_rows = (
            scope_to_site(Patient.objects.filter(created_at__date__gte=since), self.site)
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(n=Count('id'))
        )
        patients = _series([(r['day'], r['n']) for r in patient_rows], days)

        invoice_rows = (
            scope_to_site(Invoice.objects.filter(created_at__date__gte=since), self.site)
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(total=Sum('total'))
        )
        revenue = _series(
            [(r['day'], round(float(r['total'] or 0), 2)) for r in invoice_rows],
            days,
        )

        return {
            'dates': _labels(days),
            'appointments': appts,
            'consultations': consults,
            'patients': patients,
            'revenue': revenue,
        }

    # ── Clinical pipeline ───────────────────────────────────────────
    def pipeline(self):
        """Five-stage view of how a patient moves through the clinic today."""
        appts_today = self._appt_qs(self.today, self.today)
        statuses = {
            row['status']: row['n']
            for row in appts_today.values('status').annotate(n=Count('id'))
        }

        triage_today = self._triage_qs(self.today).count()
        consults_today = self._consult_qs(self.today, self.today).count()

        from lab.models import LabOrder
        lab_today = scope_to_site(
            LabOrder.objects.filter(created_at__date=self.today), self.site).count()

        from prescriptions.models import Prescription
        rx_today = scope_to_site(
            Prescription.objects.filter(created_at__date=self.today), self.site).count()

        from billing.models import Invoice
        invoices_today = scope_to_site(
            Invoice.objects.filter(created_at__date=self.today), self.site).count()

        total = max(
            1,
            sum(statuses.values()) or 0,
            triage_today,
            consults_today,
            lab_today,
            rx_today,
            invoices_today,
        )

        def pct(n):
            """Share of the busiest stage — a funnel reads 0-100%, never above."""
            return min(100.0, round((n / total) * 100, 1))

        scheduled = statuses.get('scheduled', 0)
        confirmed = statuses.get('confirmed', 0)
        in_progress = statuses.get('in_progress', 0)
        completed = statuses.get('completed', 0)
        cancelled = statuses.get('cancelled', 0) + statuses.get('no_show', 0)

        return [
            {'key': 'scheduled', 'label': 'Scheduled', 'count': scheduled,
             'pct': pct(scheduled), 'icon': 'mdi-calendar-blank'},
            {'key': 'checked_in', 'label': 'Checked in', 'count': confirmed + in_progress,
             'pct': pct(confirmed + in_progress), 'icon': 'mdi-account-check'},
            {'key': 'triaged', 'label': 'Triaged', 'count': triage_today,
             'pct': pct(triage_today), 'icon': 'mdi-heart-pulse'},
            {'key': 'seen', 'label': 'Consulted', 'count': consults_today,
             'pct': pct(consults_today), 'icon': 'mdi-stethoscope'},
            {'key': 'referred', 'label': 'Lab / Rx', 'count': max(lab_today, rx_today),
             'pct': pct(max(lab_today, rx_today)), 'icon': 'mdi-flask'},
            {'key': 'billed', 'label': 'Billed', 'count': invoices_today,
             'pct': pct(invoices_today), 'icon': 'mdi-receipt-text'},
            {'key': 'completed', 'label': 'Completed', 'count': completed,
             'pct': pct(completed), 'icon': 'mdi-check-decagram'},
            {'key': 'lost', 'label': 'Cancelled / no-show', 'count': cancelled,
             'pct': pct(cancelled), 'icon': 'mdi-account-off'},
        ]

    # ── Revenue ─────────────────────────────────────────────────────
    def revenue(self):
        invoices = self._invoice_qs(self.start_date)
        money = invoices.aggregate(
            billed=Coalesce(Sum('total'), 0, output_field=DecimalField()),
            collected=Coalesce(Sum('amount_paid'), 0, output_field=DecimalField()),
            balance=Coalesce(
                Sum(ExpressionWrapper(
                    F('total') - F('amount_paid'),
                    output_field=DecimalField(max_digits=14, decimal_places=2),
                )), 0, output_field=DecimalField()),
        )
        billed = _money(money['billed'])
        collected = _money(money['collected'])
        outstanding = max(0.0, _money(money['balance']))

        status_rows = list(
            invoices.values('status').annotate(
                n=Count('id'),
                amount=Sum('total'),
            ).order_by('-n')
        )
        total_n = sum(r['n'] for r in status_rows) or 1

        return {
            'billed': billed,
            'collected': collected,
            'outstanding': outstanding,
            'collection_rate': round((collected / billed) * 100, 1) if billed else 0.0,
            'invoice_count': sum(r['n'] for r in status_rows),
            'by_status': [
                {
                    'status': r['status'] or 'unknown',
                    'count': r['n'],
                    'amount': _money(r['amount']),
                    'pct': round((r['n'] / total_n) * 100, 1),
                }
                for r in status_rows
            ],
        }

    # ── Appointments ────────────────────────────────────────────────
    def appointments(self):
        appts = self._appt_qs(self.start_date)
        status_rows = list(
            appts.values('status').annotate(n=Count('id')).order_by('-n')
        )
        total = sum(r['n'] for r in status_rows) or 1

        today_rows = (
            self._appt_qs(self.today, self.today)
            .select_related('patient', 'patient__user', 'staff', 'department')
            .order_by('appointment_time')[:12]
        )
        upcoming_rows = (
            self._appt_qs(self.today + timedelta(days=1),
                          self.today + timedelta(days=30))
            .select_related('patient', 'patient__user', 'staff')
            .order_by('appointment_date', 'appointment_time')[:8]
        )

        return {
            'by_status': [
                {'status': r['status'], 'count': r['n'],
                 'pct': round((r['n'] / total) * 100, 1)}
                for r in status_rows
            ],
            'today': [self._appt_row(a) for a in today_rows],
            'upcoming': [self._appt_row(a) for a in upcoming_rows],
        }

    def _appt_row(self, appt):
        patient = getattr(appt, 'patient', None)
        user = getattr(patient, 'user', None)
        staff = getattr(appt, 'staff', None)
        name = 'Patient'
        if user is not None:
            name = getattr(user, 'full_name', '') or (
                f"{getattr(user, 'first_name', '')} "
                f"{getattr(user, 'last_name', '')}"
            ).strip() or getattr(user, 'email', '') or 'Patient'
        return {
            'id': appt.id,
            'patient_id': appt.patient_id,
            'patient_name': name,
            'patient_number': getattr(patient, 'patient_number', '') or '',
            'time': appt.appointment_time.strftime('%H:%M')
                    if appt.appointment_time else '',
            'date': appt.appointment_date.isoformat() if appt.appointment_date else None,
            'duration': appt.duration_minutes,
            'status': appt.status,
            'reason': appt.reason or '',
            'doctor': getattr(staff, 'full_name', '') or (
                f"{getattr(staff, 'first_name', '')} "
                f"{getattr(staff, 'last_name', '')}"
            ).strip(),
            'department': getattr(getattr(appt, 'department', None), 'name', '') or '',
        }

    # ── Triage ──────────────────────────────────────────────────────
    def triage(self):
        triage = self._triage_qs(self.start_date)
        acuity = []
        for row in triage.values('esi_level').annotate(n=Count('id')).order_by('esi_level'):
            level = row['esi_level']
            acuity.append({
                'level': level,
                'label': f'ESI {level}' if level else 'Unassigned',
                'count': row['n'],
                'tone': {
                    1: 'critical', 2: 'danger', 3: 'warn', 4: 'info', 5: 'ok',
                }.get(level, 'muted'),
            })

        open_qs = triage.exclude(status__in=['completed', 'cancelled'])

        return {
            'total': triage.count(),
            'open': open_qs.count(),
            'critical': triage.filter(esi_level__in=[1, 2]).count(),
            'by_acuity': acuity,
            'by_status': [
                {'status': r['status'], 'count': r['n']}
                for r in triage.values('status').annotate(n=Count('id')).order_by('-n')
            ],
        }

    # ── Lab ─────────────────────────────────────────────────────────
    def lab(self):
        from lab.models import LabOrder

        qs = scope_to_site(LabOrder.objects.all(), self.site)
        if self.start_date:
            qs = qs.filter(created_at__date__gte=self.start_date)

        rows = list(qs.values('status').annotate(n=Count('id')).order_by('-n'))
        by_status = [{'status': r['status'] or 'unknown', 'count': r['n']}
                     for r in rows]

        pending = qs.filter(status__in=[
            'pending', 'sample_collected', 'processing', 'in_progress',
        ]).count()
        todays = scope_to_site(
            LabOrder.objects.filter(created_at__date=self.today), self.site).count()

        return {
            'total': qs.count(),
            'pending': pending,
            'today': todays,
            'by_status': by_status,
            'by_priority': [
                {'priority': r['priority'], 'count': r['n']}
                for r in qs.values('priority').annotate(n=Count('id')).order_by('-n')
            ],
        }

    # ── Pharmacy ────────────────────────────────────────────────────
    def pharmacy(self):
        from prescriptions.models import Prescription

        qs = scope_to_site(Prescription.objects.all(), self.site)
        if self.start_date:
            qs = qs.filter(created_at__date__gte=self.start_date)

        rows = list(qs.values('status').annotate(n=Count('id')).order_by('-n'))
        open_qs = qs.exclude(status__in=['dispensed', 'cancelled'])

        return {
            'total': qs.count(),
            'open': open_qs.count(),
            'today': scope_to_site(
                Prescription.objects.filter(created_at__date=self.today), self.site).count(),
            'by_status': [{'status': r['status'] or 'unknown', 'count': r['n']}
                          for r in rows],
        }

    # ── Care team ───────────────────────────────────────────────────
    def care_team(self):
        """Consultation volume per doctor, plus completion rate."""
        consults = self._consult_qs(self.start_date)
        rows = (
            consults.exclude(doctor__isnull=True)
            .values('doctor_id', 'doctor__first_name', 'doctor__last_name',
                    'doctor__email')
            .annotate(
                total=Count('id'),
                signed=Count('id', filter=_signed_q()),
            )
            .order_by('-total')[:8]
        )
        out = []
        for r in rows:
            name = (f"{r['doctor__first_name'] or ''} "
                    f"{r['doctor__last_name'] or ''}").strip() \
                or r['doctor__email'] or 'Clinician'
            total = r['total'] or 0
            out.append({
                'id': r['doctor_id'],
                'name': name,
                'email': r['doctor__email'] or '',
                'consultations': total,
                'signed': r['signed'] or 0,
                'completion': round(((r['signed'] or 0) / total) * 100, 1) if total else 0,
            })
        return out

    # ── Departments ─────────────────────────────────────────────────
    def departments(self):
        from departments.models import Department

        appts = self._appt_qs(self.start_date)
        counts = {
            r['department_id']: r['n']
            for r in appts.exclude(department__isnull=True)
            .values('department_id').annotate(n=Count('id'))
        }
        out = []
        for dept in Department.objects.all().order_by('name'):
            out.append({
                'id': dept.id,
                'name': dept.name,
                'is_active': dept.is_active,
                'appointments': counts.get(dept.id, 0),
            })
        out.sort(key=lambda d: d['appointments'], reverse=True)
        return out

    # ── Wards ───────────────────────────────────────────────────────
    def wards(self):
        from wards.models import Bed

        total = Bed.objects.count()
        if not total:
            return None
        occupied = Bed.objects.filter(status='occupied').count()
        return {
            'beds_total': total,
            'beds_occupied': occupied,
            'beds_available': max(0, total - occupied),
            'occupancy_pct': round((occupied / total) * 100, 1),
        }

    # ── Patients ────────────────────────────────────────────────────
    def patients(self):
        from patients.models import Patient

        qs = scope_to_site(
            Patient.objects.select_related('user'), self.site,
        ).order_by('-created_at')[:6]
        out = []
        for p in qs:
            user = getattr(p, 'user', None)
            name = getattr(user, 'full_name', '') or (
                f"{getattr(user, 'first_name', '')} "
                f"{getattr(user, 'last_name', '')}"
            ).strip() or getattr(user, 'email', '') or 'Patient'
            out.append({
                'id': p.id,
                'name': name,
                'patient_number': p.patient_number or '',
                'gender': p.gender or '',
                'created_at': p.created_at.isoformat() if p.created_at else None,
                'risk': 'high' if _has_chronic_risk(p) else 'normal',
            })
        return out

    # ── Alerts ──────────────────────────────────────────────────────
    def alerts(self):
        try:
            from homecare.models import Escalation
        except Exception:
            return []
        qs = (
            Escalation.objects
            .filter(status__in=['open', 'acknowledged'])
            .select_related('patient', 'patient__user')
            .order_by('-triggered_at')[:8]
        )
        out = []
        for e in qs:
            user = getattr(getattr(e, 'patient', None), 'user', None)
            name = getattr(user, 'full_name', '') or (
                f"{getattr(user, 'first_name', '')} "
                f"{getattr(user, 'last_name', '')}"
            ).strip() or 'Patient'
            out.append({
                'id': e.id,
                'patient_name': name,
                'reason': e.reason or '',
                'severity': e.severity,
                'status': e.status,
                'triggered_at': e.triggered_at.isoformat() if e.triggered_at else None,
            })
        return out

    # ── Audit activity ──────────────────────────────────────────────
    def activity(self):
        try:
            from audit.models import AuditEvent
        except Exception:
            return []
        rows = AuditEvent.objects.order_by('-created_at')[:10]
        out = []
        for e in rows:
            out.append({
                'id': e.id,
                'action': e.action,
                'severity': e.severity,
                'description': e.description or ' '.join(
                    p for p in (e.get_action_display(), e.object_type) if p
                ) or 'Activity',
                'actor_email': e.actor_email or '',
                'created_at': e.created_at.isoformat() if e.created_at else None,
            })
        return out

    # ── counters ────────────────────────────────────────────────────
    def _patient_count(self):
        from patients.models import Patient
        return scope_to_site(Patient.objects.all(), self.site).count()

    def _patient_new_count(self, start=None, end=None):
        from patients.models import Patient
        qs = scope_to_site(Patient.objects.all(), self.site)
        if start:
            qs = qs.filter(created_at__date__gte=start)
        if end:
            qs = qs.filter(created_at__date__lte=end)
        return qs.count()

    def _lab_pending(self):
        from lab.models import LabOrder
        return scope_to_site(LabOrder.objects.all(), self.site).filter(status__in=[
            'pending', 'sample_collected', 'processing', 'in_progress',
        ]).count()

    def _rx_open(self):
        from prescriptions.models import Prescription
        return scope_to_site(Prescription.objects.all(), self.site).exclude(
            status__in=['dispensed', 'cancelled']).count()

    def _alerts_open(self):
        try:
            from homecare.models import Escalation
        except Exception:
            return 0
        return Escalation.objects.filter(
            status__in=['open', 'acknowledged']).count()
