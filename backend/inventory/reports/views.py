"""API surface for the inventory report platform.

``GET  /api/inventory/reports/catalog/``   — reports, columns, categories
``POST /api/inventory/reports/preview/``   — formatted rows for the on-screen table
``POST /api/inventory/reports/generate/``  — PDF / Excel / CSV download

Every endpoint runs the same selection pipeline
(:func:`_resolve`) so the preview table, the PDF and the spreadsheet can never
disagree about which columns or rows were chosen.
"""
from __future__ import annotations

import logging
from datetime import timedelta

from django.http import HttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from ..rbac import InventoryPermission, can_view_cost
from . import datasets
from .catalog import CATEGORIES, catalog_payload, get_report, sanitize_columns
from .datasets import COST_COLUMNS, parse_date

logger = logging.getLogger(__name__)

#: Hard ceiling on exported rows — keeps a 50k-row tenant from timing out.
MAX_ROWS = 20000


def _forced_branch(user):
    try:
        from config.branch_scope import get_scoped_branch_id
        return get_scoped_branch_id(user)
    except Exception:
        return None


def _request_data(request):
    """Body for POSTs, query string for GETs — one dict either way."""
    if request.method == 'POST':
        return request.data or {}
    return request.query_params


def _resolve(request):
    """Turn a request into ``(report, columns, context)`` or an error payload.

    Shared by preview and generate so a column the caller excluded in the
    preview is also excluded from the download.
    """
    data = _request_data(request)
    report = get_report(data.get('report'))
    if report is None:
        return None, None, ({"detail": "Unknown report."}, 400)

    columns = sanitize_columns(report, data.get('columns'))
    if not can_view_cost(request):
        # Cost-bearing columns are removed entirely for till roles: printing
        # them as "—" would still advertise what the sheet contains.
        columns = [c for c in columns if c['key'] not in COST_COLUMNS]
        if not columns:
            return None, None, (
                {'detail': 'This report shows purchase cost, which your role '
                           'cannot view.'}, 403)

    branch_id = _forced_branch(request.user) or data.get('branch') or None
    if branch_id in ('', 'all', 'null', None):
        branch_id = _forced_branch(request.user)
    try:
        branch_id = int(branch_id) if branch_id else None
    except (TypeError, ValueError):
        branch_id = _forced_branch(request.user)

    try:
        limit = int(data.get('limit') or 5000)
    except (TypeError, ValueError):
        limit = 5000
    limit = max(1, min(limit, MAX_ROWS))

    context = {
        'report': report,
        'branch_id': branch_id,
        'date_from': data.get('date_from') or None,
        'date_to': data.get('date_to') or None,
        'group_by': (data.get('group_by') or '').strip(),
        'limit': limit,
        'data': data,
    }
    return report, columns, context


def _build(context):
    """Run the dataset builder with the resolved filters."""
    report = context['report']
    builder = datasets.BUILDERS.get(report['id'])
    if builder is None:
        return {'rows': [], 'totals': {}, 'meta': {}}
    kwargs = {}
    if report['dated']:
        kwargs['date_from'] = context['date_from']
        kwargs['date_to'] = context['date_to']
    if report['branched']:
        kwargs['branch_id'] = context['branch_id']
    return builder(None, **kwargs)


def _scrub_rows(rows, columns):
    allowed = {c['key'] for c in columns}
    return [{k: v for k, v in row.items() if k in allowed} for row in rows]


def _visible_totals(totals, columns, report):
    """Totals the caller is allowed to see.

    A total is dropped only when it belongs to a *report column* the caller
    deselected (or a cost column their role cannot view — those are already
    absent from ``columns``). Aggregates that are not columns at all, such as
    ``net_quantity`` or ``units_sent``, must survive: they back the KPI tiles
    on the summary band, and filtering them out used to make "Net change"
    read 0 on every export.
    """
    column_keys = {c['key'] for c in columns}
    report_keys = {c['key'] for c in report['columns']}
    out = {}
    for key, value in (totals or {}).items():
        if key in report_keys and key not in column_keys:
            continue
        out[key] = value
    return out


def _summary_totals(totals, request):
    """Aggregates behind the summary-band KPI tiles.

    Deliberately independent of which columns the caller ticked: "Value at
    risk" must still read its figure when the user drops the money column from
    the detail table. Cost-bearing totals are still withheld from roles without
    ``stock.cost``.
    """
    out = dict(totals or {})
    if not can_view_cost(request):
        out = {k: v for k, v in out.items() if k not in COST_COLUMNS}
    return out


def _scope_lines(context, request):
    """Human scope for the letterhead / workbook block."""
    report = context['report']
    lines = []
    if report['dated']:
        start = parse_date(context['date_from'])
        end = parse_date(context['date_to'])
        if start or end:
            fmt = lambda d: d.strftime('%d %b %Y') if d else '…'
            lines.append(f'Period: {fmt(start)} - {fmt(end)}')
        else:
            lines.append('Period: all time')
    if context['branch_id']:
        try:
            from pharmacy_profile.models import Branch
            branch = Branch.objects.filter(id=context['branch_id']).first()
            lines.append(f'Warehouse: {branch.name if branch else context["branch_id"]}')
        except Exception:
            lines.append(f'Warehouse: #{context["branch_id"]}')
    elif report['branched']:
        lines.append('Warehouse: all warehouses')
    # ABC/XYZ is the one report whose *meaning* changes with the period, so say
    # which basis the letters came from — otherwise a reviewer cannot tell a
    # stored snapshot from a recomputation.
    if report['id'] == 'abc_analysis':
        start = parse_date(context['date_from'])
        end = parse_date(context['date_to'])
        lines.append('Classes recomputed from consumption in this period'
                     if (start or end)
                     else 'Classes from the stored planning snapshot')
    lines.append(context['report']['description'])
    return lines


def _summaries(report_id, totals, meta):
    """Up to four KPI tiles for the PDF summary band."""
    money = lambda v: f'KES {float(v or 0):,.2f}'
    count = lambda v: f'{int(v or 0):,}'
    percent = lambda v: f'{float(v or 0):,.1f}%'

    if report_id in ('stock_on_hand', 'low_stock'):
        out = meta.get('status_counts', {}).get('Out of stock', 0)
        expired = meta.get('status_counts', {}).get('Expired', 0)
        tiles = [
            {'label': 'Items', 'value': count(totals.get('items')
                                              or meta.get('items'))},
            {'label': 'Units on hand', 'value': count(totals.get('total_quantity'))},
            {'label': 'Out / expired', 'value': count(out + expired)},
        ]
        if totals.get('value_cost'):
            tiles.append({'label': 'Value at cost', 'value': money(totals['value_cost'])})
        return tiles[:4]

    if report_id == 'valuation':
        return [
            {'label': 'Items', 'value': count(meta.get('items'))},
            {'label': 'Value at cost', 'value': money(totals.get('value_cost'))},
            {'label': 'Value at retail', 'value': money(totals.get('value_retail'))},
            {'label': 'Gross margin', 'value': money(totals.get('margin'))},
        ]

    if report_id == 'dead_stock':
        return [
            {'label': 'Idle items', 'value': count(meta.get('items'))},
            {'label': 'Capital tied up', 'value': money(totals.get('value_cost'))},
            {'label': 'Stale window', 'value': f'{meta.get("window_days", 0)} days'},
        ]

    if report_id == 'movements':
        return [
            {'label': 'Units in', 'value': count(totals.get('quantity_in'))},
            {'label': 'Units out', 'value': count(totals.get('quantity_out'))},
            {'label': 'Net change', 'value': count(totals.get('net_quantity'))},
            {'label': 'Movements', 'value': count(meta.get('lines'))},
        ]

    if report_id == 'adjustments':
        return [
            {'label': 'Adjustments', 'value': count(meta.get('lines'))},
            {'label': 'Value removed', 'value': money(totals.get('value'))},
        ]

    if report_id == 'transfers':
        return [
            {'label': 'Transfers', 'value': count(meta.get('transfers'))},
            {'label': 'Units sent', 'value': count(totals.get('units_sent'))},
            {'label': 'Units received', 'value': count(totals.get('units_received'))},
            {'label': 'Variance', 'value': count(totals.get('variance'))},
        ]

    if report_id == 'cycle_count':
        return [
            {'label': 'Lines counted', 'value': count(totals.get('lines'))},
            {'label': 'Net variance', 'value': count(totals.get('variance'))},
            {'label': 'Variance value', 'value': money(totals.get('variance_value'))},
        ]

    if report_id == 'expiry':
        risks = meta.get('risk_counts', {})
        return [
            {'label': 'Batches', 'value': count(meta.get('batches'))},
            {'label': 'Expired', 'value': count(risks.get('Expired'))},
            {'label': 'Critical (≤7d)', 'value': count(risks.get('Critical'))},
            {'label': 'Value at risk', 'value': money(totals.get('value'))},
        ]

    if report_id == 'replenishment':
        return [
            {'label': 'Lines', 'value': count(totals.get('lines'))},
            {'label': 'Units to order', 'value': count(totals.get('suggested_quantity'))},
            {'label': 'Estimated spend', 'value': money(totals.get('estimated_cost'))},
        ]

    if report_id == 'abc_analysis':
        counts = meta.get('abc_counts', {})
        return [
            {'label': 'Items', 'value': count(totals.get('items'))},
            {'label': 'Class A', 'value': count(counts.get('A'))},
            {'label': 'Class B', 'value': count(counts.get('B'))},
            {'label': 'Class C', 'value': count(counts.get('C'))},
        ]

    if report_id == 'supplier_performance':
        return [
            {'label': 'Suppliers', 'value': count(totals.get('suppliers'))},
            {'label': 'Rated', 'value': count(totals.get('rated'))},
            {'label': 'Average score', 'value': count(totals.get('avg_score'))},
        ]

    if report_id == 'controlled_register':
        return [{'label': 'Records', 'value': count(totals.get('records'))}]

    return [{'label': 'Rows', 'value': count(len(meta.get('rows', []) or []))}]


#: Catalogue dimension → the key the dataset actually stores it under. Reports
#: name the same concept differently (`reason` vs `reason_label`), so without
#: this map a breakdown bucketed every row into "Unspecified".
DIMENSION_ROW_KEYS = {
    'type': 'movement_type',
    'reason': 'reason_label',
    'count': 'reference',
    'supplier': 'supplier_name',
}

#: Catalogue dimension → human label.
DIMENSION_LABELS = {
    'category': 'Category', 'classification': 'Type', 'branch': 'Warehouse',
    'status': 'Status', 'reason': 'Reason', 'status_label': 'Status',
    'type': 'Movement type', 'month': 'Expiry month',
    'source_branch': 'From warehouse', 'dest_branch': 'To warehouse',
    'count': 'Count sheet', 'action': 'Action', 'schedule': 'Schedule',
    'severity': 'Severity', 'abc_class': 'ABC class', 'xyz_class': 'XYZ class',
    'grade': 'Grade', 'risk': 'Risk', 'supplier': 'Supplier',
}

#: Columns that carry money, in the order a chart should prefer them.
VALUE_KEYS = ('value', 'value_cost', 'estimated_cost', 'variance_value',
              'value_retail')

#: Fallback numeric measures for reports without a money column.
QUANTITY_KEYS = ('on_hand', 'quantity_remaining', 'suggested_quantity',
                 'quantity_in', 'quantity_out', 'variance', 'available_quantity',
                 'quantity')


def _bucket_rows(rows, dimension, value_key=None):
    """Group raw rows by ``dimension``.

    Returns ``[(label, count, value)]`` sorted by count desc. ``value_key`` is
    supplied by the caller (never inferred here) so a role without ``stock.cost``
    can never have cost summed into a bucket.
    """
    if not dimension:
        return []
    buckets = {}
    alias = DIMENSION_ROW_KEYS.get(dimension)
    for row in rows:
        if dimension == 'month':
            raw = row.get('expiry_date')
            key = raw.strftime('%b %Y') if hasattr(raw, 'strftime') else 'No date'
        elif dimension == 'ymonth':
            raw = row.get('occurred_at') or row.get('created_at')
            key = raw.strftime('%b %Y') if hasattr(raw, 'strftime') else 'No date'
        else:
            # Prefer the literal key and fall back to the alias only when it is
            # genuinely absent — some reports populate both.
            key = row.get(dimension)
            if key in (None, '') and alias:
                key = row.get(alias)
            key = str(key) if key not in (None, '') else 'Unspecified'
        bucket = buckets.setdefault(key, {'count': 0, 'value': 0.0})
        bucket['count'] += 1
        if value_key:
            try:
                bucket['value'] += float(row.get(value_key) or 0)
            except (TypeError, ValueError):
                pass
    return [(key, b['count'], b['value'])
            for key, b in sorted(buckets.items(), key=lambda kv: -kv[1]['count'])]


def _breakdown_for(context, rows, columns, totals, meta):
    """Group the rows by the requested dimension into a small table."""
    dimension = context['group_by']
    report = context['report']
    if not dimension or dimension not in report['group_by']:
        return None

    value_key = next((candidate for candidate in VALUE_KEYS
                      if any(c['key'] == candidate for c in columns)), None)
    items = [
        {
            'label': label,
            'count': count,
            'value': (f'KES {value:,.2f}' if value_key else ''),
        }
        for label, count, value in _bucket_rows(rows, dimension, value_key)
    ]
    if not items:
        return None
    label = DIMENSION_LABELS.get(dimension, dimension.replace('_', ' ').title())
    return {'dimension': label, 'label': f'Breakdown by {label}', 'items': items}


# ── Charts ──────────────────────────────────────────────────────────────
def _chart_measure(rows, columns):
    """The column a chart should plot, restricted to what the caller may see.

    Only keys present in ``columns`` are considered — that list has already had
    cost columns stripped for roles without ``stock.cost``, so this can never
    leak a price into a chart.
    """
    if not rows:
        return None, 'int'
    sample = rows[0]
    for col in columns:
        if col['type'] == 'money' and col['key'] in sample:
            return col['key'], 'money'
    for col in columns:
        if col['type'] in ('int', 'num') and col['key'] in sample:
            return col['key'], 'int'
    for key in QUANTITY_KEYS:
        if any(c['key'] == key for c in columns) and key in sample:
            return key, 'int'
    return None, 'int'


def _label_key(rows):
    sample = rows[0] if rows else {}
    for key in ('medication_name', 'supplier_name', 'supplier', 'reference',
                'medication_id', 'label'):
        if key in sample:
            return key
    return None


def _fmt_measure(value, unit):
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        return '—'
    if unit == 'money':
        return f'KES {number:,.2f}'
    return f'{int(round(number)):,}'


def _abc_charts(rows, meta, columns):
    """Composition visuals for the ABC/XYZ study.

    The generic builder plots *one* measure across *one* dimension, which for
    this report produced a single donut of the ABC letters and missed the point:
    the reader needs the item share beside the value share, and the XYZ split
    next to it. Both are derived from the same class buckets the PDF prints.
    """
    charts = []
    class_summary = meta.get('class_summary') or []
    xyz_summary = meta.get('xyz_summary') or []
    has_value = any(c['key'] == 'value_share_pct' for c in columns)

    if class_summary:
        charts.append({
            'id': 'abc_value',
            'kind': 'donut' if len(class_summary) <= 5 else 'bar',
            'title': 'Share of value by ABC class' if has_value
                     else 'Items by ABC class',
            'subtitle': 'Classified value, split across the three bands',
            'unit': 'money' if has_value else 'int',
            'points': [{
                'label': f"Class {c['cls']}",
                'value': float(c.get('value_pct') or 0) if has_value
                         else float(c.get('count') or 0),
                'display': (f"{float(c.get('value_pct') or 0):.1f}%"
                            if has_value else f"{int(c.get('count') or 0):,}"),
            } for c in class_summary],
        })

    if class_summary:
        charts.append({
            'id': 'abc_items',
            'kind': 'bar',
            'title': 'Items per ABC class',
            'subtitle': 'How many SKUs sit in each band',
            'unit': 'int',
            'points': [{
                'label': f"Class {c['cls']}",
                'value': float(c.get('count') or 0),
                'display': f"{int(c.get('count') or 0):,}",
            } for c in class_summary],
        })

    if xyz_summary:
        charts.append({
            'id': 'xyz',
            'kind': 'bar',
            'title': 'Demand stability (XYZ)',
            'subtitle': 'X = steady, Y = seasonal, Z = erratic',
            'unit': 'int',
            'points': [{
                'label': f"Class {s['cls']}",
                'value': float(s.get('count') or 0),
                'display': f"{int(s.get('count') or 0):,}",
            } for s in xyz_summary],
        })
    return charts


def _charts_for(context, rows, columns, totals, meta):
    """Up to three visuals: composition, top movers and a monthly trend.

    Everything is derived from the same raw rows the table uses, so a chart can
    never disagree with the numbers beside it. Any failure returns ``[]`` — a
    chart is never allowed to break an export.
    """
    if not rows:
        return []
    report = context['report']
    if report['id'] == 'abc_analysis':
        return _abc_charts(rows, meta, columns)

    measure, unit = _chart_measure(rows, columns)
    measure_label = next((c['label'] for c in columns if c['key'] == measure),
                         'Records')
    charts = []

    # 1 ── Composition across the chosen dimension. Falls back to the report's
    #      first dimension so the panel is never empty when no breakdown is set.
    dimension = context['group_by'] or (report['group_by'][0] if report['group_by'] else '')
    if dimension in report['group_by']:
        buckets = _bucket_rows(rows, dimension, measure)[:8]
        if len(buckets) > 1:
            label = DIMENSION_LABELS.get(dimension,
                                         dimension.replace('_', ' ').title())
            charts.append({
                'id': 'distribution',
                'kind': 'donut' if len(buckets) <= 5 else 'bar',
                'title': f'{measure_label} by {label.lower()}',
                'subtitle': f'{len(buckets)} group'
                            f'{"s" if len(buckets) != 1 else ""} · '
                            f'{len(rows):,} rows',
                'unit': unit,
                'points': [
                    {'label': name,
                     'value': float(value if measure else count),
                     'display': _fmt_measure(value if measure else count,
                                             unit if measure else 'int')}
                    for name, count, value in buckets
                ],
            })

    # 2 ── Top movers: the biggest rows by the plotted measure.
    if measure:
        label_key = _label_key(rows)
        if label_key:
            ranked = sorted(rows,
                            key=lambda r: -_num(r.get(measure) or 0))[:8]
            points = [{
                'label': str(row.get(label_key) or '—')[:42],
                'value': _num(row.get(measure) or 0),
                'display': _fmt_measure(row.get(measure), unit),
            } for row in ranked if _num(row.get(measure) or 0)]
            if len(points) > 1:
                charts.append({
                    'id': 'top_items',
                    'kind': 'bar',
                    'title': f'Top {len(points)} by {measure_label}',
                    'subtitle': 'Largest rows in this selection',
                    'unit': unit,
                    'points': points,
                })

    # 3 ── Monthly trend, only for reports whose rows carry a date.
    date_key = next((key for key in ('occurred_at', 'created_at',
                                     'completed_at', 'expiry_date')
                     if rows and key in rows[0]), None)
    if date_key and measure:
        months = {}
        for row in rows:
            raw = row.get(date_key)
            if not hasattr(raw, 'strftime'):
                continue
            months[(raw.year, raw.month)] = (
                months.get((raw.year, raw.month), 0.0)
                + _num(row.get(measure) or 0))
        if len(months) > 1:
            ordered = sorted(months.items())[-12:]
            charts.append({
                'id': 'trend',
                'kind': 'line',
                'title': f'Monthly {measure_label.lower()}',
                'subtitle': f'By {date_key.replace("_", " ").title()} · '
                            f'{len(ordered)} month'
                            f'{"s" if len(ordered) != 1 else ""}',
                'unit': unit,
                'points': [{'label': _month_label(key),
                            'value': value,
                            'display': _fmt_measure(value, unit)}
                           for key, value in ordered],
            })

    return charts


def _month_label(key):
    """``(2026, 9)`` → ``'Sep 2026'`` without pulling in a formatter."""
    months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
    year, month = key
    return f'{months[max(0, min(int(month) - 1, 11))]} {year}'


def _num(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default



class ReportCatalogView(APIView):
    """Everything the picker and the configuration panel need."""

    permission_classes = [InventoryPermission]

    def get(self, request):
        payload = catalog_payload()
        if not can_view_cost(request):
            for report in payload['reports']:
                report['columns'] = [c for c in report['columns']
                                     if c['key'] not in COST_COLUMNS]
                report['defaults'] = [k for k in report['defaults']
                                      if any(c['key'] == k for c in report['columns'])]
        tenant = getattr(request, 'tenant', None)
        from .render import DEFAULT_WATERMARK_ALPHA
        payload['defaults'] = {
            'watermark': (getattr(tenant, 'name', '') or 'CONFIDENTIAL'),
            'watermark_opacity': DEFAULT_WATERMARK_ALPHA,
            'orientation': 'landscape',
        }
        payload['brand'] = {
            'name': getattr(tenant, 'name', '') or '',
            'type': getattr(tenant, 'type', '') or '',
        }
        return Response(payload)


class ReportPreviewView(APIView):
    """Formatted rows for the on-screen table (same shape as the PDF)."""

    permission_classes = [InventoryPermission]

    def post(self, request):
        report, columns, context = _resolve(request)
        if report is None:
            payload, code = context
            return Response(payload, status=code)

        result = _build(context)
        # Breakdowns group on dimensions that are usually NOT among the selected
        # columns, so they must read the raw rows — scrubbing first collapsed
        # every bucket into "Unspecified".
        raw_rows = (result['rows'] or [])[:context['limit']]
        rows = _scrub_rows(raw_rows, columns)
        totals = _visible_totals(result.get('totals'), columns, report)
        meta = result.get('meta') or {}

        from .render import format_value
        display = [
            {c['key']: format_value(row.get(c['key']), c['type']) for c in columns}
            for row in rows
        ]

        return Response({
            'report': report['id'],
            'label': report['label'],
            'columns': columns,
            'rows': display,
            'totals': totals,
            'scope': _scope_lines(context, request),
            'summaries': _summaries(
                report['id'], _summary_totals(result.get('totals'), request), meta),
            'breakdown': _breakdown_for(context, raw_rows, columns, totals, meta),
            'charts': _charts_for(context, raw_rows, columns, totals, meta),
            'count': len(rows),
            'truncated': len(result['rows']) > context['limit'],
            'available_groups': report['group_by'],
        })


class ReportGenerateView(APIView):
    """Render the report as PDF, Excel or CSV and stream it back."""

    permission_classes = [InventoryPermission]

    def post(self, request):
        report, columns, context = _resolve(request)
        if report is None:
            payload, code = context
            return Response(payload, status=code)

        fmt = (context['data'].get('format') or 'pdf').lower()
        if fmt not in ('pdf', 'xlsx', 'csv'):
            return Response({'detail': 'format must be pdf, xlsx or csv.'},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            result = _build(context)
        except Exception:
            logger.exception('inventory report %s failed to build', report['id'])
            return Response({'detail': 'Could not build this report.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        raw_rows = (result['rows'] or [])[:context['limit']]
        rows = _scrub_rows(raw_rows, columns)
        totals = _visible_totals(result.get('totals'), columns, report)
        meta = result.get('meta') or {}
        data = context['data']

        title = (data.get('title') or report['label']).strip()[:120]
        subtitle = (data.get('subtitle') or '').strip()[:160]
        notes = (data.get('notes') or '').strip()[:600]
        scope = _scope_lines(context, request)

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

        include_summary = str(data.get('include_summary', True)).lower() not in ('0', 'false', 'no')
        include_breakdown = str(data.get('include_breakdown', True)).lower() not in ('0', 'false', 'no')
        include_totals = str(data.get('include_totals', True)).lower() not in ('0', 'false', 'no')
        include_charts = str(data.get('include_charts', True)).lower() not in ('0', 'false', 'no')

        try:
            watermark_opacity = float(data.get('watermark_opacity') or 0.30)
        except (TypeError, ValueError):
            watermark_opacity = 0.30
        watermark_opacity = max(0.05, min(watermark_opacity, 0.60))

        summaries = (_summaries(report['id'],
                                _summary_totals(result.get('totals'), request), meta)
                     if include_summary else [])
        breakdown = (_breakdown_for(context, raw_rows, columns, totals, meta)
                     if include_breakdown else None)
        charts = (_charts_for(context, raw_rows, columns, totals, meta)
                  if include_charts else [])

        stamp = timezone.localtime(timezone.now()).strftime('%Y%m%d-%H%M')
        slug = report['id'].replace('_', '-')

        if fmt == 'pdf':
            from .render import render_report_pdf

            watermark = (data.get('watermark') or '').strip()
            if watermark.lower() in ('', 'none', 'off', 'false'):
                watermark = ''
            if report['id'] == 'abc_analysis':
                # ABC/XYZ is a study, not a spreadsheet: it gets the dedicated
                # Pareto / share / matrix renderer. The generic tabular PDF
                # stays available through the other reports.
                from .abc_render import render_abc_pdf
                body = render_abc_pdf(
                    rows=rows, meta=meta,
                    title=title or 'ABC / XYZ Classification',
                    subtitle=subtitle, org=org, logo_path=logo_path,
                    palette=palette, business_name=business_name,
                    scope_lines=scope, notes=notes, watermark=watermark,
                    watermark_opacity=watermark_opacity,
                    prepared_by=(getattr(request.user, 'full_name', '')
                                 or getattr(request.user, 'email', '') or ''),
                    can_view_cost=can_view_cost(request),
                )
            else:
                body = render_report_pdf(
                    columns=columns, rows=rows, totals=totals, meta={'lines': scope},
                    title=title, subtitle=subtitle, org=org, logo_path=logo_path,
                    palette=palette, business_name=business_name, watermark=watermark,
                    watermark_opacity=watermark_opacity,
                    notes=notes,
                    orientation=(data.get('orientation') or 'landscape'),
                    include_summary=include_summary,
                    include_breakdown=include_breakdown,
                    include_totals=include_totals,
                    summaries=summaries, breakdown=breakdown, charts=charts,
                )
            response = HttpResponse(body, content_type='application/pdf')
            response['Content-Disposition'] = (
                f'attachment; filename="{slug}-{stamp}.pdf"')
        elif fmt == 'xlsx':
            from .exporters import build_xlsx
            palette_hex = {}
            if palette:
                palette_hex = {k: '#' + str(v.hexval())[2:] for k, v in palette.items()}
            body = build_xlsx(
                columns=columns, rows=rows, totals=totals, title=title,
                subtitle=subtitle, scope_lines=scope, palette=palette_hex,
                include_totals=include_totals, business_name=business_name,
                breakdown=breakdown, charts=charts,
            )
            response = HttpResponse(
                body,
                content_type=('application/vnd.openxmlformats-officedocument'
                              '.spreadsheetml.sheet'))
            response['Content-Disposition'] = (
                f'attachment; filename="{slug}-{stamp}.xlsx"')
        else:
            from .exporters import build_csv
            body = build_csv(columns=columns, rows=rows, totals=totals,
                             include_totals=include_totals)
            response = HttpResponse(body, content_type='text/csv; charset=utf-8')
            response['Content-Disposition'] = (
                f'attachment; filename="{slug}-{stamp}.csv"')

        try:
            from ..views.base import _audit
            _audit(request, 'report_export', report['id'],
                   description=f'Exported {report["label"]} ({fmt.upper()}, '
                               f'{len(rows)} rows)',
                   payload_diff={'format': fmt, 'rows': len(rows),
                                 'columns': [c['key'] for c in columns],
                                 'branch': context['branch_id'],
                                 'date_from': context['date_from'],
                                 'date_to': context['date_to']})
        except Exception:
            logger.exception('could not audit the report export')

        response['X-Report-Rows'] = str(len(rows))
        return response
