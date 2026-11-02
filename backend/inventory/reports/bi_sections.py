"""Analytical engines behind the advanced BI report sections.

The on-screen BI workspace computes forecasts, variance bridges, optimisation
scenarios and the report index **in the browser** (``nuxtfrontend/utils/bi.js``).
The PDF is rendered on the server, so those models have to exist twice. They
live here, in one module, for three reasons:

* :mod:`inventory.reports.bi` stays focused on *assembling tenant data*, not on
  statistics;
* the ported maths is testable without touching a template;
* the two implementations sit side by side, so drift is easy to spot.

Every function is pure: it takes already-loaded rows and returns plain dicts.
Nothing here queries the database except :func:`build_operational_index`, which
only reads the static tabular-report catalogue.

Output is formatted by the renderer, never here. All user-facing strings are
ASCII on purpose - reportlab's Helvetica is WinAnsi and silently prints a stray
``G`` for geometric-shape glyphs.
"""
from __future__ import annotations

import datetime as _dt
import math
from calendar import month_abbr
from collections import defaultdict

# ── scalar helpers ──────────────────────────────────────────────────────
def _num(value, default=0.0):
    try:
        result = float(value)
    except (TypeError, ValueError):
        return default
    return result if math.isfinite(result) else default


def _mean(values):
    values = list(values)
    return sum(values) / len(values) if values else 0.0


def _std(values):
    """Sample standard deviation (n-1), matching the browser engine."""
    values = list(values)
    if len(values) < 2:
        return 0.0
    centre = _mean(values)
    return math.sqrt(sum((v - centre) ** 2 for v in values) / (len(values) - 1))


def _cv(values):
    centre = abs(_mean(values))
    return (_std(values) / centre) if centre else 0.0


def _clamp(value, low, high):
    return max(low, min(high, _num(value)))


def _safe_div(a, b, fallback=0.0):
    b = _num(b)
    return _num(a) / b if b else fallback


def _z_for(confidence):
    """Two-sided z multiplier for a confidence level."""
    confidence = _num(confidence, 95.0)
    if confidence >= 99:
        return 2.576
    if confidence >= 95:
        return 1.96
    if confidence >= 90:
        return 1.645
    return 1.282


def _next_month_labels(end_date, count):
    """``['Dec 2026', 'Jan 2027', ...]`` starting the month after ``end_date``."""
    labels = []
    year, month = end_date.year, end_date.month
    for _ in range(count):
        month += 1
        if month > 12:
            month = 1
            year += 1
        labels.append(f'{month_abbr[month]} {year}')
    return labels


# ── models ──────────────────────────────────────────────────────────────
def _linreg(values):
    """Ordinary least squares on an evenly spaced series."""
    ys = [_num(v) for v in values]
    n = len(ys)
    if n < 2:
        level = ys[0] if ys else 0.0
        return {'slope': 0.0, 'intercept': level, 'r2': 0.0, 'n': n}

    mean_x = (n - 1) / 2.0
    mean_y = _mean(ys)
    sxy = sxx = syy = 0.0
    for i, y in enumerate(ys):
        dx = i - mean_x
        sxy += dx * (y - mean_y)
        sxx += dx * dx
        syy += (y - mean_y) ** 2
    slope = (sxy / sxx) if sxx else 0.0
    intercept = mean_y - slope * mean_x
    r2 = (sxy ** 2) / (sxx * syy) if sxx and syy else 0.0
    return {'slope': slope, 'intercept': intercept, 'r2': r2, 'n': n}


def _holt_linear(values, alpha=0.55, beta=0.30, horizon=4):
    """Holt's linear trend (double exponential smoothing)."""
    ys = [_num(v) for v in values]
    n = len(ys)
    if n < 2:
        level = ys[0] if ys else 0.0
        return {'fitted': list(ys), 'forecast': [level] * horizon,
                'level': level, 'trend': 0.0, 'mae': 0.0, 'mape': 0.0}

    level = ys[0]
    trend = ys[1] - ys[0]
    fitted = [level]
    for i in range(1, n):
        fitted.append(level + trend)
        previous_level = level
        level = alpha * ys[i] + (1 - alpha) * (level + trend)
        trend = beta * (level - previous_level) + (1 - beta) * trend

    forecast = [max(0.0, level + h * trend) for h in range(1, horizon + 1)]
    absolute_error = 0.0
    absolute_pct = 0.0
    counted = 0
    for i in range(1, n):
        error = abs(ys[i] - fitted[i])
        absolute_error += error
        if ys[i]:
            absolute_pct += error / abs(ys[i])
            counted += 1
    return {
        'fitted': fitted,
        'forecast': forecast,
        'level': level,
        'trend': trend,
        'mae': absolute_error / max(n - 1, 1),
        'mape': (absolute_pct / counted * 100.0) if counted else 0.0,
    }


def _accuracy(actual, fitted):
    """Error statistics for a back-test against the in-sample fit."""
    pairs = list(zip(actual, fitted))
    if not pairs:
        return {'mae': 0.0, 'mape': 0.0, 'rmse': 0.0, 'bias': 0.0, 'r2': 0.0}
    absolute_error = squared_error = bias = absolute_pct = 0.0
    counted = 0
    for a, f in pairs:
        error = _num(a) - _num(f)
        absolute_error += abs(error)
        squared_error += error * error
        bias += error
        if a:
            absolute_pct += abs(error / _num(a))
            counted += 1
    n = len(pairs)
    centre = _mean([_num(a) for a, _ in pairs])
    total_variance = sum((_num(a) - centre) ** 2 for a, _ in pairs)
    r2 = (1 - squared_error / total_variance) if total_variance else 0.0
    return {
        'mae': absolute_error / n,
        'mape': (absolute_pct / counted * 100.0) if counted else 0.0,
        'rmse': math.sqrt(squared_error / n),
        'bias': bias / n,
        'r2': r2,
    }


def _anomalies(values, k=1.5):
    """z-score outliers in a series."""
    values = [_num(v) for v in values]
    if len(values) < 3:
        return []
    centre = _mean(values)
    deviation = _std(values) or 1.0
    out = []
    for index, value in enumerate(values):
        z = (value - centre) / deviation
        if abs(z) >= k:
            out.append({'index': index, 'value': value, 'z': z})
    return sorted(out, key=lambda r: -abs(r['z']))


# ── 1. Forecasts & trends ───────────────────────────────────────────────
def build_forecast(history, end_date, *, horizon=6, confidence=95,
                   history_months=None):
    """Project revenue from the monthly series.

    ``history`` points need ``label`` and ``value``; ``history_months`` is an
    optional parallel list of calendar months (1-12) used for the seasonal
    profile. Returns ``{'available': False, ...}`` when there is not enough
    history to fit a trend honestly.
    """
    values = [_num(p.get('value')) for p in history or []]
    selling_periods = sum(1 for v in values if v > 0)
    # A projection fitted on two or three points, one of which carries the
    # entire total, produces a technically-computed but meaningless line (it
    # reads "next period: 0.00" because the slope is riding one spike). Refuse
    # rather than print a number nobody should act on.
    if len(values) < 4 or selling_periods < 2:
        return {'available': False,
                'reason': ('A projection needs at least four monthly periods, '
                           'two of which carry sales. This selection has '
                           f'{len(values)} period(s) and {selling_periods} '
                           'with revenue, so a fitted trend would only be '
                           'describing a single spike.')}

    holt = _holt_linear(values, horizon=horizon)
    regression = _linreg(values)
    fitted = holt['fitted']
    point_forecast = holt['forecast']

    residuals = [values[i] - fitted[i] for i in range(1, len(values))]
    residual_std = _std(residuals)
    z = _z_for(confidence)

    labels = _next_month_labels(end_date, horizon)
    points = []
    for index, value in enumerate(point_forecast):
        width = z * residual_std * math.sqrt(index + 1)
        points.append({
            'label': labels[index],
            'value': round(value, 2),
            'low': round(max(0.0, value - width), 2),
            'high': round(value + width, 2),
        })

    accuracy = _accuracy(values[1:], fitted[1:])
    total_forecast = sum(point_forecast)
    total_history = sum(values)
    run_rate = total_history / max(len(values), 1)

    # What-if scenarios shift the whole projection; they are arithmetic, not
    # opinion, so the reader can see exactly what assumption produced them.
    scenarios = []
    for delta in (-10.0, -5.0, 0.0, 5.0, 10.0):
        projected = total_forecast * (1 + delta / 100.0)
        scenarios.append({
            'delta_pct': delta,
            'label': 'Base case' if not delta else f'{delta:+.0f}%',
            'value': round(projected, 2),
            'per_month': round(projected / horizon, 2),
        })

    # Seasonal index by calendar month (relative to the overall mean).
    seasonal = []
    months = []
    for raw in history_months or []:
        try:
            months.append(int(raw))
        except (TypeError, ValueError):
            months.append(0)
    if len(months) == len(values) and any(months):
        buckets = defaultdict(list)
        for month, value in zip(months, values):
            if 1 <= month <= 12:
                buckets[month].append(value)
        overall = _mean(values)
        for month in range(1, 13):
            samples = buckets.get(month, [])
            seasonal.append({
                'label': month_abbr[month],
                'index': round((_mean(samples) / overall) if samples and overall else 1.0, 3),
                'samples': len(samples),
                'average': round(_mean(samples), 2) if samples else 0.0,
            })

    anomalies = [
        {'label': history[row['index']]['label'],
         'value': round(row['value'], 2),
         'z': round(row['z'], 2)}
        for row in _anomalies(values, k=1.5)
    ]

    return {
        'available': True,
        'method': 'Holt linear trend',
        'horizon': horizon,
        'confidence': confidence,
        'history': [{'label': p.get('label'), 'value': round(_num(p.get('value')), 2)}
                    for p in history],
        'fitted': [round(v, 2) for v in fitted],
        'forecast': points,
        'accuracy': {
            'mae': round(accuracy['mae'], 2),
            'mape': round(accuracy['mape'], 1),
            'rmse': round(accuracy['rmse'], 2),
            'bias': round(accuracy['bias'], 2),
            'r2': round(accuracy['r2'], 3),
        },
        'slope': round(holt['trend'], 2),
        'next_value': points[0]['value'] if points else 0.0,
        'total_forecast': round(total_forecast, 2),
        'average_history': round(run_rate, 2),
        'residual_std': round(residual_std, 2),
        'scenarios': scenarios,
        'seasonal': seasonal,
        'anomalies': anomalies,
        'regression_r2': round(regression['r2'], 3),
        'direction': ('rising' if holt['trend'] > 0
                      else 'falling' if holt['trend'] < 0 else 'flat'),
    }


def build_forecast_findings(forecast, currency='KES'):
    """Plain-English reading of the projection, tied to its own numbers."""
    if not forecast.get('available'):
        return [forecast.get('reason', 'No forecast available for this period.')]

    money = lambda v: f'{currency} {_num(v):,.2f}'
    mape = forecast['accuracy']['mape']
    findings = []

    findings.append(
        f'The fitted trend is {forecast["direction"]} by '
        f'{money(abs(forecast["slope"]))} per month; the next period is '
        f'projected at {money(forecast["next_value"])}.')

    findings.append(
        f'The next {forecast["horizon"]} periods total '
        f'{money(forecast["total_forecast"])}. The {forecast["confidence"]:.0f}% '
        f'interval widens with distance and is widest in '
        f'{forecast["forecast"][-1]["label"]} '
        f'({money(forecast["forecast"][-1]["low"])} to '
        f'{money(forecast["forecast"][-1]["high"])}).')

    if mape < 12:
        quality = 'strong'
    elif mape < 25:
        quality = 'workable'
    else:
        quality = 'weak'
    findings.append(
        f'Back-tested accuracy is {quality}: mean absolute percentage error '
        f'{mape:.1f}%, R-squared {forecast["accuracy"]["r2"]:.2f} over '
        f'{len(forecast["history"])} months of history.')

    seasonal = [s for s in forecast.get('seasonal') or [] if s['samples']]
    if seasonal:
        peak = max(seasonal, key=lambda s: s['index'])
        trough = min(seasonal, key=lambda s: s['index'])
        findings.append(
            f'Seasonality is visible: {peak["label"]} runs '
            f'{peak["index"]:.2f}x the average month and {trough["label"]} '
            f'{trough["index"]:.2f}x, so a flat run-rate target would over-plan '
            f'one and under-plan the other.')

    for anomaly in (forecast.get('anomalies') or [])[:2]:
        findings.append(
            f'{anomaly["label"]} is an outlier at {money(anomaly["value"])} '
            f'(z = {anomaly["z"]:.1f}) and is pulling the fitted line.')
    return findings


# ── 2. Root-cause analysis ──────────────────────────────────────────────
def build_root_cause(*, current, previous, discount_current=0.0,
                     discount_previous=0.0, stockout_rows=None,
                     history=None, currency='KES'):
    """Price / volume / mix bridge plus separately-measured leakage.

    The bridge **reconciles by construction**: ``mix`` is defined as the
    residual, so opening + price + volume + mix always equals closing. The
    screen version adds discount and stockout effects into the same walk, which
    double-counts because those movements are already inside price and volume.
    They are therefore reported as a separate leakage block instead.
    """
    cur_revenue = _num(current.get('revenue'))
    prev_revenue = _num(previous.get('revenue'))
    cur_orders = int(_num(current.get('orders')))
    prev_orders = int(_num(previous.get('orders')))

    total = cur_revenue - prev_revenue
    cur_aov = _safe_div(cur_revenue, cur_orders)
    prev_aov = _safe_div(prev_revenue, prev_orders)

    price_effect = (cur_aov - prev_aov) * cur_orders
    volume_effect = (cur_orders - prev_orders) * prev_aov
    mix_effect = total - price_effect - volume_effect

    bridge = [
        {'label': 'Opening revenue', 'impact': 0.0,
         'running': round(prev_revenue, 2), 'kind': 'open'},
        {'label': 'Price effect', 'impact': round(price_effect, 2),
         'running': round(prev_revenue + price_effect, 2), 'kind': 'step'},
        {'label': 'Volume effect', 'impact': round(volume_effect, 2),
         'running': round(prev_revenue + price_effect + volume_effect, 2),
         'kind': 'step'},
        {'label': 'Mix effect', 'impact': round(mix_effect, 2),
         'running': round(cur_revenue, 2), 'kind': 'step'},
        {'label': 'Closing revenue', 'impact': round(total, 2),
         'running': round(cur_revenue, 2), 'kind': 'close'},
    ]

    drivers = [
        {'id': 'price', 'label': 'Price', 'impact': round(price_effect, 2),
         'hint': 'Average basket movement applied to this period\'s order count'},
        {'id': 'volume', 'label': 'Volume', 'impact': round(volume_effect, 2),
         'hint': 'Order-count movement valued at the previous average basket'},
        {'id': 'mix', 'label': 'Mix', 'impact': round(mix_effect, 2),
         'hint': 'Residual: what neither price nor volume explains'},
    ]
    absolute_total = sum(abs(d['impact']) for d in drivers) or 1.0
    for driver in drivers:
        driver['weight_pct'] = round(abs(driver['impact']) / absolute_total * 100, 1)
        driver['direction'] = 'up' if driver['impact'] >= 0 else 'down'
    drivers.sort(key=lambda d: -abs(d['impact']))

    stockouts = stockout_rows or []
    lost_revenue = sum(_num(r.get('value_at_risk')) for r in stockouts)
    discount_effect = -(discount_current - discount_previous)
    gross_current = cur_revenue + discount_current
    discount_rate = _safe_div(discount_current, gross_current) * 100

    leakage = [
        {'label': 'Discount given', 'value': round(discount_current, 2),
         'change': round(discount_effect, 2),
         'note': f'{discount_rate:.1f}% of gross value'
                 if gross_current else 'No gross value recorded'},
        {'label': 'Stock-out cost', 'value': round(lost_revenue, 2),
         'change': round(-lost_revenue, 2),
         'note': f'{len(stockouts)} item(s) at or below reorder level'},
    ]

    delta_pct = ((total / abs(prev_revenue)) * 100) if prev_revenue else None
    if total > 0:
        tone, headline = 'positive', 'Revenue grew on a positive movement'
    elif total < 0:
        tone, headline = 'negative', 'Revenue fell - the bridge shows where'
    else:
        tone, headline = 'neutral', 'Revenue was flat period-on-period'

    if drivers and abs(drivers[0]['impact']) > 0:
        lead = drivers[0]
        detail = (f'{lead["label"]} is the largest single contributor at '
                  f'{currency} {abs(lead["impact"]):,.2f} '
                  f'({lead["weight_pct"]:.0f}% of total movement).')
    else:
        detail = 'No movement to attribute in this selection.'

    top_lost = sorted(stockouts, key=lambda r: -_num(r.get('value_at_risk')))[:8]

    return {
        'current': {'revenue': round(cur_revenue, 2),
                    'orders': cur_orders,
                    'aov': round(cur_aov, 2)},
        'previous': {'revenue': round(prev_revenue, 2),
                     'orders': prev_orders,
                     'aov': round(prev_aov, 2)},
        'net_change': round(total, 2),
        'delta_pct': None if delta_pct is None else round(delta_pct, 1),
        'bridge': bridge,
        'drivers': drivers,
        'leakage': leakage,
        'discount': {'current': round(discount_current, 2),
                     'previous': round(discount_previous, 2),
                     'rate_pct': round(discount_rate, 1),
                     'effect': round(discount_effect, 2)},
        'stockouts': [{'label': r.get('label'),
                       'on_hand': int(_num(r.get('on_hand'))),
                       'reorder': int(_num(r.get('reorder'))),
                       'value_at_risk': round(_num(r.get('value_at_risk')), 2)}
                      for r in top_lost],
        'lost_revenue': round(lost_revenue, 2),
        'verdict': {'tone': tone, 'headline': headline, 'detail': detail,
                    'chip': f'{currency} {total:,.2f}'},
        'anomalies': [
            {'label': history[row['index']].get('label') if history else '',
             'value': round(row['value'], 2), 'z': round(row['z'], 2)}
            for row in _anomalies([_num(p.get('value')) for p in history or []],
                                  k=1.5)
        ] if history else [],
    }


# ── 3. Optimisation and actions ─────────────────────────────────────────
DEFAULT_ASSUMPTIONS = {
    'lead_time_days': 14.0,
    'order_cost': 2500.0,
    'holding_rate': 22.0,
    'min_margin_pct': 15.0,
    'service_level': 95.0,
    'target_margin_pct': 28.0,
}


def build_optimization(*, products, stock_by_name, span_days, branches=None,
                       assumptions=None, currency='KES'):
    """Pricing, discount guardrails, replenishment, markdown and allocation.

    Items whose purchase cost is unrecorded are **excluded** from every
    margin-based recommendation rather than being given an assumed cost - a
    made-up 70% margin would produce confident, wrong prices. They are counted
    and reported so the exclusion is visible.
    """
    config = dict(DEFAULT_ASSUMPTIONS)
    for key, value in (assumptions or {}).items():
        if key in config and value not in (None, ''):
            config[key] = _num(value, config[key])
    service_z = _z_for(config['service_level'])
    days = max(int(span_days or 30), 1)
    lookup = stock_by_name or {}

    priced, unpriced = [], 0
    for product in products or []:
        name = str(product.get('label') or '').strip()
        if not name:
            continue
        stock = lookup.get(name.lower(), {})
        quantity = _num(product.get('quantity'))
        revenue = _num(product.get('value'))
        selling = _num(stock.get('selling_price')) or _safe_div(revenue, quantity)
        cost = _num(stock.get('cost_price'))
        if cost <= 0:
            unpriced += 1
        priced.append({
            'label': name,
            'revenue': revenue,
            'quantity': quantity,
            'selling': selling,
            'cost': cost,
            'on_hand': _num(stock.get('on_hand')),
            'reorder_level': _num(stock.get('reorder_level')),
            'next_expiry': stock.get('next_expiry'),
            # Weekly quantities drive the safety-stock deviation; the series is
            # attached to the product row by the dataset builder.
            'weekly': list(product.get('weekly') or stock.get('weekly') or []),
            'abc': product.get('abc') or 'C',
            'cumulative_pct': _num(product.get('cumulative_pct')),
            'daily_demand': quantity / days,
            'cover_days': None,
        })
        if priced[-1]['daily_demand']:
            priced[-1]['cover_days'] = priced[-1]['on_hand'] / priced[-1]['daily_demand']

    for row in priced:
        row['margin_pct'] = (
            ((row['selling'] - row['cost']) / row['selling']) * 100
            if row['selling'] else 0.0)

    eligible = [r for r in priced if r['selling'] > 0 and r['cost'] > 0]

    # -- pricing ---------------------------------------------------------
    # Only *increases* are ever recommended, and only toward the target
    # margin. A line already earning more than its target is left alone: telling
    # a manager to cut a 67%-margin product down to a 15% target would destroy
    # real gross profit, and an earlier version of this ladder did exactly that.
    pricing = []
    for row in eligible:
        if row['abc'] == 'A':
            target_margin = config['target_margin_pct']
        elif row['abc'] == 'B':
            target_margin = config['target_margin_pct'] - 3
        else:
            target_margin = config['min_margin_pct']
        target_margin = _clamp(target_margin, 1, 90)

        if row['margin_pct'] >= target_margin - 0.5:
            # Already at or above target - no price action, keep it for the
            # guardrail table instead.
            continue

        floor_price = row['cost'] / (1 - target_margin / 100.0)
        # One move at a time: never suggest more than a 15% change.
        recommended = _clamp(floor_price, row['selling'],
                             row['selling'] * 1.15)
        delta_pct = ((recommended - row['selling']) / row['selling']) * 100
        if delta_pct < 0.5:
            continue
        # Net revenue impact of the move at an own-price elasticity of -1.2.
        qty_factor = max(0.0, 1 + (-1.2) * (delta_pct / 100.0))
        new_revenue = recommended * row['quantity'] * qty_factor
        net_impact = new_revenue - row['revenue']
        pricing.append({
            'label': row['label'],
            'abc': row['abc'],
            'current': round(row['selling'], 2),
            'recommended': round(recommended, 2),
            'delta_pct': round(delta_pct, 1),
            'margin_pct': round(row['margin_pct'], 1),
            'target_margin_pct': round(target_margin, 1),
            'net_impact': round(net_impact, 2),
            # Gross-profit effect: the price move applied to the projected units.
            'margin_gain': round(
                (recommended - row['cost']) * row['quantity'] * qty_factor
                - (row['selling'] - row['cost']) * row['quantity'], 2),
        })
    for row in pricing:
        row['impact'] = max(0.0, row['net_impact'])
    pricing.sort(key=lambda r: -r['impact'])
    pricing = [r for r in pricing if r['impact'] > 0.01][:12]
    pricing_upside = sum(r['impact'] for r in pricing)

    # When nothing needs a price move, show the margin ladder instead of an
    # empty table: the reader can then see that the analysis ran and why there
    # is no action, rather than wondering whether the section is broken.
    ladder = []
    for row in sorted(eligible, key=lambda r: -r['revenue'])[:12]:
        if row['abc'] == 'A':
            target = config['target_margin_pct']
        elif row['abc'] == 'B':
            target = config['target_margin_pct'] - 3
        else:
            target = config['min_margin_pct']
        target = _clamp(target, 1, 90)
        ladder.append({
            'label': row['label'],
            'abc': row['abc'],
            'price': round(row['selling'], 2),
            'cost': round(row['cost'], 2),
            'margin_pct': round(row['margin_pct'], 1),
            'target_margin_pct': round(target, 1),
            'status': 'At target' if row['margin_pct'] >= target - 0.5
                      else 'Below target',
        })

    # -- discount guardrails ---------------------------------------------
    guardrails = []
    for row in eligible:
        floor = row['cost'] / (1 - config['min_margin_pct'] / 100.0)
        room = _clamp(((row['selling'] - floor) / row['selling']) * 100, 0, 100)
        guardrails.append({
            'label': row['label'],
            'room_pct': round(room, 1),
            'margin_pct': round(row['margin_pct'], 1),
            'note': ('Protect this line - almost no discount headroom.'
                     if room < 5 else
                     f'Discounts above {room:.1f}% breach the '
                     f'{config["min_margin_pct"]:.0f}% floor.'),
        })
    guardrails.sort(key=lambda r: r['room_pct'])

    # -- replenishment ---------------------------------------------------
    replenishment = []
    for row in priced:
        if row['daily_demand'] <= 0:
            continue
        if not row['on_hand'] and row['on_hand'] != 0:
            continue
        lead_time_demand = row['daily_demand'] * config['lead_time_days']
        cover = row['cover_days'] if row['cover_days'] is not None else 9e9
        # Only plan where cover is genuinely short of the lead time.
        if row['on_hand'] > lead_time_demand * 1.25 and cover > config['lead_time_days'] * 2:
            continue
        weekly = row['weekly'] or []
        safety = service_z * _std(weekly) if len(weekly) > 1 else 0.0
        reorder_point = lead_time_demand + safety
        annual_demand = row['daily_demand'] * 365
        holding_cost = max(0.01, row['cost'] * (config['holding_rate'] / 100.0))
        eoq = (math.sqrt((2 * annual_demand * config['order_cost']) / holding_cost)
               if annual_demand and config['order_cost'] and holding_cost else 0.0)
        order_qty = max(eoq, reorder_point - row['on_hand'] + eoq, 1.0)
        replenishment.append({
            'label': row['label'],
            'on_hand': int(round(row['on_hand'])),
            'daily_demand': round(row['daily_demand'], 2),
            'cover_days': (None if cover > 3650 else int(round(cover))),
            'safety_stock': round(safety, 1),
            'reorder_point': round(reorder_point, 1),
            'eoq': round(eoq, 1),
            'order_qty': int(round(order_qty)),
            'order_value': round(order_qty * row['cost'], 2),
        })
    replenishment.sort(key=lambda r: (r['cover_days'] if r['cover_days'] is not None else 9999))
    replenishment = replenishment[:14]
    replenishment_value = sum(r['order_value'] for r in replenishment)

    # -- markdown / clearance --------------------------------------------
    today = _dt.date.today()
    markdown = []
    for row in priced:
        expiry = row['next_expiry']
        if not expiry:
            continue
        days_to_expiry = (expiry - today).days
        if days_to_expiry > 180:
            continue
        units = row['on_hand']
        if units <= 0:
            continue
        price = row['selling'] or row['cost'] * 1.3
        cover = row['cover_days'] if row['cover_days'] is not None else 999
        # Capped clearance score: expiry urgency 50%, cover 30%, slow sell-through 20%.
        score = (_clamp(100 - (days_to_expiry / 180) * 100, 0, 100) * 0.5
                 + _clamp((cover / 120) * 100, 0, 100) * 0.3
                 + _clamp((1 - _clamp(1 - days_to_expiry / 180, 0, 1)) * 100,
                          0, 100) * 0.2)
        margin_room = _clamp(((price - row['cost']) / price) * 100, 0, 60) if price else 0
        markdown_pct = _clamp(score * 0.45, 0, margin_room)
        markdown.append({
            'label': row['label'],
            'days_to_expiry': max(0, days_to_expiry),
            'units': int(round(units)),
            'value': round(units * row['cost'], 2),
            'score': round(score, 1),
            'markdown_pct': round(markdown_pct, 1),
            'recovery': round(units * price * (1 - markdown_pct / 100.0), 2),
        })
    markdown.sort(key=lambda r: -r['score'])
    markdown = markdown[:10]
    markdown_recovery = sum(r['recovery'] for r in markdown)

    # -- allocation ------------------------------------------------------
    allocation = []
    branch_rows = [b for b in (branches or []) if _num(b.get('value')) > 0]
    if len(branch_rows) > 1:
        network_average = _mean([_num(b.get('value')) for b in branch_rows])
        for branch in branch_rows:
            ratio = _safe_div(_num(branch.get('value')), network_average, 1.0)
            if ratio >= 1.15:
                action = 'Source'
                detail = (f'Trading {abs(ratio - 1) * 100:.0f}% above the network '
                          f'average - surplus cover can serve other sites.')
            elif ratio <= 0.85:
                action = 'Receive'
                detail = (f'Trading {abs(1 - ratio) * 100:.0f}% below the network '
                          f'average - prioritise replenishment here.')
            else:
                action = 'Balanced'
                detail = 'Trading in line with the network average.'
            allocation.append({
                'label': branch.get('label'),
                'value': round(_num(branch.get('value')), 2),
                'index': round(ratio, 2),
                'action': action,
                'detail': detail,
            })

    # -- prioritised action plan -----------------------------------------
    actions = []
    if replenishment:
        actions.append({
            'title': 'Replenish the items that are out of cover',
            'impact_value': replenishment_value,
            'impact_kind': 'spend',
            'effort': 'Low',
            'owner': 'Stores',
            'detail': (f'{len(replenishment)} item(s) are short of their reorder '
                       f'point; the economic order quantities total '
                       f'{currency} {replenishment_value:,.2f}.'),
        })
    if pricing:
        actions.append({
            'title': 'Implement the pricing recommendations',
            'impact_value': round(pricing_upside, 2),
            'impact_kind': 'upside',
            'effort': 'Medium',
            'owner': 'Commercial',
            'detail': (f'{len(pricing)} priced lines have room to move toward '
                       f'their target margin without leaving elasticity '
                       f'headroom behind.'),
        })
    if markdown:
        actions.append({
            'title': 'Clear near-expiry stock before it is written off',
            'impact_value': round(markdown_recovery, 2),
            'impact_kind': 'recovery',
            'effort': 'Medium',
            'owner': 'Stores',
            'detail': (f'{len(markdown)} batch(es) expire within 180 days; the '
                       f'markdown plan recovers value that would otherwise be '
                       f'written off.'),
        })
    tight = [g for g in guardrails if g['room_pct'] < 5]
    if tight:
        actions.append({
            'title': 'Protect the thin-margin lines',
            'impact_value': 0.0,
            'impact_kind': 'guardrail',
            'effort': 'Low',
            'owner': 'Finance',
            'detail': (f'{len(tight)} item(s) have under 5% discount headroom - '
                       f'any promotion on them sells below the margin floor.'),
        })
    if unpriced:
        actions.append({
            'title': 'Record purchase costs on the unpriced items',
            'impact_value': 0.0,
            'impact_kind': 'data',
            'effort': 'Low',
            'owner': 'Procurement',
            'detail': (f'{unpriced} item(s) have no purchase cost on file and are '
                       f'excluded from pricing and margin analysis.'),
        })
    actions.sort(key=lambda a: -_num(a['impact_value']))
    for index, action in enumerate(actions, start=1):
        action['rank'] = index
        action['impact_label'] = (
            'Data fix' if action['impact_kind'] == 'data'
            else 'Guardrail' if action['impact_kind'] == 'guardrail'
            else f'{currency} {_num(action["impact_value"]):,.2f}')

    return {
        'assumptions': {k: round(v, 2) for k, v in config.items()},
        'pricing': pricing,
        'pricing_upside': round(pricing_upside, 2),
        'ladder': ladder,
        'at_target': sum(1 for r in ladder if r['status'] == 'At target'),
        'below_target': sum(1 for r in ladder if r['status'] == 'Below target'),
        'guardrails': guardrails[:10],
        'replenishment': replenishment,
        'replenishment_value': round(replenishment_value, 2),
        'markdown': markdown,
        'markdown_recovery': round(markdown_recovery, 2),
        'markdown_at_risk': round(sum(r['value'] for r in markdown), 2),
        'allocation': allocation,
        'actions': actions,
        'excluded_unpriced': unpriced,
        'eligible_items': len(eligible),
    }


# ── 4. Operational report index ─────────────────────────────────────────
def build_operational_index(*, data, currency='KES'):
    """Index of every report this workspace can produce, with live headlines.

    The web page is a *launcher*: pick a report, preview it, schedule it. A PDF
    cannot launch anything, so the equivalent is an index that states, for this
    period, what each report would say. The tabular export library is listed
    separately because those reports live in the Report Centre and export to
    PDF, Excel and CSV.
    """
    totals = data.get('totals') or {}
    stock = data.get('stock_totals') or {}
    kpi = {k['id']: k for k in data.get('kpis') or []}
    forecast = data.get('forecast') or {}
    root = data.get('root_cause') or {}
    optimization = data.get('optimization') or {}
    previous = data.get('previous') or {}

    def money(value):
        return f'{currency} {_num(value):,.2f}'

    def share(value, whole):
        return f'{_safe_div(_num(value), _num(whole)) * 100:.1f}%'

    categories = data.get('categories') or []
    products = data.get('products') or []
    segments = [s for s in (data.get('segments') or []) if s.get('customers')]
    branches = data.get('branches') or []

    analytical = [
        {'domain': 'Commercial', 'label': 'Sales variance vs target',
         'headline': money(totals.get('revenue')),
         'note': 'Actual revenue for the period'},
        {'domain': 'Commercial', 'label': 'Product performance',
         'headline': (f'{products[0]["label"][:34]}' if products else 'No sales'),
         'note': (f'{products[0]["share_pct"]:.1f}% of revenue' if products
                  else 'No product sales recorded')},
        {'domain': 'Commercial', 'label': 'Category contribution',
         'headline': (categories[0]['label'] if categories else 'No categories'),
         'note': (f'{categories[0]["share_pct"]:.1f}% of revenue' if categories
                  else 'No categorised sales')},
        {'domain': 'Commercial', 'label': 'Discount and price realisation',
         'headline': f'{(root.get("discount") or {}).get("rate_pct", 0):.1f}%',
         'note': f'{money((root.get("discount") or {}).get("current", 0))} granted'},
        {'domain': 'Inventory', 'label': 'Inventory ageing and valuation',
         'headline': money(stock.get('inventory_cost', 0)),
         'note': f'{int(stock.get("expired_units", 0)):,} expired units'},
        {'domain': 'Inventory', 'label': 'Stockout impact',
         'headline': money(root.get('lost_revenue', 0)),
         'note': f'{int(stock.get("out_of_stock", 0)):,} items out of stock'},
        {'domain': 'Finance', 'label': 'Revenue bridge (price, volume, mix)',
         'headline': money(root.get('net_change', 0)),
         'note': ('Up' if _num(root.get('net_change')) >= 0 else 'Down')
                 + ' on the previous period'},
        {'domain': 'Finance', 'label': 'Movement drivers',
         'headline': ((root.get('drivers') or [{}])[0].get('label') or '-'),
         'note': (f'{(root.get("drivers") or [{}])[0].get("weight_pct", 0):.0f}% '
                  f'of total movement' if root.get('drivers') else 'No movement')},
        {'domain': 'Predictive', 'label': 'Forecast accuracy',
         'headline': (f'MAPE {forecast["accuracy"]["mape"]:.1f}%'
                      if forecast.get('available') else 'Insufficient history'),
         'note': (f'Next period {money(forecast.get("next_value", 0))}'
                  if forecast.get('available') else 'Needs three or more months')},
        {'domain': 'Customer', 'label': 'Customer segmentation',
         'headline': f'{len(segments)} segment(s)',
         'note': f'{int(kpi.get("customers", {}).get("raw", 0)):,} identified customers'},
        {'domain': 'Operations', 'label': 'Branch performance',
         'headline': (branches[0]['label'] if branches else 'No branches'),
         'note': (f'{money(branches[0]["value"])} - {share(branches[0]["value"], totals.get("revenue"))} of network'
                  if branches else 'No branch revenue')},
        {'domain': 'Operations', 'label': 'Replenishment and pricing plan',
         'headline': money(optimization.get('replenishment_value', 0)),
         'note': f'{len(optimization.get("replenishment") or [])} item(s) to order'},
    ]

    groups = defaultdict(list)
    for row in analytical:
        groups[row['domain']].append(row)
    analytical_groups = [{'label': domain, 'items': items}
                         for domain, items in groups.items()]
    order = ['Commercial', 'Finance', 'Inventory', 'Predictive', 'Customer',
             'Operations']
    analytical_groups.sort(key=lambda g: order.index(g['label'])
                           if g['label'] in order else 99)

    # Tabular export library - real catalogue, no queries.
    tabular_groups = []
    try:
        from . import catalog as tabular
        category_labels = {c['key']: c['label'] for c in tabular.CATEGORIES}
        by_category = defaultdict(list)
        for report in tabular.REPORTS:
            by_category[report['category']].append({
                'label': report['label'],
                'description': report.get('description') or '',
                'columns': len(report.get('columns') or []),
            })
        tabular_groups = [
            {'label': category_labels.get(key, key), 'items': items}
            for key, items in by_category.items()
        ]
    except Exception:
        tabular_groups = []

    tabular_count = sum(len(g['items']) for g in tabular_groups)

    return {
        'analytical_groups': analytical_groups,
        'analytical_count': len(analytical),
        'tabular_groups': tabular_groups,
        'tabular_count': tabular_count,
        'formats': ['PDF (watermarked, letterheaded)', 'Excel (.xlsx)',
                    'CSV (UTF-8)'],
        'tiles': [
            {'label': 'Analytical reports', 'value': str(len(analytical)),
             'hint': f'{len(analytical_groups)} domains'},
            {'label': 'Export reports', 'value': str(tabular_count),
             'hint': f'{len(tabular_groups)} categories'},
            {'label': 'Export formats', 'value': '3',
             'hint': 'PDF, Excel, CSV'},
            {'label': 'Sections in this pack', 'value': str(data.get('section_count', 0)),
             'hint': 'selectable at build time'},
        ],
        'period_note': (f'Headline values are for '
                        f'{_num(data.get("span_days"))} days ending '
                        f'{(data.get("end").strftime("%d %b %Y") if data.get("end") else "")}'),
    }
