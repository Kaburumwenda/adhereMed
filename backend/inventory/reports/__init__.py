"""Inventory reporting platform.

A single, configurable reporting engine behind ``/api/inventory/reports/``:

* :mod:`catalog`   — the report registry (columns, filters, options).
* :mod:`datasets`  — one row-builder per report, all returning plain dicts.
* :mod:`render`    — branded PDF renderer (letterhead, watermark, tables).
* :mod:`exporters` — CSV and Excel writers over the same rows.
* :mod:`views`     — catalog / preview / generate endpoints.

Everything shares one shape — ``{'columns': [...], 'rows': [...],
'totals': {...}, 'meta': {...}}`` — so a report only has to declare its
columns and know how to produce its rows; the PDF, the spreadsheet and the
on-screen preview all read the same payload.
"""
from .catalog import CATEGORIES, REPORTS, get_report, catalog_payload  # noqa: F401

__all__ = ['CATEGORIES', 'REPORTS', 'get_report', 'catalog_payload']
