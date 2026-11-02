"""Derived analytics for the organization Command Center.

Everything here is a **pure function** over the per-tenant rows that
``organizations.views.organization_stats`` already collects, so the numbers on
screen can be unit-tested without a database or a tenant schema switch.

The guiding rule: never invent a metric. Each score is a weighted statement
about data the API actually returns, and every score can be explained to the
person reading it (that is what ``reasons`` is for).
"""
from __future__ import annotations

SEVERITY_ORDER = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}

#: Score bands, richest first. The labels are used verbatim in the UI.
BANDS = (
    (85, 'healthy', 'Healthy'),
    (65, 'watch', 'Watch'),
    (40, 'at-risk', 'At risk'),
    (0, 'critical', 'Critical'),
)


def band_for(score) -> tuple[str, str]:
    """``92`` → ``('healthy', 'Healthy')``."""
    try:
        value = float(score)
    except (TypeError, ValueError):
        value = 0
    for threshold, key, label in BANDS:
        if value >= threshold:
            return key, label
    return 'critical', 'Critical'


def trend_pct(series, window: int):
    """Change of the last ``window`` points against the one before it.

    Returns ``None`` when there is no comparable period — a percentage
    off a zero base is not a fact, it is noise (the traffic page caps the same
    problem at ±999%).
    """
    try:
        size = int(window)
    except (TypeError, ValueError):
        return None
    series = [float(v or 0) for v in (series or [])]
    if size <= 0 or len(series) < size:
        return None
    current = sum(series[-size:])
    previous = sum(series[-size * 2:-size])
    if not previous:
        return None if not current else None
    return round((current - previous) / previous * 100, 1)


def _sum(series) -> float:
    return sum(float(v or 0) for v in (series or []))


def tenant_health(row: dict) -> dict:
    """A 0-100 operating score for one facility, plus why.

    Four components, deliberately weighted by what an operator can act on:

    * **Availability (30)** — an offline facility serves nobody.
    * **Staffing (20)** — no users means nobody can work in it.
    * **Freshness (20)** — no recorded activity recently means the data on
      this console is stale, not that the facility is quiet.
    * **Pressure (30)** — unread alerts and items below reorder level.
    """
    reasons = []

    available = 30 if row.get('is_active') else 0
    if not row.get('is_active'):
        reasons.append({'tone': 'critical', 'text': 'Facility is offline'})

    users = int(row.get('user_count') or 0)
    if users <= 0:
        staffing = 0
        reasons.append({'tone': 'high', 'text': 'No users are provisioned'})
    elif users <= 2:
        staffing = 12
        reasons.append({'tone': 'medium', 'text': f'Only {users} user(s) provisioned'})
    else:
        staffing = 20

    # Freshness is derived from the newest audit event; without one we cannot
    # claim the facility is live, so it scores zero rather than guessing.
    last = row.get('last_event_at')
    age_days = row.get('last_event_age_days')
    if age_days is None or not last:
        freshness = 0
        reasons.append({'tone': 'medium', 'text': 'No activity recorded yet'})
    elif age_days <= 1:
        freshness = 20
    elif age_days <= 7:
        freshness = 14
    elif age_days <= 30:
        freshness = 8
        reasons.append({'tone': 'low', 'text': f'Last activity {int(age_days)} days ago'})
    else:
        freshness = 3
        reasons.append({'tone': 'medium', 'text': f'Last activity {int(age_days)} days ago'})

    alerts = int(row.get('active_alerts') or 0)
    low_stock = int(row.get('low_stock_items') or 0)
    pressure = 30 - min(15, alerts * 3) - min(15, round(low_stock * 1.5))
    pressure = max(0, pressure)
    if alerts:
        reasons.append({
            'tone': 'high' if alerts >= 3 else 'medium',
            'text': f'{alerts} unread alert(s)',
        })
    if low_stock:
        reasons.append({
            'tone': 'high' if low_stock >= 5 else 'medium',
            'text': f'{low_stock} item(s) below reorder level',
        })

    score = max(0, min(100, available + staffing + freshness + pressure))
    key, label = band_for(score)
    return {
        'score': int(score),
        'band': key,
        'label': label,
        'reasons': reasons[:4],
        'components': [
            {'key': 'availability', 'label': 'Availability', 'score': available, 'max': 30},
            {'key': 'staffing', 'label': 'Staffing', 'score': staffing, 'max': 20},
            {'key': 'freshness', 'label': 'Data freshness', 'score': freshness, 'max': 20},
            {'key': 'pressure', 'label': 'Operational pressure', 'score': pressure, 'max': 30},
        ],
    }


def org_health(rows) -> dict:
    """Network score: the equal-weighted mean of the facility scores.

    Equal weighting is deliberate — a small clinic that is down is exactly as
    much of an outage as a large hospital that is down, and revenue-weighting
    would hide it.
    """
    rows = list(rows or [])
    if not rows:
        return {
            'score': 0, 'band': 'critical', 'label': 'No facilities',
            'facilities': 0,
            'components': [
                {'key': 'availability', 'label': 'Availability', 'score': 0, 'max': 30},
                {'key': 'staffing', 'label': 'Staffing', 'score': 0, 'max': 20},
                {'key': 'freshness', 'label': 'Data freshness', 'score': 0, 'max': 20},
                {'key': 'pressure', 'label': 'Operational pressure', 'score': 0, 'max': 30},
            ],
        }

    scores = [int(row.get('health', {}).get('score') or 0) for row in rows]
    score = round(sum(scores) / len(scores))
    key, label = band_for(score)

    components = []
    for index, meta in enumerate(rows[0]['health']['components']):
        part_scores = [
            row['health']['components'][index]['score']
            for row in rows
            if row.get('health', {}).get('components')
        ]
        components.append({
            'key': meta['key'],
            'label': meta['label'],
            'score': round(sum(part_scores) / len(part_scores)) if part_scores else 0,
            'max': meta['max'],
        })

    return {
        'score': int(score),
        'band': key,
        'label': label,
        'facilities': len(rows),
        'healthy': sum(1 for s in scores if s >= 85),
        'watch': sum(1 for s in scores if 65 <= s < 85),
        'at_risk': sum(1 for s in scores if 40 <= s < 65),
        'critical': sum(1 for s in scores if s < 40),
        'components': components,
    }


def attention_queue(rows) -> list:
    """Ranked, actionable findings across every facility.

    Only real conditions become entries — an empty queue is a legitimate
    "nothing needs you" answer and the UI says so instead of padding the list.
    """
    queue = []

    for row in rows or []:
        name = row.get('name') or 'Facility'
        base = {
            'tenant_id': row.get('id'),
            'tenant_name': name,
            'tenant_type': row.get('type'),
            'is_online': bool(row.get('is_active')),
            'health': (row.get('health') or {}).get('score'),
        }

        if not row.get('is_active'):
            queue.append({
                **base, 'key': f'offline-{row.get("id")}', 'kind': 'offline',
                'severity': 'critical',
                'title': f'{name} is offline',
                'detail': 'Suspended or unpublished — its users cannot sign in.',
                'metric': None,
            })

        users = int(row.get('user_count') or 0)
        if row.get('is_active') and users <= 0:
            queue.append({
                **base, 'key': f'nousers-{row.get("id")}', 'kind': 'no_users',
                'severity': 'high',
                'title': f'{name} has no users',
                'detail': 'Nobody can operate this facility until a user is provisioned.',
                'metric': 0,
            })

        low_stock = int(row.get('low_stock_items') or 0)
        if low_stock > 0:
            queue.append({
                **base, 'key': f'low-{row.get("id")}', 'kind': 'low_stock',
                'severity': 'high' if low_stock >= 5 else 'medium',
                'title': f'{low_stock} item(s) below reorder level',
                'detail': f'{name} — restock to avoid a stock-out.',
                'metric': low_stock,
            })

        alerts = int(row.get('active_alerts') or 0)
        if alerts > 0:
            queue.append({
                **base, 'key': f'alerts-{row.get("id")}', 'kind': 'alerts',
                'severity': 'high' if alerts >= 5 else 'medium',
                'title': f'{alerts} unread alert(s)',
                'detail': f'{name} — nobody has acknowledged them.',
                'metric': alerts,
            })

        age = row.get('last_event_age_days')
        if row.get('is_active') and age is not None and age > 7:
            queue.append({
                **base, 'key': f'stale-{row.get("id")}', 'kind': 'stale',
                'severity': 'low',
                'title': f'No activity for {int(age)} days',
                'detail': f'{name} — figures on this console may be out of date.',
                'metric': int(age),
            })

    queue.sort(key=lambda item: (
        SEVERITY_ORDER.get(item['severity'], 9),
        -(item.get('metric') or 0),
        item.get('tenant_name') or '',
    ))
    return queue


def severity_counts(queue) -> dict:
    counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0}
    for item in queue or []:
        key = item.get('severity')
        if key in counts:
            counts[key] += 1
    return counts


def mix(rows, key: str) -> list:
    """Share of a numeric metric per facility, largest first.

    Facilities with a zero (or absent) metric are dropped: a donut padded with
    empty slices misrepresents the mix.
    """
    items = []
    total = 0.0
    for row in rows or []:
        value = row.get(key)
        if value is None:
            continue
        try:
            number = float(value)
        except (TypeError, ValueError):
            continue
        if number <= 0:
            continue
        total += number
        items.append({
            'tenant_id': row.get('id'),
            'name': row.get('name'),
            'type': row.get('type'),
            'value': round(number, 2),
        })

    for item in items:
        item['share'] = round(item['value'] / total * 100, 1) if total else 0.0

    items.sort(key=lambda item: -item['value'])
    return items


def headline_for(row) -> dict:
    """The single number that matters most for each facility type.

    Type-driven on purpose: "users" is the best available signal for a
    hospital that does not report revenue, whereas a pharmacy's headline is
    what it sold.
    """
    ttype = row.get('type')
    if row.get('revenue_30d') is not None:
        return {'key': 'revenue_30d', 'label': 'Revenue · 30d',
                'value': row.get('revenue_30d'), 'format': 'money'}
    if row.get('appointments_today') is not None:
        return {'key': 'appointments_today', 'label': 'Appointments today',
                'value': row.get('appointments_today'), 'format': 'count'}
    if row.get('patient_count') is not None:
        return {'key': 'patient_count', 'label': 'Patients',
                'value': row.get('patient_count'), 'format': 'count'}
    if ttype == 'homecare':
        return {'key': 'user_count', 'label': 'Care team',
                'value': row.get('user_count'), 'format': 'count'}
    return {'key': 'user_count', 'label': 'Users',
            'value': row.get('user_count'), 'format': 'count'}


def heatmap(rows, days: int) -> dict:
    """Facility × day activity grid for the window.

    Returns pre-normalised intensities so the browser does no maths to decide
    a cell colour, and so two facilities with very different volumes stay
    comparable (each row is scaled against the busiest row).
    """
    labels = []
    rows = list(rows or [])
    series = [[float(v or 0) for v in (row.get('activity') or [])] for row in rows]

    length = max((len(values) for values in series), default=0)
    if length > days:
        series = [values[-days:] for values in series]
        length = days

    peak = max((max(values) if values else 0 for values in series), default=0)

    out_rows = []
    for index, row in enumerate(rows):
        values = series[index] if index < len(series) else []
        total = sum(values)
        out_rows.append({
            'tenant_id': row.get('id'),
            'name': row.get('name'),
            'type': row.get('type'),
            'values': values,
            'total': int(total),
            'peak': max(values) if values else 0,
            'cells': [
                # `level` is what the CSS keys off: 0 = no activity.
                {'value': int(v), 'level': _level(v, peak)}
                for v in values
            ],
        })

    return {'days': length, 'peak': peak, 'labels': labels, 'rows': out_rows}


def _level(value, peak) -> int:
    if not value or not peak:
        return 0
    ratio = float(value) / float(peak)
    if ratio >= 0.85:
        return 4
    if ratio >= 0.6:
        return 3
    if ratio >= 0.35:
        return 2
    if ratio > 0:
        return 1
    return 0
