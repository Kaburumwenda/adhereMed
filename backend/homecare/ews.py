"""Server-side NEWS2 (National Early Warning Score 2) computation.

Mirrors the RCP 2017 thresholds used by the homecare EWS calculator on the
frontend so that vitals recorded through the API are scored consistently and
can trigger automatic clinical escalation.
"""
from __future__ import annotations


def _num(value):
    try:
        if value is None or value == '':
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _score_rr(v):
    if v is None:
        return 0
    if v <= 8:
        return 3
    if v <= 11:
        return 1
    if v <= 20:
        return 0
    if v <= 24:
        return 2
    return 3


def _score_spo2_scale1(v):
    if v is None:
        return 0
    if v <= 91:
        return 3
    if v <= 93:
        return 2
    if v <= 95:
        return 1
    return 0


def _score_spo2_scale2(v, on_o2):
    if v is None:
        return 0
    if v <= 83:
        return 3
    if v <= 85:
        return 2
    if v <= 87:
        return 1
    if v <= 92:
        return 0
    if not on_o2:
        return 0
    if v <= 94:
        return 1
    if v <= 96:
        return 2
    return 3


def _score_oxygen(on_o2):
    return 2 if on_o2 else 0


def _score_sbp(v):
    if v is None:
        return 0
    if v <= 90:
        return 3
    if v <= 100:
        return 2
    if v <= 110:
        return 1
    if v <= 219:
        return 0
    return 3


def _score_hr(v):
    if v is None:
        return 0
    if v <= 40:
        return 3
    if v <= 50:
        return 1
    if v <= 90:
        return 0
    if v <= 110:
        return 1
    if v <= 130:
        return 2
    return 3


def _score_temp(v):
    if v is None:
        return 0
    if v <= 35.0:
        return 3
    if v <= 36.0:
        return 1
    if v <= 38.0:
        return 0
    if v <= 39.0:
        return 1
    return 2


def _score_consciousness(c):
    return 0 if str(c or 'A').strip().upper() in ('A', 'ALERT') else 3


def compute_news2(*, rr=None, spo2=None, scale2=False, on_oxygen=False,
                  sbp=None, hr=None, temp=None, consciousness='A'):
    """Return a dict with the NEWS2 breakdown.

    Keys: ``scores`` (per-parameter), ``total``, ``has_red`` (any single
    parameter scored 3), ``band`` (Low / Low-Medium / Medium / High),
    ``severity`` (maps to Escalation.Severity) and ``should_escalate``.
    """
    rr = _num(rr)
    spo2 = _num(spo2)
    sbp = _num(sbp)
    hr = _num(hr)
    temp = _num(temp)
    on_o2 = bool(on_oxygen)

    scores = {
        'rr': _score_rr(rr),
        'spo2': _score_spo2_scale2(spo2, on_o2) if scale2 else _score_spo2_scale1(spo2),
        'oxygen': _score_oxygen(on_o2),
        'sbp': _score_sbp(sbp),
        'hr': _score_hr(hr),
        'temp': _score_temp(temp),
        'consciousness': _score_consciousness(consciousness),
    }
    total = sum(scores.values())
    has_red = any(s >= 3 for s in scores.values())

    if total == 0:
        band = 'Low'
    elif total <= 4 and not has_red:
        band = 'Low-Medium'
    elif total <= 6 or has_red:
        band = 'Medium'
    else:
        band = 'High'

    # Escalate on medium risk and above (>=5, or any red parameter).
    should_escalate = total >= 5 or has_red
    if total >= 7:
        severity = 'critical'
    elif should_escalate:
        severity = 'high'
    else:
        severity = 'medium'

    return {
        'scores': scores,
        'total': total,
        'has_red': has_red,
        'band': band,
        'severity': severity,
        'should_escalate': should_escalate,
    }
