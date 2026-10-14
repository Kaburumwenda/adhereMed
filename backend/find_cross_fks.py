"""Find ALL cross-schema FKs that reference public.accounts_user."""
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

with connection.cursor() as c:
    c.execute("""
        SELECT DISTINCT ns.nspname AS schema_name, rel.relname AS table_name, 
               att.attname AS column_name, con.conname AS constraint_name
        FROM pg_constraint con
        JOIN pg_class rel ON con.conrelid = rel.oid
        JOIN pg_namespace ns ON rel.relnamespace = ns.oid
        JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = con.conkey[1]
        LEFT JOIN pg_class refcls ON con.confrelid = refcls.oid
        LEFT JOIN pg_namespace refns ON refcls.relnamespace = refns.oid
        WHERE con.contype = 'f'
          AND refcls.relname = 'accounts_user'
          AND refns.nspname = 'public'
          AND ns.nspname != 'public'
        ORDER BY ns.nspname, rel.relname
    """)
    rows = c.fetchall()
    print(f"Found {len(rows)} cross-schema FK constraints referencing public.accounts_user:")
    # Group by (table_name, column_name)
    from collections import defaultdict
    groups = defaultdict(list)
    for r in rows:
        groups[(r[1], r[2])].append(r[0])
    
    for (table, col), schemas in sorted(groups.items()):
        print(f'  {table}.{col}  ({len(schemas)} schemas)')
