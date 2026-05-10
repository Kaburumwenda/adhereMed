"""LOINC code mapping for homecare vital signs and common observations.

Minimal subset — extend as needed. Keys are the JSON field names we
already store in `CaregiverNote.vitals`.
"""
from __future__ import annotations

LOINC_VITALS: dict[str, dict] = {
    'bp':       {'code': '85354-9', 'display': 'Blood pressure panel',          'unit': 'mmHg'},
    'systolic': {'code': '8480-6',  'display': 'Systolic blood pressure',       'unit': 'mmHg'},
    'diastolic':{'code': '8462-4',  'display': 'Diastolic blood pressure',      'unit': 'mmHg'},
    'hr':       {'code': '8867-4',  'display': 'Heart rate',                    'unit': 'bpm'},
    'pulse':    {'code': '8867-4',  'display': 'Heart rate',                    'unit': 'bpm'},
    'rr':       {'code': '9279-1',  'display': 'Respiratory rate',              'unit': '/min'},
    'temp':     {'code': '8310-5',  'display': 'Body temperature',              'unit': 'Cel'},
    'spo2':     {'code': '59408-5', 'display': 'Oxygen saturation',             'unit': '%'},
    'glucose':  {'code': '15074-8', 'display': 'Glucose [Moles/volume] in Blood','unit': 'mmol/L'},
    'weight':   {'code': '29463-7', 'display': 'Body weight',                   'unit': 'kg'},
    'height':   {'code': '8302-2',  'display': 'Body height',                   'unit': 'cm'},
    'bmi':      {'code': '39156-5', 'display': 'Body mass index',               'unit': 'kg/m2'},
    'pain':     {'code': '72514-3', 'display': 'Pain severity',                 'unit': '{score}'},
}


def vital_unit(key: str) -> str:
    return (LOINC_VITALS.get(key) or {}).get('unit', '')


def vital_display(key: str) -> str:
    return (LOINC_VITALS.get(key) or {}).get('display', key)
