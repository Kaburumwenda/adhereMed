"""Stock-take board.

One round-trip payload for the premium ``/ims/inventory/stock-take`` screen.
The count-sheet viewset already exposes full CRUD; this module only *reads*
and aggregates, so the page can render a queue, a progress posture and a
variance/accuracy history without walking every sheet's lines client-side.

Blocks returned by :func:`board`:

``summary``        posture numbers — open paperwork, outstanding lines,
                   net/value variance, accuracy.
``sheets``         every open sheet plus the most recent closed ones.
``open_sheets``    same rows as ``sheets`` but only the actionable queue.
``accuracy_trend`` per-sheet accuracy for the last completed sheets.
``variance_leaders`` largest line-level variances in the window.
``by_category``    variance roll-up per category.
``by_branch``      paperwork + variance roll-up per warehouse.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import timedelta

from django.db.models import Count
from django.utils import timezone

from ..models import InventoryCount, InventoryCountLine

#: Statuses in which a sheet is still waiting to be counted.
OPEN_STATUSES = (InventoryCount.Status.DRAFT, InventoryCount.Status.IN_PROGRESS)

#: How many line-level variances the screen can usefully show.
LEADER_LIMIT = 12


def _pct(part, whole, digits: int = 1):
    if not whole:
        return None
    return round(part / whole * 100, digits)


def _hours_between(start, end):
    if not start or not end:
        return None
    return round((end - start).total_seconds() / 3600, 1)


def _sheet(count, lines, *, show_cost: bool) -> dict:
    """Collapse one count sheet into the row the screen renders."""
    counted = [line for line in lines if line.counted_quantity is not None]
    outstanding = len(lines) - len(counted)

    expected_units = sum(int(line.expected_quantity or 0) for line in lines)
    counted_units = sum(int(line.counted_quantity or 0) for line in counted)
    counted_expected = sum(int(line.expected_quantity or 0) for line in counted)

    net_variance = sum(
        int(line.counted_quantity) - int(line.expected_quantity) for line in counted)
    abs_variance = sum(
        abs(int(line.counted_quantity) - int(line.expected_quantity))
        for line in counted)

    variance_value = 0.0
    overage_value = 0.0
    shortage_value = 0.0
    value_at_stake = 0.0
    mismatched = 0
    for line in lines:
        cost = float(line.stock.cost_price or 0) if line.stock else 0.0
        value_at_stake += cost * int(line.expected_quantity or 0)
        if line.counted_quantity is None:
            continue
        delta = int(line.counted_quantity) - int(line.expected_quantity)
        if delta:
            mismatched += 1
        value = cost * delta
        variance_value += value
        if value > 0:
            overage_value += value
        elif value < 0:
            shortage_value += -value

    accurate = (100 - (abs_variance / counted_expected * 100)
                if counted_expected else None)

    return {
        'id': count.id,
        'reference': count.reference,
        'name': count.name,
        'status': count.status,
        'is_open': count.status in OPEN_STATUSES,
        'branch_id': count.branch_id,
        'branch_name': count.branch.name if count.branch else '',
        'category_id': count.category_id,
        'category_name': count.category.name if count.category else '',
        'notes': count.notes or '',
        'created_by_name': getattr(count.created_by, 'full_name', None) or None,
        'completed_by_name': getattr(count.completed_by, 'full_name', None) or None,
        'created_at': count.created_at.isoformat(),
        'completed_at': count.completed_at.isoformat() if count.completed_at else None,
        'duration_hours': _hours_between(count.created_at, count.completed_at),
        'lines': len(lines),
        'counted': len(counted),
        'outstanding': outstanding,
        'mismatched': mismatched,
        'progress_pct': (round(len(counted) / len(lines) * 100)
                         if lines else 0),
        'expected_units': expected_units,
        'counted_units': counted_units,
        'net_variance': net_variance,
        'abs_variance': abs_variance,
        'accuracy_pct': (round(accurate, 1) if accurate is not None else None),
        'variance_value': round(variance_value, 2) if show_cost else 0.0,
        'overage_value': round(overage_value, 2) if show_cost else 0.0,
        'shortage_value': round(shortage_value, 2) if show_cost else 0.0,
        'value_at_stake': round(value_at_stake, 2) if show_cost else 0.0,
    }


def _lines_by_count(count_ids) -> dict:
    grouped = defaultdict(list)
    queryset = (InventoryCountLine.objects
                .filter(count_id__in=count_ids)
                .select_related('stock', 'stock__unit', 'stock__category')
                .order_by('stock__medication_name'))
    for line in queryset:
        grouped[line.count_id].append(line)
    return grouped


def board(*, branch_id=None, limit: int = 60, window_days: int = 365,
          show_cost: bool = True) -> dict:
    """Everything the stock-take screen renders, in one round-trip."""
    limit = max(5, min(int(limit or 60), 200))
    window_days = max(30, min(int(window_days or 365), 1095))
    since = timezone.now() - timedelta(days=window_days)

    counts = InventoryCount.objects.select_related(
        'branch', 'category', 'created_by', 'completed_by')
    if branch_id:
        counts = counts.filter(branch_id=branch_id)

    open_counts = list(counts.filter(status__in=OPEN_STATUSES)
                       .order_by('-created_at'))
    closed_counts = list(counts.exclude(status__in=OPEN_STATUSES)
                         .order_by('-created_at')[:limit])

    lines_by_count = _lines_by_count([c.id for c in open_counts + closed_counts])

    open_sheets = [
        _sheet(count, lines_by_count.get(count.id, []), show_cost=show_cost)
        for count in open_counts
    ]
    closed_sheets = [
        _sheet(count, lines_by_count.get(count.id, []), show_cost=show_cost)
        for count in closed_counts
    ]
    sheets = open_sheets + closed_sheets
    # Open paperwork first — it is the actionable queue — then newest first
    # inside each group.
    sheets.sort(key=lambda row: (row['is_open'], row['created_at']), reverse=True)

    # ── Scored lines (completed sheets inside the window) ──────────────
    scored_queryset = (InventoryCountLine.objects
                       .filter(count__status=InventoryCount.Status.COMPLETED,
                               counted_quantity__isnull=False,
                               count__completed_at__gte=since)
                       .select_related('stock', 'stock__category', 'count'))
    if branch_id:
        scored_queryset = scored_queryset.filter(count__branch_id=branch_id)

    scored = list(scored_queryset)

    exact = 0
    abs_variance = 0
    expected_total = 0
    net_variance = 0
    overage_value = 0.0
    shortage_value = 0.0
    category_stats = defaultdict(lambda: {
        'category_id': None, 'category_name': 'Uncategorised', 'lines': 0,
        'mismatched': 0, 'abs_variance': 0, 'variance_value': 0.0,
        'accuracy_pct': None,
    })
    leaders = []

    for line in scored:
        delta = int(line.counted_quantity) - int(line.expected_quantity)
        expected = int(line.expected_quantity or 0)
        cost = float(line.stock.cost_price or 0) if line.stock else 0.0
        value = cost * delta

        expected_total += abs(expected)
        abs_variance += abs(delta)
        net_variance += delta
        if delta == 0:
            exact += 1
        elif value > 0:
            overage_value += value
        else:
            shortage_value += -value

        category = line.stock.category if line.stock else None
        key = category.id if category else 0
        bucket = category_stats[key]
        bucket['category_id'] = category.id if category else None
        bucket['category_name'] = category.name if category else 'Uncategorised'
        bucket['lines'] += 1
        bucket['abs_variance'] += abs(delta)
        bucket['variance_value'] += value
        if delta:
            bucket['mismatched'] += 1

        if delta:
            leaders.append({
                'line_id': line.id,
                'sheet_id': line.count_id,
                'reference': line.count.reference,
                'completed_at': (line.count.completed_at.isoformat()
                                 if line.count.completed_at else None),
                'stock_id': line.stock_id,
                'name': line.stock.medication_name if line.stock else '—',
                'unit': (line.stock.unit.abbreviation
                         if line.stock and line.stock.unit else ''),
                'category_name': bucket['category_name'],
                'expected': expected,
                'counted': int(line.counted_quantity),
                'variance': delta,
                'variance_value': round(value, 2) if show_cost else 0.0,
                'cost_hidden': not show_cost,
            })

    accuracy_pct = (round(100 - (abs_variance / expected_total * 100), 1)
                    if expected_total else None)
    exact_pct = round(exact / len(scored) * 100, 1) if scored else None

    # Category accuracy needs its own expected total; recompute cheaply from
    # the line set we already hold.
    cat_expected = defaultdict(int)
    cat_abs = defaultdict(int)
    for line in scored:
        category = line.stock.category if line.stock else None
        key = category.id if category else 0
        cat_expected[key] += abs(int(line.expected_quantity or 0))
        cat_abs[key] += abs(int(line.counted_quantity) - int(line.expected_quantity))
    for key, bucket in category_stats.items():
        bucket['variance_value'] = (round(bucket['variance_value'], 2)
                                    if show_cost else 0.0)
        bucket['accuracy_pct'] = (
            round(100 - cat_abs[key] / cat_expected[key] * 100, 1)
            if cat_expected[key] else None)

    by_category = sorted(
        category_stats.values(),
        key=lambda row: (-abs(row['variance_value']), -row['mismatched'],
                         row['category_name']))

    if show_cost:
        leaders.sort(key=lambda row: -abs(row['variance_value']))
    else:
        leaders.sort(key=lambda row: -abs(row['variance']))
    leaders = leaders[:LEADER_LIMIT]

    # ── Accuracy trend: one point per completed sheet ──────────────────
    trend_counts = [count for count in closed_counts
                    if count.status == InventoryCount.Status.COMPLETED][:12]
    trend_map = defaultdict(list)
    if trend_counts:
        trend_lines = _lines_by_count([c.id for c in trend_counts])
        for count in trend_counts:
            trend_map[count.id] = trend_lines.get(count.id, [])
    accuracy_trend = []
    for count in sorted(trend_counts, key=lambda c: c.completed_at or c.created_at):
        row = _sheet(count, trend_map.get(count.id, []), show_cost=show_cost)
        accuracy_trend.append({
            'id': row['id'],
            'reference': row['reference'],
            'name': row['name'],
            'completed_at': row['completed_at'],
            'accuracy_pct': row['accuracy_pct'],
            'exact_pct': (round(row['counted'] and
                                (row['counted'] - row['mismatched']) / row['counted'] * 100, 1)
                          if row['counted'] else None),
            'abs_variance': row['abs_variance'],
            'variance_value': row['variance_value'],
        })

    # ── Warehouse roll-up ─────────────────────────────────────────────
    branch_stats = defaultdict(lambda: {
        'branch_id': None, 'name': 'Unassigned', 'open_sheets': 0,
        'open_lines': 0, 'open_counted': 0, 'open_outstanding': 0,
        'completed_sheets': 0, 'variance_value': 0.0, 'abs_variance': 0,
        'value_at_stake': 0.0,
    })
    for row in sheets:
        key = row['branch_id'] or 0
        bucket = branch_stats[key]
        bucket['branch_id'] = row['branch_id']
        bucket['name'] = row['branch_name'] or 'Unassigned'
        if row['is_open']:
            bucket['open_sheets'] += 1
            bucket['open_lines'] += row['lines']
            bucket['open_counted'] += row['counted']
            bucket['open_outstanding'] += row['outstanding']
            bucket['value_at_stake'] += row['value_at_stake']
        elif row['status'] == InventoryCount.Status.COMPLETED:
            bucket['completed_sheets'] += 1
            bucket['variance_value'] += row['variance_value']
            bucket['abs_variance'] += row['abs_variance']
    for bucket in branch_stats.values():
        bucket['variance_value'] = round(bucket['variance_value'], 2)
        bucket['value_at_stake'] = round(bucket['value_at_stake'], 2)
        bucket['progress_pct'] = (
            round(bucket['open_counted'] / bucket['open_lines'] * 100)
            if bucket['open_lines'] else 0)
    by_branch = sorted(
        branch_stats.values(),
        key=lambda row: (-row['open_sheets'], -abs(row['variance_value']),
                         row['name']))

    # ── Summary ───────────────────────────────────────────────────────
    open_lines = sum(row['lines'] for row in open_sheets)
    open_counted = sum(row['counted'] for row in open_sheets)
    open_outstanding = sum(row['outstanding'] for row in open_sheets)
    open_net_variance = sum(row['net_variance'] for row in open_sheets)
    open_variance_value = sum(row['variance_value'] for row in open_sheets)
    open_value_at_stake = sum(row['value_at_stake'] for row in open_sheets)

    completed_rows = [row for row in sheets
                      if row['status'] == InventoryCount.Status.COMPLETED]
    durations = [row['duration_hours'] for row in completed_rows
                 if row['duration_hours'] is not None]
    last_completed = max(
        (row['completed_at'] for row in completed_rows if row['completed_at']),
        default=None)

    total_sheets = counts.count()
    status_counts = dict(
        counts.values('status').annotate(n=Count('id')).values_list('status', 'n'))

    summary = {
        'sheets_total': total_sheets,
        'sheets_by_status': status_counts,
        'open_sheets': len(open_sheets),
        'open_lines': open_lines,
        'open_counted': open_counted,
        'open_outstanding': open_outstanding,
        'open_progress_pct': (round(open_counted / open_lines * 100)
                              if open_lines else 0),
        'open_net_variance': open_net_variance,
        'open_variance_value': (round(open_variance_value, 2)
                                if show_cost else 0.0),
        'open_value_at_stake': (round(open_value_at_stake, 2)
                                if show_cost else 0.0),
        'completed_sheets': status_counts.get(InventoryCount.Status.COMPLETED, 0),
        'cancelled_sheets': status_counts.get(InventoryCount.Status.CANCELLED, 0),
        'draft_sheets': status_counts.get(InventoryCount.Status.DRAFT, 0),
        'in_progress_sheets': status_counts.get(InventoryCount.Status.IN_PROGRESS, 0),
        'scored_lines': len(scored),
        'exact_lines': exact,
        'exact_pct': exact_pct,
        'accuracy_pct': accuracy_pct,
        'abs_variance': abs_variance,
        'net_variance': net_variance,
        'expected_units': expected_total,
        'variance_value': round(overage_value - shortage_value, 2) if show_cost else 0.0,
        'overage_value': round(overage_value, 2) if show_cost else 0.0,
        'shortage_value': round(shortage_value, 2) if show_cost else 0.0,
        'avg_duration_hours': (round(sum(durations) / len(durations), 1)
                               if durations else None),
        'last_completed_at': last_completed,
        'window_days': window_days,
        'cost_hidden': not show_cost,
    }

    return {
        'summary': summary,
        'sheets': sheets,
        'open_sheets': open_sheets,
        'accuracy_trend': accuracy_trend,
        'variance_leaders': leaders,
        'by_category': by_category,
        'by_branch': by_branch,
        'window_days': window_days,
    }
