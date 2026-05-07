"""
Usage-billing API.

Tenant-facing:
  GET  /api/usage-billing/dashboard/        – current month usage + projection

Super-admin:
  GET  /api/usage-billing/admin/rates/      – list rates
  POST /api/usage-billing/admin/rates/      – create / update billing rate
  GET  /api/usage-billing/admin/usage/      – per-tenant current month usage
  GET  /api/usage-billing/admin/usage/<id>/ – daily breakdown for a tenant
  GET  /api/usage-billing/admin/bills/      – monthly bills
  POST /api/usage-billing/admin/generate-bills/ – generate bills for a month
"""
import calendar
from datetime import date, timedelta
from decimal import Decimal

from django.db import connection
from django.db.models import Count, Sum
from django.utils import timezone
from django_tenants.utils import schema_context
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from superadmin.permissions import IsSuperAdmin
from tenants.models import Tenant

from .models import BillingRate, DailyUsage, DoctorCommissionRate, MonthlyBill
from .serializers import (
    BillingRateSerializer,
    DailyUsageSerializer,
    DoctorCommissionRateSerializer,
    MonthlyBillSerializer,
)


# ── helpers ───────────────────────────────────────────────────────────────────

def _month_bounds(year: int, month: int):
    first = date(year, month, 1)
    last = date(year, month, calendar.monthrange(year, month)[1])
    return first, last


def _aggregate(tenant, start, end):
    qs = DailyUsage.objects.filter(tenant=tenant, date__gte=start, date__lte=end)
    total = qs.aggregate(total=Sum("request_count"))["total"] or 0
    daily = list(qs.order_by("date").values("date", "request_count"))
    return total, daily


def _project_month_total(total_so_far: int, day: date) -> int:
    days_in_month = calendar.monthrange(day.year, day.month)[1]
    days_elapsed = day.day
    if days_elapsed <= 0:
        return total_so_far
    avg = total_so_far / days_elapsed
    return int(round(avg * days_in_month))


# ── tenant dashboard ──────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def tenant_dashboard(request):
    """Usage stats for the current authenticated tenant."""
    tenant = getattr(request, "tenant", None)
    if tenant is None or getattr(tenant, "schema_name", "public") == "public":
        return Response(
            {"detail": "No tenant context for this request."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    today = timezone.localdate()
    month_start, month_end = _month_bounds(today.year, today.month)
    total, daily = _aggregate(tenant, month_start, month_end)

    rate = BillingRate.current()
    cost_so_far = rate.cost_for(total)
    projected_requests = _project_month_total(total, today)
    projected_cost = rate.cost_for(projected_requests)

    # last 30 days for charting (may include previous month)
    last_30_start = today - timedelta(days=29)
    last_30_total, last_30 = _aggregate(tenant, last_30_start, today)

    recent_bills = MonthlyBill.objects.filter(tenant=tenant).order_by("-year", "-month")[:6]

    # ── Extra analytics ────────────────────────────────────────────────
    # Previous month comparison
    if today.month == 1:
        prev_year, prev_month = today.year - 1, 12
    else:
        prev_year, prev_month = today.year, today.month - 1
    prev_start, prev_end = _month_bounds(prev_year, prev_month)
    prev_total, _ = _aggregate(tenant, prev_start, prev_end)

    # Same elapsed days in previous month for fair MoM comparison
    cmp_end = min(prev_start.replace(day=today.day) if today.day <= calendar.monthrange(prev_year, prev_month)[1]
                  else prev_end, prev_end)
    prev_same_period_total, _ = _aggregate(tenant, prev_start, cmp_end)
    if prev_same_period_total > 0:
        mom_change_pct = round(((total - prev_same_period_total) / prev_same_period_total) * 100, 2)
    else:
        mom_change_pct = None

    # Trailing-7-day average and today vs yesterday
    week_start = today - timedelta(days=6)
    week_total, week_daily = _aggregate(tenant, week_start, today)
    avg_7d = round(week_total / 7, 2) if week_total else 0
    today_count = next((d["request_count"] for d in week_daily if d["date"] == today), 0)
    yesterday = today - timedelta(days=1)
    yesterday_count = next((d["request_count"] for d in week_daily if d["date"] == yesterday), 0)

    # Peak day in current month
    peak_day = max(daily, key=lambda d: d["request_count"], default=None)

    # Days remaining + average needed to stay under arbitrary budgets
    days_in_month = calendar.monthrange(today.year, today.month)[1]
    days_remaining = days_in_month - today.day
    daily_avg_so_far = round(total / max(today.day, 1), 2)

    # Weekday distribution (Mon=0 ... Sun=6) over last 30 days
    weekday_counts = [0] * 7
    weekday_days = [0] * 7
    for d in last_30:
        wd = d["date"].weekday() if hasattr(d["date"], "weekday") else date.fromisoformat(str(d["date"])).weekday()
        weekday_counts[wd] += d["request_count"]
        weekday_days[wd] += 1
    weekday_breakdown = [
        {
            "weekday": i,
            "label": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i],
            "total": weekday_counts[i],
            "average": round(weekday_counts[i] / weekday_days[i], 2) if weekday_days[i] else 0,
        }
        for i in range(7)
    ]

    # Last 6 months series (totals + cost) for trend chart
    monthly_history = []
    cursor_y, cursor_m = today.year, today.month
    for _ in range(6):
        ms, me = _month_bounds(cursor_y, cursor_m)
        m_total, _ = _aggregate(tenant, ms, me)
        monthly_history.append(
            {
                "year": cursor_y,
                "month": cursor_m,
                "label": f"{cursor_y}-{cursor_m:02d}",
                "total_requests": m_total,
                "cost": str(rate.cost_for(m_total)),
            }
        )
        if cursor_m == 1:
            cursor_y, cursor_m = cursor_y - 1, 12
        else:
            cursor_m -= 1
    monthly_history.reverse()

    return Response(
        {
            "tenant": {
                "id": tenant.id,
                "name": tenant.name,
                "schema": tenant.schema_name,
                "type": tenant.type,
            },
            "current_month": {
                "year": today.year,
                "month": today.month,
                "start": month_start,
                "end": month_end,
                "total_requests": total,
                "cost_so_far": str(cost_so_far),
                "projected_requests": projected_requests,
                "projected_cost": str(projected_cost),
                "days_elapsed": today.day,
                "days_remaining": days_remaining,
                "daily_average_so_far": daily_avg_so_far,
                "peak_day": peak_day,
            },
            "comparison": {
                "previous_month": {
                    "year": prev_year,
                    "month": prev_month,
                    "total_requests": prev_total,
                    "cost": str(rate.cost_for(prev_total)),
                },
                "previous_same_period_total": prev_same_period_total,
                "mom_change_pct": mom_change_pct,
                "today_requests": today_count,
                "yesterday_requests": yesterday_count,
                "trailing_7d_total": week_total,
                "trailing_7d_average": avg_7d,
            },
            "rate": BillingRateSerializer(rate).data,
            "daily_current_month": daily,
            "daily_last_30_days": last_30,
            "weekday_breakdown": weekday_breakdown,
            "monthly_history": monthly_history,
            "recent_bills": MonthlyBillSerializer(recent_bills, many=True).data,
        }
    )


# ── tenant range query ────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def tenant_range_usage(request):
    """Aggregated usage for an arbitrary date range.

    Query params:
      preset = today | yesterday | last_7_days | last_14_days | last_30_days |
               this_month | last_month | this_year | custom
      start  = YYYY-MM-DD (used when preset=custom or omitted)
      end    = YYYY-MM-DD (used when preset=custom or omitted)
    """
    tenant = getattr(request, "tenant", None)
    if tenant is None or getattr(tenant, "schema_name", "public") == "public":
        return Response(
            {"detail": "No tenant context for this request."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    today = timezone.localdate()
    preset = (request.GET.get("preset") or "").strip().lower()
    start_param = request.GET.get("start")
    end_param = request.GET.get("end")

    def parse(d):
        try:
            return date.fromisoformat(d)
        except (TypeError, ValueError):
            return None

    start = end = None
    if preset == "today":
        start = end = today
    elif preset == "yesterday":
        start = end = today - timedelta(days=1)
    elif preset == "last_7_days":
        start, end = today - timedelta(days=6), today
    elif preset == "last_14_days":
        start, end = today - timedelta(days=13), today
    elif preset == "last_30_days":
        start, end = today - timedelta(days=29), today
    elif preset == "this_month":
        start, end = _month_bounds(today.year, today.month)
        end = today
    elif preset == "last_month":
        if today.month == 1:
            ly, lm = today.year - 1, 12
        else:
            ly, lm = today.year, today.month - 1
        start, end = _month_bounds(ly, lm)
    elif preset == "this_year":
        start, end = date(today.year, 1, 1), today
    else:
        start = parse(start_param)
        end = parse(end_param)

    if not start or not end:
        return Response(
            {"detail": "Provide a valid preset or start/end (YYYY-MM-DD)."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if start > end:
        start, end = end, start

    total, daily = _aggregate(tenant, start, end)
    rate = BillingRate.current()
    span_days = (end - start).days + 1
    avg = round(total / span_days, 2) if span_days else 0
    peak = max(daily, key=lambda d: d["request_count"], default=None)

    return Response(
        {
            "preset": preset or "custom",
            "start": start,
            "end": end,
            "days": span_days,
            "total_requests": total,
            "daily_average": avg,
            "peak_day": peak,
            "cost": str(rate.cost_for(total)),
            "rate": BillingRateSerializer(rate).data,
            "daily": daily,
        }
    )


# ── super-admin: rates ────────────────────────────────────────────────────────

class RateListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = BillingRateSerializer
    queryset = BillingRate.objects.all()

    def perform_create(self, serializer):
        # New rates supersede previous ones unless explicitly kept active.
        if serializer.validated_data.get("is_active", True):
            BillingRate.objects.filter(is_active=True).update(is_active=False)
        serializer.save(created_by=self.request.user, is_active=True)


class RateDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = BillingRateSerializer
    queryset = BillingRate.objects.all()


# ── super-admin: usage ────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def admin_usage_overview(request):
    """Current-month requests for every tenant, plus projected cost."""
    today = timezone.localdate()
    month_start, month_end = _month_bounds(today.year, today.month)
    rate = BillingRate.current()

    rows = []
    grand_total = 0
    grand_projected_cost = Decimal("0")
    for tenant in Tenant.objects.exclude(schema_name="public").order_by("name"):
        total, _ = _aggregate(tenant, month_start, month_end)
        projected_requests = _project_month_total(total, today)
        projected_cost = rate.cost_for(projected_requests)
        grand_total += total
        grand_projected_cost += projected_cost
        rows.append(
            {
                "tenant_id": tenant.id,
                "tenant_name": tenant.name,
                "tenant_schema": tenant.schema_name,
                "tenant_type": tenant.type,
                "is_active": tenant.is_active,
                "requests_so_far": total,
                "cost_so_far": str(rate.cost_for(total)),
                "projected_requests": projected_requests,
                "projected_cost": str(projected_cost),
            }
        )

    return Response(
        {
            "period": {"year": today.year, "month": today.month, "start": month_start, "end": month_end},
            "rate": BillingRateSerializer(rate).data,
            "totals": {
                "tenants": len(rows),
                "requests_so_far": grand_total,
                "projected_cost": str(grand_projected_cost),
            },
            "tenants": rows,
        }
    )


@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def admin_tenant_usage_detail(request, tenant_id):
    try:
        tenant = Tenant.objects.exclude(schema_name="public").get(pk=tenant_id)
    except Tenant.DoesNotExist:
        return Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)

    today = timezone.localdate()
    month_start, month_end = _month_bounds(today.year, today.month)
    total, daily = _aggregate(tenant, month_start, month_end)
    last_90_start = today - timedelta(days=89)
    _, last_90 = _aggregate(tenant, last_90_start, today)

    rate = BillingRate.current()
    bills = MonthlyBill.objects.filter(tenant=tenant).order_by("-year", "-month")

    return Response(
        {
            "tenant": {
                "id": tenant.id,
                "name": tenant.name,
                "schema": tenant.schema_name,
                "type": tenant.type,
                "is_active": tenant.is_active,
            },
            "current_month": {
                "year": today.year,
                "month": today.month,
                "total_requests": total,
                "cost_so_far": str(rate.cost_for(total)),
            },
            "rate": BillingRateSerializer(rate).data,
            "daily_current_month": daily,
            "daily_last_90_days": last_90,
            "bills": MonthlyBillSerializer(bills, many=True).data,
        }
    )


# ── super-admin: monthly bills ────────────────────────────────────────────────

class BillListView(generics.ListAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = MonthlyBillSerializer

    def get_queryset(self):
        qs = MonthlyBill.objects.select_related("tenant").all()
        params = self.request.query_params
        if params.get("tenant"):
            qs = qs.filter(tenant_id=params["tenant"])
        if params.get("year"):
            qs = qs.filter(year=params["year"])
        if params.get("month"):
            qs = qs.filter(month=params["month"])
        if params.get("status"):
            qs = qs.filter(status=params["status"])
        return qs


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def generate_bills(request):
    """
    Generate monthly bills for every tenant for a given (year, month).
    Defaults to the previous calendar month.
    Existing bills for the period are refreshed (unless already PAID).
    """
    today = timezone.localdate()
    if today.month == 1:
        default_year, default_month = today.year - 1, 12
    else:
        default_year, default_month = today.year, today.month - 1

    try:
        year = int(request.data.get("year", default_year))
        month = int(request.data.get("month", default_month))
    except (TypeError, ValueError):
        return Response({"detail": "Invalid year/month."}, status=status.HTTP_400_BAD_REQUEST)

    if not (1 <= month <= 12):
        return Response({"detail": "month must be 1-12."}, status=status.HTTP_400_BAD_REQUEST)

    start, end = _month_bounds(year, month)
    rate = BillingRate.current()

    created, updated, skipped = 0, 0, 0
    out = []
    for tenant in Tenant.objects.exclude(schema_name="public"):
        total, _ = _aggregate(tenant, start, end)
        amount = rate.cost_for(total)
        bill, was_created = MonthlyBill.objects.get_or_create(
            tenant=tenant,
            year=year,
            month=month,
            defaults={
                "total_requests": total,
                "requests_per_unit": rate.requests_per_unit,
                "unit_cost": rate.unit_cost,
                "amount": amount,
                "currency": rate.currency,
                "status": MonthlyBill.Status.ISSUED,
            },
        )
        if was_created:
            created += 1
        elif bill.status == MonthlyBill.Status.PAID:
            skipped += 1
        else:
            bill.total_requests = total
            bill.requests_per_unit = rate.requests_per_unit
            bill.unit_cost = rate.unit_cost
            bill.amount = amount
            bill.currency = rate.currency
            bill.status = MonthlyBill.Status.ISSUED
            bill.save()
            updated += 1
        out.append(MonthlyBillSerializer(bill).data)

    return Response(
        {
            "period": {"year": year, "month": month},
            "created": created,
            "updated": updated,
            "skipped_paid": skipped,
            "bills": out,
        },
        status=status.HTTP_200_OK,
    )


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def mark_bill_paid(request, pk):
    try:
        bill = MonthlyBill.objects.get(pk=pk)
    except MonthlyBill.DoesNotExist:
        return Response({"detail": "Bill not found."}, status=status.HTTP_404_NOT_FOUND)
    bill.status = MonthlyBill.Status.PAID
    bill.paid_at = timezone.now()
    bill.save(update_fields=["status", "paid_at"])
    return Response(MonthlyBillSerializer(bill).data)


# ── doctor commission billing ────────────────────────────────────────────────
#
# Doctors are billed 20% (configurable) of their consultation fees.
# Patients use the system free of charge (the request middleware already
# skips them).

def _doctor_consultation_stats(doctor_user, start, end, fee):
    """Aggregate one doctor's consultations in the *current* tenant schema."""
    from consultations.models import Consultation

    qs = Consultation.objects.filter(
        doctor=doctor_user,
        created_at__date__gte=start,
        created_at__date__lte=end,
    )
    count = qs.count()
    fees_total = (Decimal(fee) * count).quantize(Decimal("0.01"))
    return count, fees_total


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def doctor_dashboard(request):
    """Commission stats for the current authenticated doctor."""
    user = request.user
    if getattr(user, "role", None) not in ("doctor", "clinical_officer", "dentist"):
        return Response(
            {"detail": "Only doctors can view this dashboard."},
            status=status.HTTP_403_FORBIDDEN,
        )

    # Pull the doctor profile (lives in public schema)
    with schema_context("public"):
        from doctors.models import DoctorProfile
        try:
            profile = DoctorProfile.objects.get(user=user)
        except DoctorProfile.DoesNotExist:
            return Response(
                {"detail": "No doctor profile found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        fee = profile.consultation_fee or Decimal("0")
        commission_rate = DoctorCommissionRate.current()

    today = timezone.localdate()
    month_start, month_end = _month_bounds(today.year, today.month)
    count_mtd, fees_mtd = _doctor_consultation_stats(user, month_start, month_end, fee)
    commission_mtd = commission_rate.commission_for(fees_mtd)

    # Previous month
    if today.month == 1:
        py, pm = today.year - 1, 12
    else:
        py, pm = today.year, today.month - 1
    prev_start, prev_end = _month_bounds(py, pm)
    count_prev, fees_prev = _doctor_consultation_stats(user, prev_start, prev_end, fee)
    commission_prev = commission_rate.commission_for(fees_prev)

    # Last 6 months series
    history = []
    cy, cm = today.year, today.month
    for _ in range(6):
        ms, me = _month_bounds(cy, cm)
        cnt, ftot = _doctor_consultation_stats(user, ms, me, fee)
        history.append(
            {
                "year": cy,
                "month": cm,
                "label": f"{cy}-{cm:02d}",
                "consultations": cnt,
                "fees_total": str(ftot),
                "commission": str(commission_rate.commission_for(ftot)),
            }
        )
        if cm == 1:
            cy, cm = cy - 1, 12
        else:
            cm -= 1
    history.reverse()

    return Response(
        {
            "doctor": {
                "id": user.id,
                "email": user.email,
                "consultation_fee": str(fee),
                "currency": commission_rate.currency,
            },
            "commission_rate": DoctorCommissionRateSerializer(commission_rate).data,
            "current_month": {
                "year": today.year,
                "month": today.month,
                "consultations": count_mtd,
                "fees_total": str(fees_mtd),
                "commission_owed": str(commission_mtd),
            },
            "previous_month": {
                "year": py,
                "month": pm,
                "consultations": count_prev,
                "fees_total": str(fees_prev),
                "commission_owed": str(commission_prev),
            },
            "monthly_history": history,
        }
    )


# ── super-admin: doctor commission rate ──────────────────────────────────────

class DoctorRateListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = DoctorCommissionRateSerializer
    queryset = DoctorCommissionRate.objects.all()

    def perform_create(self, serializer):
        if serializer.validated_data.get("is_active", True):
            DoctorCommissionRate.objects.filter(is_active=True).update(is_active=False)
        serializer.save(created_by=self.request.user, is_active=True)


class DoctorRateDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = DoctorCommissionRateSerializer
    queryset = DoctorCommissionRate.objects.all()


@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def admin_doctor_commission_overview(request):
    """Cross-tenant doctor commission summary for the current month."""
    today = timezone.localdate()
    month_start, month_end = _month_bounds(today.year, today.month)
    commission_rate = DoctorCommissionRate.current()

    # Load all doctor profiles from public schema
    from doctors.models import DoctorProfile
    profiles = list(
        DoctorProfile.objects.select_related("user", "hospital").all()
    )
    fee_by_user = {p.user_id: (p.consultation_fee or Decimal("0")) for p in profiles}
    profile_by_user = {p.user_id: p for p in profiles}

    # Aggregate consultations across every tenant schema
    counts = {uid: 0 for uid in fee_by_user}
    for tenant in Tenant.objects.exclude(schema_name="public"):
        try:
            with schema_context(tenant.schema_name):
                from consultations.models import Consultation
                qs = (
                    Consultation.objects.filter(
                        created_at__date__gte=month_start,
                        created_at__date__lte=month_end,
                    )
                    .values("doctor_id")
                    .annotate(c=Count("id"))
                )
                for row in qs:
                    if row["doctor_id"] in counts:
                        counts[row["doctor_id"]] += row["c"]
        except Exception:
            continue

    rows = []
    grand_consultations = 0
    grand_commission = Decimal("0")
    for uid, count in counts.items():
        if count == 0:
            continue
        fee = fee_by_user[uid]
        fees_total = (Decimal(fee) * count).quantize(Decimal("0.01"))
        commission = commission_rate.commission_for(fees_total)
        prof = profile_by_user[uid]
        rows.append(
            {
                "doctor_id": uid,
                "doctor_name": prof.user.full_name if hasattr(prof.user, "full_name") else prof.user.email,
                "doctor_email": prof.user.email,
                "specialization": prof.specialization,
                "hospital": prof.hospital.name if prof.hospital else None,
                "consultation_fee": str(fee),
                "consultations": count,
                "fees_total": str(fees_total),
                "commission_owed": str(commission),
            }
        )
        grand_consultations += count
        grand_commission += commission

    rows.sort(key=lambda r: Decimal(r["commission_owed"]), reverse=True)

    return Response(
        {
            "period": {"year": today.year, "month": today.month, "start": month_start, "end": month_end},
            "commission_rate": DoctorCommissionRateSerializer(commission_rate).data,
            "totals": {
                "doctors_billable": len(rows),
                "consultations": grand_consultations,
                "commission_owed": str(grand_commission),
            },
            "doctors": rows,
        }
    )
