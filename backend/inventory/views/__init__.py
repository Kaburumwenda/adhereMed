"""Inventory API views, split by domain.

``inventory.urls`` imports the viewsets from this package, so the public
surface (``from inventory import views``) is unchanged.
"""
from .analytics import InventoryAnalyticsView, InventoryOverviewView  # noqa: F401
from .catalog import CategoryViewSet, ClassificationViewSet, UnitViewSet  # noqa: F401
from .controlled import ControlledSubstanceLogViewSet  # noqa: F401
from .counts import (  # noqa: F401
    InventoryCountViewSet,
    StockTakeBoardView,
    StockTakeRegisterPdfView,
)
from .execution import (  # noqa: F401
    LabelPrintView,
    ScanVerifyView,
    StockPlacementSerializer,
    StockPlacementViewSet,
    WarehouseBinSerializer,
    WarehouseBinViewSet,
)
from .insights import (  # noqa: F401
    AnomalyViewSet,
    CycleCountPlanView,
    InsightsView,
    InventorySnapshotViewSet,
    LandedCostView,
    PlanRefreshView,
    SupplierScorecardView,
    WhatIfView,
    WriteOffRequestSerializer,
    WriteOffRequestViewSet,
)
from .movements import StockMovementReportView  # noqa: F401
from .planning import (  # noqa: F401
    DemandForecastViewSet,
    InventorySettingsView,
    SOPView,
    StockPolicySerializer,
    StockPolicyViewSet,
    StorageZoneViewSet,
)
from .quality import (  # noqa: F401
    BatchCertificationView,
    ComplianceExportView,
    QualityDashboardView,
    SupplierCertificateSerializer,
    SupplierCertificateViewSet,
    TemperatureExcursionSerializer,
    TemperatureExcursionViewSet,
)
from .rbac_views import (  # noqa: F401
    RBACBuiltinRoleOverrideView,
    RBACMatrixView,
    RBACSetUserRoleView,
    RoleDefinitionSerializer,
    RoleDefinitionViewSet,
)
from .recall import (  # noqa: F401
    RecallCaseSerializer,
    RecallCaseViewSet,
    RecallLineSerializer,
    RecallSummaryView,
)
from .replenishment import (  # noqa: F401
    AutoDraftSettingsView,
    DaysOfCoverView,
    DraftPurchaseOrdersView,
    LinkSupplierView,
    ReplenishmentView,
    ReviewedPurchaseOrdersView,
    RFQFromPlanView,
    SupplierPickerView,
)
from .traceability import (  # noqa: F401
    BatchTraceExportView,
    BatchTracePdfView,
    BatchTraceSearchView,
    BatchTraceView,
    StockTraceExportView,
    StockTracePdfView,
    StockTraceView,
    TraceBranchesView,
    TraceSearchView,
)
from .stocks import (  # noqa: F401
    MedicationStockViewSet,
    StockAdjustmentViewSet,
    StockBatchViewSet,
)
from .transfers import StockTransferFilterSet, StockTransferViewSet  # noqa: F401

__all__ = [
    'CategoryViewSet', 'UnitViewSet', 'ClassificationViewSet',
    'MedicationStockViewSet', 'StockBatchViewSet', 'StockAdjustmentViewSet',
    'InventoryAnalyticsView', 'InventoryOverviewView',
    'InventoryCountViewSet',
    'StockTakeBoardView',
    'StockTakeRegisterPdfView',
    'StockTransferFilterSet', 'StockTransferViewSet',
    'RBACMatrixView', 'RBACSetUserRoleView', 'RoleDefinitionSerializer',
    'RoleDefinitionViewSet', 'RBACBuiltinRoleOverrideView',
    'ControlledSubstanceLogViewSet', 'StockMovementReportView',
    # Tier 1 — automation / replenishment
    'ReplenishmentView', 'DraftPurchaseOrdersView', 'DaysOfCoverView',
    'AutoDraftSettingsView', 'CycleCountPlanView', 'PlanRefreshView',
    'ReviewedPurchaseOrdersView', 'RFQFromPlanView', 'LinkSupplierView',
    'SupplierPickerView',
    # Tier 2 — planning
    'StockPolicySerializer', 'StockPolicyViewSet', 'DemandForecastViewSet',
    'SOPView', 'InventorySettingsView', 'StorageZoneViewSet',
    # Tier 3 — traceability & compliance
    'RecallCaseSerializer', 'RecallLineSerializer', 'RecallCaseViewSet',
    'RecallSummaryView', 'TemperatureExcursionSerializer',
    'TemperatureExcursionViewSet', 'SupplierCertificateSerializer',
    'SupplierCertificateViewSet', 'QualityDashboardView',
    'BatchCertificationView', 'ComplianceExportView',
    # Tier 4 — warehouse execution
    'WarehouseBinSerializer', 'WarehouseBinViewSet',
    'StockPlacementSerializer', 'StockPlacementViewSet',
    'ScanVerifyView', 'LabelPrintView',
    # Tier 5 — finance
    'InventorySnapshotViewSet', 'LandedCostView',
    'WriteOffRequestSerializer', 'WriteOffRequestViewSet',
    # Tier 6 — suppliers
    'SupplierScorecardView',
    # Tier 7 — insights
    'InsightsView', 'WhatIfView', 'AnomalyViewSet',
]
