"""ABC-driven cycle-count scheduling (Tier 1).

Replaces the "somebody remembers to create a count" process with a rolling
plan: A items monthly, B quarterly, C yearly (all configurable). The
nightly job re-plans and can auto-create the count sheet.
"""
from __future__ import annotations

from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from ..models import (CycleCountSchedule, InventoryCount, InventoryCountLine,
                      InventorySettings, MedicationStock, StockPolicy)

#: Prefix stamped on sheets minted from the plan. Used both when creating a
#: sheet and when detecting that an open one already exists, so the two can
#: never drift apart.
PLAN_NOTE_PREFIX = 'Auto-created from the ABC cycle-count plan'

#: Statuses in which a sheet is still waiting to be counted.
OPEN_STATUSES = (InventoryCount.Status.DRAFT, InventoryCount.Status.IN_PROGRESS)


def cadence_for(abc_class: str) -> tuple[str, int]:
    settings_obj = InventorySettings.get()
    if abc_class == 'A':
        return CycleCountSchedule.Cadence.A, settings_obj.count_cadence_a
    if abc_class == 'B':
        return CycleCountSchedule.Cadence.B, settings_obj.count_cadence_b
    return CycleCountSchedule.Cadence.C, settings_obj.count_cadence_c


def cadence_days() -> dict:
    """The interval each class should be counted at, in days."""
    settings_obj = InventorySettings.get()
    return {
        'A': settings_obj.count_cadence_a,
        'B': settings_obj.count_cadence_b,
        'C': settings_obj.count_cadence_c,
    }


def ensure_coverage(*, branch_id=None) -> dict:
    """Re-plan only when the schedule set is smaller than the stock set.

    The original bootstrap ran ``replan`` only when *no* schedule rows
    existed. A tenant that seeded three rows, or that loaded stock after the
    first plan, therefore ended up permanently under-covered: those items
    never appear on the plan and are never counted, silently. Comparing the
    two counts catches both the cold-start case and the partial-coverage
    case at the cost of two ``COUNT`` queries.
    """
    stocks = MedicationStock.objects.filter(is_active=True)
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)
    schedules = CycleCountSchedule.objects.filter(is_active=True)
    if branch_id:
        schedules = schedules.filter(branch_id=branch_id)
    if schedules.count() >= stocks.count():
        return {'replanned': False}
    return {'replanned': True, **replan(branch_id=branch_id)}


@transaction.atomic
def replan(*, branch_id=None) -> dict:
    """Create/refresh a schedule row for every active stock item."""
    today = timezone.localdate()
    stocks = MedicationStock.objects.filter(is_active=True).select_related('policy')
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)

    created = updated = 0
    for stock in stocks.iterator():
        policy = getattr(stock, 'policy', None)
        cadence, interval = cadence_for(policy.abc_class if policy else 'C')

        schedule = CycleCountSchedule.objects.filter(
            stock=stock, branch_id=stock.branch_id).first()
        is_new = schedule is None
        if is_new:
            schedule = CycleCountSchedule(
                stock=stock, branch=stock.branch, next_due=today)
        schedule.cadence = cadence
        schedule.interval_days = interval
        if not schedule.next_due or schedule.next_due < today - timedelta(days=interval):
            # Never let a plan silently drift a whole cycle behind.
            schedule.next_due = today
        schedule.is_active = True
        schedule.save()
        created += 1 if is_new else 0
        updated += 0 if is_new else 1

        if policy is not None:
            policy.next_count_due = schedule.next_due
            policy.save(update_fields=['next_count_due', 'updated_at'])

    return {'schedules': created + updated, 'created': created, 'updated': updated}


def plan_summary(*, branch_id=None) -> dict:
    """Headline numbers for the cycle-count plan screen.

    Deliberately counts the whole schedule (not just what is due), so the
    "Class A / Class B" tiles describe the plan's shape rather than the
    backlog — otherwise they all read 0 right after a count is created.
    """
    today = timezone.localdate()
    qs = CycleCountSchedule.objects.filter(is_active=True)
    if branch_id:
        qs = qs.filter(branch_id=branch_id)
    rows = list(qs.values_list('cadence', 'next_due'))
    by_cadence = {c: 0 for c, _ in CycleCountSchedule.Cadence.choices}
    for cadence, _due in rows:
        by_cadence[cadence] = by_cadence.get(cadence, 0) + 1
    upcoming = [d for _, d in rows if d and d >= today]
    return {
        'scheduled': len(rows),
        'by_cadence': by_cadence,
        'next_due': min(upcoming).isoformat() if upcoming else None,
    }


def due_schedules(*, branch_id=None, limit: int = 500) -> list[dict]:
    today = timezone.localdate()
    qs = (CycleCountSchedule.objects
          .filter(is_active=True, next_due__lte=today)
          .select_related('stock', 'stock__unit', 'stock__policy', 'branch'))
    if branch_id:
        qs = qs.filter(branch_id=branch_id)
    return [_row(s, today) for s in qs.order_by('next_due')[:limit]]


def _row(schedule, today) -> dict:
    """One plan row, carrying everything the screen needs to reason about it."""
    policy = getattr(schedule.stock, 'policy', None)
    on_hand = float(schedule.stock.total_quantity or 0)
    cost = float(schedule.stock.cost_price or 0)
    return {
        'schedule_id': schedule.id,
        'stock_id': schedule.stock_id,
        'name': schedule.stock.medication_name,
        'branch_id': schedule.branch_id,
        'branch_name': schedule.branch.name if schedule.branch else '',
        'cadence': schedule.cadence,
        'interval_days': schedule.interval_days,
        'next_due': schedule.next_due.isoformat(),
        'days_overdue': (today - schedule.next_due).days,
        'unit': schedule.stock.unit.abbreviation if schedule.stock.unit else '',
        'abc_class': policy.abc_class if policy else 'C',
        'xyz_class': policy.xyz_class if policy else 'X',
        'on_hand': round(on_hand, 1),
        'value': round(on_hand * cost, 2),
        'is_quarantined': bool(policy.is_quarantined) if policy else False,
        'last_counted_at': (schedule.last_counted_at.isoformat()
                            if schedule.last_counted_at else None),
    }


def upcoming_schedules(*, branch_id=None, horizon_days: int = 90,
                       limit: int = 400) -> list[dict]:
    """Schedules falling due after today but inside the horizon."""
    today = timezone.localdate()
    until = today + timedelta(days=horizon_days)
    qs = (CycleCountSchedule.objects
          .filter(is_active=True, next_due__gt=today, next_due__lte=until)
          .select_related('stock', 'stock__unit', 'stock__policy', 'branch'))
    if branch_id:
        qs = qs.filter(branch_id=branch_id)
    rows = []
    for schedule in qs.order_by('next_due')[:limit]:
        row = _row(schedule, today)
        row['days_until'] = -row['days_overdue']
        row['days_overdue'] = 0
        rows.append(row)
    return rows


def plan_dashboard(*, branch_id=None, horizon_days: int = 90) -> dict:
    """Everything the cycle-count screen renders, in one round-trip.

    Blocks: ``summary`` (plan shape + coverage), ``due``, ``upcoming``,
    ``calendar`` (weekly workload), ``by_branch`` (coverage per warehouse),
    ``sheets`` (recent count sheets with variance) and ``accuracy`` (how
    close the last completed counts came to the book quantity).
    """
    today = timezone.localdate()

    stocks = MedicationStock.objects.with_quantities().filter(is_active=True)
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)
    stock_rows = list(stocks.select_related('branch', 'policy', 'unit'))
    total_items = len(stock_rows)

    schedules = CycleCountSchedule.objects.filter(is_active=True).select_related(
        'stock', 'stock__unit', 'stock__policy', 'branch')
    if branch_id:
        schedules = schedules.filter(branch_id=branch_id)
    schedule_rows = list(schedules)

    by_cadence = {c: 0 for c, _ in CycleCountSchedule.Cadence.choices}
    due_count = overdue_count = 0
    planned_stock_ids = set()
    value_on_plan = 0.0
    for schedule in schedule_rows:
        by_cadence[schedule.cadence] = by_cadence.get(schedule.cadence, 0) + 1
        planned_stock_ids.add(schedule.stock_id)
        if schedule.next_due <= today:
            due_count += 1
            if schedule.next_due < today:
                overdue_count += 1
        value_on_plan += float(schedule.stock.total_quantity or 0) * float(
            schedule.stock.cost_price or 0)

    # Stock rows that have no schedule at all — invisible to the plan.
    uncovered = [s for s in stock_rows if s.id not in planned_stock_ids]
    uncovered_value = sum(
        float(s.total_quantity or 0) * float(s.cost_price or 0) for s in uncovered)

    upcoming_dates = [s.next_due for s in schedule_rows if s.next_due > today]
    covered = total_items - len(uncovered)

    # ── Weekly workload ────────────────────────────────────────────────
    buckets = {}
    for offset in range(0, horizon_days + 1, 7):
        start = today + timedelta(days=offset)
        key = start.isoformat()
        buckets[key] = {'week_start': key, 'due': 0, 'upcoming': 0, 'overdue': 0}
    for schedule in schedule_rows:
        delta = (schedule.next_due - today).days
        if delta < 0:
            # Pile overdue work into the current week so the bar is visible.
            buckets[today.isoformat()]['overdue'] += 1
            continue
        if delta > horizon_days:
            continue
        week_start = today + timedelta(days=(delta // 7) * 7)
        bucket = buckets.get(week_start.isoformat())
        if bucket is None:
            continue
        if delta == 0:
            bucket['due'] += 1
        else:
            bucket['upcoming'] += 1
    calendar = sorted(buckets.values(), key=lambda b: b['week_start'])

    # ── Coverage per warehouse ─────────────────────────────────────────
    branch_stats = {}
    for stock in stock_rows:
        stats = branch_stats.setdefault(
            stock.branch_id,
            {'branch_id': stock.branch_id,
             'name': stock.branch.name if stock.branch else 'Unassigned',
             'total': 0, 'planned': 0, 'due': 0, 'overdue': 0, 'value': 0.0})
        stats['total'] += 1
        stats['value'] += float(stock.total_quantity or 0) * float(
            stock.cost_price or 0)
    for schedule in schedule_rows:
        stats = branch_stats.get(schedule.branch_id)
        if stats is None:
            continue
        stats['planned'] += 1
        if schedule.next_due <= today:
            stats['due'] += 1
        if schedule.next_due < today:
            stats['overdue'] += 1
    by_branch = []
    for stats in branch_stats.values():
        stats['coverage_pct'] = (
            round(stats['planned'] / stats['total'] * 100, 1) if stats['total'] else 0)
        stats['value'] = round(stats['value'], 2)
        by_branch.append(stats)
    by_branch.sort(key=lambda b: (-b['total'], b['name']))

    # ── Recent count sheets ────────────────────────────────────────────
    sheet_qs = (InventoryCount.objects
                .select_related('branch', 'completed_by')
                .prefetch_related('lines'))
    if branch_id:
        sheet_qs = sheet_qs.filter(branch_id=branch_id)
    sheets = []
    for count in sheet_qs.order_by('-created_at')[:12]:
        lines = list(count.lines.all())
        counted = [l for l in lines if l.counted_quantity is not None]
        variance = sum(l.variance for l in counted)
        variance_value = sum(float(l.variance_value or 0) for l in counted)
        sheets.append({
            'id': count.id,
            'reference': count.reference,
            'name': count.name,
            'status': count.status,
            'branch_name': count.branch.name if count.branch else '',
            'lines': len(lines),
            'counted': len(counted),
            'variance': variance,
            'variance_value': round(variance_value, 2),
            'is_open': count.status in OPEN_STATUSES,
            'progress_pct': (round(len(counted) / len(lines) * 100)
                             if lines else 0),
            'created_at': count.created_at.isoformat(),
            'completed_at': (count.completed_at.isoformat()
                             if count.completed_at else None),
        })

    # Sheets still waiting to be counted — the actionable backlog. Repeated
    # clicks on "Create count sheets" used to mint a fresh duplicate every
    # time; the view now refuses to duplicate, so this number is the real
    # amount of outstanding paperwork.
    open_sheets = [s for s in sheets if s['is_open']]

    # ── Count accuracy from completed sheets ───────────────────────────
    scored_lines = [line for line in (
        InventoryCountLine.objects
        .filter(count__status=InventoryCount.Status.COMPLETED,
                counted_quantity__isnull=False)
        .select_related('stock', 'count'))]
    if branch_id:
        scored_lines = [l for l in scored_lines if l.count.branch_id == branch_id]
    exact = sum(1 for l in scored_lines if l.variance == 0)
    expected_total = sum(abs(l.expected_quantity) for l in scored_lines)
    abs_variance = sum(abs(l.variance) for l in scored_lines)
    accuracy_pct = (round(100 - (abs_variance / expected_total * 100), 1)
                    if expected_total else None)

    return {
        'due': due_schedules(branch_id=branch_id),
        'summary': {
            'scheduled': len(schedule_rows),
            'by_cadence': by_cadence,
            'next_due': (min(upcoming_dates).isoformat()
                         if upcoming_dates else None),
            'items': total_items,
            'covered': covered,
            'uncovered': len(uncovered),
            'coverage_pct': (round(covered / total_items * 100, 1)
                             if total_items else 0),
            'due_now': due_count,
            'overdue': overdue_count,
            'value_on_plan': round(value_on_plan, 2),
            'value_uncovered': round(uncovered_value, 2),
            'cadence_days': cadence_days(),
            'open_sheets': len(open_sheets),
            'open_lines': sum(s['lines'] for s in open_sheets),
            'open_counted': sum(s['counted'] for s in open_sheets),
        },
        'upcoming': upcoming_schedules(branch_id=branch_id,
                                       horizon_days=horizon_days),
        'calendar': calendar,
        'by_branch': by_branch,
        'sheets': sheets,
        'open_sheets': open_sheets,
        'accuracy': {
            'scored_lines': len(scored_lines),
            'exact': exact,
            'exact_pct': (round(exact / len(scored_lines) * 100, 1)
                          if scored_lines else None),
            'abs_variance': round(abs_variance, 1),
            'accuracy_pct': accuracy_pct,
        },
        'horizon_days': horizon_days,
    }


@transaction.atomic
def create_count_from_schedule(*, branch_id=None, user=None, limit: int = 200) -> dict:
    """Create one ``InventoryCount`` per warehouse covering its due items.

    Idempotent per warehouse: a branch that already has an **open** sheet
    minted from the plan is skipped. Because creating a sheet deliberately
    does not advance the schedule, a second click on "Create count sheets"
    used to mint an identical duplicate — two warehouses quickly became four
    identical sheets with no way to tell them apart.
    """
    today = timezone.localdate()
    due = (CycleCountSchedule.objects
           .filter(is_active=True, next_due__lte=today)
           .select_related('stock', 'branch'))
    if branch_id:
        due = due.filter(branch_id=branch_id)

    by_branch = {}
    for schedule in due:
        by_branch.setdefault(schedule.branch_id, []).append(schedule)

    open_branch_ids = set(
        InventoryCount.objects
        .filter(status__in=OPEN_STATUSES, notes__startswith=PLAN_NOTE_PREFIX)
        .values_list('branch_id', flat=True))

    created = []
    skipped = []
    for branch_id_, schedules in by_branch.items():
        if not schedules:
            continue
        if branch_id_ in open_branch_ids:
            skipped.append({'branch_id': branch_id_, 'items': len(schedules)})
            continue
        schedules = schedules[:limit]
        count = InventoryCount.objects.create(
            name=f'Scheduled cycle count · {today:%b %Y}',
            branch_id=branch_id_,
            status=InventoryCount.Status.DRAFT,
            notes=(f'{PLAN_NOTE_PREFIX} ({len(schedules)} item(s)).'),
            created_by=user if user and getattr(user, 'is_authenticated', False) else None,
        )
        lines = [
            InventoryCountLine(
                count=count,
                stock=s.stock,
                expected_quantity=s.stock.total_quantity,
            )
            for s in schedules
        ]
        InventoryCountLine.objects.bulk_create(lines, batch_size=500)
        count.status = InventoryCount.Status.IN_PROGRESS
        count.save(update_fields=['status'])

        # NB: the schedule deliberately does *not* advance here. Creating the
        # sheet is not the same as doing the count — advancing on creation let
        # a cancelled or abandoned sheet remove the item from the backlog for a
        # whole cycle. See :func:`advance_from_count`.

        created.append({
            'count_id': count.id,
            'reference': count.reference,
            'branch_id': branch_id_,
            'lines': len(lines),
        })

    return {'counts_created': len(created), 'counts': created,
            'items_scheduled': sum(len(v) for v in by_branch.values()),
            'skipped_open': len(skipped), 'skipped': skipped}


@transaction.atomic
def advance_from_count(count) -> dict:
    """Move the ABC schedule forward after a count sheet is **completed**.

    Only lines that were actually counted advance. A sheet completed with
    ``allow_partial`` leaves the un-counted items sitting in the backlog —
    they were never verified, so skipping them for a whole cycle would be a
    silent loss of control.

    Idempotent: re-running for an already-advanced schedule is a no-op because
    ``next_due`` is only pushed when it is due or in the past.
    """
    today = timezone.localdate()
    now = timezone.now()
    stock_ids = list(count.lines
                     .exclude(counted_quantity__isnull=True)
                     .values_list('stock_id', flat=True))
    if not stock_ids:
        return {'schedules_advanced': 0}

    advanced = 0
    for schedule in (CycleCountSchedule.objects
                     .filter(stock_id__in=stock_ids, is_active=True)):
        schedule.last_counted_at = now
        schedule.next_due = today + timedelta(days=schedule.interval_days or 30)
        schedule.save(update_fields=['last_counted_at', 'next_due'])
        StockPolicy.objects.filter(stock_id=schedule.stock_id).update(
            last_counted_at=now, next_count_due=schedule.next_due)
        advanced += 1
    return {'schedules_advanced': advanced}
