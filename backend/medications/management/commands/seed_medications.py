"""
Seed the shared Medication catalog from the comprehensive Kenyan-market
pharmacy stock list.

Reuses ``inventory.management.commands.seed_pharmacy_stock.STOCK_DATA``
so the catalog stays in lockstep with the per-tenant pharmacy stock seed
(currently 800+ unique products).

Usage:
    python manage.py seed_medications
    python manage.py seed_medications --reset       # wipe & reseed
    python manage.py seed_medications --skip-existing
"""

import re

from django.core.management.base import BaseCommand
from django.db import transaction

from medications.models import Medication

# Reuse the canonical Kenyan-market catalog used by the pharmacy stock seed.
from inventory.management.commands.seed_pharmacy_stock import STOCK_DATA


# ---------------------------------------------------------------------------
# Brand names (Kenyan market) — keyed by canonical generic name (lowercase).
# Sources: KEML, common Kenyan pharmacy distributors (Cosmos, UCL, Dawa,
# Beta Healthcare, GSK, Pfizer, Sanofi, Cipla, Sun, Aurobindo, Hetero, etc.)
# ---------------------------------------------------------------------------
BRAND_NAMES: dict[str, list[str]] = {
    # Analgesics / NSAIDs
    "paracetamol": ["Panadol", "Calpol", "Tylenol", "Hedex", "Action", "Mara Moja"],
    "ibuprofen": ["Brufen", "Advil", "Nurofen", "Ibucap"],
    "diclofenac": ["Voltaren", "Cataflam", "Olfen", "Dyclo"],
    "diclofenac sodium": ["Voltaren", "Cataflam", "Olfen"],
    "diclofenac potassium": ["Cataflam", "Voltfast"],
    "aspirin": ["Disprin", "Bayer Aspirin", "Cardiprin", "Ascard"],
    "tramadol": ["Tramal", "Domadol", "Tramacip"],
    "morphine sulfate": ["MS Contin", "Sevredol"],
    "morphine": ["MS Contin", "Sevredol"],
    "pethidine": ["Demerol"],
    "codeine phosphate": ["Codalgin"],
    "codeine": ["Codalgin"],
    "naproxen": ["Naprosyn", "Synflex"],
    "meloxicam": ["Mobic", "Melox"],
    "celecoxib": ["Celebrex", "Cobix"],
    "etoricoxib": ["Arcoxia", "Etoshine"],
    "piroxicam": ["Feldene"],
    "indomethacin": ["Indocin"],
    "ketorolac": ["Toradol", "Ketanov"],
    "nimesulide": ["Nise", "Nimulid"],
    "mefenamic acid": ["Ponstan", "Ponstel"],

    # Antibiotics
    "amoxicillin": ["Amoxil", "Ospamox", "Moxypen"],
    "amoxicillin/clavulanate": ["Augmentin", "Amoclav", "Clavam"],
    "amoxicillin/clavulanic acid": ["Augmentin", "Amoclav", "Clavam"],
    "ampicillin": ["Penbritin"],
    "ampicillin/cloxacillin": ["Ampiclox"],
    "azithromycin": ["Zithromax", "Azithral", "Azee"],
    "ciprofloxacin": ["Cipro", "Ciproxin", "Cifran"],
    "levofloxacin": ["Levaquin", "Tavanic"],
    "ofloxacin": ["Floxin", "Tarivid"],
    "moxifloxacin": ["Avelox", "Mosi"],
    "metronidazole": ["Flagyl", "Metrogyl"],
    "doxycycline": ["Vibramycin", "Doxy"],
    "tetracycline": ["Achromycin"],
    "ceftriaxone": ["Rocephin", "Cefaxone"],
    "cefuroxime": ["Zinnat", "Zinacef", "Cefuro"],
    "cefixime": ["Suprax", "Cefspan"],
    "cefpodoxime": ["Vantin", "Cefpod"],
    "cefaclor": ["Ceclor"],
    "cefadroxil": ["Duricef", "Cedrox"],
    "cefalexin": ["Keflex", "Sporidex"],
    "cephalexin": ["Keflex", "Sporidex"],
    "cefotaxime": ["Claforan"],
    "ceftazidime": ["Fortum"],
    "cefepime": ["Maxipime"],
    "meropenem": ["Meronem"],
    "imipenem": ["Tienam"],
    "erythromycin": ["Erythrocin", "Eryc"],
    "clarithromycin": ["Klacid", "Klaricid"],
    "cloxacillin": ["Cloxapen", "Orbenin"],
    "flucloxacillin": ["Floxapen"],
    "benzylpenicillin": ["Crystapen"],
    "phenoxymethylpenicillin": ["Penicillin V"],
    "benzathine penicillin": ["Penadur"],
    "procaine penicillin": ["Pro-Pen"],
    "gentamicin": ["Garamycin", "Gentacyn"],
    "amikacin": ["Amikin"],
    "streptomycin": ["Strepto"],
    "nitrofurantoin": ["Macrobid", "Furadantin"],
    "cotrimoxazole": ["Septrin", "Bactrim", "Septran"],
    "trimethoprim/sulfamethoxazole": ["Septrin", "Bactrim"],
    "clindamycin": ["Dalacin C", "Cleocin"],
    "lincomycin": ["Lincocin"],
    "vancomycin": ["Vancocin"],
    "linezolid": ["Zyvox"],
    "chloramphenicol": ["Chloromycetin"],

    # Antituberculosis
    "rifampicin": ["Rifadin", "Rimactane"],
    "isoniazid": ["INH"],
    "ethambutol": ["Myambutol"],
    "pyrazinamide": ["Pyzina"],
    "rifampicin/isoniazid": ["Rifinah"],
    "rifampicin/isoniazid/pyrazinamide/ethambutol": ["RHZE", "Forecox"],

    # Antifungals
    "fluconazole": ["Diflucan", "Forcan"],
    "itraconazole": ["Sporanox", "Canditral"],
    "ketoconazole": ["Nizoral"],
    "clotrimazole": ["Canesten", "Candid"],
    "miconazole": ["Daktarin"],
    "nystatin": ["Mycostatin", "Nilstat"],
    "terbinafine": ["Lamisil"],
    "griseofulvin": ["Grisovin"],
    "amphotericin b": ["Fungizone"],

    # Antivirals / ARVs
    "acyclovir": ["Zovirax", "Acivir"],
    "valacyclovir": ["Valtrex"],
    "oseltamivir": ["Tamiflu"],
    "tenofovir": ["Viread"],
    "tenofovir/lamivudine": ["Truvada"],
    "tenofovir/lamivudine/dolutegravir": ["TLD", "Acriptega"],
    "tenofovir/lamivudine/efavirenz": ["TLE", "Atripla"],
    "zidovudine": ["Retrovir", "AZT"],
    "lamivudine": ["Epivir", "3TC"],
    "efavirenz": ["Stocrin", "Sustiva"],
    "nevirapine": ["Viramune"],
    "dolutegravir": ["Tivicay"],
    "lopinavir/ritonavir": ["Kaletra", "Aluvia"],
    "abacavir": ["Ziagen"],
    "atazanavir": ["Reyataz"],
    "raltegravir": ["Isentress"],

    # Antimalarials
    "artemether/lumefantrine": ["Coartem", "ALu", "Lumartem"],
    "artesunate": ["Arinate", "Larinate"],
    "artesunate/amodiaquine": ["Camoquin Plus", "Coarsucam"],
    "dihydroartemisinin/piperaquine": ["Duo-Cotecxin", "Eurartesim"],
    "quinine": ["Quinimax", "Quinoric"],
    "mefloquine": ["Lariam", "Mephaquin"],
    "primaquine": ["Primacip"],
    "sulfadoxine/pyrimethamine": ["Fansidar", "SP"],
    "amodiaquine": ["Camoquin"],

    # Antiparasitics / Anthelmintics
    "albendazole": ["Zentel", "Albamax"],
    "mebendazole": ["Vermox", "Wormin"],
    "praziquantel": ["Biltricide", "Cestox"],
    "ivermectin": ["Mectizan", "Stromectol"],
    "levamisole": ["Decaris", "Ergamisol"],
    "niclosamide": ["Yomesan"],
    "tinidazole": ["Tindamax", "Fasigyn"],
    "secnidazole": ["Flagentyl"],

    # Antihistamines
    "cetirizine": ["Zyrtec", "Cetrizet", "Zincet"],
    "loratadine": ["Claritin", "Lorfast", "Lorinol"],
    "desloratadine": ["Aerius"],
    "fexofenadine": ["Allegra", "Telfast"],
    "levocetirizine": ["Xyzal", "Levocet"],
    "chlorpheniramine": ["Piriton", "Chlor-Trimeton"],
    "promethazine": ["Phenergan", "Avomine"],
    "diphenhydramine": ["Benadryl"],
    "hydroxyzine": ["Atarax"],

    # Antihypertensives
    "amlodipine": ["Norvasc", "Amlopin", "Amlong"],
    "nifedipine": ["Adalat", "Nifedicor"],
    "felodipine": ["Plendil"],
    "enalapril": ["Renitec", "Vasotec"],
    "lisinopril": ["Zestril", "Prinivil", "Lisinop"],
    "captopril": ["Capoten"],
    "ramipril": ["Tritace", "Cardace"],
    "perindopril": ["Coversyl"],
    "losartan": ["Cozaar", "Losacar", "Repace"],
    "valsartan": ["Diovan"],
    "telmisartan": ["Micardis", "Telma"],
    "irbesartan": ["Aprovel", "Avapro"],
    "atenolol": ["Tenormin"],
    "bisoprolol": ["Concor", "Cardicor"],
    "metoprolol": ["Lopressor", "Betaloc"],
    "carvedilol": ["Coreg", "Dilatrend"],
    "propranolol": ["Inderal"],
    "labetalol": ["Trandate"],
    "hydrochlorothiazide": ["HCT", "Esidrex"],
    "methyldopa": ["Aldomet"],
    "hydralazine": ["Apresoline"],
    "prazosin": ["Minipress"],
    "doxazosin": ["Cardura"],
    "clonidine": ["Catapres"],

    # Cardiovascular / Anticoagulant / Diuretic
    "furosemide": ["Lasix", "Frusemide"],
    "spironolactone": ["Aldactone"],
    "indapamide": ["Natrilix"],
    "bumetanide": ["Bumex"],
    "atorvastatin": ["Lipitor", "Atorlip"],
    "simvastatin": ["Zocor", "Simvotin"],
    "rosuvastatin": ["Crestor", "Rozavel"],
    "pravastatin": ["Pravachol"],
    "fenofibrate": ["Tricor", "Lipanthyl"],
    "warfarin": ["Coumadin", "Marevan"],
    "heparin": ["Heparin Sodium"],
    "enoxaparin": ["Clexane", "Lovenox"],
    "clopidogrel": ["Plavix", "Clopilet"],
    "ticagrelor": ["Brilinta"],
    "digoxin": ["Lanoxin"],
    "isosorbide dinitrate": ["Isordil", "Sorbitrate"],
    "isosorbide mononitrate": ["Imdur", "Monit"],
    "glyceryl trinitrate": ["Nitrolingual", "Nitrostat"],
    "nitroglycerin": ["Nitrolingual", "Nitrostat"],
    "amiodarone": ["Cordarone"],

    # Antidiabetics
    "metformin": ["Glucophage", "Glycomet", "Diaformin"],
    "glibenclamide": ["Daonil", "Glyburide", "Euglucon"],
    "gliclazide": ["Diamicron"],
    "glimepiride": ["Amaryl", "Glimy"],
    "pioglitazone": ["Actos", "Pioz"],
    "sitagliptin": ["Januvia", "Istavel"],
    "vildagliptin": ["Galvus"],
    "linagliptin": ["Trajenta"],
    "empagliflozin": ["Jardiance"],
    "dapagliflozin": ["Forxiga"],
    "insulin (soluble)": ["Actrapid", "Humulin R"],
    "insulin soluble": ["Actrapid", "Humulin R"],
    "insulin (nph)": ["Insulatard", "Humulin N"],
    "insulin nph": ["Insulatard", "Humulin N"],
    "insulin glargine": ["Lantus", "Basaglar"],
    "insulin aspart": ["NovoRapid"],
    "insulin lispro": ["Humalog"],
    "insulin mixtard": ["Mixtard 30/70"],

    # GI / Antacids
    "omeprazole": ["Losec", "Prilosec", "Omez"],
    "esomeprazole": ["Nexium", "Esoz"],
    "pantoprazole": ["Controloc", "Protonix", "Pantop"],
    "lansoprazole": ["Prevacid", "Lanzol"],
    "rabeprazole": ["Pariet", "Razo"],
    "ranitidine": ["Zantac", "Rantac"],
    "famotidine": ["Pepcid"],
    "cimetidine": ["Tagamet"],
    "magnesium trisilicate": ["Gelusil"],
    "aluminium hydroxide/magnesium hydroxide": ["Mucaine", "Maalox"],
    "loperamide": ["Imodium"],
    "metoclopramide": ["Plasil", "Maxolon", "Reglan"],
    "ondansetron": ["Zofran", "Emeset"],
    "domperidone": ["Motilium", "Domstal"],
    "hyoscine butylbromide": ["Buscopan"],
    "ors": ["Oralite", "Resta"],
    "ors (oral rehydration salts)": ["Oralite", "Resta"],
    "lactulose": ["Duphalac"],
    "bisacodyl": ["Dulcolax"],
    "mesalazine": ["Pentasa", "Asacol"],
    "sucralfate": ["Carafate"],

    # Respiratory
    "salbutamol": ["Ventolin", "Asthalin"],
    "salbutamol/ipratropium": ["Combivent", "Duolin"],
    "ipratropium bromide": ["Atrovent"],
    "ipratropium": ["Atrovent"],
    "beclometasone": ["Becotide", "Qvar", "Beclate"],
    "budesonide": ["Pulmicort", "Budecort"],
    "fluticasone": ["Flixotide", "Flixonase"],
    "fluticasone/salmeterol": ["Seretide", "Adoair"],
    "formoterol/budesonide": ["Symbicort"],
    "montelukast": ["Singulair", "Montair"],
    "aminophylline": ["Phyllocontin"],
    "theophylline": ["Theo-Dur", "Quibron"],

    # CNS / Psychiatric
    "diazepam": ["Valium", "Calmpose"],
    "lorazepam": ["Ativan"],
    "midazolam": ["Dormicum"],
    "alprazolam": ["Xanax"],
    "carbamazepine": ["Tegretol", "Zeptol"],
    "phenytoin": ["Dilantin", "Epanutin"],
    "sodium valproate": ["Epilim", "Depakene", "Valparin"],
    "valproic acid": ["Depakene", "Valparin"],
    "lamotrigine": ["Lamictal"],
    "levetiracetam": ["Keppra"],
    "phenobarbital": ["Luminal"],
    "amitriptyline": ["Elavil", "Tryptanol"],
    "imipramine": ["Tofranil"],
    "fluoxetine": ["Prozac", "Fludac"],
    "sertraline": ["Zoloft", "Serlift"],
    "citalopram": ["Cipram"],
    "escitalopram": ["Lexapro", "Cipralex"],
    "paroxetine": ["Paxil", "Seroxat"],
    "venlafaxine": ["Effexor"],
    "haloperidol": ["Haldol", "Serenace"],
    "chlorpromazine": ["Largactil"],
    "olanzapine": ["Zyprexa", "Oleanz"],
    "risperidone": ["Risperdal", "Sizodon"],
    "quetiapine": ["Seroquel"],
    "lithium carbonate": ["Lithicarb"],

    # Hormonal / Steroids
    "prednisolone": ["Deltasone", "Prednis"],
    "prednisone": ["Deltasone"],
    "dexamethasone": ["Decadron", "Dexa"],
    "hydrocortisone": ["Solu-Cortef", "Cortef"],
    "methylprednisolone": ["Solu-Medrol", "Medrol"],
    "betamethasone": ["Betnesol", "Celestone"],
    "triamcinolone": ["Kenacort"],
    "levothyroxine": ["Eltroxin", "Synthroid", "Thyronorm"],
    "carbimazole": ["Neo-Mercazole"],
    "propylthiouracil": ["PTU"],
    "tamoxifen": ["Nolvadex"],
    "testosterone": ["Sustanon"],
    "progesterone": ["Utrogestan", "Crinone"],
    "estradiol": ["Progynova"],

    # Contraceptives
    "ethinylestradiol/levonorgestrel": ["Microgynon", "Pilplan"],
    "levonorgestrel": ["Postinor 2", "Plan B", "Truston 2"],
    "medroxyprogesterone": ["Depo-Provera"],
    "norethisterone": ["Primolut N"],

    # Vitamins / Supplements
    "ferrous sulfate": ["Fefol", "Sangobion"],
    "ferrous fumarate": ["Galfer", "Fersamal"],
    "folic acid": ["Folvite"],
    "ferrous sulfate/folic acid": ["Iberet", "Fefol"],
    "vitamin b complex": ["Neurobion", "Becosules"],
    "vitamin b12": ["Macrabin", "Methycobal"],
    "cyanocobalamin": ["Macrabin"],
    "thiamine": ["Benerva"],
    "vitamin c (ascorbic acid)": ["Celin", "Limcee"],
    "ascorbic acid": ["Celin", "Limcee"],
    "vitamin a": ["Aquasol A"],
    "vitamin d3": ["D-Cal", "Calcirol"],
    "cholecalciferol": ["D-Cal", "Calcirol"],
    "multivitamin": ["Centrum", "Supradyn", "Pharmaton"],
    "calcium + vitamin d3": ["Caltrate", "Shelcal", "Calcimax"],
    "calcium carbonate": ["Caltrate", "Shelcal"],
    "zinc sulfate": ["Zincovit"],
    "magnesium sulfate": ["Mag Sulph"],

    # Dermatological
    "betamethasone (cream)": ["Betnovate", "Betnesol"],
    "mometasone": ["Elocon", "Momate"],
    "permethrin": ["Lyclear", "Elimite"],
    "benzyl benzoate": ["Ascabiol"],
    "calamine": ["Calamine Lotion"],
    "salicylic acid": ["Duofilm"],
    "benzoyl peroxide": ["Panoxyl", "Persol"],
    "tretinoin": ["Retin-A"],
    "adapalene": ["Differin"],
    "silver sulfadiazine": ["Silvadene", "Flamazine"],
    "fusidic acid": ["Fucidin"],
    "mupirocin": ["Bactroban"],

    # Ophthalmic
    "ciprofloxacin (eye)": ["Ciplox-D", "Cipla Eye"],
    "chloramphenicol (eye)": ["Chlorsig"],
    "tobramycin (eye)": ["Tobrex"],
    "tropicamide": ["Mydriacyl"],
    "timolol (eye)": ["Timoptol"],
    "latanoprost": ["Xalatan"],
    "prednisolone (eye)": ["Pred Forte"],
    "artificial tears": ["Tears Naturale", "Refresh"],

    # Emergency / IV Fluids / Anaesthetics
    "normal saline": ["NSS"],
    "ringers lactate": ["RL", "Hartmann's"],
    "dextrose 5%": ["D5W"],
    "dextrose 10%": ["D10W"],
    "dextrose normal saline": ["DNS"],
    "adrenaline": ["Epinephrine"],
    "epinephrine": ["EpiPen"],
    "atropine": ["Atropine Sulphate"],
    "lignocaine": ["Xylocaine"],
    "lidocaine": ["Xylocaine"],
    "bupivacaine": ["Marcaine", "Sensorcaine"],
    "ketamine": ["Ketalar"],
    "propofol": ["Diprivan"],
    "thiopental": ["Pentothal"],
    "suxamethonium": ["Anectine", "Scoline"],

    # Muscle relaxants
    "baclofen": ["Lioresal"],
    "tizanidine": ["Sirdalud", "Zanaflex"],
    "orphenadrine": ["Norflex"],
    "chlorzoxazone": ["Parafon"],

    # Urology
    "tamsulosin": ["Flomax", "Urimax"],
    "finasteride": ["Proscar", "Propecia"],
    "dutasteride": ["Avodart"],
    "sildenafil": ["Viagra", "Suhagra"],
    "tadalafil": ["Cialis", "Tadacip"],
    "oxybutynin": ["Ditropan"],
    "solifenacin": ["Vesicare"],
}


def _brand_lookup(generic_name: str) -> list[str]:
    """Return brand name list for a generic name (case-insensitive)."""
    key = generic_name.lower().strip()
    if key in BRAND_NAMES:
        return list(BRAND_NAMES[key])
    # Try without trailing parenthetical (e.g. "Insulin (Soluble)" already keyed)
    no_paren = re.sub(r"\s*\([^)]*\)\s*$", "", key).strip()
    if no_paren and no_paren != key and no_paren in BRAND_NAMES:
        return list(BRAND_NAMES[no_paren])
    # Try first token (e.g. "Amoxicillin/Clavulanate" → "amoxicillin")
    first = key.split("/")[0].strip()
    if first != key and first in BRAND_NAMES:
        return list(BRAND_NAMES[first])
    return []


# ---------------------------------------------------------------------------
# Abbreviations / shorthand codes — keyed by canonical generic name (lowercase).
# Common in Kenyan clinical practice + pharmacy worksheets.
# ---------------------------------------------------------------------------
ABBREVIATIONS: dict[str, str] = {
    # Analgesics / NSAIDs
    "paracetamol": "PCM",
    "ibuprofen": "IBU",
    "diclofenac": "DCF",
    "diclofenac sodium": "DCF-Na",
    "diclofenac potassium": "DCF-K",
    "aspirin": "ASA",
    "tramadol": "TRM",
    "morphine sulfate": "MOR",
    "morphine": "MOR",
    "pethidine": "PETH",
    "codeine phosphate": "COD",
    "codeine": "COD",
    "naproxen": "NPX",
    "meloxicam": "MLX",
    "celecoxib": "CLX",
    "etoricoxib": "ETX",
    "indomethacin": "INDO",
    "ketorolac": "KTR",
    "mefenamic acid": "MFA",

    # Antibiotics
    "amoxicillin": "AMOX",
    "amoxicillin/clavulanate": "AMC",
    "amoxicillin/clavulanic acid": "AMC",
    "ampicillin": "AMP",
    "ampicillin/cloxacillin": "AMP/CLX",
    "azithromycin": "AZM",
    "ciprofloxacin": "CIP",
    "levofloxacin": "LVX",
    "ofloxacin": "OFX",
    "moxifloxacin": "MXF",
    "metronidazole": "MTZ",
    "doxycycline": "DOX",
    "tetracycline": "TET",
    "ceftriaxone": "CRO",
    "cefuroxime": "CXM",
    "cefixime": "CFM",
    "cefpodoxime": "CPD",
    "cefaclor": "CEC",
    "cefadroxil": "CDR",
    "cefalexin": "LEX",
    "cephalexin": "LEX",
    "cefotaxime": "CTX",
    "ceftazidime": "CAZ",
    "cefepime": "FEP",
    "meropenem": "MEM",
    "imipenem": "IPM",
    "erythromycin": "ERY",
    "clarithromycin": "CLR",
    "cloxacillin": "CLX",
    "flucloxacillin": "FLX",
    "benzylpenicillin": "PEN-G",
    "phenoxymethylpenicillin": "PEN-V",
    "benzathine penicillin": "BPG",
    "procaine penicillin": "PPG",
    "gentamicin": "GEN",
    "amikacin": "AMK",
    "streptomycin": "SM",
    "nitrofurantoin": "NIT",
    "cotrimoxazole": "SXT",
    "trimethoprim/sulfamethoxazole": "TMP-SMX",
    "clindamycin": "CLI",
    "lincomycin": "LIN",
    "vancomycin": "VAN",
    "linezolid": "LZD",
    "chloramphenicol": "CHL",

    # TB
    "rifampicin": "R",
    "isoniazid": "H",
    "ethambutol": "E",
    "pyrazinamide": "Z",
    "rifampicin/isoniazid": "RH",
    "rifampicin/isoniazid/pyrazinamide/ethambutol": "RHZE",

    # Antifungals
    "fluconazole": "FLU",
    "itraconazole": "ITR",
    "ketoconazole": "KTC",
    "clotrimazole": "CTM",
    "miconazole": "MCZ",
    "nystatin": "NYS",
    "terbinafine": "TBF",
    "griseofulvin": "GRI",
    "amphotericin b": "AMB",

    # Antivirals / ARVs
    "acyclovir": "ACV",
    "valacyclovir": "VCV",
    "oseltamivir": "OST",
    "tenofovir": "TDF",
    "tenofovir/lamivudine": "TDF/3TC",
    "tenofovir/lamivudine/dolutegravir": "TLD",
    "tenofovir/lamivudine/efavirenz": "TLE",
    "zidovudine": "AZT",
    "lamivudine": "3TC",
    "efavirenz": "EFV",
    "nevirapine": "NVP",
    "dolutegravir": "DTG",
    "lopinavir/ritonavir": "LPV/r",
    "abacavir": "ABC",
    "atazanavir": "ATV",
    "raltegravir": "RAL",

    # Antimalarials
    "artemether/lumefantrine": "AL",
    "artesunate": "AS",
    "artesunate/amodiaquine": "AS/AQ",
    "dihydroartemisinin/piperaquine": "DHA-PPQ",
    "quinine": "QN",
    "mefloquine": "MQ",
    "primaquine": "PQ",
    "sulfadoxine/pyrimethamine": "SP",
    "amodiaquine": "AQ",

    # Antiparasitics
    "albendazole": "ALB",
    "mebendazole": "MBZ",
    "praziquantel": "PZQ",
    "ivermectin": "IVM",
    "levamisole": "LEV",
    "tinidazole": "TNZ",
    "secnidazole": "SCZ",

    # Antihistamines
    "cetirizine": "CTZ",
    "loratadine": "LOR",
    "desloratadine": "DLR",
    "fexofenadine": "FEX",
    "levocetirizine": "L-CTZ",
    "chlorpheniramine": "CPM",
    "promethazine": "PMZ",
    "diphenhydramine": "DPH",
    "hydroxyzine": "HXZ",

    # Cardiovascular / Antihypertensives
    "amlodipine": "AML",
    "nifedipine": "NIF",
    "felodipine": "FLD",
    "enalapril": "ENA",
    "lisinopril": "LIS",
    "captopril": "CAP",
    "ramipril": "RAM",
    "perindopril": "PER",
    "losartan": "LOS",
    "valsartan": "VAL",
    "telmisartan": "TEL",
    "irbesartan": "IRB",
    "atenolol": "ATN",
    "bisoprolol": "BIS",
    "metoprolol": "MET",
    "carvedilol": "CVD",
    "propranolol": "PRP",
    "labetalol": "LBT",
    "hydrochlorothiazide": "HCTZ",
    "methyldopa": "MDP",
    "hydralazine": "HYD",
    "prazosin": "PRZ",
    "doxazosin": "DOX-A",
    "clonidine": "CLN",
    "furosemide": "FUR",
    "spironolactone": "SPL",
    "indapamide": "IND",
    "atorvastatin": "ATV-S",
    "simvastatin": "SIM",
    "rosuvastatin": "RSV",
    "warfarin": "WAR",
    "heparin": "HEP",
    "enoxaparin": "ENX",
    "clopidogrel": "CLP",
    "ticagrelor": "TCG",
    "digoxin": "DGX",
    "isosorbide dinitrate": "ISDN",
    "isosorbide mononitrate": "ISMN",
    "glyceryl trinitrate": "GTN",
    "nitroglycerin": "NTG",
    "amiodarone": "AMD",

    # Antidiabetics
    "metformin": "MTF",
    "glibenclamide": "GLB",
    "gliclazide": "GLZ",
    "glimepiride": "GLM",
    "pioglitazone": "PIO",
    "sitagliptin": "STG",
    "vildagliptin": "VLG",
    "linagliptin": "LNG",
    "empagliflozin": "EMP",
    "dapagliflozin": "DPG",
    "insulin (soluble)": "INS-R",
    "insulin soluble": "INS-R",
    "insulin (nph)": "INS-N",
    "insulin nph": "INS-N",
    "insulin glargine": "INS-G",
    "insulin aspart": "INS-A",
    "insulin lispro": "INS-L",
    "insulin mixtard": "INS-M",

    # GI
    "omeprazole": "OMP",
    "esomeprazole": "ESO",
    "pantoprazole": "PAN",
    "lansoprazole": "LAN",
    "rabeprazole": "RAB",
    "ranitidine": "RAN",
    "famotidine": "FAM",
    "cimetidine": "CIM",
    "loperamide": "LOP",
    "metoclopramide": "MCP",
    "ondansetron": "OND",
    "domperidone": "DOM",
    "hyoscine butylbromide": "HBB",
    "ors": "ORS",
    "ors (oral rehydration salts)": "ORS",
    "lactulose": "LAC",
    "bisacodyl": "BIS-C",

    # Respiratory
    "salbutamol": "SAL",
    "salbutamol/ipratropium": "SAL/IPR",
    "ipratropium bromide": "IPR",
    "ipratropium": "IPR",
    "beclometasone": "BEC",
    "budesonide": "BUD",
    "fluticasone": "FLT",
    "fluticasone/salmeterol": "FLT/SAL",
    "formoterol/budesonide": "FOR/BUD",
    "montelukast": "MTK",
    "aminophylline": "AMP-H",
    "theophylline": "THP",

    # CNS
    "diazepam": "DZP",
    "lorazepam": "LZP",
    "midazolam": "MDZ",
    "alprazolam": "ALP",
    "carbamazepine": "CBZ",
    "phenytoin": "PHT",
    "sodium valproate": "VPA",
    "valproic acid": "VPA",
    "lamotrigine": "LTG",
    "levetiracetam": "LEV-T",
    "phenobarbital": "PB",
    "amitriptyline": "AMT",
    "imipramine": "IMI",
    "fluoxetine": "FLX-T",
    "sertraline": "SRT",
    "citalopram": "CIT",
    "escitalopram": "ESC",
    "paroxetine": "PRX",
    "venlafaxine": "VEN",
    "haloperidol": "HAL",
    "chlorpromazine": "CPZ",
    "olanzapine": "OLZ",
    "risperidone": "RIS",
    "quetiapine": "QTP",
    "lithium carbonate": "Li2CO3",

    # Steroids / Hormones
    "prednisolone": "PRD",
    "prednisone": "PRD",
    "dexamethasone": "DEX",
    "hydrocortisone": "HC",
    "methylprednisolone": "MPS",
    "betamethasone": "BTM",
    "triamcinolone": "TAC",
    "levothyroxine": "L-T4",
    "carbimazole": "CMZ",
    "propylthiouracil": "PTU",
    "tamoxifen": "TAM",
    "testosterone": "TST",
    "progesterone": "PRG",
    "estradiol": "E2",

    # Contraceptives
    "ethinylestradiol/levonorgestrel": "EE/LNG",
    "levonorgestrel": "LNG",
    "medroxyprogesterone": "DMPA",
    "norethisterone": "NET",

    # Vitamins
    "ferrous sulfate": "FeSO4",
    "ferrous fumarate": "FeFum",
    "folic acid": "FA",
    "ferrous sulfate/folic acid": "FeSO4/FA",
    "vitamin b complex": "Vit-B",
    "vitamin b12": "B12",
    "cyanocobalamin": "B12",
    "thiamine": "B1",
    "vitamin c (ascorbic acid)": "Vit-C",
    "ascorbic acid": "Vit-C",
    "vitamin a": "Vit-A",
    "vitamin d3": "Vit-D3",
    "cholecalciferol": "Vit-D3",
    "multivitamin": "MVI",
    "calcium + vitamin d3": "Ca/D3",
    "calcium carbonate": "CaCO3",
    "zinc sulfate": "ZnSO4",
    "magnesium sulfate": "MgSO4",
    "magnesium citrate": "MgCit",

    # Emergency / Anaesthesia / IV
    "normal saline": "NS",
    "ringers lactate": "RL",
    "dextrose 5%": "D5W",
    "dextrose 10%": "D10W",
    "dextrose normal saline": "DNS",
    "adrenaline": "ADR",
    "epinephrine": "EPI",
    "atropine": "ATR",
    "lignocaine": "LIG",
    "lidocaine": "LID",
    "bupivacaine": "BUP",
    "ketamine": "KET",
    "propofol": "PROP",
    "thiopental": "TPL",
    "suxamethonium": "SUX",

    # Muscle relaxants / Urology
    "baclofen": "BAC",
    "tizanidine": "TZN",
    "tamsulosin": "TAM-S",
    "finasteride": "FIN",
    "dutasteride": "DUT",
    "sildenafil": "SIL",
    "tadalafil": "TDL",

    # Dermatological
    "permethrin": "PERM",
    "benzyl benzoate": "BB",
    "salicylic acid": "SA",
    "benzoyl peroxide": "BPO",
    "tretinoin": "TRT",
    "adapalene": "ADP",
    "silver sulfadiazine": "SSD",
    "fusidic acid": "FA-D",
    "mupirocin": "MUP",
}


def _abbrev_lookup(generic_name: str) -> str:
    """Return shorthand code for a generic name (case-insensitive)."""
    key = generic_name.lower().strip()
    if key in ABBREVIATIONS:
        return ABBREVIATIONS[key]
    no_paren = re.sub(r"\s*\([^)]*\)\s*$", "", key).strip()
    if no_paren and no_paren != key and no_paren in ABBREVIATIONS:
        return ABBREVIATIONS[no_paren]
    first = key.split("/")[0].strip()
    if first != key and first in ABBREVIATIONS:
        return ABBREVIATIONS[first]
    return ""


# ---------------------------------------------------------------------------
# Mapping helpers
# ---------------------------------------------------------------------------

CATEGORY_MAP = {
    "Analgesic / Pain Reliever":    Medication.Category.ANALGESIC,
    "Antibiotic":                   Medication.Category.ANTIBIOTIC,
    "Antifungal":                   Medication.Category.ANTIFUNGAL,
    "Antiviral":                    Medication.Category.ANTIVIRAL,
    "Antiparasitic":                Medication.Category.ANTIPARASITIC,
    "Antimalarial":                 Medication.Category.ANTIMALARIAL,
    "Antituberculosis":             Medication.Category.ANTIBIOTIC,
    "Antiretroviral (ARV)":         Medication.Category.ANTIVIRAL,
    "Antihypertensive":             Medication.Category.ANTIHYPERTENSIVE,
    "Antidiabetic":                 Medication.Category.ANTIDIABETIC,
    "Antihistamine":                Medication.Category.ANTIHISTAMINE,
    "Antacid / GI":                 Medication.Category.ANTACID,
    "Cardiovascular":               Medication.Category.CARDIOVASCULAR,
    "Respiratory":                  Medication.Category.RESPIRATORY,
    "Central Nervous System":       Medication.Category.CNS,
    "Psychiatric":                  Medication.Category.CNS,
    "Hormonal":                     Medication.Category.HORMONE,
    "Contraceptive":                Medication.Category.HORMONE,
    "Vitamin / Supplement":         Medication.Category.VITAMIN,
    "Vaccine":                      Medication.Category.VACCINE,
    "Dermatological":               Medication.Category.DERMATOLOGICAL,
    "Ophthalmic":                   Medication.Category.OPHTHALMIC,
    "ENT (Ear/Nose/Throat)":        Medication.Category.OTHER,
    "Emergency / IV Fluids":        Medication.Category.OTHER,
    "Anticoagulant":                Medication.Category.CARDIOVASCULAR,
    "Diuretic":                     Medication.Category.CARDIOVASCULAR,
    "Oncology":                     Medication.Category.ONCOLOGY,
    "Urology":                      Medication.Category.OTHER,
    "Muscle Relaxant":              Medication.Category.OTHER,
    "Anaesthetic":                  Medication.Category.OTHER,
    "Herbal / Traditional":         Medication.Category.OTHER,
    "Nutrition / Infant Formula":   Medication.Category.VITAMIN,
    "First Aid / Wound Care":       Medication.Category.OTHER,
    "Medical Device / Consumable":  Medication.Category.OTHER,
    "Other":                        Medication.Category.OTHER,
}

UNIT_TO_FORM = {
    "Tablets":      Medication.DosageForm.TABLET,
    "Capsules":     Medication.DosageForm.CAPSULE,
    "Syrup":        Medication.DosageForm.SYRUP,
    "Suspension":   Medication.DosageForm.SUSPENSION,
    "Solution":     Medication.DosageForm.SOLUTION,
    "Injection":    Medication.DosageForm.INJECTION,
    "Vial":         Medication.DosageForm.INJECTION,
    "Ampoule":      Medication.DosageForm.INJECTION,
    "Cream/Gel":    Medication.DosageForm.CREAM,
    "Ointment":     Medication.DosageForm.OINTMENT,
    "Lotion":       Medication.DosageForm.SOLUTION,
    "Drops":        Medication.DosageForm.DROPS,
    "Inhaler":      Medication.DosageForm.INHALER,
    "Nebule":       Medication.DosageForm.SOLUTION,
    "Suppository":  Medication.DosageForm.SUPPOSITORY,
    "Pessary":      Medication.DosageForm.SUPPOSITORY,
    "Powder":       Medication.DosageForm.POWDER,
    "Patch":        Medication.DosageForm.PATCH,
    "IV Bag":       Medication.DosageForm.SOLUTION,
    "Sachet":       Medication.DosageForm.POWDER,
    "Bottle":       Medication.DosageForm.SOLUTION,
    "Box":          Medication.DosageForm.OTHER,
    "Piece":        Medication.DosageForm.OTHER,
    "Roll":         Medication.DosageForm.OTHER,
}

# Trailing dosage-form keywords often baked into the product name.
FORM_WORDS = (
    r"Tablet|Tablets|Capsule|Capsules|Syrup|Suspension|Solution|Injection|"
    r"Inj|Vial|Ampoule|Cream|Gel|Ointment|Lotion|Drops|Drop|Inhaler|"
    r"Nebule|Nebuliser|Suppository|Pessary|Powder|Patch|Sachet|Bottle|"
    r"Box|Piece|Roll|Spray|Lozenge|Pastille|MDI|DPI|IV Infusion|IV|Infusion"
)

# Strength regex: a number (with optional decimal/fraction) followed by
# a unit or %, optionally with a /denominator (e.g. 250mg/5ml, 20/120mg).
STRENGTH_RE = re.compile(
    r"\b("
    r"\d+(?:[.,]\d+)?(?:/\d+(?:[.,]\d+)?)?"        # 250 or 20/120 or 0.5
    r"\s*"
    r"(?:mg|mcg|g|kg|ml|l|iu|u|%|meq|mmol)"        # unit
    r"(?:/\s*\d*\s*(?:ml|tab|dose|kg|hr|h|day))?"  # /5ml, /tab, /dose
    r")\b",
    re.IGNORECASE,
)


def _parse_name(raw: str, unit: str) -> tuple[str, str, str]:
    """
    Split a stock-catalog product name like
        "Amoxicillin 500mg Capsule"
    into (generic_name, strength, dosage_form).

    Falls back to the unit-derived dosage form when the trailing word is
    missing or ambiguous.
    """
    name = raw.strip()

    # 1) extract strength (first match wins)
    strength = ""
    m = STRENGTH_RE.search(name)
    if m:
        strength = re.sub(r"\s+", "", m.group(1))
        name = (name[:m.start()] + " " + name[m.end():]).strip()

    # 2) strip trailing form keyword(s) and any parenthetical qualifier
    form_match = re.search(rf"\b({FORM_WORDS})\b\s*\(?[^)]*\)?\s*$", name, re.IGNORECASE)
    parsed_form = None
    if form_match:
        parsed_form = form_match.group(1).lower()
        name = name[:form_match.start()].strip(" -,")

    # 3) drop a trailing parenthetical qualifier on the generic name
    name = re.sub(r"\s*\([^)]*\)\s*$", "", name).strip(" -,")

    # 4) decide dosage form
    form_lookup = {
        "tablet": Medication.DosageForm.TABLET,
        "tablets": Medication.DosageForm.TABLET,
        "capsule": Medication.DosageForm.CAPSULE,
        "capsules": Medication.DosageForm.CAPSULE,
        "syrup": Medication.DosageForm.SYRUP,
        "suspension": Medication.DosageForm.SUSPENSION,
        "solution": Medication.DosageForm.SOLUTION,
        "injection": Medication.DosageForm.INJECTION,
        "inj": Medication.DosageForm.INJECTION,
        "vial": Medication.DosageForm.INJECTION,
        "ampoule": Medication.DosageForm.INJECTION,
        "cream": Medication.DosageForm.CREAM,
        "gel": Medication.DosageForm.GEL,
        "ointment": Medication.DosageForm.OINTMENT,
        "lotion": Medication.DosageForm.SOLUTION,
        "drops": Medication.DosageForm.DROPS,
        "drop": Medication.DosageForm.DROPS,
        "inhaler": Medication.DosageForm.INHALER,
        "mdi": Medication.DosageForm.INHALER,
        "dpi": Medication.DosageForm.INHALER,
        "nebule": Medication.DosageForm.SOLUTION,
        "nebuliser": Medication.DosageForm.SOLUTION,
        "suppository": Medication.DosageForm.SUPPOSITORY,
        "pessary": Medication.DosageForm.SUPPOSITORY,
        "powder": Medication.DosageForm.POWDER,
        "sachet": Medication.DosageForm.POWDER,
        "patch": Medication.DosageForm.PATCH,
        "spray": Medication.DosageForm.SPRAY,
        "lozenge": Medication.DosageForm.LOZENGE,
        "pastille": Medication.DosageForm.LOZENGE,
        "iv": Medication.DosageForm.SOLUTION,
        "infusion": Medication.DosageForm.SOLUTION,
        "iv infusion": Medication.DosageForm.SOLUTION,
        "bottle": Medication.DosageForm.SOLUTION,
        "box": Medication.DosageForm.OTHER,
        "piece": Medication.DosageForm.OTHER,
        "roll": Medication.DosageForm.OTHER,
    }
    dosage_form = (
        form_lookup.get(parsed_form)
        or UNIT_TO_FORM.get(unit, Medication.DosageForm.OTHER)
    )

    if not name:
        name = raw.strip()

    return name, strength, dosage_form


# ---------------------------------------------------------------------------
# Command
# ---------------------------------------------------------------------------

class Command(BaseCommand):
    help = "Seed the shared Medication catalog from the Kenyan-market pharmacy stock list."

    def add_arguments(self, parser):
        parser.add_argument(
            "--reset",
            action="store_true",
            help="Delete all existing medications before seeding.",
        )
        parser.add_argument(
            "--skip-existing",
            action="store_true",
            help="Skip rows that already exist (matched on generic_name + strength + dosage_form).",
        )

    @transaction.atomic
    def handle(self, *args, **opts):
        reset = opts["reset"]
        skip_existing = opts["skip_existing"]

        if reset:
            removed = Medication.objects.all().delete()[0]
            self.stdout.write(self.style.WARNING(f"Deleted {removed} existing medications."))

        # Build canonical key set for skip-existing
        existing_keys: set[tuple[str, str, str]] = set()
        if skip_existing or not reset:
            existing_keys = set(
                Medication.objects.values_list("generic_name", "strength", "dosage_form")
            )

        to_create: list[Medication] = []
        seen: set[tuple[str, str, str]] = set()
        skipped = 0

        for raw_name, raw_category, raw_unit in STOCK_DATA:
            generic_name, strength, dosage_form = _parse_name(raw_name, raw_unit)
            category = CATEGORY_MAP.get(raw_category, Medication.Category.OTHER)
            key = (generic_name, strength, dosage_form)

            if key in seen:
                continue
            seen.add(key)

            if key in existing_keys:
                skipped += 1
                continue

            to_create.append(Medication(
                generic_name=generic_name,
                abbreviation=_abbrev_lookup(generic_name),
                brand_names=_brand_lookup(generic_name),
                category=category,
                subcategory=raw_category,
                dosage_form=dosage_form,
                strength=strength,
                unit=raw_unit,
                requires_prescription=category in {
                    Medication.Category.ANTIBIOTIC,
                    Medication.Category.ANTIVIRAL,
                    Medication.Category.ANTIMALARIAL,
                    Medication.Category.ANTIHYPERTENSIVE,
                    Medication.Category.ANTIDIABETIC,
                    Medication.Category.CARDIOVASCULAR,
                    Medication.Category.CNS,
                    Medication.Category.HORMONE,
                    Medication.Category.ONCOLOGY,
                    Medication.Category.IMMUNOSUPPRESSANT,
                },
                is_active=True,
            ))

        Medication.objects.bulk_create(to_create, batch_size=500, ignore_conflicts=True)

        self.stdout.write(self.style.SUCCESS(
            f"Seeded {len(to_create)} medications "
            f"({skipped} skipped, {len(seen)} unique source rows, "
            f"{len(STOCK_DATA)} raw rows)."
        ))
