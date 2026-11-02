"""Demand forecasting and inventory-policy mathematics.

Deliberately dependency-free (no numpy/pandas): the tenant schemas are small
enough that pure-Python is faster than the import, and it keeps the Celery
workers light.

Everything here is a pure function over lists of numbers, so it is trivially
unit-testable — see ``inventory/tests.py``.

Formulas
--------
Safety stock (demand & lead-time variability):

    SS = z · sqrt(LT · σ_d² + d̄² · σ_LT²)

Reorder point:

    ROP = d̄ · LT + SS

Economic order quantity (Wilson):

    EOQ = sqrt(2 · D · S / H)

where ``D`` is annual demand, ``S`` the cost per order and ``H`` the holding
cost per unit per year.
"""
from __future__ import annotations

import math
from datetime import date, timedelta
from statistics import fmean, pstdev
from typing import Iterable, Sequence

# z-values for the common service levels (money/units at risk is symmetric
# enough that we do not need the full inverse-normal implementation).
Z_TABLE = {
    80: 0.84, 85: 1.04, 90: 1.28, 92: 1.41, 95: 1.645,
    97: 1.88, 98: 2.05, 99: 2.33, 99.5: 2.58,
}


def z_for_service_level(service_level: int | float) -> float:
    """Return the normal z-score for a target service level (percent)."""
    try:
        pct = float(service_level)
    except (TypeError, ValueError):
        return Z_TABLE[95]
    if pct <= 50:
        return 0.0
    key = min(Z_TABLE, key=lambda k: abs(k - pct))
    if abs(key - pct) <= 2:
        return Z_TABLE[key]
    # Linear interpolation between neighbouring table entries.
    lower = max((k for k in Z_TABLE if k < pct), default=80)
    upper = min((k for k in Z_TABLE if k > pct), default=99)
    lo, hi = Z_TABLE[lower], Z_TABLE[upper]
    return lo + (hi - lo) * (pct - lower) / (upper - lower)


# ── Series helpers ──────────────────────────────────────────────────────
def daily_series(rows: Iterable[tuple[date, float]], start: date,
                 end: date) -> list[float]:
    """Turn sparse ``(date, qty)`` pairs into a dense daily series.

    Missing days are genuine zeros (no sale happened), which is what the
    statistics need — dropping them would over-state the average.
    """
    by_day = {}
    for d, qty in rows:
        if d is None:
            continue
        by_day[d] = by_day.get(d, 0.0) + float(qty or 0)
    out = []
    cursor = start
    while cursor <= end:
        out.append(by_day.get(cursor, 0.0))
        cursor += timedelta(days=1)
    return out


def moving_average(series: Sequence[float], window: int = 7,
                   days_ahead: int = 1) -> list[float]:
    """Project ``window``-day moving averages ``days_ahead`` days forward."""
    if not series:
        return []
    window = max(1, min(window, len(series)))
    tail = list(series[-window:])
    avg = fmean(tail)
    return [avg] * max(1, days_ahead)


def weighted_moving_average(series: Sequence[float], window: int = 7,
                            days_ahead: int = 1) -> list[float]:
    """Like ``moving_average`` but recent days weigh more (linear weights)."""
    if not series:
        return []
    window = max(1, min(window, len(series)))
    tail = list(series[-window:])
    weights = list(range(1, len(tail) + 1))
    total = sum(weights)
    avg = sum(v * w for v, w in zip(tail, weights)) / total
    return [avg] * max(1, days_ahead)


def holt_winters(series: Sequence[float], season_length: int = 7,
                 alpha: float = 0.4, beta: float = 0.1,
                 days_ahead: int = 7) -> list[float]:
    """Additive Holt-Winters (level + trend + weekly seasonality).

    Falls back to a weighted average when there are fewer than two full
    seasons of history — a sparse series produces wild seasonal indices.
    """
    days_ahead = max(1, days_ahead)
    if len(series) < season_length * 2:
        return weighted_moving_average(series, min(7, len(series) or 1), days_ahead)

    # Initial level/trend from the first two seasons.
    first = series[:season_length]
    second = series[season_length:season_length * 2]
    level = fmean(first)
    trend = (fmean(second) - fmean(first)) / season_length
    seasonals = [v - level for v in first]

    for i, value in enumerate(series):
        idx = i % season_length
        predicted = level + trend + seasonals[idx]
        error = value - predicted
        new_level = level + alpha * error
        new_trend = trend + alpha * beta * error
        seasonals[idx] = seasonals[idx] + (1 - alpha) * error
        level, trend = new_level, new_trend

    out = []
    for step in range(1, days_ahead + 1):
        idx = (len(series) + step - 1) % season_length
        out.append(max(0.0, level + step * trend + seasonals[idx]))
    return out


def mape(actual: Sequence[float], predicted: Sequence[float]) -> float | None:
    """Mean absolute percentage error (percent), ignoring zero actuals."""
    pairs = [(a, p) for a, p in zip(actual, predicted) if a not in (None, 0)]
    if not pairs:
        return None
    return 100.0 * fmean(abs((a - p) / a) for a, p in pairs)


def classify_xyz(cv: float) -> str:
    """XYZ demand classification from the coefficient of variation."""
    if cv <= 0.25:
        return 'X'
    if cv <= 0.5:
        return 'Y'
    return 'Z'


def abc_classes(values: Sequence[float]) -> list[str]:
    """Pareto ABC split: first 70% of cumulative value = A, next 20% = B.

    Returns one letter per input value, in the original order.

    The class of an item is decided by the cumulative share **before** the
    item is added — otherwise the single item that makes up 97% of the value
    would be labelled C just because it crossed the threshold on its own.
    """
    total = sum(v for v in values if v and v > 0)
    if total <= 0:
        return ['C'] * len(values)
    order = sorted(range(len(values)), key=lambda i: values[i], reverse=True)
    out = ['C'] * len(values)
    cumulative = 0.0
    for i in order:
        share_before = cumulative / total
        out[i] = 'A' if share_before < 0.7 else 'B' if share_before < 0.9 else 'C'
        cumulative += max(0.0, values[i] or 0)
    return out


# ── Policy maths ────────────────────────────────────────────────────────
def safety_stock(avg_demand: float, demand_stddev: float,
                 lead_time_days: float, lead_time_stddev: float = 0.0,
                 service_level: float = 95) -> float:
    """``z · sqrt(LT·σ_d² + d̄²·σ_LT²)`` — handles both variability sources."""
    z = z_for_service_level(service_level)
    lt = max(0.0, float(lead_time_days or 0))
    var = lt * float(demand_stddev or 0) ** 2 \
        + float(avg_demand or 0) ** 2 * float(lead_time_stddev or 0) ** 2
    return round(z * math.sqrt(max(0.0, var)), 2)


def reorder_point(avg_demand: float, lead_time_days: float,
                  safety: float) -> float:
    """``d̄ · LT + SS``."""
    return round(float(avg_demand or 0) * float(lead_time_days or 0)
                 + float(safety or 0), 2)


def economic_order_quantity(annual_demand: float, order_cost: float,
                            holding_cost_per_unit: float) -> float:
    """Wilson EOQ; returns 0 when inputs are unusable."""
    try:
        d = float(annual_demand)
        s = float(order_cost)
        h = float(holding_cost_per_unit)
    except (TypeError, ValueError):
        return 0.0
    if d <= 0 or s <= 0 or h <= 0:
        return 0.0
    return round(math.sqrt(2 * d * s / h), 2)


def round_to_multiple(value: float, multiple: int) -> int:
    """Round an order quantity up to the supplier's pack size."""
    multiple = max(1, int(multiple or 1))
    if value <= 0:
        return 0
    return int(math.ceil(value / multiple) * multiple)


def summarise_series(series: Sequence[float]) -> dict:
    """Average, standard deviation and coefficient of variation."""
    if not series:
        return {'avg': 0.0, 'stddev': 0.0, 'cv': 0.0, 'total': 0.0}
    avg = fmean(series)
    sd = pstdev(series) if len(series) > 1 else 0.0
    return {
        'avg': round(avg, 4),
        'stddev': round(sd, 4),
        'cv': round(sd / avg, 4) if avg else 0.0,
        'total': round(sum(series), 2),
    }


def choose_method(history_days: int, min_history: int = 14) -> str:
    """Pick the forecast method the data actually supports."""
    if history_days < min_history:
        return 'naive'
    if history_days < 28:
        return 'weighted'
    return 'holt_winters'


def forecast_series(series: Sequence[float], method: str,
                    days_ahead: int = 1) -> list[float]:
    """Dispatch to the requested method."""
    if method == 'holt_winters':
        return holt_winters(series, days_ahead=days_ahead)
    if method == 'weighted':
        return weighted_moving_average(series, days_ahead=days_ahead)
    if method == 'naive':
        avg = fmean(series) if series else 0.0
        return [avg] * max(1, days_ahead)
    return moving_average(series, days_ahead=days_ahead)
