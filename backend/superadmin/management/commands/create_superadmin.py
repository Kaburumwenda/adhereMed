"""
Usage:
    python manage.py create_superadmin
    python manage.py create_superadmin --email admin@afyaone.com --password MySecurePass123
    python manage.py create_superadmin --recreate  # deletes the old super admin and creates fresh
"""
import getpass

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

User = get_user_model()


class Command(BaseCommand):
    help = "Create (or recreate) the platform super admin account."

    def add_arguments(self, parser):
        parser.add_argument("--email", type=str, default="", help="Super admin email address.")
        parser.add_argument("--first-name", type=str, default="Super", dest="first_name")
        parser.add_argument("--last-name", type=str, default="Admin", dest="last_name")
        parser.add_argument("--phone", type=str, default="", help="Phone number (optional).")
        parser.add_argument("--password", type=str, default="", help="Password (prompted if omitted).")
        parser.add_argument(
            "--recreate",
            action="store_true",
            default=False,
            help="Delete the existing super admin(s) and create a fresh account.",
        )

    def handle(self, *args, **options):
        email = options["email"].strip()
        first_name = options["first_name"].strip()
        last_name = options["last_name"].strip()
        phone = options["phone"].strip()
        password = options["password"].strip()
        recreate = options["recreate"]

        # ── Prompt for missing values ───────────────────────────────────
        if not email:
            email = input("Super admin email: ").strip()
        if not email:
            raise CommandError("Email is required.")

        if not password:
            password = getpass.getpass("Password: ")
            confirm = getpass.getpass("Confirm password: ")
            if password != confirm:
                raise CommandError("Passwords do not match.")
        if len(password) < 8:
            raise CommandError("Password must be at least 8 characters.")

        # ── Recreate logic ──────────────────────────────────────────────
        if recreate:
            # Use update() to avoid cascade-delete across tenant schemas
            updated = User.objects.filter(role=User.Role.SUPER_ADMIN).update(is_active=False)
            if updated:
                self.stdout.write(self.style.WARNING(
                    f"Deactivated {updated} existing super admin(s)."
                ))

        # ── Check email uniqueness ──────────────────────────────────────
        existing = User.objects.filter(email=email).first()
        if existing:
            if recreate:
                # Promote existing user to super admin
                existing.role = User.Role.SUPER_ADMIN
                existing.is_staff = True
                existing.is_superuser = True
                existing.is_active = True
                existing.tenant = None
                existing.first_name = first_name
                existing.last_name = last_name
                if phone:
                    existing.phone = phone
                existing.set_password(password)
                existing.save()
                self.stdout.write(self.style.SUCCESS(
                    f"\n✓ Existing user promoted to super admin.\n"
                    f"  Email   : {existing.email}\n"
                    f"  ID      : {existing.id}\n"
                ))
                return
            raise CommandError(
                f"A user with email '{email}' already exists. "
                "Use --recreate to overwrite, or choose a different email."
            )

        # ── Create ──────────────────────────────────────────────────────
        user = User.objects.create_user(
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
            phone=phone,
            role=User.Role.SUPER_ADMIN,
            is_staff=True,
            is_superuser=True,
            tenant=None,  # Super admin has no tenant
        )

        self.stdout.write(self.style.SUCCESS(
            f"\n✓ Super admin created successfully.\n"
            f"  Email   : {user.email}\n"
            f"  Name    : {user.full_name}\n"
            f"  Role    : {user.role}\n"
            f"  ID      : {user.id}\n"
        ))
