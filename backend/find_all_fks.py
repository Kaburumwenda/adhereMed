"""Find ALL FK constraints referencing accounts_user, including deferrable ones."""
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

with connection.cursor() as c:
    c.execute("SET search_path = public")
    # Use pg_constraint to find ALL FKs, including deferrable ones
    c.execute("""
        SELECT con.conname, rel.relname AS table_name, 
               att.attname AS column_name,
               con.condeferred, con.condeferrable
        FROM pg_constraint con
        JOIN pg_class rel ON con.conrelid = rel.oid
        JOIN pg_namespace ns ON rel.relnamespace = ns.oid
        JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = con.conkey[1]
        WHERE con.contype = 'f'
          AND ns.nspname = 'public'
          AND con.confrelid = (
              SELECT oid FROM pg_class WHERE relname = 'accounts_user'
              AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
          )
        ORDER BY rel.relname
    """)
    rows = c.fetchall()
    print(f"Found {len(rows)} FK constraints referencing accounts_user (via pg_constraint):")
    for r in rows:
        print(f'  {r[1]}.{r[2]}  (constraint: {r[0]}, deferred={r[3]}, deferrable={r[4]})')
    
    # Also find appointments_appointment FK
    print("\n=== appointments_appointment constraints ===")
    c.execute("""
        SELECT con.conname, rel.relname, att.attname, 
               refcls.relname AS ref_table
        FROM pg_constraint con
        JOIN pg_class rel ON con.conrelid = rel.oid
        JOIN pg_namespace ns ON rel.relnamespace = ns.oid
        JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = con.conkey[1]
        LEFT JOIN pg_class refcls ON con.confrelid = refcls.oid
        WHERE con.contype = 'f'
          AND ns.nspname = 'public'
          AND rel.relname = 'appointments_appointment'
        ORDER BY con.conname
    """)
    for r in c.fetchall():
        print(f"  {r[1]}.{r[2]} -> {r[3]} (constraint: {r[0]})")
