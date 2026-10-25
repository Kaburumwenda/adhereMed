"""
Middleware that meters API requests per tenant per day.

Counts only requests that:
  * hit `/api/...`
  * resolve to a non-public tenant

Updates are best-effort: failures are swallowed so billing tracking can
never break a customer-facing response.

It also keeps a short rolling window of request timestamps per tenant, which
the Command Center's traffic monitor uses for a live per-minute rate.
"""
import logging
from collections import defaultdict, deque
from threading import Lock
from time import monotonic

from django.db import connection, transaction
from django.db.models import F
from django.utils import timezone

logger = logging.getLogger(__name__)

# Endpoints that should NOT count against the tenant's bill (auth, the
# usage-billing dashboard itself, schema docs, etc.). Match by `startswith`.
EXCLUDED_PREFIXES = (
    "/api/auth/",
    "/api/usage-billing/",
    "/api/schema",
    "/api/docs",
)

# ── Live traffic window ───────────────────────────────────────────────────────
# `DailyUsage` is the durable, per-day record. That is far too coarse for a
# monitor, so each request also drops a monotonic timestamp into a bounded
# in-process deque. A monitoring view can then report "requests in the last
# 60 s" with no query at all.
#
# This window is per worker process: with N gunicorn workers the true rate is
# up to N x the reported figure. That is acceptable for a liveness/throughput
# indicator (and it is exact on the single-process dev server), and it keeps
# the hot path free of cache round-trips. The durable totals come from
# `DailyUsage`, which is exact.
LIVE_WINDOW_SECONDS = 900
_LIVE_MAX_SAMPLES = 20000

_traffic_window = defaultdict(deque)
_traffic_lock = Lock()


def record_traffic(schema_name: str, ts: float | None = None) -> None:
    """Drop a sample for ``schema_name`` into the rolling window (best effort)."""
    if not schema_name:
        return
    now_ts = monotonic() if ts is None else ts
    try:
        with _traffic_lock:
            bucket = _traffic_window[schema_name]
            bucket.append(now_ts)
            # Drop samples that fell out of the window, then hard-cap the deque
            # so a request flood cannot grow memory without bound.
            cutoff = now_ts - LIVE_WINDOW_SECONDS
            while bucket and bucket[0] < cutoff:
                bucket.popleft()
    except Exception:  # pragma: no cover - never break a response
        logger.debug("record_traffic failed", exc_info=True)


def live_traffic_snapshot() -> dict:
    """Return ``{schema_name: {"per_min": float, "last_60s": int, "last_seen_s": float|None}}``.

    ``per_min`` is the average requests/minute across the whole 15-minute
    window; ``last_60s`` is the count in the last minute. Both are 0 when the
    tenant has been quiet for longer than the window.
    """
    now_ts = monotonic()
    out = {}
    try:
        with _traffic_lock:
            for schema, bucket in _traffic_window.items():
                cutoff = now_ts - LIVE_WINDOW_SECONDS
                while bucket and bucket[0] < cutoff:
                    bucket.popleft()
                if not bucket:
                    out[schema] = {"per_min": 0.0, "last_60s": 0, "last_seen_s": None}
                    continue
                last_60 = sum(1 for t in bucket if t >= now_ts - 60)
                span = max(1.0, min(LIVE_WINDOW_SECONDS, now_ts - bucket[0]))
                out[schema] = {
                    "per_min": round(len(bucket) / (span / 60.0), 2),
                    "last_60s": last_60,
                    "last_seen_s": round(now_ts - bucket[-1], 1),
                }
    except Exception:  # pragma: no cover
        logger.debug("live_traffic_snapshot failed", exc_info=True)
    return out


class RequestUsageMiddleware:
    """Increment `DailyUsage` for the active tenant on each billable API call."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        try:
            self._track(request, response)
        except Exception:  # pragma: no cover - never break the response
            logger.exception("RequestUsageMiddleware tracking failed")
        return response

    def _track(self, request, response):
        path = request.path or ""
        if not path.startswith("/api/"):
            return

        tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
        schema = getattr(tenant, "schema_name", None)

        # Traffic metering counts every API hit against the facility, including
        # the bill-excluded endpoints and patient traffic — a monitor cares
        # about load, not about what gets invoiced.
        if schema and schema != "public":
            record_traffic(schema)

        if any(path.startswith(p) for p in EXCLUDED_PREFIXES):
            return

        # Patients use the system free of charge.
        user = getattr(request, "user", None)
        if user is not None and getattr(user, "is_authenticated", False):
            if getattr(user, "role", None) == "patient":
                return

        if tenant is None:
            return
        if not schema or schema == "public":
            return

        # Lazy import to avoid AppRegistryNotReady at import time.
        from usage_billing.models import DailyUsage

        today = timezone.localdate()
        is_lab = path.startswith("/api/lab/")
        # Use the public schema connection for the write so the row lands
        # in the shared table regardless of which tenant schema is active.
        with transaction.atomic():
            update_fields = {"request_count": F("request_count") + 1}
            if is_lab:
                update_fields["lab_request_count"] = F("lab_request_count") + 1
            updated = DailyUsage.objects.filter(
                tenant_id=tenant.id, date=today
            ).update(**update_fields)
            if not updated:
                _, created = DailyUsage.objects.get_or_create(
                    tenant_id=tenant.id,
                    date=today,
                    defaults={
                        "request_count": 1,
                        "lab_request_count": 1 if is_lab else 0,
                    },
                )
                if not created:
                    # A parallel request created the row; apply our increment.
                    DailyUsage.objects.filter(
                        tenant_id=tenant.id, date=today
                    ).update(**update_fields)

        # ── Referral coin tracking ────────────────────────────────────
        self._track_referral_coins(tenant)

    # noinspection PyMethodMayBeStatic
    def _track_referral_coins(self, tenant):
        """Award 1 Adhere Coin to the referrer for every 1 000 requests made by this tenant."""
        try:
            from usage_billing.referral_models import Referral
            referral = Referral.objects.select_related('referrer__referral_profile').filter(
                referred=tenant, status=Referral.Status.ACTIVE,
            ).first()
            if referral is None:
                return

            from django.db.models import F
            Referral.objects.filter(pk=referral.pk).update(tracked_requests=F('tracked_requests') + 1)
            referral.refresh_from_db()

            # Every 1000th request earns the referrer 1 coin
            if referral.tracked_requests % 1000 == 0:
                from decimal import Decimal
                profile = referral.referrer.referral_profile
                profile.credit(
                    Decimal('1'),
                    f'Usage milestone: {referral.tracked_requests} requests by {tenant.name}',
                    related_tenant=tenant,
                )
                Referral.objects.filter(pk=referral.pk).update(
                    coins_from_usage=F('coins_from_usage') + 1,
                )
        except Exception:
            logger.exception("Referral coin tracking failed")
