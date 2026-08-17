"""
Super Admin API views.
All operate in the PUBLIC schema (shared data: Tenant, User).
Protected by IsSuperAdmin permission.
"""
import secrets
import string

from django.contrib.auth import get_user_model
from django.db.models import Count, Q
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from tenants.models import Domain, Tenant

from .permissions import IsSuperAdmin
from .serializers import (
    TenantAdminSerializer,
    TenantCreateSerializer,
    UserAdminSerializer,
    UserAdminUpdateSerializer,
    CoinAllocateSerializer,
    CoinDeductSerializer,
    CoinPackageSerializer,
    CoinTransactionSerializer,
    CoinWalletSerializer,
    ReferralAdminSerializer,
    ReferralProfileAdminSerializer,
)

User = get_user_model()


# ── Helper ────────────────────────────────────────────────────────────────────

def _generate_password(length: int = 12) -> str:
    alphabet = string.ascii_letters + string.digits + "!@#$%"
    return "".join(secrets.choice(alphabet) for _ in range(length))


# ── Platform Stats ─────────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def platform_stats(request):
    """High-level platform overview for the super admin dashboard."""
    tenants = Tenant.objects.exclude(schema_name="public")
    total_tenants = tenants.count()
    active_tenants = tenants.filter(is_active=True).count()
    by_type = list(
        tenants.values("type").annotate(count=Count("id")).order_by("type")
    )

    users = User.objects.all()
    total_users = users.count()
    active_users = users.filter(is_active=True).count()

    thirty_days_ago = timezone.now() - timezone.timedelta(days=30)
    new_tenants_30d = tenants.filter(created_at__gte=thirty_days_ago).count()
    new_users_30d = users.filter(date_joined__gte=thirty_days_ago).count()

    role_counts = list(
        users.values("role").annotate(count=Count("id")).order_by("-count")
    )

    return Response(
        {
            "tenants": {
                "total": total_tenants,
                "active": active_tenants,
                "inactive": total_tenants - active_tenants,
                "new_last_30_days": new_tenants_30d,
                "by_type": by_type,
            },
            "users": {
                "total": total_users,
                "active": active_users,
                "inactive": total_users - active_users,
                "new_last_30_days": new_users_30d,
                "by_role": role_counts,
            },
        }
    )


# ── Tenant Management ───────────────────────────────────────────────────────────

class TenantListView(generics.ListCreateAPIView):
    permission_classes = [IsSuperAdmin]

    def get_queryset(self):
        qs = Tenant.objects.exclude(schema_name="public").order_by("-created_at")
        q = self.request.query_params.get("q", "")
        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(city__icontains=q) | Q(email__icontains=q))
        type_filter = self.request.query_params.get("type", "")
        if type_filter:
            qs = qs.filter(type=type_filter)
        return qs

    def get_serializer_class(self):
        if self.request.method == "POST":
            return TenantCreateSerializer
        return TenantAdminSerializer

    def create(self, request, *args, **kwargs):
        serializer = TenantCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        tenant = Tenant.objects.create(
            name=data["name"],
            type=data["type"],
            slug=data["slug"],
            schema_name=data["slug"].replace("-", "_"),
            address=data.get("address", ""),
            city=data.get("city", ""),
            phone=data.get("phone", ""),
            email=data.get("email", ""),
            website=data.get("website", ""),
            country=data.get("country", "Kenya"),
            latitude=data.get("latitude"),
            longitude=data.get("longitude"),
            place_name=data.get("place_name", ""),
        )
        Domain.objects.create(
            domain=data["domain"],
            tenant=tenant,
            is_primary=True,
        )

        admin_password = data.get("admin_password") or _generate_password()
        admin = User.objects.create_user(
            email=data["admin_email"],
            password=admin_password,
            first_name=data["admin_first_name"],
            last_name=data["admin_last_name"],
            role=User.Role.TENANT_ADMIN,
            tenant=tenant,
        )

        # Auto-create coin wallet & grant 300 coins for pharmacies
        from usage_billing.referral_models import ReferralProfile
        profile, _ = ReferralProfile.objects.get_or_create(tenant=tenant)
        if tenant.type == "pharmacy":
            profile.credit(300, "Welcome bonus: 300 Adhere Coins on registration")

        return Response(
            {
                "tenant": TenantAdminSerializer(tenant).data,
                "admin_user": {
                    "id": admin.id,
                    "email": admin.email,
                    "name": admin.full_name,
                    "generated_password": admin_password if not data.get("admin_password") else None,
                },
            },
            status=status.HTTP_201_CREATED,
        )


class TenantDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = TenantAdminSerializer
    queryset = Tenant.objects.exclude(schema_name="public")


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def toggle_tenant_active(request, pk):
    try:
        tenant = Tenant.objects.exclude(schema_name="public").get(pk=pk)
    except Tenant.DoesNotExist:
        return Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)
    tenant.is_active = not tenant.is_active
    tenant.save(update_fields=["is_active"])
    return Response({"is_active": tenant.is_active, "name": tenant.name})


@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def tenant_stats(request, pk):
    try:
        tenant = Tenant.objects.exclude(schema_name="public").get(pk=pk)
    except Tenant.DoesNotExist:
        return Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)

    users = User.objects.filter(tenant=tenant)
    by_role = list(users.values("role").annotate(count=Count("id")).order_by("-count"))

    return Response(
        {
            "tenant": {"id": tenant.id, "name": tenant.name, "type": tenant.type},
            "users": {
                "total": users.count(),
                "active": users.filter(is_active=True).count(),
                "by_role": by_role,
            },
        }
    )


# ── User Management ─────────────────────────────────────────────────────────────

class UserListView(generics.ListAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = UserAdminSerializer

    def get_queryset(self):
        qs = User.objects.select_related("tenant").order_by("-date_joined")
        q = self.request.query_params.get("q", "")
        if q:
            qs = qs.filter(
                Q(email__icontains=q)
                | Q(first_name__icontains=q)
                | Q(last_name__icontains=q)
                | Q(phone__icontains=q)
            )
        role = self.request.query_params.get("role", "")
        if role:
            qs = qs.filter(role=role)
        tenant_id = self.request.query_params.get("tenant_id", "")
        if tenant_id:
            qs = qs.filter(tenant_id=tenant_id)
        is_active = self.request.query_params.get("is_active", "")
        if is_active in ("true", "false"):
            qs = qs.filter(is_active=(is_active == "true"))
        return qs


class UserDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsSuperAdmin]
    queryset = User.objects.select_related("tenant").all()

    def get_serializer_class(self):
        if self.request.method in ("PUT", "PATCH"):
            return UserAdminUpdateSerializer
        return UserAdminSerializer

    def partial_update(self, request, *args, **kwargs):
        kwargs["partial"] = True
        return self.update(request, *args, **kwargs)


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def reset_user_password(request, pk):
    try:
        user = User.objects.get(pk=pk)
    except User.DoesNotExist:
        return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

    new_password = request.data.get("new_password") or _generate_password()
    user.set_password(new_password)
    user.save(update_fields=["password"])
    return Response(
        {
            "detail": "Password reset successfully.",
            "generated_password": new_password if not request.data.get("new_password") else None,
        }
    )


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def toggle_user_active(request, pk):
    try:
        user = User.objects.get(pk=pk)
    except User.DoesNotExist:
        return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
    if user.role == User.Role.SUPER_ADMIN and user != request.user:
        return Response(
            {"detail": "Cannot deactivate another super admin."},
            status=status.HTTP_403_FORBIDDEN,
        )
    user.is_active = not user.is_active
    user.save(update_fields=["is_active"])
    return Response({"is_active": user.is_active, "email": user.email})


# ── Seed Data ────────────────────────────────────────────────────────────────────

SEED_COMMANDS = {
    "medications": {
        "label": "Global Medications",
        "description": "~120 common medications (analgesics, antibiotics, etc.)",
        "scope": "public",
        "command": "seed_medications",
    },
    "clinical_catalog": {
        "label": "Clinical Catalog",
        "description": "Allergies, chronic conditions, ICD-style diagnoses & procedures",
        "scope": "public",
        "command": "seed_clinical_catalog",
        "supports_clear": True,
    },
    "pharmacy_stock": {
        "label": "Pharmacy Stock",
        "description": "150+ medication stock items with prices, categories & units",
        "scope": "tenant",
        "command": "seed_pharmacy_stock",
        "supports_reset": True,
    },
    "lab_tests": {
        "label": "Lab Test Catalog",
        "description": "~75 lab tests (hematology, biochemistry, microbiology, etc.)",
        "scope": "tenant",
        "command": "seed_lab_tests",
    },
    "homecare_catalog": {
        "label": "Homecare Catalog (Diagnoses + Allergies)",
        "description": "Copies the global allergies & chronic conditions into a tenant's editable catalog.",
        "scope": "tenant",
        "command": "seed_homecare_catalog",
        "supports_reset": True,
    },
    "radiology_exams": {
        "label": "Radiology Exam Catalog",
        "description": "143 standard imaging exams (X-Ray, CT, MRI, Ultrasound, Mammography, Fluoroscopy, PET-CT, DEXA, Interventional) with protocols & prep instructions.",
        "scope": "tenant",
        "command": "seed_exam_catalog",
        "supports_reset": True,
    },
    "radiology_panels": {
        "label": "Radiology Exam Panels",
        "description": "32 common exam bundles (Trauma, Cardiac, Neuro, Spine, MSK, Breast, Oncology, Paediatric, Pre-Op, Interventional) with discounted pricing.",
        "scope": "tenant",
        "command": "seed_exam_panels",
        "supports_reset": True,
    },
}


@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def seed_catalog(request):
    """Return the list of available seed commands."""
    items = []
    for key, info in SEED_COMMANDS.items():
        items.append({
            "key": key,
            "label": info["label"],
            "description": info["description"],
            "scope": info["scope"],
            "supports_reset": info.get("supports_reset", False),
            "supports_clear": info.get("supports_clear", False),
        })
    return Response(items)


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def run_seed(request):
    """
    Run a seed command for a tenant (or globally).
    Body: { "command": "pharmacy_stock", "tenant_id": 2, "reset": false }
    """
    from django.core.management import call_command
    from django_tenants.utils import schema_context

    cmd_key = request.data.get("command", "")
    tenant_id = request.data.get("tenant_id")
    all_tenants = bool(request.data.get("all_tenants"))
    reset = request.data.get("reset", False)

    if cmd_key not in SEED_COMMANDS:
        return Response(
            {"detail": f"Unknown seed command: {cmd_key}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    info = SEED_COMMANDS[cmd_key]

    # Tenant-scoped commands need a tenant
    if info["scope"] == "tenant":
        if all_tenants:
            tenants_qs = Tenant.objects.exclude(schema_name="public").filter(is_active=True)
            results = []
            kwargs = {}
            if reset and info.get("supports_reset"):
                kwargs["reset"] = True
            for t in tenants_qs:
                try:
                    with schema_context(t.schema_name):
                        call_command(info["command"], **kwargs)
                    results.append({"tenant": t.name, "status": "ok"})
                except Exception as e:
                    results.append({"tenant": t.name, "status": "error", "error": str(e)})
            ok = sum(1 for r in results if r["status"] == "ok")
            return Response({
                "detail": f"'{info['label']}' seeded for {ok}/{len(results)} tenants.",
                "command": cmd_key,
                "results": results,
            })

        if not tenant_id:
            return Response(
                {"detail": "tenant_id (or all_tenants=true) is required for this seed command."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            tenant = Tenant.objects.exclude(schema_name="public").get(pk=tenant_id)
        except Tenant.DoesNotExist:
            return Response(
                {"detail": "Tenant not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            kwargs = {}
            if reset and info.get("supports_reset"):
                kwargs["reset"] = True
            with schema_context(tenant.schema_name):
                call_command(info["command"], **kwargs)
        except Exception as e:
            return Response(
                {"detail": f"Seed failed: {e}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response({
            "detail": f"'{info['label']}' seeded successfully for {tenant.name}.",
            "tenant": tenant.name,
            "command": cmd_key,
        })

    # Public-scoped commands
    try:
        kwargs = {}
        if reset and info.get("supports_clear"):
            kwargs["clear"] = True
        call_command(info["command"], **kwargs)
    except Exception as e:
        return Response(
            {"detail": f"Seed failed: {e}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return Response({
        "detail": f"'{info['label']}' seeded successfully (global).",
        "command": cmd_key,
    })


# ── Adhere Coins ─────────────────────────────────────────────────────────────────

from usage_billing.referral_models import ReferralProfile, CoinTransaction as RefCoinTransaction
from .models import CoinPackage


class CoinPackageListView(generics.ListCreateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = CoinPackageSerializer
    queryset = CoinPackage.objects.all()


class CoinPackageDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = CoinPackageSerializer
    queryset = CoinPackage.objects.all()


class CoinWalletListView(generics.ListAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = CoinWalletSerializer

    def get_queryset(self):
        qs = ReferralProfile.objects.select_related("tenant").all()
        q = self.request.query_params.get("q", "")
        if q:
            qs = qs.filter(tenant__name__icontains=q)
        return qs


class CoinTransactionListView(generics.ListAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = CoinTransactionSerializer

    def get_queryset(self):
        qs = RefCoinTransaction.objects.select_related("profile__tenant", "related_tenant").all()
        tenant_id = self.request.query_params.get("tenant")
        if tenant_id:
            qs = qs.filter(profile__tenant_id=tenant_id)
        tx_type = self.request.query_params.get("tx_type")
        if tx_type:
            qs = qs.filter(type=tx_type)
        return qs


@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def coin_stats(request):
    """High-level coin economy stats."""
    from django.db.models import Sum

    wallets = ReferralProfile.objects.all()
    total_wallets = wallets.count()
    total_balance = wallets.aggregate(s=Sum("coin_balance"))["s"] or 0
    total_earned = wallets.aggregate(s=Sum("total_earned"))["s"] or 0
    total_spent = wallets.aggregate(s=Sum("total_redeemed"))["s"] or 0

    recent_txs = RefCoinTransaction.objects.count()
    active_packages = CoinPackage.objects.filter(is_active=True).count()

    return Response({
        "total_wallets": total_wallets,
        "total_balance": float(total_balance),
        "total_earned": float(total_earned),
        "total_spent": float(total_spent),
        "total_transactions": recent_txs,
        "active_packages": active_packages,
    })


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def coin_allocate(request):
    """Credit / bonus / refund coins to a tenant wallet."""
    serializer = CoinAllocateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data

    try:
        tenant = Tenant.objects.exclude(schema_name="public").get(pk=data["tenant_id"])
    except Tenant.DoesNotExist:
        return Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)

    profile, _ = ReferralProfile.objects.get_or_create(tenant=tenant)
    amount = data["amount"]
    reason = data.get("description", "") or f"{data['tx_type'].title()} — {amount} coins"
    profile.credit(amount, reason)

    return Response({
        "tenant": tenant.name,
        "amount": amount,
        "balance": float(profile.coin_balance),
    }, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def coin_deduct(request):
    """Debit coins from a tenant wallet."""
    serializer = CoinDeductSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data

    try:
        tenant = Tenant.objects.exclude(schema_name="public").get(pk=data["tenant_id"])
    except Tenant.DoesNotExist:
        return Response({"detail": "Tenant not found."}, status=status.HTTP_404_NOT_FOUND)

    profile = ReferralProfile.objects.filter(tenant=tenant).first()
    if not profile:
        return Response({"detail": "Wallet not found for this tenant."}, status=status.HTTP_404_NOT_FOUND)

    amount = data["amount"]
    if profile.coin_balance < amount:
        return Response(
            {"detail": f"Insufficient balance. Current: {profile.coin_balance}, requested: {amount}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    reason = data.get("description", "") or f"Deduction — {amount} coins"
    profile.debit(amount, reason)

    return Response({
        "tenant": tenant.name,
        "amount": amount,
        "balance": float(profile.coin_balance),
    }, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def coin_init_wallets(request):
    """Create ReferralProfile wallets for all tenants that don't have one yet."""
    tenants_without = Tenant.objects.exclude(schema_name="public").exclude(
        referral_profile__isnull=False
    )
    created = []
    for t in tenants_without:
        ReferralProfile.objects.get_or_create(tenant=t)
        created.append(t.name)
    return Response({"created": len(created), "tenants": created})


# ── Referral Management ───────────────────────────────────────────────────────

from usage_billing.referral_models import Referral


@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def referral_admin_stats(request):
    """Platform-wide referral statistics."""
    from django.db.models import Sum, Avg

    profiles = ReferralProfile.objects.all()
    referrals = Referral.objects.all()

    total_profiles = profiles.count()
    total_referrals = referrals.count()
    active_referrals = referrals.filter(status="active").count()
    total_coins_earned = profiles.aggregate(s=Sum("total_earned"))["s"] or 0
    total_coins_redeemed = profiles.aggregate(s=Sum("total_redeemed"))["s"] or 0
    avg_referrals = profiles.aggregate(a=Avg("referral_count"))["a"] or 0

    # Top referrers
    top_referrers = (
        profiles.filter(referral_count__gt=0)
        .select_related("tenant")
        .order_by("-referral_count")[:10]
    )

    return Response({
        "total_profiles": total_profiles,
        "total_referrals": total_referrals,
        "active_referrals": active_referrals,
        "pending_referrals": referrals.filter(status="pending").count(),
        "expired_referrals": referrals.filter(status="expired").count(),
        "total_coins_earned": float(total_coins_earned),
        "total_coins_redeemed": float(total_coins_redeemed),
        "avg_referrals_per_tenant": round(float(avg_referrals), 1),
        "top_referrers": [
            {
                "tenant_name": p.tenant.name,
                "referral_count": p.referral_count,
                "coin_balance": float(p.coin_balance),
                "total_earned": float(p.total_earned),
            }
            for p in top_referrers
        ],
    })


class ReferralListView(generics.ListAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = ReferralAdminSerializer

    def get_queryset(self):
        qs = Referral.objects.select_related("referrer", "referred").all()
        q = self.request.query_params.get("q", "")
        if q:
            qs = qs.filter(
                Q(referrer__name__icontains=q) | Q(referred__name__icontains=q)
            )
        status_filter = self.request.query_params.get("status", "")
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs


class ReferralDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = ReferralAdminSerializer
    queryset = Referral.objects.select_related("referrer", "referred").all()


class ReferralProfileListView(generics.ListAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = ReferralProfileAdminSerializer

    def get_queryset(self):
        qs = ReferralProfile.objects.select_related("tenant").all()
        q = self.request.query_params.get("q", "")
        if q:
            qs = qs.filter(
                Q(tenant__name__icontains=q) | Q(referral_code__icontains=q)
            )
        return qs


class ReferralProfileDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = ReferralProfileAdminSerializer
    queryset = ReferralProfile.objects.select_related("tenant").all()


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def regenerate_referral_code(request, pk):
    """Regenerate the referral code for a profile."""
    try:
        profile = ReferralProfile.objects.get(pk=pk)
    except ReferralProfile.DoesNotExist:
        return Response({"detail": "Profile not found."}, status=status.HTTP_404_NOT_FOUND)

    import secrets as _secrets
    import string as _string
    chars = _string.ascii_uppercase + _string.digits
    while True:
        code = ''.join(_secrets.choice(chars) for _ in range(8))
        if not ReferralProfile.objects.filter(referral_code=code).exists():
            break
    profile.referral_code = code
    profile.save(update_fields=["referral_code", "updated_at"])
    return Response({"referral_code": code, "tenant_name": profile.tenant.name})


# ── System Health (tenant-scoped) ──────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def system_health(request):
    """Tenant-scoped system health dashboard.

    Returns database connectivity, storage stats, user activity,
    stock health, recent sales, and service status for the current tenant.
    """
    from datetime import timedelta
    from django.db import connection
    from django.contrib.auth import get_user_model
    from django.db.models import Count, Q as DQ

    health = {}
    now = timezone.now()

    # ── 1. Database connectivity & tenant info ──────────────────────
    try:
        db_ok = True
        db_latency_ms = 0
        import time
        t0 = time.time()
        with connection.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        db_latency_ms = round((time.time() - t0) * 1000, 1)
    except Exception as e:
        db_ok = False
        db_latency_ms = -1

    tenant = getattr(request, 'tenant', None)
    tenant_info = {}
    if tenant:
        tenant_info = {
            'name': tenant.name,
            'schema': tenant.schema_name,
            'type': getattr(tenant, 'type', ''),
            'is_active': getattr(tenant, 'is_active', True),
            'created_at': tenant.created_at.isoformat() if hasattr(tenant, 'created_at') else '',
        }

    health['database'] = {
        'status': 'healthy' if db_ok else 'error',
        'latency_ms': db_latency_ms,
        'engine': connection.settings_dict.get('ENGINE', '').split('.')[-1],
    }
    health['tenant'] = tenant_info

    # ── 2. User activity ─────────────────────────────────────────────
    try:
        User = get_user_model()
        total_users = User.objects.count()
        active_users = User.objects.filter(is_active=True).count()
        staff_users = User.objects.exclude(role='patient').count()
        roles = list(User.objects.exclude(role__isnull=True).values('role').annotate(
            count=Count('id')
        ).order_by('-count'))
        last_24h = User.objects.filter(last_login__gte=now - timedelta(hours=24)).count()
        last_7d = User.objects.filter(last_login__gte=now - timedelta(days=7)).count()
        health['users'] = {
            'total': total_users,
            'active': active_users,
            'inactive': total_users - active_users,
            'staff': staff_users,
            'active_24h': last_24h,
            'active_7d': last_7d,
            'by_role': roles,
        }
    except Exception:
        health['users'] = {'total': 0, 'active': 0, 'inactive': 0, 'staff': 0, 'active_24h': 0, 'active_7d': 0, 'by_role': []}

    # ── 3. Stock health ──────────────────────────────────────────────
    try:
        from inventory.models import MedicationStock, StockBatch
        total_skus = MedicationStock.objects.filter(is_active=True).count()
        low_stock = 0
        out_of_stock = 0
        for stock in MedicationStock.objects.filter(is_active=True):
            qty = stock.total_quantity
            if qty <= 0:
                out_of_stock += 1
            elif qty <= stock.reorder_level:
                low_stock += 1
        # Expiring batches (next 60 days)
        from datetime import datetime as _dt
        expiry_soon = StockBatch.objects.filter(
            quantity_remaining__gt=0,
            expiry_date__isnull=False,
            expiry_date__lte=now.date() + timedelta(days=60),
        ).count()
        expired = StockBatch.objects.filter(
            quantity_remaining__gt=0,
            expiry_date__isnull=False,
            expiry_date__lt=now.date(),
        ).count()
        health['stock'] = {
            'total_skus': total_skus,
            'low_stock': low_stock,
            'out_of_stock': out_of_stock,
            'healthy': total_skus - low_stock - out_of_stock,
            'expiring_soon': expiry_soon,
            'expired': expired,
        }
    except Exception:
        health['stock'] = {'total_skus': 0, 'low_stock': 0, 'out_of_stock': 0, 'healthy': 0, 'expiring_soon': 0, 'expired': 0}

    # ── 4. Recent sales activity ────────────────────────────────────
    try:
        from pos.models import POSTransaction
        sales_24h = POSTransaction.objects.filter(
            created_at__gte=now - timedelta(hours=24),
            status='completed',
        ).count()
        sales_7d = POSTransaction.objects.filter(
            created_at__gte=now - timedelta(days=7),
            status='completed',
        ).count()
        sales_30d = POSTransaction.objects.filter(
            created_at__gte=now - timedelta(days=30),
            status='completed',
        ).count()
        cancelled_7d = POSTransaction.objects.filter(
            created_at__gte=now - timedelta(days=7),
            status='cancelled',
        ).count()
        from decimal import Decimal
        revenue_7d = POSTransaction.objects.filter(
            created_at__gte=now - timedelta(days=7),
            status='completed',
        ).aggregate(total=Count('id'))
        revenue_sum = Decimal('0')
        for tx in POSTransaction.objects.filter(created_at__gte=now - timedelta(days=7), status='completed'):
            revenue_sum += tx.total or Decimal('0')
        health['sales'] = {
            'last_24h': sales_24h,
            'last_7d': sales_7d,
            'last_30d': sales_30d,
            'cancelled_7d': cancelled_7d,
            'revenue_7d': float(revenue_sum),
        }
    except Exception:
        health['sales'] = {'last_24h': 0, 'last_7d': 0, 'last_30d': 0, 'cancelled_7d': 0, 'revenue_7d': 0}

    # ── 5. Branches ─────────────────────────────────────────────────
    try:
        from pharmacy_profile.models import Branch
        branches = Branch.objects.count()
        health['branches'] = {'count': branches}
    except Exception:
        health['branches'] = {'count': 0}

    # ── 6. Database table count ────────────────────────────────────
    try:
        with connection.cursor() as cur:
            cur.execute("""
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = %s
            """, [connection.schema_name if hasattr(connection, 'schema_name') else 'public'])
            table_count = cur.fetchone()[0]
        health['database']['tables'] = table_count
    except Exception:
        health['database']['tables'] = 0

    # ── 7. Service statuses ────────────────────────────────────────
    services = []
    # Redis / Celery
    try:
        import redis
        from django.conf import settings
        broker_url = getattr(settings, 'CELERY_BROKER_URL', '')
        if broker_url:
            r = redis.from_url(broker_url, socket_connect_timeout=2)
            r.ping()
            services.append({'name': 'Redis (Celery Broker)', 'status': 'healthy', 'detail': broker_url})
        else:
            services.append({'name': 'Redis (Celery Broker)', 'status': 'not_configured', 'detail': ''})
    except Exception as e:
        services.append({'name': 'Redis (Celery Broker)', 'status': 'unreachable', 'detail': str(e)[:100]})

    # Celery eager mode (dev)
    from django.conf import settings
    eager = getattr(settings, 'CELERY_TASK_ALWAYS_EAGER', False)
    services.append({
        'name': 'Celery',
        'status': 'eager' if eager else 'configured',
        'detail': 'Tasks run synchronously (dev mode)' if eager else 'Async task queue ready',
    })

    # Email backend
    email_backend = getattr(settings, 'EMAIL_BACKEND', '')
    services.append({
        'name': 'Email',
        'status': 'smtp' if 'smtp' in email_backend.lower() else 'console' if 'console' in email_backend.lower() else 'configured',
        'detail': email_backend.split('.')[-1] if email_backend else 'not set',
    })

    health['services'] = services

    # ── 8. Overall health score ────────────────────────────────────
    score = 100
    issues = []
    if not db_ok:
        score = 0
        issues.append('Database connection failed')
    if health['stock'].get('expired', 0) > 0:
        score -= 10
        issues.append(f"{health['stock']['expired']} expired batch(es)")
    if health['stock'].get('out_of_stock', 0) > 0:
        score -= 5
        issues.append(f"{health['stock']['out_of_stock']} SKU(s) out of stock")
    if health['sales'].get('cancelled_7d', 0) > 0:
        score -= 3
        issues.append(f"{health['sales']['cancelled_7d']} cancelled sale(s) in 7 days")
    for svc in health['services']:
        if svc['status'] == 'unreachable':
            score -= 10
            issues.append(f"{svc['name']} unreachable")
    score = max(0, score)

    health['score'] = score
    health['status'] = 'healthy' if score >= 80 else 'warning' if score >= 50 else 'critical'
    health['issues'] = issues
    health['checked_at'] = now.isoformat()

    return Response(health)


@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def referral_earnings_history(request):
    """
    Detailed earnings history: coins earned by each referrer from their referred tenants.
    Includes individual transaction records + aggregated per-referral summaries.
    Optional filters: ?referrer_id=&referred_id=&months=6
    """
    from django.db.models import Sum, Count
    from django.db.models.functions import TruncMonth

    referrer_id = request.query_params.get("referrer_id")
    referred_id = request.query_params.get("referred_id")

    # Get all referral-related transactions (bonus + earned from usage)
    txs = RefCoinTransaction.objects.select_related(
        "profile__tenant", "related_tenant"
    ).filter(
        type__in=["earned", "bonus"]
    ).order_by("-created_at")

    if referrer_id:
        txs = txs.filter(profile__tenant_id=referrer_id)
    if referred_id:
        txs = txs.filter(related_tenant_id=referred_id)

    # Per-referral earnings summary (referrer -> referred -> total)
    referral_summaries = []
    referrals_qs = Referral.objects.select_related("referrer", "referred").all()
    if referrer_id:
        referrals_qs = referrals_qs.filter(referrer_id=referrer_id)
    if referred_id:
        referrals_qs = referrals_qs.filter(referred_id=referred_id)

    for ref in referrals_qs:
        earned_from = RefCoinTransaction.objects.filter(
            profile__tenant=ref.referrer,
            related_tenant=ref.referred,
        ).aggregate(
            total=Sum("amount"),
            count=Count("id"),
        )
        referral_summaries.append({
            "referral_id": ref.id,
            "referrer_id": ref.referrer_id,
            "referrer_name": ref.referrer.name,
            "referred_id": ref.referred_id,
            "referred_name": ref.referred.name,
            "status": ref.status,
            "bonus_awarded": ref.bonus_awarded,
            "tracked_requests": ref.tracked_requests,
            "coins_from_usage": float(ref.coins_from_usage),
            "requests_to_next_coin": 1000 - (ref.tracked_requests % 1000) if ref.tracked_requests % 1000 != 0 else 0,
            "total_earned_from_referred": float(earned_from["total"] or 0),
            "transaction_count": earned_from["count"] or 0,
            "created_at": ref.created_at.isoformat(),
        })

    # Recent transactions list (last 100)
    recent_txs = txs[:100]
    tx_list = [
        {
            "id": tx.id,
            "referrer_name": tx.profile.tenant.name,
            "referrer_id": tx.profile.tenant_id,
            "referred_name": tx.related_tenant.name if tx.related_tenant else "—",
            "referred_id": tx.related_tenant_id,
            "type": tx.type,
            "amount": float(tx.amount),
            "reason": tx.reason,
            "created_at": tx.created_at.isoformat(),
        }
        for tx in recent_txs
    ]

    return Response({
        "referral_summaries": referral_summaries,
        "recent_transactions": tx_list,
        "total_records": txs.count(),
    })


@api_view(["GET"])
@permission_classes([IsSuperAdmin])
def referral_monthly_projections(request):
    """
    Monthly earning trends + projections based on historical data.
    Returns last 12 months of actual data + 3 month forecast.
    """
    from django.db.models import Sum, Count
    from django.db.models.functions import TruncMonth
    from datetime import timedelta
    import statistics

    now = timezone.now()
    twelve_months_ago = now - timedelta(days=365)

    # Monthly aggregation of referral earnings
    monthly_data = (
        RefCoinTransaction.objects
        .filter(type__in=["earned", "bonus"], created_at__gte=twelve_months_ago)
        .annotate(month=TruncMonth("created_at"))
        .values("month")
        .annotate(
            total_earned=Sum("amount"),
            transaction_count=Count("id"),
        )
        .order_by("month")
    )

    # Monthly new referrals
    monthly_referrals = (
        Referral.objects
        .filter(created_at__gte=twelve_months_ago)
        .annotate(month=TruncMonth("created_at"))
        .values("month")
        .annotate(count=Count("id"))
        .order_by("month")
    )
    referral_by_month = {item["month"]: item["count"] for item in monthly_referrals}

    # Monthly new profiles (sign-ups)
    monthly_profiles = (
        ReferralProfile.objects
        .filter(created_at__gte=twelve_months_ago)
        .annotate(month=TruncMonth("created_at"))
        .values("month")
        .annotate(count=Count("id"))
        .order_by("month")
    )
    profiles_by_month = {item["month"]: item["count"] for item in monthly_profiles}

    # Build monthly history
    history = []
    earnings_values = []
    for item in monthly_data:
        month = item["month"]
        earned = float(item["total_earned"] or 0)
        earnings_values.append(earned)
        history.append({
            "month": month.strftime("%Y-%m"),
            "month_label": month.strftime("%b %Y"),
            "total_earned": earned,
            "transaction_count": item["transaction_count"],
            "new_referrals": referral_by_month.get(month, 0),
            "new_profiles": profiles_by_month.get(month, 0),
        })

    # Projections: simple linear trend + moving average for next 3 months
    projections = []
    if len(earnings_values) >= 2:
        # Use last 6 months for trend
        recent = earnings_values[-6:] if len(earnings_values) >= 6 else earnings_values
        avg_earning = statistics.mean(recent)
        # Simple growth rate
        if len(recent) >= 2 and recent[0] > 0:
            growth_rate = (recent[-1] - recent[0]) / (len(recent) - 1) / recent[0]
        else:
            growth_rate = 0

        for i in range(1, 4):
            projected_month = now + timedelta(days=30 * i)
            projected_earnings = avg_earning * (1 + growth_rate * i)
            projections.append({
                "month": projected_month.strftime("%Y-%m"),
                "month_label": projected_month.strftime("%b %Y"),
                "projected_earned": round(max(projected_earnings, 0), 2),
                "confidence": "high" if len(recent) >= 4 else "low",
            })
    elif len(earnings_values) == 1:
        for i in range(1, 4):
            projected_month = now + timedelta(days=30 * i)
            projections.append({
                "month": projected_month.strftime("%Y-%m"),
                "month_label": projected_month.strftime("%b %Y"),
                "projected_earned": earnings_values[0],
                "confidence": "low",
            })

    # Summary metrics
    total_all_time = float(
        RefCoinTransaction.objects.filter(type__in=["earned", "bonus"]).aggregate(s=Sum("amount"))["s"] or 0
    )
    this_month_earned = float(
        RefCoinTransaction.objects.filter(
            type__in=["earned", "bonus"],
            created_at__year=now.year,
            created_at__month=now.month,
        ).aggregate(s=Sum("amount"))["s"] or 0
    )
    last_month = now - timedelta(days=30)
    last_month_earned = float(
        RefCoinTransaction.objects.filter(
            type__in=["earned", "bonus"],
            created_at__year=last_month.year,
            created_at__month=last_month.month,
        ).aggregate(s=Sum("amount"))["s"] or 0
    )
    mom_growth = None
    if last_month_earned > 0:
        mom_growth = round(((this_month_earned - last_month_earned) / last_month_earned) * 100, 1)

    return Response({
        "history": history,
        "projections": projections,
        "summary": {
            "total_all_time_earned": total_all_time,
            "this_month_earned": this_month_earned,
            "last_month_earned": last_month_earned,
            "mom_growth_percent": mom_growth,
            "avg_monthly": round(statistics.mean(earnings_values), 2) if earnings_values else 0,
        },
    })


# ── Mail Configuration ────────────────────────────────────────────────────────

from .models import MailConfiguration
from .serializers import MailConfigurationSerializer
from .mailer import send_test_mail


@api_view(["GET", "PUT", "PATCH"])
@permission_classes([IsSuperAdmin])
def mail_config(request):
    """Retrieve or update the platform mail configuration (singleton)."""
    cfg = MailConfiguration.get_solo()

    if request.method == "GET":
        return Response(MailConfigurationSerializer(cfg).data)

    serializer = MailConfigurationSerializer(cfg, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(MailConfigurationSerializer(cfg).data)


@api_view(["POST"])
@permission_classes([IsSuperAdmin])
def mail_config_test(request):
    """Send a test email to verify the mail configuration."""
    to = request.data.get("to") or getattr(request.user, "email", None)
    if not to:
        return Response(
            {"detail": "No recipient address provided."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    ok, error = send_test_mail(to)
    if ok:
        return Response({"ok": True, "detail": f"Test email sent to {to}."})
    return Response(
        {"ok": False, "detail": error or "Failed to send test email."},
        status=status.HTTP_502_BAD_GATEWAY,
    )

