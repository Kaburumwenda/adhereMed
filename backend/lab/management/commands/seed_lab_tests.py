from django.core.management.base import BaseCommand
from lab.models import LabTestCatalog


TESTS = [
    # ── Hematology ──
    {"name": "Complete Blood Count (CBC)", "code": "CBC", "department": "Hematology", "specimen_type": "Blood (EDTA)", "price": 500, "turnaround_time": "2 hours", "reference_ranges": {"WBC": "4.0-11.0 x10^9/L", "RBC": "4.5-5.5 x10^12/L", "Hemoglobin": "12-17 g/dL", "Hematocrit": "36-54%", "Platelets": "150-400 x10^9/L"}},
    {"name": "Full Hemogram", "code": "FHG", "department": "Hematology", "specimen_type": "Blood (EDTA)", "price": 800, "turnaround_time": "2 hours", "reference_ranges": {"WBC": "4.0-11.0 x10^9/L", "RBC": "4.5-5.5 x10^12/L", "Hemoglobin": "12-17 g/dL", "MCV": "80-100 fL", "MCH": "27-33 pg"}},
    {"name": "Erythrocyte Sedimentation Rate (ESR)", "code": "ESR", "department": "Hematology", "specimen_type": "Blood (EDTA)", "price": 300, "turnaround_time": "1 hour", "reference_ranges": {"Male": "0-15 mm/hr", "Female": "0-20 mm/hr"}},
    {"name": "Peripheral Blood Smear", "code": "PBS", "department": "Hematology", "specimen_type": "Blood (EDTA)", "price": 400, "turnaround_time": "3 hours", "reference_ranges": {}},
    {"name": "Reticulocyte Count", "code": "RETIC", "department": "Hematology", "specimen_type": "Blood (EDTA)", "price": 500, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "0.5-2.5%"}},
    {"name": "Coagulation Screen (PT/INR/APTT)", "code": "COAG", "department": "Hematology", "specimen_type": "Blood (Citrate)", "price": 1200, "turnaround_time": "3 hours", "reference_ranges": {"PT": "11-15 sec", "INR": "0.8-1.2", "APTT": "25-35 sec"}},
    {"name": "D-Dimer", "code": "DDIMER", "department": "Hematology", "specimen_type": "Blood (Citrate)", "price": 2000, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "<0.5 mg/L"}},
    {"name": "Blood Grouping & Rh", "code": "BG", "department": "Hematology", "specimen_type": "Blood (EDTA)", "price": 300, "turnaround_time": "30 minutes", "reference_ranges": {}},
    {"name": "Cross Match", "code": "XMATCH", "department": "Hematology", "specimen_type": "Blood (EDTA)", "price": 500, "turnaround_time": "1 hour", "reference_ranges": {}},
    {"name": "Sickling Test", "code": "SICKLE", "department": "Hematology", "specimen_type": "Blood (EDTA)", "price": 400, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "Negative"}},

    # ── Clinical Chemistry / Biochemistry ──
    {"name": "Random Blood Sugar (RBS)", "code": "RBS", "department": "Biochemistry", "specimen_type": "Blood (Fluoride)", "price": 200, "turnaround_time": "30 minutes", "reference_ranges": {"Normal": "3.9-7.8 mmol/L"}},
    {"name": "Fasting Blood Sugar (FBS)", "code": "FBS", "department": "Biochemistry", "specimen_type": "Blood (Fluoride)", "price": 200, "turnaround_time": "30 minutes", "reference_ranges": {"Normal": "3.9-5.6 mmol/L", "Pre-diabetic": "5.6-6.9 mmol/L", "Diabetic": ">=7.0 mmol/L"}, "instructions": "Patient must fast for 8-12 hours"},
    {"name": "HbA1c (Glycated Hemoglobin)", "code": "HBA1C", "department": "Biochemistry", "specimen_type": "Blood (EDTA)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "<5.7%", "Pre-diabetic": "5.7-6.4%", "Diabetic": ">=6.5%"}},
    {"name": "Oral Glucose Tolerance Test (OGTT)", "code": "OGTT", "department": "Biochemistry", "specimen_type": "Blood (Fluoride)", "price": 800, "turnaround_time": "3 hours", "reference_ranges": {"Normal_2hr": "<7.8 mmol/L", "Impaired": "7.8-11.0 mmol/L", "Diabetic": ">=11.1 mmol/L"}, "instructions": "75g glucose load after fasting"},
    {"name": "Renal Function Tests (RFT/UEC)", "code": "RFT", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 1000, "turnaround_time": "3 hours", "reference_ranges": {"Urea": "2.5-6.7 mmol/L", "Creatinine": "62-106 umol/L", "Sodium": "136-145 mmol/L", "Potassium": "3.5-5.1 mmol/L", "Chloride": "98-106 mmol/L"}},
    {"name": "Liver Function Tests (LFT)", "code": "LFT", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 1200, "turnaround_time": "3 hours", "reference_ranges": {"ALT": "7-56 U/L", "AST": "10-40 U/L", "ALP": "44-147 U/L", "GGT": "0-65 U/L", "Total Bilirubin": "3-21 umol/L", "Direct Bilirubin": "0-5 umol/L", "Total Protein": "60-80 g/L", "Albumin": "35-50 g/L"}},
    {"name": "Lipid Profile", "code": "LIPID", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 1000, "turnaround_time": "3 hours", "reference_ranges": {"Total Cholesterol": "<5.2 mmol/L", "Triglycerides": "<1.7 mmol/L", "HDL": ">1.0 mmol/L", "LDL": "<3.4 mmol/L"}, "instructions": "Patient should fast for 12 hours"},
    {"name": "Uric Acid", "code": "URIC", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 500, "turnaround_time": "2 hours", "reference_ranges": {"Male": "210-420 umol/L", "Female": "150-360 umol/L"}},
    {"name": "Serum Calcium", "code": "CA", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 500, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "2.15-2.55 mmol/L"}},
    {"name": "Serum Phosphate", "code": "PHOS", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 500, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "0.8-1.5 mmol/L"}},
    {"name": "Serum Magnesium", "code": "MG", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 500, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "0.7-1.0 mmol/L"}},
    {"name": "Serum Iron & TIBC", "code": "IRON", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 1000, "turnaround_time": "4 hours", "reference_ranges": {"Serum Iron": "10-30 umol/L", "TIBC": "45-72 umol/L"}},
    {"name": "Serum Ferritin", "code": "FERR", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Male": "30-400 ng/mL", "Female": "15-150 ng/mL"}},
    {"name": "Cardiac Enzymes (CK-MB, Troponin)", "code": "CARDIAC", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 2500, "turnaround_time": "2 hours", "reference_ranges": {"CK-MB": "<25 U/L", "Troponin I": "<0.04 ng/mL"}},
    {"name": "Amylase", "code": "AMYL", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 800, "turnaround_time": "3 hours", "reference_ranges": {"Normal": "28-100 U/L"}},
    {"name": "Lipase", "code": "LIPASE", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 800, "turnaround_time": "3 hours", "reference_ranges": {"Normal": "0-160 U/L"}},
    {"name": "C-Reactive Protein (CRP)", "code": "CRP", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 800, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "<10 mg/L"}},
    {"name": "Procalcitonin", "code": "PCT", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 3000, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "<0.1 ng/mL", "Sepsis_likely": ">2.0 ng/mL"}},

    # ── Thyroid ──
    {"name": "Thyroid Function Tests (TFT)", "code": "TFT", "department": "Endocrinology", "specimen_type": "Blood (Plain)", "price": 2000, "turnaround_time": "4 hours", "reference_ranges": {"TSH": "0.27-4.2 mIU/L", "Free T4": "12-22 pmol/L", "Free T3": "3.1-6.8 pmol/L"}},
    {"name": "TSH", "code": "TSH", "department": "Endocrinology", "specimen_type": "Blood (Plain)", "price": 800, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "0.27-4.2 mIU/L"}},

    # ── Hormones ──
    {"name": "Prostate Specific Antigen (PSA)", "code": "PSA", "department": "Endocrinology", "specimen_type": "Blood (Plain)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "<4.0 ng/mL"}},
    {"name": "Beta-hCG (Pregnancy Test - Serum)", "code": "BHCG", "department": "Endocrinology", "specimen_type": "Blood (Plain)", "price": 800, "turnaround_time": "2 hours", "reference_ranges": {"Non-pregnant": "<5 mIU/mL"}},
    {"name": "Prolactin", "code": "PRL", "department": "Endocrinology", "specimen_type": "Blood (Plain)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Male": "4-15 ng/mL", "Female": "4-23 ng/mL"}},
    {"name": "Cortisol (Morning)", "code": "CORT", "department": "Endocrinology", "specimen_type": "Blood (Plain)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Morning": "185-624 nmol/L"}, "instructions": "Collect between 7-9 AM"},
    {"name": "Testosterone", "code": "TESTO", "department": "Endocrinology", "specimen_type": "Blood (Plain)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Male": "8.64-29 nmol/L", "Female": "0.35-2.6 nmol/L"}},
    {"name": "Vitamin D (25-OH)", "code": "VITD", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 2000, "turnaround_time": "6 hours", "reference_ranges": {"Deficient": "<30 nmol/L", "Insufficient": "30-50 nmol/L", "Sufficient": "50-125 nmol/L"}},
    {"name": "Vitamin B12", "code": "B12", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "200-900 pg/mL"}},
    {"name": "Folate", "code": "FOLATE", "department": "Biochemistry", "specimen_type": "Blood (Plain)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "3-20 ng/mL"}},

    # ── Urinalysis ──
    {"name": "Urinalysis", "code": "UA", "department": "Urinalysis", "specimen_type": "Urine (Mid-stream)", "price": 300, "turnaround_time": "1 hour", "reference_ranges": {"pH": "4.5-8.0", "Specific Gravity": "1.005-1.030"}, "instructions": "Mid-stream clean-catch urine"},
    {"name": "Urine Culture & Sensitivity", "code": "UCS", "department": "Microbiology", "specimen_type": "Urine (Mid-stream)", "price": 1000, "turnaround_time": "48 hours", "reference_ranges": {"Normal": "<10^4 CFU/mL"}, "instructions": "Collect before starting antibiotics"},
    {"name": "24-Hour Urine Protein", "code": "24UP", "department": "Biochemistry", "specimen_type": "Urine (24-hour)", "price": 800, "turnaround_time": "24 hours", "reference_ranges": {"Normal": "<150 mg/day"}, "instructions": "Collect all urine for 24 hours"},
    {"name": "Urine Pregnancy Test", "code": "UPT", "department": "Urinalysis", "specimen_type": "Urine", "price": 200, "turnaround_time": "15 minutes", "reference_ranges": {}},

    # ── Microbiology ──
    {"name": "Blood Culture & Sensitivity", "code": "BCS", "department": "Microbiology", "specimen_type": "Blood (Aerobic/Anaerobic bottles)", "price": 2000, "turnaround_time": "72 hours", "reference_ranges": {"Normal": "No growth"}, "instructions": "Collect during febrile episodes, before antibiotics"},
    {"name": "Stool Culture & Sensitivity", "code": "SCS", "department": "Microbiology", "specimen_type": "Stool", "price": 1000, "turnaround_time": "48 hours", "reference_ranges": {}},
    {"name": "Stool Microscopy (Ova & Cysts)", "code": "STOOL", "department": "Microbiology", "specimen_type": "Stool", "price": 300, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "No ova/cysts seen"}},
    {"name": "Stool Occult Blood", "code": "FOBT", "department": "Microbiology", "specimen_type": "Stool", "price": 400, "turnaround_time": "1 hour", "reference_ranges": {"Normal": "Negative"}},
    {"name": "Wound Swab Culture & Sensitivity", "code": "WCS", "department": "Microbiology", "specimen_type": "Wound swab", "price": 1000, "turnaround_time": "48 hours", "reference_ranges": {}},
    {"name": "Throat Swab Culture", "code": "TCS", "department": "Microbiology", "specimen_type": "Throat swab", "price": 800, "turnaround_time": "48 hours", "reference_ranges": {}},
    {"name": "Sputum Culture & Sensitivity", "code": "SPUTCS", "department": "Microbiology", "specimen_type": "Sputum", "price": 1000, "turnaround_time": "48 hours", "reference_ranges": {}},
    {"name": "Sputum AFB (TB Smear)", "code": "AFB", "department": "Microbiology", "specimen_type": "Sputum", "price": 500, "turnaround_time": "24 hours", "reference_ranges": {"Normal": "Negative"}, "instructions": "Early morning sputum x3"},
    {"name": "GeneXpert (TB PCR)", "code": "GENEX", "department": "Microbiology", "specimen_type": "Sputum", "price": 3000, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "Not detected"}},
    {"name": "H. pylori Antigen (Stool)", "code": "HPYLORI", "department": "Microbiology", "specimen_type": "Stool", "price": 1000, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "Negative"}},
    {"name": "High Vaginal Swab (HVS)", "code": "HVS", "department": "Microbiology", "specimen_type": "Vaginal swab", "price": 800, "turnaround_time": "48 hours", "reference_ranges": {}},

    # ── Serology / Immunology ──
    {"name": "HIV 1&2 Antibody Test", "code": "HIV", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 300, "turnaround_time": "30 minutes", "reference_ranges": {"Normal": "Non-reactive"}},
    {"name": "HIV Viral Load", "code": "HIVVL", "department": "Serology", "specimen_type": "Blood (EDTA)", "price": 3000, "turnaround_time": "7 days", "reference_ranges": {"Undetectable": "<50 copies/mL"}},
    {"name": "CD4 Count", "code": "CD4", "department": "Serology", "specimen_type": "Blood (EDTA)", "price": 1500, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "500-1500 cells/uL"}},
    {"name": "Hepatitis B Surface Antigen (HBsAg)", "code": "HBSAG", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 500, "turnaround_time": "30 minutes", "reference_ranges": {"Normal": "Non-reactive"}},
    {"name": "Hepatitis B Panel", "code": "HBPANEL", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 2500, "turnaround_time": "4 hours", "reference_ranges": {}},
    {"name": "Hepatitis C Antibody", "code": "HCV", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 800, "turnaround_time": "1 hour", "reference_ranges": {"Normal": "Non-reactive"}},
    {"name": "VDRL/RPR (Syphilis Screen)", "code": "VDRL", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 300, "turnaround_time": "1 hour", "reference_ranges": {"Normal": "Non-reactive"}},
    {"name": "TPHA (Syphilis Confirmatory)", "code": "TPHA", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 500, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "Non-reactive"}},
    {"name": "Widal Test (Typhoid)", "code": "WIDAL", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 500, "turnaround_time": "1 hour", "reference_ranges": {"Normal": "<1:80"}},
    {"name": "Brucella Antibodies", "code": "BRUC", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 800, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "Negative"}},
    {"name": "Rheumatoid Factor (RF)", "code": "RF", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 600, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "<14 IU/mL"}},
    {"name": "Anti-Streptolysin O (ASO)", "code": "ASO", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 600, "turnaround_time": "2 hours", "reference_ranges": {"Normal": "<200 IU/mL"}},
    {"name": "ANA (Antinuclear Antibody)", "code": "ANA", "department": "Serology", "specimen_type": "Blood (Plain)", "price": 2000, "turnaround_time": "4 hours", "reference_ranges": {"Normal": "Negative"}},

    # ── Malaria ──
    {"name": "Malaria Rapid Test (mRDT)", "code": "MRDT", "department": "Parasitology", "specimen_type": "Blood (Finger prick)", "price": 200, "turnaround_time": "15 minutes", "reference_ranges": {"Normal": "Negative"}},
    {"name": "Malaria Blood Smear (BS for MPS)", "code": "MPS", "department": "Parasitology", "specimen_type": "Blood (EDTA)", "price": 300, "turnaround_time": "1 hour", "reference_ranges": {"Normal": "No parasites seen"}},

    # ── CSF ──
    {"name": "CSF Analysis", "code": "CSF", "department": "Biochemistry", "specimen_type": "Cerebrospinal Fluid", "price": 2000, "turnaround_time": "4 hours", "reference_ranges": {"Protein": "15-45 mg/dL", "Glucose": "2.5-4.5 mmol/L", "WBC": "0-5 cells/uL"}},

    # ── Tumor Markers ──
    {"name": "CA-125", "code": "CA125", "department": "Oncology", "specimen_type": "Blood (Plain)", "price": 2500, "turnaround_time": "6 hours", "reference_ranges": {"Normal": "<35 U/mL"}},
    {"name": "CEA (Carcinoembryonic Antigen)", "code": "CEA", "department": "Oncology", "specimen_type": "Blood (Plain)", "price": 2000, "turnaround_time": "6 hours", "reference_ranges": {"Normal": "<5 ng/mL"}},
    {"name": "AFP (Alpha-fetoprotein)", "code": "AFP", "department": "Oncology", "specimen_type": "Blood (Plain)", "price": 2000, "turnaround_time": "6 hours", "reference_ranges": {"Normal": "<10 ng/mL"}},
]


class Command(BaseCommand):
    help = 'Seed the lab test catalog with common tests'

    def handle(self, *args, **options):
        created = 0
        skipped = 0
        for t in TESTS:
            _, was_created = LabTestCatalog.objects.get_or_create(
                code=t['code'],
                defaults={
                    'name': t['name'],
                    'department': t.get('department', ''),
                    'specimen_type': t.get('specimen_type', ''),
                    'reference_ranges': t.get('reference_ranges', {}),
                    'price': t.get('price', 0),
                    'turnaround_time': t.get('turnaround_time', ''),
                    'instructions': t.get('instructions', ''),
                    'is_active': True,
                },
            )
            if was_created:
                created += 1
            else:
                skipped += 1
        self.stdout.write(self.style.SUCCESS(
            f'Done: {created} tests created, {skipped} already existed.'
        ))
