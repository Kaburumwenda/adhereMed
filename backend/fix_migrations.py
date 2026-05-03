"""Fix missing tenant tables in public schema.

Migrations show as applied but tables don't exist.
This script removes false migration records and re-runs them.
"""
import django, os
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'
django.setup()

from django.db import connection

TENANT_APPS = [
    'departments', 'staff_profiles', 'patients', 'appointments',
    'consultations', 'prescriptions', 'lab', 'radiology', 'wards',
    'triage', 'billing', 'notifications', 'pharmacy_profile',
    'inventory', 'suppliers', 'purchase_orders', 'pos', 'dispensing',
]

with connection.cursor() as c:
    # Check which tenant tables actually exist
    c.execute("SELECT tablename FROM pg_tables WHERE schemaname='public'")
    existing = {r[0] for r in c.fetchall()}
    print(f"Existing tables: {len(existing)}")

    # Remove false migration records for tenant apps
    for app in TENANT_APPS:
        c.execute("DELETE FROM django_migrations WHERE app = %s", [app])
        print(f"  Cleared migration records for: {app}")

print("\nNow run: python manage.py migrate_schemas --schema=public")
