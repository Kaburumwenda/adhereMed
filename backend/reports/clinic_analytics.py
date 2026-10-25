"""Clinic Analytics — one comprehensive payload for /clinics/analytics.

The analytics workspace is a single screen: headline KPIs, a multi-series
trend chart, revenue quality, the patient journey funnel, demand heatmap,
department/doctor performance, demographics, lab & pharmacy throughput and
ward utilisation.  Computing all of that client-side meant downloading every
row of five endpoints; this view aggregates in the tenant schema so the page
paints from one request.

Query params
------------
``range``      today | 7d | 30d | 90d | all   (default ``30d``)
``trend_days`` 7..90                          (default 14)

Every section is built behind ``_safe`` so a single unavailable module (for
example wards on a tenant with no beds) can never take the whole page down.
"""
from __future__ import annotations

import logging
from datetime import date, timedelta

from django.db.models import Count, DecimalField, ExpressionWrapper, F, Q, Sum
from django.db.models.functions import Coalesce, TruncDate
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from clinic_sites.utils import resolve_site, scope_to_site, sites_snapshot

logger = logging.getLogger(__name__)

RANGES = {'today': 1, '7d': 7, '30d': 30, '90d': 90, 'all': None}
DEFAULT_RANGE = '30d'
DEFAULT_TREND_DAYS = 14
MAX_TREND_DAYS = 90
CURRENCY = 'KES'

WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
HEAT_HOURS = list(range(7, 20))  # 07:00 → 19:00


# ── helpers ──────────────────────────────────────────────────────────────
def _money(value) -> float:
    try:
        return round(float(value or 0), 2)
    except (TypeError, ValueError):
        return 0.0


def _delta(current, previous):
    """Percent change, or ``None`` when there is no comparable baseline."""
    try:
        current = float(current or 0)
        if previous in (None, 0):
            return None if not current else 100.0
        return round(((current - float(previous)) / float(previous)) * 100, 1)
    except (TypeError, ValueError):
        return None


def _pct(part, whole):
    try:
        if not whole:
            return 0.0
        return round((float(part or 0) / float(whole)) * 100, 1)
    except (TypeError, ValueError):
        return 0.0


def _safe(fn, default, label: str = 'section'):
    """Build one section; a broken module degrades that card only."""
    try:
        return fn()
    except Exception as exc:  # noqa: BLE001 - analytics must never 500
        logger.warning('clinic analytics: %s failed: %s', label, exc)
        return default


def _range_qs(qs, field, start, end=None):
    if start is not None:
        qs = qs.filter(**{f'{field}__date__gte': start})
    if end is not None:
        qs = qs.filter(**{f'{field}__date__lte': end})
    return qs


def _patient_qs(site, start=None, end=None):
    """Patients belonging to a site (``clinic_site IS NULL`` = HQ)."""
    from patients.models import Patient
    qs = scope_to_site(Patient.objects.all(), site)
    if start is not None:
        qs = qs.filter(created_at__date__gte=start)
    if end is not None:
        qs = qs.filter(created_at__date__lte=end)
    return qs


def _series(rows, days, start):
    """Zero-fill ``[(date, value), ...]`` into ``days`` buckets."""
    out = [0] * days
    for day, value in rows:
        if day is None:
            continue
        idx = (day - start).days
        if 0 <= idx < days:
            out[idx] = value
    return out


def _month_key(d: date) -> str:
    return f'{d.year}-{d.month:02d}'


def _month_label(d: date) -> str:
    return d.strftime('%b %y')


class ClinicAnalyticsView(APIView):
    """Comprehensive, range-scoped analytics payload for a clinic tenant."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        range_key = (request.query_params.get('range') or DEFAULT_RANGE).lower()
        if range_key not in RANGES:
            range_key = DEFAULT_RANGE
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
            prev_start = prev_end = None
        else:
            start_date = today - timedelta(days=span - 1)
            prev_end = start_date - timedelta(days=1)
            prev_start = prev_end - timedelta(days=span - 1)

        ctx = _AnalyticsContext(
            today=today,
            start_date=start_date,
            prev_start=prev_start,
            prev_end=prev_end,
            trend_days=trend_days,
            site=site,
        )
        payload = ctx.build()
        payload.update({
            'generated_at': timezone.now().isoformat(),
            'range': range_key,
            'range_days': span,
            'trend_days': trend_days,
            'currency': CURRENCY,
            'site': site.id if site else None,
            'site_name': site.name if site else None,
            'sites': sites_snapshot(),
        })
        return Response(payload)


class _AnalyticsContext:  # noqa: PLR0904 - builder, split per section
    def __init__(self, today, start_date, prev_start, prev_end, trend_days, site=None):
        self.today = today
        self.start_date = start_date
        self.prev_start = prev_start
        self.prev_end = prev_end
        self.trend_days = trend_days
        self.site = site

    # ── querysets ───────────────────────────────────────────────────
    def _appointments(self, start=None, end=None):
        from appointments.models import Appointment
        qs = scope_to_site(Appointment.objects.all(), self.site)
        if start is not None:
            qs = qs.filter(appointment_date__gte=start)
        if end is not None:
            qs = qs.filter(appointment_date__lte=end)
        return qs

    def _consultations(self, start=None, end=None):
        from consultations.models import Consultation
        return _range_qs(
            scope_to_site(Consultation.objects.all(), self.site),
            'created_at', start, end,
        )

    def _invoices(self, start=None, end=None):
        from billing.models import Invoice
        return _range_qs(
            scope_to_site(Invoice.objects.all(), self.site),
            'created_at', start, end,
        )

    def _payments(self, start=None, end=None):
        from billing.models import Payment
        return _range_qs(
            scope_to_site(Payment.objects.all(), self.site, field='invoice__clinic_site'),
            'paid_at', start, end,
        )

    def _triage(self, start=None, end=None):
        from triage.models import Triage
        return _range_qs(
            scope_to_site(Triage.objects.all(), self.site),
            'triage_time', start, end,
        )

    def _lab(self, start=None, end=None):
        from lab.models import LabOrder
        return _range_qs(
            scope_to_site(LabOrder.objects.all(), self.site),
            'created_at', start, end,
        )

    def _prescriptions(self, start=None, end=None):
        from prescriptions.models import Prescription
        return _range_qs(
            scope_to_site(Prescription.objects.all(), self.site),
            'created_at', start, end,
        )

    # ── build ───────────────────────────────────────────────────────
    def build(self):
        kpis = _safe(self.kpis, {}, 'kpis')
        previous = _safe(self.previous, None, 'previous')
        deltas = _safe(self.deltas, {}, 'deltas')
        revenue = _safe(self.revenue, {}, 'revenue')
        return {
            'kpis': kpis,
            'previous': previous,
            'deltas': deltas,
            'trend': _safe(self.trend, {'dates': []}, 'trend'),
            'revenue': revenue,
            'appointments': _safe(self.appointments, {}, 'appointments'),
            'demand': _safe(self.demand, {'hours': HEAT_HOURS, 'days': WEEKDAYS, 'matrix': []}, 'demand'),
            'funnel': _safe(self.funnel, [], 'funnel'),
            'departments': _safe(self.departments, [], 'departments'),
            'doctors': _safe(self.doctors, [], 'doctors'),
            'patients': _safe(self.patients, {}, 'patients'),
            'triage': _safe(self.triage, {}, 'triage'),
            'lab': _safe(self.lab, {}, 'lab'),
            'pharmacy': _safe(self.pharmacy, {}, 'pharmacy'),
            'wards': _safe(self.wards, {'available': False}, 'wards'),
            'insights': _safe(
                lambda: self.insights(kpis, previous, deltas, revenue), [], 'insights'),
        }

    # ── KPIs ────────────────────────────────────────────────────────
    def kpis(self):
        from patients.models import Patient

        appts = self._appointments(self.start_date)
        consults = self._consultations(self.start_date)
        invoices = self._invoices(self.start_date)
        triage = self._triage(self.start_date)
        lab = self._lab(self.start_date)
        rx = self._prescriptions(self.start_date)

        money = invoices.aggregate(
            billed=Coalesce(Sum('total'), 0, output_field=DecimalField()),
            paid=Coalesce(Sum('amount_paid'), 0, output_field=DecimalField()),
            balance=Coalesce(
                Sum(ExpressionWrapper(
                    F('total') - F('amount_paid'),
                    output_field=DecimalField(max_digits=14, decimal_places=2),
                )), 0, output_field=DecimalField()),
        )
        billed = _money(money['billed'])
        paid_on_invoices = _money(money['paid'])
        cash = _money(self._payments(self.start_date).aggregate(
            total=Coalesce(Sum('amount'), 0, output_field=DecimalField()))['total'])

        appt_total = appts.count()
        no_shows = appts.filter(status='no_show').count()

        new_start = self.start_date
        patients_new = _patient_qs(self.site, new_start).count()

        return {
            'appointments': appt_total,
            'appointments_completed': appts.filter(status='completed').count(),
            'appointments_cancelled': appts.filter(status='cancelled').count(),
            'appointments_no_show': no_shows,
            'no_show_rate': _pct(no_shows, appt_total),
            'consultations': consults.count(),
            'consultations_signed': consults.filter(status__in=['signed', 'locked']).count(),
            'patients_total': _patient_qs(self.site).count(),
            'patients_new': patients_new,
            'revenue_billed': billed,
            'revenue_collected': cash,
            'revenue_collected_on_invoices': paid_on_invoices,
            'revenue_outstanding': max(0.0, _money(money['balance'])),
            'collection_rate': _pct(paid_on_invoices, billed),
            'avg_ticket': round(billed / invoices.count(), 2) if invoices.count() else 0.0,
            'triage': triage.count(),
            'triage_critical': triage.filter(esi_level__in=[1, 2]).count(),
            'lab_orders': lab.count(),
            'lab_pending': lab.filter(status__in=[
                'pending', 'sample_collected', 'processing']).count(),
            'rx_total': rx.count(),
            'rx_open': rx.exclude(status__in=['dispensed', 'cancelled']).count(),
            'active_clinicians': consults.exclude(doctor__isnull=True)
                .values('doctor_id').distinct().count(),
        }

    def previous(self):
        if self.prev_start is None:
            return None
        from patients.models import Patient

        appts = self._appointments(self.prev_start, self.prev_end)
        invoices = self._invoices(self.prev_start, self.prev_end)
        money = invoices.aggregate(
            billed=Coalesce(Sum('total'), 0, output_field=DecimalField()),
            paid=Coalesce(Sum('amount_paid'), 0, output_field=DecimalField()),
        )
        cash = _money(self._payments(self.prev_start, self.prev_end).aggregate(
            total=Coalesce(Sum('amount'), 0, output_field=DecimalField()))['total'])
        return {
            'appointments': appts.count(),
            'appointments_completed': appts.filter(status='completed').count(),
            'no_show_rate': _pct(
                appts.filter(status='no_show').count(), appts.count()),
            'consultations': self._consultations(self.prev_start, self.prev_end).count(),
            'patients_new': _patient_qs(
                self.site, self.prev_start, self.prev_end).count(),
            'revenue_billed': _money(money['billed']),
            'revenue_collected': cash,
            'revenue_collected_on_invoices': _money(money['paid']),
            'triage': self._triage(self.prev_start, self.prev_end).count(),
        }

    def deltas(self):
        prev = self.previous()
        if not prev:
            return {}
        cur = self.kpis()
        return {
            key: _delta(cur.get(key), prev.get(key))
            for key in (
                'appointments', 'appointments_completed', 'consultations',
                'patients_new', 'revenue_billed', 'revenue_collected',
                'triage', 'no_show_rate',
            )
        }

    # ── Trend ───────────────────────────────────────────────────────
    def trend(self):
        from appointments.models import Appointment
        from billing.models import Invoice, Payment
        from consultations.models import Consultation
        from lab.models import LabOrder
        from patients.models import Patient

        days = self.trend_days
        start = self.today - timedelta(days=days - 1)

        appt_rows = (
            scope_to_site(Appointment.objects.filter(appointment_date__gte=start), self.site)
            .values('appointment_date').annotate(n=Count('id'))
        )
        consult_rows = (
            scope_to_site(Consultation.objects.filter(created_at__date__gte=start), self.site)
            .annotate(day=TruncDate('created_at')).values('day').annotate(n=Count('id'))
        )
        patient_rows = (
            _patient_qs(self.site, start)
            .annotate(day=TruncDate('created_at')).values('day').annotate(n=Count('id'))
        )
        invoice_rows = (
            scope_to_site(Invoice.objects.filter(created_at__date__gte=start), self.site)
            .annotate(day=TruncDate('created_at')).values('day')
            .annotate(total=Sum('total'), paid=Sum('amount_paid'))
        )
        payment_rows = (
            scope_to_site(
                Payment.objects.filter(paid_at__date__gte=start), self.site,
                field='invoice__clinic_site',
            )
            .annotate(day=TruncDate('paid_at')).values('day').annotate(total=Sum('amount'))
        )
        lab_rows = (
            scope_to_site(LabOrder.objects.filter(created_at__date__gte=start), self.site)
            .annotate(day=TruncDate('created_at')).values('day').annotate(n=Count('id'))
        )
        admission_rows = []
        try:
            from wards.models import Admission
            admission_rows = list(
                scope_to_site(
                    Admission.objects.filter(admission_date__date__gte=start), self.site,
                )
                .annotate(day=TruncDate('admission_date')).values('day')
                .annotate(n=Count('id'))
            )
        except Exception:  # noqa: BLE001 - wards are optional for a clinic
            pass

        return {
            'dates': [(start + timedelta(days=i)).isoformat() for i in range(days)],
            'appointments': _series(
                [(r['appointment_date'], r['n']) for r in appt_rows], days, start),
            'consultations': _series([(r['day'], r['n']) for r in consult_rows], days, start),
            'patients': _series([(r['day'], r['n']) for r in patient_rows], days, start),
            'revenue': _series(
                [(r['day'], _money(r['total'])) for r in invoice_rows], days, start),
            'collected': _series(
                [(r['day'], _money(r['total'])) for r in payment_rows], days, start),
            'lab': _series([(r['day'], r['n']) for r in lab_rows], days, start),
            'admissions': _series([(r['day'], r['n']) for r in admission_rows], days, start),
        }

    # ── Appointments ────────────────────────────────────────────────
    def appointments(self):
        qs = self._appointments(self.start_date)
        rows = list(qs.values('status').annotate(n=Count('id')).order_by('-n'))
        total = sum(r['n'] for r in rows) or 1
        return {
            'total': qs.count(),
            'by_status': [
                {'status': r['status'] or 'unknown', 'count': r['n'],
                 'pct': _pct(r['n'], total)}
                for r in rows
            ],
            'completed_rate': _pct(qs.filter(status='completed').count(), qs.count()),
            'avg_duration': round(
                _money(qs.aggregate(v=Coalesce(Sum('duration_minutes'), 0))['v'])
                / (qs.count() or 1), 1),
        }

    # ── Demand heatmap ──────────────────────────────────────────────
    def demand(self):
        """Weekday × hour grid — where the schedule actually fills up."""
        qs = self._appointments(self.start_date)
        matrix = [[0 for _ in HEAT_HOURS] for _ in WEEKDAYS]
        for appt_date, appt_time in qs.values_list('appointment_date', 'appointment_time'):
            if not appt_date or not appt_time:
                continue
            # Python weekday(): Mon=0 … Sun=6
            day_idx = appt_date.weekday()
            hour = appt_time.hour
            if 0 <= day_idx < 7 and hour in HEAT_HOURS:
                matrix[day_idx][HEAT_HOURS.index(hour)] += 1
        peak = {'day': '', 'hour': '', 'count': 0}
        if qs.exists():
            best_day = max(range(7), key=lambda i: sum(matrix[i]))
            best_hour = max(
                range(len(HEAT_HOURS)),
                key=lambda i: sum(matrix[d][i] for d in range(7)))
            peak = {
                'day': WEEKDAYS[best_day],
                'hour': f'{HEAT_HOURS[best_hour]:02d}:00',
                'count': max(
                    max(matrix[best_day]) if matrix[best_day] else 0,
                    sum(matrix[best_day]),
                ),
            }
        return {
            'days': WEEKDAYS,
            'hours': HEAT_HOURS,
            'matrix': matrix,
            'max': max((max(row) for row in matrix), default=0),
            'peak': peak,
        }

    # ── Funnel ──────────────────────────────────────────────────────
    def funnel(self):
        appts = self._appointments(self.start_date)
        stages = [
            ('booked', 'Appointments booked', appts.count(), 'mdi-calendar-blank'),
            ('checked_in', 'Checked in',
             appts.filter(status__in=['confirmed', 'in_progress', 'completed']).count(),
             'mdi-account-check'),
            ('triaged', 'Triaged', self._triage(self.start_date).count(), 'mdi-heart-pulse'),
            ('consulted', 'Consulted', self._consultations(self.start_date).count(),
             'mdi-stethoscope'),
            ('ordered', 'Lab / prescriptions',
             self._lab(self.start_date).count() + self._prescriptions(self.start_date).count(),
             'mdi-flask-outline'),
            ('billed', 'Invoiced', self._invoices(self.start_date).count(),
             'mdi-receipt-text'),
            ('paid', 'Paid', self._invoices(self.start_date).filter(
                status='paid').count(), 'mdi-cash-check'),
        ]
        top = max((s[2] for s in stages), default=0) or 1
        return [
            {'key': key, 'label': label, 'count': count, 'icon': icon,
             'pct': _pct(count, top)}
            for key, label, count, icon in stages
        ]

    # ── Departments ─────────────────────────────────────────────────
    def departments(self):
        from departments.models import Department

        appt_counts = {
            r['department_id']: r['n']
            for r in self._appointments(self.start_date)
            .exclude(department__isnull=True)
            .values('department_id').annotate(n=Count('id'))
        }
        consult_counts = {
            r['appointment__department_id']: r['n']
            for r in self._consultations(self.start_date)
            .exclude(appointment__isnull=True)
            .exclude(appointment__department__isnull=True)
            .values('appointment__department_id').annotate(n=Count('id'))
        }
        revenue_map = {}
        try:
            for r in (
                self._invoices(self.start_date)
                .exclude(consultation__isnull=True)
                .exclude(consultation__appointment__department__isnull=True)
                .values('consultation__appointment__department_id')
                .annotate(total=Sum('total'))
            ):
                revenue_map[r['consultation__appointment__department_id']] = _money(r['total'])
        except Exception:  # noqa: BLE001 - invoice→consultation links are optional
            revenue_map = {}

        out = []
        for dept in Department.objects.all().order_by('name'):
            out.append({
                'id': dept.id,
                'name': dept.name,
                'is_active': dept.is_active,
                'appointments': appt_counts.get(dept.id, 0),
                'consultations': consult_counts.get(dept.id, 0),
                'revenue': revenue_map.get(dept.id, 0.0),
            })
        total = sum(row['appointments'] for row in out) or 1
        for row in out:
            row['share'] = _pct(row['appointments'], total)
        out.sort(key=lambda d: (d['appointments'], d['revenue']), reverse=True)
        return out

    # ── Doctors ─────────────────────────────────────────────────────
    def doctors(self):
        consults = self._consultations(self.start_date)
        rows = list(
            consults.exclude(doctor__isnull=True)
            .values('doctor_id', 'doctor__first_name', 'doctor__last_name', 'doctor__email')
            .annotate(total=Count('id'),
                      signed=Count('id', filter=Q(status__in=['signed', 'locked'])))
            .order_by('-total')[:10]
        )

        revenue_map = {}
        try:
            for r in (
                self._invoices(self.start_date)
                .exclude(consultation__isnull=True)
                .exclude(consultation__doctor__isnull=True)
                .values('consultation__doctor_id').annotate(total=Sum('total'))
            ):
                revenue_map[r['consultation__doctor_id']] = _money(r['total'])
        except Exception:  # noqa: BLE001
            revenue_map = {}

        out = []
        for row in rows:
            name = (f"{row['doctor__first_name'] or ''} "
                    f"{row['doctor__last_name'] or ''}").strip() \
                or row['doctor__email'] or 'Clinician'
            total = row['total'] or 0
            out.append({
                'id': row['doctor_id'],
                'name': name,
                'email': row['doctor__email'] or '',
                'consultations': total,
                'signed': row['signed'] or 0,
                'completion': _pct(row['signed'] or 0, total),
                'revenue': revenue_map.get(row['doctor_id'], 0.0),
            })
        out.sort(key=lambda d: d['consultations'], reverse=True)
        return out

    # ── Revenue ─────────────────────────────────────────────────────
    def revenue(self):
        from billing.models import Invoice

        qs = self._invoices(self.start_date)
        agg = qs.aggregate(
            billed=Coalesce(Sum('total'), 0, output_field=DecimalField()),
            paid=Coalesce(Sum('amount_paid'), 0, output_field=DecimalField()),
        )
        billed = _money(agg['billed'])
        paid = _money(agg['paid'])
        outstanding = 0.0
        for total, amount_paid in qs.values_list('total', 'amount_paid'):
            outstanding += max(0.0, _money(total) - _money(amount_paid))

        status_rows = list(
            qs.values('status').annotate(n=Count('id'), amount=Sum('total')).order_by('-n')
        )
        total_n = sum(r['n'] for r in status_rows) or 1

        method_rows = []
        try:
            method_rows = list(
                self._payments(self.start_date)
                .values('method').annotate(n=Count('id'), amount=Sum('amount'))
                .order_by('-amount')
            )
        except Exception:  # noqa: BLE001
            method_rows = []
        method_total = sum(_money(r['amount']) for r in method_rows) or 1

        # Aging buckets on money still owed.
        buckets = [
            {'key': 'current', 'label': 'Current', 'amount': 0.0, 'count': 0},
            {'key': '30', 'label': '1–30 days', 'amount': 0.0, 'count': 0},
            {'key': '60', 'label': '31–60 days', 'amount': 0.0, 'count': 0},
            {'key': '90', 'label': '60+ days', 'amount': 0.0, 'count': 0},
        ]
        for created_at, total, amount_paid in qs.values_list(
                'created_at', 'total', 'amount_paid'):
            balance = _money(total) - _money(amount_paid)
            if balance <= 0 or not created_at:
                continue
            age = (self.today - created_at.date()).days
            idx = 0 if age <= 0 else 1 if age <= 30 else 2 if age <= 60 else 3
            buckets[idx]['amount'] += balance
            buckets[idx]['count'] += 1
        for b in buckets:
            b['amount'] = round(b['amount'], 2)

        # Top billed services from invoice line items.
        services = {}
        for items in qs.values_list('items', flat=True):
            if not items or not isinstance(items, (list, tuple)):
                continue
            for item in items:
                if not isinstance(item, dict):
                    continue
                desc = str(item.get('description') or item.get('name') or 'Uncategorised').strip()
                try:
                    amount = float(item.get('total') or 0)
                except (TypeError, ValueError):
                    amount = 0.0
                if not amount:
                    try:
                        amount = float(item.get('quantity') or 0) * float(
                            item.get('unit_price') or 0)
                    except (TypeError, ValueError):
                        amount = 0.0
                services[desc] = services.get(desc, 0.0) + amount
        top_services = [
            {'name': name, 'amount': round(amount, 2)}
            for name, amount in sorted(services.items(), key=lambda kv: kv[1], reverse=True)[:8]
        ]

        # Six-month history for the revenue bars (independent of ?range=).
        monthly = []
        try:
            first = (self.today.replace(day=1) - timedelta(days=150)).replace(day=1)
            month_rows = (
                scope_to_site(
                    Invoice.objects.filter(created_at__date__gte=first), self.site,
                )
                .annotate(day=TruncDate('created_at')).values('day')
                .annotate(billed=Sum('total'), paid=Sum('amount_paid'), n=Count('id'))
            )
            buckets_by_month = {}
            for r in month_rows:
                key = _month_key(r['day'])
                entry = buckets_by_month.setdefault(
                    key, {'month': key, 'label': _month_label(r['day']),
                          'billed': 0.0, 'collected': 0.0, 'invoices': 0})
                entry['billed'] += _money(r['billed'])
                entry['collected'] += _money(r['paid'])
                entry['invoices'] += r['n']
            cursor = first
            for _ in range(6):
                key = _month_key(cursor)
                entry = buckets_by_month.get(key) or {
                    'month': key, 'label': _month_label(cursor),
                    'billed': 0.0, 'collected': 0.0, 'invoices': 0}
                monthly.append(entry)
                cursor = (cursor.replace(day=28) + timedelta(days=7)).replace(day=1)
        except Exception:  # noqa: BLE001
            monthly = []

        for entry in monthly:
            entry['billed'] = round(entry['billed'], 2)
            entry['collected'] = round(entry['collected'], 2)

        return {
            'billed': billed,
            'collected_on_invoices': paid,
            'outstanding': round(outstanding, 2),
            'collection_rate': _pct(paid, billed),
            'invoice_count': total_n,
            'avg_ticket': round(billed / total_n, 2) if total_n else 0.0,
            'by_status': [
                {'status': r['status'] or 'unknown', 'count': r['n'],
                 'amount': _money(r['amount']), 'pct': _pct(r['n'], total_n)}
                for r in status_rows
            ],
            'by_method': [
                {'method': r['method'] or 'unknown', 'count': r['n'],
                 'amount': _money(r['amount']), 'pct': _pct(_money(r['amount']), method_total)}
                for r in method_rows
            ],
            'aging': buckets,
            'top_services': top_services,
            'monthly': monthly,
        }

    # ── Patients ────────────────────────────────────────────────────
    def patients(self):
        qs = _patient_qs(self.site)
        total = qs.count() or 1

        gender_counts = {}
        age_counts = {'0-17': 0, '18-29': 0, '30-44': 0, '45-59': 0, '60+': 0}
        payer_counts = {}
        returning = 0
        for p in qs.only('gender', 'date_of_birth', 'insurance_provider'):
            g = (p.gender or 'unknown').lower()
            gender_counts[g] = gender_counts.get(g, 0) + 1

            if p.date_of_birth:
                age = self.today.year - p.date_of_birth.year - (
                    (self.today.month, self.today.day) <
                    (p.date_of_birth.month, p.date_of_birth.day))
                key = ('0-17' if age < 18 else '18-29' if age < 30 else
                       '30-44' if age < 45 else '45-59' if age < 60 else '60+')
                age_counts[key] += 1

            payer = (p.insurance_provider or '').strip() or 'Self-pay'
            payer_counts[payer] = payer_counts.get(payer, 0) + 1

        try:
            returning = (
                _patient_qs(self.site).annotate(appt_count=Count('appointments'))
                .filter(appt_count__gt=1).count()
            )
        except Exception:  # noqa: BLE001
            returning = 0

        gender = [
            {'key': key, 'label': key.title(), 'count': count,
             'pct': _pct(count, total)}
            for key, count in sorted(gender_counts.items(), key=lambda kv: kv[1], reverse=True)
        ]
        ages = [
            {'band': band, 'count': count, 'pct': _pct(count, total)}
            for band, count in age_counts.items()
        ]
        payers = [
            {'provider': name, 'count': count, 'pct': _pct(count, total)}
            for name, count in sorted(
                payer_counts.items(), key=lambda kv: kv[1], reverse=True)[:6]
        ]

        new_count = qs.count() if self.start_date is None else \
            qs.filter(created_at__date__gte=self.start_date).count()

        return {
            'total': qs.count(),
            'new_in_range': new_count,
            'returning': returning,
            'returning_pct': _pct(returning, total),
            'gender': gender,
            'ages': ages,
            'payers': payers,
        }

    # ── Triage ──────────────────────────────────────────────────────
    def triage(self):
        qs = self._triage(self.start_date)
        total = qs.count() or 1
        acuity = []
        for row in qs.values('esi_level').annotate(n=Count('id')).order_by('esi_level'):
            level = row['esi_level']
            acuity.append({
                'level': level,
                'label': f'ESI {level}' if level else 'Unassigned',
                'count': row['n'],
                'pct': _pct(row['n'], total),
            })
        return {
            'total': qs.count(),
            'open': qs.filter(status='draft').count(),
            'completed': qs.filter(status='completed').count(),
            'critical': qs.filter(esi_level__in=[1, 2]).count(),
            'by_acuity': acuity,
            'by_arrival': [
                {'mode': r['arrival_mode'] or 'unknown', 'count': r['n']}
                for r in qs.values('arrival_mode').annotate(n=Count('id')).order_by('-n')
            ],
        }

    # ── Lab ─────────────────────────────────────────────────────────
    def lab(self):
        qs = self._lab(self.start_date)
        total = qs.count() or 1
        abnormal = 0
        results = 0
        try:
            from lab.models import LabResult
            results_qs = _range_qs(
                scope_to_site(LabResult.objects.all(), self.site, field='order__clinic_site'),
                'result_date', self.start_date)
            results = results_qs.count()
            abnormal = results_qs.filter(is_abnormal=True).count()
        except Exception:  # noqa: BLE001
            pass

        test_counts = {}
        for order in qs.prefetch_related('tests'):
            for test in order.tests.all():
                test_counts[test.name] = test_counts.get(test.name, 0) + 1
        top_tests = [
            {'name': name, 'count': count}
            for name, count in sorted(test_counts.items(), key=lambda kv: kv[1], reverse=True)[:6]
        ]

        return {
            'total': qs.count(),
            'pending': qs.filter(status__in=[
                'pending', 'sample_collected', 'processing']).count(),
            'completed': qs.filter(status='completed').count(),
            'completion_rate': _pct(qs.filter(status='completed').count(), total),
            'urgent': qs.filter(priority__in=['urgent', 'stat', 'emergency']).count(),
            'home_collection': qs.filter(is_home_collection=True).count(),
            'results': results,
            'abnormal': abnormal,
            'abnormal_rate': _pct(abnormal, results),
            'by_status': [
                {'status': r['status'] or 'unknown', 'count': r['n'],
                 'pct': _pct(r['n'], total)}
                for r in qs.values('status').annotate(n=Count('id')).order_by('-n')
            ],
            'by_priority': [
                {'priority': r['priority'] or 'routine', 'count': r['n']}
                for r in qs.values('priority').annotate(n=Count('id')).order_by('-n')
            ],
            'top_tests': top_tests,
        }

    # ── Pharmacy ────────────────────────────────────────────────────
    def pharmacy(self):
        qs = self._prescriptions(self.start_date)
        total = qs.count() or 1
        meds = {}
        items = 0
        try:
            from prescriptions.models import PrescriptionItem
            item_qs = scope_to_site(
                PrescriptionItem.objects.all(), self.site,
                field='prescription__clinic_site',
            )
            if self.start_date is not None:
                item_qs = item_qs.filter(
                    prescription__created_at__date__gte=self.start_date)
            items = item_qs.count()
            for row in item_qs.values('medication_name').annotate(n=Count('id')).order_by('-n')[:8]:
                name = row['medication_name'] or 'Unnamed'
                meds[name] = row['n']
        except Exception:  # noqa: BLE001
            items = 0
        return {
            'total': qs.count(),
            'open': qs.exclude(status__in=['dispensed', 'cancelled']).count(),
            'dispensed': qs.filter(status='dispensed').count(),
            'dispense_rate': _pct(qs.filter(status='dispensed').count(), total),
            'items': items,
            'avg_items': round(items / (qs.count() or 1), 1),
            'by_status': [
                {'status': r['status'] or 'unknown', 'count': r['n'],
                 'pct': _pct(r['n'], total)}
                for r in qs.values('status').annotate(n=Count('id')).order_by('-n')
            ],
            'top_medications': [
                {'name': name, 'count': count} for name, count in meds.items()
            ],
        }

    # ── Wards ───────────────────────────────────────────────────────
    def wards(self):
        from wards.models import Admission, Bed

        total = Bed.objects.count()
        if not total:
            return {'available': False}

        occupied = Bed.objects.filter(status='occupied').count()
        by_ward = []
        for row in (
            Bed.objects.values('ward__name')
            .annotate(total=Count('id'),
                      occupied=Count('id', filter=Q(status='occupied')))
            .order_by('ward__name')
        ):
            beds = row['total'] or 0
            occ = row['occupied'] or 0
            by_ward.append({
                'name': row['ward__name'] or 'Ward',
                'beds': beds,
                'occupied': occ,
                'occupancy_pct': _pct(occ, beds),
            })

        admissions = _range_qs(
            scope_to_site(Admission.objects.all(), self.site),
            'admission_date', self.start_date,
        )
        discharged = admissions.filter(status='discharged')
        stays = []
        for admitted, left in discharged.values_list('admission_date', 'discharge_date'):
            if admitted and left:
                stays.append(max(0.0, (left - admitted).total_seconds() / 86400))
        return {
            'available': True,
            'beds_total': total,
            'beds_occupied': occupied,
            'beds_available': max(0, total - occupied),
            'occupancy_pct': _pct(occupied, total),
            'admissions': admissions.count(),
            'discharges': discharged.count(),
            'active': scope_to_site(
                Admission.objects.filter(status='active'), self.site).count(),
            'avg_stay_days': round(sum(stays) / len(stays), 1) if stays else 0.0,
            'by_ward': by_ward,
        }

    # ── Insight strip ───────────────────────────────────────────────
    def insights(self, kpis, previous, deltas, revenue):
        """Short, data-derived observations — the 'so what' above the charts."""
        out = []

        rate = kpis.get('collection_rate') or 0
        if rate >= 85:
            out.append({
                'tone': 'good', 'icon': 'mdi-cash-check',
                'title': 'Collections are healthy',
                'detail': f'{rate}% of billed value has been collected in this window.',
            })
        elif rate >= 60:
            out.append({
                'tone': 'warn', 'icon': 'mdi-cash-clock',
                'title': 'Collections need a push',
                'detail': f"{rate}% collected · KES {_money(revenue.get('outstanding')):,.0f} still outstanding.",
            })
        else:
            out.append({
                'tone': 'bad', 'icon': 'mdi-alert-circle-outline',
                'title': 'Revenue is leaking',
                'detail': f'Only {rate}% collected. Review open invoices and follow up overdue balances.',
            })

        no_show = kpis.get('no_show_rate') or 0
        if no_show >= 15:
            out.append({
                'tone': 'bad', 'icon': 'mdi-account-off',
                'title': 'No-shows are eating capacity',
                'detail': f'{no_show}% of appointments were missed. Consider reminders 24h before.',
            })
        elif no_show > 0:
            out.append({
                'tone': 'warn', 'icon': 'mdi-calendar-alert',
                'title': 'A few missed visits',
                'detail': f'{no_show}% no-show rate — under the 15% watch line.',
            })

        growth = deltas.get('patients_new')
        if growth is not None:
            direction = 'up' if growth >= 0 else 'down'
            out.append({
                'tone': 'good' if growth >= 0 else 'warn',
                'icon': 'mdi-account-plus-outline',
                'title': f'New registrations {direction} {abs(growth):.1f}%',
                'detail': f'{kpis.get("patients_new", 0)} new patients joined in this window.',
            })

        lab_pending = kpis.get('lab_pending') or 0
        if lab_pending:
            out.append({
                'tone': 'warn' if lab_pending < 10 else 'bad',
                'icon': 'mdi-flask-outline',
                'title': f'{lab_pending} lab order{"s" if lab_pending != 1 else ""} pending',
                'detail': 'Clear the worklist to keep turnaround times inside target.',
            })

        rx_open = kpis.get('rx_open') or 0
        if rx_open:
            out.append({
                'tone': 'warn', 'icon': 'mdi-pill',
                'title': f'{rx_open} prescription{"s" if rx_open != 1 else ""} open',
                'detail': 'Dispense or hand off to the pharmacy queue.',
            })

        if kpis.get('active_clinicians'):
            out.append({
                'tone': 'good', 'icon': 'mdi-stethoscope',
                'title': f'{kpis["active_clinicians"]} clinicians active',
                'detail': f'{kpis.get("consultations", 0)} consultations recorded in this window.',
            })

        return out[:5]
