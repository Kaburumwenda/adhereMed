"""
Referral system API views.
All endpoints live under /api/usage-billing/referral/…
"""
from datetime import date, timedelta
from decimal import Decimal

from django.db import connection
from django.db.models import Count, Sum
from django.db.models.functions import TruncDate
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from tenants.models import Tenant

from .referral_models import CoinTransaction, Referral, ReferralProfile
from .referral_serializers import (
    CoinTransactionSerializer,
    ReferralProfileSerializer,
    ReferralSerializer,
)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def referral_dashboard(request):
    """Return the calling tenant's referral profile, referral list, and recent transactions."""
    tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
    if not tenant or getattr(tenant, "schema_name", None) == "public":
        return Response({"detail": "No tenant context."}, status=400)

    profile, _ = ReferralProfile.objects.get_or_create(tenant=tenant)
    referrals = Referral.objects.filter(referrer=tenant).select_related("referred")
    transactions = CoinTransaction.objects.filter(profile=profile)[:50]

    return Response({
        "profile": ReferralProfileSerializer(profile).data,
        "referrals": ReferralSerializer(referrals, many=True).data,
        "transactions": CoinTransactionSerializer(transactions, many=True).data,
        "referral_link": f"https://adheremed.com/register-facility?ref={profile.referral_code}",
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def referral_transactions(request):
    """Paginated transaction history for the calling tenant."""
    tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
    if not tenant or getattr(tenant, "schema_name", None) == "public":
        return Response({"detail": "No tenant context."}, status=400)

    profile, _ = ReferralProfile.objects.get_or_create(tenant=tenant)
    transactions = CoinTransaction.objects.filter(profile=profile)
    return Response(CoinTransactionSerializer(transactions, many=True).data)


@api_view(["GET"])
@permission_classes([AllowAny])
def validate_referral_code(request, code):
    """Check whether a referral code is valid. Used by the registration form."""
    try:
        profile = ReferralProfile.objects.select_related("tenant").get(referral_code=code.upper())
        return Response({
            "valid": True,
            "referrer_name": profile.tenant.name,
        })
    except ReferralProfile.DoesNotExist:
        return Response({"valid": False, "referrer_name": None})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def referral_stats(request):
    """Quick stats for the referral card widget."""
    tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
    if not tenant or getattr(tenant, "schema_name", None) == "public":
        return Response({"detail": "No tenant context."}, status=400)

    profile, _ = ReferralProfile.objects.get_or_create(tenant=tenant)
    return Response({
        "coin_balance": str(profile.coin_balance),
        "total_earned": str(profile.total_earned),
        "total_redeemed": str(profile.total_redeemed),
        "referral_count": profile.referral_count,
        "referral_code": profile.referral_code,
    })


def _parse_date_range(request):
    """Parse start/end from query params. Supports preset shortcuts."""
    preset = request.query_params.get("preset", "")
    today = date.today()

    if preset == "today":
        return today, today
    elif preset == "yesterday":
        return today - timedelta(days=1), today - timedelta(days=1)
    elif preset == "7d":
        return today - timedelta(days=6), today
    elif preset == "30d":
        return today - timedelta(days=29), today
    elif preset == "90d":
        return today - timedelta(days=89), today
    elif preset == "this_month":
        return today.replace(day=1), today
    elif preset == "last_month":
        first = (today.replace(day=1) - timedelta(days=1)).replace(day=1)
        last = today.replace(day=1) - timedelta(days=1)
        return first, last

    start = request.query_params.get("start")
    end = request.query_params.get("end")
    try:
        start = date.fromisoformat(start) if start else today - timedelta(days=29)
        end = date.fromisoformat(end) if end else today
    except ValueError:
        start, end = today - timedelta(days=29), today
    return start, end


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def referral_performance(request):
    """
    Referral performance trends with date filtering.

    Query params:
      preset  – today | yesterday | 7d | 30d | 90d | this_month | last_month
      start   – YYYY-MM-DD (custom range)
      end     – YYYY-MM-DD (custom range)
    """
    tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
    if not tenant or getattr(tenant, "schema_name", None) == "public":
        return Response({"detail": "No tenant context."}, status=400)

    profile, _ = ReferralProfile.objects.get_or_create(tenant=tenant)
    start, end = _parse_date_range(request)

    # ── Transactions in range ──
    tx_qs = CoinTransaction.objects.filter(
        profile=profile,
        created_at__date__gte=start,
        created_at__date__lte=end,
    )

    # Daily coins earned/redeemed trend
    daily_earned = (
        tx_qs.filter(type__in=["earned", "bonus"])
        .annotate(day=TruncDate("created_at"))
        .values("day")
        .annotate(total=Sum("amount"))
        .order_by("day")
    )
    daily_redeemed = (
        tx_qs.filter(type="redeemed")
        .annotate(day=TruncDate("created_at"))
        .values("day")
        .annotate(total=Sum("amount"))
        .order_by("day")
    )

    # Summary stats for the period
    period_earned = tx_qs.filter(type__in=["earned", "bonus"]).aggregate(t=Sum("amount"))["t"] or Decimal("0")
    period_redeemed = tx_qs.filter(type="redeemed").aggregate(t=Sum("amount"))["t"] or Decimal("0")
    period_tx_count = tx_qs.count()

    # Referrals created in range
    referrals_in_range = Referral.objects.filter(
        referrer=tenant,
        created_at__date__gte=start,
        created_at__date__lte=end,
    )
    new_referrals = referrals_in_range.count()

    # Daily new referrals trend
    daily_referrals = (
        referrals_in_range
        .annotate(day=TruncDate("created_at"))
        .values("day")
        .annotate(count=Count("id"))
        .order_by("day")
    )

    # Per-referral performance
    all_referrals = (
        Referral.objects.filter(referrer=tenant)
        .select_related("referred")
        .order_by("-tracked_requests")
    )
    top_referrals = [
        {
            "id": r.id,
            "referred_name": r.referred.name,
            "status": r.status,
            "tracked_requests": r.tracked_requests,
            "coins_from_usage": str(r.coins_from_usage),
            "created_at": r.created_at.isoformat(),
        }
        for r in all_referrals[:10]
    ]

    # Breakdown by transaction type in range
    type_breakdown = (
        tx_qs.values("type")
        .annotate(total=Sum("amount"), count=Count("id"))
        .order_by("type")
    )

    # Recent transactions in range
    recent_transactions = CoinTransactionSerializer(tx_qs[:20], many=True).data

    return Response({
        "period": {"start": start.isoformat(), "end": end.isoformat()},
        "summary": {
            "coins_earned": str(period_earned),
            "coins_redeemed": str(period_redeemed),
            "net_coins": str(period_earned - period_redeemed),
            "transactions": period_tx_count,
            "new_referrals": new_referrals,
            "total_balance": str(profile.coin_balance),
        },
        "trends": {
            "daily_earned": [{"date": d["day"].isoformat(), "amount": str(d["total"])} for d in daily_earned],
            "daily_redeemed": [{"date": d["day"].isoformat(), "amount": str(d["total"])} for d in daily_redeemed],
            "daily_referrals": [{"date": d["day"].isoformat(), "count": d["count"]} for d in daily_referrals],
        },
        "type_breakdown": [{"type": t["type"], "total": str(t["total"]), "count": t["count"]} for t in type_breakdown],
        "top_referrals": top_referrals,
        "recent_transactions": recent_transactions,
    })
