"""Business-Intelligence report: section registry + dataset builder.

This is the *narrative* counterpart to the tabular sheets in
:mod:`inventory.reports.catalog`. A tabular sheet answers "list the rows"; a BI
report answers "what happened, why, and what should we do". It is therefore
built from the same sources the BI workspace on screen uses — POS transactions,
inventory stocks and the derived commercial measures — but assembled into
sections the reader can switch off.

Every section is independently omittable (``'revenue_trajectory'`` is one of
them), because a branch manager and a finance controller want very different
documents out of the same data.
"""
from __future__ import annotations

import logging
from collections import defaultdict
from datetime import timedelta

from django.db.models import Count, Min, Q, Sum
from django.db.models.functions import TruncMonth, TruncWeek
from django.utils import timezone

logger = logging.getLogger(__name__)

#: Human label for the POS payment methods.
PAYMENT_LABELS = {
    'cash': 'Cash', 'card': 'Card', 'mpesa': 'M-Pesa',
    'insurance': 'Insurance', 'credit': 'Credit',
}

#: Report sections, in the order they appear in the document.
#:
#: ``needs_cost`` marks sections whose numbers depend on purchase cost — they are
#: dropped for roles without ``stock.cost`` rather than printed as zeros.
#: ``kind`` tells the renderer how to lay the section out.
SECTIONS = [
    {
        'id': 'executive_summary',
        'label': 'Executive summary',
        'description': 'Headline figures and a written summary of what moved '
                       'and why.',
        'icon': 'mdi-text-box-outline',
        'kind': 'prose',
        'needs_cost': False,
    },
    {
        'id': 'kpi_scorecard',
        'label': 'KPI scorecard',
        'description': 'Twelve commercial measures with period-on-period '
                       'change.',
        'icon': 'mdi-view-dashboard-outline',
        'kind': 'kpi',
        'needs_cost': False,
    },
    {
        'id': 'revenue_trajectory',
        'label': 'Revenue trajectory',
        'description': 'Monthly revenue for the period with month-on-month '
                       'change and the fitted trend.',
        'icon': 'mdi-chart-areaspline',
        'kind': 'chart',
        'needs_cost': False,
    },
    {
        'id': 'root_cause',
        'label': 'Root-cause analysis',
        'description': 'Price, volume and mix bridge explaining the movement '
                       'against the previous period.',
        'icon': 'mdi-magnify-scan',
        'kind': 'bridge',
        'needs_cost': False,
    },
    {
        'id': 'forecast_trends',
        'label': 'Forecasts & trends',
        'description': 'Projected revenue with a confidence band, back-tested '
                       'accuracy, seasonality and scenarios.',
        'icon': 'mdi-chart-timeline-variant-shimmer',
        'kind': 'forecast',
        'needs_cost': False,
    },
    {
        'id': 'category_mix',
        'label': 'Category mix',
        'description': 'Where the revenue comes from, by product category.',
        'icon': 'mdi-chart-donut',
        'kind': 'chart',
        'needs_cost': False,
    },
    {
        'id': 'branch_comparison',
        'label': 'Warehouse comparison',
        'description': 'Revenue, orders and average basket per warehouse.',
        'icon': 'mdi-chart-bar',
        'kind': 'chart',
        'needs_cost': False,
    },
    {
        'id': 'top_products',
        'label': 'Top products (Pareto)',
        'description': 'Best sellers with revenue share and cumulative '
                       'contribution.',
        'icon': 'mdi-trophy-outline',
        'kind': 'table',
        'needs_cost': False,
    },
    {
        'id': 'payment_mix',
        'label': 'Payment mix',
        'description': 'How customers paid — cash, card, mobile money, '
                       'insurance, credit.',
        'icon': 'mdi-credit-card-outline',
        'kind': 'chart',
        'needs_cost': False,
    },
    {
        'id': 'customer_segments',
        'label': 'Customer segments',
        'description': 'Spend concentration across the customer base (RFM-lite).',
        'icon': 'mdi-account-group-outline',
        'kind': 'chart',
        'needs_cost': False,
    },
    {
        'id': 'stock_health',
        'label': 'Stock health',
        'description': 'Capital employed, cover, expiry exposure and stock-out '
                       'risk.',
        'icon': 'mdi-package-variant-closed',
        'kind': 'table',
        'needs_cost': True,
    },
    {
        'id': 'optimization',
        'label': 'Optimization & actions',
        'description': 'Pricing moves, discount guardrails, replenishment '
                       'quantities and clearance plan.',
        'icon': 'mdi-tune-variant',
        'kind': 'optimization',
        'needs_cost': True,
    },
    {
        'id': 'operational_reports',
        'label': 'Operational report index',
        'description': 'Every report this workspace can deliver, with live '
                       'headline values and export formats.',
        'icon': 'mdi-bookshelf',
        'kind': 'library',
        'needs_cost': False,
    },
    {
        'id': 'recommendations',
        'label': 'Findings & recommendations',
        'description': 'Auto-generated actions derived from the figures above.',
        'icon': 'mdi-lightbulb-on-outline',
        'kind': 'prose',
        'needs_cost': False,
    },
]

SECTION_IDS = [s['id'] for s in SECTIONS]
SECTIONS_BY_ID = {s['id']: s for s in SECTIONS}

#: On by default — everything, so the first render is the complete document.
DEFAULT_SECTIONS = list(SECTION_IDS)


def resolve_sections(requested):
    """Normalise the caller's section list.

    ``None`` means "everything". An empty list is *not* silently upgraded to
    everything: a reader who unticked all ten sections asked for a cover page
    and nothing else, and guessing otherwise would resurrect content they
    explicitly removed.
    """
    if requested is None:
        return list(DEFAULT_SECTIONS)
    if isinstance(requested, str):
        requested = [requested]
    wanted = {str(s).strip() for s in requested if str(s).strip()}
    return [sid for sid in SECTION_IDS if sid in wanted]


def available_sections(request):
    """Sections this caller may see (cost-bearing ones are gated)."""
    try:
        from ..rbac import can_view_cost
        allow_cost = can_view_cost(request)
    except Exception:
        allow_cost = True
    return [s for s in SECTIONS if allow_cost or not s['needs_cost']]


def catalog_payload(request):
    return {
        'sections': available_sections(request),
        'defaults': [s['id'] for s in available_sections(request)],
    }


# ── Helpers ─────────────────────────────────────────────────────────────
def _num(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _pct_change(current, previous):
    """Signed % change. ``None`` when there is no comparable base."""
    current, previous = _num(current), _num(previous)
    if not previous:
        return None
    return round((current - previous) / abs(previous) * 100.0, 1)


def _month_label(value):
    if value is None:
        return 'No date'
    return value.strftime('%b %Y')


def _bounds(date_from, date_to, default_days=365):
    """Resolve the reporting window, defaulting to a rolling year."""
    end = _parse(date_to) or timezone.localdate()
    start = _parse(date_from) or (end - timedelta(days=default_days - 1))
    if start > end:
        start, end = end, start
    return start, end


def _parse(value):
    from .datasets import parse_date
    return parse_date(value)


def _money(value, currency='KES'):
    return f'{currency} {_num(value):,.2f}'


def _count(value):
    return f'{int(round(_num(value))):,}'


def _trend_line(values):
    """Least-squares slope/intercept for a simple fitted trend."""
    points = [v for v in values]
    n = len(points)
    if n < 2:
        return None
    xs = list(range(n))
    mean_x = sum(xs) / n
    mean_y = sum(points) / n
    denom = sum((x - mean_x) ** 2 for x in xs)
    if not denom:
        return None
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, points)) / denom
    intercept = mean_y - slope * mean_x
    return {'slope': slope, 'intercept': intercept,
            'next': intercept + slope * n}


# ── Dataset ─────────────────────────────────────────────────────────────
def build_bi_dataset(request, *, date_from=None, date_to=None, branch_id=None,
                     currency='KES'):
    """Assemble every measure the report needs, in one pass.

    Returns a dict of *already computed* values. The renderer only formats —
    it never queries — so the on-screen preview and the PDF can be produced
    from the identical payload.
    """
    from pos.models import POSTransaction, TransactionItem
    from ..models import MedicationStock

    start, end = _bounds(date_from, date_to)
    # Same-length comparison window immediately before the period, so the
    # "vs previous period" column is a like-for-like comparison rather than an
    # arbitrary "last month".
    span = (end - start).days + 1
    prev_end = start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=span - 1)

    def tx_qs(from_date, to_date):
        qs = POSTransaction.objects.filter(
            status=POSTransaction.SaleStatus.COMPLETED,
            created_at__date__gte=from_date,
            created_at__date__lte=to_date,
        )
        if branch_id:
            qs = qs.filter(branch_id=branch_id)
        return qs

    current = tx_qs(start, end)
    previous = tx_qs(prev_start, prev_end)

    def totals(qs):
        row = qs.aggregate(
            revenue=Sum('total'),
            orders=Count('id'),
            discount=Sum('discount'),
            tax=Sum('tax'),
            customers=Count('customer', distinct=True),
        )
        return {k: _num(v) for k, v in row.items()}

    now, before = totals(current), totals(previous)

    items = (TransactionItem.objects
             .filter(transaction__in=current)
             .select_related('stock', 'stock__category', 'stock__branch'))
    units = _num(items.aggregate(q=Sum('quantity'))['q'])

    # ── Monthly history ────────────────────────────────────────────────
    monthly = (current
               .annotate(bucket=TruncMonth('created_at'))
               .values('bucket')
               .annotate(revenue=Sum('total'), orders=Count('id'))
               .order_by('bucket'))
    history = []
    for row in monthly:
        bucket = row['bucket']
        history.append({
            'label': _month_label(bucket),
            'value': round(_num(row['revenue']), 2),
            'orders': int(row['orders'] or 0),
            # Kept separately from ``label`` so the seasonal profile can bucket
            # by calendar month instead of re-parsing a formatted string.
            'month': getattr(bucket, 'month', None),
            'year': getattr(bucket, 'year', None),
        })
    for i, point in enumerate(history):
        point['delta_pct'] = (_pct_change(point['value'],
                                          history[i - 1]['value'])
                              if i else None)
    trend = _trend_line([p['value'] for p in history])

    # ── Category mix ───────────────────────────────────────────────────
    by_category = defaultdict(float)
    for row in (items.values('stock__category__name')
                .annotate(revenue=Sum('total_price')).order_by('-revenue')):
        by_category[row['stock__category__name'] or 'Uncategorised'] += _num(row['revenue'])
    cat_total = sum(by_category.values()) or 1.0
    categories = [
        {'label': name, 'value': round(value, 2),
         'share_pct': round(value / cat_total * 100, 1)}
        for name, value in sorted(by_category.items(), key=lambda kv: -kv[1])
    ]

    # ── Branch comparison ──────────────────────────────────────────────
    branches = []
    for row in (current.values('branch__name')
                .annotate(revenue=Sum('total'), orders=Count('id'))
                .order_by('-revenue')):
        revenue = _num(row['revenue'])
        orders = int(row['orders'] or 0)
        branches.append({
            'label': row['branch__name'] or 'Unassigned',
            'value': round(revenue, 2),
            'orders': orders,
            'aov': round(revenue / orders, 2) if orders else 0.0,
        })

    # ── Top products ───────────────────────────────────────────────────
    product_rows = list(items.values('medication_name')
                        .annotate(revenue=Sum('total_price'),
                                  quantity=Sum('quantity'))
                        .order_by('-revenue')[:15])
    product_total = _num(items.aggregate(r=Sum('total_price'))['r']) or 1.0
    products = []
    cumulative = 0.0
    for row in product_rows:
        revenue = _num(row['revenue'])
        cumulative += revenue
        cumulative_pct = round(cumulative / product_total * 100, 1)
        products.append({
            'label': row['medication_name'] or 'Unnamed',
            'value': round(revenue, 2),
            'quantity': int(row['quantity'] or 0),
            'share_pct': round(revenue / product_total * 100, 1),
            'cumulative_pct': cumulative_pct,
            # Pareto class, used by the optimisation pricing ladder.
            'abc': ('A' if cumulative_pct <= 80
                    else 'B' if cumulative_pct <= 95 else 'C'),
        })

    # ── Payment mix ────────────────────────────────────────────────────
    payments = []
    pay_total = 0.0
    for row in (current.values('payment_method')
                .annotate(revenue=Sum('total'), orders=Count('id'))
                .order_by('-revenue')):
        revenue = _num(row['revenue'])
        pay_total += revenue
        payments.append({
            'label': PAYMENT_LABELS.get(row['payment_method'],
                                        str(row['payment_method']).title()),
            'value': round(revenue, 2),
            'orders': int(row['orders'] or 0),
        })
    for point in payments:
        point['share_pct'] = (round(point['value'] / pay_total * 100, 1)
                              if pay_total else 0.0)

    # ── Customer segments (RFM-lite on transaction frequency) ──────────
    per_customer = (current.exclude(customer__isnull=True)
                    .values('customer')
                    .annotate(spend=Sum('total'), visits=Count('id')))
    buckets = {'One-off': 0.0, 'Occasional (2–3)': 0.0,
               'Regular (4–9)': 0.0, 'Frequent (10+)': 0.0}
    counts = {k: 0 for k in buckets}
    for row in per_customer:
        visits = int(row['visits'] or 0)
        spend = _num(row['spend'])
        if visits >= 10:
            key = 'Frequent (10+)'
        elif visits >= 4:
            key = 'Regular (4–9)'
        elif visits >= 2:
            key = 'Occasional (2–3)'
        else:
            key = 'One-off'
        buckets[key] += spend
        counts[key] += 1
    identified_spend = sum(buckets.values())
    segments = [
        {'label': key, 'value': round(value, 2), 'customers': counts[key],
         'share_pct': round(value / identified_spend * 100, 1)
         if identified_spend else 0.0}
        for key, value in buckets.items()
    ]

    # ── Stock health ───────────────────────────────────────────────────
    stocks = MedicationStock.objects.filter(is_active=True).with_quantities()
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)
    stock_rows = list(stocks.values(
        'medication_name', 'selling_price', 'cost_price', 'reorder_level',
        'branch__name', 'annotated_total_quantity',
        'annotated_sellable_quantity', 'annotated_expired_quantity'))
    inv_cost = inv_retail = 0.0
    on_hand = out_of_stock = low_stock = expired_units = 0
    for row in stock_rows:
        qty = int(row['annotated_total_quantity'] or 0)
        cost = _num(row['cost_price'])
        retail = _num(row['selling_price'])
        on_hand += qty
        inv_cost += qty * cost
        inv_retail += qty * retail
        expired_units += int(row['annotated_expired_quantity'] or 0)
        if int(row['annotated_sellable_quantity'] or 0) <= 0:
            out_of_stock += 1
        if qty <= int(row['reorder_level'] or 0):
            low_stock += 1

    health_rows = sorted(
        ({'label': r['medication_name'] or 'Unnamed',
          'branch': r['branch__name'] or '',
          'on_hand': int(r['annotated_total_quantity'] or 0),
          'reorder_level': int(r['reorder_level'] or 0),
          'value': round(int(r['annotated_total_quantity'] or 0)
                         * _num(r['cost_price']), 2)}
         for r in stock_rows
         if int(r['annotated_total_quantity'] or 0) <= int(r['reorder_level'] or 0)),
        key=lambda r: -r['value'])[:12]

    # ── Derived commercial measures ────────────────────────────────────
    gross_cost = 0.0
    cost_map = {r['medication_name']: _num(r['cost_price']) for r in stock_rows}
    for row in items.values('medication_name').annotate(q=Sum('quantity')):
        gross_cost += _num(row['q']) * cost_map.get(row['medication_name'], 0.0)
    gross_margin = now['revenue'] - gross_cost
    margin_pct = (gross_margin / now['revenue'] * 100) if now['revenue'] else 0.0
    avg_basket = (now['revenue'] / now['orders']) if now['orders'] else 0.0
    prev_basket = (before['revenue'] / before['orders']) if before['orders'] else 0.0
    daily_units = units / span if span else 0.0
    days_cover = round(on_hand / daily_units) if daily_units else None

    def _cover_display(value):
        """Cap cover at ten years — beyond that the figure is an artefact of a
        thin sales history, not a planning signal, and printing "24,313 days"
        just makes the report look broken."""
        if value is None:
            return '—'
        return '> 3,650' if value > 3650 else f'{value:,}'

    kpis = [
        {'id': 'revenue', 'label': 'Revenue', 'value': _money(now['revenue'], currency),
         'raw': round(now['revenue'], 2), 'unit': 'money',
         'delta_pct': _pct_change(now['revenue'], before['revenue']),
         'hint': f'{span} days'},
        {'id': 'orders', 'label': 'Orders', 'value': _count(now['orders']),
         'raw': now['orders'], 'unit': 'count',
         'delta_pct': _pct_change(now['orders'], before['orders']),
         'hint': 'completed sales'},
        {'id': 'aov', 'label': 'Average basket', 'value': _money(avg_basket, currency),
         'raw': round(avg_basket, 2), 'unit': 'money',
         'delta_pct': _pct_change(avg_basket, prev_basket),
         'hint': 'revenue ÷ orders'},
        {'id': 'units', 'label': 'Units sold', 'value': _count(units),
         'raw': units, 'unit': 'count', 'delta_pct': None,
         'hint': 'all line items'},
        {'id': 'customers', 'label': 'Identified customers',
         'value': _count(now['customers']), 'raw': now['customers'],
         'unit': 'count',
         'delta_pct': _pct_change(now['customers'], before['customers']),
         'hint': 'linked to a profile'},
        {'id': 'gross_margin', 'label': 'Gross margin',
         'value': _money(gross_margin, currency), 'raw': round(gross_margin, 2),
         'unit': 'money', 'delta_pct': None, 'cost': True,
         'hint': f'{margin_pct:.1f}% of revenue'},
        {'id': 'inventory_value', 'label': 'Inventory at cost',
         'value': _money(inv_cost, currency), 'raw': round(inv_cost, 2),
         'unit': 'money', 'delta_pct': None, 'cost': True,
         'hint': f'{_money(inv_retail, currency)} at retail'},
        {'id': 'days_cover', 'label': 'Days of cover',
         'value': _cover_display(days_cover),
         'raw': days_cover, 'unit': 'count', 'delta_pct': None,
         'hint': 'stock ÷ daily units'},
        {'id': 'stock_turns', 'label': 'Stock turns (annualised)',
         'value': (f'{inv_cost and (gross_cost / inv_cost * 365 / span):.2f}'
                   if inv_cost and span else '—'),
         'raw': round(gross_cost / inv_cost * 365 / span, 2) if inv_cost and span else 0,
         'unit': 'count', 'delta_pct': None, 'cost': True,
         'hint': 'cost of sales ÷ inventory'},
        {'id': 'units_on_hand', 'label': 'Units on hand', 'value': _count(on_hand),
         'raw': on_hand, 'unit': 'count', 'delta_pct': None,
         'hint': f'{len(stock_rows):,} active items'},
        {'id': 'stockouts', 'label': 'Out of stock', 'value': _count(out_of_stock),
         'raw': out_of_stock, 'unit': 'count', 'delta_pct': None, 'tone': 'bad',
         'hint': f'{low_stock:,} at/below reorder'},
        {'id': 'expired_units', 'label': 'Expired units', 'value': _count(expired_units),
         'raw': expired_units, 'unit': 'count', 'delta_pct': None, 'tone': 'bad',
         'hint': 'write-off exposure'},
    ]

    allow_cost = True
    try:
        from ..rbac import can_view_cost
        allow_cost = can_view_cost(request)
        if not allow_cost:
            kpis = [k for k in kpis if not k.get('cost')]
    except Exception:
        pass

    scope = [f'Period: {start.strftime("%d %b %Y")} – {end.strftime("%d %b %Y")}'
             f' ({span} days)']
    if branch_id:
        scope.append(f'Warehouse: {branches[0]["label"] if len(branches) == 1 else branch_id}')
    else:
        scope.append('Warehouse: all warehouses')

    dataset = {
        'scope': scope,
        'start': start,
        'end': end,
        'span_days': span,
        'currency': currency,
        'kpis': kpis,
        'history': history,
        'trend': trend,
        'categories': categories,
        'branches': branches,
        'products': products,
        'payments': payments,
        'segments': segments,
        'stock_health': health_rows,
        'stock_totals': {
            'inventory_cost': round(inv_cost, 2),
            'inventory_retail': round(inv_retail, 2),
            'units_on_hand': on_hand,
            'out_of_stock': out_of_stock,
            'low_stock': low_stock,
            'expired_units': expired_units,
            'items': len(stock_rows),
        },
        'totals': {
            'revenue': round(now['revenue'], 2),
            'orders': int(now['orders']),
            'units': int(units),
            'aov': round(avg_basket, 2),
            'gross_margin': round(gross_margin, 2),
            'margin_pct': round(margin_pct, 1),
            'discount': round(now['discount'], 2),
        },
        'previous': {
            'revenue': round(before['revenue'], 2),
            'orders': int(before['orders']),
        },
        'section_count': len(SECTIONS),
    }
    _attach_advanced(dataset, current_items=items, stock_rows=stock_rows,
                     span=span, start=start, end=end, branch_id=branch_id,
                     currency=currency, allow_cost=allow_cost)
    return dataset


#: Blocks the advanced sections need. Built lazily so an error in one model
#: (a thin dataset, a missing cost, an empty branch) costs that section rather
#: than the whole document.
ADVANCED_BLOCKS = ('forecast', 'root_cause', 'optimization', 'operational')


def _attach_advanced(dataset, *, current_items, stock_rows, span, start, end,
                     branch_id, currency='KES', allow_cost=True):
    """Compute the forecast / root-cause / optimisation / index blocks.

    Each block is wrapped individually: the report is still useful without any
    one of them, and a single arithmetic edge case (dividing by a zero-length
    week) must never turn a board pack into a 500.
    """
    from . import bi_sections as sections_engine

    # ── Per-product weekly demand, densified so quiet weeks count as zero ──
    weekly_by_product = defaultdict(dict)
    try:
        week_rows = (current_items
                     .annotate(week=TruncWeek('transaction__created_at'))
                     .values('medication_name', 'week')
                     .annotate(quantity=Sum('quantity')))
        for row in week_rows:
            key = str(row['medication_name'] or '').strip().lower()
            week = row['week']
            if key and week:
                weekly_by_product[key][week] = _num(row['quantity'])
    except Exception:
        weekly_by_product = defaultdict(dict)

    week_grid = []
    cursor = start - timedelta(days=start.weekday())
    while cursor <= end:
        week_grid.append(cursor)
        cursor += timedelta(days=7)

    def weekly_series(name):
        filled = weekly_by_product.get(str(name or '').strip().lower())
        if not filled:
            return []
        return [float(filled.get(week, 0)) for week in week_grid]

    # ── Earliest sellable expiry per item (drives the clearance plan) ─────
    expiry_map = {}
    try:
        from ..models import StockBatch
        batches = StockBatch.objects.filter(
            quantity_remaining__gt=0, is_blocked=False,
            expiry_date__isnull=False)
        if branch_id:
            batches = batches.filter(stock__branch_id=branch_id)
        for row in (batches.values('stock__medication_name')
                    .annotate(next_expiry=Min('expiry_date'))):
            key = str(row['stock__medication_name'] or '').strip().lower()
            if key and row['next_expiry']:
                expiry_map[key] = row['next_expiry']
    except Exception:
        expiry_map = {}

    # ── Stock lookup keyed by item name (per-branch rows rolled up) ───────
    stock_by_name = {}
    for row in stock_rows or []:
        key = str(row['medication_name'] or '').strip().lower()
        if not key:
            continue
        entry = stock_by_name.setdefault(key, {
            'selling_price': 0.0, 'cost_price': 0.0, 'on_hand': 0.0,
            'reorder_level': 0.0, 'next_expiry': None,
        })
        entry['on_hand'] += _num(row['annotated_sellable_quantity'])
        entry['reorder_level'] += _num(row['reorder_level'])
        if not entry['selling_price']:
            entry['selling_price'] = _num(row['selling_price'])
        if not entry['cost_price']:
            entry['cost_price'] = _num(row['cost_price'])
        if key in expiry_map:
            entry['next_expiry'] = expiry_map[key]

    # ── Stock-out opportunity cost ────────────────────────────────────────
    stockout_rows = []
    for row in stock_rows or []:
        sellable = _num(row['annotated_sellable_quantity'])
        reorder = _num(row['reorder_level'])
        gap = max(0.0, reorder - sellable)
        if gap <= 0:
            continue
        unit_value = _num(row['selling_price']) or _num(row['cost_price'])
        stockout_rows.append({
            'label': row['medication_name'] or 'Unnamed',
            'on_hand': sellable,
            'reorder': reorder,
            'value_at_risk': gap * unit_value,
        })
    stockout_rows.sort(key=lambda r: -r['value_at_risk'])

    # ── 1. Forecast ───────────────────────────────────────────────────────
    try:
        dataset['forecast'] = sections_engine.build_forecast(
            dataset['history'], end,
            history_months=[p.get('month') for p in dataset['history']])
        dataset['forecast_findings'] = sections_engine.build_forecast_findings(
            dataset['forecast'], currency)
    except Exception:
        logger.exception('BI forecast block failed')
        dataset['forecast'] = {'available': False,
                               'reason': 'The projection could not be built.'}
        dataset['forecast_findings'] = []

    # ── 2. Root cause ─────────────────────────────────────────────────────
    try:
        dataset['root_cause'] = sections_engine.build_root_cause(
            current=dataset['totals'],
            previous=dataset['previous'],
            discount_current=dataset['totals']['discount'],
            discount_previous=_previous_discount(dataset, span, branch_id),
            stockout_rows=stockout_rows,
            history=dataset['history'],
            currency=currency)
    except Exception:
        logger.exception('BI root-cause block failed')
        dataset['root_cause'] = None

    # ── 3. Optimisation ───────────────────────────────────────────────────
    # Margin-based advice needs purchase cost, so the block is not even built
    # for a role that cannot see cost - the section is dropped from the pack by
    # the view, and computing it would only put cost data in memory.
    try:
        if not allow_cost:
            dataset['optimization'] = None
        else:
            for product in dataset['products']:
                product['weekly'] = weekly_series(product['label'])
            dataset['optimization'] = sections_engine.build_optimization(
                products=dataset['products'],
                stock_by_name=stock_by_name,
                span_days=span,
                branches=dataset['branches'],
                currency=currency)
    except Exception:
        logger.exception('BI optimization block failed')
        dataset['optimization'] = None

    # ── 4. Operational report index (needs the blocks above) ──────────────
    try:
        dataset['operational'] = sections_engine.build_operational_index(
            data=dataset, currency=currency)
    except Exception:
        logger.exception('BI operational index block failed')
        dataset['operational'] = None


def _previous_discount(dataset, span, branch_id):
    """Discount granted in the comparison window.

    Cheap second aggregate rather than threading another value through
    :func:`build_bi_dataset`'s already long signature.
    """
    try:
        from pos.models import POSTransaction as _Tx
        end = dataset['start'] - timedelta(days=1)
        start = end - timedelta(days=span - 1)
        qs = _Tx.objects.filter(
            status=_Tx.SaleStatus.COMPLETED,
            created_at__date__gte=start,
            created_at__date__lte=end)
        if branch_id:
            qs = qs.filter(branch_id=branch_id)
        return _num(qs.aggregate(value=Sum('discount'))['value'])
    except Exception:
        return 0.0


# ── Narrative ───────────────────────────────────────────────────────────
def build_narrative(data):
    """Plain-English findings derived from the figures.

    Deliberately deterministic and arithmetic — a report that invents reasons
    ("demand softened because of weather") is worse than one that states the
    movement and the two or three measurable contributors.
    """
    totals = data['totals']
    prev = data['previous']
    kpi = {k['id']: k for k in data['kpis']}
    findings = []

    revenue_delta = kpi.get('revenue', {}).get('delta_pct')
    if revenue_delta is not None:
        direction = 'grew' if revenue_delta >= 0 else 'fell'
        findings.append(
            f'Revenue {direction} {abs(revenue_delta):.1f}% '
            f'({_money(prev["revenue"])} → {_money(totals["revenue"])}) '
            f'across {totals["orders"]:,} completed orders.')
    else:
        findings.append(
            f'Revenue was {_money(totals["revenue"])} across '
            f'{totals["orders"]:,} completed orders; there is no comparable '
            f'prior period for this selection.')

    if data['categories']:
        top = data['categories'][0]
        findings.append(
            f'{top["label"]} is the largest category at '
            f'{top["share_pct"]:.1f}% of revenue ({_money(top["value"])}).')
    if len(data['products']) >= 3:
        head = data['products'][:3]
        contribution = head[-1]['cumulative_pct']
        findings.append(
            f'The top three products contribute {contribution:.1f}% of revenue, '
            f'led by {head[0]["label"]} at {head[0]["share_pct"]:.1f}%.')
    if data['payments']:
        lead = data['payments'][0]
        findings.append(
            f'{lead["label"]} is the dominant settlement method at '
            f'{lead["share_pct"]:.1f}% of collected value.')
    if data['branches']:
        best = data['branches'][0]
        if len(data['branches']) > 1:
            findings.append(
                f'{best["label"]} leads the network with '
                f'{_money(best["value"])} and an average basket of '
                f'{_money(best["aov"])}.')
        else:
            findings.append(
                f'All revenue is attributed to {best["label"]} '
                f'(average basket {_money(best["aov"])}).')

    totals_stock = data['stock_totals']
    if totals_stock['out_of_stock']:
        findings.append(
            f'{totals_stock["out_of_stock"]:,} of {totals_stock["items"]:,} '
            f'active items have nothing sellable on the shelf, and '
            f'{totals_stock["low_stock"]:,} sit at or below their reorder level.')
    cover = kpi.get('days_cover', {}).get('raw')
    if cover and cover > 3650:
        findings.append(
            f'Stock on hand ({_count(totals_stock["units_on_hand"])} units) '
            f'far exceeds demand at the current run rate — the cover figure is '
            f'off the scale for this period.')
    elif cover:
        findings.append(
            f'Stock covers {cover:,} days of demand at the current run rate.')

    return findings


def build_recommendations(data):
    """Actionable next steps, each tied to a number that triggered it."""
    totals = data['totals']
    stock = data['stock_totals']
    kpi = {k['id']: k for k in data['kpis']}
    actions = []

    if stock['out_of_stock']:
        actions.append(
            f'Replenish the {stock["out_of_stock"]:,} out-of-stock items first — '
            f'each is lost revenue, not deferred revenue.')
    if stock['expired_units']:
        actions.append(
            f'Raise write-offs for {stock["expired_units"]:,} expired units so '
            f'the balance sheet reflects realisable stock.')
    if data['products']:
        top = data['products'][0]
        actions.append(
            f'Protect availability of {top["label"]} — it alone is '
            f'{top["share_pct"]:.1f}% of revenue, so a stock-out there costs '
            f'more than any other item.')
    if len(data['categories']) > 4:
        tail = data['categories'][-1]
        actions.append(
            f'Review the long tail: {tail["label"]} contributes only '
            f'{tail["share_pct"]:.1f}% of revenue and may not justify its '
            f'shelf space.')
    cover = kpi.get('days_cover', {}).get('raw')
    if cover and cover > 3650:
        actions.append(
            f'Stock on hand is many years of cover at the current sell-through '
            f'rate — stop replenishing the slowest movers and review whether the '
            f'range is over-bought.')
    elif cover and cover > 90:
        actions.append(
            f'{cover:,} days of cover is heavy — reduce order quantities on the '
            f'slowest movers to free working capital.')
    elif cover and cover < 21:
        actions.append(
            f'{cover:,} days of cover is thin — bring forward purchase orders '
            f'on fast movers to avoid stock-outs.')
    margin = totals.get('margin_pct')
    if margin is not None and margin and margin < 20:
        actions.append(
            f'Gross margin is {margin:.1f}% — review discount depth and '
            f'supplier pricing on the top-selling lines.')
    if not actions:
        actions.append('No exception thresholds were breached in this period.')
    return actions
