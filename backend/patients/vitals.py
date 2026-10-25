"""Vital-sign scoring helpers for the clinic vitals module.

Single source of truth for NEWS2 on the server. The Nuxt page mirrors this so the
form can show a live score, but anything that is *stored* (``news2_score``) or
counted in dashboards is computed here.

Bands follow the Royal College of Physicians NEWS2 2017 chart.
"""


def _num(value):
    """Coerce to float, treating None/'' /non-numeric as missing."""
    if value is None or value == '':
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _rr_score(rr):
    if rr is None or rr <= 0:
        # 0 / blank is *unrecorded*, not bradypnoea. Scoring it 3 made every
        # fresh record look critically ill.
        return 0
    if rr <= 8:
        return 3
    if rr <= 11:
        return 1
    if rr <= 20:
        return 0
    if rr <= 24:
        return 2
    return 3


def _spo2_score(sat, scale=1):
    if sat is None or sat <= 0:
        return 0
    if int(scale or 1) == 2:
        # Hypercapnic / target 88-92 %. Being *above* target also scores.
        if sat <= 83:
            return 3
        if sat <= 85:
            return 2
        if sat <= 87:
            return 1
        if sat <= 92:
            return 0
        if sat <= 94:
            return 1
        if sat <= 96:
            return 2
        return 3
    if sat <= 91:
        return 3
    if sat <= 93:
        return 2
    if sat <= 95:
        return 1
    return 0


def _systolic_score(sys):
    if sys is None or sys <= 0:
        return 0
    if sys <= 90:
        return 3
    if sys <= 100:
        return 2
    if sys <= 110:
        return 1
    if sys <= 219:
        return 0
    return 3


def _pulse_score(hr):
    if hr is None or hr <= 0:
        return 0
    if hr <= 40:
        return 3
    if hr <= 50:
        return 1
    if hr <= 90:
        return 0
    if hr <= 110:
        return 1
    if hr <= 130:
        return 2
    return 3


def _temp_score(temp):
    if temp is None or temp <= 0:
        return 0
    if temp <= 35.0:
        return 3
    if temp <= 36.0:
        return 1
    if temp <= 38.0:
        return 0
    if temp <= 39.0:
        return 1
    return 2


def _consciousness_score(level):
    if not level:
        return 0
    return 0 if str(level).upper() == 'A' else 3


def score_news2(vitals):
    """Return ``(total, breakdown)`` for a vital-signs mapping.

    Accepts the clinic's canonical keys and the legacy aliases found in older
    triage/consultation JSON (``pulse``, ``resp``, ``spo2``, ``blood_pressure_*``).
    """
    v = vitals or {}

    def pick(*keys):
        for k in keys:
            val = _num(v.get(k))
            if val is not None:
                return val
        return None

    rr = pick('respiratory_rate', 'resp_rate', 'resp')
    sat = pick('oxygen_saturation', 'spo2', 'o2_saturation')
    sys = pick('bp_systolic', 'systolic', 'blood_pressure_systolic')
    pulse = pick('heart_rate', 'pulse')
    temp = pick('temperature', 'temp')
    avpu = v.get('consciousness') or v.get('avpu') or 'A'
    on_o2 = bool(v.get('on_oxygen'))
    scale = v.get('spo2_scale') or 1

    breakdown = {
        'respiratory_rate': _rr_score(rr),
        'oxygen_saturation': _spo2_score(sat, scale),
        'on_oxygen': 2 if on_o2 else 0,
        'bp_systolic': _systolic_score(sys),
        'heart_rate': _pulse_score(pulse),
        'consciousness': _consciousness_score(avpu),
        'temperature': _temp_score(temp),
    }
    return sum(breakdown.values()), breakdown


def news2_risk(score, breakdown=None):
    """Map a NEWS2 total to ``low|low_medium|medium|high``.

    A single parameter scoring 3 lifts the record to at least ``low_medium`` even
    when the aggregate is small — that is the NEWS2 rule the aggregate alone
    would hide.
    """
    try:
        score = int(score or 0)
    except (TypeError, ValueError):
        score = 0
    any_three = bool(breakdown) and any(int(x or 0) >= 3 for x in breakdown.values())
    if score >= 7:
        return 'high'
    if score >= 5:
        return 'medium'
    if any_three or score >= 1:
        return 'low_medium'
    return 'low'


def bmi_for(weight, height_cm):
    """BMI from kg and cm. Heights under 3 are assumed to already be metres."""
    w = _num(weight)
    h = _num(height_cm)
    if not w or not h:
        return None
    metres = h / 100 if h > 3 else h
    if metres <= 0:
        return None
    return round(w / (metres * metres), 1)
