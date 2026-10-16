// ─────────────────────────────────────────────────────────────────────────
// Business Intelligence analytics engine
//
// Pure, dependency-free statistical + machine-learning style models used by
// the BI Analysis workspace (pages/analytics/bi/*). Everything runs on the
// client so the BI layer works against live tenant data without requiring a
// bespoke backend service.
//
// Covered capability families
//   • Descriptive   — aggregation, distributions, Pareto, ABC / XYZ, RFM
//   • Diagnostic    — variance attribution, driver decomposition, anomalies
//   • Predictive    — linear regression, Holt's linear trend, moving average,
//                     seasonal profiling, confidence bands, accuracy metrics
//   • Prescriptive  — EOQ, safety stock, reorder point, price elasticity,
//                     discount guardrails, markdown / clearance scoring
//   • Association   — market-basket (Apriori-style) cross-sell rules
// ─────────────────────────────────────────────────────────────────────────

export const BI_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

// ── scalar helpers ───────────────────────────────────────────────────────
export function num(v) {
  const n = Number(v)
  return Number.isFinite(n) ? n : 0
}
export function sum(arr = [], f = (x) => x) {
  return arr.reduce((s, x) => s + num(f(x)), 0)
}
export function mean(arr = []) {
  return arr.length ? sum(arr) / arr.length : 0
}
export function median(arr = []) {
  if (!arr.length) return 0
  const s = [...arr].map(num).sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}
export function variance(arr = []) {
  if (arr.length < 2) return 0
  const m = mean(arr)
  return sum(arr, (x) => (num(x) - m) ** 2) / (arr.length - 1)
}
export function stdDev(arr = []) {
  return Math.sqrt(variance(arr))
}
export function cv(arr = []) {
  const m = Math.abs(mean(arr))
  return m ? stdDev(arr) / m : 0
}
export function pctChange(cur, prev) {
  if (!prev) return null
  return ((num(cur) - num(prev)) / Math.abs(num(prev))) * 100
}
export function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, num(v)))
}
export function round(v, d = 2) {
  const p = 10 ** d
  return Math.round(num(v) * p) / p
}
export function safeDiv(a, b, fallback = 0) {
  return num(b) ? num(a) / num(b) : fallback
}
/** z-score for a 2-sided confidence level (90/95/99 …). */
export function zFor(confidence = 95) {
  return confidence >= 99 ? 2.576 : confidence >= 95 ? 1.96 : confidence >= 90 ? 1.645 : 1.282
}

// ── descriptive ──────────────────────────────────────────────────────────
/**
 * Pareto / ABC classification. Rows are sorted by `valueKey` descending and
 * tagged A (top 80% of cumulative value), B (next 15%) or C (last 5%).
 */
export function abcClass(rows = [], { valueKey = 'value' } = {}) {
  const sorted = [...rows].sort((a, b) => num(b[valueKey]) - num(a[valueKey]))
  const total = sum(sorted, (r) => r[valueKey]) || 1
  let cum = 0
  const out = sorted.map((r) => {
    cum += num(r[valueKey])
    const cumPct = (cum / total) * 100
    const abc = cumPct <= 80 ? 'A' : cumPct <= 95 ? 'B' : 'C'
    return { ...r, share: (num(r[valueKey]) / total) * 100, cumPct, abc }
  })
  const summary = ['A', 'B', 'C'].map((k) => {
    const bucket = out.filter((r) => r.abc === k)
    return {
      class: k,
      count: bucket.length,
      value: sum(bucket, (r) => r[valueKey]),
      share: sum(bucket, (r) => r.share)
    }
  })
  return { rows: out, summary, total }
}

/**
 * XYZ classification by demand variability (coefficient of variation).
 * X = stable (CV < 0.5), Y = variable (0.5 ≤ CV < 1), Z = erratic (CV ≥ 1).
 */
export function xyzClass(rows = [], { seriesKey = 'series' } = {}) {
  return rows.map((r) => {
    const c = cv(r[seriesKey] || [])
    const xyz = c < 0.5 ? 'X' : c < 1 ? 'Y' : 'Z'
    return { ...r, cv: c, xyz }
  })
}

/** 9-box ABC × XYZ demand matrix counts. */
export function abcXyzMatrix(rows = []) {
  const matrix = {}
  for (const a of ['A', 'B', 'C']) {
    for (const x of ['X', 'Y', 'Z']) matrix[`${a}${x}`] = []
  }
  for (const r of rows) {
    if (r.abc && r.xyz && matrix[`${r.abc}${r.xyz}`]) matrix[`${r.abc}${r.xyz}`].push(r)
  }
  return matrix
}

/** Ranked 1–5 score per row (highest value = 5) — used by RFM scoring. */
export function rankScores(rows = [], key) {
  const values = rows.map((r) => num(r[key]))
  const sorted = [...values].sort((a, b) => a - b)
  const n = sorted.length || 1
  return rows.map((r) => {
    const idx = sorted.indexOf(num(r[key]))
    const score = idx < 0 ? 1 : Math.min(5, Math.floor((idx / n) * 5) + 1)
    return score
  })
}

/**
 * RFM (Recency / Frequency / Monetary) customer segmentation with the
 * classic 11-segment naming used by premium BI suites.
 */
export function rfmSegments(tx = [], { now = new Date() } = {}) {
  const map = new Map()
  for (const t of tx) {
    const name = String(t.customer_name || '').trim()
    if (!name || name.toLowerCase() === 'walk-in') continue
    const d = new Date(t.created_at || t.date || 0)
    const amt = num(t.total ?? t.total_amount)
    const row = map.get(name) || { name, last: d, f: 0, m: 0 }
    if (d > row.last) row.last = d
    row.f += 1
    row.m += amt
    map.set(name, row)
  }
  const rows = [...map.values()].map((r) => ({
    ...r,
    recency: Math.max(0, Math.round((now - r.last) / 86400000))
  }))
  if (!rows.length) return { rows: [], summary: [] }

  const rScores = rankScores(rows, 'recency').map((s) => 6 - s) // lower recency = better
  const fScores = rankScores(rows, 'f')
  const mScores = rankScores(rows, 'm')
  const scored = rows.map((r, i) => {
    const R = rScores[i], F = fScores[i], M = mScores[i]
    const fm = (F + M) / 2
    let segment = 'Hibernating'
    if (R >= 4 && fm >= 4) segment = 'Champions'
    else if (R >= 3 && fm >= 3) segment = 'Loyal'
    else if (R >= 4 && fm < 3) segment = 'Promising'
    else if (R >= 3 && fm < 2) segment = 'New / Recent'
    else if (R === 2 && fm >= 3) segment = 'Cannot Lose Them'
    else if (R === 2 && fm >= 2) segment = 'Need Attention'
    else if (R <= 2 && fm >= 4) segment = 'At Risk (VIP)'
    else if (R <= 2 && fm >= 2) segment = 'At Risk'
    else if (R <= 2 && fm <= 1) segment = 'Lost'
    return { ...r, rScore: R, fScore: F, mScore: M, segment }
  })
  const segments = [...new Set(scored.map((s) => s.segment))]
  const summary = segments
    .map((s) => {
      const bucket = scored.filter((x) => x.segment === s)
      return {
        segment: s,
        customers: bucket.length,
        revenue: sum(bucket, (r) => r.m),
        avgSpend: mean(bucket.map((r) => r.m)),
        avgRecency: Math.round(mean(bucket.map((r) => r.recency)))
      }
    })
    .sort((a, b) => b.revenue - a.revenue)
  return { rows: scored, summary }
}

// ── diagnostic ───────────────────────────────────────────────────────────
/**
 * Variance attribution — given per-dimension current vs prior values, returns
 * each dimension's absolute + relative contribution to the total movement.
 */
export function varianceAttribution(current = {}, previous = {}, { labels = {} } = {}) {
  const keys = new Set([...Object.keys(current), ...Object.keys(previous)])
  const rows = [...keys].map((k) => {
    const c = num(current[k])
    const p = num(previous[k])
    return { key: k, label: labels[k] || k, current: c, previous: p, delta: c - p }
  })
  const totalDelta = sum(rows, (r) => r.delta)
  return rows
    .map((r) => ({ ...r, contribution: totalDelta ? (r.delta / Math.abs(totalDelta)) * 100 : 0 }))
    .sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta))
}

/** Z-score based anomaly detection. Returns indices + z values. */
export function anomalies(values = [], { k = 2 } = {}) {
  const m = mean(values)
  const sd = stdDev(values) || 1
  return values
    .map((v, i) => ({ i, value: num(v), z: (num(v) - m) / sd }))
    .filter((r) => Math.abs(r.z) >= k)
    .sort((a, b) => Math.abs(b.z) - Math.abs(a.z))
}

/** Shannon-style importance proxy: share of total absolute movement. */
export function driverRanking(drivers = []) {
  const total = sum(drivers, (d) => Math.abs(num(d.impact))) || 1
  return [...drivers]
    .map((d) => ({ ...d, weight: (Math.abs(num(d.impact)) / total) * 100 }))
    .sort((a, b) => Math.abs(num(b.impact)) - Math.abs(num(a.impact)))
}

// ── predictive ───────────────────────────────────────────────────────────
/** Ordinary least-squares fit on an evenly spaced series. */
export function linreg(values = []) {
  const ys = values.map(num)
  const n = ys.length
  if (n < 2) {
    const lvl = ys[0] || 0
    return { slope: 0, intercept: lvl, r2: 0, n, fit: () => lvl, predict: () => lvl }
  }
  const mx = (n - 1) / 2
  const my = mean(ys)
  let sxy = 0
  let sxx = 0
  let syy = 0
  for (let i = 0; i < n; i++) {
    sxy += (i - mx) * (ys[i] - my)
    sxx += (i - mx) ** 2
    syy += (ys[i] - my) ** 2
  }
  const slope = sxx ? sxy / sxx : 0
  const intercept = my - slope * mx
  const r2 = sxx && syy ? (sxy ** 2) / (sxx * syy) : 0
  return {
    slope,
    intercept,
    r2,
    n,
    fit: (x) => intercept + slope * x,
    predict: (h = 1) => intercept + slope * (n - 1 + h)
  }
}

/** Holt's linear (double exponential smoothing) with trend. */
export function holtLinear(values = [], { alpha = 0.55, beta = 0.3, horizon = 4 } = {}) {
  const y = values.map(num)
  const n = y.length
  if (n < 2) {
    const lvl = y[0] || 0
    return { fitted: y, forecast: Array(horizon).fill(lvl), level: lvl, trend: 0, mape: 0, mae: 0 }
  }
  let level = y[0]
  let trend = y[1] - y[0]
  const fitted = [level]
  for (let i = 1; i < n; i++) {
    fitted.push(level + trend)
    const prevLevel = level
    level = alpha * y[i] + (1 - alpha) * (level + trend)
    trend = beta * (level - prevLevel) + (1 - beta) * trend
  }
  const forecast = []
  for (let h = 1; h <= horizon; h++) forecast.push(Math.max(0, level + h * trend))
  let ape = 0
  let ae = 0
  let cnt = 0
  for (let i = 1; i < n; i++) {
    ae += Math.abs(y[i] - fitted[i])
    if (y[i]) {
      ape += Math.abs((y[i] - fitted[i]) / y[i])
      cnt++
    }
  }
  return {
    fitted,
    forecast,
    level,
    trend,
    mae: ae / (n - 1 || 1),
    mape: cnt ? (ape / cnt) * 100 : 0
  }
}

/** Simple trailing moving average (also usable as a naive forecast). */
export function movingAverage(values = [], w = 3) {
  const out = []
  for (let i = 0; i < values.length; i++) {
    out.push(mean(values.slice(Math.max(0, i - w + 1), i + 1)))
  }
  return out
}

/** Naive seasonal-naive forecast (repeat last observed season). */
export function seasonalNaive(values = [], horizon = 4, season = 12) {
  const out = []
  for (let h = 0; h < horizon; h++) {
    const idx = values.length - season + (h % season)
    out.push(num(values[idx] ?? values[values.length - 1] ?? 0))
  }
  return out
}

/** Calendar-month seasonal index (relative to the overall mean). */
export function seasonalProfile(monthly = []) {
  const byMonth = Array.from({ length: 12 }, () => [])
  for (const r of monthly) byMonth[r.m].push(num(r.value))
  const overall = mean(monthly.map((r) => num(r.value)))
  const index = byMonth.map((arr) => (arr.length && overall ? mean(arr) / overall : 1))
  return { index, overall }
}

/** Accuracy metrics for a forecast vs actual series. */
export function accuracy(actual = [], forecasted = []) {
  const n = Math.min(actual.length, forecasted.length)
  if (!n) return { mae: 0, mape: 0, rmse: 0, bias: 0, r2: 0 }
  let ae = 0
  let ape = 0
  let se = 0
  let be = 0
  let cnt = 0
  for (let i = 0; i < n; i++) {
    const a = num(actual[i])
    const f = num(forecasted[i])
    const e = a - f
    ae += Math.abs(e)
    se += e * e
    be += e
    if (a) {
      ape += Math.abs(e / a)
      cnt++
    }
  }
  const ybar = mean(actual.slice(0, n))
  let sst = 0
  let sse = 0
  for (let i = 0; i < n; i++) {
    sst += (num(actual[i]) - ybar) ** 2
    sse += (num(actual[i]) - num(forecasted[i])) ** 2
  }
  return {
    mae: ae / n,
    mape: cnt ? (ape / cnt) * 100 : 0,
    rmse: Math.sqrt(se / n),
    bias: be / n,
    r2: sst ? 1 - sse / sst : 0
  }
}

/** Confidence band around a forecast from residual volatility. */
export function confidenceBand(forecast = [], residualStd = 0, { z = 1.96 } = {}) {
  return {
    upper: forecast.map((v, i) => num(v) + z * residualStd * Math.sqrt(i + 1)),
    lower: forecast.map((v, i) => Math.max(0, num(v) - z * residualStd * Math.sqrt(i + 1)))
  }
}

/** Unified forecasting entry point. */
export function trendForecast(values = [], { horizon = 4, method = 'holt' } = {}) {
  const v = values.map(num)
  let forecast = []
  let fitted = []
  if (method === 'linear') {
    const m = linreg(v)
    fitted = v.map((_, i) => m.fit(i))
    forecast = Array.from({ length: horizon }, (_, h) => Math.max(0, m.predict(h + 1)))
  } else if (method === 'ma') {
    fitted = movingAverage(v, 3)
    const avg = mean(v.slice(-3))
    forecast = Array(horizon).fill(Math.max(0, avg))
  } else if (method === 'seasonal') {
    const m = linreg(v)
    fitted = v.map((_, i) => m.fit(i))
    forecast = seasonalNaive(v, horizon)
  } else {
    const m = holtLinear(v, { horizon })
    fitted = m.fitted
    forecast = m.forecast
  }
  const residuals = v.slice(1).map((y, i) => y - num(fitted[i + 1]))
  const residualStd = stdDev(residuals)
  const band = confidenceBand(forecast, residualStd)
  const acc = accuracy(v.slice(1), fitted.slice(1))
  return { actual: v, fitted, forecast, band, residualStd, accuracy: acc, method }
}

// ── prescriptive ─────────────────────────────────────────────────────────
/** Economic order quantity. */
export function eoq({ annualDemand = 0, orderCost = 0, holdingCost = 0 } = {}) {
  const d = num(annualDemand)
  const s = num(orderCost)
  const h = num(holdingCost)
  if (!d || !s || !h) return 0
  return Math.sqrt((2 * d * s) / h)
}

/** Safety stock from demand + lead-time variability. */
export function safetyStock({ stdDevDemand = 0, avgLeadTime = 0, serviceZ = 1.65 } = {}) {
  return num(serviceZ) * num(stdDevDemand) * Math.sqrt(Math.max(1, num(avgLeadTime)))
}

/** Reorder point = lead-time demand + safety stock. */
export function reorderPoint({ avgDailyDemand = 0, leadTimeDays = 0, safety = 0 } = {}) {
  return num(avgDailyDemand) * num(leadTimeDays) + num(safety)
}

/**
 * Price elasticity via log-log regression:  ln(Q) = a + b·ln(P).
 * `b` is the elasticity (typically negative). Returns optimum revenue price.
 */
export function priceElasticity(points = []) {
  const pts = points.filter((p) => num(p.price) > 0 && num(p.qty) > 0)
  if (pts.length < 2) return { elasticity: 0, r2: 0, optimumPrice: null, points: pts.length }
  const lx = pts.map((p) => Math.log(num(p.price)))
  const ly = pts.map((p) => Math.log(num(p.qty)))
  // bivariate log-log fit (elasticity = slope of ln Q on ln P)
  const mx = mean(lx)
  const my = mean(ly)
  let sxy = 0
  let sxx = 0
  let syy = 0
  for (let i = 0; i < pts.length; i++) {
    sxy += (lx[i] - mx) * (ly[i] - my)
    sxx += (lx[i] - mx) ** 2
    syy += (ly[i] - my) ** 2
  }
  const elasticity = sxx ? sxy / sxx : 0
  const a = my - elasticity * mx
  const r2 = sxx && syy ? (sxy ** 2) / (sxx * syy) : 0
  // Revenue R(P) = P · Q(P) = P · e^(a + b·lnP) → maximised at b = -1
  const basePrice = mean(pts.map((p) => num(p.price)))
  const lift = elasticity < -1 ? 0.05 : 0.1 // raise price if inelastic, cut if very elastic
  const optimumPrice = basePrice * (1 + lift * -Math.sign(elasticity || 1))
  return { elasticity, r2, a, optimumPrice: elasticity ? Math.max(0, optimumPrice) : null, points: pts.length }
}

/**
 * Discount guardrail — the maximum discount % that can be given before the
 * order drops below the minimum gross-margin target.
 */
export function maxDiscount({ price = 0, cost = 0, minMarginPct = 15 } = {}) {
  const p = num(price)
  const c = num(cost)
  if (!p) return 0
  const floor = c / (1 - num(minMarginPct) / 100)
  return clamp(((p - floor) / p) * 100, 0, 100)
}

/** Markdown / clearance score (0–100) — higher = clear sooner. */
export function clearanceScore({ daysToExpiry = 999, daysOfCover = 999, sellThrough = 1 } = {}) {
  const exp = clamp(100 - (num(daysToExpiry) / 180) * 100, 0, 100)
  const cover = clamp((num(daysOfCover) / 120) * 100, 0, 100)
  const slow = clamp((1 - num(sellThrough)) * 100, 0, 100)
  return round(exp * 0.5 + cover * 0.3 + slow * 0.2, 1)
}

// ── association / cross-sell ─────────────────────────────────────────────
/**
 * Apriori-style market-basket analysis over POS transactions.
 * `tx` items: [{ items: [{ product_name | name | medication_name, quantity }] }]
 */
export function marketBasket(tx = [], { minSupport = 0.01, minConfidence = 0.2, maxItems = 40 } = {}) {
  const baskets = tx.map((t) =>
    [...new Set((t.items || []).map((it) => String(it.product_name || it.name || it.medication_name || '').trim()))].filter(Boolean)
  )
  const n = baskets.length || 1
  const support = new Map()
  const pairSupport = new Map()
  for (const b of baskets) {
    for (const a of b) {
      support.set(a, (support.get(a) || 0) + 1)
      for (const c of b) {
        if (a >= c) continue
        const key = `${a}|||${c}`
        pairSupport.set(key, (pairSupport.get(key) || 0) + 1)
      }
    }
  }
  const rules = []
  for (const [key, count] of pairSupport.entries()) {
    const [a, c] = key.split('|||')
    const sup = count / n
    if (sup < minSupport) continue
    const confAC = count / (support.get(a) || 1)
    const confCA = count / (support.get(c) || 1)
    const lift = confAC / ((support.get(c) || 1) / n)
    if (confAC >= minConfidence) rules.push({ a, b: c, support: sup, confidence: confAC, lift })
    if (confCA >= minConfidence) rules.push({ a: c, b: a, support: sup, confidence: confCA, lift })
  }
  return rules.sort((x, y) => y.lift * y.confidence - x.lift * x.confidence).slice(0, maxItems)
}

// ── logistic-style scoring (stockout risk) ───────────────────────────────
/**
 * Lightweight logistic risk score (0–1) from standardised drivers.
 * `drivers` = [{ value, mean, std, weight }] — higher value ⇒ higher risk.
 */
export function logisticRisk(drivers = []) {
  let z = -0.5
  for (const d of drivers) {
    const sd = num(d.std) || 1
    const std = (num(d.value) - num(d.mean)) / sd
    z += num(d.weight) * std
  }
  return 1 / (1 + Math.exp(-z))
}

// ── bucketing helpers shared by the BI pages ─────────────────────────────
export function isoDay(d) {
  return new Date(d).toISOString().slice(0, 10)
}

/** Roll transactions into calendar-month buckets: [{ y, m, label, value, qty, orders }] */
export function monthlyBuckets(tx = [], { months = 12, valueFn = (t) => num(t.total ?? t.total_amount), now = new Date() } = {}) {
  const buckets = []
  const base = new Date(now.getFullYear(), now.getMonth(), 1)
  for (let i = months - 1; i >= 0; i--) {
    const d = new Date(base.getFullYear(), base.getMonth() - i, 1)
    buckets.push({ y: d.getFullYear(), m: d.getMonth(), label: `${BI_MONTHS[d.getMonth()]} ${String(d.getFullYear()).slice(2)}`, value: 0, qty: 0, orders: 0 })
  }
  const idx = new Map(buckets.map((b, i) => [`${b.y}-${b.m}`, i]))
  for (const t of tx) {
    const d = new Date(t.created_at || t.date || 0)
    if (Number.isNaN(d.getTime())) continue
    const i = idx.get(`${d.getFullYear()}-${d.getMonth()}`)
    if (i == null) continue
    const b = buckets[i]
    b.value += valueFn(t)
    b.orders += 1
    for (const it of t.items || []) b.qty += num(it.quantity || 1)
  }
  return buckets
}

/** Product-level rollup from POS transactions. */
export function productRollup(tx = [], { limit = 500 } = {}) {
  const map = new Map()
  for (const t of tx) {
    for (const it of t.items || []) {
      const name = String(it.product_name || it.name || it.medication_name || 'Item').trim()
      const qty = num(it.quantity || 1)
      const rev = num(it.total ?? it.subtotal ?? num(it.unit_price) * qty)
      const cost = num(it.cost_price ?? it.unit_cost) * qty
      const row = map.get(name) || { name, qty: 0, revenue: 0, cost: 0, category: it.category_name || it.category || 'Other', orders: 0 }
      row.qty += qty
      row.revenue += rev
      row.cost += cost
      row.orders += 1
      map.set(name, row)
    }
  }
  return [...map.values()].map((r) => ({ ...r, margin: r.revenue - r.cost, marginPct: r.revenue ? ((r.revenue - r.cost) / r.revenue) * 100 : 0 })).sort((a, b) => b.revenue - a.revenue).slice(0, limit)
}

export const BI_PALETTE = ['#0d9488', '#3b82f6', '#8b5cf6', '#f59e0b', '#22c55e', '#ec4899', '#06b6d4', '#ef4444', '#6366f1', '#84cc16']

/** Serialise rows to CSV (client only) and trigger a download. */
export function downloadCsv(filename, headers, rows) {
  if (!import.meta.client) return
  const esc = (v) => {
    const s = v == null ? '' : String(v)
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  const lines = [headers.map(esc).join(',')]
  for (const r of rows || []) lines.push(headers.map((h) => esc(r[h])).join(','))
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename.endsWith('.csv') ? filename : `${filename}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

/** Human-friendly compact number (1.2M / 340K). */
export function compactNumber(v) {
  const n = num(v)
  const abs = Math.abs(n)
  if (abs >= 1e9) return `${(n / 1e9).toFixed(1)}B`
  if (abs >= 1e6) return `${(n / 1e6).toFixed(1)}M`
  if (abs >= 1e3) return `${(n / 1e3).toFixed(1)}K`
  return String(round(n, 2))
}
