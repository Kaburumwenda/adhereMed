"""Seed a handful of sample AuditEvent rows so the UI isn't empty on first run.

    python manage.py seed_audit_events --reset

Only run in development. The ``--reset`` flag wipes existing audit rows
for the current tenant; without it, the command just appends a handful of
synthetic events so historical data can be retained.
"""
import random
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from audit.models import AuditEvent


ACTORS = [
    {"id": 1, "email": "admin@yusra.co", "role": "tenant_admin"},
    {"id": 2, "email": "pharmacist@yusra.co", "role": "pharmacist"},
    {"id": 3, "email": "cashier@yusra.co", "role": "cashier"},
    {"id": 4, "email": "boss@yusra.co", "role": "branch_admin"},
    {"id": 5, "email": "reception@yusra.co", "role": "receptionist"},
]

# Mix of object types matching the real backend apps.
OBJECT_TYPES = [
    ("patients", "Patient", "PT-000123", "Mrs"),
    ("pos", "POSTransaction", "TX-2026-00432", "KES 2,500 sale"),
    ("pos", "ParkedSale", "PK-9921", "Sale resumed"),
    ("prescriptions", "Prescription", "RX-44510", "Amoxicillin 500mg"),
    ("dispensing", "DispensingRecord", "DI-22001", "Dispensed 3 items"),
    ("inventory", "MedicationStock", "ST-00875", "Restocked amoxicillin"),
    ("accounts", "User", "USR-007", "Created staff user"),
    ("auth", "Session", "", "Failed sign-in attempt"),
    ("purchase_orders", "PurchaseOrder", "PO-1180", "Created purchase order"),
    ("suppliers", "Supplier", "SUP-44", "Updated supplier"),
    ("pharmacy_profile", "Branch", "BR-02", "Updated branch hours"),
    ("settings", "PharmacyDetail", "", "Updated operating hours"),
    ("reports", "ReportCache", "", "Generated sales report"),
    ("insurance", "Claim", "CLM-33010", "Submitted claim"),
]


class Command(BaseCommand):
    help = "Seed sample AuditEvent rows for the current tenant."

    def add_arguments(self, parser):
        parser.add_argument("--reset", action="store_true", default=False,
                            help="Drop existing audit rows before seeding.")
        parser.add_argument("--count", type=int, default=80,
                            help="Number of synthetic events to create.")

    def handle(self, *args, **options):
        reset = options.get("reset", False)
        count = options.get("count", 80)
        if reset:
            deleted, _ = AuditEvent.objects.all().delete()
            self.stdout.write(self.style.WARNING(
                f"Reset: removed {deleted} existing audit event(s)."
            ))

        now = timezone.now()
        actions = [
            ("create", AuditEvent.Severity.NOTICE),
            ("create", AuditEvent.Severity.NOTICE),
            ("update", AuditEvent.Severity.INFO),
            ("update", AuditEvent.Severity.INFO),
            ("update", AuditEvent.Severity.INFO),
            ("delete", AuditEvent.Severity.CRITICAL),
            ("view", AuditEvent.Severity.INFO),
            ("view", AuditEvent.Severity.INFO),
            ("export", AuditEvent.Severity.NOTICE),
            ("login", AuditEvent.Severity.INFO),
            ("logout", AuditEvent.Severity.INFO),
            ("action", AuditEvent.Severity.INFO),
        ]
        methods = ["POST", "PUT", "PATCH", "DELETE", "GET", "GET", "GET"]
        statuses = [200, 201, 200, 400, 500, 200, 200]
        ips = ["105.60.224.81", "41.90.0.18", "197.232.84.10", "127.0.0.1"]

        created = 0
        for i in range(count):
            actor = random.choice(ACTORS)
            obj_type, obj_class, obj_id, obj_repr = random.choice(OBJECT_TYPES)
            action, severity = random.choice(actions)
            hours_back = int(i * 24 / count)  # spread over 24h
            ts = now - timedelta(hours=hours_back, minutes=random.randint(0, 59))
            method = (random.choice(methods)
                      if action not in ("login", "logout", "export") else
                      {"login": "POST", "logout": "POST", "export": "GET"}.get(action, "GET"))
            status = random.choice(statuses) if action != "delete" else 204
            path = f"/api/{obj_type}/{obj_id}/" if obj_id else f"/api/{obj_type}/"

            AuditEvent.objects.create(
                actor_user_id=actor["id"],
                actor_email=actor["email"],
                actor_role=actor["role"],
                action=action,
                severity=severity,
                object_type=obj_type,
                object_id=obj_id,
                object_repr=f"{obj_class} {obj_repr}" if obj_id else obj_class,
                description=f"{actor['role']} performed {action} on {obj_type}",
                method=method,
                path=path,
                ip=random.choice(ips),
                user_agent="Mozilla/5.0 (AdhereMed/Edge)",
                payload_diff={"before": {"status": "open"}, "after": {"status": "closed"}},
                extra={"branch_id": 1, "module": obj_type},
                status_code=status,
                created_at=ts,
            )
            created += 1

        self.stdout.write(self.style.SUCCESS(
            f"Seeded {created} synthetic audit event(s) over the last 24h."
        ))
