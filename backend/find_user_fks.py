"""Find ALL tables in public schema that reference accounts_user via FK."""
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

with connection.cursor() as c:
    c.execute("SET search_path = public")
    c.execute("""
        SELECT DISTINCT tc.table_name, kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage ccu
          ON tc.constraint_name = ccu.constraint_name
          AND tc.table_schema = ccu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
          AND ccu.table_name = 'accounts_user'
          AND ccu.table_schema = 'public'
        ORDER BY tc.table_name
    """)
    rows = c.fetchall()
    print(f"Found {len(rows)} table+column pairs referencing accounts_user:")
    for t, col in rows:
        print(f'  ("{t}", "{col}"),')
