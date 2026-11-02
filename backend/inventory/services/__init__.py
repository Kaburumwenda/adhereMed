"""Domain services for the inventory app.

Business rules that used to live inline in views/serializers live here so
they can be reused (adjustments, stock takes, transfers, imports) and unit
tested without going through HTTP.
"""
from .stock import (  # noqa: F401
    InsufficientStock,
    apply_quantity_change,
    consume_stock,
    receipt_stock,
    reconcile_quantity,
)

__all__ = [
    'InsufficientStock',
    'apply_quantity_change',
    'consume_stock',
    'receipt_stock',
    'reconcile_quantity',
]

# Modules in this package (imported lazily by call sites):
#   anomaly · bins · cycle_count · demand · expiry · forecasting · kpis
#   labels · planning · quality · recall · replenishment · scanning
#   scorecard · valuation
SUBMODULES = (
    'anomaly', 'bins', 'cycle_count', 'demand', 'expiry', 'forecasting',
    'kpis', 'labels', 'planning', 'quality', 'recall', 'replenishment',
    'scanning', 'scorecard', 'valuation',
)
