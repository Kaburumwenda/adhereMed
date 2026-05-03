"""
Pharmacy stock seed command.

Seeds MedicationStock for the current tenant with 150+ common medications,
default selling/cost prices, units, categories, and reorder levels.

Usage (single tenant):
    python manage.py tenant_command seed_pharmacy_stock --schema=<schema_name>

Usage (all tenants):
    python manage.py all_tenants_command seed_pharmacy_stock

Flags:
    --skip-existing   Skip items that already exist (default: update prices if already present)
    --reset           Delete all existing stock and reseed from scratch (use with care)
"""

from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

import random

from inventory.models import Category, MedicationStock, StockBatch, Unit


# ---------------------------------------------------------------------------
# Pricing / quantity helpers
# Each item: (generic_name + form label, category_name, unit_name,
#             selling_price, cost_price, reorder_level, reorder_qty, location)
# Prices in local currency (KES by default — pharmacists can adjust after seed)
# ---------------------------------------------------------------------------

CATEGORY_DEFS = [
    "Analgesic / Pain Reliever",
    "Antibiotic",
    "Antifungal",
    "Antiviral",
    "Antiparasitic",
    "Antimalarial",
    "Antihypertensive",
    "Antidiabetic",
    "Antihistamine",
    "Antacid / GI",
    "Cardiovascular",
    "Respiratory",
    "Central Nervous System",
    "Hormonal",
    "Vitamin / Supplement",
    "Vaccine",
    "Dermatological",
    "Ophthalmic",
    "Emergency / IV Fluids",
    "Other",
]

UNIT_DEFS = [
    ("Tablets",    "tab"),
    ("Capsules",   "cap"),
    ("Syrup",      "btl"),
    ("Injection",  "vial"),
    ("Cream/Gel",  "tube"),
    ("Drops",      "bot"),
    ("Inhaler",    "inh"),
    ("Suppository","supp"),
    ("Suspension", "btl"),
    ("Powder",     "sachet"),
    ("Solution",   "btl"),
    ("Patch",      "patch"),
]

# fmt: off
# Columns: medication_name, category_name, unit_name,
#          selling_price, cost_price, reorder_level, reorder_qty
STOCK_DATA = [
    # ── Analgesics / NSAIDs ──────────────────────────────────────────────
    ("Paracetamol 500mg Tablet",          "Analgesic / Pain Reliever",  "Tablets",    10,    5,  200, 1000),
    ("Paracetamol 120mg/5ml Syrup",       "Analgesic / Pain Reliever",  "Syrup",      85,   40,   50,  200),
    ("Ibuprofen 400mg Tablet",            "Analgesic / Pain Reliever",  "Tablets",    15,    7,  150,  500),
    ("Ibuprofen 100mg/5ml Suspension",    "Analgesic / Pain Reliever",  "Suspension", 90,   45,   30,  100),
    ("Diclofenac 50mg Tablet",            "Analgesic / Pain Reliever",  "Tablets",    18,    8,  100,  400),
    ("Diclofenac 1% Gel",                 "Analgesic / Pain Reliever",  "Cream/Gel",  250,  120,  20,   80),
    ("Aspirin 300mg Tablet",              "Analgesic / Pain Reliever",  "Tablets",     8,    3,  100,  500),
    ("Aspirin 75mg Tablet (Cardio)",      "Cardiovascular",             "Tablets",    12,    5,   80,  400),
    ("Tramadol 50mg Capsule",             "Analgesic / Pain Reliever",  "Capsules",   50,   25,   50,  200),
    ("Morphine Sulfate 10mg Tablet",      "Analgesic / Pain Reliever",  "Tablets",   150,   80,   20,   50),
    ("Codeine 30mg Tablet",               "Analgesic / Pain Reliever",  "Tablets",    60,   30,   30,  100),
    ("Lidocaine 2% Injection",            "Analgesic / Pain Reliever",  "Injection",  180,   90,   20,   60),
    ("Mefenamic Acid 500mg Capsule",      "Analgesic / Pain Reliever",  "Capsules",   25,   12,   80,  300),

    # ── Antibiotics ─────────────────────────────────────────────────────
    ("Amoxicillin 500mg Capsule",         "Antibiotic",  "Capsules",   30,   14,  150,  600),
    ("Amoxicillin 250mg/5ml Suspension",  "Antibiotic",  "Suspension", 120,   60,   40,  150),
    ("Amoxicillin/Clavulanate 625mg Tab", "Antibiotic",  "Tablets",    80,   40,   80,  300),
    ("Azithromycin 500mg Tablet",         "Antibiotic",  "Tablets",    75,   38,   80,  300),
    ("Azithromycin 200mg/5ml Suspension", "Antibiotic",  "Suspension", 250,  125,   20,   60),
    ("Ciprofloxacin 500mg Tablet",        "Antibiotic",  "Tablets",    45,   22,  100,  400),
    ("Ciprofloxacin 200mg/100ml IV",      "Antibiotic",  "Injection",  350,  175,   20,   60),
    ("Metronidazole 400mg Tablet",        "Antibiotic",  "Tablets",    20,    9,  120,  500),
    ("Metronidazole 500mg/100ml IV",      "Antibiotic",  "Injection",  400,  200,   15,   50),
    ("Doxycycline 100mg Capsule",         "Antibiotic",  "Capsules",   25,   12,   80,  300),
    ("Ceftriaxone 1g Injection",          "Antibiotic",  "Injection",  350,  175,   30,  100),
    ("Ceftriaxone 250mg Injection",       "Antibiotic",  "Injection",  220,  110,   20,   80),
    ("Cefuroxime 500mg Tablet",           "Antibiotic",  "Tablets",    90,   45,   60,  200),
    ("Erythromycin 500mg Tablet",         "Antibiotic",  "Tablets",    35,   17,   60,  250),
    ("Cloxacillin 500mg Capsule",         "Antibiotic",  "Capsules",   30,   15,  100,  400),
    ("Gentamicin 80mg/2ml Injection",     "Antibiotic",  "Injection",  120,   60,   20,   80),
    ("Nitrofurantoin 100mg Capsule",      "Antibiotic",  "Capsules",   60,   30,   40,  150),
    ("Cotrimoxazole 960mg Tablet",        "Antibiotic",  "Tablets",    20,    9,  100,  400),
    ("Clindamycin 300mg Capsule",         "Antibiotic",  "Capsules",   65,   32,   40,  150),
    ("Flucloxacillin 500mg Capsule",      "Antibiotic",  "Capsules",   35,   17,   60,  250),
    ("Tetracycline 250mg Capsule",        "Antibiotic",  "Capsules",   20,    9,   50,  200),
    ("Chloramphenicol 250mg Capsule",     "Antibiotic",  "Capsules",   20,    9,   30,  100),
    ("Benzylpenicillin 5MU Injection",    "Antibiotic",  "Injection",  180,   90,   20,   60),
    ("Vancomycin 500mg Injection",        "Antibiotic",  "Injection",  800,  400,   10,   30),

    # ── Antimalarials ────────────────────────────────────────────────────
    ("Artemether/Lumefantrine 20/120mg",  "Antimalarial", "Tablets",   90,   45,  100,  400),
    ("Quinine 300mg/ml Injection",        "Antimalarial", "Injection", 250,  125,   20,   60),
    ("Quinine 300mg Tablet",              "Antimalarial", "Tablets",   30,   15,   60,  200),
    ("Mefloquine 250mg Tablet",           "Antimalarial", "Tablets",   150,   75,   20,   60),
    ("Artesunate 60mg Injection",         "Antimalarial", "Injection", 500,  250,   15,   50),
    ("Artesunate 50mg Tablet",            "Antimalarial", "Tablets",   60,   30,   40,  150),
    ("Doxycycline 100mg (Prophylaxis)",   "Antimalarial", "Capsules",  25,   12,   30,  100),

    # ── Antifungals ──────────────────────────────────────────────────────
    ("Fluconazole 150mg Capsule",         "Antifungal",  "Capsules",   80,   40,   50,  200),
    ("Fluconazole 200mg Capsule",         "Antifungal",  "Capsules",   120,   60,   30,  100),
    ("Clotrimazole 1% Cream",             "Antifungal",  "Cream/Gel",  180,   90,   20,   80),
    ("Clotrimazole Pessary 500mg",        "Antifungal",  "Suppository",200,  100,   20,   60),
    ("Ketoconazole 200mg Tablet",         "Antifungal",  "Tablets",    60,   30,   30,  100),
    ("Nystatin Oral Suspension",          "Antifungal",  "Suspension", 250,  125,   15,   50),
    ("Miconazole 2% Cream",               "Antifungal",  "Cream/Gel",  200,  100,   15,   60),
    ("Griseofulvin 500mg Tablet",         "Antifungal",  "Tablets",    50,   25,   20,   80),

    # ── Antivirals ───────────────────────────────────────────────────────
    ("Acyclovir 400mg Tablet",            "Antiviral",  "Tablets",    80,   40,   40,  150),
    ("Acyclovir 5% Cream",                "Antiviral",  "Cream/Gel",  250,  125,   15,   50),
    ("Acyclovir 250mg Injection",         "Antiviral",  "Injection",  600,  300,   10,   30),

    # ── Antihistamines ───────────────────────────────────────────────────
    ("Cetirizine 10mg Tablet",            "Antihistamine", "Tablets",   20,    9,  100,  400),
    ("Loratadine 10mg Tablet",            "Antihistamine", "Tablets",   20,    9,  100,  400),
    ("Fexofenadine 180mg Tablet",         "Antihistamine", "Tablets",   50,   25,   50,  200),
    ("Chlorpheniramine 4mg Tablet",       "Antihistamine", "Tablets",   10,    4,  100,  400),
    ("Promethazine 25mg Tablet",          "Antihistamine", "Tablets",   25,   12,   50,  200),
    ("Promethazine 25mg Injection",       "Antihistamine", "Injection", 120,   60,   20,   80),

    # ── Antihypertensives ────────────────────────────────────────────────
    ("Amlodipine 5mg Tablet",             "Antihypertensive", "Tablets",  25,   12,  100,  400),
    ("Amlodipine 10mg Tablet",            "Antihypertensive", "Tablets",  35,   17,   80,  300),
    ("Enalapril 10mg Tablet",             "Antihypertensive", "Tablets",  30,   14,   80,  300),
    ("Enalapril 5mg Tablet",              "Antihypertensive", "Tablets",  22,   10,   80,  300),
    ("Losartan 50mg Tablet",              "Antihypertensive", "Tablets",  50,   25,   80,  300),
    ("Losartan 100mg Tablet",             "Antihypertensive", "Tablets",  75,   37,   60,  200),
    ("Atenolol 50mg Tablet",              "Antihypertensive", "Tablets",  20,    9,   80,  300),
    ("Atenolol 100mg Tablet",             "Antihypertensive", "Tablets",  30,   14,   60,  250),
    ("Hydrochlorothiazide 25mg Tablet",   "Antihypertensive", "Tablets",  15,    6,   80,  300),
    ("Nifedipine 20mg Tablet",            "Antihypertensive", "Tablets",  30,   14,   60,  250),
    ("Lisinopril 10mg Tablet",            "Antihypertensive", "Tablets",  35,   17,   60,  250),
    ("Captopril 25mg Tablet",             "Antihypertensive", "Tablets",  20,    9,   60,  250),
    ("Methyldopa 250mg Tablet",           "Antihypertensive", "Tablets",  30,   14,   50,  200),
    ("Valsartan 80mg Tablet",             "Antihypertensive", "Tablets",  60,   30,   40,  150),
    ("Carvedilol 6.25mg Tablet",          "Antihypertensive", "Tablets",  50,   25,   40,  150),

    # ── Cardiovascular ───────────────────────────────────────────────────
    ("Furosemide 40mg Tablet",            "Cardiovascular", "Tablets",   20,    9,   80,  300),
    ("Furosemide 20mg/ml Injection",      "Cardiovascular", "Injection", 200,  100,   20,   80),
    ("Atorvastatin 20mg Tablet",          "Cardiovascular", "Tablets",   40,   20,   80,  300),
    ("Atorvastatin 40mg Tablet",          "Cardiovascular", "Tablets",   65,   32,   60,  250),
    ("Simvastatin 20mg Tablet",           "Cardiovascular", "Tablets",   35,   17,   60,  250),
    ("Warfarin 5mg Tablet",               "Cardiovascular", "Tablets",   30,   14,   40,  150),
    ("Digoxin 0.25mg Tablet",             "Cardiovascular", "Tablets",   25,   12,   40,  150),
    ("Spironolactone 25mg Tablet",        "Cardiovascular", "Tablets",   35,   17,   50,  200),
    ("Clopidogrel 75mg Tablet",           "Cardiovascular", "Tablets",   60,   30,   60,  200),
    ("Adrenaline (Epinephrine) 1mg/ml",   "Emergency / IV Fluids", "Injection", 350, 175, 10, 30),
    ("Atropine 0.6mg/ml Injection",       "Emergency / IV Fluids", "Injection", 200, 100, 10, 30),
    ("Normal Saline 0.9% 1L",             "Emergency / IV Fluids", "Solution",  150,  70,  50, 150),
    ("Normal Saline 0.9% 500ml",          "Emergency / IV Fluids", "Solution",  100,  48,  50, 150),
    ("Ringer's Lactate 1L",               "Emergency / IV Fluids", "Solution",  160,  80,  40, 120),
    ("Dextrose 5% 500ml",                 "Emergency / IV Fluids", "Solution",  120,  60,  40, 120),
    ("Dextrose 50% 50ml Injection",       "Emergency / IV Fluids", "Injection", 180,  90,  20,  60),

    # ── Antidiabetics ────────────────────────────────────────────────────
    ("Metformin 500mg Tablet",            "Antidiabetic", "Tablets",   20,    9,  100,  400),
    ("Metformin 850mg Tablet",            "Antidiabetic", "Tablets",   30,   14,   80,  300),
    ("Metformin 1000mg Tablet",           "Antidiabetic", "Tablets",   40,   20,   60,  250),
    ("Glibenclamide 5mg Tablet",          "Antidiabetic", "Tablets",   20,    9,   60,  250),
    ("Glimepiride 2mg Tablet",            "Antidiabetic", "Tablets",   50,   25,   50,  200),
    ("Insulin Soluble 100IU/ml (10ml)",   "Antidiabetic", "Injection", 550,  275,  20,   60),
    ("Insulin NPH 100IU/ml (10ml)",       "Antidiabetic", "Injection", 600,  300,  20,   60),
    ("Insulin Glargine 100IU/ml (10ml)",  "Antidiabetic", "Injection", 1500, 750,  10,   30),
    ("Sitagliptin 50mg Tablet",           "Antidiabetic", "Tablets",   200,  100,  20,   60),

    # ── GI / Antacids ────────────────────────────────────────────────────
    ("Omeprazole 20mg Capsule",           "Antacid / GI", "Capsules",  30,   14,  100,  400),
    ("Omeprazole 40mg Injection",         "Antacid / GI", "Injection", 400,  200,  20,   60),
    ("Pantoprazole 40mg Tablet",          "Antacid / GI", "Tablets",   45,   22,   80,  300),
    ("Ranitidine 150mg Tablet",           "Antacid / GI", "Tablets",   15,    6,   60,  250),
    ("Magnesium Trisilicate Tablet",      "Antacid / GI", "Tablets",    8,    3,  100,  400),
    ("Loperamide 2mg Capsule",            "Antacid / GI", "Capsules",  30,   14,   50,  200),
    ("Metoclopramide 10mg Tablet",        "Antacid / GI", "Tablets",   15,    6,   60,  250),
    ("Metoclopramide 10mg Injection",     "Antacid / GI", "Injection", 120,   60,   20,   80),
    ("Ondansetron 8mg Tablet",            "Antacid / GI", "Tablets",   80,   40,   50,  200),
    ("Ondansetron 4mg/2ml Injection",     "Antacid / GI", "Injection", 250,  125,   20,   80),
    ("Domperidone 10mg Tablet",           "Antacid / GI", "Tablets",   20,    9,   60,  250),
    ("Hyoscine Butylbromide 10mg Tab",    "Antacid / GI", "Tablets",   25,   12,   50,  200),
    ("Hyoscine 20mg/ml Injection",        "Antacid / GI", "Injection", 150,   75,   20,   80),
    ("ORS Sachets (20.5g)",               "Antacid / GI", "Powder",    30,   14,   80,  300),
    ("Lactulose Syrup 3.35g/5ml",         "Antacid / GI", "Syrup",     280,  140,   20,   80),

    # ── Respiratory ──────────────────────────────────────────────────────
    ("Salbutamol 100mcg Inhaler",         "Respiratory", "Inhaler",   350,  175,   30,  100),
    ("Salbutamol 5mg/ml Nebuliser",       "Respiratory", "Solution",  150,   75,   20,   80),
    ("Salbutamol 2mg/5ml Syrup",          "Respiratory", "Syrup",     120,   60,   30,  100),
    ("Beclometasone 250mcg Inhaler",      "Respiratory", "Inhaler",   950,  475,   15,   50),
    ("Budesonide 200mcg Inhaler",         "Respiratory", "Inhaler",   1200, 600,   10,   40),
    ("Aminophylline 100mg Tablet",        "Respiratory", "Tablets",    20,    9,   60,  200),
    ("Aminophylline 250mg/10ml Inj",      "Respiratory", "Injection",  180,   90,   15,   50),
    ("Prednisolone 5mg Tablet",           "Hormonal",    "Tablets",    15,    6,   80,  300),
    ("Prednisolone 25mg Tablet",          "Hormonal",    "Tablets",    40,   20,   50,  200),

    # ── CNS ──────────────────────────────────────────────────────────────
    ("Diazepam 5mg Tablet",               "Central Nervous System", "Tablets",  25,   12,  40,  150),
    ("Diazepam 10mg/2ml Injection",       "Central Nervous System", "Injection",150,  75,  15,   50),
    ("Carbamazepine 200mg Tablet",        "Central Nervous System", "Tablets",  35,   17,  60,  200),
    ("Phenytoin 100mg Tablet",            "Central Nervous System", "Tablets",  25,   12,  50,  200),
    ("Sodium Valproate 200mg Tablet",     "Central Nervous System", "Tablets",  40,   20,  50,  200),
    ("Amitriptyline 25mg Tablet",         "Central Nervous System", "Tablets",  20,    9,  50,  200),
    ("Fluoxetine 20mg Capsule",           "Central Nervous System", "Capsules", 60,   30,  40,  150),
    ("Haloperidol 5mg Tablet",            "Central Nervous System", "Tablets",  30,   14,  30,  100),
    ("Haloperidol 5mg/ml Injection",      "Central Nervous System", "Injection",180,  90,  15,   50),
    ("Chlorpromazine 100mg Tablet",       "Central Nervous System", "Tablets",  25,   12,  30,  100),
    ("Phenobarbitone 30mg Tablet",        "Central Nervous System", "Tablets",  15,    6,  50,  200),

    # ── Hormonal ─────────────────────────────────────────────────────────
    ("Dexamethasone 4mg Tablet",          "Hormonal", "Tablets",    30,   14,  50,  200),
    ("Dexamethasone 4mg/ml Injection",    "Hormonal", "Injection",  200,  100, 20,   80),
    ("Hydrocortisone 100mg Injection",    "Hormonal", "Injection",  350,  175, 20,   60),
    ("Levothyroxine 50mcg Tablet",        "Hormonal", "Tablets",    35,   17,  50,  200),
    ("Levothyroxine 100mcg Tablet",       "Hormonal", "Tablets",    50,   25,  40,  150),
    ("Levonorgestrel 0.75mg Tablet",      "Hormonal", "Tablets",    80,   40,  30,  100),
    ("Combined OCP (EE/LNG)",             "Hormonal", "Tablets",    50,   25,  30,  100),
    ("Oxytocin 10IU/ml Injection",        "Hormonal", "Injection",  200,  100, 20,   60),
    ("Medroxyprogesterone 150mg Inj",     "Hormonal", "Injection",  350,  175, 15,   50),

    # ── Antiparasitics ───────────────────────────────────────────────────
    ("Albendazole 400mg Tablet",          "Antiparasitic", "Tablets",  40,   20,  50,  200),
    ("Mebendazole 100mg Tablet",          "Antiparasitic", "Tablets",  30,   14,  50,  200),
    ("Praziquantel 600mg Tablet",         "Antiparasitic", "Tablets",  80,   40,  30,  100),
    ("Ivermectin 3mg Tablet",             "Antiparasitic", "Tablets",  60,   30,  30,  100),
    ("Permethrin 5% Cream",               "Antiparasitic", "Cream/Gel",250,  125,  15,   50),

    # ── Vitamins & Supplements ───────────────────────────────────────────
    ("Ferrous Sulfate 200mg Tablet",      "Vitamin / Supplement", "Tablets",  15,    6, 100,  400),
    ("Folic Acid 5mg Tablet",             "Vitamin / Supplement", "Tablets",   8,    3, 100,  400),
    ("Vitamin B Complex Tablet",          "Vitamin / Supplement", "Tablets",  15,    6,  80,  300),
    ("Vitamin C 500mg Tablet",            "Vitamin / Supplement", "Tablets",  15,    6,  80,  300),
    ("Multivitamin Tablet",               "Vitamin / Supplement", "Tablets",  20,    9,  80,  300),
    ("Calcium + Vit D3 500mg/250IU Tab",  "Vitamin / Supplement", "Tablets",  25,   12,  60,  250),
    ("Zinc Sulfate 20mg Tablet",          "Vitamin / Supplement", "Tablets",  20,    9,  60,  250),
    ("Vitamin A + D Capsule",             "Vitamin / Supplement", "Capsules", 20,    9,  60,  250),
    ("Magnesium 250mg Tablet",            "Vitamin / Supplement", "Tablets",  30,   14,  50,  200),

    # ── Dermatological ───────────────────────────────────────────────────
    ("Betamethasone 0.1% Cream",          "Dermatological", "Cream/Gel", 180,   90,  20,  80),
    ("Hydrocortisone 1% Cream",           "Dermatological", "Cream/Gel", 150,   75,  20,  80),
    ("Silver Sulfadiazine 1% Cream",      "Dermatological", "Cream/Gel", 350,  175,  10,  40),
    ("Calamine Lotion",                   "Dermatological", "Solution",  120,   60,  20,  80),
    ("Benzoyl Peroxide 5% Gel",           "Dermatological", "Cream/Gel", 280,  140,  15,  50),
    ("Salicylic Acid 2% Cream",           "Dermatological", "Cream/Gel", 200,  100,  15,  50),

    # ── Ophthalmic ───────────────────────────────────────────────────────
    ("Chloramphenicol 0.5% Eye Drops",    "Ophthalmic", "Drops",  120,   60,  20,  80),
    ("Gentamicin 0.3% Eye Drops",         "Ophthalmic", "Drops",  150,   75,  15,  60),
    ("Timolol 0.5% Eye Drops",            "Ophthalmic", "Drops",  200,  100,  10,  40),
    ("Tetracaine 1% Eye Drops",           "Ophthalmic", "Drops",  250,  125,  10,  40),
    ("Dexamethasone 0.1% Eye Drops",      "Ophthalmic", "Drops",  200,  100,  10,  40),
    ("Artificial Tears Eye Drops",        "Ophthalmic", "Drops",  150,   75,  20,  60),
]
# fmt: on


class Command(BaseCommand):
    help = (
        "Seed MedicationStock for the current tenant with 150+ common medications, "
        "default prices, units, and reorder levels."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--skip-existing",
            action="store_true",
            default=False,
            help="Skip medications that already have a stock entry (default: update prices).",
        )
        parser.add_argument(
            "--reset",
            action="store_true",
            default=False,
            help="Delete ALL existing stock entries before seeding. Use with caution.",
        )

    def handle(self, *args, **options):
        skip_existing = options["skip_existing"]
        reset = options["reset"]

        if reset:
            deleted, _ = MedicationStock.objects.all().delete()
            self.stdout.write(self.style.WARNING(f"Deleted {deleted} existing stock entries."))
            batch_del, _ = StockBatch.objects.all().delete()
            if batch_del:
                self.stdout.write(self.style.WARNING(f"Deleted {batch_del} existing batches."))

        # ── Ensure Categories exist ──────────────────────────────────────
        category_map = {}
        for name in CATEGORY_DEFS:
            cat, _ = Category.objects.get_or_create(name=name)
            category_map[name] = cat

        # ── Ensure Units exist ───────────────────────────────────────────
        unit_map = {}
        for name, abbr in UNIT_DEFS:
            unit, _ = Unit.objects.get_or_create(
                name=name,
                defaults={"abbreviation": abbr},
            )
            unit_map[name] = unit

        # ── Seed stock ───────────────────────────────────────────────────
        created = skipped = updated = 0

        for (
            med_name,
            cat_name,
            unit_name,
            sell_price,
            cost_price,
            reorder_lvl,
            reorder_qty,
        ) in STOCK_DATA:
            category = category_map.get(cat_name)
            unit = unit_map.get(unit_name)

            existing = MedicationStock.objects.filter(
                medication_name=med_name
            ).first()

            if existing:
                if skip_existing:
                    skipped += 1
                    continue
                # Update prices / levels if they differ
                changed = False
                fields_to_update = []
                if existing.selling_price != Decimal(str(sell_price)):
                    existing.selling_price = Decimal(str(sell_price))
                    fields_to_update.append("selling_price")
                    changed = True
                if existing.cost_price != Decimal(str(cost_price)):
                    existing.cost_price = Decimal(str(cost_price))
                    fields_to_update.append("cost_price")
                    changed = True
                if existing.reorder_level != reorder_lvl:
                    existing.reorder_level = reorder_lvl
                    fields_to_update.append("reorder_level")
                    changed = True
                if existing.reorder_quantity != reorder_qty:
                    existing.reorder_quantity = reorder_qty
                    fields_to_update.append("reorder_quantity")
                    changed = True
                if changed:
                    existing.save(update_fields=fields_to_update)
                    updated += 1
                else:
                    skipped += 1
            else:
                stock = MedicationStock.objects.create(
                    medication_name=med_name,
                    category=category,
                    unit=unit,
                    selling_price=Decimal(str(sell_price)),
                    cost_price=Decimal(str(cost_price)),
                    reorder_level=reorder_lvl,
                    reorder_quantity=reorder_qty,
                    is_active=True,
                )
                # Create an initial stock batch with random qty 100-300
                qty = random.randint(100, 300)
                expiry = timezone.now().date() + timezone.timedelta(days=random.randint(365, 730))
                StockBatch.objects.create(
                    stock=stock,
                    batch_number=f"SEED-{stock.id:04d}",
                    quantity_received=qty,
                    quantity_remaining=qty,
                    cost_price_per_unit=Decimal(str(cost_price)),
                    expiry_date=expiry,
                )
                created += 1

        total = MedicationStock.objects.count()
        self.stdout.write(self.style.SUCCESS(
            f"\nPharmacy Stock Seed Complete\n"
            f"  Created : {created}\n"
            f"  Updated : {updated}\n"
            f"  Skipped : {skipped}\n"
            f"  Total in DB: {total}"
        ))
