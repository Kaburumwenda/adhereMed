"""
M-Pesa STK push + wallet payment API views.

Tenant-facing:
  POST /api/usage-billing/payments/mpesa/initiate/   – start an STK push
  POST /api/usage-billing/payments/mpesa/confirm/    – poll a payment result
  POST /api/usage-billing/payments/wallet/pay-bill/  – pay a bill from wallet

Super-admin:
  GET/PUT /api/usage-billing/admin/payment-config/   – gateway URLs
  GET     /api/usage-billing/admin/payments/         – every M-Pesa transaction
"""
import json
import logging
import socket
import ssl
import time
import urllib.error
import urllib.request
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

from django.db import connection, transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from superadmin.permissions import IsSuperAdmin

from .models import BillingRate, MonthlyBill
from .payment_models import (
    MpesaTransaction,
    PaymentGatewayConfig,
    TenantWallet,
)
from .payment_serializers import (
    MpesaTransactionSerializer,
    PaymentGatewayConfigSerializer,
)

logger = logging.getLogger(__name__)


# ── helpers ───────────────────────────────────────────────────────────────────

def _tenant(request):
    tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
    if not tenant or getattr(tenant, "schema_name", None) == "public":
        return None
    return tenant


def _to_decimal(value):
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, TypeError):
        return None
    return amount if amount > 0 else None


def _gateway_post(url, payload, timeout=30, retries=2):
    """POST JSON to the payment gateway and return (data, error).

    Retries on transient network / 5xx errors since the dev server may
    occasionally fail to reach the gateway on the first attempt.
    """
    body = json.dumps(payload).encode("utf-8")
    ssl_context = ssl.create_default_context()
    last_error = "Could not reach payment gateway."

    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json", "Accept": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout, context=ssl_context) as resp:
                raw = resp.read().decode("utf-8")
            try:
                return json.loads(raw), None
            except (ValueError, TypeError):
                logger.warning("Gateway returned non-JSON body: %s", raw[:500])
                return None, "Invalid response from payment gateway."
        except urllib.error.HTTPError as exc:
            try:
                raw = exc.read().decode("utf-8")
            except Exception:
                raw = ""
            logger.warning(
                "Gateway HTTP %s (attempt %s/%s): %s", exc.code, attempt, retries, raw[:500]
            )
            # Some gateways return a useful JSON body even on 4xx.
            try:
                return json.loads(raw), None
            except (ValueError, TypeError):
                last_error = f"Gateway returned HTTP {exc.code}."
                if exc.code < 500:
                    return None, last_error
        except (urllib.error.URLError, socket.timeout, TimeoutError, OSError) as exc:
            reason = getattr(exc, "reason", exc)
            last_error = f"Could not reach payment gateway: {reason}."
            logger.warning("Gateway connection error (attempt %s/%s): %s", attempt, retries, reason)
        except Exception as exc:  # noqa: BLE001
            last_error = f"Unexpected gateway error: {exc}."
            logger.exception("Unexpected gateway error")

        if attempt < retries:
            time.sleep(1)

    return None, last_error


def _get(data, *keys):
    """Case-insensitive nested lookup helper for gateway responses."""
    if not isinstance(data, dict):
        return None
    lowered = {str(k).lower(): v for k, v in data.items()}
    for key in keys:
        val = lowered.get(str(key).lower())
        if val not in (None, ""):
            return val
    return None


def _apply_successful_payment(txn: MpesaTransaction):
    """Credit a successful M-Pesa payment to the right place (idempotent)."""
    if txn.applied:
        return
    with transaction.atomic():
        txn = MpesaTransaction.objects.select_for_update().get(pk=txn.pk)
        if txn.applied:
            return
        wallet, _ = TenantWallet.objects.get_or_create(
            tenant=txn.tenant, defaults={"currency": txn.currency}
        )
        if txn.purpose == MpesaTransaction.Purpose.BILL and txn.bill_id:
            bill = MonthlyBill.objects.select_for_update().get(pk=txn.bill_id)
            applied = bill.apply_payment(txn.amount)
            leftover = Decimal(txn.amount) - applied
            if leftover > 0:
                wallet.credit(
                    leftover,
                    f"Overpayment credited from bill {bill.period_label}",
                    related_bill=bill,
                    mpesa=txn,
                )
        else:
            wallet.credit(txn.amount, "M-Pesa wallet top-up", mpesa=txn)
        txn.applied = True
        txn.save(update_fields=["applied"])


# ── tenant: initiate STK push ─────────────────────────────────────────────────

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mpesa_initiate(request):
    tenant = _tenant(request)
    if tenant is None:
        return Response({"detail": "No tenant context."}, status=status.HTTP_400_BAD_REQUEST)

    gateway = PaymentGatewayConfig.get_solo()
    if not gateway.is_active:
        return Response(
            {"detail": "M-Pesa payments are currently unavailable."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    phone = (request.data.get("phone") or "").strip()
    amount = _to_decimal(request.data.get("amount"))
    purpose = (request.data.get("purpose") or "bill").strip().lower()
    bill_id = request.data.get("bill_id")

    if not phone:
        return Response({"detail": "Phone number is required."}, status=status.HTTP_400_BAD_REQUEST)
    if amount is None:
        return Response({"detail": "A valid amount is required."}, status=status.HTTP_400_BAD_REQUEST)
    if purpose not in (MpesaTransaction.Purpose.BILL, MpesaTransaction.Purpose.WALLET):
        return Response({"detail": "Invalid payment purpose."}, status=status.HTTP_400_BAD_REQUEST)

    bill = None
    if purpose == MpesaTransaction.Purpose.BILL:
        if not bill_id:
            return Response({"detail": "bill_id is required for bill payments."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            bill = MonthlyBill.objects.get(pk=bill_id, tenant=tenant)
        except MonthlyBill.DoesNotExist:
            return Response({"detail": "Bill not found."}, status=status.HTTP_404_NOT_FOUND)
        if bill.status not in (MonthlyBill.Status.ISSUED, MonthlyBill.Status.PARTIAL, MonthlyBill.Status.DRAFT):
            return Response({"detail": "This bill cannot be paid."}, status=status.HTTP_400_BAD_REQUEST)

    rate = BillingRate.current()
    # M-Pesa only accepts whole-number amounts; the gateway calls int() on it.
    charge_amount = amount.quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    if charge_amount < 1:
        charge_amount = Decimal("1")
    payload = {
        "phone": phone,
        "amount": str(int(charge_amount)),
        "source": gateway.source,
    }
    data, err = _gateway_post(payload=payload, url=gateway.stk_push_url, timeout=40)
    if err:
        return Response({"detail": err}, status=status.HTTP_502_BAD_GATEWAY)

    response_code = str(_get(data, "ResponseCode", "responseCode", "response_code") or "")
    checkout_id = _get(data, "CheckoutRequestID", "checkoutRequestID", "checkoutid", "CheckoutRequestId")

    if response_code != "0" or not checkout_id:
        message = (
            _get(data, "ResponseDescription", "errorMessage", "message", "detail")
            or "Failed to initiate M-Pesa payment. Please try again."
        )
        return Response({"detail": str(message), "gateway": data}, status=status.HTTP_400_BAD_REQUEST)

    txn = MpesaTransaction.objects.create(
        tenant=tenant,
        purpose=purpose,
        bill=bill,
        phone=phone,
        amount=charge_amount,
        currency=rate.currency,
        checkout_request_id=str(checkout_id),
        status=MpesaTransaction.Status.PENDING,
        initiate_response=data if isinstance(data, dict) else {"raw": data},
        initiated_by=request.user if request.user.is_authenticated else None,
    )

    return Response(
        {
            "detail": "Payment request sent. Approve the prompt on your phone.",
            "transaction_id": txn.id,
            "checkout_request_id": txn.checkout_request_id,
            "poll_interval_seconds": gateway.poll_interval_seconds,
            "timeout_seconds": gateway.request_timeout_seconds,
            "transaction": MpesaTransactionSerializer(txn).data,
        },
        status=status.HTTP_201_CREATED,
    )


# ── tenant: confirm / poll STK push ───────────────────────────────────────────

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mpesa_confirm(request):
    tenant = _tenant(request)
    if tenant is None:
        return Response({"detail": "No tenant context."}, status=status.HTTP_400_BAD_REQUEST)

    txn_id = request.data.get("transaction_id")
    if not txn_id:
        return Response({"detail": "transaction_id is required."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        txn = MpesaTransaction.objects.get(pk=txn_id, tenant=tenant)
    except MpesaTransaction.DoesNotExist:
        return Response({"detail": "Transaction not found."}, status=status.HTTP_404_NOT_FOUND)

    # Already resolved — return the stored outcome.
    if txn.status == MpesaTransaction.Status.SUCCESS:
        _apply_successful_payment(txn)
        return Response({"status": "success", "detail": "Payment confirmed.", "transaction": MpesaTransactionSerializer(txn).data})
    if txn.status == MpesaTransaction.Status.FAILED:
        return Response({"status": "failed", "detail": txn.result_desc or "Payment failed.", "transaction": MpesaTransactionSerializer(txn).data})

    gateway = PaymentGatewayConfig.get_solo()
    data, err = _gateway_post(
        payload={"checkoutid": txn.checkout_request_id},
        url=gateway.confirm_url,
        timeout=20,
    )
    if err:
        # Transient gateway/network issue — let the client keep polling.
        return Response({"status": "pending", "detail": err})

    txn.confirm_response = data if isinstance(data, dict) else {"raw": data}

    result_code = _get(data, "ResultCode", "resultCode", "result_code")
    error_code = _get(data, "errorCode", "error_code")
    result_desc = _get(data, "ResultDesc", "resultDesc", "errorMessage", "message")
    result_code = str(result_code) if result_code is not None else None
    error_code = str(error_code) if error_code is not None else None

    if result_code == "0":
        txn.result_code = "0"
        txn.result_desc = str(result_desc or "Payment received.")
        txn.status = MpesaTransaction.Status.SUCCESS
        txn.completed_at = timezone.now()
        txn.save(update_fields=["confirm_response", "result_code", "result_desc", "status", "completed_at"])
        _apply_successful_payment(txn)
        return Response({
            "status": "success",
            "detail": "Payment confirmed successfully.",
            "transaction": MpesaTransactionSerializer(txn).data,
        })

    if result_code == "1032":
        txn.result_code = "1032"
        txn.result_desc = str(result_desc or "Payment cancelled or insufficient balance.")
        txn.status = MpesaTransaction.Status.FAILED
        txn.completed_at = timezone.now()
        txn.save(update_fields=["confirm_response", "result_code", "result_desc", "status", "completed_at"])
        return Response({
            "status": "failed",
            "detail": txn.result_desc,
            "transaction": MpesaTransactionSerializer(txn).data,
        })

    # 500.001.1001 (processing) or anything else not yet terminal — keep polling.
    txn.save(update_fields=["confirm_response"])
    detail = str(result_desc or "Payment is still being processed. Please wait…")
    return Response({"status": "pending", "detail": detail, "error_code": error_code})


# ── tenant: pay a bill from wallet balance ────────────────────────────────────

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def wallet_pay_bill(request):
    tenant = _tenant(request)
    if tenant is None:
        return Response({"detail": "No tenant context."}, status=status.HTTP_400_BAD_REQUEST)

    bill_id = request.data.get("bill_id")
    if not bill_id:
        return Response({"detail": "bill_id is required."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        bill = MonthlyBill.objects.get(pk=bill_id, tenant=tenant)
    except MonthlyBill.DoesNotExist:
        return Response({"detail": "Bill not found."}, status=status.HTTP_404_NOT_FOUND)

    if bill.status not in (MonthlyBill.Status.ISSUED, MonthlyBill.Status.PARTIAL, MonthlyBill.Status.DRAFT):
        return Response({"detail": "This bill cannot be paid."}, status=status.HTTP_400_BAD_REQUEST)

    rate = BillingRate.current()
    wallet, _ = TenantWallet.objects.get_or_create(
        tenant=tenant, defaults={"currency": rate.currency}
    )

    requested = request.data.get("amount")
    amount = _to_decimal(requested) if requested not in (None, "") else bill.balance
    if amount is None:
        return Response({"detail": "A valid amount is required."}, status=status.HTTP_400_BAD_REQUEST)

    amount = min(Decimal(amount), bill.balance)
    if amount <= 0:
        return Response({"detail": "Nothing left to pay on this bill."}, status=status.HTTP_400_BAD_REQUEST)
    if wallet.balance < amount:
        return Response(
            {"detail": f"Insufficient wallet balance. You have {wallet.balance} {wallet.currency}."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    with transaction.atomic():
        bill = MonthlyBill.objects.select_for_update().get(pk=bill.pk)
        wallet = TenantWallet.objects.select_for_update().get(pk=wallet.pk)
        applied = bill.apply_payment(amount)
        wallet.debit(applied, f"Bill payment — {bill.period_label}", related_bill=bill)

    return Response({
        "detail": f"Paid {applied} {wallet.currency} towards bill {bill.period_label}.",
        "amount_applied": str(applied),
        "wallet_balance": str(wallet.balance),
        "bill_status": bill.status,
    })


# ── super-admin: gateway config ───────────────────────────────────────────────

@api_view(["GET", "PUT", "PATCH"])
@permission_classes([IsSuperAdmin])
def payment_config(request):
    config = PaymentGatewayConfig.get_solo()
    if request.method == "GET":
        return Response(PaymentGatewayConfigSerializer(config).data)

    serializer = PaymentGatewayConfigSerializer(config, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save(updated_by=request.user)
    return Response(serializer.data)


# ── super-admin: all M-Pesa transactions ──────────────────────────────────────

@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def admin_payments(request):
    qs = MpesaTransaction.objects.select_related("tenant", "bill").all()
    params = request.query_params
    if params.get("tenant"):
        qs = qs.filter(tenant_id=params["tenant"])
    if params.get("status"):
        qs = qs.filter(status=params["status"])
    if params.get("purpose"):
        qs = qs.filter(purpose=params["purpose"])

    totals = {
        "count": qs.count(),
        "success": qs.filter(status=MpesaTransaction.Status.SUCCESS).count(),
        "pending": qs.filter(status=MpesaTransaction.Status.PENDING).count(),
        "failed": qs.filter(status=MpesaTransaction.Status.FAILED).count(),
    }
    collected = sum(
        (Decimal(t.amount) for t in qs.filter(status=MpesaTransaction.Status.SUCCESS)),
        Decimal("0"),
    )

    return Response({
        "totals": {**totals, "collected": str(collected)},
        "transactions": MpesaTransactionSerializer(qs[:500], many=True).data,
    })
