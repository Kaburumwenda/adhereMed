"""Warehouse execution helpers: bin hierarchy, putaway and pick (Tier 4).

The bin model supersedes the free-text ``location_in_store`` once a
placement exists. Putaway suggests a slot by capacity and cold-chain
compatibility; pick builds a FEFO walk path ordered by bin.
"""
from __future__ import annotations

from collections import defaultdict

from django.db import transaction

from ..models import (MedicationStock, StockBatch, StockPlacement,
                      WarehouseBin)


def _compatible(bin_obj, stock) -> bool:
    """A cold-chain item must land in a cold-chain bin (and vice versa)."""
    policy = getattr(stock, 'policy', None)
    zone = policy.storage_zone if policy else None
    if bin_obj.storage_zone and zone and bin_obj.storage_zone_id != zone.id:
        return False
    return True


def _free_units(bin_obj) -> float:
    """Free units, treating "no capacity set" as unbounded."""
    free = bin_obj.free_units
    return float('inf') if free is None else float(free)


def suggest_putaway(stock, quantity: int, *, branch_id=None) -> dict | None:
    """Best bin for ``quantity`` units of ``stock``.

    Preference: an existing placement (consolidate) → the emptiest
    compatible bin with capacity → the emptiest compatible bin at all.
    """
    branch_id = branch_id or stock.branch_id
    bins = list(WarehouseBin.objects
                .filter(branch_id=branch_id, is_active=True)
                .select_related('storage_zone'))
    if not bins:
        return None

    existing = (StockPlacement.objects
                .filter(stock=stock, bin__in=bins)
                .select_related('bin')
                .order_by('-quantity')
                .first())
    if existing:
        free = existing.bin.free_units
        if free is None or free >= quantity:
            return {'bin': existing.bin, 'reason': 'Consolidate with existing stock'}

    with_capacity = [
        b for b in bins
        if _compatible(b, stock)
        and (b.free_units is None or b.free_units >= quantity)
    ]
    pool = with_capacity or [b for b in bins if _compatible(b, stock)]
    if not pool:
        return None

    pool.sort(key=lambda b: (b.fill_pct, -_free_units(b), b.used_units))
    target = pool[0]
    reason = 'Emptiest compatible bin' if with_capacity else 'No bin has enough free capacity'
    return {'bin': target, 'reason': reason}


@transaction.atomic
def place_stock(stock, bin_obj, quantity: int, *, batch=None) -> StockPlacement:
    """Add ``quantity`` units to a bin (idempotent per stock/batch)."""
    placement, created = StockPlacement.objects.get_or_create(
        bin=bin_obj, stock=stock, batch=batch,
        defaults={'quantity': 0})
    placement.quantity = (0 if created else placement.quantity) + int(quantity)
    placement.save(update_fields=['quantity', 'updated_at'])
    return placement


@transaction.atomic
def move_placement(placement: StockPlacement, target_bin) -> StockPlacement:
    """Move a placement to another bin (merging if the target holds some)."""
    merged, _ = StockPlacement.objects.get_or_create(
        bin=target_bin, stock=placement.stock, batch=placement.batch,
        defaults={'quantity': 0})
    merged.quantity += placement.quantity
    merged.save(update_fields=['quantity', 'updated_at'])
    if merged.pk != placement.pk:
        placement.delete()
    return merged


def pick_list(*, branch_id=None, limit: int = 50) -> list[dict]:
    """FEFO pick suggestions: earliest expiry first, grouped by bin."""
    batches = (StockBatch.objects
               .filter(quantity_remaining__gt=0, is_blocked=False,
                       expiry_date__isnull=False)
               .select_related('stock', 'stock__unit', 'stock__branch'))
    if branch_id:
        batches = batches.filter(stock__branch_id=branch_id)
    batches = batches.order_by('expiry_date')[:limit]

    placements = defaultdict(list)
    for placement in (StockPlacement.objects
                      .filter(batch_id__in=[b.id for b in batches])
                      .select_related('bin')):
        placements[placement.batch_id].append(placement)

    rows = []
    for batch in batches:
        bins = placements.get(batch.id, [])
        rows.append({
            'batch_id': batch.id,
            'stock_id': batch.stock_id,
            'name': batch.stock.medication_name,
            'unit': batch.stock.unit.abbreviation if batch.stock.unit else '',
            'batch_number': batch.batch_number,
            'expiry_date': batch.expiry_date.isoformat() if batch.expiry_date else None,
            'days_to_expiry': batch.days_to_expiry,
            'quantity': batch.quantity_remaining,
            'bins': [
                {'id': p.bin_id, 'code': p.bin.canonical, 'qty': p.quantity}
                for p in bins
            ],
            'bin_label': bins[0].bin.canonical if bins else '',
            'unplaced': not bins,
        })
    return rows


def bin_utilisation(*, branch_id=None) -> list[dict]:
    bins = WarehouseBin.objects.select_related('branch', 'storage_zone')
    if branch_id:
        bins = bins.filter(branch_id=branch_id)
    out = []
    for bin_obj in bins:
        used = bin_obj.used_units
        out.append({
            'id': bin_obj.id,
            'name': bin_obj.name,
            'code': bin_obj.canonical,
            'branch_name': bin_obj.branch.name,
            'zone_name': bin_obj.storage_zone.name if bin_obj.storage_zone else '',
            'capacity_units': bin_obj.capacity_units,
            'used_units': used,
            'free_units': bin_obj.free_units,
            'fill_pct': bin_obj.fill_pct,
            'skus': bin_obj.placements.values('stock_id').distinct().count(),
            'is_active': bin_obj.is_active,
        })
    out.sort(key=lambda r: -r['fill_pct'])
    return out


def unplaced_stock(*, branch_id=None, limit: int = 100) -> list[dict]:
    """Stock items with units on hand but no bin assignment."""
    placed = set(StockPlacement.objects.values_list('stock_id', flat=True))
    qs = (MedicationStock.objects.with_quantities()
          .filter(is_active=True, annotated_total_quantity__gt=0)
          .exclude(id__in=placed)
          .select_related('branch', 'unit'))
    if branch_id:
        qs = qs.filter(branch_id=branch_id)
    return [{
        'id': s.id,
        'name': s.medication_name,
        'branch_name': s.branch.name if s.branch else '',
        'quantity': s.total_quantity,
        'unit': s.unit.abbreviation if s.unit else '',
        'location': s.location_in_store,
    } for s in qs[:limit]]
