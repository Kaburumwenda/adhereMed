"""Backfill: every clinic branch gets a drug store.

Existing tenants created their clinic branches (``clinic_sites.ClinicSite``) and
drug stores (``pharmacy_profile.Branch``) independently, so stores were never
linked to a branch. This migration:

1. links each unlinked store to the branch whose name best matches it (falling
   back to the HQ branch, then to the first branch);
2. creates a store for every branch that still has none.

It runs per tenant schema, so it is safe under django-tenants.
"""

from django.db import migrations


def _default_store_name(site_name):
    base = (site_name or 'Clinic').strip()
    if base.lower().endswith('drug store'):
        return base
    return f'{base} Drug Store'


def forwards(apps, schema_editor):
    ClinicSite = apps.get_model('clinic_sites', 'ClinicSite')
    Branch = apps.get_model('pharmacy_profile', 'Branch')

    sites = list(ClinicSite.objects.all().order_by('-is_hq', 'name'))
    # Nothing to do in a schema without clinic branches (e.g. a pure pharmacy
    # tenant) — leave its drug stores untouched.
    if not sites:
        return

    hq = next((s for s in sites if s.is_hq), sites[0])
    by_name = {s.name.strip().lower(): s for s in sites if (s.name or '').strip()}

    branches = list(Branch.objects.all())

    def match_site(branch):
        """Best-effort link: store name/place contains a branch name, or vice versa."""
        haystack = ' '.join(
            filter(None, [branch.name or '', branch.place_name or '', branch.address or ''])
        ).strip().lower()
        if not haystack:
            return None
        for site_name, site in by_name.items():
            if site_name and site_name in haystack:
                return site
        for site_name, site in by_name.items():
            if site_name and haystack.split(' ')[0] and haystack.split(' ')[0] in site_name:
                return site
        return None

    # 1. Link unlinked stores.
    linked_site_ids = {b.site_id for b in branches if b.site_id}
    for branch in branches:
        if branch.site_id:
            continue
        site = match_site(branch)
        if site is None and len(branches) <= len(sites):
            site = hq
        if site is not None:
            branch.site_id = site.pk
            branch.save(update_fields=['site'])
            linked_site_ids.add(site.pk)

    # 2. Create the missing store for each branch.
    linked_site_ids = {
        b.site_id for b in Branch.objects.exclude(site__isnull=True).only('site_id')
    }
    first_created = None
    for site in sites:
        if site.pk in linked_site_ids:
            continue
        created = Branch.objects.create(
            site_id=site.pk,
            name=_default_store_name(site.name)[:255],
            address=site.address or '',
            place_name=site.place_name or site.city or '',
            phone=site.phone or '',
            email=site.email or '',
            latitude=site.latitude,
            longitude=site.longitude,
            is_main=bool(site.is_hq),
            is_active=True,
        )
        linked_site_ids.add(site.pk)
        if site.is_hq:
            first_created = created

    # 3. Make sure exactly one store is flagged main when we created one.
    if first_created is not None and not Branch.objects.filter(is_main=True).exists():
        Branch.objects.filter(pk=first_created.pk).update(is_main=True)


def backwards(apps, schema_editor):
    # Unlink only — never delete stores or their stock.
    Branch = apps.get_model('pharmacy_profile', 'Branch')
    Branch.objects.update(site=None)


class Migration(migrations.Migration):

    dependencies = [
        ('clinic_sites', '0002_alter_clinicsite_profile'),
        ('pharmacy_profile', '0012_branch_site'),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
