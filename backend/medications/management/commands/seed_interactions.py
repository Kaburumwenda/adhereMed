"""
Seed common drug-drug interactions.

Usage:
    python manage.py seed_interactions
    python manage.py seed_interactions --reset
"""

from django.core.management.base import BaseCommand
from django.db import transaction

from medications.models import DrugInteraction, Medication


# (drug_a_generic_name_fragment, drug_b_generic_name_fragment, severity, description, clinical_advice)
INTERACTION_DATA = [
    # ── Major / Contraindicated ──────────────────────────────────────────
    ("Warfarin", "Aspirin", "major",
     "Increased risk of bleeding due to anticoagulant and antiplatelet synergy.",
     "Avoid combination unless specifically indicated. Monitor INR closely."),
    ("Warfarin", "Ibuprofen", "major",
     "NSAIDs increase bleeding risk and may displace warfarin from protein binding.",
     "Avoid NSAIDs or use short-term with close INR monitoring."),
    ("Warfarin", "Metronidazole", "major",
     "Metronidazole inhibits CYP2C9, increasing warfarin levels and bleeding risk.",
     "Reduce warfarin dose and monitor INR more frequently."),
    ("Methotrexate", "Ibuprofen", "major",
     "NSAIDs reduce renal clearance of methotrexate, risking toxicity.",
     "Avoid concurrent use or monitor methotrexate levels."),
    ("Metformin", "Contrast dye", "major",
     "Risk of lactic acidosis when metformin is used with iodinated contrast.",
     "Hold metformin 48h before and after contrast administration."),
    ("Simvastatin", "Erythromycin", "major",
     "Erythromycin inhibits CYP3A4, greatly increasing statin levels and rhabdomyolysis risk.",
     "Use alternative statin or antibiotic. Avoid combination."),
    ("Ciprofloxacin", "Theophylline", "major",
     "Ciprofloxacin inhibits theophylline metabolism, causing toxicity.",
     "Monitor theophylline levels. Consider alternative quinolone."),
    ("ACE inhibitor", "Potassium", "major",
     "ACE inhibitors reduce aldosterone, and combined with potassium supplements causes hyperkalemia.",
     "Monitor serum potassium regularly. Avoid unnecessary potassium supplementation."),
    ("Digoxin", "Amiodarone", "major",
     "Amiodarone increases digoxin levels by 70-100%, risking toxicity.",
     "Reduce digoxin dose by 50% when starting amiodarone. Monitor levels."),
    ("Lithium", "Ibuprofen", "major",
     "NSAIDs reduce lithium clearance, increasing levels and toxicity risk.",
     "Avoid NSAIDs or monitor lithium levels closely."),

    # ── Moderate ─────────────────────────────────────────────────────────
    ("Amoxicillin", "Methotrexate", "moderate",
     "Penicillins may reduce renal tubular secretion of methotrexate.",
     "Monitor for methotrexate toxicity. Consider dose adjustment."),
    ("Ciprofloxacin", "Antacid", "moderate",
     "Antacids (Al/Mg/Ca) chelate ciprofloxacin, reducing absorption by up to 90%.",
     "Give ciprofloxacin 2h before or 6h after antacids."),
    ("Metformin", "Alcohol", "moderate",
     "Alcohol potentiates metformin's effect on lactate metabolism.",
     "Advise patients to limit alcohol consumption."),
    ("Amlodipine", "Simvastatin", "moderate",
     "Amlodipine inhibits CYP3A4, increasing simvastatin levels.",
     "Limit simvastatin to 20mg/day when used with amlodipine."),
    ("Omeprazole", "Clopidogrel", "moderate",
     "Omeprazole inhibits CYP2C19 activation of clopidogrel, reducing efficacy.",
     "Use pantoprazole instead. Avoid omeprazole with clopidogrel."),
    ("Fluconazole", "Simvastatin", "moderate",
     "Fluconazole inhibits CYP3A4 and CYP2C9, increasing statin exposure.",
     "Suspend statin during short-course fluconazole. Monitor for muscle pain."),
    ("Metronidazole", "Alcohol", "moderate",
     "Disulfiram-like reaction: nausea, vomiting, flushing, tachycardia.",
     "Avoid alcohol during and 48h after metronidazole treatment."),
    ("Prednisolone", "Ibuprofen", "moderate",
     "Increased risk of GI ulceration and bleeding with corticosteroid + NSAID.",
     "Add PPI prophylaxis if combination is necessary."),
    ("Furosemide", "Gentamicin", "moderate",
     "Both are ototoxic and nephrotoxic; combined risk is increased.",
     "Monitor renal function and hearing. Use lowest effective doses."),
    ("Carbamazepine", "Oral contraceptive", "moderate",
     "Carbamazepine induces CYP3A4, reducing contraceptive efficacy.",
     "Use higher-dose OCP or alternative contraception method."),
    ("Phenytoin", "Omeprazole", "moderate",
     "Omeprazole inhibits CYP2C19, potentially increasing phenytoin levels.",
     "Monitor phenytoin levels when starting or stopping omeprazole."),
    ("Atenolol", "Verapamil", "moderate",
     "Additive negative inotropic and chronotropic effects risk heart block.",
     "Monitor heart rate and ECG. Avoid in patients with conduction abnormalities."),
    ("Spironolactone", "ACE inhibitor", "moderate",
     "Dual RAAS blockade increases hyperkalemia risk.",
     "Monitor potassium within 1 week of initiation and regularly thereafter."),
    ("Clarithromycin", "Simvastatin", "major",
     "Clarithromycin strongly inhibits CYP3A4, dramatically increasing statin levels.",
     "Contraindicated. Suspend statin during clarithromycin course."),
    ("Azithromycin", "Amiodarone", "moderate",
     "Both prolong QT interval; combined use increases torsades de pointes risk.",
     "Avoid combination. If unavoidable, monitor ECG closely."),

    # ── Minor ────────────────────────────────────────────────────────────
    ("Paracetamol", "Warfarin", "minor",
     "Regular paracetamol use may slightly increase INR.",
     "Occasional use is safe. Monitor INR with regular/high-dose use."),
    ("Omeprazole", "Iron", "minor",
     "Acid suppression reduces iron absorption.",
     "Take iron supplements with vitamin C or between PPI doses."),
    ("Metformin", "Vitamin B12", "minor",
     "Long-term metformin use reduces B12 absorption.",
     "Monitor B12 levels annually. Supplement if deficient."),
    ("Levothyroxine", "Calcium", "minor",
     "Calcium reduces levothyroxine absorption.",
     "Separate administration by at least 4 hours."),
    ("Levothyroxine", "Iron", "minor",
     "Iron reduces levothyroxine absorption.",
     "Separate administration by at least 4 hours."),
]


class Command(BaseCommand):
    help = "Seed common drug-drug interactions (~30 pairs)"

    def add_arguments(self, parser):
        parser.add_argument(
            "--reset",
            action="store_true",
            help="Delete all existing interactions before seeding.",
        )
        parser.add_argument(
            "--skip-existing",
            action="store_true",
            help="Skip interaction pairs that already exist.",
        )

    @transaction.atomic
    def handle(self, *args, **opts):
        reset = opts["reset"]
        skip_existing = opts["skip_existing"]

        if reset:
            deleted, _ = DrugInteraction.objects.all().delete()
            self.stdout.write(self.style.WARNING(f"Deleted {deleted} existing interactions."))

        created = skipped = not_found = 0

        for drug_a_frag, drug_b_frag, severity, desc, advice in INTERACTION_DATA:
            med_a = Medication.objects.filter(generic_name__icontains=drug_a_frag).first()
            med_b = Medication.objects.filter(generic_name__icontains=drug_b_frag).first()

            if not med_a or not med_b:
                not_found += 1
                self.stdout.write(
                    self.style.NOTICE(f"  Skipped: {drug_a_frag} ↔ {drug_b_frag} (medication not found)")
                )
                continue

            # Check both orderings
            exists = DrugInteraction.objects.filter(
                drug_a=med_a, drug_b=med_b
            ).exists() or DrugInteraction.objects.filter(
                drug_a=med_b, drug_b=med_a
            ).exists()

            if exists:
                if skip_existing:
                    skipped += 1
                    continue
                # Update existing
                interaction = DrugInteraction.objects.filter(
                    drug_a=med_a, drug_b=med_b
                ).first() or DrugInteraction.objects.filter(
                    drug_a=med_b, drug_b=med_a
                ).first()
                interaction.severity = severity
                interaction.description = desc
                interaction.clinical_advice = advice
                interaction.source = "AdhereMed seed data"
                interaction.save()
                skipped += 1
                continue

            DrugInteraction.objects.create(
                drug_a=med_a,
                drug_b=med_b,
                severity=severity,
                description=desc,
                clinical_advice=advice,
                source="AdhereMed seed data",
            )
            created += 1

        self.stdout.write(self.style.SUCCESS(
            f"Done: {created} created, {skipped} skipped, {not_found} not found (seed medications first)."
        ))
