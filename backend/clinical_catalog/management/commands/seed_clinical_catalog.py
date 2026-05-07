"""
Seed command for the clinical catalog: Allergies and Chronic Conditions.

Usage:
    python manage.py seed_clinical_catalog
    python manage.py seed_clinical_catalog --clear   # drops all existing records first
"""

from django.core.management.base import BaseCommand
from clinical_catalog.models import Allergy, ChronicCondition


# ─────────────────────────────────────────────────────────────────────────────
# Allergy seed data
# ─────────────────────────────────────────────────────────────────────────────

ALLERGIES = [
    # ── Drug / Medication ──────────────────────────────────────────────────
    ('Penicillin', 'drug', 'Antibiotic in the beta-lactam family.',
     'Rash, hives, itching, shortness of breath, anaphylaxis'),
    ('Amoxicillin', 'drug', 'Beta-lactam antibiotic related to penicillin.',
     'Rash, hives, itching, anaphylaxis'),
    ('Ampicillin', 'drug', 'Broad-spectrum beta-lactam antibiotic.',
     'Rash, diarrhea, anaphylaxis'),
    ('Cephalosporins', 'drug', 'Antibiotic class closely related to penicillins.',
     'Rash, hives, anaphylaxis'),
    ('Sulfonamides (Sulfa drugs)', 'drug', 'Antibiotics including co-trimoxazole.',
     'Rash, Stevens-Johnson syndrome, photosensitivity'),
    ('Tetracyclines', 'drug', 'Broad-spectrum antibiotics (e.g. doxycycline).',
     'Rash, photosensitivity, nausea'),
    ('Fluoroquinolones', 'drug', 'Antibiotics including ciprofloxacin, levofloxacin.',
     'Rash, tendon rupture, peripheral neuropathy'),
    ('Metronidazole', 'drug', 'Antibiotic / antiprotozoal.',
     'Nausea, metallic taste, rash'),
    ('Vancomycin', 'drug', 'Glycopeptide antibiotic.',
     'Red man syndrome (flushing, rash), hypotension'),
    ('Erythromycin / Macrolides', 'drug', 'Macrolide antibiotic class.',
     'Nausea, abdominal cramps, rash'),
    ('Aspirin', 'drug', 'Non-steroidal anti-inflammatory drug (NSAID).',
     'Hives, angioedema, bronchospasm, anaphylaxis'),
    ('Ibuprofen', 'drug', 'Common NSAID analgesic.',
     'Hives, angioedema, bronchospasm'),
    ('Naproxen', 'drug', 'NSAID analgesic / anti-inflammatory.',
     'Rash, hives, bronchospasm'),
    ('NSAIDs (General)', 'drug', 'Non-selective NSAID class allergy.',
     'Hives, angioedema, asthma exacerbation'),
    ('Codeine', 'drug', 'Opioid analgesic.',
     'Rash, itching, nausea, constipation'),
    ('Morphine', 'drug', 'Opioid analgesic.',
     'Rash, itching, hives, hypotension'),
    ('Tramadol', 'drug', 'Opioid-like analgesic.',
     'Rash, seizure risk, serotonin syndrome'),
    ('Opioids (General)', 'drug', 'Class allergy to opioid analgesics.',
     'Rash, itching, nausea, respiratory depression'),
    ('Insulin', 'drug', 'Hormone used in diabetes management.',
     'Local skin reaction, lipodystrophy, anaphylaxis (rare)'),
    ('Metformin', 'drug', 'Biguanide antidiabetic agent.',
     'Gastrointestinal upset, lactic acidosis (rare)'),
    ('ACE Inhibitors', 'drug', 'Antihypertensive drug class (e.g. enalapril, lisinopril).',
     'Dry cough, angioedema'),
    ('Angiotensin Receptor Blockers (ARBs)', 'drug',
     'Antihypertensive drug class (e.g. losartan).',
     'Angioedema (rare), dizziness'),
    ('Beta-Blockers', 'drug', 'Antihypertensive / cardiac drug class.',
     'Bradycardia, bronchospasm, fatigue'),
    ('Statins', 'drug', 'Cholesterol-lowering agents (e.g. atorvastatin).',
     'Myopathy, rhabdomyolysis, elevated liver enzymes'),
    ('Allopurinol', 'drug', 'Urate-lowering therapy for gout.',
     'Stevens-Johnson syndrome, DRESS syndrome, rash'),
    ('Carbamazepine', 'drug', 'Anticonvulsant / mood stabiliser.',
     'Stevens-Johnson syndrome, DRESS, rash'),
    ('Phenytoin', 'drug', 'Anticonvulsant.',
     'Rash, gingival hyperplasia, Stevens-Johnson syndrome'),
    ('Phenobarbital', 'drug', 'Barbiturate anticonvulsant.',
     'Rash, drowsiness, Stevens-Johnson syndrome'),
    ('Lamotrigine', 'drug', 'Anticonvulsant / mood stabiliser.',
     'Rash, Stevens-Johnson syndrome'),
    ('Iodine-based Contrast Dye', 'contrast', 'Used in CT and angiographic procedures.',
     'Flushing, urticaria, anaphylaxis, nephrotoxicity'),
    ('Gadolinium Contrast Agent', 'contrast', 'MRI contrast agent.',
     'Nausea, headache, nephrogenic systemic fibrosis'),
    ('Local Anaesthetics (Ester-type)', 'drug',
     'e.g. procaine, benzocaine.',
     'Contact dermatitis, anaphylaxis'),
    ('Local Anaesthetics (Amide-type)', 'drug',
     'e.g. lidocaine, bupivacaine.',
     'Hypotension, seizure, cardiac arrhythmia (high dose)'),
    ('Chlorhexidine', 'chemical', 'Antiseptic used in surgical prep and wound care.',
     'Anaphylaxis, contact dermatitis'),

    # ── Food ──────────────────────────────────────────────────────────────
    ('Peanuts', 'food', 'A legume; one of the most common severe food allergens.',
     'Hives, angioedema, anaphylaxis'),
    ('Tree Nuts', 'food',
     'Includes almonds, cashews, walnuts, pistachios, Brazil nuts, hazelnuts, pecans.',
     'Hives, angioedema, anaphylaxis'),
    ('Almonds', 'food', 'Tree nut.',
     'Hives, oral allergy syndrome, anaphylaxis'),
    ('Cashews', 'food', 'Tree nut.',
     'Hives, angioedema, anaphylaxis'),
    ('Walnuts', 'food', 'Tree nut.',
     'Hives, oral allergy syndrome, anaphylaxis'),
    ('Shellfish (Crustacean)', 'food', 'Shrimp, crab, lobster, crayfish.',
     'Hives, vomiting, anaphylaxis'),
    ('Shellfish (Molluscs)', 'food', 'Clams, oysters, scallops, mussels, squid.',
     'Hives, vomiting, anaphylaxis'),
    ('Fish', 'food', 'Finned fish including cod, salmon, tuna, tilapia, halibut.',
     'Hives, vomiting, anaphylaxis'),
    ('Milk / Dairy', 'food', 'Cow\'s milk and products containing milk proteins.',
     'Hives, vomiting, diarrhoea, anaphylaxis'),
    ('Eggs', 'food', 'Hen\'s eggs (white or yolk).',
     'Hives, eczema, vomiting, anaphylaxis'),
    ('Wheat / Gluten', 'food', 'Wheat-based products; distinct from coeliac disease.',
     'Hives, abdominal pain, diarrhoea, anaphylaxis'),
    ('Soy', 'food', 'Soy and soy-derived products.',
     'Hives, eczema, vomiting, diarrhoea'),
    ('Sesame', 'food', 'Sesame seeds and sesame oil.',
     'Hives, angioedema, anaphylaxis'),
    ('Mustard', 'food', 'Mustard seed and condiments.',
     'Hives, angioedema, anaphylaxis'),
    ('Celery', 'food', 'Celery stalk, leaves, and seeds.',
     'Oral allergy syndrome, urticaria, anaphylaxis'),
    ('Lupin', 'food', 'Lupin flour and seeds used in some breads and pastas.',
     'Hives, angioedema, anaphylaxis'),
    ('Sulphites / Sulfites', 'food',
     'Preservatives found in wine, dried fruit, processed foods.',
     'Bronchospasm, urticaria, anaphylaxis'),
    ('Corn / Maize', 'food', 'Corn and corn-derived ingredients.',
     'Urticaria, abdominal pain, anaphylaxis (rare)'),
    ('Banana', 'food', 'Banana; associated with latex cross-reactivity.',
     'Oral itching, urticaria, anaphylaxis'),
    ('Kiwi', 'food', 'Kiwi fruit; associated with latex cross-reactivity.',
     'Oral allergy syndrome, urticaria, anaphylaxis'),
    ('Avocado', 'food', 'Avocado; associated with latex cross-reactivity.',
     'Oral allergy syndrome, urticaria'),

    # ── Environmental ─────────────────────────────────────────────────────
    ('Grass Pollen', 'environmental', 'Pollen from grasses (ryegrass, Bermuda grass, etc.).',
     'Rhinitis, sneezing, itchy eyes, asthma'),
    ('Tree Pollen', 'environmental', 'Pollen from trees (birch, oak, cedar, olive, etc.).',
     'Rhinitis, sneezing, itchy eyes, asthma'),
    ('Weed Pollen', 'environmental', 'Pollen from weeds (ragweed, mugwort, pellitory).',
     'Rhinitis, sneezing, itchy eyes, asthma'),
    ('House Dust Mites', 'environmental', 'Dermatophagoides pteronyssinus and farinae.',
     'Rhinitis, sneezing, asthma, eczema'),
    ('Cat Dander', 'environmental', 'Allergens from cat skin, saliva, and urine.',
     'Rhinitis, itchy eyes, asthma, urticaria'),
    ('Dog Dander', 'environmental', 'Allergens from dog skin, saliva, and urine.',
     'Rhinitis, itchy eyes, asthma'),
    ('Cockroach', 'environmental', 'Cockroach droppings and body parts.',
     'Rhinitis, asthma, eczema'),
    ('Mold / Mould Spores', 'environmental', 'Aspergillus, Cladosporium, Alternaria, Penicillium.',
     'Rhinitis, asthma, sinusitis'),
    ('Nickel', 'chemical', 'Metal found in jewellery, belts, coins.',
     'Contact dermatitis, itching, rash at contact site'),
    ('Formaldehyde', 'chemical', 'Chemical used in preservatives and building materials.',
     'Contact dermatitis, rhinitis, asthma'),
    ('Fragrance / Perfume', 'chemical', 'Synthetic or natural aromatic compounds.',
     'Contact dermatitis, rhinitis, migraines'),
    ('Hair Dye (PPD)', 'chemical', 'Para-phenylenediamine in permanent hair dyes.',
     'Severe scalp/face dermatitis, angioedema'),
    ('Rubber Latex', 'latex', 'Natural rubber latex from Hevea brasiliensis.',
     'Urticaria, rhinitis, asthma, anaphylaxis'),

    # ── Insect / Venom ────────────────────────────────────────────────────
    ('Bee Sting (Honey Bee)', 'insect', 'Venom from Apis mellifera.',
     'Local swelling, urticaria, anaphylaxis'),
    ('Wasp / Yellow Jacket Sting', 'insect', 'Venom from Vespula species.',
     'Local swelling, urticaria, anaphylaxis'),
    ('Hornet Sting', 'insect', 'Venom from hornets.',
     'Local swelling, urticaria, anaphylaxis'),
    ('Fire Ant Sting', 'insect', 'Solenopsis invicta venom.',
     'Pustules, urticaria, anaphylaxis'),
    ('Mosquito Bite', 'insect', 'Salivary proteins from mosquito bite.',
     'Local swelling, papular urticaria'),
]

# ─────────────────────────────────────────────────────────────────────────────
# Chronic Condition seed data
# ─────────────────────────────────────────────────────────────────────────────

CHRONIC_CONDITIONS = [
    # ── Cardiovascular ─────────────────────────────────────────────────────
    ('Hypertension (High Blood Pressure)', 'cardiovascular', 'I10',
     'Persistently elevated arterial blood pressure (≥140/90 mmHg).'),
    ('Coronary Artery Disease (CAD)', 'cardiovascular', 'I25',
     'Narrowing or blockage of coronary arteries due to atherosclerosis.'),
    ('Heart Failure', 'cardiovascular', 'I50',
     'Inability of the heart to pump sufficient blood to meet the body\'s demands.'),
    ('Atrial Fibrillation', 'cardiovascular', 'I48',
     'Irregular and often rapid heart rate due to disorganised electrical signals.'),
    ('Peripheral Artery Disease (PAD)', 'cardiovascular', 'I70',
     'Narrowing of peripheral arteries causing reduced blood flow to limbs.'),
    ('Cardiomyopathy', 'cardiovascular', 'I42',
     'Disease of the heart muscle affecting its size, shape, or function.'),
    ('Rheumatic Heart Disease', 'cardiovascular', 'I09',
     'Valvular damage caused by rheumatic fever.'),
    ('Deep Vein Thrombosis (DVT)', 'cardiovascular', 'I82',
     'Blood clot formation in a deep vein, usually the leg.'),
    ('Pulmonary Embolism', 'cardiovascular', 'I26',
     'Blockage of a pulmonary artery by a blood clot.'),
    ('Hyperlipidaemia / High Cholesterol', 'cardiovascular', 'E78',
     'Elevated levels of lipids (cholesterol and/or triglycerides) in the blood.'),
    ('Stroke (Cerebrovascular Disease)', 'cardiovascular', 'I69',
     'Brain injury caused by interruption or rupture of blood supply.'),

    # ── Endocrine / Metabolic ──────────────────────────────────────────────
    ('Type 1 Diabetes Mellitus', 'endocrine', 'E10',
     'Autoimmune destruction of pancreatic beta cells resulting in absolute insulin deficiency.'),
    ('Type 2 Diabetes Mellitus', 'endocrine', 'E11',
     'Insulin resistance and progressive insulin secretory defect.'),
    ('Gestational Diabetes', 'endocrine', 'O24',
     'Glucose intolerance first recognised during pregnancy.'),
    ('Hypothyroidism', 'endocrine', 'E03',
     'Underactive thyroid gland with insufficient thyroid hormone production.'),
    ('Hyperthyroidism / Graves\' Disease', 'endocrine', 'E05',
     'Overactive thyroid gland producing excess thyroid hormones.'),
    ('Cushing\'s Syndrome', 'endocrine', 'E24',
     'Excess cortisol exposure from endogenous or exogenous sources.'),
    ('Addison\'s Disease (Adrenal Insufficiency)', 'endocrine', 'E27',
     'Insufficient production of cortisol and often aldosterone by the adrenal glands.'),
    ('Polycystic Ovary Syndrome (PCOS)', 'endocrine', 'E28',
     'Hormonal disorder causing enlarged ovaries with small cysts.'),
    ('Obesity', 'endocrine', 'E66',
     'Excess body fat accumulation with BMI ≥30 kg/m².'),
    ('Metabolic Syndrome', 'endocrine', 'E88',
     'Cluster of conditions including hypertension, hyperglycaemia, dyslipidaemia, and central obesity.'),
    ('Gout', 'musculoskeletal', 'M10',
     'Crystal arthropathy caused by hyperuricaemia and urate crystal deposition.'),
    ('Hyperuricaemia', 'endocrine', 'E79',
     'Elevated uric acid levels in the blood.'),

    # ── Respiratory ───────────────────────────────────────────────────────
    ('Asthma', 'respiratory', 'J45',
     'Chronic inflammatory airway disease with reversible bronchospasm and airway hyperresponsiveness.'),
    ('Chronic Obstructive Pulmonary Disease (COPD)', 'respiratory', 'J44',
     'Progressive airflow limitation due to emphysema and/or chronic bronchitis.'),
    ('Chronic Bronchitis', 'respiratory', 'J42',
     'Persistent productive cough for at least 3 months in 2 consecutive years.'),
    ('Emphysema', 'respiratory', 'J43',
     'Destruction of alveolar walls causing impaired gas exchange.'),
    ('Pulmonary Fibrosis (IPF)', 'respiratory', 'J84',
     'Progressive scarring of lung tissue of unknown cause.'),
    ('Obstructive Sleep Apnoea', 'respiratory', 'G47',
     'Repeated upper airway obstruction during sleep.'),
    ('Bronchiectasis', 'respiratory', 'J47',
     'Permanent dilation of bronchi due to chronic infection or inflammation.'),
    ('Pulmonary Hypertension', 'respiratory', 'I27',
     'Elevated blood pressure in the pulmonary arteries.'),
    ('Sarcoidosis', 'respiratory', 'D86',
     'Multisystem granulomatous disease most commonly affecting the lungs.'),
    ('Cystic Fibrosis', 'respiratory', 'J98',
     'Genetic disorder causing thick mucus buildup in the lungs and digestive tract.'),

    # ── Neurological ──────────────────────────────────────────────────────
    ('Epilepsy', 'neurological', 'G40',
     'Recurrent unprovoked seizures due to abnormal brain electrical activity.'),
    ('Parkinson\'s Disease', 'neurological', 'G20',
     'Progressive neurodegenerative disorder affecting movement and dopamine pathways.'),
    ('Multiple Sclerosis (MS)', 'neurological', 'G35',
     'Autoimmune demyelinating disease of the central nervous system.'),
    ('Alzheimer\'s Disease', 'neurological', 'G30',
     'Most common form of dementia; progressive neurodegeneration and cognitive decline.'),
    ('Chronic Migraine', 'neurological', 'G43',
     'Recurrent moderate-to-severe headaches, often with nausea and photophobia.'),
    ('Peripheral Neuropathy', 'neurological', 'G62',
     'Damage to peripheral nerves causing weakness, numbness, and pain.'),
    ('Myasthenia Gravis', 'neurological', 'G70',
     'Autoimmune disorder of neuromuscular transmission causing muscle weakness.'),
    ('Huntington\'s Disease', 'neurological', 'G10',
     'Inherited neurodegenerative disorder causing progressive motor and cognitive decline.'),
    ('Amyotrophic Lateral Sclerosis (ALS)', 'neurological', 'G12',
     'Progressive degeneration of motor neurons.'),
    ('Narcolepsy', 'neurological', 'G47',
     'Chronic sleep disorder causing overwhelming daytime drowsiness and sudden sleep attacks.'),

    # ── Musculoskeletal ───────────────────────────────────────────────────
    ('Rheumatoid Arthritis', 'musculoskeletal', 'M05',
     'Autoimmune inflammatory arthritis primarily affecting synovial joints.'),
    ('Osteoarthritis', 'musculoskeletal', 'M19',
     'Degenerative joint disease with cartilage breakdown.'),
    ('Osteoporosis', 'musculoskeletal', 'M81',
     'Reduced bone mineral density increasing fracture risk.'),
    ('Ankylosing Spondylitis', 'musculoskeletal', 'M45',
     'Chronic inflammatory arthritis of the spine and sacroiliac joints.'),
    ('Systemic Lupus Erythematosus (SLE)', 'musculoskeletal', 'M32',
     'Systemic autoimmune disease affecting skin, joints, kidneys, and other organs.'),
    ('Fibromyalgia', 'musculoskeletal', 'M79',
     'Widespread musculoskeletal pain with fatigue, sleep, and cognitive disturbances.'),
    ('Psoriatic Arthritis', 'musculoskeletal', 'M07',
     'Inflammatory arthritis associated with psoriasis.'),
    ('Systemic Sclerosis (Scleroderma)', 'musculoskeletal', 'M34',
     'Autoimmune connective tissue disease causing fibrosis and vascular abnormalities.'),
    ('Polymyalgia Rheumatica', 'musculoskeletal', 'M35',
     'Inflammatory disorder causing pain in the shoulders, neck, and hips.'),
    ('Reactive Arthritis', 'musculoskeletal', 'M02',
     'Arthritis triggered by an infection elsewhere in the body.'),

    # ── Gastrointestinal ─────────────────────────────────────────────────
    ('Crohn\'s Disease', 'gastrointestinal', 'K50',
     'Chronic transmural inflammatory bowel disease affecting any part of the GI tract.'),
    ('Ulcerative Colitis', 'gastrointestinal', 'K51',
     'Chronic mucosal inflammatory bowel disease limited to the colon and rectum.'),
    ('Irritable Bowel Syndrome (IBS)', 'gastrointestinal', 'K58',
     'Functional bowel disorder with abdominal pain and altered bowel habits.'),
    ('Gastroesophageal Reflux Disease (GERD)', 'gastrointestinal', 'K21',
     'Chronic reflux of gastric contents into the oesophagus.'),
    ('Coeliac Disease', 'gastrointestinal', 'K90',
     'Autoimmune enteropathy triggered by gluten ingestion.'),
    ('Liver Cirrhosis', 'gastrointestinal', 'K74',
     'Late-stage scarring of the liver from various causes.'),
    ('Non-Alcoholic Fatty Liver Disease (NAFLD)', 'gastrointestinal', 'K76',
     'Accumulation of excess fat in the liver not caused by alcohol.'),
    ('Peptic Ulcer Disease', 'gastrointestinal', 'K27',
     'Ulcers in the stomach or duodenum, often related to H. pylori or NSAIDs.'),
    ('Chronic Pancreatitis', 'gastrointestinal', 'K86',
     'Progressive inflammation and fibrosis of the pancreas.'),
    ('Haemochromatosis', 'gastrointestinal', 'E83',
     'Genetic disorder causing iron overload in organs.'),
    ('Primary Biliary Cholangitis', 'gastrointestinal', 'K74',
     'Autoimmune destruction of bile ducts in the liver.'),

    # ── Renal / Urological ────────────────────────────────────────────────
    ('Chronic Kidney Disease (CKD)', 'renal', 'N18',
     'Progressive loss of kidney function over months or years.'),
    ('Nephrotic Syndrome', 'renal', 'N04',
     'Heavy proteinuria, oedema, and hypoalbuminaemia due to glomerular disease.'),
    ('Polycystic Kidney Disease (PKD)', 'renal', 'Q61',
     'Genetic disorder with multiple fluid-filled cysts in the kidneys.'),
    ('Urolithiasis (Kidney Stones)', 'renal', 'N20',
     'Formation of calculi in the urinary tract.'),
    ('Chronic Urinary Tract Infection', 'renal', 'N30',
     'Recurrent infections of the urinary system.'),
    ('Benign Prostatic Hyperplasia (BPH)', 'renal', 'N40',
     'Non-cancerous enlargement of the prostate gland causing urinary symptoms.'),
    ('Interstitial Cystitis', 'renal', 'N30',
     'Chronic bladder pain syndrome without infection.'),

    # ── Hematological ─────────────────────────────────────────────────────
    ('Sickle Cell Disease', 'hematological', 'D57',
     'Inherited red blood cell disorder causing haemolytic anaemia and vaso-occlusive crises.'),
    ('Thalassaemia', 'hematological', 'D56',
     'Inherited blood disorder causing reduced or absent haemoglobin production.'),
    ('Haemophilia A', 'hematological', 'D66',
     'X-linked coagulation disorder due to Factor VIII deficiency.'),
    ('Haemophilia B', 'hematological', 'D67',
     'X-linked coagulation disorder due to Factor IX deficiency.'),
    ('Iron Deficiency Anaemia', 'hematological', 'D50',
     'Anaemia due to insufficient iron for haemoglobin synthesis.'),
    ('Pernicious Anaemia (B12 Deficiency)', 'hematological', 'D51',
     'Megaloblastic anaemia due to vitamin B12 deficiency from intrinsic factor lack.'),
    ('Thrombocytopenia', 'hematological', 'D69',
     'Abnormally low platelet count increasing bleeding risk.'),
    ('Polycythaemia Vera', 'hematological', 'D45',
     'Myeloproliferative neoplasm with overproduction of red blood cells.'),
    ('Chronic Myeloid Leukaemia (CML)', 'hematological', 'C92',
     'Myeloproliferative neoplasm driven by the BCR-ABL fusion gene.'),
    ('Chronic Lymphocytic Leukaemia (CLL)', 'hematological', 'C91',
     'Most common adult leukaemia; clonal accumulation of mature B cells.'),
    ('Von Willebrand Disease', 'hematological', 'D68',
     'Inherited bleeding disorder due to Von Willebrand factor deficiency.'),
    ('G6PD Deficiency', 'hematological', 'D55',
     'Enzyme deficiency causing red blood cell destruction in response to oxidative stress.'),

    # ── Immunological / Infectious ────────────────────────────────────────
    ('HIV / AIDS', 'immunological', 'B20',
     'Human immunodeficiency virus infection leading to acquired immunodeficiency syndrome.'),
    ('Tuberculosis (Chronic / Latent)', 'immunological', 'A15',
     'Mycobacterium tuberculosis infection that may be latent or chronic active.'),
    ('Common Variable Immunodeficiency (CVID)', 'immunological', 'D83',
     'Primary antibody deficiency with low immunoglobulin levels.'),
    ('IgA Deficiency', 'immunological', 'D80',
     'Most common primary immunodeficiency; absent or very low serum IgA.'),
    ('Autoimmune Hepatitis', 'immunological', 'K75',
     'Immune-mediated liver inflammation.'),
    ('Sjögren\'s Syndrome', 'immunological', 'M35',
     'Autoimmune condition targeting exocrine glands, causing dry eyes and mouth.'),

    # ── Mental Health ─────────────────────────────────────────────────────
    ('Major Depressive Disorder', 'mental_health', 'F32',
     'Persistent low mood, anhedonia, and cognitive impairment lasting ≥2 weeks.'),
    ('Bipolar Disorder', 'mental_health', 'F31',
     'Mood disorder characterised by episodes of mania and depression.'),
    ('Schizophrenia', 'mental_health', 'F20',
     'Chronic psychotic disorder with positive, negative, and cognitive symptoms.'),
    ('Generalised Anxiety Disorder (GAD)', 'mental_health', 'F41',
     'Excessive, uncontrollable worry about everyday matters lasting ≥6 months.'),
    ('Obsessive-Compulsive Disorder (OCD)', 'mental_health', 'F42',
     'Intrusive obsessions and repetitive compulsive behaviours.'),
    ('Post-Traumatic Stress Disorder (PTSD)', 'mental_health', 'F43',
     'Persistent distress following exposure to a traumatic event.'),
    ('Attention-Deficit Hyperactivity Disorder (ADHD)', 'mental_health', 'F90',
     'Neurodevelopmental disorder characterised by inattention, hyperactivity, and impulsivity.'),
    ('Autism Spectrum Disorder (ASD)', 'mental_health', 'F84',
     'Neurodevelopmental condition affecting social communication and behaviour.'),
    ('Borderline Personality Disorder (BPD)', 'mental_health', 'F60',
     'Pervasive pattern of emotional instability, impulsivity, and unstable relationships.'),
    ('Eating Disorders (Anorexia / Bulimia)', 'mental_health', 'F50',
     'Psychiatric disorders characterised by abnormal eating behaviours and weight concerns.'),
    ('Substance Use Disorder', 'mental_health', 'F19',
     'Chronic disorder characterised by compulsive substance use despite harmful consequences.'),

    # ── Oncological ───────────────────────────────────────────────────────
    ('Breast Cancer', 'oncological', 'C50',
     'Malignant neoplasm originating in breast tissue.'),
    ('Lung Cancer', 'oncological', 'C34',
     'Malignant neoplasm of the bronchus and lung.'),
    ('Colorectal Cancer', 'oncological', 'C18',
     'Cancer of the colon and/or rectum.'),
    ('Prostate Cancer', 'oncological', 'C61',
     'Malignant neoplasm of the prostate gland.'),
    ('Cervical Cancer', 'oncological', 'C53',
     'Cancer of the uterine cervix, often caused by HPV.'),
    ('Stomach (Gastric) Cancer', 'oncological', 'C16',
     'Malignant neoplasm of the stomach.'),
    ('Liver Cancer (HCC)', 'oncological', 'C22',
     'Primary hepatocellular carcinoma, often associated with cirrhosis.'),
    ('Thyroid Cancer', 'oncological', 'C73',
     'Malignant neoplasm of the thyroid gland.'),
    ('Lymphoma (Hodgkin\'s / Non-Hodgkin\'s)', 'oncological', 'C81',
     'Cancer of the lymphatic system.'),
    ('Multiple Myeloma', 'oncological', 'C90',
     'Cancer of plasma cells in the bone marrow.'),
    ('Ovarian Cancer', 'oncological', 'C56',
     'Malignant neoplasm of the ovary.'),
    ('Bladder Cancer', 'oncological', 'C67',
     'Malignant neoplasm of the urinary bladder.'),
    ('Pancreatic Cancer', 'oncological', 'C25',
     'Malignant neoplasm of the pancreas with poor prognosis.'),

    # ── Dermatological ────────────────────────────────────────────────────
    ('Psoriasis', 'dermatological', 'L40',
     'Chronic autoimmune skin condition causing rapid skin cell turnover and plaques.'),
    ('Atopic Dermatitis (Eczema)', 'dermatological', 'L20',
     'Chronic inflammatory skin condition causing itching and rashes.'),
    ('Rosacea', 'dermatological', 'L71',
     'Chronic facial redness and visible blood vessels.'),
    ('Vitiligo', 'dermatological', 'L80',
     'Loss of skin pigmentation due to destruction of melanocytes.'),
    ('Hidradenitis Suppurativa', 'dermatological', 'L73',
     'Chronic skin condition with painful lumps under the skin in hair follicle areas.'),
    ('Pemphigus Vulgaris', 'dermatological', 'L10',
     'Autoimmune blistering disorder affecting skin and mucous membranes.'),

    # ── Ophthalmological ─────────────────────────────────────────────────
    ('Glaucoma', 'ophthalmological', 'H40',
     'Optic nerve damage typically caused by elevated intraocular pressure.'),
    ('Age-Related Macular Degeneration (AMD)', 'ophthalmological', 'H35',
     'Progressive degeneration of the macula leading to central vision loss.'),
    ('Diabetic Retinopathy', 'ophthalmological', 'H36',
     'Microvascular complication of diabetes affecting the retina.'),
    ('Cataracts', 'ophthalmological', 'H26',
     'Clouding of the lens of the eye causing blurred vision.'),
    ('Retinitis Pigmentosa', 'ophthalmological', 'H35',
     'Hereditary degenerative disease of the retinal photoreceptors.'),
]


class Command(BaseCommand):
    help = 'Seed the clinical catalog with Allergies and Chronic Conditions'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Delete all existing records before seeding',
        )

    def handle(self, *args, **options):
        if options['clear']:
            Allergy.objects.all().delete()
            ChronicCondition.objects.all().delete()
            self.stdout.write(self.style.WARNING('Cleared all existing records.'))

        # ── Allergies ──
        allergy_created = 0
        allergy_skipped = 0
        for name, category, description, symptoms in ALLERGIES:
            _, created = Allergy.objects.get_or_create(
                name=name,
                defaults={
                    'category': category,
                    'description': description,
                    'common_symptoms': symptoms,
                    'is_active': True,
                },
            )
            if created:
                allergy_created += 1
            else:
                allergy_skipped += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'Allergies — created: {allergy_created}, already existed: {allergy_skipped}'
            )
        )

        # ── Chronic Conditions ──
        condition_created = 0
        condition_skipped = 0
        for name, category, icd_code, description in CHRONIC_CONDITIONS:
            _, created = ChronicCondition.objects.get_or_create(
                name=name,
                defaults={
                    'category': category,
                    'icd_code': icd_code,
                    'description': description,
                    'is_active': True,
                },
            )
            if created:
                condition_created += 1
            else:
                condition_skipped += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'Chronic Conditions — created: {condition_created}, already existed: {condition_skipped}'
            )
        )

        self.stdout.write(self.style.SUCCESS('Clinical catalog seeding complete.'))
