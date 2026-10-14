"""Check where appointments_appointment actually exists."""
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

with connection.cursor() as c:
    # Check which schemas have appointments_appointment
    c.execute("""
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_name = 'appointments_appointment'
        ORDER BY table_schema
    """)
    rows = c.fetchall()
    print("appointments_appointment found in:")
    for r in rows:
        print(f"  schema={r[0]}")
    
    # Check FK constraints that reference accounts_user in ALL schemas
    c.execute("""
        SELECT con.conname, rel.relname, att.attname, 
               ns.nspname AS schema_name,
               refcls.relname AS ref_table,
               refns.nspname AS ref_schema
        FROM pg_constraint con
        JOIN pg_class rel ON con.conrelid = rel.oid
        JOIN pg_namespace ns ON rel.relnamespace = ns.oid
        JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = con.conkey[1]
        LEFT JOIN pg_class refcls ON con.confrelid = refcls.oid
        LEFT JOIN pg_namespace refns ON refcls.relnamespace = refns.oid
        WHERE con.contype = 'f'
          AND rel.relname = 'appointments_appointment'
          AND refcls.relname = 'accounts_user'
        ORDER BY ns.nspname
    """)
    rows = c.fetchall()
    print(f"\nFK constraints on appointments_appointment referencing accounts_user:")
    for r in rows:
        print(f"  schema={r[3]} {r[1]}.{r[2]} -> {r[5]}.{r[4]} (constraint: {r[0]})")
    
    # Check if accounts_user exists in py_test schema or was it already dropped
    c.execute("""
        SELECT table_schema 
        FROM information_schema.tables 
        WHERE table_name = 'accounts_user'
        ORDER BY table_schema
    """)
    print(f"\naccounts_user exists in schemas:")
    for r in c.fetchall():
        print(f"  {r[0]}")
