"""Production-facing equipment seeding.

The ``/clinics/seed-data`` page runs these endpoints. Two packs exist because a
live clinic and a demo/training clinic need completely different things:

* ``categories``      — reference data only. Idempotent and safe to run on a
                        production tenant; it never creates fictional assets.
* ``demo_estate``     — 44 sample assets with maintenance history, faults and
                        transfers. Gated behind an explicit ``confirm_demo``
                        flag so nobody seeds invented assets into a live
                        clinic by clicking the wrong button.

Every run is written to ``EquipmentSeedRun`` so the page can show durable
history instead of losing it on reload.
"""

import time

from django.core.management import call_command
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import (
    Equipment,
    EquipmentCategory,
    EquipmentFault,
    EquipmentMaintenance,
    EquipmentSeedRun,
    EquipmentTransfer,
)

ALLOWED_SEED_ROLES = {
    'tenant_admin', 'clinic_admin', 'admin', 'super_admin', 'branch_admin',
    'inventory_admin',
}

SEED_PACKS = {
    'categories': {
        'label': 'Equipment categories',
        'description': (
            'Reference catalogue of equipment classes (imaging, monitoring, laboratory, '
            'theatre, life support, dental, sterilisation, physiotherapy, IT, maternity, '
            'cold chain) with their servicing and calibration intervals.'
        ),
        'safe_for_production': True,
        'creates_demo_assets': False,
        'command': 'seed_equipment',
        'args': {'categories_only': True},
        'counters': ('categories_created',),
    },
    'demo_estate': {
        'label': 'Demo equipment estate',
        'description': (
            '44 sample assets across every category, plus maintenance history, '
            'scheduled jobs, reported faults and branch transfers. For training, '
            'demos and staging tenants — do not run on a live clinic.'
        ),
        'safe_for_production': False,
        'creates_demo_assets': True,
        'command': 'seed_equipment',
        'args': {'demo': True},
        'counters': ('categories_created', 'assets_created', 'jobs_created',
                     'faults_created', 'transfers_created'),
    },
}


def _counts():
    """Snapshot the row counts each pack can affect."""
    try:
        return {
            'categories': EquipmentCategory.objects.count(),
            'assets': Equipment.objects.count(),
            'jobs': EquipmentMaintenance.objects.count(),
            'faults': EquipmentFault.objects.count(),
            'transfers': EquipmentTransfer.objects.count(),
        }
    except Exception:
        # Table missing in this schema — treat as empty.
        return {'categories': 0, 'assets': 0, 'jobs': 0, 'faults': 0, 'transfers': 0}


def _user_label(user):
    if not user or not getattr(user, 'is_authenticated', False):
        return ''
    full = f'{user.first_name or ""} {user.last_name or ""}'.strip()
    return full or getattr(user, 'email', '') or getattr(user, 'username', '') or ''


def _forbidden():
    return Response(
        {'detail': 'Only clinic administrators can seed equipment data.'},
        status=status.HTTP_403_FORBIDDEN,
    )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def equipment_seed_catalog(request):
    """Available equipment seed packs plus what already exists."""
    if request.user.role not in ALLOWED_SEED_ROLES:
        return _forbidden()

    counts = _counts()
    packs = []
    for key, info in SEED_PACKS.items():
        packs.append({
            'key': key,
            'label': info['label'],
            'description': info['description'],
            'safe_for_production': info['safe_for_production'],
            'creates_demo_assets': info['creates_demo_assets'],
            'preview': info.get('preview', {}),
        })

    return Response({
        'packs': packs,
        'counts': counts,
        'is_empty': counts['assets'] == 0,
    })


@api_view(['GET', 'DELETE'])
@permission_classes([IsAuthenticated])
def equipment_seed_history(request):
    """Seed run history for this clinic.

    GET    – list runs (``?limit=`` max 200, ``?status=success|failed``).
    DELETE – clear history rows (does not touch equipment data).
    """
    if request.user.role not in ALLOWED_SEED_ROLES:
        return _forbidden()

    if request.method == 'DELETE':
        qs = EquipmentSeedRun.objects.all()
        pack = request.query_params.get('pack')
        if pack:
            qs = qs.filter(pack_key=pack)
        deleted, _ = qs.delete()
        return Response({
            'detail': f'Cleared {deleted} history entr{"y" if deleted == 1 else "ies"}.',
            'deleted': deleted,
        })

    try:
        limit = min(int(request.query_params.get('limit') or 20), 200)
    except (TypeError, ValueError):
        limit = 20

    qs = EquipmentSeedRun.objects.all()
    run_status = request.query_params.get('status')
    if run_status in dict(EquipmentSeedRun.Status.choices):
        qs = qs.filter(status=run_status)

    rows = [
        {
            'id': run.pk,
            'pack_key': run.pack_key,
            'label': run.label,
            'status': run.status,
            'detail': run.detail,
            'records_created': run.records_created,
            'categories_created': run.categories_created,
            'assets_created': run.assets_created,
            'jobs_created': run.jobs_created,
            'faults_created': run.faults_created,
            'transfers_created': run.transfers_created,
            'duration_ms': run.duration_ms,
            'run_by_label': run.run_by_label,
            'created_at': run.created_at,
        }
        for run in qs[:limit]
    ]
    return Response({'results': rows, 'count': qs.count()})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def equipment_run_seed(request):
    """Execute an equipment seed pack for the current tenant.

    Body:
        { "pack": "categories" }
        { "pack": "demo_estate", "confirm_demo": true }

    ``demo_estate`` refuses to run without ``confirm_demo`` — that guard is the
    only thing standing between a live clinic and 44 invented assets.
    """
    if request.user.role not in ALLOWED_SEED_ROLES:
        return _forbidden()

    pack_key = (request.data.get('pack') or '').strip()
    if pack_key not in SEED_PACKS:
        return Response(
            {'detail': f'Unknown seed pack: {pack_key or "(none)"}'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    info = SEED_PACKS[pack_key]

    # Production guard: demo assets require an explicit acknowledgement.
    if info['creates_demo_assets'] and not bool(request.data.get('confirm_demo')):
        return Response(
            {
                'detail': (
                    'This pack creates demo assets, faults and transfers. '
                    'Re-send with "confirm_demo": true to proceed.'
                ),
                'requires_confirmation': True,
                'pack': pack_key,
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    before = _counts()
    started = time.monotonic()

    try:
        call_command(info['command'], **info.get('args', {}))
    except Exception as exc:  # noqa: BLE001 — surface the reason to the operator
        duration_ms = int((time.monotonic() - started) * 1000)
        message = f'Seed failed: {exc}'
        run = EquipmentSeedRun.objects.create(
            pack_key=pack_key,
            label=info['label'],
            status=EquipmentSeedRun.Status.FAILED,
            detail=message,
            duration_ms=duration_ms,
            run_by=request.user,
            run_by_label=_user_label(request.user),
        )
        return Response(
            {'detail': message, 'pack': pack_key, 'run': {'id': run.pk}},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    duration_ms = int((time.monotonic() - started) * 1000)
    after = _counts()
    delta = {
        'categories': max(0, after['categories'] - before['categories']),
        'assets': max(0, after['assets'] - before['assets']),
        'jobs': max(0, after['jobs'] - before['jobs']),
        'faults': max(0, after['faults'] - before['faults']),
        'transfers': max(0, after['transfers'] - before['transfers']),
    }
    total = sum(delta.values())

    detail = (
        f'{info["label"]}: {total} new record{"s" if total != 1 else ""} created.'
        if total
        else f'{info["label"]}: already up to date — nothing new to create.'
    )

    run = EquipmentSeedRun.objects.create(
        pack_key=pack_key,
        label=info['label'],
        status=EquipmentSeedRun.Status.SUCCESS,
        detail=detail,
        categories_created=delta['categories'],
        assets_created=delta['assets'],
        jobs_created=delta['jobs'],
        faults_created=delta['faults'],
        transfers_created=delta['transfers'],
        duration_ms=duration_ms,
        run_by=request.user,
        run_by_label=_user_label(request.user),
    )

    return Response({
        'detail': detail,
        'pack': pack_key,
        'created': delta,
        'records_created': total,
        'duration_ms': duration_ms,
        'counts': after,
        'run': {
            'id': run.pk,
            'label': run.label,
            'status': run.status,
            'created_at': run.created_at,
            'run_by_label': run.run_by_label,
        },
    })
