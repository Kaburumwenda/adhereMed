import django, os
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'
django.setup()

from django.db import connection
from tenants.models import Tenant

# Check what happens when we switch to hospital schema
hospital = Tenant.objects.get(schema_name='hospital_demo')
connection.set_tenant(hospital)

print(f"Current schema: {connection.schema_name}")

# Can we query users?
from accounts.models import User
try:
    users = User.objects.all()
    print(f"Users found: {users.count()}")
    for u in users:
        print(f"  {u.email} ({u.role})")
except Exception as e:
    print(f"Error querying users: {e}")

# Can we query tenant tables?
try:
    with connection.cursor() as c:
        c.execute("SELECT tablename FROM pg_tables WHERE schemaname='hospital_demo' ORDER BY tablename")
        tables = [r[0] for r in c.fetchall()]
    print(f"\nTables in hospital_demo schema: {len(tables)}")
    for t in tables:
        print(f"  {t}")
except Exception as e:
    print(f"Error listing tables: {e}")

# Test querying a tenant table
try:
    from departments.models import Department
    depts = Department.objects.all()
    print(f"\nDepartments: {depts.count()}")
except Exception as e:
    print(f"\nError querying departments: {e}")
