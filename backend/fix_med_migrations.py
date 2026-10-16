"""
Remove medications migration records from each tenant schema so we can
re-apply them and actually create the tables in each tenant.
"""
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

# Get all tenant schemas
cursor = connection.cursor()
cursor.execute("SELECT schema_name FROM tenants_tenant WHERE schema_name != 'public'")
tenants = [r[0] for r in cursor.fetchall()]
print(f"Tenant schemas: {tenants}\n")

for schema in tenants:
    # Delete medications migration records from this tenant schema
    cursor.execute(f'DELETE FROM "{schema}".django_migrations WHERE app = %s', ['medications'])
    deleted = cursor.rowcount
    print(f"  {schema}: deleted {deleted} medications migration records")

print("\nDone. Now run: python manage.py migrate_schemas --tenant")
