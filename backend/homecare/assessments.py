"""Patient Assessment scoring engine.

Pure functions that compute validated risk-scale totals, risk-level bands
and clinical alerts from the raw assessment section payloads.  The
ViewSet layer calls ``recalculate_session`` before persisting so that the
mirrored score columns and ``alerts_triggered`` JSON always agree with
the structured payloads.

Scales implemented (per the Patient Assessment Module Specification):
  • Braden Scale  – pressure ulcer risk (6 subscales, 6–23)
  • Caprini Score – VTE risk (factor checklist, 0–≥5)
  • Morse Fall Scale – falls risk (6 items, 0–125)
  • MUST          – malnutrition risk (BAPEN, 0–≥2)
  • CAM           – delirium screening (positive/negative)
  • NRS Pain      – 0–10 numeric rating
"""
from __future__ import annotations

from typing import Any

from django.utils import timezone


# ─────────────────────────────────────────────────────────
#  Braden Scale  (NPIAP)
# ─────────────────────────────────────────────────────────
BRADEN_SUBSCALES = ('sensory', 'moisture', 'activity', 'mobility', 'nutrition', 'friction')


def _safe_int(v, default=None):
    try:
        if v is None or v == '':
            return default
        return int(v)
    except (TypeError, ValueError):
        return default


def calc_braden(payload: dict) -> dict:
    """Compute Braden total (6–23) and risk band.

    Each subscale is scored 1–4 except friction/shear which is 1–3.
    Lower total → higher risk.
    """
    payload = payload or {}
    out = {k: _safe_int(payload.get(k)) for k in BRADEN_SUBSCALES}
    valid = [v for v in out.values() if v is not None]
    if len(valid) != len(BRADEN_SUBSCALES):
        out['total'] = payload.get('total')
        out['risk_level'] = payload.get('risk_level', '')
        return out
    total = sum(valid)
    out['total'] = total
    out['risk_level'] = braden_risk_label(total)
    return out


def braden_risk_label(total: int) -> str:
    if total <= 9:
        return 'Severe Risk'
    if total <= 12:
        return 'High Risk'
    if total <= 14:
        return 'Moderate Risk'
    if total <= 18:
        return 'Mild Risk'
    return 'No Risk'


# ─────────────────────────────────────────────────────────
#  Caprini Score  (VTE risk)
# ─────────────────────────────────────────────────────────
# Each key maps to the points awarded when the factor is True.
# Age is handled separately (range-based).
CAPRINI_FACTORS: dict[str, int] = {
    'age_41_60': 1,
    'age_61_74': 2,
    'age_75_plus': 3,
    'bmi_25_plus': 1,
    'minor_surgery': 1,
    'major_surgery_45min': 2,
    'laparoscopic_surgery_45min': 2,
    'elective_major_orthopedic': 2,
    'pregnancy_postpartum': 1,
    'history_vte': 3,
    'thrombophilia': 3,
    'sepsis': 1,
    'malignancy_present': 2,
    'malignancy_previous': 1,
    'acute_mi': 1,
    'congestive_heart_failure': 1,
    'bedbound': 1,
    'central_venous_access': 2,
    'varicose_veins': 1,
    'inflammatory_bowel_disease': 1,
    'serious_lung_disease': 1,
    'oral_contraceptives': 1,
    'swollen_leg': 1,
    'acute_spinal_cord_injury': 3,
}


def calc_caprini(payload: dict) -> dict:
    """Sum Caprini risk-factor points and assign a risk band.

    ``factors`` is a dict of {factor_key: bool}.  ``age`` (if supplied)
    is used only for display — the caller picks the correct age-range
    factor checkbox.
    """
    payload = payload or {}
    factors = payload.get('factors') or {}
    # Also accept a flat payload where factors sit at top level.
    if not isinstance(factors, dict):
        factors = {}
    points = 0
    for key, pts in CAPRINI_FACTORS.items():
        if factors.get(key):
            points += pts
    out = dict(payload)
    out['factors'] = factors
    out['points'] = points
    out['risk_level'] = caprini_risk_label(points)
    return out


def caprini_risk_label(points: int) -> str:
    if points <= 1:
        return 'Low'
    if points == 2:
        return 'Moderate'
    if points <= 4:
        return 'High'
    return 'Very High'


# ─────────────────────────────────────────────────────────
#  Morse Fall Scale
# ─────────────────────────────────────────────────────────
def _morse_history(v) -> int:
    return 15 if v else 0


def _morse_secondary_dx(v) -> int:
    return 15 if v else 0


def _morse_ambulatory_aid(v) -> int:
    v = (v or '').lower() if isinstance(v, str) else v
    # 0 = none/bedrest/wheelchair/nurse-assisted
    # 15 = crutches/cane/walker
    # 30 = furniture
    if v in ('crutches', 'cane', 'walker', 15):
        return 15
    if v in ('furniture', 30):
        return 30
    if isinstance(v, (int, float)):
        return int(v)
    return 0


def _morse_iv_lock(v) -> int:
    return 15 if v else 0


def _morse_gait(v) -> int:
    v = (v or '').lower() if isinstance(v, str) else v
    # 0 = normal/bedrest/immobile
    # 10 = weak
    # 20 = impaired
    if v in ('weak', 10):
        return 10
    if v in ('impaired', 20):
        return 20
    if isinstance(v, (int, float)):
        return int(v)
    return 0


def _morse_mental_status(v) -> int:
    v = (v or '').lower() if isinstance(v, str) else v
    # 0 = oriented / knows own limitations
    # 15 = overestimates / forgets limitations
    if v in ('overestimates', 'forgets_limitations', 15):
        return 15
    if isinstance(v, (int, float)):
        return int(v)
    return 0


def calc_morse(payload: dict) -> dict:
    """Compute the Morse Fall Scale (0–125) and risk band."""
    payload = payload or {}
    items = {
        'history_of_falls': _morse_history(payload.get('history_of_falls')),
        'secondary_dx': _morse_secondary_dx(payload.get('secondary_dx')),
        'ambulatory_aid': _morse_ambulatory_aid(payload.get('ambulatory_aid')),
        'iv_lock': _morse_iv_lock(payload.get('iv_lock')),
        'gait': _morse_gait(payload.get('gait')),
        'mental_status': _morse_mental_status(payload.get('mental_status')),
    }
    score = sum(items.values())
    out = dict(payload)
    out.update(items)
    out['score'] = score
    out['risk_level'] = morse_risk_label(score)
    return out


def morse_risk_label(score: int) -> str:
    if score >= 45:
        return 'High'
    if score >= 25:
        return 'Moderate'
    return 'Low'


# ─────────────────────────────────────────────────────────
#  MUST  (BAPEN malnutrition screening)
# ─────────────────────────────────────────────────────────
def _must_bmi_score(bmi):
    if bmi is None:
        return None
    if bmi > 20:
        return 0
    if bmi >= 18.5:
        return 1
    return 2


def _must_loss_score(pct):
    if pct is None:
        return None
    if pct < 5:
        return 0
    if pct <= 10:
        return 1
    return 2


def calc_must(payload: dict) -> dict:
    """Compute the MUST score (0–≥2) and risk band."""
    payload = payload or {}
    out = dict(payload)
    height = _safe_int(payload.get('height_cm'))
    weight = payload.get('weight_kg')
    try:
        weight = float(weight) if weight not in (None, '') else None
    except (TypeError, ValueError):
        weight = None

    bmi = None
    if height and weight:
        bmi = round(weight / ((height / 100) ** 2), 1)
    out['bmi'] = bmi

    bmi_score = _must_bmi_score(bmi)
    out['bmi_score'] = bmi_score

    loss_pct = payload.get('weight_loss_percent')
    try:
        loss_pct = float(loss_pct) if loss_pct not in (None, '') else None
    except (TypeError, ValueError):
        loss_pct = None
    loss_score = _must_loss_score(loss_pct)
    out['loss_score'] = loss_score

    acute = bool(payload.get('acute_no_nutrition'))
    acute_score = 2 if acute else 0
    out['acute_score'] = acute_score

    scores = [s for s in (bmi_score, loss_score, acute_score) if s is not None]
    total = sum(scores) if scores else None
    out['total_score'] = total
    out['risk_level'] = must_risk_label(total) if total is not None else ''
    return out


def must_risk_label(total: int) -> str:
    if total >= 2:
        return 'High'
    if total == 1:
        return 'Medium'
    return 'Low'


# ─────────────────────────────────────────────────────────
#  CAM  (Confusion Assessment Method — delirium)
# ─────────────────────────────────────────────────────────
def calc_cam(payload: dict) -> dict:
    """Determine CAM positive/negative.

    CAM is positive when:
      Feature 1 (acute onset / fluctuating course)  AND
      Feature 2 (inattention)                        AND
      (Feature 3 (disorganized thinking) OR Feature 4 (altered consciousness))
    """
    payload = payload or {}
    f1 = bool(payload.get('acute_onset')) or bool(payload.get('fluctuating'))
    f2 = bool(payload.get('inattention'))
    f3 = bool(payload.get('disorganized_thinking'))
    f4 = bool(payload.get('altered_consciousness'))
    positive = f1 and f2 and (f3 or f4)
    out = dict(payload)
    out['acute_onset'] = f1 or bool(payload.get('acute_onset'))
    out['inattention'] = f2
    out['disorganized_thinking'] = f3
    out['altered_consciousness'] = f4
    out['cam_positive'] = positive
    return out


# ─────────────────────────────────────────────────────────
#  Pain  (NRS 0–10)
# ─────────────────────────────────────────────────────────
def calc_pain(payload: dict) -> dict:
    payload = payload or {}
    score = _safe_int(payload.get('score'))
    out = dict(payload)
    out['score'] = score
    out['score_category'] = pain_category(score) if score is not None else ''
    return out


def pain_category(score: int) -> str:
    if score is None:
        return ''
    if score == 0:
        return 'None'
    if score <= 3:
        return 'Mild'
    if score <= 6:
        return 'Moderate'
    return 'Severe'


# ─────────────────────────────
#  GCS  (Glasgow Coma Scale, 3–15)
# ─────────────────────────────
def calc_gcs(payload: dict) -> dict:
    payload = payload or {}
    eyes = _safe_int(payload.get('eyes'))
    verbal = _safe_int(payload.get('verbal'))
    motor = _safe_int(payload.get('motor'))
    out = dict(payload)
    out['eyes'] = eyes
    out['verbal'] = verbal
    out['motor'] = motor
    if eyes is not None and verbal is not None and motor is not None:
        out['total'] = eyes + verbal + motor
    else:
        out['total'] = payload.get('total')
    return out


# ─────────────────────────────────────────────────────────
#  Overall risk aggregation
# ─────────────────────────────────────────────────────────
def aggregate_risk(braden_total, caprini_points, morse_score,
                   must_total, cam_positive, pain_score) -> str:
    """Pick the highest risk level implied by any single scale."""
    from .models import HomecarePatient
    levels = [HomecarePatient.RiskLevel.LOW]
    if braden_total is not None and braden_total <= 12:
        levels.append(HomecarePatient.RiskLevel.HIGH)
    elif braden_total is not None and braden_total <= 18:
        levels.append(HomecarePatient.RiskLevel.MEDIUM)
    if caprini_points is not None and caprini_points >= 5:
        levels.append(HomecarePatient.RiskLevel.CRITICAL)
    elif caprini_points is not None and caprini_points >= 3:
        levels.append(HomecarePatient.RiskLevel.HIGH)
    if morse_score is not None and morse_score >= 45:
        levels.append(HomecarePatient.RiskLevel.HIGH)
    if must_total is not None and must_total >= 2:
        levels.append(HomecarePatient.RiskLevel.HIGH)
    if cam_positive:
        levels.append(HomecarePatient.RiskLevel.HIGH)
    if pain_score is not None and pain_score >= 7:
        levels.append(HomecarePatient.RiskLevel.HIGH)
    # Order by severity
    rank = {HomecarePatient.RiskLevel.LOW: 0,
            HomecarePatient.RiskLevel.MEDIUM: 1,
            HomecarePatient.RiskLevel.HIGH: 2,
            HomecarePatient.RiskLevel.CRITICAL: 3}
    return max(levels, key=lambda l: rank.get(l, 0))


# ─────────────────────────────────────────────────────────
#  Alert generation
# ─────────────────────────────────────────────────────────
def generate_alerts(session_data: dict) -> list[dict]:
    """Return a list of alert dicts for the given computed episode data.

    ``session_data`` is a flat dict: {braden_total, braden_risk,
    caprini_points, caprini_risk, morse_score, morse_risk, must_score,
    must_risk, cam_positive, pain_score, catheter_bundle,
    central_line_bundle}.

    Each alert: {code, category, severity, title, detail, threshold,
    value, recommendation}
    """
    alerts: list[dict] = []
    braden_total = session_data.get('braden_total')
    braden_risk = session_data.get('braden_risk', '')
    if braden_total is not None and braden_total <= 18:
        sev = 'critical' if braden_total <= 12 else ('high' if braden_total <= 14 else 'warning')
        alerts.append({
            'code': 'BRADEN_RISK', 'category': 'pressure', 'severity': sev,
            'title': 'Pressure injury risk',
            'detail': f'Braden total {braden_total} ({braden_risk}). '
                      f'Implement pressure-relief measures and skin care bundle.',
            'threshold': 'Braden ≤ 18', 'value': f'{braden_total} – {braden_risk}',
            'recommendation': 'Reposition every 2 h, pressure-relieving mattress, '
                              'skin moisture management (NPIAP).',
        })

    caprini_points = session_data.get('caprini_points')
    caprini_risk = session_data.get('caprini_risk', '')
    if caprini_points is not None and caprini_points >= 3:
        sev = 'critical' if caprini_points >= 5 else 'high'
        alerts.append({
            'code': 'VTE_RISK', 'category': 'vte', 'severity': sev,
            'title': 'Venous thromboembolism risk',
            'detail': f'Caprini score {caprini_points} ({caprini_risk}). '
                      f'Consider pharmacological / mechanical prophylaxis.',
            'threshold': 'Caprini ≥ 3', 'value': f'{caprini_points} – {caprini_risk}',
            'recommendation': 'Assess for anticoagulation or compression stockings '
                              'per physician order.',
        })

    morse_score = session_data.get('morse_score')
    morse_risk = session_data.get('morse_risk', '')
    if morse_score is not None and morse_score >= 45:
        alerts.append({
            'code': 'FALLS_RISK', 'category': 'falls', 'severity': 'high',
            'title': 'High falls risk',
            'detail': f'Morse score {morse_score} ({morse_risk}). '
                      f'Implement falls-prevention care plan.',
            'threshold': 'Morse ≥ 45', 'value': f'{morse_score} – {morse_risk}',
            'recommendation': 'Bed alarm, non-slip footwear, toileting schedule, '
                              'review sedating medications.',
        })

    must_total = session_data.get('must_score')
    must_risk = session_data.get('must_risk', '')
    if must_total is not None and must_total >= 2:
        alerts.append({
            'code': 'MALNUTRITION', 'category': 'nutrition', 'severity': 'high',
            'title': 'Malnutrition risk',
            'detail': f'MUST score {must_total} ({must_risk}). '
                      f'Refer to dietitian for nutritional support.',
            'threshold': 'MUST ≥ 2', 'value': f'{must_total} – {must_risk}',
            'recommendation': 'Dietitian referral, oral nutritional supplements, '
                              'reassess per care setting.',
        })

    if session_data.get('cam_positive'):
        alerts.append({
            'code': 'DELIRIUM', 'category': 'delirium', 'severity': 'critical',
            'title': 'Delirium detected (CAM positive)',
            'detail': 'CAM is positive — acute confusional state. '
                      'Alert physician for medical review.',
            'threshold': 'CAM positive', 'value': 'Positive',
            'recommendation': 'Physician review, identify and treat underlying cause, '
                              'orient patient, address sensory deficits.',
        })

    pain_score = session_data.get('pain_score')
    if pain_score is not None and pain_score >= 7:
        sev = 'critical' if pain_score >= 9 else 'high'
        alerts.append({
            'code': 'SEVERE_PAIN', 'category': 'pain', 'severity': sev,
            'title': 'Severe pain',
            'detail': f'Pain score {pain_score}/10. Provide analgesia and '
                      f'reassess in 30–60 min.',
            'threshold': 'Pain ≥ 7', 'value': f'{pain_score}/10',
            'recommendation': 'Administer prescribed analgesia, reassess '
                              '30–60 min post-intervention.',
        })

    # Device-bundle reminders
    cb = session_data.get('catheter_bundle') or {}
    if cb.get('present') and cb.get('needs_review'):
        alerts.append({
            'code': 'CATHETER_REVIEW', 'category': 'device', 'severity': 'warning',
            'title': 'Catheter removal review',
            'detail': 'Catheter may no longer be needed — review indication for '
                      'prompt removal (CDC).',
            'threshold': 'Catheter still needed = No', 'value': 'Review due',
            'recommendation': 'Assess daily whether catheter is still indicated; '
                              'remove ASAP when no longer needed.',
        })

    clb = session_data.get('central_line_bundle') or {}
    if clb.get('present') and clb.get('needs_removal'):
        alerts.append({
            'code': 'LINE_REMOVAL', 'category': 'device', 'severity': 'warning',
            'title': 'Central line removal review',
            'detail': 'Central line may no longer be needed — review for '
                      'prompt removal (CDC CLABSI).',
            'threshold': 'Line still needed = No', 'value': 'Review due',
            'recommendation': 'Remove promptly when no longer needed to prevent '
                              'CLABSI.',
        })

    return alerts


# ─────────────────────────────────────────────────────────
#  Episode mirror refresh (parent AssessmentSession)
#  Each individual scale now lives in its own strictly-separate model
#  (BradenAssessment, CapriniAssessment, MorseAssessment, MustAssessment,
#  CamAssessment, PainAssessment, GcsAssessment, …). This recomputes the
#  parent episode's mirrored columns, overall risk and alerts from the
#  latest related child record of each type.
# ─────────────────────────────────────────────────────────
def refresh_episode_mirrors(episode) -> dict:
    """Recompute mirrored score columns, overall risk and alerts on the
    parent ``AssessmentSession`` episode from its latest related child
    assessment records. Mutates ``episode`` in place — caller must
    ``save()`` it. Returns the dict of computed mirror values.
    """
    braden = episode.braden_assessments.order_by('-assessed_at').first()
    caprini = episode.caprini_assessments.order_by('-assessed_at').first()
    morse = episode.morse_assessments.order_by('-assessed_at').first()
    must = episode.must_assessments.order_by('-assessed_at').first()
    cam = episode.cam_assessments.order_by('-assessed_at').first()
    pain = episode.pain_assessments.order_by('-assessed_at').first()
    gcs = episode.gcs_assessments.order_by('-assessed_at').first()

    episode.braden_total = braden.total if braden else None
    episode.caprini_points = caprini.points if caprini else None
    episode.morse_score = morse.score if morse else None
    episode.must_score = must.total_score if must else None
    episode.cam_positive = cam.cam_positive if cam else None
    episode.pain_score = pain.score if pain else None
    episode.gcs_total = gcs.total if gcs else None

    episode.overall_risk_level = aggregate_risk(
        episode.braden_total, episode.caprini_points, episode.morse_score,
        episode.must_score, episode.cam_positive, episode.pain_score,
    )

    episode.alerts_triggered = generate_alerts({
        'braden_total': episode.braden_total, 'braden_risk': braden.risk_level if braden else '',
        'caprini_points': episode.caprini_points, 'caprini_risk': caprini.risk_level if caprini else '',
        'morse_score': episode.morse_score, 'morse_risk': morse.risk_level if morse else '',
        'must_score': episode.must_score, 'must_risk': must.risk_level if must else '',
        'cam_positive': episode.cam_positive,
        'pain_score': episode.pain_score,
        'catheter_bundle': episode.catheter_bundle or {},
        'central_line_bundle': episode.central_line_bundle or {},
    })

    return {
        'braden_total': episode.braden_total, 'caprini_points': episode.caprini_points,
        'morse_score': episode.morse_score, 'must_score': episode.must_score,
        'cam_positive': episode.cam_positive, 'pain_score': episode.pain_score,
        'gcs_total': episode.gcs_total,
    }


# ─────────────────────────────────────────────────────────
#  Escalation creation for critical alerts
# ─────────────────────────────────────────────────────────
SEVERITY_MAP = {
    'info': 'low',
    'warning': 'medium',
    'high': 'high',
    'critical': 'critical',
}


def create_escalations(session, actor_user=None):
    """Create Escalation records for critical/high assessment alerts.

    Returns the list of created Escalation objects (empty if none).
    Idempotent — skips alert codes already escalated for this session.
    """
    from .models import AssessmentAlert, Escalation
    created = []
    existing_codes = set(
        session.alerts.values_list('code', flat=True)
    )
    for a in (session.alerts_triggered or []):
        code = a.get('code', '')
        if code in existing_codes:
            continue
        sev = SEVERITY_MAP.get(a.get('severity', 'warning'), 'medium')
        esc = None
        if sev in ('high', 'critical'):
            esc = Escalation.objects.create(
                patient=session.patient,
                triggered_at=timezone.now(),
                reason=a.get('title', 'Assessment alert'),
                detail=f'{a.get("detail", "")}\n\nRecommendation: '
                       f'{a.get("recommendation", "")}',
                severity=sev,
                status=Escalation.Status.OPEN,
            )
        alert = AssessmentAlert.objects.create(
            session=session,
            category=a.get('category', 'other'),
            severity=a.get('severity', 'warning'),
            title=a.get('title', ''),
            detail=a.get('detail', ''),
            threshold=a.get('threshold', ''),
            value=a.get('value', ''),
            recommendation=a.get('recommendation', ''),
            escalation=esc,
            code=code,
        )
        if esc:
            created.append(esc)
    return created


# ─────────────────────────────────────────────────────────
#  PIVC  — VIP Score (Visual Infusion Phlebitis, RCN)
# ─────────────────────────────────────────────────────────
# VIP Score thresholds based on Royal College of Nursing standard.
# Score 0 = healthy site, Score 5 = advanced thrombophlebitis.

def calc_pivc(payload: dict) -> dict:
    """Compute the VIP score (0–5) from PIVC clinical assessment fields.

    The scoring follows the RCN Visual Infusion Phlebitis scale:
      Score 0 – Healthy IV site (no pain, no redness, no swelling)
      Score 1 – Possible first signs (slight pain OR slight redness)
      Score 2 – Early phlebitis (pain + redness + swelling)
      Score 3 – Medium phlebitis (pain along vein + redness + induration)
      Score 4 – Advanced phlebitis (extensive pain + extensive redness + palpable cord)
      Score 5 – Advanced thrombophlebitis (all of the above + pyrexia/purulent drainage)
    """
    payload = payload or {}
    out = dict(payload)

    pain = (payload.get('pain_level') or '').strip()
    erythema = (payload.get('erythema') or '').strip()
    swelling = (payload.get('swelling') or '').strip()
    induration = (payload.get('induration') or '').strip()
    palpable_cord = (payload.get('palpable_cord') or '').strip()
    drainage_type = (payload.get('drainage_type') or '').strip()

    has_pain = pain in ('palpation', 'during_infusion', 'constant', 'severe')
    has_slight_pain = pain == 'palpation'
    has_extensive_pain = pain in ('constant', 'severe')

    has_redness = erythema not in ('', 'none')
    has_slight_redness = erythema == 'localized_lt_1cm'
    has_extensive_redness = erythema in ('along_vein', 'extensive')
    has_swelling = swelling not in ('', 'none')
    has_induration = induration not in ('', 'none')
    has_palpable_cord = palpable_cord not in ('', 'no')
    has_purulent = drainage_type == 'purulent'

    vip = 0
    if not has_pain and not has_redness and not has_swelling:
        vip = 0
    elif (has_slight_pain or has_slight_redness) and not has_swelling and not has_induration:
        vip = 1
    elif has_pain and has_redness and has_swelling and not has_induration and not has_palpable_cord:
        vip = 2
    elif has_pain and has_redness and has_induration and not has_palpable_cord:
        vip = 3
    elif has_extensive_pain and has_extensive_redness and has_palpable_cord and not has_purulent:
        vip = 4
    elif has_extensive_pain and has_extensive_redness and has_palpable_cord and has_purulent:
        vip = 5
    # Fallback: determine from individual features
    if vip == 0 and (has_pain or has_redness or has_swelling):
        vip = 2 if has_swelling else 1

    colour_map = {0: 'green', 1: 'yellow', 2: 'orange', 3: 'red', 4: 'dark_red', 5: 'critical_red'}
    label_map = {
        0: 'Healthy IV site', 1: 'Possible first signs of phlebitis',
        2: 'Early phlebitis', 3: 'Medium phlebitis',
        4: 'Advanced phlebitis', 5: 'Advanced thrombophlebitis',
    }

    out['vip_score'] = vip
    out['vip_colour'] = colour_map.get(vip, 'grey')
    out['vip_label'] = label_map.get(vip, '')
    out['recommendations'] = _pivc_recommendations(vip)

    # Bundle compliance %
    bundle_keys = [k for k in out if k.startswith('bundle_') and k != 'bundle_compliance_pct']
    answered = [k for k in bundle_keys if out.get(k, '') in ('yes', 'no', 'na')]
    yes_count = sum(1 for k in bundle_keys if out.get(k) == 'yes')
    if answered:
        out['bundle_compliance_pct'] = round(yes_count / len(answered) * 100)
    else:
        out['bundle_compliance_pct'] = None

    return out


def _pivc_recommendations(vip: int) -> list[str]:
    """Generate clinical recommendations based on VIP score."""
    recs = []
    if vip == 0:
        recs.append('Continue routine observations per policy.')
    elif vip == 1:
        recs.append('Observe catheter site carefully.')
        recs.append('Repeat assessment according to policy (minimum every 4 hours).')
    elif vip == 2:
        recs.append('Consider resiting the catheter.')
        recs.append('Monitor patient closely.')
    elif vip == 3:
        recs.append('Remove catheter immediately.')
        recs.append('Restart IV elsewhere if required.')
        recs.append('Inform clinician and document intervention.')
    elif vip == 4:
        recs.append('Immediate catheter removal.')
        recs.append('Medical review required.')
        recs.append('Initiate treatment as prescribed.')
        recs.append('Document as adverse event.')
    elif vip == 5:
        recs.append('Urgent medical review — escalate immediately.')
        recs.append('Remove catheter.')
        recs.append('Blood cultures if prescribed.')
        recs.append('Commence treatment.')
        recs.append('Complete incident report.')
    return recs
