import json
from django.core.management.base import BaseCommand
from medications.models import Medication


MEDICATIONS = [
    {"generic_name": "Paracetamol", "brand_names": ["Panadol", "Tylenol", "Calpol"], "category": "analgesic", "dosage_form": "tablet", "strength": "500mg"},
    {"generic_name": "Paracetamol", "brand_names": ["Panadol Syrup", "Calpol"], "category": "analgesic", "dosage_form": "syrup", "strength": "120mg/5ml"},
    {"generic_name": "Ibuprofen", "brand_names": ["Brufen", "Advil", "Nurofen"], "category": "nsaid", "dosage_form": "tablet", "strength": "400mg"},
    {"generic_name": "Ibuprofen", "brand_names": ["Brufen"], "category": "nsaid", "dosage_form": "suspension", "strength": "100mg/5ml"},
    {"generic_name": "Diclofenac", "brand_names": ["Voltaren", "Cataflam"], "category": "nsaid", "dosage_form": "tablet", "strength": "50mg"},
    {"generic_name": "Diclofenac", "brand_names": ["Voltaren Gel"], "category": "nsaid", "dosage_form": "gel", "strength": "1%"},
    {"generic_name": "Aspirin", "brand_names": ["Disprin", "Bayer Aspirin"], "category": "analgesic", "dosage_form": "tablet", "strength": "300mg"},
    {"generic_name": "Aspirin", "brand_names": ["Cardiprin"], "category": "cardiovascular", "dosage_form": "tablet", "strength": "75mg"},
    {"generic_name": "Tramadol", "brand_names": ["Tramal"], "category": "analgesic", "dosage_form": "capsule", "strength": "50mg", "controlled_substance_class": "Schedule IV"},
    {"generic_name": "Morphine Sulfate", "brand_names": ["MS Contin"], "category": "analgesic", "dosage_form": "tablet", "strength": "10mg", "controlled_substance_class": "Schedule II"},
    {"generic_name": "Codeine Phosphate", "brand_names": ["Codalgin"], "category": "analgesic", "dosage_form": "tablet", "strength": "30mg", "controlled_substance_class": "Schedule V"},
    # Antibiotics
    {"generic_name": "Amoxicillin", "brand_names": ["Amoxil", "Ospamox"], "category": "antibiotic", "dosage_form": "capsule", "strength": "500mg"},
    {"generic_name": "Amoxicillin", "brand_names": ["Amoxil"], "category": "antibiotic", "dosage_form": "suspension", "strength": "250mg/5ml"},
    {"generic_name": "Amoxicillin/Clavulanate", "brand_names": ["Augmentin", "Amoclav"], "category": "antibiotic", "dosage_form": "tablet", "strength": "625mg"},
    {"generic_name": "Azithromycin", "brand_names": ["Zithromax", "Azithral"], "category": "antibiotic", "dosage_form": "tablet", "strength": "500mg"},
    {"generic_name": "Ciprofloxacin", "brand_names": ["Cipro", "Ciproxin"], "category": "antibiotic", "dosage_form": "tablet", "strength": "500mg"},
    {"generic_name": "Metronidazole", "brand_names": ["Flagyl"], "category": "antibiotic", "dosage_form": "tablet", "strength": "400mg"},
    {"generic_name": "Metronidazole", "brand_names": ["Flagyl IV"], "category": "antibiotic", "dosage_form": "injection", "strength": "500mg/100ml"},
    {"generic_name": "Doxycycline", "brand_names": ["Vibramycin"], "category": "antibiotic", "dosage_form": "capsule", "strength": "100mg"},
    {"generic_name": "Ceftriaxone", "brand_names": ["Rocephin"], "category": "antibiotic", "dosage_form": "injection", "strength": "1g"},
    {"generic_name": "Cefuroxime", "brand_names": ["Zinnat", "Zinacef"], "category": "antibiotic", "dosage_form": "tablet", "strength": "500mg"},
    {"generic_name": "Erythromycin", "brand_names": ["Erythrocin", "Eryc"], "category": "antibiotic", "dosage_form": "tablet", "strength": "500mg"},
    {"generic_name": "Cloxacillin", "brand_names": ["Cloxapen"], "category": "antibiotic", "dosage_form": "capsule", "strength": "500mg"},
    {"generic_name": "Gentamicin", "brand_names": ["Garamycin"], "category": "antibiotic", "dosage_form": "injection", "strength": "80mg/2ml"},
    {"generic_name": "Nitrofurantoin", "brand_names": ["Macrobid", "Furadantin"], "category": "antibiotic", "dosage_form": "capsule", "strength": "100mg"},
    {"generic_name": "Cotrimoxazole", "brand_names": ["Septrin", "Bactrim"], "category": "antibiotic", "dosage_form": "tablet", "strength": "960mg"},
    {"generic_name": "Clindamycin", "brand_names": ["Dalacin C"], "category": "antibiotic", "dosage_form": "capsule", "strength": "300mg"},
    {"generic_name": "Flucloxacillin", "brand_names": ["Floxapen"], "category": "antibiotic", "dosage_form": "capsule", "strength": "500mg"},
    # Antimalarials
    {"generic_name": "Artemether/Lumefantrine", "brand_names": ["Coartem", "ALu"], "category": "antimalarial", "dosage_form": "tablet", "strength": "20/120mg"},
    {"generic_name": "Quinine", "brand_names": ["Quinimax"], "category": "antimalarial", "dosage_form": "injection", "strength": "300mg/ml"},
    {"generic_name": "Mefloquine", "brand_names": ["Lariam"], "category": "antimalarial", "dosage_form": "tablet", "strength": "250mg"},
    {"generic_name": "Artesunate", "brand_names": ["Arinate"], "category": "antimalarial", "dosage_form": "injection", "strength": "60mg"},
    # Antifungals
    {"generic_name": "Fluconazole", "brand_names": ["Diflucan"], "category": "antifungal", "dosage_form": "capsule", "strength": "150mg"},
    {"generic_name": "Clotrimazole", "brand_names": ["Canesten"], "category": "antifungal", "dosage_form": "cream", "strength": "1%"},
    {"generic_name": "Ketoconazole", "brand_names": ["Nizoral"], "category": "antifungal", "dosage_form": "tablet", "strength": "200mg"},
    {"generic_name": "Nystatin", "brand_names": ["Mycostatin"], "category": "antifungal", "dosage_form": "suspension", "strength": "100000IU/ml"},
    {"generic_name": "Miconazole", "brand_names": ["Daktarin"], "category": "antifungal", "dosage_form": "cream", "strength": "2%"},
    # Antivirals
    {"generic_name": "Acyclovir", "brand_names": ["Zovirax"], "category": "antiviral", "dosage_form": "tablet", "strength": "400mg"},
    {"generic_name": "Acyclovir", "brand_names": ["Zovirax Cream"], "category": "antiviral", "dosage_form": "cream", "strength": "5%"},
    # Antihistamines
    {"generic_name": "Cetirizine", "brand_names": ["Zyrtec", "Cetrizet"], "category": "antihistamine", "dosage_form": "tablet", "strength": "10mg"},
    {"generic_name": "Loratadine", "brand_names": ["Claritin", "Lorfast"], "category": "antihistamine", "dosage_form": "tablet", "strength": "10mg"},
    {"generic_name": "Chlorpheniramine", "brand_names": ["Piriton", "Chlor-Trimeton"], "category": "antihistamine", "dosage_form": "tablet", "strength": "4mg"},
    {"generic_name": "Fexofenadine", "brand_names": ["Allegra"], "category": "antihistamine", "dosage_form": "tablet", "strength": "180mg"},
    # Antihypertensives
    {"generic_name": "Amlodipine", "brand_names": ["Norvasc", "Amlopin"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "5mg"},
    {"generic_name": "Amlodipine", "brand_names": ["Norvasc"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "10mg"},
    {"generic_name": "Enalapril", "brand_names": ["Renitec", "Vasotec"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "10mg"},
    {"generic_name": "Losartan", "brand_names": ["Cozaar", "Losacar"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "50mg"},
    {"generic_name": "Atenolol", "brand_names": ["Tenormin"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "50mg"},
    {"generic_name": "Hydrochlorothiazide", "brand_names": ["HCT", "Esidrex"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "25mg"},
    {"generic_name": "Nifedipine", "brand_names": ["Adalat"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "20mg"},
    {"generic_name": "Lisinopril", "brand_names": ["Zestril", "Prinivil"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "10mg"},
    {"generic_name": "Captopril", "brand_names": ["Capoten"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "25mg"},
    {"generic_name": "Methyldopa", "brand_names": ["Aldomet"], "category": "antihypertensive", "dosage_form": "tablet", "strength": "250mg"},
    # Cardiovascular
    {"generic_name": "Furosemide", "brand_names": ["Lasix"], "category": "cardiovascular", "dosage_form": "tablet", "strength": "40mg"},
    {"generic_name": "Furosemide", "brand_names": ["Lasix"], "category": "cardiovascular", "dosage_form": "injection", "strength": "20mg/ml"},
    {"generic_name": "Atorvastatin", "brand_names": ["Lipitor"], "category": "cardiovascular", "dosage_form": "tablet", "strength": "20mg"},
    {"generic_name": "Simvastatin", "brand_names": ["Zocor"], "category": "cardiovascular", "dosage_form": "tablet", "strength": "20mg"},
    {"generic_name": "Warfarin", "brand_names": ["Coumadin", "Marevan"], "category": "cardiovascular", "dosage_form": "tablet", "strength": "5mg"},
    {"generic_name": "Digoxin", "brand_names": ["Lanoxin"], "category": "cardiovascular", "dosage_form": "tablet", "strength": "0.25mg"},
    {"generic_name": "Spironolactone", "brand_names": ["Aldactone"], "category": "cardiovascular", "dosage_form": "tablet", "strength": "25mg"},
    {"generic_name": "Clopidogrel", "brand_names": ["Plavix"], "category": "cardiovascular", "dosage_form": "tablet", "strength": "75mg"},
    # Antidiabetics
    {"generic_name": "Metformin", "brand_names": ["Glucophage", "Daonil"], "category": "antidiabetic", "dosage_form": "tablet", "strength": "500mg"},
    {"generic_name": "Metformin", "brand_names": ["Glucophage"], "category": "antidiabetic", "dosage_form": "tablet", "strength": "850mg"},
    {"generic_name": "Glibenclamide", "brand_names": ["Daonil", "Glyburide"], "category": "antidiabetic", "dosage_form": "tablet", "strength": "5mg"},
    {"generic_name": "Glimepiride", "brand_names": ["Amaryl"], "category": "antidiabetic", "dosage_form": "tablet", "strength": "2mg"},
    {"generic_name": "Insulin (Soluble)", "brand_names": ["Actrapid", "Humulin R"], "category": "antidiabetic", "dosage_form": "injection", "strength": "100IU/ml"},
    {"generic_name": "Insulin (NPH)", "brand_names": ["Insulatard", "Humulin N"], "category": "antidiabetic", "dosage_form": "injection", "strength": "100IU/ml"},
    {"generic_name": "Insulin Glargine", "brand_names": ["Lantus"], "category": "antidiabetic", "dosage_form": "injection", "strength": "100IU/ml"},
    # GI / Antacids
    {"generic_name": "Omeprazole", "brand_names": ["Losec", "Prilosec"], "category": "antacid", "dosage_form": "capsule", "strength": "20mg"},
    {"generic_name": "Pantoprazole", "brand_names": ["Controloc", "Protonix"], "category": "antacid", "dosage_form": "tablet", "strength": "40mg"},
    {"generic_name": "Ranitidine", "brand_names": ["Zantac"], "category": "antacid", "dosage_form": "tablet", "strength": "150mg"},
    {"generic_name": "Magnesium Trisilicate", "brand_names": ["Gelusil"], "category": "antacid", "dosage_form": "tablet", "strength": "500mg"},
    {"generic_name": "Loperamide", "brand_names": ["Imodium"], "category": "antacid", "dosage_form": "capsule", "strength": "2mg"},
    {"generic_name": "Metoclopramide", "brand_names": ["Plasil", "Maxolon"], "category": "antacid", "dosage_form": "tablet", "strength": "10mg"},
    {"generic_name": "Ondansetron", "brand_names": ["Zofran"], "category": "antacid", "dosage_form": "tablet", "strength": "8mg"},
    {"generic_name": "Domperidone", "brand_names": ["Motilium"], "category": "antacid", "dosage_form": "tablet", "strength": "10mg"},
    {"generic_name": "Hyoscine Butylbromide", "brand_names": ["Buscopan"], "category": "antacid", "dosage_form": "tablet", "strength": "10mg"},
    {"generic_name": "ORS (Oral Rehydration Salts)", "brand_names": ["ORS"], "category": "antacid", "dosage_form": "powder", "strength": "20.5g/L"},
    # Respiratory
    {"generic_name": "Salbutamol", "brand_names": ["Ventolin"], "category": "respiratory", "dosage_form": "inhaler", "strength": "100mcg"},
    {"generic_name": "Salbutamol", "brand_names": ["Ventolin Nebule"], "category": "respiratory", "dosage_form": "solution", "strength": "5mg/ml"},
    {"generic_name": "Beclometasone", "brand_names": ["Becotide", "Qvar"], "category": "respiratory", "dosage_form": "inhaler", "strength": "250mcg"},
    {"generic_name": "Aminophylline", "brand_names": ["Phyllocontin"], "category": "respiratory", "dosage_form": "tablet", "strength": "100mg"},
    {"generic_name": "Salbutamol", "brand_names": ["Ventolin Syrup"], "category": "respiratory", "dosage_form": "syrup", "strength": "2mg/5ml"},
    {"generic_name": "Prednisolone", "brand_names": ["Deltasone"], "category": "hormone", "dosage_form": "tablet", "strength": "5mg"},
    {"generic_name": "Dexamethasone", "brand_names": ["Decadron"], "category": "hormone", "dosage_form": "tablet", "strength": "4mg"},
    {"generic_name": "Dexamethasone", "brand_names": ["Decadron"], "category": "hormone", "dosage_form": "injection", "strength": "4mg/ml"},
    {"generic_name": "Hydrocortisone", "brand_names": ["Solu-Cortef"], "category": "hormone", "dosage_form": "injection", "strength": "100mg"},
    {"generic_name": "Hydrocortisone", "brand_names": ["HC Cream"], "category": "dermatological", "dosage_form": "cream", "strength": "1%"},
    # CNS
    {"generic_name": "Diazepam", "brand_names": ["Valium"], "category": "cns", "dosage_form": "tablet", "strength": "5mg", "controlled_substance_class": "Schedule IV"},
    {"generic_name": "Carbamazepine", "brand_names": ["Tegretol"], "category": "cns", "dosage_form": "tablet", "strength": "200mg"},
    {"generic_name": "Phenytoin", "brand_names": ["Dilantin", "Epanutin"], "category": "cns", "dosage_form": "tablet", "strength": "100mg"},
    {"generic_name": "Sodium Valproate", "brand_names": ["Epilim", "Depakene"], "category": "cns", "dosage_form": "tablet", "strength": "200mg"},
    {"generic_name": "Amitriptyline", "brand_names": ["Elavil", "Tryptanol"], "category": "cns", "dosage_form": "tablet", "strength": "25mg"},
    {"generic_name": "Fluoxetine", "brand_names": ["Prozac"], "category": "cns", "dosage_form": "capsule", "strength": "20mg"},
    {"generic_name": "Haloperidol", "brand_names": ["Haldol"], "category": "cns", "dosage_form": "tablet", "strength": "5mg"},
    {"generic_name": "Chlorpromazine", "brand_names": ["Largactil"], "category": "cns", "dosage_form": "tablet", "strength": "100mg"},
    # Vitamins & Supplements
    {"generic_name": "Ferrous Sulfate", "brand_names": ["FeSO4"], "category": "vitamin", "dosage_form": "tablet", "strength": "200mg"},
    {"generic_name": "Folic Acid", "brand_names": ["Folvite"], "category": "vitamin", "dosage_form": "tablet", "strength": "5mg"},
    {"generic_name": "Vitamin B Complex", "brand_names": ["Neurobion"], "category": "vitamin", "dosage_form": "tablet", "strength": ""},
    {"generic_name": "Vitamin C (Ascorbic Acid)", "brand_names": ["Celin"], "category": "vitamin", "dosage_form": "tablet", "strength": "500mg"},
    {"generic_name": "Multivitamin", "brand_names": ["Centrum", "Supradyn"], "category": "vitamin", "dosage_form": "tablet", "strength": ""},
    {"generic_name": "Calcium + Vitamin D3", "brand_names": ["Caltrate", "Shelcal"], "category": "vitamin", "dosage_form": "tablet", "strength": "500mg/250IU"},
    {"generic_name": "Zinc Sulfate", "brand_names": ["Zincovit"], "category": "vitamin", "dosage_form": "tablet", "strength": "20mg"},
    # Hormonal
    {"generic_name": "Levothyroxine", "brand_names": ["Eltroxin", "Synthroid"], "category": "hormone", "dosage_form": "tablet", "strength": "50mcg"},
    {"generic_name": "Levonorgestrel", "brand_names": ["Postinor-2"], "category": "hormone", "dosage_form": "tablet", "strength": "0.75mg"},
    {"generic_name": "Combined OCP (Ethinylestradiol/Levonorgestrel)", "brand_names": ["Microgynon"], "category": "hormone", "dosage_form": "tablet", "strength": "0.03/0.15mg"},
    {"generic_name": "Oxytocin", "brand_names": ["Pitocin"], "category": "hormone", "dosage_form": "injection", "strength": "10IU/ml"},
    {"generic_name": "Medroxyprogesterone", "brand_names": ["Depo-Provera"], "category": "hormone", "dosage_form": "injection", "strength": "150mg/ml"},
    # Antiparasitics
    {"generic_name": "Albendazole", "brand_names": ["Zentel"], "category": "antiparasitic", "dosage_form": "tablet", "strength": "400mg"},
    {"generic_name": "Mebendazole", "brand_names": ["Vermox"], "category": "antiparasitic", "dosage_form": "tablet", "strength": "100mg"},
    {"generic_name": "Praziquantel", "brand_names": ["Biltricide"], "category": "antiparasitic", "dosage_form": "tablet", "strength": "600mg"},
    {"generic_name": "Ivermectin", "brand_names": ["Stromectol", "Mectizan"], "category": "antiparasitic", "dosage_form": "tablet", "strength": "3mg"},
    {"generic_name": "Permethrin", "brand_names": ["Lyclear"], "category": "antiparasitic", "dosage_form": "cream", "strength": "5%"},
    # Dermatological
    {"generic_name": "Betamethasone", "brand_names": ["Betnovate"], "category": "dermatological", "dosage_form": "cream", "strength": "0.1%"},
    {"generic_name": "Silver Sulfadiazine", "brand_names": ["Flamazine"], "category": "dermatological", "dosage_form": "cream", "strength": "1%"},
    {"generic_name": "Calamine Lotion", "brand_names": ["Calamine"], "category": "dermatological", "dosage_form": "solution", "strength": ""},
    {"generic_name": "Benzoyl Peroxide", "brand_names": ["Benzac"], "category": "dermatological", "dosage_form": "gel", "strength": "5%"},
    # Ophthalmic
    {"generic_name": "Chloramphenicol Eye Drops", "brand_names": ["Chlorsig"], "category": "ophthalmic", "dosage_form": "drops", "strength": "0.5%"},
    {"generic_name": "Gentamicin Eye Drops", "brand_names": ["Garamycin Eye"], "category": "ophthalmic", "dosage_form": "drops", "strength": "0.3%"},
    {"generic_name": "Timolol Eye Drops", "brand_names": ["Timoptol"], "category": "ophthalmic", "dosage_form": "drops", "strength": "0.5%"},
    {"generic_name": "Tetracaine Eye Drops", "brand_names": ["Minims Amethocaine"], "category": "ophthalmic", "dosage_form": "drops", "strength": "1%"},
    # Emergency / Other
    {"generic_name": "Adrenaline (Epinephrine)", "brand_names": ["EpiPen"], "category": "cardiovascular", "dosage_form": "injection", "strength": "1mg/ml"},
    {"generic_name": "Atropine", "brand_names": ["Atropine Sulfate"], "category": "cardiovascular", "dosage_form": "injection", "strength": "0.6mg/ml"},
    {"generic_name": "Lidocaine", "brand_names": ["Xylocaine"], "category": "analgesic", "dosage_form": "injection", "strength": "2%"},
    {"generic_name": "Normal Saline", "brand_names": ["NS 0.9%"], "category": "other", "dosage_form": "solution", "strength": "0.9%"},
    {"generic_name": "Ringer's Lactate", "brand_names": ["Hartmann's Solution"], "category": "other", "dosage_form": "solution", "strength": ""},
    {"generic_name": "Dextrose", "brand_names": ["D5W"], "category": "other", "dosage_form": "solution", "strength": "5%"},
]


class Command(BaseCommand):
    help = 'Seed the global medication pool with common medications'

    def handle(self, *args, **options):
        created_count = 0
        for med_data in MEDICATIONS:
            _, created = Medication.objects.get_or_create(
                generic_name=med_data['generic_name'],
                dosage_form=med_data['dosage_form'],
                strength=med_data.get('strength', ''),
                defaults={
                    'brand_names': med_data.get('brand_names', []),
                    'category': med_data.get('category', 'other'),
                    'controlled_substance_class': med_data.get('controlled_substance_class', ''),
                    'requires_prescription': med_data.get('category') != 'vitamin',
                },
            )
            if created:
                created_count += 1

        self.stdout.write(self.style.SUCCESS(
            f'Seeded {created_count} medications (total: {Medication.objects.count()})'
        ))
