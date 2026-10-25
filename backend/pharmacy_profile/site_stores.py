"""Every clinic branch owns one drug store.

A ``clinic_sites.ClinicSite`` is a physical branch of the clinic; medication
stock, dispensing and transfers all hang off a ``pharmacy_profile.Branch`` (the
drug store). This module keeps the two in lockstep:

* creating a clinic branch creates its drug store;
* renaming a branch renames its store (unless the store name was customised);
* a data migration / management command backfills existing branches.

All calls are schema-safe: they run through the ORM, so django-tenants routes
them to the schema that is currently active.
"""

from django.db import models

# Name suffix used when we generate the store name from a branch name.
STORE_SUFFIX = 'Drug Store'


def default_store_name(site):
    """``"Westlands"`` → ``"Westlands Drug Store"``."""
    base = (getattr(site, 'name', '') or 'Clinic').strip()
    if base.lower().endswith(STORE_SUFFIX.lower()):
        return base
    return f'{base} {STORE_SUFFIX}'


def ensure_store_for_site(site, *, create=True):
    """Return the drug store attached to ``site``, creating it when missing.

    ``create=False`` makes this a pure read (used when rendering lists so a GET
    never mutates data). Returns ``None`` when the store does not exist and
    ``create`` is False.
    """
    if site is None:
        return None
    # Imported lazily: pharmacy_profile imports clinic_sites models and vice versa.
    from .models import Branch

    store = Branch.objects.filter(site_id=site.pk).first()
    if store or not create:
        return store

    return Branch.objects.create(
        site_id=site.pk,
        name=default_store_name(site)[:255],
        address=getattr(site, 'address', '') or '',
        place_name=getattr(site, 'place_name', '') or getattr(site, 'city', '') or '',
        phone=getattr(site, 'phone', '') or '',
        email=getattr(site, 'email', '') or '',
        latitude=getattr(site, 'latitude', None),
        longitude=getattr(site, 'longitude', None),
        is_main=bool(getattr(site, 'is_hq', False)),
        is_active=bool(getattr(site, 'is_active', True)),
    )


def sync_site_to_store(site, created=False):
    """Keep the store's identity aligned with its clinic branch.

    Only fields the operator has not deliberately diverged from are touched:
    the store keeps its own name once it stops looking auto-generated, and its
    own contact details once they differ from the branch's.
    """
    from .models import Branch

    store = Branch.objects.filter(site_id=site.pk).first()
    if store is None:
        if created or getattr(site, 'is_active', True):
            ensure_store_for_site(site)
        return

    updates = []

    # Name: follow the branch while it still looks auto-generated.
    auto_name = default_store_name(site)[:255]
    if store.name in ('', None) or store.name.endswith(STORE_SUFFIX):
        if store.name != auto_name:
            store.name = auto_name
            updates.append('name')

    # HQ branch keeps the "main store" flag.
    if getattr(site, 'is_hq', False) and not store.is_main:
        Branch.objects.filter(is_main=True).update(is_main=False)
        store.is_main = True
        updates.append('is_main')

    if not getattr(site, 'is_active', True) and store.is_active:
        store.is_active = False
        updates.append('is_active')

    if updates:
        store.save(update_fields=updates + ['updated_at'])


def connect_signals():
    """Idempotently hook ``ClinicSite`` saves into the store sync."""
    from django.db.models.signals import post_save

    from clinic_sites.models import ClinicSite

    post_save.connect(
        _on_site_saved,
        sender=ClinicSite,
        dispatch_uid='pharmacy_profile.sync_site_to_store',
        weak=False,
    )


def _on_site_saved(sender, instance, created, **kwargs):
    try:
        sync_site_to_store(instance, created=created)
    except Exception:
        # Store bootstrapping must never break saving a clinic branch — a
        # management command can always backfill (`sync_clinic_stores`).
        pass
