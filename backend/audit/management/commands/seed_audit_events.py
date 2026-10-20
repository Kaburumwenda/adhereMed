"""Seed a handful of sample AuditEvent rows so the UI isn't empty on first run.

    python manage.py seed_audit_events --reset
    python manage.py seed_audit_events --reset --profile ohsms --schema aegis_ohs

Only run in development. The ``--reset`` flag wipes existing audit rows
for the current tenant; without it, the command just appends a handful of
synthetic events so historical data can be retained.
"""
import random
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db import connection
from django.utils import timezone

from audit.models import AuditEvent


ACTORS = [
    {"id": 1, "email": "admin@yusra.co", "role": "tenant_admin"},
    {"id": 2, "email": "pharmacist@yusra.co", "role": "pharmacist"},
    {"id": 3, "email": "cashier@yusra.co", "role": "cashier"},
    {"id": 4, "email": "boss@yusra.co", "role": "branch_admin"},
    {"id": 5, "email": "reception@yusra.co", "role": "receptionist"},
]

# Occupational Health & Safety actors — mirrors seed_ohsms staff.
OHSMS_ACTORS = [
    {"id": 1, "email": "admin@aegisohs.co", "role": "tenant_admin"},
    {"id": 2, "email": "grace.wanjiku@aegisohs.co", "role": "hse_manager"},
    {"id": 3, "email": "martin.kariuki@aegisohs.co", "role": "safety_officer"},
    {"id": 4, "email": "purity.chebet@aegisohs.co", "role": "safety_officer"},
    {"id": 5, "email": "lydia.muthoni@aegisohs.co", "role": "occ_health_nurse"},
    {"id": 6, "email": "joseph.wekesa@aegisohs.co", "role": "supervisor"},
    {"id": 7, "email": "rachel.achieng@aegisohs.co", "role": "supervisor"},
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

# OHSMS registers — these mirror the /api/ohs/ router prefixes.
OHSMS_OBJECT_TYPES = [
    ("ohs/hazards", "Hazard", "HAZ-2026-0014", "Forklift pedestrian interaction"),
    ("ohs/hazards", "Hazard", "HAZ-2026-0022", "Confined space entry — tank 4"),
    ("ohs/incidents", "Incident", "INC-2026-0009", "Hand laceration — packing line"),
    ("ohs/incidents", "Incident", "INC-2026-0011", "Near miss — falling pallet"),
    ("ohs/risk-assessments", "RiskAssessment", "RA-2026-0006", "Warehouse manual handling"),
    ("ohs/inspections", "Inspection", "INS-2026-0031", "Monthly warehouse walkthrough"),
    ("ohs/permits", "PermitToWork", "PTW-2026-0044", "Hot work — workshop bay 2"),
    ("ohs/equipment", "SafetyEquipment", "EQ-2026-0012", "SCBA set — 6.8L composite"),
    ("ohs/equipment", "SafetyEquipment", "EQ-2026-0037", "Lifting sling — 2T web"),
    ("ohs/documents", "Document", "DOC-2026-0005", "Hazardous substances policy"),
    ("ohs/contractors", "Contractor", "CPR/2026/623", "Bytes & Networks IT"),
    ("ohs/meetings", "SafetyMeeting", "", "Monthly safety committee"),
    ("ohs/management-reviews", "ManagementReview", "MR-2026-0002", "Q3 management review"),
    ("ohs/training-records", "TrainingRecord", "", "Forklift refresher — 12 attendees"),
    ("ohs/health-surveillance", "HealthSurveillance", "", "Audiometry — plant operators"),
    ("ohs/observations", "Observation", "", "Safe behaviour observation"),
    ("ohs/certifications", "Certification", "", "ISO 45001:2018 certification"),
    ("ohs/sites", "Site", "SITE-03", "Kisumu Processing Plant"),
    ("staff", "StaffProfile", "USR-014", "Added safety officer"),
    ("tenants", "Tenant", "", "Updated brand colours"),
    ("accounts", "User", "USR-007", "Reset staff password"),
    ("auth", "Session", "", "Failed sign-in attempt"),
]


OHSMS_ROLE_LABELS = {
    "tenant_admin": "Tenant Admin",
    "hse_manager": "HSE Manager",
    "safety_officer": "Safety Officer",
    "occ_health_nurse": "Occupational Health Nurse",
    "supervisor": "Supervisor",
    "pharmacist": "Pharmacist",
    "cashier": "Cashier",
    "branch_admin": "Branch Admin",
    "receptionist": "Receptionist",
}


def role_label(role: str) -> str:
    return OHSMS_ROLE_LABELS.get(role, role.replace("_", " ").title())


class Command(BaseCommand):
    help = "Seed sample AuditEvent rows for the current tenant."

    def add_arguments(self, parser):
        parser.add_argument("--reset", action="store_true", default=False,
                            help="Drop existing audit rows before seeding.")
        parser.add_argument("--count", type=int, default=80,
                            help="Number of synthetic events to create.")
        parser.add_argument("--profile", default="default",
                            choices=["default", "ohsms"],
                            help="Which event vocabulary to use.")
        parser.add_argument("--schema", default=None,
                            help="Tenant schema to seed (sets the DB schema first).")
        parser.add_argument("--days", type=int, default=1,
                            help="Spread events across this many days.")

    def handle(self, *args, **options):
        schema = options.get("schema")
        if schema:
            connection.set_schema(schema)

        reset = options.get("reset", False)
        count = options.get("count", 80)
        profile = options.get("profile", "default")
        days = max(1, int(options.get("days", 1) or 1))

        is_ohsms = profile == "ohsms"
        actors = OHSMS_ACTORS if is_ohsms else ACTORS
        object_pool = OHSMS_OBJECT_TYPES if is_ohsms else OBJECT_TYPES

        if reset:
            deleted, _ = AuditEvent.objects.all().delete()
            self.stdout.write(self.style.WARNING(
                f"Reset: removed {deleted} existing audit event(s)."
            ))

        now = timezone.now()
        if is_ohsms:
            actions = [
                ("view", AuditEvent.Severity.INFO),
                ("view", AuditEvent.Severity.INFO),
                ("view", AuditEvent.Severity.INFO),
                ("update", AuditEvent.Severity.INFO),
                ("update", AuditEvent.Severity.INFO),
                ("update", AuditEvent.Severity.NOTICE),
                ("create", AuditEvent.Severity.NOTICE),
                ("create", AuditEvent.Severity.NOTICE),
                ("create", AuditEvent.Severity.NOTICE),
                ("delete", AuditEvent.Severity.CRITICAL),
                ("export", AuditEvent.Severity.NOTICE),
                ("print", AuditEvent.Severity.INFO),
                ("config", AuditEvent.Severity.WARNING),
                ("login", AuditEvent.Severity.INFO),
                ("login", AuditEvent.Severity.INFO),
                ("logout", AuditEvent.Severity.INFO),
                ("action", AuditEvent.Severity.INFO),
                ("action", AuditEvent.Severity.NOTICE),
            ]
        else:
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
        # Sample GPS coordinates around Nairobi, Kenya.
        gps = [
            (-1.286389, 36.817223),   # Nairobi CBD
            (-1.292066, 36.821945),   # Westlands
            (-1.310036, 36.821945),   # Karen
            (-1.258730, 36.816830),   # Kilimani
            (None, None),             # sometimes unavailable
        ]

        created = 0
        for i in range(count):
            actor = random.choice(actors)
            obj_type, obj_class, obj_id, obj_repr = random.choice(object_pool)
            action, severity = random.choice(actions)
            # Spread across the requested window, biased toward working hours
            # so the hourly profile looks realistic.
            span_hours = max(1, days * 24)
            hours_back = int(i * span_hours / max(count, 1))
            ts = now - timedelta(hours=hours_back, minutes=random.randint(0, 59))
            if random.random() < 0.82:
                ts = ts.replace(hour=random.randint(7, 18))
            method = (random.choice(methods)
                      if action not in ("login", "logout", "export") else
                      {"login": "POST", "logout": "POST", "export": "GET"}.get(action, "GET"))
            status = random.choice(statuses) if action != "delete" else 204
            path = f"/api/{obj_type}/{obj_id}/" if obj_id else f"/api/{obj_type}/"
            lat, lon = random.choice(gps)

            event = AuditEvent.objects.create(
                actor_user_id=actor["id"],
                actor_email=actor["email"],
                actor_role=actor["role"],
                action=action,
                severity=severity,
                object_type=obj_type,
                object_id=obj_id,
                object_repr=f"{obj_class} {obj_repr}" if obj_id else obj_class,
                description=f"{role_label(actor['role'])} performed {action} on {obj_type}",
                method=method,
                path=path,
                ip=random.choice(ips),
                latitude=lat,
                longitude=lon,
                user_agent="Mozilla/5.0 (AdhereMed/Edge)",
                payload_diff={"before": {"status": "open"}, "after": {"status": "closed"}},
                extra={"module": obj_type, "session": f"sess-{random.randint(1000, 9999)}"},
                status_code=status,
            )
            # `created_at` is `auto_now_add`, so the timestamp has to be
            # back-dated with an explicit UPDATE after insert.
            AuditEvent.objects.filter(pk=event.pk).update(created_at=ts)
            created += 1

        if schema:
            connection.set_schema_to_public()

        self.stdout.write(self.style.SUCCESS(
            f"Seeded {created} synthetic audit event(s) across {days} day(s)."
        ))
