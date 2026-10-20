"""Demo data API for the OHSMS module (SECURITY & SETTINGS → Demo data).

Endpoints (registered under ``/api/ohs/``):

    GET  demo-data/          dataset catalogue, run history and live totals
    POST demo-data/seed/     {"datasets": ["hazards", ...]}
    POST demo-data/clear/    {"datasets": [...]} | {"all": true} | {"run": "<uuid>"}

Everything here is tenant-admin only: seeding writes thousands of rows and
clearing deletes data, so it must never be reachable by a read-only role.
Every mutation is written to the tenant audit log.
"""
from django.db import connection
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from audit.utils import log_event

from . import demo_data
from .models import DemoDataRun
from .rbac import has_capability


def _can_manage(request):
    user = getattr(request, 'user', None)
    role = getattr(user, 'role', '') or ''
    if role in ('tenant_admin', 'admin', 'super_admin') or getattr(user, 'is_superuser', False):
        return True
    return has_capability(request, 'demo.manage')


def _forbidden():
    return Response(
        {'detail': 'You need tenant administrator rights to manage demo data.'},
        status=status.HTTP_403_FORBIDDEN,
    )


class OhsDemoDataOverviewView(APIView):
    """Catalogue + history for the Demo data page."""

    def get(self, request):
        if not _can_manage(request):
            return _forbidden()
        data = demo_data.overview()
        data['can_manage'] = True
        data['schema'] = connection.schema_name
        return Response(data)


class OhsDemoDataSeedView(APIView):
    """Seed the selected datasets (prerequisites are added automatically)."""

    def post(self, request):
        if not _can_manage(request):
            return _forbidden()

        raw = request.data.get('datasets')
        if raw in (None, '', []):
            return Response(
                {'detail': 'Choose at least one dataset to seed.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if isinstance(raw, str):
            raw = [k.strip() for k in raw.split(',') if k.strip()]

        try:
            keys = demo_data.expand(list(raw))
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        try:
            run = demo_data.seed(
                keys, user=request.user, reset=bool(request.data.get('reset')),
            )
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        log_event(
            request=request,
            action='seed',
            object_type='ohs/demo_data',
            object_id=str(run.run_id),
            object_repr=', '.join(keys),
            description=f'Seeded demo data: {run.objects_created} objects',
            extra={
                'datasets': keys,
                'objects_created': run.objects_created,
                'status': run.status,
            },
            severity='warning',
        )

        payload = {
            'run_id': str(run.run_id),
            'datasets': run.datasets,
            'summary': run.summary,
            'objects_created': run.objects_created,
            'status': run.status,
            'error': run.error,
            'duration_ms': run.duration_ms,
        }
        if run.status == DemoDataRun.Status.FAILED:
            payload['hint'] = (
                'Some demo records for these datasets already exist, so the seeder '
                'hit a duplicate reference. Use "Clear & re-seed" to replace the '
                'existing demo data, or clear it first.'
            )
            return Response(payload, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response(payload, status=status.HTTP_201_CREATED)


class OhsDemoDataClearView(APIView):
    """Delete demo objects only. Real records are never touched."""

    def post(self, request):
        if not _can_manage(request):
            return _forbidden()

        run = None
        run_uuid = (request.data.get('run') or '').strip()
        if run_uuid:
            run = DemoDataRun.objects.filter(run_id=run_uuid).first()
            if run is None:
                return Response(
                    {'detail': 'That demo run no longer exists.'},
                    status=status.HTTP_404_NOT_FOUND,
                )

        datasets = request.data.get('datasets') or None
        if isinstance(datasets, str):
            datasets = [k.strip() for k in datasets.split(',') if k.strip()]
        clear_all = bool(request.data.get('all')) or (run is None and not datasets)

        if not clear_all and not datasets and run is None:
            return Response(
                {'detail': 'Nothing selected to clear.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        result = demo_data.clear(
            datasets=None if clear_all else datasets,
            run=run,
        )

        log_event(
            request=request,
            action='delete',
            object_type='ohs/demo_data',
            object_id=str(run.run_id) if run else '',
            object_repr=', '.join(datasets) if datasets else 'all demo data',
            description=f'Cleared demo data: {result["deleted"]} objects removed',
            extra={'deleted': result['deleted'], 'models': result['models']},
            severity='critical',
        )

        return Response({
            'deleted': result['deleted'],
            'models': result['models'],
            'errors': result['errors'],
        })
