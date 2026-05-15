"""
Seed common radiology exam panels (bundles).
Requires ExamCatalog to be seeded first (seed_exam_catalog).

Usage:  python manage.py tenant_command seed_exam_panels --schema=<schema>
        python manage.py tenant_command seed_exam_panels --schema=<schema> --clear
"""
from decimal import Decimal
from django.core.management.base import BaseCommand
from radiology.models import ExamCatalog, ExamPanel


PANELS = [
    # ── Emergency / Trauma ────────────────────────────────────────────
    {
        "name": "Trauma – Full Body Screen",
        "description": "Complete trauma workup: CT head, C-spine, chest, abdomen & pelvis with contrast.",
        "exam_codes": ["CT-HEAD", "CT-CSPINE", "CT-CHEST-C", "CT-ABD-PELVIS"],
        "price": 28000,
    },
    {
        "name": "Trauma – Extremity Panel",
        "description": "AP/lateral X-rays of commonly injured extremities after blunt trauma.",
        "exam_codes": ["XR-SHOULDER-R", "XR-SHOULDER-L", "XR-PELVIS", "XR-KNEE-R", "XR-KNEE-L"],
        "price": 7000,
    },
    {
        "name": "Acute Abdomen Panel",
        "description": "Standard workup for acute abdominal pain: erect & supine abdomen X-Ray plus abdominal ultrasound.",
        "exam_codes": ["XR-ABDOMEN", "US-ABDOMEN"],
        "price": 4500,
    },

    # ── Chest / Pulmonary ─────────────────────────────────────────────
    {
        "name": "Chest Complete Panel",
        "description": "PA, lateral and AP chest X-Rays for comprehensive lung evaluation.",
        "exam_codes": ["XR-CHEST-PA", "XR-CHEST-LAT"],
        "price": 2500,
    },
    {
        "name": "Pulmonary Embolism Workup",
        "description": "CT pulmonary angiography for suspected PE.",
        "exam_codes": ["CT-CHEST-C", "XR-CHEST-PA"],
        "price": 12000,
    },

    # ── Cardiac ───────────────────────────────────────────────────────
    {
        "name": "Cardiac Workup Panel",
        "description": "Chest X-Ray and echocardiogram for cardiac evaluation.",
        "exam_codes": ["XR-CHEST-PA", "US-ABDOMEN"],
        "price": 7000,
    },

    # ── Neurological ──────────────────────────────────────────────────
    {
        "name": "Stroke Protocol Panel",
        "description": "Urgent CT head without contrast plus CT angiography head & neck for acute stroke.",
        "exam_codes": ["CT-HEAD", "CT-ANGIO-NECK"],
        "price": 16000,
    },
    {
        "name": "Brain MRI Complete",
        "description": "MRI brain with and without contrast for comprehensive neurological evaluation.",
        "exam_codes": ["MRI-BRAIN", "MRI-BRAIN-C"],
        "price": 18000,
    },
    {
        "name": "Headache Workup Panel",
        "description": "CT head and C-spine for headache evaluation with possible cervicogenic component.",
        "exam_codes": ["CT-HEAD", "XR-CSPINE"],
        "price": 10000,
    },

    # ── Spine ─────────────────────────────────────────────────────────
    {
        "name": "Full Spine X-Ray Panel",
        "description": "Complete spinal X-Ray series: cervical, thoracic, and lumbar spine.",
        "exam_codes": ["XR-CSPINE", "XR-TSPINE", "XR-LSPINE"],
        "price": 5500,
    },
    {
        "name": "Lumbar Spine Workup",
        "description": "Lumbar X-Ray plus MRI lumbar spine for lower back pain evaluation.",
        "exam_codes": ["XR-LSPINE", "MRI-LSPINE"],
        "price": 14000,
    },
    {
        "name": "Cervical Spine Workup",
        "description": "Cervical X-Ray plus MRI cervical spine for neck pain evaluation.",
        "exam_codes": ["XR-CSPINE", "MRI-CSPINE"],
        "price": 14000,
    },

    # ── Musculoskeletal ───────────────────────────────────────────────
    {
        "name": "Knee Complete Panel",
        "description": "Bilateral knee X-Rays plus MRI of the affected knee.",
        "exam_codes": ["XR-KNEE-R", "XR-KNEE-L", "MRI-KNEE-R"],
        "price": 13000,
    },
    {
        "name": "Shoulder Complete Panel",
        "description": "Shoulder X-Ray plus MRI shoulder for rotator cuff evaluation.",
        "exam_codes": ["XR-SHOULDER-R", "MRI-SHOULDER-R"],
        "price": 13000,
    },
    {
        "name": "Hip & Pelvis Panel",
        "description": "Pelvis AP plus bilateral hip X-Rays.",
        "exam_codes": ["XR-PELVIS", "XR-HIP-R", "XR-HIP-L"],
        "price": 4500,
    },
    {
        "name": "Bone Density Screening",
        "description": "DEXA scan of hip and lumbar spine for osteoporosis screening.",
        "exam_codes": ["DEXA-HIP", "DEXA-SPINE"],
        "price": 5000,
    },

    # ── Abdominal / GI ────────────────────────────────────────────────
    {
        "name": "Abdominal CT Complete",
        "description": "CT abdomen & pelvis for comprehensive abdominal evaluation.",
        "exam_codes": ["CT-ABD-PELVIS"],
        "price": 10000,
    },
    {
        "name": "Liver & Biliary Panel",
        "description": "Abdominal ultrasound focused on liver, gallbladder and biliary tree.",
        "exam_codes": ["US-ABDOMEN", "US-LIVER"],
        "price": 5500,
    },
    {
        "name": "Renal Workup Panel",
        "description": "KUB X-Ray plus renal ultrasound for kidney evaluation.",
        "exam_codes": ["XR-KUB", "US-RENAL"],
        "price": 4500,
    },
    {
        "name": "Upper GI Series",
        "description": "Fluoroscopic barium swallow study for oesophageal & gastric evaluation.",
        "exam_codes": ["FL-BARIUM-SWALLOW"],
        "price": 4000,
    },

    # ── Obstetric / Gynecological ─────────────────────────────────────
    {
        "name": "Obstetric Screening Panel",
        "description": "Standard obstetric ultrasound with Doppler assessment.",
        "exam_codes": ["US-OBS-2ND", "US-OBS-3RD"],
        "price": 5000,
    },
    {
        "name": "Pelvic Assessment Panel",
        "description": "Pelvic ultrasound (transabdominal) for gynaecological evaluation.",
        "exam_codes": ["US-PELVIS-F"],
        "price": 3500,
    },

    # ── Breast ────────────────────────────────────────────────────────
    {
        "name": "Breast Screening Panel",
        "description": "Bilateral screening mammography plus breast ultrasound.",
        "exam_codes": ["MAM-SCREEN", "US-BREAST-BI"],
        "price": 6000,
    },
    {
        "name": "Breast Diagnostic Panel",
        "description": "Diagnostic mammography plus breast ultrasound for palpable lump workup.",
        "exam_codes": ["MAM-DIAG", "US-BREAST-BI"],
        "price": 7000,
    },

    # ── Vascular ──────────────────────────────────────────────────────
    {
        "name": "Carotid Doppler Panel",
        "description": "Bilateral carotid ultrasound with Doppler for stroke risk assessment.",
        "exam_codes": ["US-CAROTID"],
        "price": 5000,
    },
    {
        "name": "Lower Limb Venous Doppler",
        "description": "Bilateral lower limb venous Doppler for DVT assessment.",
        "exam_codes": ["US-VENOUS-LE"],
        "price": 5500,
    },

    # ── Oncology / Staging ────────────────────────────────────────────
    {
        "name": "Cancer Staging – Chest/Abdomen/Pelvis CT",
        "description": "CT chest, abdomen and pelvis with contrast for oncology staging.",
        "exam_codes": ["CT-CHEST-C", "CT-ABD-PELVIS"],
        "price": 20000,
    },
    {
        "name": "PET-CT Whole Body",
        "description": "FDG PET-CT whole body scan for cancer staging or surveillance.",
        "exam_codes": ["PET-FDG-WB"],
        "price": 55000,
    },
    {
        "name": "Brain Metastasis Screen",
        "description": "MRI brain with contrast for metastatic disease screening.",
        "exam_codes": ["MRI-BRAIN-C"],
        "price": 12000,
    },

    # ── Paediatric ────────────────────────────────────────────────────
    {
        "name": "Paediatric Chest Panel",
        "description": "AP chest X-Ray for paediatric chest evaluation.",
        "exam_codes": ["XR-CHEST-AP"],
        "price": 1200,
    },
    {
        "name": "Paediatric Hip Screening",
        "description": "Hip ultrasound for developmental dysplasia of the hip (DDH).",
        "exam_codes": ["US-MSK-SHOULDER"],
        "price": 3500,
    },

    # ── Pre-operative ─────────────────────────────────────────────────
    {
        "name": "Pre-Op Chest Panel",
        "description": "Standard pre-operative chest X-Ray (PA view).",
        "exam_codes": ["XR-CHEST-PA"],
        "price": 1300,
    },

    # ── Interventional ────────────────────────────────────────────────
    {
        "name": "CT-Guided Biopsy Panel",
        "description": "CT-guided percutaneous biopsy with follow-up imaging.",
        "exam_codes": ["IR-CT-BIOPSY"],
        "price": 25000,
    },
]


class Command(BaseCommand):
    help = 'Seed common radiology exam panels (requires exam catalog to exist)'

    def add_arguments(self, parser):
        parser.add_argument('--clear', '--reset', action='store_true', help='Delete all panels before seeding')

    def handle(self, *args, **options):
        if options['clear']:
            deleted, _ = ExamPanel.objects.all().delete()
            self.stdout.write(f'Cleared {deleted} existing panel records.')

        # Build a code→id lookup from existing catalog
        code_map = dict(ExamCatalog.objects.values_list('code', 'id'))
        if not code_map:
            self.stderr.write(self.style.ERROR(
                'ExamCatalog is empty. Run seed_exam_catalog first.'
            ))
            return

        created = 0
        skipped = 0
        missing_codes = set()

        for entry in PANELS:
            # Resolve exam codes to IDs
            exam_ids = []
            for code in entry['exam_codes']:
                eid = code_map.get(code)
                if eid:
                    exam_ids.append(eid)
                else:
                    missing_codes.add(code)

            if not exam_ids:
                skipped += 1
                continue

            panel, was_created = ExamPanel.objects.get_or_create(
                name=entry['name'],
                defaults={
                    'description': entry.get('description', ''),
                    'price': Decimal(str(entry['price'])),
                    'is_active': True,
                },
            )
            if was_created:
                panel.exams.set(exam_ids)
                created += 1
            else:
                skipped += 1

        if missing_codes:
            self.stdout.write(self.style.WARNING(
                f'Warning: {len(missing_codes)} exam code(s) not found in catalog: {", ".join(sorted(missing_codes))}'
            ))

        total = ExamPanel.objects.count()
        self.stdout.write(self.style.SUCCESS(
            f'Done — {created} panels created, {skipped} skipped (already exist). Total panels: {total}'
        ))
