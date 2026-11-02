"""API surface for the Business-Intelligence report pack.

``GET  /api/inventory/reports/bi/catalog/``   — the sections that can be included
``POST /api/inventory/reports/bi/preview/``   — the computed dataset for on-screen
``POST /api/inventory/reports/bi/generate/``  — the premium PDF

The three endpoints share :func:`_payload`, so the preview and the document can
never disagree about which sections were kept or which window was used.
"""
from __future__ import annotations

import logging

from django.http import HttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from ..rbac import InventoryPermission
from . import bi

logger = logging.getLogger(__name__)


def _forced_branch(user):
    try:
        from config.branch_scope import get_scoped_branch_id
        return get_scoped_branch_id(user)
    except Exception:
        return None


def _data(request):
    return (request.data if request.method == 'POST' else request.query_params) or {}


def _payload(request):
    """Resolve window + sections once, for both preview and export."""
    data = _data(request)

    branch_id = _forced_branch(request.user) or data.get('branch') or None
    if branch_id in ('', 'all', 'null', None):
        branch_id = _forced_branch(request.user)
    try:
        branch_id = int(branch_id) if branch_id else None
    except (TypeError, ValueError):
        branch_id = _forced_branch(request.user)

    # An explicit empty list means "no sections" — see bi.resolve_sections.
    requested = data.get('sections')
    if requested is None and 'sections[]' in data:
        requested = data.getlist('sections[]')
    sections = bi.resolve_sections(requested)

    try:
        from ..rbac import can_view_cost as _can
        allow_cost = _can(request)
    except Exception:
        allow_cost = True
    if not allow_cost:
        sections = [s for s in sections
                    if not bi.SECTIONS_BY_ID[s]['needs_cost']]

    dataset = bi.build_bi_dataset(
        request,
        date_from=data.get('date_from') or None,
        date_to=data.get('date_to') or None,
        branch_id=branch_id,
    )
    dataset['narrative'] = bi.build_narrative(dataset)
    dataset['actions'] = bi.build_recommendations(dataset)
    return data, sections, dataset, branch_id


class BiReportCatalogView(APIView):
    """The section list the picker needs."""

    permission_classes = [InventoryPermission]

    def get(self, request):
        payload = bi.catalog_payload(request)
        tenant = getattr(request, 'tenant', None)
        payload['defaults'] = {
            'sections': payload['defaults'],
            'watermark': (getattr(tenant, 'name', '') or 'CONFIDENTIAL'),
            'watermark_opacity': 0.30,
            'title': 'Business Intelligence Report',
        }
        payload['brand'] = {
            'name': getattr(tenant, 'name', '') or '',
            'type': getattr(tenant, 'type', '') or '',
        }
        return Response(payload)


class BiReportPreviewView(APIView):
    """The dataset for the selected sections, formatted for the screen."""

    permission_classes = [InventoryPermission]

    def post(self, request):
        _, sections, dataset, _branch = _payload(request)
        forecast = dataset.get('forecast') or {}
        root = dataset.get('root_cause') or {}
        optimization = dataset.get('optimization') or {}
        operational = dataset.get('operational') or {}
        return Response({
            'sections': sections,
            'scope': dataset['scope'],
            'kpis': dataset['kpis'],
            'totals': dataset['totals'],
            'previous': dataset['previous'],
            'history': dataset['history'],
            'trend': dataset['trend'],
            'categories': dataset['categories'],
            'branches': dataset['branches'],
            'products': dataset['products'],
            'payments': dataset['payments'],
            'segments': dataset['segments'],
            'stock_health': dataset['stock_health'],
            'stock_totals': dataset['stock_totals'],
            'narrative': dataset['narrative'],
            'actions': dataset['actions'],
            'span_days': dataset['span_days'],
            # Advanced blocks, trimmed to what the preview renders.
            'forecast': {
                'available': forecast.get('available', False),
                'reason': forecast.get('reason'),
                'method': forecast.get('method'),
                'horizon': forecast.get('horizon'),
                'next_value': forecast.get('next_value'),
                'total_forecast': forecast.get('total_forecast'),
                'slope': forecast.get('slope'),
                'direction': forecast.get('direction'),
                'accuracy': forecast.get('accuracy'),
                'forecast': (forecast.get('forecast') or [])[:6],
                'findings': dataset.get('forecast_findings') or [],
            },
            'root_cause': {
                'net_change': root.get('net_change'),
                'delta_pct': root.get('delta_pct'),
                'verdict': root.get('verdict'),
                'bridge': root.get('bridge') or [],
                'drivers': root.get('drivers') or [],
                'leakage': root.get('leakage') or [],
                'lost_revenue': root.get('lost_revenue'),
                'stockouts': (root.get('stockouts') or [])[:5],
            } if root else None,
            'optimization': {
                'pricing': (optimization.get('pricing') or [])[:5],
                'pricing_upside': optimization.get('pricing_upside'),
                'replenishment': (optimization.get('replenishment') or [])[:5],
                'replenishment_value': optimization.get('replenishment_value'),
                'markdown': (optimization.get('markdown') or [])[:5],
                'markdown_recovery': optimization.get('markdown_recovery'),
                'at_target': optimization.get('at_target'),
                'actions': optimization.get('actions') or [],
            } if optimization else None,
            'operational': {
                'tiles': operational.get('tiles') or [],
                'analytical_count': operational.get('analytical_count', 0),
                'tabular_count': operational.get('tabular_count', 0),
                'analytical_groups': [
                    {'label': g['label'], 'count': len(g['items'])}
                    for g in operational.get('analytical_groups') or []
                ],
            } if operational else None,
        })


class BiReportGenerateView(APIView):
    """Render the BI pack as a premium PDF."""

    permission_classes = [InventoryPermission]

    def post(self, request):
        data, sections, dataset, _branch = _payload(request)
        if not sections:
            return Response(
                {'detail': 'Select at least one section to include.'},
                status=status.HTTP_400_BAD_REQUEST)

        title = (data.get('title') or 'Business Intelligence Report').strip()[:120]
        subtitle = (data.get('subtitle') or '').strip()[:160]
        watermark = (data.get('watermark') or '').strip()
        if watermark.lower() in ('', 'none', 'off', 'false'):
            watermark = ''

        try:
            opacity = float(data.get('watermark_opacity') or 0.30)
        except (TypeError, ValueError):
            opacity = 0.30
        opacity = max(0.05, min(opacity, 0.60))

        from config.pdf_branding import resolve_branding, resolve_palette
        try:
            logo_path, business_name = resolve_branding(request)
            palette = resolve_palette(request)
        except Exception:
            logo_path, business_name, palette = None, '', None

        tenant = getattr(request, 'tenant', None)
        org = {
            'name': getattr(tenant, 'name', '') or business_name or '',
            'address': getattr(tenant, 'address', '') or '',
            'city': getattr(tenant, 'city', '') or '',
            'country': getattr(tenant, 'country', '') or '',
            'phone': getattr(tenant, 'phone', '') or '',
            'email': getattr(tenant, 'email', '') or '',
            'website': getattr(tenant, 'website', '') or '',
        }
        business_name = org['name'] or business_name

        from .bi_render import render_bi_pdf
        try:
            body = render_bi_pdf(
                dataset=dataset, sections=sections, org=org,
                logo_path=logo_path, palette=palette,
                business_name=business_name, title=title,
                subtitle=subtitle or ' · '.join(dataset['scope']),
                watermark=watermark, watermark_opacity=opacity,
            )
        except Exception:
            logger.exception('BI report render failed')
            return Response({'detail': 'Could not build this report.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        stamp = timezone.localtime(timezone.now()).strftime('%Y%m%d-%H%M')
        response = HttpResponse(body, content_type='application/pdf')
        response['Content-Disposition'] = (
            f'attachment; filename="bi-report-{stamp}.pdf"')
        response['X-BI-Sections'] = str(len(sections))

        try:
            from ..views.base import _audit
            _audit(request, 'report_export', 'bi_report',
                   description=f'Exported the BI report '
                               f'({len(sections)} sections)')
        except Exception:
            logger.exception('could not audit the BI report export')
        return response
