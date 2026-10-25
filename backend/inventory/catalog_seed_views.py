"""Clinic catalog seed endpoints.

Clinic tenants reuse the shared Category/Unit models inside their own
tenant schema. These endpoints expose a curated seed catalog for the clinic
Catalog workspace — for now only the categories & units reference data
(the same `seed_pharmacy_stock --categories-only` command the pharmacy and
inventory tenants use, minus the stock/branch requirements).

Every executed seed is persisted in ``CatalogSeedRun`` so the Catalog →
Seed Data page can show a durable run history (who seeded what, when and
whether it worked) instead of losing it on page reload.
"""
import time

from django.core.management import call_command
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import CatalogSeedRun
from .serializers import CatalogSeedRunSerializer

# Only reference-data seeds for now — no stock, medications or interactions.
CLINIC_CATALOG_SEED_COMMANDS = {
    "categories_units": {
        "label": "Categories & Units",
        "description": "35 stock categories and 24 measurement units for the clinic catalog",
        "command": "seed_pharmacy_stock",
        "args": {"skip_existing": True, "categories_only": True},
        "counter": "categories_units",
    },
    "allergies": {
        "label": "Allergies",
        "description": "~74 common allergies copied from the platform clinical catalog into this clinic",
        "command": "seed_clinic_catalog",
        "args": {"allergies": True},
        "counter": "allergies",
    },
    "chronic_conditions": {
        "label": "Chronic Conditions",
        "description": "~100 chronic conditions with ICD-10 codes copied from the platform clinical catalog",
        "command": "seed_clinic_catalog",
        "args": {"conditions": True},
        "counter": "chronic_conditions",
    },
}

ALLOWED_CLINIC_SEED_ROLES = {"tenant_admin", "clinic_admin", "admin"}


def _count_records(counter_key):
    """Snapshot the number of reference rows a seed command targets.

    Counts are taken before/after the command so the delta is a true
    "created" figure for the run history.
    """
    try:
        if counter_key == "categories_units":
            from .models import Category, Unit
            return Category.objects.count() + Unit.objects.count()
        if counter_key == "allergies":
            from clinic_catalog.models import ClinicAllergy
            return ClinicAllergy.objects.count()
        if counter_key == "chronic_conditions":
            from clinic_catalog.models import ClinicChronicCondition
            return ClinicChronicCondition.objects.count()
    except Exception:
        # Missing table / app not installed in this tenant — treat as zero.
        return 0
    return 0


def _user_label(user):
    if not user or not getattr(user, 'is_authenticated', False):
        return ''
    full = f'{user.first_name or ""} {user.last_name or ""}'.strip()
    return full or getattr(user, 'email', '') or getattr(user, 'username', '')


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def clinic_seed_catalog(request):
    """Return the available clinic catalog seed commands."""
    if request.user.role not in ALLOWED_CLINIC_SEED_ROLES:
        return Response(
            {"detail": "You do not have permission to seed data."},
            status=status.HTTP_403_FORBIDDEN,
        )
    items = [
        {
            "key": key,
            "label": info["label"],
            "description": info["description"],
        }
        for key, info in CLINIC_CATALOG_SEED_COMMANDS.items()
    ]
    return Response(items)


@api_view(["GET", "DELETE"])
@permission_classes([IsAuthenticated])
def clinic_seed_history(request):
    """Catalog-seed run history for this clinic.

    GET  – list runs. Query params:
              limit   – max rows to return (default 25, max 200)
              command – filter by seed key, e.g. ``allergies``
              status  – ``success`` or ``failed``
    DELETE – clear runs (optionally filtered by ``command``).
    """
    if request.method == "DELETE":
        if request.user.role not in ALLOWED_CLINIC_SEED_ROLES:
            return Response(
                {"detail": "You do not have permission to clear seed history."},
                status=status.HTTP_403_FORBIDDEN,
            )
        qs = CatalogSeedRun.objects.all()
        command = request.query_params.get("command")
        if command:
            qs = qs.filter(command_key=command)
        deleted, _ = qs.delete()
        return Response({
            "detail": f"Cleared {deleted} history entr{'y' if deleted == 1 else 'ies'}.",
            "deleted": deleted,
        })

    try:
        limit = min(int(request.query_params.get("limit") or 25), 200)
    except (TypeError, ValueError):
        limit = 25

    qs = CatalogSeedRun.objects.all()

    command = request.query_params.get("command")
    if command:
        qs = qs.filter(command_key=command)

    run_status = request.query_params.get("status")
    if run_status in dict(CatalogSeedRun.Status.choices):
        qs = qs.filter(status=run_status)

    serializer = CatalogSeedRunSerializer(qs[:limit], many=True)
    return Response({
        "results": serializer.data,
        "count": qs.count(),
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def clinic_run_seed(request):
    """
    Run a clinic catalog seed command for the current tenant and persist
    the outcome in the run history.

    Body: { "command": "categories_units" }
    """
    if request.user.role not in ALLOWED_CLINIC_SEED_ROLES:
        return Response(
            {"detail": "You do not have permission to seed data."},
            status=status.HTTP_403_FORBIDDEN,
        )

    cmd_key = request.data.get("command", "")
    if cmd_key not in CLINIC_CATALOG_SEED_COMMANDS:
        return Response(
            {"detail": f"Unknown seed command: {cmd_key}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    info = CLINIC_CATALOG_SEED_COMMANDS[cmd_key]
    counter_key = info.get("counter")
    before = _count_records(counter_key) if counter_key else 0

    started = time.monotonic()
    try:
        call_command(info["command"], **info.get("args", {}))
        duration_ms = int((time.monotonic() - started) * 1000)
        created = max(0, _count_records(counter_key) - before) if counter_key else 0
        detail = f"'{info['label']}' seeded successfully."

        run = CatalogSeedRun.objects.create(
            command_key=cmd_key,
            label=info["label"],
            status=CatalogSeedRun.Status.SUCCESS,
            detail=detail,
            duration_ms=duration_ms,
            records_created=created,
            run_by=request.user if request.user.is_authenticated else None,
            run_by_label=_user_label(request.user),
        )
        return Response({
            "detail": detail,
            "command": cmd_key,
            "records_created": created,
            "duration_ms": duration_ms,
            "run": CatalogSeedRunSerializer(run).data,
        })
    except Exception as e:
        duration_ms = int((time.monotonic() - started) * 1000)
        message = f"Seed failed: {str(e)}"

        CatalogSeedRun.objects.create(
            command_key=cmd_key,
            label=info["label"],
            status=CatalogSeedRun.Status.FAILED,
            detail=message,
            duration_ms=duration_ms,
            records_created=0,
            run_by=request.user if request.user.is_authenticated else None,
            run_by_label=_user_label(request.user),
        )
        return Response({"detail": message}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
