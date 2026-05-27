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


# ─────────────────────────────────────────────────────────────────────────
#  Redemption endpoints
# ─────────────────────────────────────────────────────────────────────────

# Conversion rate: 1 Adhere Coin = 1 KSH (configurable)
COIN_TO_KSH = Decimal("1")


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def redeem_pay_bill(request):
    """
    Apply Adhere Coins to pay an outstanding API usage bill.

    Payload:
      - bill_id: int (MonthlyBill pk)
      - amount: decimal (coins to apply; optional — defaults to full bill amount)
    """
    from .models import MonthlyBill
    from django.utils import timezone

    tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
    if not tenant or getattr(tenant, "schema_name", None) == "public":
        return Response({"detail": "No tenant context."}, status=400)

    bill_id = request.data.get("bill_id")
    if not bill_id:
        return Response({"detail": "bill_id is required."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        bill = MonthlyBill.objects.get(pk=bill_id, tenant=tenant)
    except MonthlyBill.DoesNotExist:
        return Response({"detail": "Bill not found."}, status=status.HTTP_404_NOT_FOUND)

    if bill.status != MonthlyBill.Status.ISSUED:
        return Response({"detail": "Only issued bills can be paid."}, status=status.HTTP_400_BAD_REQUEST)

    profile, _ = ReferralProfile.objects.get_or_create(tenant=tenant)

    # Amount in coins to apply
    requested = request.data.get("amount")
    bill_amount_coins = bill.amount / COIN_TO_KSH  # convert KSH to coins
    if requested:
        coins_to_apply = min(Decimal(str(requested)), bill_amount_coins)
    else:
        coins_to_apply = bill_amount_coins

    if coins_to_apply <= 0:
        return Response({"detail": "Amount must be positive."}, status=status.HTTP_400_BAD_REQUEST)

    if profile.coin_balance < coins_to_apply:
        return Response({
            "detail": f"Insufficient balance. You have {profile.coin_balance} coins but need {coins_to_apply}.",
        }, status=status.HTTP_400_BAD_REQUEST)

    # Debit coins
    profile.debit(coins_to_apply, f"API bill payment — {bill.year}-{bill.month:02d}")

    # Mark bill as paid
    ksh_paid = coins_to_apply * COIN_TO_KSH
    bill.status = MonthlyBill.Status.PAID
    bill.paid_at = timezone.now()
    bill.notes = (bill.notes or "") + f"\nPaid with {coins_to_apply} Adhere Coins ({ksh_paid} KSH)."
    bill.save(update_fields=["status", "paid_at", "notes"])

    return Response({
        "detail": f"Successfully paid bill with {coins_to_apply} Adhere Coins.",
        "coins_applied": str(coins_to_apply),
        "ksh_equivalent": str(ksh_paid),
        "remaining_balance": str(profile.coin_balance),
        "bill_status": bill.status,
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def redeem_gift_coins(request):
    """
    Gift Adhere Coins to another pharmacy.

    Payload:
      - recipient_code: str (referral code of the recipient pharmacy)
      - amount: decimal (coins to send)
      - message: str (optional greeting message)
    """
    tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
    if not tenant or getattr(tenant, "schema_name", None) == "public":
        return Response({"detail": "No tenant context."}, status=400)

    recipient_code = (request.data.get("recipient_code") or "").strip().upper()
    amount = request.data.get("amount")
    message = (request.data.get("message") or "").strip()

    if not recipient_code:
        return Response({"detail": "recipient_code is required."}, status=status.HTTP_400_BAD_REQUEST)
    if not amount or Decimal(str(amount)) <= 0:
        return Response({"detail": "amount must be a positive number."}, status=status.HTTP_400_BAD_REQUEST)

    amount = Decimal(str(amount))

    # Sender profile
    sender_profile, _ = ReferralProfile.objects.get_or_create(tenant=tenant)

    # Recipient profile
    try:
        recipient_profile = ReferralProfile.objects.select_related("tenant").get(referral_code=recipient_code)
    except ReferralProfile.DoesNotExist:
        return Response({"detail": "Recipient pharmacy not found. Check the referral code."}, status=status.HTTP_404_NOT_FOUND)

    if recipient_profile.tenant_id == tenant.pk:
        return Response({"detail": "You cannot gift coins to yourself."}, status=status.HTTP_400_BAD_REQUEST)

    if sender_profile.coin_balance < amount:
        return Response({
            "detail": f"Insufficient balance. You have {sender_profile.coin_balance} coins.",
        }, status=status.HTTP_400_BAD_REQUEST)

    # Transfer
    reason_send = f"Gift to {recipient_profile.tenant.name}" + (f" — {message}" if message else "")
    reason_receive = f"Gift from {tenant.name}" + (f" — {message}" if message else "")

    sender_profile.debit(amount, reason_send)
    recipient_profile.credit(amount, reason_receive, related_tenant=tenant)

    return Response({
        "detail": f"Successfully gifted {amount} Adhere Coins to {recipient_profile.tenant.name}.",
        "amount_sent": str(amount),
        "recipient_name": recipient_profile.tenant.name,
        "remaining_balance": str(sender_profile.coin_balance),
    })
