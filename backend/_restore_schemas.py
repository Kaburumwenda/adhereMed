"""Recreate the tenant schemas that were dropped, then migrate them.

WHY THIS EXISTS: an earlier cleanup script connected to the wrong database and
dropped every tenant schema in `afyaone`. The ``tenants_tenant`` rows survived
(in ``public``), so the fix is to recreate the empty schemas and re-run tenant
migrations. Data is *not* recovered by this script.

Safety: prints the plan and requires the ``--apply`` flag to actually run.
"""
import os
import sys

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

import psycopg
from django.conf import settings
from django.db import connection
from tenants.models import Tenant

apply = "--apply" in sys.argv

config = settings.DATABASES["default"]
print("database :", config["NAME"])
print("mode     :", "APPLY" if apply else "dry run (pass --apply to execute)")

with connection.cursor() as cur:
    cur.execute(
        "SELECT nspname FROM pg_namespace WHERE nspname NOT LIKE 'pg\\_%%' "
        "AND nspname <> 'information_schema'")
    existing = {r[0] for r in cur.fetchall()}

tenants = list(Tenant.objects.exclude(schema_name="public").order_by("id"))
missing = [t for t in tenants if t.schema_name not in existing]

print("\ntenants tracked in public:", len(tenants))
print("schemas still present     :", sorted(existing - {"public"}) or "none")
print("schemas to recreate       :", len(missing))
for tenant in missing:
    print("   + %-22s %s" % (tenant.schema_name, tenant.name[:40]))

if not apply:
    print("\nDry run only. Re-run with --apply to create them.")
    raise SystemExit(0)

print("\nCreating schemas ...")
conn = psycopg.connect(
    dbname=config["NAME"], user=config.get("USER"),
    password=config.get("PASSWORD"), host=config.get("HOST") or "localhost",
    port=config.get("PORT") or 5432, autocommit=True,
)
with conn.cursor() as cur:
    for tenant in missing:
        cur.execute('CREATE SCHEMA IF NOT EXISTS "%s"' % tenant.schema_name)
        print("   created", tenant.schema_name)
conn.close()
print("\nDone. Now run: manage.py migrate_schemas --tenant --noinput")
