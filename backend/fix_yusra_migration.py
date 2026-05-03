"""
Fix the yusra_pharmacy schema that is stuck on migration 0003.
Steps:
1. Create the specialization table in yusra_pharmacy
2. Seed the specializations
3. Add specialization_id FK column
4. Migrate old string data to FK references
5. Drop old specialization varchar column
6. Rename specialization_id to specialization
7. Mark migrations 0003 and 0004 as applied
"""
import django, os
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'
django.setup()

from django.db import connection

SPECIALIZATIONS = [
    'Clinical Pharmacy',
    'Community Pharmacy',
    'Hospital Pharmacy',
    'Industrial Pharmacy',
    'Compounding Pharmacy',
    'Pharmacovigilance',
    'Oncology Pharmacy',
    'Pediatric Pharmacy',
    'Geriatric Pharmacy',
    'Psychiatric Pharmacy',
    'Ambulatory Care Pharmacy',
    'Critical Care Pharmacy',
    'Infectious Disease Pharmacy',
    'Nuclear Pharmacy',
    'Nutrition Support Pharmacy',
    'Regulatory Affairs',
    'Drug Information',
    'Dispensing',
    'Inventory Management',
    'Sterile Compounding',
    'Medication Therapy Management',
    'Pharmacy Billing & Insurance',
    'General',
    'Other',
]

# Map old TextChoices values to the display names used in the Specialization table
OLD_VALUE_TO_NAME = {
    'clinical_pharmacy': 'Clinical Pharmacy',
    'community_pharmacy': 'Community Pharmacy',
    'hospital_pharmacy': 'Hospital Pharmacy',
    'industrial_pharmacy': 'Industrial Pharmacy',
    'compounding': 'Compounding Pharmacy',
    'pharmacovigilance': 'Pharmacovigilance',
    'oncology_pharmacy': 'Oncology Pharmacy',
    'pediatric_pharmacy': 'Pediatric Pharmacy',
    'geriatric_pharmacy': 'Geriatric Pharmacy',
    'psychiatric_pharmacy': 'Psychiatric Pharmacy',
    'ambulatory_care': 'Ambulatory Care Pharmacy',
    'critical_care': 'Critical Care Pharmacy',
    'infectious_disease': 'Infectious Disease Pharmacy',
    'nuclear_pharmacy': 'Nuclear Pharmacy',
    'nutrition_support': 'Nutrition Support Pharmacy',
    'regulatory_affairs': 'Regulatory Affairs',
    'drug_information': 'Drug Information',
    'dispensing': 'Dispensing',
    'inventory_management': 'Inventory Management',
    'sterile_compounding': 'Sterile Compounding',
    'medication_therapy': 'Medication Therapy Management',
    'pharmacy_billing': 'Pharmacy Billing & Insurance',
    'general': 'General',
    'other': 'Other',
}

SEED_DATA = [
    ('Clinical Pharmacy', 'Patient-oriented pharmaceutical care in clinical settings'),
    ('Community Pharmacy', 'Retail and community-based pharmaceutical services'),
    ('Hospital Pharmacy', 'Pharmacy services within hospital settings'),
    ('Industrial Pharmacy', 'Drug manufacturing and pharmaceutical industry'),
    ('Compounding Pharmacy', 'Custom medication preparation and formulation'),
    ('Pharmacovigilance', 'Drug safety monitoring and adverse event reporting'),
    ('Oncology Pharmacy', 'Cancer treatment and chemotherapy management'),
    ('Pediatric Pharmacy', 'Pharmaceutical care for infants, children, and adolescents'),
    ('Geriatric Pharmacy', 'Pharmaceutical care for elderly patients'),
    ('Psychiatric Pharmacy', 'Mental health and psychotropic medication management'),
    ('Ambulatory Care Pharmacy', 'Outpatient pharmaceutical care and chronic disease management'),
    ('Critical Care Pharmacy', 'Intensive care and emergency pharmaceutical services'),
    ('Infectious Disease Pharmacy', 'Antimicrobial therapy and infection management'),
    ('Nuclear Pharmacy', 'Radiopharmaceutical preparation and dispensing'),
    ('Nutrition Support Pharmacy', 'Parenteral and enteral nutrition therapy'),
    ('Regulatory Affairs', 'Drug regulation, compliance, and quality assurance'),
    ('Drug Information', 'Medication information services and evidence-based guidance'),
    ('Dispensing', 'Prescription dispensing and medication distribution'),
    ('Inventory Management', 'Stock control, purchasing, and supply chain management'),
    ('Sterile Compounding', 'Aseptic preparation of sterile medications'),
    ('Medication Therapy Management', 'Patient medication reviews and therapy optimization'),
    ('Pharmacy Billing & Insurance', 'Claims processing, insurance verification, and billing'),
    ('General', 'General pharmacy practice'),
    ('Other', 'Other specialization not listed'),
]

schema = 'yusra_pharmacy'
print(f"Fixing schema: {schema}")
connection.set_schema(schema)
cursor = connection.cursor()

# 1. Create specialization table
print("  Creating staff_profiles_specialization table...")
cursor.execute("""
    CREATE TABLE IF NOT EXISTS staff_profiles_specialization (
        id BIGSERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE,
        description TEXT NOT NULL DEFAULT '',
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
""")

# 2. Seed specializations
print("  Seeding specializations...")
for name, desc in SEED_DATA:
    cursor.execute(
        "INSERT INTO staff_profiles_specialization (name, description) VALUES (%s, %s) ON CONFLICT (name) DO NOTHING",
        [name, desc],
    )

# 3. Add temp FK column
print("  Adding specialization_id column...")
cursor.execute("""
    SELECT column_name FROM information_schema.columns
    WHERE table_schema=%s AND table_name='staff_profiles_staffprofile' AND column_name='specialization_id'
""", [schema])
if not cursor.fetchone():
    cursor.execute("ALTER TABLE staff_profiles_staffprofile ADD COLUMN specialization_id BIGINT NULL")

# 4. Migrate old string data to FK
print("  Migrating old string data to FK references...")
cursor.execute("SELECT DISTINCT specialization FROM staff_profiles_staffprofile WHERE specialization IS NOT NULL AND specialization != ''")
old_values = [row[0] for row in cursor.fetchall()]
for old_val in old_values:
    new_name = OLD_VALUE_TO_NAME.get(old_val)
    if new_name:
        cursor.execute(
            "UPDATE staff_profiles_staffprofile SET specialization_id = (SELECT id FROM staff_profiles_specialization WHERE name = %s) WHERE specialization = %s",
            [new_name, old_val],
        )
        print(f"    Mapped '{old_val}' -> '{new_name}'")
    else:
        print(f"    WARNING: No mapping for '{old_val}', setting to NULL")

# 5. Drop old varchar column
print("  Dropping old specialization varchar column...")
cursor.execute("ALTER TABLE staff_profiles_staffprofile DROP COLUMN specialization")

# 6. Rename specialization_id
print("  Renaming specialization_id -> specialization_id (FK convention)...")
# Django FK fields are already named <field>_id in the DB, so this is correct as-is

# 7. Add FK constraint
print("  Adding FK constraint...")
cursor.execute("""
    ALTER TABLE staff_profiles_staffprofile
    ADD CONSTRAINT staff_profiles_staffpr_specialization_id_fk
    FOREIGN KEY (specialization_id) REFERENCES staff_profiles_specialization(id)
    ON DELETE SET NULL
""")

# 8. Mark migrations as applied
print("  Marking migrations 0003 and 0004 as applied...")
cursor.execute(
    "INSERT INTO django_migrations (app, name, applied) VALUES ('staff_profiles', '0003_specialization_alter_staffprofile_specialization', NOW()) ON CONFLICT DO NOTHING"
)
cursor.execute(
    "INSERT INTO django_migrations (app, name, applied) VALUES ('staff_profiles', '0004_seed_specializations', NOW()) ON CONFLICT DO NOTHING"
)

connection.connection.commit()
print("Done! yusra_pharmacy schema fixed.")
