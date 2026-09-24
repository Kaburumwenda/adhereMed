"""Role-based access control (RBAC) for the inventory module.

Enforcement is capability-based. Every check resolves through
`has_capability(request, cap)`:

  * built-in roles resolve through BUILTIN_ROLE_CAPS (tiers cascade:
    ADMIN > SUPERVISOR > STOCK_OPS > staff/read-only);
  * tenant-created custom roles (RoleDefinition rows) resolve through
    their own capability list, editable on the Roles & Access page.

Capability matrix (built-in roles):

  Capability                     tenant_  branch_  store-  cashier  pharma-  pharma-
                                 admin    admin    keeper          cist     tech
  ----------------------------------------------------------------------------------
  View stock items & batches       ✓        ✓       ✓       ✓        ✓        ✓
  View cost prices                 ✓        ✓       ✓       ✗        ✓        ✗
  Create / edit stock items        ✓        ✓       ✗       ✗        ✗        ✗
  Delete stock items               ✓        ✗       ✗       ✗        ✗        ✗
  Manage categories / units        ✓        ✓       ✗       ✗        ✗        ✗
  Excel import                     ✓        ✓       ✗       ✗        ✗        ✗
  View adjustments                 ✓        ✓       ✓       ✗        ✓        ✓
  Record adjustments               ✓        ✓       ✓       ✗        ✗        ✗
  Run stock takes                  ✓        ✓       ✓       ✗        ✗        ✗
  View transfers                    ✓       ✓       ✓       ✗        ✓        ✓
  Create / receive transfers       ✓       ✓       ✓       ✗        ✗        ✗
  Approve & ship transfers         ✓       ✓       ✗       ✗        ✗        ✗
  View controlled register         ✓       ✓       ✓       ✗        ✗        ✗
  Record controlled entries        ✓       ✗       ✗       ✗        ✗        ✗
  Manage warehouses                ✓        ✗       ✗       ✗        ✗        ✗
  Update org profile               ✓        ✗       ✗       ✗        ✗        ✗
  Change staff roles               ✓        ✗       ✗       ✗        ✗        ✗

Custom roles may be granted any capability above (and are then enforced
everywhere a built-in role would be).
"""
from rest_framework.permissions import IsAuthenticated, SAFE_METHODS

# ── Role tiers (kept for UI/secondary guards) ────────────────────────────
ADMIN_ROLES = {'super_admin', 'tenant_admin', 'inventory_admin', 'admin'}
SUPERVISOR_ROLES = ADMIN_ROLES | {'branch_admin'}
STOCK_OPS_ROLES = SUPERVISOR_ROLES | {'storekeeper'}

# Roles whose till / counter duties do not include cost visibility.
COST_HIDDEN_ROLES = {'cashier', 'pharmacy_tech', 'receptionist'}


def _role(request):
    return getattr(getattr(request, 'user', None), 'role', '') or ''


# ── Capability catalog (drives the Roles & Access page) ──────────────────
CAPABILITY_CATALOG = [
    {'key': 'stock.view', 'label': 'View stock items, batches & levels',
     'group': 'Stock', 'description': 'Read the item catalog and stock quantities.'},
    {'key': 'stock.cost', 'label': 'View cost prices & valuation',
     'group': 'Stock', 'description': 'Purchase costs appear in lists, batches and insights.'},
    {'key': 'stock.manage', 'label': 'Create & edit stock items',
     'group': 'Stock', 'description': 'Register and update items, incl. Excel import.'},
    {'key': 'stock.delete', 'label': 'Delete stock items',
     'group': 'Stock', 'description': 'Destructive — deactivate is the safer alternative.'},
    {'key': 'catalog.manage', 'label': 'Manage categories, units & medication catalog',
     'group': 'Stock', 'description': 'Create and edit catalog reference data.'},
    {'key': 'adjustment.view', 'label': 'View stock adjustments',
     'group': 'Adjustments', 'description': 'Read the adjustment ledger.'},
    {'key': 'adjustment.create', 'label': 'Record stock adjustments',
     'group': 'Adjustments', 'description': 'Damage, expiry, corrections and returns to supplier.'},
    {'key': 'stocktake.run', 'label': 'Run stock takes (cycle counts)',
     'group': 'Stock take', 'description': 'Create, count and complete inventory counts.'},
    {'key': 'transfer.view', 'label': 'View warehouse transfers',
     'group': 'Transfers', 'description': 'Read the transfer list and notes.'},
    {'key': 'transfer.create', 'label': 'Create & submit transfers',
     'group': 'Transfers', 'description': 'Move stock between warehouses.'},
    {'key': 'transfer.approve', 'label': 'Approve & ship transfers',
     'group': 'Transfers', 'description': 'Supervisory sign-off — stock leaves the source warehouse.'},
    {'key': 'transfer.receive', 'label': 'Receive transfers at destination',
     'group': 'Transfers', 'description': 'Confirm quantities that physically arrived.'},
    {'key': 'controlled.view', 'label': 'View controlled-substance register',
     'group': 'Controlled', 'description': 'Read the regulatory register.'},
    {'key': 'controlled.manage', 'label': 'Record controlled-substance entries',
     'group': 'Controlled', 'description': 'Compliance record — grant carefully.'},
    {'key': 'warehouse.manage', 'label': 'Create, edit & delete warehouses',
     'group': 'Administration', 'description': 'Org-level structure.'},
    {'key': 'org.manage', 'label': 'Update organization profile',
     'group': 'Administration', 'description': 'Name, address, contacts, logo.'},
    {'key': 'rbac.manage', 'label': 'Change staff roles',
     'group': 'Administration', 'description': 'Assign or reassign member roles.'},
]
ALL_CAP_KEYS = {c['key'] for c in CAPABILITY_CATALOG}
CAPABILITY_LABELS = {c['key']: c['label'] for c in CAPABILITY_CATALOG}

# ── Built-in role → capabilities ─────────────────────────────────────────
BUILTIN_ROLE_CAPS = {
    'tenant_admin': ALL_CAP_KEYS,
    'inventory_admin': ALL_CAP_KEYS,
    'admin': ALL_CAP_KEYS,
    'branch_admin': ALL_CAP_KEYS - {
        'stock.delete', 'controlled.manage', 'warehouse.manage', 'org.manage',
        'rbac.manage',
    },
    'storekeeper': {
        'stock.view', 'stock.cost',
        'adjustment.view', 'adjustment.create',
        'stocktake.run',
        'transfer.view', 'transfer.create', 'transfer.receive',
        'controlled.view',
    },
    'cashier': {'stock.view'},
    'pharmacist': {'stock.view', 'stock.cost', 'adjustment.view', 'transfer.view'},
    'pharmacy_tech': {'stock.view', 'adjustment.view', 'transfer.view'},
    'receptionist': {'stock.view', 'adjustment.view', 'transfer.view'},
}

# ── Presentation metadata (drives the Roles & Access admin page) ─────────
ROLE_META = [
    {'key': 'tenant_admin', 'label': 'Tenant Admin', 'tier': 'admin',
     'icon': 'mdi-shield-account',
     'description': 'Owner of the organization — full control of every module.'},
    {'key': 'inventory_admin', 'label': 'Inventory Admin', 'tier': 'admin',
     'icon': 'mdi-shield-crown-outline',
     'description': 'Manages stock, warehouses, procurement and staff roles.'},
    {'key': 'branch_admin', 'label': 'Branch / Warehouse Manager', 'tier': 'supervisor',
     'icon': 'mdi-source-branch',
     'description': 'Runs a warehouse: edits items, approves transfers, manages its team.'},
    {'key': 'storekeeper', 'label': 'Storekeeper', 'tier': 'stock_ops',
     'icon': 'mdi-warehouse',
     'description': 'Warehouse operator: counts, adjustments, creates & receives transfers.'},
    {'key': 'cashier', 'label': 'Cashier', 'tier': 'staff',
     'icon': 'mdi-cash-register',
     'description': 'Sells at POS. Views stock and sales only — costs hidden.'},
    {'key': 'pharmacist', 'label': 'Pharmacist', 'tier': 'staff',
     'icon': 'mdi-pill',
     'description': 'Clinical counter role with read access to stock and adjustments.'},
    {'key': 'pharmacy_tech', 'label': 'Pharmacy Tech', 'tier': 'staff',
     'icon': 'mdi-pill-multiple',
     'description': 'Counter role with read access to stock history.'},
]

# Built-in roles that may be assigned from the Roles & Access page. The
# tenant owner role can only be transferred through the platform superadmin.
ASSIGNABLE_ROLES = ['inventory_admin', 'branch_admin', 'storekeeper', 'cashier']

# Built-in roles whose capabilities tenants may customize (capability
# override rows). The tenant owner role is platform-managed and locked.
EDITABLE_BUILTIN_ROLES = {
    'inventory_admin', 'branch_admin', 'storekeeper', 'cashier',
    'pharmacist', 'pharmacy_tech', 'receptionist',
}

# ── Pharmacy tenant role catalog ─────────────────────────────────────────
# Pharmacy tenants use the same Roles & Access page but see a pharmacy
# role set instead of the inventory/warehouse set. There is no `pharmacy_admin`
# role in the User model — pharmacy tenants are owned by `tenant_admin`, so
# the pharmacy catalog's admin tier is mapped onto `tenant_admin` itself and
# the rest of the operational roles follow the existing built-in model.
PHARMACY_ROLE_META = [
    {'key': 'tenant_admin', 'label': 'Pharmacy Admin', 'tier': 'admin',
     'icon': 'mdi-shield-account',
     'description': 'Owner of the pharmacy — full control of every module.'},
    {'key': 'branch_admin', 'label': 'Branch / Store Manager', 'tier': 'supervisor',
     'icon': 'mdi-source-branch',
     'description': 'Runs a branch: edits stock, approves transfers, manages its team.'},
    {'key': 'pharmacist', 'label': 'Pharmacist', 'tier': 'staff',
     'icon': 'mdi-pill',
     'description': 'Clinical counter role with read access to stock and adjustments.'},
    {'key': 'pharmacy_tech', 'label': 'Pharmacy Tech', 'tier': 'staff',
     'icon': 'mdi-pill-multiple',
     'description': 'Counter role with read access to stock history.'},
    {'key': 'cashier', 'label': 'Cashier', 'tier': 'staff',
     'icon': 'mdi-cash-register',
     'description': 'Sells at POS. Views stock and sales only — costs hidden.'},
    {'key': 'receptionist', 'label': 'Receptionist', 'tier': 'staff',
     'icon': 'mdi-deskphone',
     'description': 'Front-desk role with read access to stock levels.'},
]

# Operational roles assignable on the pharmacy Roles & Access page.
PHARMACY_ASSIGNABLE_ROLES = ['branch_admin', 'pharmacist', 'pharmacy_tech',
                             'cashier', 'receptionist']

# Built-in roles whose capabilities pharmacy tenants may customize.
PHARMACY_EDITABLE_BUILTIN_ROLES = {
    'branch_admin', 'pharmacist', 'pharmacy_tech', 'cashier', 'receptionist',
}

# Capabilities that must never be removed from a built-in role override.
PROTECTED_BUILTIN_CAPS = {'stock.view'}

# Roles that cannot be used as custom-role keys (reserved).
RESERVED_ROLE_KEYS = set(BUILTIN_ROLE_CAPS) | {
    'super_admin', 'patient', 'caregiver', 'doctor', 'nurse', 'midwife',
    'dentist', 'clinical_officer', 'lab_tech', 'radiologist', 'homecare_admin',
}


# ── Capability resolution ────────────────────────────────────────────────
def _role_caps(role):
    """Resolve a role's capability set:
    1. a tenant RoleDefinition row wins (custom role OR built-in override),
    2. built-in roles fall back to the platform defaults in code."""
    from .models import RoleDefinition
    try:
        rd = RoleDefinition.objects.filter(key=role, is_active=True).first()
    except Exception:
        # The RoleDefinition table may not exist yet in a schema whose
        # tenant migrations are pending — fall back to built-in defaults
        # so roles and permissions still resolve instead of erroring.
        rd = None
    if rd is not None:
        return set(rd.capabilities or [])
    if role in BUILTIN_ROLE_CAPS:
        return set(BUILTIN_ROLE_CAPS[role])
    return set()


def get_role_capabilities(request):
    """Resolve the requesting user's full capability set (per-request cache)."""
    # A request-less call (e.g. a serializer instantiated without context)
    # has no user and cannot carry a per-request cache — resolve to no
    # capabilities rather than raising on attribute assignment.
    if request is None:
        return set()
    cache = getattr(request, '_rbac_caps_cache', None)
    if cache is not None:
        return cache
    user = getattr(request, 'user', None)
    role = _role(request)
    if role == 'super_admin' or getattr(user, 'is_superuser', False):
        caps = ALL_CAP_KEYS
    else:
        caps = _role_caps(role)
    try:
        request._rbac_caps_cache = caps
    except (AttributeError, TypeError):
        # Objects that disallow arbitrary attribute assignment (or proxy
        # wrappers) still get the resolved capabilities, just uncached.
        pass
    return caps


def has_capability(request, cap):
    return cap in get_role_capabilities(request)


def can_view_cost(request):
    """Cost prices are hidden from roles without the stock.cost capability."""
    return has_capability(request, 'stock.cost')


def has_role(request, roles):
    return _role(request) in roles


def capability_matrix():
    """The capability catalog (labels + allowed built-in roles) for the
    Roles & Access page."""
    return [
        {**cap, 'roles': sorted(
            [k for k, caps in BUILTIN_ROLE_CAPS.items() if cap['key'] in caps])}
        for cap in CAPABILITY_CATALOG
    ]


# ── Permission classes (capability-based) ────────────────────────────────
class CapabilityPermission(IsAuthenticated):
    """Reads require `view_capability`, writes require `write_capability`.
    Both resolve through has_capability (built-in or custom roles)."""
    view_capability = 'stock.view'
    write_capability = 'stock.manage'

    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        cap = self.view_capability if request.method in SAFE_METHODS else self.write_capability
        return has_capability(request, cap)


class InventoryPermission(CapabilityPermission):
    """Stock items, categories, units, batches. Destructive deletes are
    further restricted on the viewset itself (stock.delete capability)."""
    view_capability = 'stock.view'
    write_capability = 'stock.manage'


class AdjustmentPermission(CapabilityPermission):
    view_capability = 'adjustment.view'
    write_capability = 'adjustment.create'


class StockTakePermission(CapabilityPermission):
    view_capability = 'stocktake.run'
    write_capability = 'stocktake.run'


class TransferPermission(CapabilityPermission):
    view_capability = 'transfer.view'
    write_capability = 'transfer.create'


class ControlledRegisterPermission(CapabilityPermission):
    view_capability = 'controlled.view'
    write_capability = 'controlled.manage'


class TenantAdminOnly(IsAuthenticated):
    """Guard for org-level admin surfaces (RBAC management itself)."""
    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        role = _role(request)
        return role == 'super_admin' or role in ADMIN_ROLES
