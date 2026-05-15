"""
Middleware that meters API requests per tenant per day.

Counts only requests that:
  * hit `/api/...`
  * resolve to a non-public tenant

Updates are best-effort: failures are swallowed so billing tracking can
never break a customer-facing response.
"""
import logging

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
        if any(path.startswith(p) for p in EXCLUDED_PREFIXES):
            return

        # Patients use the system free of charge.
        user = getattr(request, "user", None)
        if user is not None and getattr(user, "is_authenticated", False):
            if getattr(user, "role", None) == "patient":
                return

        tenant = getattr(request, "tenant", None) or getattr(connection, "tenant", None)
        if tenant is None:
            return
        schema = getattr(tenant, "schema_name", None)
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
