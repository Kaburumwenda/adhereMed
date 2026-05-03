import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection
from tenants.models import Tenant

for t in Tenant.objects.all():
    print(f'Tenant: {t.name} ({t.schema_name}, type={t.type})')
    try:
        with connection.cursor() as c:
            c.execute(f'SET search_path TO "{t.schema_name}"')
            c.execute('SELECT COUNT(*) FROM lab_labtestcatalog')
            count = c.fetchone()[0]
            print(f'  LabTestCatalog count: {count}')
            if count > 0:
                c.execute('SELECT id, name, code FROM lab_labtestcatalog LIMIT 5')
                for row in c.fetchall():
                    print(f'    {row}')
            c.execute('SET search_path TO "public"')
    except Exception as e:
        print(f'  Error: {e}')
        try:
            with connection.cursor() as c:
                c.execute('SET search_path TO "public"')
        except:
            pass
