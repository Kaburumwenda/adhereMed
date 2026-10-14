"""Update brand_names on existing Medication records from the BRAND_NAMES dictionary.

Usage (tenant-aware):
    python manage.py tenant_command update_brand_names --schema=<schema_name>

Or inside the tenant schema shell:
    python manage.py update_brand_names

Options:
    --dry-run   Show what would change without writing.
    --force      Overwrite non-empty brand_names (default: only fill empty ones).
"""
from __future__ import annotations

from django.core.management.base import BaseCommand

from medications.management.commands.seed_medications import _get_brand_names
from medications.models import Medication


class Command(BaseCommand):
    help = "Update brand_names on existing Medication records from the known brand-name dictionary."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Show what would change without writing to the database.",
        )
        parser.add_argument(
            "--force",
            action="store_true",
            help="Overwrite brand_names even if the field is already populated.",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        force = options["force"]

        qs = Medication.objects.all()
        total = qs.count()
        self.stdout.write(self.style.NOTICE(f"Scanning {total} medication(s) …"))

        updated = 0
        skipped = 0
        unchanged = 0

        for med in qs.iterator():
            # Use generic_name preferentially, fall back to name/product_name
            lookup_name = med.generic_name or med.name or ""
            if not lookup_name:
                skipped += 1
                continue

            detected = _get_brand_names(lookup_name)
            if not detected:
                # Also try product_code or abbreviation as secondary fallback
                alt_name = f"{med.product_code or ''} {med.abbreviation or ''}".strip()
                if alt_name:
                    detected = _get_brand_names(alt_name)

            if not detected:
                unchanged += 1
                continue

            current = med.brand_names or []
            # Compare as lowercase sets for meaningful comparison
            current_lower = {b.lower() for b in current}
            detected_lower = {b.lower() for b in detected}

            if not force and current:
                # Already populated and force not requested — skip
                unchanged += 1
                continue

            if detected_lower == current_lower and not force:
                unchanged += 1
                continue

            if dry_run:
                self.stdout.write(
                    f"  Would update: {med.generic_name or med.name} "
                    f"(id={med.id}) → {detected}"
                )
                updated += 1
                continue

            med.brand_names = detected
            med.save(update_fields=["brand_names"])
            updated += 1

        self.stdout.write("")
        if dry_run:
            self.stdout.write(
                self.style.WARNING(
                    f"Dry run complete: {updated} would be updated, "
                    f"{skipped} skipped, {unchanged} unchanged."
                )
            )
        else:
            self.stdout.write(
                self.style.SUCCESS(
                    f"Done: {updated} updated, {skipped} skipped, {unchanged} unchanged."
                )
            )
