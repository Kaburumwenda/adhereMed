"""Report registry: what can be reported, and which columns it offers.

A report is a plain dict so the API can serialise it straight to the client:

``id``          stable key used by ``/reports/preview/`` and ``/generate/``
``label``       human title, also the default PDF heading
``description`` one line explaining what the sheet answers
``category``    grouping in the picker (see :data:`CATEGORIES`)
``icon``        mdi icon for the picker card
``columns``     ordered ``{key, label, type, align, width}`` definitions
``defaults``    column keys selected when the report is first opened
``group_by``    breakdown dimensions offered (``''`` = no breakdown)
``dated``       whether ``date_from`` / ``date_to`` apply
``branched``    whether a warehouse filter applies
"""
from __future__ import annotations

#: Picker groupings. Order here is the order in the UI.
CATEGORIES = [
    {'key': 'stock', 'label': 'Stock & Valuation',
     'blurb': 'What is on the shelf, what it is worth, and what is not sellable.'},
    {'key': 'operations', 'label': 'Operations',
     'blurb': 'Every movement, adjustment and warehouse transfer in the period.'},
    {'key': 'compliance', 'label': 'Expiry & Compliance',
     'blurb': 'Dated stock, recalls and the controlled-substance register.'},
    {'key': 'planning', 'label': 'Planning & Suppliers',
     'blurb': 'Replenishment need, ABC classification and supplier performance.'},
]


def _col(key, label, type_='text', align='left', width=1.0):
    """Shorthand column definition."""
    return {'key': key, 'label': label, 'type': type_, 'align': align,
            'width': width}


# ── Shared column groups (kept identical so two reports never disagree) ──
_COLS_IDENTITY = [
    _col('medication_id', 'Code', width=0.7),
    _col('medication_name', 'Item', width=2.4),
    _col('strength', 'Strength', width=0.9),
    _col('category', 'Category', width=1.1),
    _col('classification', 'Type', width=1.0),
]

_COLS_QUANTITY = [
    _col('total_quantity', 'On hand', 'int', 'right', 0.8),
    _col('sellable_quantity', 'Sellable', 'int', 'right', 0.8),
    _col('expired_quantity', 'Expired', 'int', 'right', 0.8),
    _col('committed_quantity', 'Committed', 'int', 'right', 0.9),
    _col('available_quantity', 'Available', 'int', 'right', 0.9),
    _col('reorder_level', 'Reorder at', 'int', 'right', 0.9),
]

_COLS_PRICE = [
    _col('unit', 'Unit', width=0.6),
    _col('cost_price', 'Unit cost', 'money', 'right', 1.0),
    _col('selling_price', 'Unit price', 'money', 'right', 1.0),
    _col('value_cost', 'Value at cost', 'money', 'right', 1.2),
    _col('value_retail', 'Value at retail', 'money', 'right', 1.2),
]

_COLS_LOCATION = [
    _col('branch', 'Warehouse', width=1.2),
    _col('location', 'Location', width=1.0),
    _col('barcode', 'Barcode', width=1.0),
]


REPORTS = [
    # ══════════════════════════════════════════════════════════════════
    #  Stock & valuation
    # ══════════════════════════════════════════════════════════════════
    {
        'id': 'stock_on_hand',
        'label': 'Stock on hand',
        'description': 'Every active item with physical, sellable and available '
                       'quantities plus cost and retail value.',
        'category': 'stock',
        'icon': 'mdi-package-variant-closed',
        'dated': False,
        'branched': True,
        'group_by': ['category', 'classification', 'branch'],
        'columns': (_COLS_IDENTITY + _COLS_QUANTITY + _COLS_PRICE
                    + [_col('status', 'Status', 'badge', 'center', 0.8)]
                    + [_col('next_expiry', 'Next expiry', 'date', 'center', 1.0)]
                    + _COLS_LOCATION),
        'defaults': ['medication_name', 'strength', 'category', 'branch',
                     'total_quantity', 'sellable_quantity', 'available_quantity',
                     'reorder_level', 'value_cost', 'status'],
    },
    {
        'id': 'valuation',
        'label': 'Valuation',
        'description': 'Capital tied up per item: cost value, retail value and '
                       'the margin the shelf is carrying.',
        'category': 'stock',
        'icon': 'mdi-scale-balance',
        'dated': False,
        'branched': True,
        'group_by': ['category', 'classification', 'branch'],
        'columns': (_COLS_IDENTITY + [
            _col('quantity', 'Qty', 'int', 'right', 0.8),
            _col('unit_cost', 'Unit cost', 'money', 'right', 1.0),
            _col('value_cost', 'Value at cost', 'money', 'right', 1.3),
            _col('value_retail', 'Value at retail', 'money', 'right', 1.3),
            _col('margin', 'Gross margin', 'money', 'right', 1.2),
            _col('margin_pct', 'Margin %', 'percent', 'right', 0.9),
        ] + [_col('branch', 'Warehouse', width=1.2)]),
        'defaults': ['medication_name', 'category', 'branch', 'quantity',
                     'unit_cost', 'value_cost', 'value_retail', 'margin_pct'],
    },
    {
        'id': 'dead_stock',
        'label': 'Dead & slow stock',
        'description': 'Items holding stock that have not sold in the stale '
                       'window — idle capital to move or write off.',
        'category': 'stock',
        'icon': 'mdi-package-off',
        'dated': False,
        'branched': True,
        'group_by': ['category', 'branch'],
        'columns': (_COLS_IDENTITY + [
            _col('quantity', 'On hand', 'int', 'right', 0.8),
            _col('value_cost', 'Value at cost', 'money', 'right', 1.2),
            _col('last_sold', 'Last sold', 'date', 'center', 1.0),
            _col('days_idle', 'Days idle', 'int', 'right', 0.9),
            _col('branch', 'Warehouse', width=1.2),
        ]),
        'defaults': ['medication_name', 'category', 'branch', 'quantity',
                     'value_cost', 'last_sold', 'days_idle'],
    },

    # ══════════════════════════════════════════════════════════════════
    #  Operations
    # ══════════════════════════════════════════════════════════════════
    {
        'id': 'movements',
        'label': 'Stock movement ledger',
        'description': 'One line per quantity change: receipts, sales, '
                       'dispensing, adjustments, transfers and write-offs.',
        'category': 'operations',
        'icon': 'mdi-swap-vertical-bold',
        'dated': True,
        'branched': True,
        'group_by': ['reason', 'type', 'branch'],
        'columns': [
            _col('occurred_at', 'When', 'datetime', 'left', 1.3),
            _col('movement_type', 'Type', 'badge', 'center', 0.9),
            _col('reason', 'Reason', width=1.2),
            _col('medication_name', 'Item', width=2.2),
            _col('batch_number', 'Batch', width=1.0),
            _col('reference', 'Reference', width=1.2),
            _col('branch', 'Warehouse', width=1.1),
            _col('quantity_in', 'In', 'int', 'right', 0.7),
            _col('quantity_out', 'Out', 'int', 'right', 0.7),
            _col('unit_cost', 'Unit cost', 'money', 'right', 1.0),
            _col('value', 'Value', 'money', 'right', 1.1),
            _col('user', 'By', width=1.1),
        ],
        'defaults': ['occurred_at', 'movement_type', 'reason', 'medication_name',
                     'reference', 'quantity_in', 'quantity_out', 'value'],
    },
    {
        'id': 'adjustments',
        'label': 'Adjustments & write-offs',
        'description': 'Damage, theft, expiry, count corrections and supplier '
                       'returns, with the cost each one removed.',
        'category': 'operations',
        'icon': 'mdi-tune',
        'dated': True,
        'branched': True,
        'group_by': ['reason', 'branch'],
        'columns': [
            _col('created_at', 'When', 'datetime', 'left', 1.3),
            _col('reason_label', 'Reason', 'badge', 'center', 1.1),
            _col('medication_name', 'Item', width=2.2),
            _col('batch_number', 'Batch', width=1.0),
            _col('quantity_change', 'Qty', 'int', 'right', 0.7),
            _col('value', 'Value', 'money', 'right', 1.1),
            _col('branch', 'Warehouse', width=1.1),
            _col('user', 'By', width=1.1),
            _col('notes', 'Notes', width=1.8),
        ],
        'defaults': ['created_at', 'reason_label', 'medication_name',
                     'quantity_change', 'value', 'user', 'notes'],
    },
    {
        'id': 'transfers',
        'label': 'Warehouse transfers',
        'description': 'Shipments between warehouses with sent, received and '
                       'variance quantities.',
        'category': 'operations',
        'icon': 'mdi-truck-delivery-outline',
        'dated': True,
        'branched': True,
        'group_by': ['status', 'source_branch', 'dest_branch'],
        'columns': [
            _col('requested_at', 'Requested', 'datetime', 'left', 1.2),
            _col('reference', 'Transfer', width=1.0),
            _col('status', 'Status', 'badge', 'center', 0.9),
            _col('source_branch', 'From', width=1.2),
            _col('dest_branch', 'To', width=1.2),
            _col('priority', 'Priority', width=0.8),
            _col('lines', 'Lines', 'int', 'right', 0.6),
            _col('units_sent', 'Sent', 'int', 'right', 0.7),
            _col('units_received', 'Received', 'int', 'right', 0.8),
            _col('variance', 'Variance', 'int', 'right', 0.8),
            _col('value', 'Value', 'money', 'right', 1.1),
        ],
        'defaults': ['requested_at', 'reference', 'status', 'source_branch',
                     'dest_branch', 'units_sent', 'units_received', 'variance'],
    },
    {
        'id': 'cycle_count',
        'label': 'Cycle count variance',
        'description': 'Stock-take lines with expected vs counted quantities '
                       'and the value of each variance.',
        'category': 'operations',
        'icon': 'mdi-clipboard-check-outline',
        'dated': True,
        'branched': True,
        'group_by': ['count', 'branch'],
        'columns': [
            _col('completed_at', 'Completed', 'date', 'center', 0.9),
            _col('reference', 'Sheet', width=0.9),
            _col('medication_name', 'Item', width=2.2),
            _col('expected_quantity', 'Expected', 'int', 'right', 0.8),
            _col('counted_quantity', 'Counted', 'int', 'right', 0.8),
            _col('variance', 'Variance', 'int', 'right', 0.8),
            _col('variance_value', 'Variance value', 'money', 'right', 1.1),
            _col('branch', 'Warehouse', width=1.1),
        ],
        'defaults': ['completed_at', 'reference', 'medication_name',
                     'expected_quantity', 'counted_quantity', 'variance',
                     'variance_value'],
    },

    # ══════════════════════════════════════════════════════════════════
    #  Expiry & compliance
    # ══════════════════════════════════════════════════════════════════
    {
        'id': 'expiry',
        'label': 'Expiry schedule',
        'description': 'Live batches ordered by expiry, with days remaining '
                       'and the capital at risk.',
        'category': 'compliance',
        'icon': 'mdi-clock-alert-outline',
        # Date-scoped on the expiry date — "what falls due between X and Y"
        # is the question this sheet answers, so the range must apply.
        'dated': True,
        'branched': True,
        'group_by': ['month', 'category', 'branch'],
        'columns': [
            _col('medication_name', 'Item', width=2.4),
            _col('strength', 'Strength', width=0.9),
            _col('batch_number', 'Batch', width=1.1),
            _col('expiry_date', 'Expires', 'date', 'center', 0.9),
            _col('days_to_expiry', 'Days left', 'int', 'right', 0.8),
            _col('quantity_remaining', 'Qty', 'int', 'right', 0.7),
            _col('unit_cost', 'Unit cost', 'money', 'right', 1.0),
            _col('value', 'Value at risk', 'money', 'right', 1.2),
            _col('risk', 'Risk', 'badge', 'center', 0.8),
            _col('branch', 'Warehouse', width=1.1),
        ],
        'defaults': ['medication_name', 'batch_number', 'expiry_date',
                     'days_to_expiry', 'quantity_remaining', 'value', 'risk'],
    },
    {
        'id': 'low_stock',
        'label': 'Low & out of stock',
        'description': 'Items at or below their reorder level, or with nothing '
                       'sellable on the shelf.',
        'category': 'compliance',
        'icon': 'mdi-bell-alert',
        'dated': False,
        'branched': True,
        'group_by': ['status', 'category', 'branch'],
        'columns': (_COLS_IDENTITY + [
            _col('available_quantity', 'Available', 'int', 'right', 0.9),
            _col('reorder_level', 'Reorder at', 'int', 'right', 0.9),
            _col('shortfall', 'Shortfall', 'int', 'right', 0.9),
            _col('status', 'Status', 'badge', 'center', 0.8),
            _col('branch', 'Warehouse', width=1.2),
        ]),
        'defaults': ['medication_name', 'category', 'branch',
                     'available_quantity', 'reorder_level', 'shortfall', 'status'],
    },
    {
        'id': 'controlled_register',
        'label': 'Controlled substances register',
        'description': 'Regulatory register of every controlled-substance '
                       'dispensing, receipt, adjustment and destruction.',
        'category': 'compliance',
        'icon': 'mdi-shield-lock-outline',
        'dated': True,
        'branched': False,
        'group_by': ['action', 'schedule'],
        'columns': [
            _col('created_at', 'When', 'datetime', 'left', 1.3),
            _col('medication_name', 'Item', width=2.2),
            _col('schedule', 'Schedule', width=0.9),
            _col('action', 'Action', 'badge', 'center', 0.9),
            _col('quantity', 'Qty', 'num', 'right', 0.7),
            _col('batch_number', 'Batch', width=1.0),
            _col('patient_name', 'Patient', width=1.4),
            _col('prescriber_name', 'Prescriber', width=1.4),
            _col('prescription_reference', 'Prescription', width=1.1),
            _col('user', 'Recorded by', width=1.1),
        ],
        'defaults': ['created_at', 'medication_name', 'schedule', 'action',
                     'quantity', 'patient_name', 'prescriber_name', 'user'],
    },

    # ══════════════════════════════════════════════════════════════════
    #  Planning & suppliers
    # ══════════════════════════════════════════════════════════════════
    {
        'id': 'replenishment',
        'label': 'Replenishment plan',
        'description': 'What to buy, how much and from whom, ranked by '
                       'urgency.',
        'category': 'planning',
        'icon': 'mdi-cart-arrow-down',
        'dated': False,
        'branched': True,
        'group_by': ['severity', 'supplier', 'branch'],
        'columns': [
            _col('medication_name', 'Item', width=2.4),
            _col('branch', 'Warehouse', width=1.2),
            _col('on_hand', 'On hand', 'int', 'right', 0.7),
            _col('on_order', 'On order', 'int', 'right', 0.8),
            _col('reorder_point', 'ROP', 'num', 'right', 0.7),
            _col('days_cover', 'Cover (d)', 'num', 'right', 0.8),
            _col('suggested_quantity', 'Order qty', 'int', 'right', 0.9),
            _col('unit_cost', 'Unit cost', 'money', 'right', 1.0),
            _col('estimated_cost', 'Est. cost', 'money', 'right', 1.1),
            _col('supplier_name', 'Supplier', width=1.4),
            _col('severity', 'Severity', 'badge', 'center', 0.8),
        ],
        'defaults': ['medication_name', 'branch', 'on_hand', 'days_cover',
                     'suggested_quantity', 'estimated_cost', 'supplier_name',
                     'severity'],
    },
    {
        'id': 'abc_analysis',
        'label': 'ABC / XYZ classification',
        'description': 'Value-based ABC and demand-stability XYZ classes, with '
                       'the planning parameters derived from them.',
        'category': 'planning',
        'icon': 'mdi-chart-timeline-variant',
        # Date-scoped: ABC/XYZ are recomputed from consumption inside the chosen
        # window, so picking a period actually changes the letters.
        'dated': True,
        'branched': True,
        'group_by': ['abc_class', 'xyz_class', 'branch'],
        'columns': [
            _col('medication_name', 'Item', width=2.4),
            _col('abc_class', 'ABC', 'badge', 'center', 0.6),
            _col('xyz_class', 'XYZ', 'badge', 'center', 0.6),
            _col('value_share_pct', 'Value share', 'percent', 'right', 0.9),
            _col('avg_daily_demand', 'Avg/day', 'num', 'right', 0.9),
            _col('reorder_point', 'ROP', 'num', 'right', 0.8),
            _col('safety_stock', 'Safety', 'num', 'right', 0.8),
            _col('eoq', 'EOQ', 'num', 'right', 0.8),
            _col('lead_time_days', 'Lead (d)', 'int', 'right', 0.8),
            _col('forecast_mape', 'MAPE %', 'num', 'right', 0.8),
            _col('branch', 'Warehouse', width=1.1),
        ],
        'defaults': ['medication_name', 'abc_class', 'xyz_class',
                     'value_share_pct', 'reorder_point', 'eoq', 'lead_time_days'],
    },
    {
        'id': 'supplier_performance',
        'label': 'Supplier performance',
        'description': 'On-time-in-full, fill rate, lead time and the composite '
                       'grade for every rated supplier.',
        'category': 'planning',
        'icon': 'mdi-account-star-outline',
        'dated': False,
        'branched': False,
        'group_by': ['grade', 'risk'],
        'columns': [
            _col('supplier', 'Supplier', width=2.0),
            _col('grade', 'Grade', 'badge', 'center', 0.7),
            _col('score', 'Score', 'num', 'right', 0.7),
            _col('otif_pct', 'OTIF %', 'percent', 'right', 0.8),
            _col('fill_rate_pct', 'Fill rate %', 'percent', 'right', 0.9),
            _col('on_time_pct', 'On time %', 'percent', 'right', 0.9),
            _col('avg_lead_time_days', 'Lead (d)', 'num', 'right', 0.8),
            _col('orders_count', 'Orders', 'int', 'right', 0.7),
            _col('risk', 'Risk', 'badge', 'center', 0.8),
            _col('period_end', 'Period', 'date', 'center', 0.9),
        ],
        'defaults': ['supplier', 'grade', 'score', 'otif_pct', 'fill_rate_pct',
                     'on_time_pct', 'avg_lead_time_days', 'risk'],
    },
]

REPORTS_BY_ID = {r['id']: r for r in REPORTS}


def get_report(report_id: str) -> dict | None:
    """Look a report up by id (``None`` when unknown)."""
    return REPORTS_BY_ID.get((report_id or '').strip())


def sanitize_columns(report: dict, requested) -> list[dict]:
    """Return the ordered column definitions to render.

    Only keys the report actually declares are kept, and the report's own
    order wins — a client cannot inject an arbitrary field, reorder the sheet
    into nonsense, or drop every column.
    """
    allowed = {c['key']: c for c in report['columns']}
    wanted = [k for k in (requested or []) if k in allowed]
    if not wanted:
        wanted = [k for k in report['defaults'] if k in allowed]
    if not wanted:
        wanted = [c['key'] for c in report['columns']]
    return [allowed[k] for k in allowed if k in wanted]


def catalog_payload() -> dict:
    """Everything the picker needs, in one payload."""
    return {
        'categories': CATEGORIES,
        'reports': [
            {
                'id': r['id'],
                'label': r['label'],
                'description': r['description'],
                'category': r['category'],
                'icon': r['icon'],
                'dated': r['dated'],
                'branched': r['branched'],
                'group_by': r['group_by'],
                'columns': r['columns'],
                'defaults': r['defaults'],
            }
            for r in REPORTS
        ],
    }
