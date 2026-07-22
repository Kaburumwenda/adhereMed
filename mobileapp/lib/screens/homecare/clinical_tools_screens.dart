import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api.dart';
import 'hc_common.dart';
import 'vitals_screen.dart' show news2Color;

// ═════════════════ EWS / NEWS2 CALCULATOR (local scoring) ═════════════════
class HomecareEwsScreen extends StatefulWidget {
  const HomecareEwsScreen({super.key});

  @override
  State<HomecareEwsScreen> createState() => _HomecareEwsScreenState();
}

class _HomecareEwsScreenState extends State<HomecareEwsScreen> {
  double _rr = 16;
  double _spo2 = 97;
  bool _scale2 = false;
  bool _oxygen = false;
  double _sbp = 120;
  double _hr = 75;
  double _temp = 36.8;
  String _consciousness = 'A';

  int _scoreRR(num v) {
    if (v <= 8) return 3;
    if (v <= 11) return 1;
    if (v <= 20) return 0;
    if (v <= 24) return 2;
    return 3;
  }

  int _scoreSpO2(num v) {
    if (_scale2) {
      // Scale 2 (hypercapnic respiratory failure target 88–92%)
      if (v <= 83) return 3;
      if (v <= 85) return 2;
      if (v <= 87) return 1;
      if (v <= 92) return 0;
      if (!_oxygen) return 0;
      if (v <= 94) return 1;
      if (v <= 96) return 2;
      return 3;
    }
    if (v <= 91) return 3;
    if (v <= 93) return 2;
    if (v <= 95) return 1;
    return 0;
  }

  int _scoreSBP(num v) {
    if (v <= 90) return 3;
    if (v <= 100) return 2;
    if (v <= 110) return 1;
    if (v <= 219) return 0;
    return 3;
  }

  int _scoreHR(num v) {
    if (v <= 40) return 3;
    if (v <= 50) return 1;
    if (v <= 90) return 0;
    if (v <= 110) return 1;
    if (v <= 130) return 2;
    return 3;
  }

  int _scoreTemp(num v) {
    if (v <= 35.0) return 3;
    if (v <= 36.0) return 1;
    if (v <= 38.0) return 0;
    if (v <= 39.0) return 1;
    return 2;
  }

  int get _total =>
      _scoreRR(_rr) +
      _scoreSpO2(_spo2) +
      (_oxygen ? 2 : 0) +
      _scoreSBP(_sbp) +
      _scoreHR(_hr) +
      _scoreTemp(_temp) +
      (_consciousness == 'A' ? 0 : 3);

  String get _band {
    final t = _total;
    if (t >= 7) return 'HIGH — emergency response';
    if (t >= 5) return 'MEDIUM — urgent review';
    if (t > 0) return 'LOW-MED — ward review';
    return 'LOW — routine monitoring';
  }

  @override
  Widget build(BuildContext context) {
    final color = news2Color(_total);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const HcHero(
          eyebrow: 'CLINICAL TOOLS',
          title: 'NEWS2 calculator',
          subtitle: 'Bedside early-warning score (RCP NEWS2)',
          icon: Icons.calculate_rounded,
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3)),
                alignment: Alignment.center,
                child: Text('$_total',
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
              const SizedBox(height: 8),
              Text(_band,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: color)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        HcPanel(
          title: 'Observations',
          icon: Icons.tune_rounded,
          color: hcTeal,
          child: Column(children: [
            _SliderRow(
                label: 'Resp rate',
                value: _rr,
                min: 4,
                max: 40,
                unit: '/min',
                score: _scoreRR(_rr),
                onChanged: (v) => setState(() => _rr = v)),
            _SliderRow(
                label: 'SpO₂',
                value: _spo2,
                min: 70,
                max: 100,
                unit: '%',
                score: _scoreSpO2(_spo2),
                onChanged: (v) => setState(() => _spo2 = v)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _scale2,
                title: const Text('SpO₂ Scale 2 (COPD, target 88–92%)',
                    style: TextStyle(fontSize: 13)),
                onChanged: (v) => setState(() => _scale2 = v)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _oxygen,
                title: const Text('On supplemental oxygen (+2)',
                    style: TextStyle(fontSize: 13)),
                onChanged: (v) => setState(() => _oxygen = v)),
            _SliderRow(
                label: 'Systolic BP',
                value: _sbp,
                min: 60,
                max: 240,
                unit: 'mmHg',
                score: _scoreSBP(_sbp),
                onChanged: (v) => setState(() => _sbp = v)),
            _SliderRow(
                label: 'Heart rate',
                value: _hr,
                min: 30,
                max: 180,
                unit: 'bpm',
                score: _scoreHR(_hr),
                onChanged: (v) => setState(() => _hr = v)),
            _SliderRow(
                label: 'Temperature',
                value: _temp,
                min: 33,
                max: 41,
                unit: '°C',
                decimals: 1,
                score: _scoreTemp(_temp),
                onChanged: (v) => setState(() => _temp = v)),
            const SizedBox(height: 6),
            Row(children: [
              const Expanded(
                  child: Text('Consciousness (ACVPU)',
                      style: TextStyle(fontSize: 13))),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'A', label: Text('A')),
                  ButtonSegment(value: 'C', label: Text('C')),
                  ButtonSegment(value: 'V', label: Text('V')),
                  ButtonSegment(value: 'P', label: Text('P')),
                  ButtonSegment(value: 'U', label: Text('U')),
                ],
                selected: {_consciousness},
                showSelectedIcon: false,
                style:
                    const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (s) =>
                    setState(() => _consciousness = s.first),
              ),
            ]),
          ]),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final int score;
  final int decimals;
  final ValueChanged<double> onChanged;
  const _SliderRow(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.unit,
      required this.score,
      this.decimals = 0,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scoreColor = score == 0
        ? hcGreen
        : score == 1
            ? hcBlue
            : score == 2
                ? hcAmber
                : hcRed;
    return Column(children: [
      Row(children: [
        Expanded(
            child:
                Text(label, style: const TextStyle(fontSize: 13))),
        Text('${value.toStringAsFixed(decimals)} $unit',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        HcStatusChip(label: '+$score', color: scoreColor),
      ]),
      Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * (decimals == 1 ? 10 : 1)).round(),
          onChanged: onChanged),
    ]);
  }
}

// ═════════════════ CLINICAL PROTOCOLS (reference library) ═════════════════

class _P {
  final String code, version, category, title, acuity, owner, updated, summary, indication, reference;
  final Color color;
  final IconData icon;
  final List<String> tags;
  final List<(String, String)> steps;      // (title, detail)
  final List<(String, String)> medications; // (name, dose)
  final List<String> redFlags;
  const _P(this.code, this.version, this.category, this.title, this.acuity, this.color, this.icon,
      this.owner, this.updated, this.tags, this.summary, this.indication, this.steps,
      this.medications, this.redFlags, this.reference);
}

const _pRed = Color(0xFFDC2626);
const _pOrange = Color(0xFFEA580C);
const _pCyan = Color(0xFF0891B2);
const _pPurple = Color(0xFF7C3AED);
const _pBlue = Color(0xFF1D4ED8);
const _pPink = Color(0xFFDB2777);
const _pTeal = Color(0xFF0D9488);
const _pSlate = Color(0xFF475569);
const _pGreen = Color(0xFF16A34A);
const _pRose = Color(0xFFE11D48);
const _pAmber = Color(0xFFF59E0B);
const _pBrown = Color(0xFFA16207);
const _pIndigo = Color(0xFF6366F1);
const _pSky = Color(0xFF0EA5E9);
const _pDarkRed = Color(0xFF7F1D1D);
const _pDarkBlue = Color(0xFF0369A1);
const _pDeepIndigo = Color(0xFF4338CA);
const _pDarkTeal = Color(0xFF0F766E);

final _protocols = <_P>[
  _P('PR-001','1.4','Sepsis','Sepsis Six (Adult)','Critical',_pRed,Icons.bug_report_rounded,
    'ICU Lead · Dr. Mwangi','Updated 2 days ago',['Adult','Sepsis','Bundle'],
    'Deliver three and take three within one hour of suspected sepsis.',
    'Suspected sepsis with NEWS2 ≥ 5, qSOFA ≥ 2, or clinical concern.',
    [('Give high-flow oxygen','Target SpO₂ 94–98% (88–92% if COPD).'),
     ('Take blood cultures','Before antibiotics if no delay >45 min.'),
     ('IV broad-spectrum antibiotics','Per local antimicrobial stewardship.'),
     ('IV fluid resuscitation','30 mL/kg crystalloid bolus over 3 hours.'),
     ('Measure serum lactate','Repeat if initial >2 mmol/L.'),
     ('Monitor urine output','Hourly via catheter; target ≥0.5 mL/kg/h.')],
    [('Ceftriaxone','2 g IV stat'),('Hartmann\u2019s solution','30 mL/kg IV bolus')],
    ['Lactate > 4 mmol/L','Persistent hypotension after fluids','AMS / GCS drop','Mottling, anuria'],
    'NICE NG51 / Surviving Sepsis Campaign 2021'),

  _P('PR-002','2.1','Cardiology','Acute Chest Pain Pathway','High',_pOrange,Icons.favorite_rounded,
    'Cardiology · Dr. Otieno','Updated last week',['ACS','ECG','Triage'],
    'Rapid triage and risk stratification for adult chest pain.',
    'Adult patient with non-traumatic chest pain or anginal equivalent.',
    [('12-lead ECG within 10 min','Compare to prior if available.'),
     ('Aspirin 300 mg PO chewed','Unless contraindicated.'),
     ('IV access + bloods','Troponin, FBC, U&E, glucose.'),
     ('Continuous cardiac monitoring','Defib pads on standby.'),
     ('GTN spray sublingual','If SBP > 90 and no PDE5i in 24 h.'),
     ('Risk score (HEART)','Refer cath lab if STEMI / high risk.')],
    [('Aspirin','300 mg PO'),('GTN','400 mcg SL PRN'),('Morphine','2.5–5 mg IV titrated')],
    ['ST-elevation on ECG','Hypotension','New murmur','Syncope'],
    'ESC 2023 NSTE-ACS / Kenya MoH Cardiology Guideline'),

  _P('PR-003','1.0','Respiratory','Asthma Exacerbation (Adult)','High',_pCyan,Icons.air_rounded,
    'Respiratory · Dr. Kamau','Updated 1 month ago',['Asthma','Nebuliser','Adult'],
    'Stepwise management of acute asthma in the adult patient.',
    'Acute breathlessness, wheeze, PEF < 75% personal best.',
    [('Assess severity','PEF, SpO₂, RR, ability to speak in sentences.'),
     ('Oxygen 94–98%','Use Venturi or NRBM as needed.'),
     ('Salbutamol 5 mg neb','Repeat every 15 min; back-to-back if severe.'),
     ('Ipratropium 0.5 mg neb','Add if severe or life-threatening.'),
     ('Steroids','Prednisolone 40 mg PO or hydrocortisone 100 mg IV.'),
     ('Magnesium sulphate','1.2–2 g IV over 20 min for life-threatening.')],
    [('Salbutamol nebulised','5 mg in O₂'),('Ipratropium nebulised','0.5 mg'),('Prednisolone','40 mg PO OD × 5 days')],
    ['Silent chest','SpO₂ < 92%','Exhaustion','PEF < 33%'],
    'BTS/SIGN 2019 Asthma Guideline'),

  _P('PR-004','1.2','Endocrine','Diabetic Ketoacidosis (DKA)','Critical',_pPurple,Icons.water_drop_rounded,
    'Endocrine · Dr. Wanjiku','Updated 3 weeks ago',['Diabetes','DKA','Insulin'],
    'Fluid + insulin + potassium replacement protocol for DKA.',
    'Glucose >11, ketones ≥3 (or urine ≥2+), pH <7.3 / HCO₃ <15.',
    [('0.9% NaCl bolus','1 L over 1 h, then titrated.'),
     ('Fixed-rate insulin','0.1 U/kg/h IV (Actrapid).'),
     ('Monitor K+ hourly','Replace once <5.5 mmol/L.'),
     ('Add 10% dextrose','When glucose <14 mmol/L.'),
     ('Hourly capillary glucose & ketones','Aim ketone fall ≥0.5/h.'),
     ('VTE prophylaxis','Once euvolaemic.')],
    [('Sodium chloride 0.9%','1 L over 1 h'),('Insulin (Actrapid)','0.1 U/kg/h IV'),('KCl','40 mmol/L if K 3.5–5.5')],
    ['GCS drop','Cerebral oedema signs (esp. paeds)','Anuria','Persistent acidosis after 6 h'],
    'JBDS-IP DKA Guideline 2023'),

  _P('PR-005','1.0','Neurology','Acute Stroke (FAST)','Critical',_pBlue,Icons.psychology_rounded,
    'Neurology · Dr. Njoroge','Updated last week',['Stroke','Thrombolysis','FAST'],
    'Time-critical assessment for suspected stroke and TIA.',
    'Sudden-onset focal neurological deficit; FAST positive.',
    [('Note exact onset time','Or last-known-well.'),
     ('NIHSS assessment','Document baseline score.'),
     ('Capillary glucose','Exclude hypoglycaemia mimic.'),
     ('Urgent CT head (non-contrast)','Within 1 h of arrival.'),
     ('Consider thrombolysis','If <4.5 h and no contraindications.'),
     ('Stroke team referral','For thrombectomy / unit admission.')],
    [('Alteplase','0.9 mg/kg IV (10% bolus)'),('Aspirin','300 mg PO/PR (after CT excludes haemorrhage)')],
    ['GCS drop','New seizure','Vomiting + headache (haemorrhage)'],
    'NICE NG128 Stroke / WSO Guidelines'),

  _P('PR-006','1.1','Maternity','Postpartum Haemorrhage','Critical',_pPink,Icons.child_care_rounded,
    'Obstetrics · Dr. Achieng','Updated 2 weeks ago',['PPH','Maternity','Bleeding'],
    '4 T\u2019s approach to postpartum haemorrhage.',
    'Blood loss >500 mL vaginal / >1000 mL c-section, or symptomatic.',
    [('Call for help','Senior midwife, obstetrician, anaesthetist.'),
     ('ABC + 2 large-bore IV','Bloods incl. crossmatch 4 units.'),
     ('Uterine massage + empty bladder','Identify cause (4T).'),
     ('Uterotonics','Oxytocin → ergometrine → carboprost → misoprostol.'),
     ('Tranexamic acid 1 g IV','Within 3 h of bleed onset.'),
     ('Escalate to theatre','Bakri balloon, B-Lynch, hysterectomy.')],
    [('Oxytocin','5 IU IV slow + 40 IU in 500 mL infusion'),('Ergometrine','500 mcg IM (avoid in HTN)'),('Tranexamic acid','1 g IV')],
    ['Ongoing bleeding > 1500 mL','Hypotension','Tachycardia >120','Signs of DIC'],
    'WHO PPH Guideline 2022 / RCOG GTG 52'),

  _P('PR-007','1.0','Wound Care','Pressure Ulcer Prevention','Routine',_pTeal,Icons.healing_rounded,
    'Tissue Viability · S/N Mwende','Updated last month',['Homecare','SSKIN','Skin'],
    'SSKIN bundle for bedbound and limited-mobility patients.',
    'Braden ≤18 or any patient on bedrest >48 h.',
    [('Skin assessment','Daily inspection of bony prominences.'),
     ('Surface','Pressure-redistributing mattress / cushion.'),
     ('Keep moving','Reposition q2h; small shifts hourly.'),
     ('Incontinence care','Barrier cream, prompt changes.'),
     ('Nutrition','Protein 1.2–1.5 g/kg/day; refer dietitian if MUST ≥2.')],
    [('Barrier cream','Apply with each pad change')],
    ['New non-blanching erythema','Broken skin','Foul odour / exudate'],
    'NICE CG179 Pressure Ulcers'),

  _P('PR-008','1.0','Palliative','Symptom Control – End of Life','Routine',_pSlate,Icons.volunteer_activism_rounded,
    'Palliative · Dr. Hassan','Updated 1 week ago',['Palliative','Comfort','Anticipatory'],
    'Anticipatory prescribing for the last days of life.',
    'Patient in last days of life (recognised by MDT).',
    [('Stop non-essential meds','Review all routes.'),
     ('Convert to syringe driver','If unable to swallow.'),
     ('Pain – morphine','2.5–5 mg SC PRN; baseline if opioid-naïve.'),
     ('Nausea – haloperidol','0.5–1.5 mg SC PRN.'),
     ('Secretions – hyoscine butylbromide','20 mg SC PRN, max 120 mg/24 h.'),
     ('Agitation – midazolam','2.5–5 mg SC PRN.')],
    [('Morphine sulfate','2.5–5 mg SC PRN'),('Midazolam','2.5–5 mg SC PRN'),('Hyoscine butylbromide','20 mg SC PRN')],
    ['Uncontrolled pain after 4 doses','Distress despite anxiolytic','Family request for review'],
    'NICE NG31 Care of Dying Adults'),

  _P('PR-009','1.0','Infection','Suspected Tuberculosis','Moderate',_pGreen,Icons.coronavirus_rounded,
    'Infectious Diseases · Dr. Karanja','Updated 3 weeks ago',['TB','Isolation','Public Health'],
    'Initial workup and isolation pathway for suspected TB.',
    'Cough >2 weeks + weight loss, fever, night sweats, or contact.',
    [('Place in isolation','Negative-pressure room if available; mask.'),
     ('Sputum × 3 (incl. early morning)','GeneXpert MTB/RIF + AFB.'),
     ('CXR','Look for cavitation, infiltrates, effusion.'),
     ('HIV test + screen contacts','Per national TB policy.'),
     ('Notify public health','Mandatory disease notification.'),
     ('Start RIPE if confirmed','Per body weight banding.')],
    [('Rifampicin / Isoniazid / Pyrazinamide / Ethambutol','Per Kenya TB programme')],
    ['Massive haemoptysis','Resp failure','Drug-resistant suspicion'],
    'WHO TB Guidelines 2023 / NTLD-P Kenya'),

  _P('PR-010','1.3','Anaphylaxis','Anaphylaxis (Adult & Paediatric)','Critical',_pRose,Icons.emergency_rounded,
    'Emergency · Dr. Owino','Updated 5 days ago',['Allergy','Adrenaline','ABCDE'],
    'Immediate management of suspected anaphylaxis with adrenaline-first approach.',
    'Sudden airway / breathing / circulation problem with skin changes after likely trigger.',
    [('Remove trigger if possible','Stop infusions, brush off stings.'),
     ('Call resus team & lay patient flat','Legs raised; pregnant – left lateral.'),
     ('IM adrenaline','Adult 500 mcg; child 6–12 yr 300 mcg; <6 yr 150 mcg. Repeat after 5 min.'),
     ('High-flow oxygen','15 L/min via NRBM; intubate if airway compromise.'),
     ('IV fluid bolus','Adult 500–1000 mL crystalloid; child 10 mL/kg.'),
     ('Reassess and observe ≥6 h','Risk of biphasic reaction; refer allergy clinic.')],
    [('Adrenaline 1:1000','500 mcg IM (adult)'),('Hydrocortisone','200 mg IV'),('Chlorphenamine','10 mg IV/IM')],
    ['Stridor / hoarseness','Hypotension despite 2 doses adrenaline','Loss of consciousness','Pregnancy with anaphylaxis'],
    'Resuscitation Council UK 2021 / EAACI Guideline'),

  _P('PR-011','1.0','Paediatrics','Paediatric Fever (0–5 years)','Moderate',_pAmber,Icons.child_friendly_rounded,
    'Paediatrics · Dr. Wambui','Updated 2 weeks ago',['Paeds','Traffic light','Fever'],
    'NICE traffic-light triage for the febrile child under 5.',
    'Child <5 years with axillary T ≥ 37.5 °C.',
    [('Measure full vitals','Tympanic/axillary T, HR, RR, SpO₂, CRT.'),
     ('Apply traffic-light tool','Colour, activity, respiratory, circulation, other.'),
     ('Identify focus of infection','ENT, chest, urine, skin, meningism.'),
     ('Septic screen if Red','FBC, CRP, blood culture, urine, ± LP, CXR.'),
     ('Antipyretic for distress','Paracetamol 15 mg/kg or ibuprofen 10 mg/kg.'),
     ('Safety-net or admit','Red → admit; Amber → senior review; Green → home.')],
    [('Paracetamol','15 mg/kg PO 4–6 hrly'),('Ibuprofen','10 mg/kg PO 6–8 hrly'),('Ceftriaxone','50 mg/kg IV')],
    ['Non-blanching rash','Bulging fontanelle','Grunting / chest indrawing','CRT ≥3 s','Reduced consciousness','Age <3 months with T ≥38 °C'],
    'NICE NG143 Fever in under 5s'),

  _P('PR-012','1.0','Paediatrics','Severe Acute Malnutrition (IMCI)','High',_pBrown,Icons.no_food_rounded,
    'Paediatrics · Dr. Mwende','Updated last month',['IMCI','F-75','Nutrition'],
    'Inpatient stabilisation of children with SAM per WHO 10-step plan.',
    'MUAC <115 mm, WFH <-3 SD, or bilateral pitting oedema.',
    [('Treat / prevent hypoglycaemia','50 mL of 10% dextrose PO/NG or IV.'),
     ('Treat / prevent hypothermia','Kangaroo care, blankets, warm room.'),
     ('Cautious rehydration','ReSoMal 5 mL/kg q30 min × 2 h, NEVER routine IV.'),
     ('Correct electrolytes','Extra K, Mg; restrict Na.'),
     ('Treat infection empirically','Amoxicillin or ampicillin + gentamicin.'),
     ('Start feeding F-75','Small frequent feeds; transition to F-100/RUTF.')],
    [('Amoxicillin','15 mg/kg PO TDS × 5 days'),('Ampicillin + Gentamicin','IV per WHO weight bands'),('Vitamin A','Single dose per age')],
    ['Refeeding syndrome','Heart failure during rehydration','Persistent hypoglycaemia','Hypothermia <35 °C'],
    'WHO Pocket Book of Hospital Care for Children 2013 (rev. 2024)'),

  _P('PR-013','1.1','Endocrine','Hypoglycaemia Management','High',_pPurple,Icons.bloodtype_rounded,
    'Diabetes Team · S/N Achieng','Updated last week',['Hypo','Diabetes','Glucose'],
    'Adult hypoglycaemia (BG < 4 mmol/L) treatment ladder.',
    'Capillary glucose <4 mmol/L, with or without symptoms.',
    [('Check capillary BG & ABC','Confirm before treating.'),
     ('Conscious & cooperative','15–20 g fast-acting carb (e.g. 4 glucose tabs).'),
     ('Conscious but uncooperative','1.5–2 tubes Glucogel buccally.'),
     ('Unconscious / NBM','150 mL 10% dextrose IV over 15 min, or 1 mg glucagon IM.'),
     ('Recheck in 15 min','Repeat treatment up to 3 cycles; escalate if persists.'),
     ('Long-acting carbohydrate','Sandwich / biscuits once BG ≥4 mmol/L.')],
    [('10% dextrose','150 mL IV over 15 min'),('Glucagon','1 mg IM (one dose only)')],
    ['Refractory after 3 cycles','Suspected sulfonylurea / alcohol cause','Reduced GCS','Seizure'],
    'JBDS-IP Hypoglycaemia in Adults 2023'),

  _P('PR-014','1.0','Gastroenterology','Upper GI Bleed','High',_pDarkRed,Icons.local_hospital_rounded,
    'Gastroenterology · Dr. Mutua','Updated 2 weeks ago',['Haematemesis','Variceal','Endoscopy'],
    'Resuscitation and risk stratification for acute upper GI bleed.',
    'Haematemesis, melaena, or significant drop in Hb with shock.',
    [('ABC + 2 large-bore IV','Bloods incl. crossmatch 4 units, INR.'),
     ('Calculate Glasgow-Blatchford','Score ≥6 → endoscopy within 24 h.'),
     ('Resuscitate to MAP ≥65','Crystalloid + transfuse if Hb <70 g/L.'),
     ('Reverse anticoagulation','Vitamin K, PCC if on warfarin; idarucizumab for dabigatran.'),
     ('Pre-endoscopy meds','IV PPI; in suspected variceal: terlipressin + ceftriaxone.'),
     ('Urgent endoscopy','Within 24 h; <12 h if unstable / variceal.')],
    [('Pantoprazole','80 mg IV bolus then 8 mg/h infusion'),('Terlipressin','2 mg IV q4h (variceal)'),('Ceftriaxone','1 g IV OD × 7 days')],
    ['Ongoing haematemesis','SBP <90','Lactate >4','Failure of endoscopic haemostasis'],
    'NICE CG141 Acute Upper GI Bleed'),

  _P('PR-015','1.0','Surgery','Acute Abdomen Triage','High',_pOrange,Icons.medical_services_rounded,
    'General Surgery · Dr. Kibet','Updated 3 weeks ago',['Surgery','Abdomen','Triage'],
    'Structured workup of the patient with severe abdominal pain.',
    'Severe abdominal pain ≥6 h or peritonitic features.',
    [('NEWS2 + analgesia','IV morphine titrated; antiemetic.'),
     ('IV access + bloods','FBC, U&E, LFT, amylase, lactate, lipase, CRP, βhCG.'),
     ('Imaging','Erect CXR + AXR; CT abdo/pelvis if peritonitic / >65 y.'),
     ('NBM + IV fluids','Until surgical review.'),
     ('Antibiotics if sepsis','Co-amoxiclav + metronidazole (per local).'),
     ('Senior surgical review','Within 1 h for peritonitis or shock.')],
    [('Morphine','2.5–5 mg IV titrated'),('Co-amoxiclav','1.2 g IV TDS'),('Metronidazole','500 mg IV TDS')],
    ['Rigid / silent abdomen','Hypotension','Bilious vomiting','Suspected ruptured AAA in >55 y'],
    'RCS Eng. Emergency General Surgery Standards'),

  _P('PR-016','1.0','Mental Health','Acute Behavioural Disturbance','High',_pIndigo,Icons.psychology_alt_rounded,
    'Psychiatry · Dr. Said','Updated last week',['De-escalation','Sedation','Safety'],
    'Safe management of the acutely agitated or aggressive patient.',
    'Severe agitation risking harm to self, staff or others.',
    [('Ensure team safety','Call security, clear environment, exit route.'),
     ('Verbal de-escalation','Calm tone, single spokesperson, offer choices.'),
     ('Rule out medical cause','Glucose, hypoxia, infection, intoxication, head injury.'),
     ('Offer oral medication','Lorazepam 1–2 mg PO ± promethazine 25 mg PO.'),
     ('IM rapid tranquillisation','Lorazepam 2 mg IM; or haloperidol 5 mg + promethazine 25 mg IM.'),
     ('Monitor & document','BP, RR, SpO₂, sedation score q15 min for 1 h.')],
    [('Lorazepam','1–2 mg PO/IM (max 4 mg in 24 h)'),('Haloperidol','5 mg IM'),('Promethazine','25–50 mg IM')],
    ['Over-sedation (RASS ≤-3)','Airway compromise','QTc >500 ms','Suspected NMS'],
    'NICE NG10 Violence and Aggression'),

  _P('PR-017','1.0','Renal','Acute Kidney Injury (AKI)','Moderate',_pSky,Icons.water_outlined,
    'Nephrology · Dr. Njeri','Updated 2 weeks ago',['AKI','Fluids','Nephrotoxins'],
    'STOP-AKI bundle: identify, optimise, refer.',
    'Creatinine ↑ ≥26 µmol/L in 48 h or ≥1.5× baseline; or UO <0.5 mL/kg/h ×6 h.',
    [('Stage AKI (KDIGO 1–3)','Use baseline creatinine and urine output.'),
     ('Assess volume status','Postural BP, JVP, lung bases, IVC US.'),
     ('Sepsis 6 if infected','Treat underlying cause.'),
     ('Stop nephrotoxins','NSAIDs, ACEi/ARB, metformin, diuretics, contrast.'),
     ('Cautious fluid challenge','250–500 mL crystalloid; reassess.'),
     ('Refer renal if Stage 3 / refractory','Consider RRT for AEIOU indications.')],
    [('Hartmann\u2019s solution','500 mL IV bolus'),('Furosemide','Only for fluid overload, not for AKI itself')],
    ['K+ >6.5 mmol/L','pH <7.15','Pulmonary oedema','Pericardial rub','Uraemic encephalopathy'],
    'NICE NG148 / KDIGO AKI Guideline 2012'),

  _P('PR-018','1.2','Infection','Catheter-Associated UTI Prevention','Routine',_pGreen,Icons.medical_information_rounded,
    'IPC · S/N Achieng','Updated 3 weeks ago',['CAUTI','IPC','Bundle'],
    'Insertion + maintenance bundle to prevent catheter UTIs.',
    'Any patient with an indwelling urinary catheter.',
    [('Confirm indication daily','Remove ASAP if no longer required.'),
     ('Aseptic insertion','Hand hygiene, sterile gloves, sterile field.'),
     ('Closed drainage system','Bag below bladder, never on floor.'),
     ('Perineal care BD','Soap and water; no antiseptic.'),
     ('Sample correctly','From sampling port after disinfection, never from bag.'),
     ('Document & audit','Insertion date, indication, removal date.')],
    [('No prophylactic antibiotics','Avoid unless documented infection')],
    ['Cloudy / foul-smelling urine + fever','Suprapubic / loin pain','New confusion in elderly','Catheter blockage'],
    'IPC Kenya / NICE QS61'),

  _P('PR-019','1.0','Wound Care','Diabetic Foot Ulcer','Moderate',_pDarkTeal,Icons.directions_walk_rounded,
    'Diabetes / Vascular · Dr. Kiprono','Updated last month',['Diabetes','Ulcer','Offloading'],
    'Multidisciplinary management of the diabetic foot ulcer.',
    'Any new or non-healing foot wound in a diabetic patient.',
    [('Classify (SINBAD / Wagner)','Document size, depth, infection, ischaemia.'),
     ('Vascular assessment','Pulses, ABPI, refer if absent.'),
     ('Probe to bone test','Positive → suspect osteomyelitis; X-ray.'),
     ('Sharp debridement','Remove callus and slough.'),
     ('Offloading device','Total-contact cast or removable boot.'),
     ('Infection control','Swab if signs of infection; antibiotics per culture.')],
    [('Flucloxacillin','500 mg PO QDS (mild infection)'),('Co-amoxiclav','625 mg PO TDS or 1.2 g IV TDS')],
    ['Spreading cellulitis','Crepitus / necrosis (gas gangrene)','Critical limb ischaemia','Systemic sepsis'],
    'NICE NG19 Diabetic Foot Problems / IWGDF 2023'),

  _P('PR-020','1.0','Critical Care','Massive Transfusion Protocol','Critical',_pDarkRed,Icons.opacity_rounded,
    'Anaesthesia · Dr. Mohammed','Updated 1 week ago',['MTP','Trauma','Haemorrhage'],
    'Balanced 1:1:1 transfusion for major haemorrhage.',
    'ABC score ≥2, expected ≥10 units RBC in 24 h, or shock index >1.4.',
    [('Activate MTP – call blood bank','Senior clinician declares MTP.'),
     ('Permissive hypotension','Target SBP 80–90 (90–100 if TBI).'),
     ('Tranexamic acid','1 g IV over 10 min within 3 h, then 1 g over 8 h.'),
     ('Issue Pack 1','4 RBC : 4 FFP : 1 platelet pool.'),
     ('Repeat near-patient testing','ABG, ROTEM/TEG, fibrinogen, Ca²⁺ q30 min.'),
     ('Source control','Theatre / IR within 1 h; deactivate MTP when stable.')],
    [('Tranexamic acid','1 g IV bolus + 1 g over 8 h'),('Calcium chloride 10%','10 mL IV after every 4 units RBC'),('Cryoprecipitate / fibrinogen','Target fibrinogen >1.5 g/L')],
    ['Lethal triad: acidosis, coagulopathy, hypothermia','Hyperkalaemia from stored blood','Citrate toxicity (low Ca)','Failure to identify source within 60 min'],
    'NICE NG39 Major Trauma / NHSBT MTP Guidance'),

  _P('PR-021','1.0','Cardiology','Acute Decompensated Heart Failure','High',_pDarkBlue,Icons.heart_broken_rounded,
    'Cardiology · Dr. Otieno','Updated 2 weeks ago',['Heart failure','Pulmonary oedema','Diuretics'],
    'LMNOP approach to acute pulmonary oedema and decompensated HF.',
    'Acute breathlessness with crackles, raised JVP, ± peripheral oedema.',
    [('Sit up, oxygen if SpO₂ <94%','NIV (CPAP) early if persistent hypoxia.'),
     ('IV access + bloods + ECG','Troponin, BNP, U&E, FBC, TFT.'),
     ('IV loop diuretic','Furosemide 40–80 mg IV (or 2.5× home dose).'),
     ('GTN infusion if SBP >110','10–200 mcg/min titrated.'),
     ('Daily weights + strict I/O','Catheterise if accurate UO needed.'),
     ('Investigate trigger','ACS, AF, infection, non-compliance, anaemia.')],
    [('Furosemide','40–80 mg IV (or infusion 5–10 mg/h)'),('GTN infusion','10–200 mcg/min IV'),('Morphine','2.5 mg IV (use sparingly)')],
    ['SBP <90 with peripheral shutdown (cardiogenic shock)','SpO₂ <90% on NRBM','Anuria despite diuretics','New STEMI on ECG'],
    'ESC 2021 Heart Failure Guidelines'),

  _P('PR-022','1.0','Neurology','Status Epilepticus (Adult)','Critical',_pDeepIndigo,Icons.bolt_rounded,
    'Neurology · Dr. Njoroge','Updated 5 days ago',['Seizure','Benzodiazepine','EEG'],
    'Time-staged anticonvulsant ladder for convulsive status epilepticus.',
    'Continuous seizure ≥5 min or recurrent seizures without recovery.',
    [('0–5 min: ABC, position, oxygen','Capillary glucose, IV access, bloods incl. AED levels.'),
     ('5–10 min: First benzodiazepine','Lorazepam 4 mg IV, or midazolam 10 mg IM/buccal.'),
     ('10–20 min: Second benzodiazepine','Repeat once if still seizing.'),
     ('20–40 min: Second-line AED','Levetiracetam 60 mg/kg or sodium valproate 40 mg/kg IV.'),
     ('40+ min: Refractory – call ICU','Intubate; thiopentone or propofol infusion.'),
     ('Continuous EEG when refractory','Identify NCSE; treat underlying cause.')],
    [('Lorazepam','4 mg IV (repeat once at 10 min)'),('Levetiracetam','60 mg/kg IV over 10 min'),('Sodium valproate','40 mg/kg IV over 10 min')],
    ['Hypoxia / aspiration','Hypoglycaemia','Pregnancy (eclampsia)','Refractory after 2 second-line agents'],
    'ILAE 2023 / NICE NG217'),
];

Color _acuityColor(String a) => switch (a) {
      'Critical' => hcRed,
      'High' => hcAmber,
      'Moderate' => hcBlue,
      'Routine' => hcGreen,
      _ => hcSlate,
    };

class HomecareProtocolsScreen extends StatefulWidget {
  const HomecareProtocolsScreen({super.key});
  @override
  State<HomecareProtocolsScreen> createState() => _HomecareProtocolsScreenState();
}

class _HomecareProtocolsScreenState extends State<HomecareProtocolsScreen> {
  final _search = TextEditingController();
  String? _filterCategory;
  String? _filterAcuity;
  bool _isGrid = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_P> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _protocols.where((p) {
      if (_filterCategory != null && p.category != _filterCategory) return false;
      if (_filterAcuity != null && p.acuity != _filterAcuity) return false;
      if (q.isEmpty) return true;
      final blob = '${p.title} ${p.code} ${p.summary} ${p.tags.join(' ')}'.toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  List<String> get _categories => _protocols.map((p) => p.category).toSet().toList()..sort();

  void _openDetail(_P p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ProtocolDetailSheet(p: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final criticalCount = _protocols.where((p) => p.acuity == 'Critical').length;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Custom protocol authoring coming soon.'))),
        backgroundColor: hcIndigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New protocol'),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          HcHero(
            eyebrow: 'CLINICAL GOVERNANCE',
            title: 'Clinical Protocols',
            subtitle: 'Evidence-based pathways your care team can follow at the bedside.',
            icon: Icons.menu_book_rounded,
            gradient: const [hcIndigo, Color(0xFF4F46E5), Color(0xFF4338CA)],
            chips: [
              HcHeroChip(icon: Icons.verified_rounded, label: 'Peer reviewed'),
              HcHeroChip(icon: Icons.update_rounded, label: 'Versioned'),
            ],
          ),

          // ── KPI strip ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              Expanded(child: HcKpi(label: 'Total', value: '${_protocols.length}', icon: Icons.menu_book_rounded, color: hcTeal)),
              const SizedBox(width: 8),
              Expanded(child: HcKpi(label: 'Categories', value: '${_categories.length}', icon: Icons.category_rounded, color: hcIndigo)),
              const SizedBox(width: 8),
              Expanded(child: HcKpi(label: 'Critical', value: '$criticalCount', icon: Icons.warning_rounded, color: hcRed)),
              const SizedBox(width: 8),
              Expanded(child: HcKpi(label: 'Updated', value: 'Today', icon: Icons.update_rounded, color: hcPurple)),
            ]),
          ),

          // ── Filters ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        hintText: 'Search protocols…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ProtoViewToggle(isGrid: _isGrid, onChanged: (v) => setState(() => _isGrid = v)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: DropdownButtonFormField<String>(
                      value: _filterCategory,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        prefixIcon: Icon(Icons.category_outlined, size: 16),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All categories', overflow: TextOverflow.ellipsis)),
                        for (final c in _categories)
                          DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _filterCategory = v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: DropdownButtonFormField<String>(
                      value: _filterAcuity,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Acuity',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        prefixIcon: Icon(Icons.warning_amber_outlined, size: 16),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All acuities', overflow: TextOverflow.ellipsis)),
                        for (final a in const ['Routine', 'Moderate', 'High', 'Critical'])
                          DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _filterAcuity = v),
                    ),
                  ),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Grid / List ──
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Column(children: [
                Icon(Icons.search_off_rounded, size: 40, color: hcSlate.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                const Text('No protocols match', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Try changing the filters or search terms.', style: TextStyle(fontSize: 12, color: hcSlate)),
              ])),
            )
          else if (_isGrid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in filtered)
                    SizedBox(
                      width: (screenW - 32 - 10) / (screenW > 600 ? 3 : 2),
                      child: _ProtoGridCard(p: p, onTap: () => _openDetail(p)),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                for (final p in filtered)
                  _ProtoListCard(p: p, onTap: () => _openDetail(p)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ProtoViewToggle extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onChanged;
  const _ProtoViewToggle({required this.isGrid, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(context, Icons.grid_view_rounded, isGrid, () => onChanged(true)),
        Container(width: 1, height: 20, color: Theme.of(context).dividerColor),
        _btn(context, Icons.view_list_rounded, !isGrid, () => onChanged(false)),
      ]),
    );
  }
  Widget _btn(BuildContext ctx, IconData icon, bool sel, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Icon(icon, size: 18, color: sel ? hcIndigo : Theme.of(ctx).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ProtoGridCard extends StatelessWidget {
  final _P p;
  final VoidCallback onTap;
  const _ProtoGridCard({required this.p, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: p.color.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Color band
            Container(height: 5, decoration: BoxDecoration(color: p.color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)))),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Icon + title + acuity
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(10)),
                    child: Icon(p.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    Text('${p.code} · v${p.version}', style: TextStyle(fontSize: 9.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                  HcStatusChip(label: p.acuity, color: _acuityColor(p.acuity)),
                ]),
                const SizedBox(height: 6),
                // Summary
                Text(p.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                // Tags
                Wrap(spacing: 3, runSpacing: 3, children: [
                  for (final t in p.tags.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: hcSlate.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(5)),
                      child: Text(t, style: const TextStyle(fontSize: 8.5, color: hcSlate)),
                    ),
                ]),
                const SizedBox(height: 4),
                // Owner + updated
                Row(children: [
                  Icon(Icons.person_outline, size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Expanded(child: Text(p.owner, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProtoListCard extends StatelessWidget {
  final _P p;
  final VoidCallback onTap;
  const _ProtoListCard({required this.p, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: p.color.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(10)),
                child: Icon(p.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text('${p.code} · ${p.summary}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              HcStatusChip(label: p.acuity, color: _acuityColor(p.acuity)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: hcSlate.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(5)),
                child: Text('v${p.version}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: hcSlate)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ProtocolDetailSheet extends StatelessWidget {
  final _P p;
  const _ProtocolDetailSheet({required this.p});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: CustomScrollView(
            slivers: [
              // Gradient hero
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 8, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.color, p.color.withValues(alpha: 0.65)]),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 24, backgroundColor: Colors.white, child: Icon(p.icon, color: p.color, size: 24)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p.category} · v${p.version}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(p.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${p.code} · ${p.owner}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 5, runSpacing: 4, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.warning_amber_rounded, size: 11, color: Colors.white), const SizedBox(width: 4), Text('${p.acuity} acuity', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600))]),
                      ),
                      for (final t in p.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(10)),
                          child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                    ]),
                  ]),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Indication
                    _sectionTitle(context, Icons.track_changes_rounded, hcTeal, 'Indication'),
                    const SizedBox(height: 6),
                    Text(p.indication, style: const TextStyle(fontSize: 13, height: 1.4)),
                    const SizedBox(height: 20),

                    // Steps
                    _sectionTitle(context, Icons.format_list_numbered_rounded, hcIndigo, 'Steps'),
                    const SizedBox(height: 8),
                    for (var i = 0; i < p.steps.length; i++)
                      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 28, child: Column(children: [
                          Container(width: 22, height: 22, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle), alignment: Alignment.center, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                          if (i < p.steps.length - 1) Expanded(child: Container(width: 2, color: p.color.withValues(alpha: 0.2))),
                        ])),
                        const SizedBox(width: 10),
                        Expanded(child: Padding(
                          padding: EdgeInsets.only(bottom: i == p.steps.length - 1 ? 0 : 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.steps[i].$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            const SizedBox(height: 2),
                            Text(p.steps[i].$2, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3)),
                          ]),
                        )),
                      ])),
                    const SizedBox(height: 20),

                    // Medications + Red flags
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _sectionTitle(context, Icons.medication_rounded, hcPurple, 'Medications'),
                        const SizedBox(height: 6),
                        if (p.medications.isEmpty)
                          Text('No medications listed', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))
                        else
                          for (final m in p.medications)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: hcPurple.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(m.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                                  Text(m.$2, style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ]),
                              ),
                            ),
                      ])),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _sectionTitle(context, Icons.warning_rounded, hcRed, 'Red flags / escalate if'),
                        const SizedBox(height: 6),
                        if (p.redFlags.isEmpty)
                          Text('None listed', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))
                        else
                          for (final r in p.redFlags)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Icon(Icons.error_outline_rounded, size: 14, color: hcRed),
                                const SizedBox(width: 4),
                                Expanded(child: Text(r, style: const TextStyle(fontSize: 11))),
                              ]),
                            ),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Reference
                    Row(children: [
                      Icon(Icons.menu_book_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Reference: ${p.reference}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                    ]),
                    const SizedBox(height: 16),
                    // Actions
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Print not available on mobile.'))),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Print'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/homecare/patients');
                        },
                        icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                        label: const Text('Apply'),
                        style: FilledButton.styleFrom(backgroundColor: hcTeal, minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      )),
                    ]),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, Color color, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    ]);
  }
}

// ═════════════════ CATALOG (diagnoses + allergies) ═════════════════
final _diagnosesProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/diagnoses/', params: {'page_size': 300});
});
final _allergiesProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/allergies/', params: {'page_size': 300});
});

class HomecareCatalogScreen extends ConsumerWidget {
  const HomecareCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagCount =
        ref.watch(_diagnosesProvider).whenOrNull(data: (d) => d.length) ?? 0;
    final alleCount =
        ref.watch(_allergiesProvider).whenOrNull(data: (d) => d.length) ?? 0;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Clinical catalog',
              style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_for_offline_rounded),
              tooltip: 'Seed from platform catalog',
              onPressed: () => _seedCurrentTab(context, ref),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(
              text: 'Diagnoses',
              icon: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.medical_information_rounded, size: 16),
                const SizedBox(width: 6),
                _CountBadge(count: diagCount, color: hcTeal),
              ]),
            ),
            Tab(
              text: 'Allergies',
              icon: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.warning_rounded, size: 16),
                const SizedBox(width: 6),
                _CountBadge(count: alleCount, color: hcRed),
              ]),
            ),
          ]),
        ),
        body: const TabBarView(children: [
          _CatalogList(kind: 'diagnoses'),
          _CatalogList(kind: 'allergies'),
        ]),
      ),
    );
  }

  void _seedCurrentTab(BuildContext context, WidgetRef ref) {
    final tabController = DefaultTabController.of(context);
    final kind = tabController.index == 0 ? 'diagnoses' : 'allergies';
    _seedCatalog(context, ref, kind);
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

void _seedCatalog(BuildContext context, WidgetRef ref, String kind) {
  final label = kind == 'diagnoses' ? 'diagnoses' : 'allergies';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.download_for_offline_rounded, color: hcTeal),
        const SizedBox(width: 10),
        const Text('Seed from platform', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      content: Text(
          'Import all $label from the platform catalog? Existing names are kept untouched.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: hcTeal),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Seed'),
          onPressed: () async {
            Navigator.pop(ctx);
            final messenger = ScaffoldMessenger.of(context);
            try {
              final dio = ref.read(dioProvider);
              final res = await dio.post('/homecare/$label/seed/');
              final detail = res.data is Map ? res.data['detail'] : null;
              ref.invalidate(kind == 'diagnoses' ? _diagnosesProvider : _allergiesProvider);
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(
                  content: Text(detail ?? 'Seeded successfully.'),
                  backgroundColor: hcGreen,
                ));
              }
            } catch (_) {
              if (context.mounted) {
                messenger.showSnackBar(const SnackBar(
                  content: Text('Seed failed (admin only).'),
                  backgroundColor: hcRed,
                ));
              }
            }
          },
        ),
      ],
    ),
  );
}

class _CatalogList extends ConsumerStatefulWidget {
  final String kind;
  const _CatalogList({required this.kind});

  @override
  ConsumerState<_CatalogList> createState() => _CatalogListState();
}

class _CatalogListState extends ConsumerState<_CatalogList> {
  String _query = '';
  String _sourceFilter = ''; // '' | 'seed' | 'custom'

  bool _matchesSource(Map r) {
    if (_sourceFilter.isEmpty) return true;
    final src = (r['source'] ?? 'custom').toString();
    return src == _sourceFilter;
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.kind == 'diagnoses' ? _diagnosesProvider : _allergiesProvider;
    final data = ref.watch(provider);
    final isDiag = widget.kind == 'diagnoses';
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'add-${widget.kind}',
        backgroundColor: hcTeal,
        foregroundColor: Colors.white,
        onPressed: () => _openEditSheet(context, item: null),
        child: const Icon(Icons.add_rounded),
      ),
      body: HcAsyncBody(
        value: data,
        onRefresh: () async => ref.refresh(provider.future),
        builder: (list) {
          var rows = list.cast<Map>().where(_matchesSource).toList();
          if (_query.isNotEmpty) {
            final q = _query.toLowerCase();
            rows = rows.where((r) => [
                  r['name'],
                  r['icd_code'],
                  r['category'],
                  r['common_symptoms'],
                  r['description'],
                ].any((v) => (v ?? '').toString().toLowerCase().contains(q))).toList();
          }
          return Column(children: [
            // ── Toolbar: search + source filter ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.kind}…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DropdownButton<String>(
                    value: _sourceFilter,
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(14),
                    isDense: true,
                    icon: const Icon(Icons.filter_list_rounded, size: 20),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All sources')),
                      DropdownMenuItem(value: 'seed', child: Text('Seed')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    ],
                    onChanged: (v) => setState(() => _sourceFilter = v ?? ''),
                  ),
                ),
              ]),
            ),
            // ── Result count ──
            if (rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${rows.length} ${widget.kind}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                ),
            // ── List ──
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          const Text('No entries.'),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _seedCatalog(context, ref, widget.kind),
                            icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                            label: const Text('Seed defaults'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final isSeed = r['source'] == 'seed';
                        final isActive = r['is_active'] != false;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: (isDiag ? hcTeal : hcAmber).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isDiag ? Icons.medical_information_rounded : Icons.warning_rounded,
                                color: isDiag ? hcTeal : hcAmber,
                                size: 18,
                              ),
                            ),
                            title: Row(children: [
                              Expanded(
                                child: Text(r['name']?.toString() ?? '—',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                              if (!isActive)
                                HcStatusChip(label: 'INACTIVE', color: hcSlate, icon: Icons.cancel_rounded),
                            ]),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (isDiag && (r['icd_code'] ?? '').toString().isNotEmpty)
                                    HcStatusChip(label: 'ICD ${r['icd_code']}', color: hcIndigo),
                                  if ((r['category'] ?? '').toString().isNotEmpty)
                                    HcStatusChip(label: hcLabel(r['category']?.toString()), color: hcPurple),
                                  HcStatusChip(
                                    label: isSeed ? 'SEED' : 'CUSTOM',
                                    color: isSeed ? hcTeal : hcBlue,
                                    icon: isSeed ? Icons.download_done_rounded : Icons.edit_rounded,
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.toggle_on_rounded, size: 22),
                                color: isActive ? hcGreen : hcSlate,
                                tooltip: isActive ? 'Deactivate' : 'Activate',
                                onPressed: () => _toggleActive(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                tooltip: 'Edit',
                                onPressed: () => _openEditSheet(context, item: r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                color: hcRed,
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(r),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  void _toggleActive(Map item) async {
    final newActive = item['is_active'] == false;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/${widget.kind}/${item['id']}/', data: {'is_active': newActive});
      ref.invalidate(widget.kind == 'diagnoses' ? _diagnosesProvider : _allergiesProvider);
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(newActive ? 'Activated' : 'Deactivated'),
          backgroundColor: hcGreen,
        ));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Failed to toggle.'), backgroundColor: hcRed));
      }
    }
  }

  void _confirmDelete(Map item) {
    final name = item['name']?.toString() ?? 'this entry';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.warning_rounded, color: hcRed),
          const SizedBox(width: 10),
          const Text('Delete?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Text('Permanently delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: hcRed),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final dio = ref.read(dioProvider);
                await dio.delete('/homecare/${widget.kind}/${item['id']}/');
                ref.invalidate(widget.kind == 'diagnoses' ? _diagnosesProvider : _allergiesProvider);
                if (mounted) {
                  messenger.showSnackBar(const SnackBar(content: Text('Deleted.'), backgroundColor: hcGreen));
                }
              } catch (_) {
                if (mounted) {
                  messenger.showSnackBar(const SnackBar(content: Text('Delete failed.'), backgroundColor: hcRed));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, {Map? item}) {
    final isEdit = item != null;
    final isDiag = widget.kind == 'diagnoses';
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final category = TextEditingController(text: item?['category']?.toString() ?? '');
    final icdCode = TextEditingController(text: item?['icd_code']?.toString() ?? '');
    final description = TextEditingController(text: item?['description']?.toString() ?? '');
    final commonSymptoms = TextEditingController(text: item?['common_symptoms']?.toString() ?? '');
    bool isActive = item?['is_active'] != false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(isDiag ? Icons.medical_information_rounded : Icons.warning_rounded,
                      color: isDiag ? hcTeal : hcAmber, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${isEdit ? 'Edit' : 'New'} ${isDiag ? 'diagnosis' : 'allergy'}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ]),
                const SizedBox(height: 16),
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder())),
                if (isDiag) ...[
                  const SizedBox(height: 10),
                  TextField(
                      controller: icdCode,
                      decoration: const InputDecoration(labelText: 'ICD-10 code', border: OutlineInputBorder())),
                ],
                const SizedBox(height: 10),
                TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                if (!isDiag) ...[
                  const SizedBox(height: 10),
                  TextField(
                      controller: commonSymptoms,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Common symptoms', border: OutlineInputBorder())),
                ],
                const SizedBox(height: 12),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) => setSheetState(() => isActive = v),
                  activeThumbColor: hcTeal,
                  title: const Text('Active'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: hcTeal),
                    onPressed: saving
                        ? null
                        : () async {
                            if (name.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Name is required.')));
                              return;
                            }
                            setSheetState(() => saving = true);
                            try {
                              final dio = ref.read(dioProvider);
                              final payload = {
                                'name': name.text.trim(),
                                'category': category.text.trim(),
                                'description': description.text.trim(),
                                'is_active': isActive,
                                if (isDiag) 'icd_code': icdCode.text.trim(),
                                if (!isDiag) 'common_symptoms': commonSymptoms.text.trim(),
                              };
                              if (isEdit) {
                                await dio.patch('/homecare/${widget.kind}/${item['id']}/', data: payload);
                              } else {
                                await dio.post('/homecare/${widget.kind}/', data: payload);
                              }
                              ref.invalidate(widget.kind == 'diagnoses'
                                  ? _diagnosesProvider
                                  : _allergiesProvider);
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(isEdit ? 'Updated successfully.' : 'Created successfully.'),
                                  backgroundColor: hcGreen,
                                ));
                              }
                            } catch (_) {
                              setSheetState(() => saving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(isEdit ? 'Failed to update.' : 'Could not add (may already exist).'),
                                  backgroundColor: hcRed,
                                ));
                              }
                            }
                          },
                    icon: saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                    label: Text(isEdit ? 'Save changes' : 'Add'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════ INBOX (messaging threads) ═════════════════
final _threadsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/messaging/threads/',
      queryParameters: {'context': 'homecare'});
  final data = res.data;
  return data is List ? data : ((data?['results'] as List?) ?? []);
});

class HomecareInboxScreen extends ConsumerWidget {
  const HomecareInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(_threadsProvider);
    return HcAsyncBody(
      value: threads,
      onRefresh: () async => ref.refresh(_threadsProvider.future),
      builder: (list) {
        final rows = list.cast<Map>();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'COMMUNICATION',
              title: 'Inbox',
              subtitle: 'Message threads with patients & staff',
              icon: Icons.forum_rounded,
              chips: [
                HcHeroChip(
                    icon: Icons.chat_rounded,
                    label: '${rows.length} threads'),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No message threads.')),
              )
            else
              ...rows.map((t) {
                final at = DateTime.tryParse(
                        (t['updated_at'] ?? t['last_message_at'] ?? '')
                            .toString())
                    ?.toLocal();
                final unread = (t['unread_count'] as num?) ?? 0;
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ListTile(
                    onTap: () => _openThread(context, ref, t),
                    leading: HcAvatar(
                        name: (t['title'] ??
                                t['other_party_name'] ??
                                t['subject'] ??
                                '?')
                            .toString(),
                        size: 42,
                        color: unread > 0 ? hcTeal : hcSlate),
                    title: Text(
                        (t['title'] ??
                                t['other_party_name'] ??
                                t['subject'] ??
                                'Thread #${t['id']}')
                            .toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 13.5)),
                    subtitle: Text(
                        (t['last_message'] ?? t['snippet'] ?? '')
                            .toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(at != null ? timeago.format(at) : '',
                            style: const TextStyle(fontSize: 10)),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: hcTeal,
                                borderRadius: BorderRadius.circular(999)),
                            child: Text('$unread',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _openThread(
      BuildContext context, WidgetRef ref, Map thread) async {
    List messages = [];
    try {
      final dio = ref.read(dioProvider);
      final res =
          await dio.get('/messaging/threads/${thread['id']}/messages/');
      final data = res.data;
      messages =
          data is List ? data : ((data?['results'] as List?) ?? []);
    } catch (_) {}
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(
                (thread['title'] ??
                        thread['other_party_name'] ??
                        'Conversation')
                    .toString(),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            const Divider(height: 20),
            Expanded(
              child: messages.isEmpty
                  ? const Center(child: Text('No messages.'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i] as Map;
                        final mine = m['is_mine'] == true ||
                            m['sent_by_me'] == true;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            constraints:
                                const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: mine
                                  ? hcTeal.withValues(alpha: 0.14)
                                  : hcSlate.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      (m['content'] ??
                                              m['body'] ??
                                              m['text'] ??
                                              '')
                                          .toString(),
                                      style: const TextStyle(
                                          fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(hcDateTime(m['created_at']),
                                      style:
                                          const TextStyle(fontSize: 9.5)),
                                ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
