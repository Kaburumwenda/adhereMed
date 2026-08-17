"""
Seed built-in security roles (auth.Group) for the current pharmacy tenant.

These roles mirror the user role choices defined in `accounts.User.Role` so
that admins can attach Django auth permissions to each role from the
"IAM & Security" sidebar.

Usage:
    python manage.py seed_roles
        # seed into the tenant identified by the X-Tenant-Schema middleware
        # (or the schema_name passed via --schema)

    python manage.py seed_roles --schema yusra_pharmacy
        # explicitly seed a given tenant schema

    python manage.py seed_roles --reset
        # drop existing Groups created by this command (name starts with the
        # role label and is marked via Group.name) before re-seed. Useful in
        # development.

The command is idempotent — re-running it will not duplicate groups and will
keep any permission overrides the tenant admin has made (unless --reset).
"""
from django.core.management.base import BaseCommand
from django.contrib.auth.models import Group, Permission
from django.contrib.contenttypes.models import ContentType
from django.db import transaction

from accounts.models import User


# Map each built-in role -> dict of role definition.
# `permissions` maps Django app labels to either:
#     - "*" (all permission codenames on that app's models), OR
#     - a list of specific `<model>.<action>` tuples, OR
#     - a list of permission codenames (model-agnostic within the app)
ROLE_BLUEPRINTS = {
    "Pharmacy Admin": {
        "system_role": User.Role.TENANT_ADMIN,
        "description": "Full pharmacy tenant administrator. Manages users, branches, settings, billing.",
        "permissions": {
            "*": "*",  # all permissions, every app
        },
    },
    "Branch Admin": {
        "system_role": User.Role.BRANCH_ADMIN,
        "description": "Manages a single branch — staff, inventory, sales, purchases for their branch.",
        "permissions": {
            "pos": "*",
            "inventory": "*",
            "dispensing": "*",
            "suppliers": "*",
            "purchase_orders": "*",
            "expenses": "*",
            "pharmacy_profile": "*",
            "patients": "*",
            "messaging": "*",
            "notifications": "*",
            "staff_profiles": "*",
            "prescriptions": "*",
            "accounts": ["add_user", "change_user", "view_user"],
        },
    },
    "Pharmacist": {
        "system_role": User.Role.PHARMACIST,
        "description": "Verifies prescriptions, dispenses medication, manages stock levels.",
        "permissions": {
            "pos": "*",
            "inventory": ["view_medicationstock", "change_medicationstock"],
            "dispensing": "*",
            "prescriptions": "*",
            "medications": ["view_medication", "view_druginteraction"],
            "purchase_orders": ["view_purchaseorder", "add_purchaseorder"],
            "suppliers": ["view_supplier"],
            "patients": ["view_patient"],
            "messaging": "*",
            "notifications": "*",
        },
    },
    "Pharmacy Technician": {
        "system_role": User.Role.PHARMACY_TECH,
        "description": "Supports the pharmacist — receives deliveries, restocks shelves, deals at the till.",
        "permissions": {
            "pos": "*",
            "inventory": ["view_medicationstock", "change_medicationstock"],
            "dispensing": ["view_dispensingrecord", "add_dispensingrecord",
                           "view_dispensereturn", "add_dispensereturn"],
            "purchase_orders": ["view_purchaseorder"],
            "suppliers": ["view_supplier"],
            "patients": ["view_patient"],
            "messaging": "*",
            "notifications": "*",
        },
    },
    "Cashier": {
        "system_role": User.Role.CASHIER,
        "description": "Front-of-store POS operator. Handles sales, returns, till closing.",
        "permissions": {
            "pos": ["view_postransaction", "add_postransaction", "change_postransaction",
                    "view_parkedsale", "add_parkedsale",
                    "change_parkedsale", "delete_parkedsale",
                    "view_cashiershift", "add_cashiershift", "change_cashiershift",
                    "view_customer", "change_customer",
                    "view_loyaltytransaction"],
            "patients": ["view_patient", "add_patient"],
            "dispensing": ["view_dispensingrecord",
                           "view_dispensereturn", "add_dispensereturn"],
            "messaging": "*",
            "notifications": "*",
        },
    },
    "Receptionist": {
        "system_role": User.Role.RECEPTIONIST,
        "description": "Customer service desk — registers patients, books deliveries, sends messages.",
        "permissions": {
            "patients": ["view_patient", "add_patient", "change_patient"],
            "pos": ["view_postransaction"],
            "messaging": "*",
            "notifications": "*",
            "pharmacy_profile": ["view_branch"],
        },
    },
    "Doctor": {
        "system_role": User.Role.DOCTOR,
        "description": "Clinical prescriber — writes prescriptions and refers patients to the pharmacy.",
        "permissions": {
            "prescriptions": "*",
            "patients": ["view_patient", "change_patient"],
            "medications": ["view_medication", "view_druginteraction"],
            "dispensing": ["view_dispensingrecord"],
            "messaging": "*",
            "notifications": "*",
        },
    },
    "Clinical Officer": {
        "system_role": User.Role.CLINICAL_OFFICER,
        "description": "Same access scope as Doctor for pharmacy purposes.",
        "permissions": {
            "prescriptions": "*",
            "patients": ["view_patient", "change_patient"],
            "medications": ["view_medication", "view_druginteraction"],
            "dispensing": ["view_dispensingrecord"],
            "messaging": "*",
            "notifications": "*",
        },
    },
    "Nurse": {
        "system_role": User.Role.NURSE,
        "description": "Read-only pharmacy access for care continuity.",
        "permissions": {
            "patients": ["view_patient"],
            "prescriptions": ["view_prescription"],
            "medications": ["view_medication"],
            "messaging": "*",
            "notifications": "*",
        },
    },
}


class Command(BaseCommand):
    help = "Seed built-in security roles (auth.Group) for the current tenant."

    def add_arguments(self, parser):
        parser.add_argument(
            "--schema",
            type=str,
            default=None,
            help="Specific tenant schema_name to seed. Defaults to the "
                 "schema identified by the X-Tenant-Schema middleware.",
        )
        parser.add_argument(
            "--reset",
            action="store_true",
            default=False,
            help="Drop existing built-in role Groups before seeding.",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        reset = options.get("reset", False)
        schema = options.get("schema")

        if reset:
            deleted, _ = Group.objects.filter(
                name__in=list(ROLE_BLUEPRINTS.keys())
            ).delete()
            self.stdout.write(self.style.WARNING(
                f"Reset: removed {deleted} existing role group(s)."
            ))

        created = 0
        updated = 0
        for role_name, blueprint in ROLE_BLUEPRINTS.items():
            group, was_created = Group.objects.get_or_create(name=role_name)
            if was_created:
                created += 1
            else:
                updated += 1

            # Only attach permissions when the group is freshly created OR
            # when --reset was used (so admin customisations aren't wiped).
            if was_created or reset:
                perms = self._resolve_permissions(blueprint.get("permissions", {}))
                group.permissions.set(perms)
                sys_role = blueprint.get("system_role", "")
                self.stdout.write(
                    self.style.SUCCESS(
                        f"{'Created' if was_created else 'Reset'} role "
                        f"'{role_name}' ({sys_role}) "
                        f"with {perms.count()} permission(s)."
                    )
                )
            else:
                self.stdout.write(
                    self.style.NOTICE(
                        f"Role '{role_name}' already exists — "
                        f"left permissions unchanged (use --reset to refresh)."
                    )
                )

        self.stdout.write(self.style.SUCCESS(
            f"\nDone. {created} role(s) created, {updated} role(s) unchanged."
        ))

    def _resolve_permissions(self, perm_spec):
        """Resolve a permissions spec into a Permission queryset.

        Spec keys are Django app_labels. Values are:
            "*" -> resolve to all Permission rows in that app_label
            [list of codename strings] -> those codenames within that app
        A top-level key "*" with value "*" means every permission.
        """
        if perm_spec == {"*": "*"}:
            return Permission.objects.all()

        perm_ids = set()
        for app_label, spec in perm_spec.items():
            if app_label == "*" and spec == "*":
                # belt-and-braces
                return Permission.objects.all()

            ctypes = ContentType.objects.filter(app_label=app_label)
            if not ctypes.exists():
                self.stderr.write(self.style.WARNING(
                    f"App label '{app_label}' has no ContentTypes — skipped."
                ))
                continue

            if spec == "*":
                ids = Permission.objects.filter(
                    content_type__app_label=app_label
                ).values_list("id", flat=True)
            else:
                ids = Permission.objects.filter(
                    content_type__app_label=app_label,
                    codename__in=spec,
                ).values_list("id", flat=True)
                missing = set(spec) - set(
                    Permission.objects.filter(
                        content_type__app_label=app_label,
                        codename__in=spec,
                    ).values_list("codename", flat=True)
                )
                if missing:
                    self.stderr.write(self.style.WARNING(
                        f"App '{app_label}' missing codenames: "
                        f"{sorted(missing)}"
                    ))
            perm_ids.update(ids)

        return Permission.objects.filter(id__in=perm_ids)
