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
from rest_framework.response import Response

from tenants.models import Domain, Tenant

from .permissions import IsSuperAdmin
from .serializers import (
    TenantAdminSerializer,
    TenantCreateSerializer,
    UserAdminSerializer,
    UserAdminUpdateSerializer,
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
    "pharmacy_stock": {
        "label": "Pharmacy Stock",
        "description": "150+ medication stock items with prices, categories & units",
        "scope": "tenant",
        "command": "seed_pharmacy_stock",
    },
    "lab_tests": {
        "label": "Lab Test Catalog",
        "description": "~75 lab tests (hematology, biochemistry, microbiology, etc.)",
        "scope": "tenant",
        "command": "seed_lab_tests",
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
    reset = request.data.get("reset", False)

    if cmd_key not in SEED_COMMANDS:
        return Response(
            {"detail": f"Unknown seed command: {cmd_key}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    info = SEED_COMMANDS[cmd_key]

    # Tenant-scoped commands need a tenant
    if info["scope"] == "tenant":
        if not tenant_id:
            return Response(
                {"detail": "tenant_id is required for this seed command."},
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
            if reset and cmd_key == "pharmacy_stock":
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
        call_command(info["command"])
    except Exception as e:
        return Response(
            {"detail": f"Seed failed: {e}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return Response({
        "detail": f"'{info['label']}' seeded successfully (global).",
        "command": cmd_key,
    })
