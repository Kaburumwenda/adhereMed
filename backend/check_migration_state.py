import django, os
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'
django.setup()

from django.db import connection

# Check public schema
cursor = connection.cursor()
cursor.execute("SELECT app, name FROM django_migrations WHERE app='staff_profiles' ORDER BY id")
print("=== PUBLIC schema migrations ===")
for row in cursor.fetchall():
    print(row)

# Check first tenant schema
from tenants.models import Tenant
for t in Tenant.objects.exclude(schema_name='public'):
    connection.set_schema(t.schema_name)
    cursor = connection.cursor()
    cursor.execute("SELECT app, name FROM django_migrations WHERE app='staff_profiles' ORDER BY id")
    rows = cursor.fetchall()
    print(f"\n=== {t.schema_name} migrations ===")
    for row in rows:
        print(row)
    
    # Check if specialization table exists
    cursor.execute("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema=%s AND table_name='staff_profiles_specialization')", [t.schema_name])
    print(f"  specialization table exists: {cursor.fetchone()[0]}")
    
    # Check if old column type
    cursor.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema=%s AND table_name='staff_profiles_staffprofile' AND column_name LIKE '%%specializ%%'", [t.schema_name])
    for row in cursor.fetchall():
        print(f"  column: {row}")
    
    connection.set_schema('public')
