from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views
from . import catalog_seed_views
from .reports import views as report_views
from .reports import bi_views

router = DefaultRouter()
router.register('categories', views.CategoryViewSet, basename='category')
router.register('units', views.UnitViewSet, basename='unit')
router.register('classifications', views.ClassificationViewSet, basename='classification')
router.register('stocks', views.MedicationStockViewSet, basename='medicationstock')
router.register('batches', views.StockBatchViewSet, basename='stockbatch')
router.register('adjustments', views.StockAdjustmentViewSet, basename='stockadjustment')
router.register('counts', views.InventoryCountViewSet, basename='inventorycount')
router.register('transfers', views.StockTransferViewSet, basename='stocktransfer')
router.register('controlled-register', views.ControlledSubstanceLogViewSet, basename='controlled-register')
router.register('rbac/roles', views.RoleDefinitionViewSet, basename='rbac-role')
# ── Tier 2: planning ────────────────────────────────────────────────────
router.register('policies', views.StockPolicyViewSet, basename='stock-policy')
router.register('forecasts', views.DemandForecastViewSet, basename='demand-forecast')
router.register('zones', views.StorageZoneViewSet, basename='storage-zone')
# ── Tier 3: traceability & quality ──────────────────────────────────────
router.register('recalls', views.RecallCaseViewSet, basename='recall-case')
router.register('recall-summary', views.RecallSummaryView, basename='recall-summary')
router.register('excursions', views.TemperatureExcursionViewSet, basename='temperature-excursion')
router.register('certificates', views.SupplierCertificateViewSet, basename='supplier-certificate')
# ── Tier 4: warehouse execution ─────────────────────────────────────────
router.register('bins', views.WarehouseBinViewSet, basename='warehouse-bin')
router.register('placements', views.StockPlacementViewSet, basename='stock-placement')
# ── Tier 5 & 7: finance & insights ──────────────────────────────────────
router.register('snapshots', views.InventorySnapshotViewSet, basename='inventory-snapshot')
router.register('writeoffs', views.WriteOffRequestViewSet, basename='writeoff-request')
router.register('anomalies', views.AnomalyViewSet, basename='stock-anomaly')

urlpatterns = [
    path('analytics/', views.InventoryAnalyticsView.as_view(), name='inventory-analytics'),
    path('overview/', views.InventoryOverviewView.as_view(), name='inventory-overview'),
    path('stock-movements/', views.StockMovementReportView.as_view(), name='inventory-stock-movements'),
    path('rbac/', views.RBACMatrixView.as_view(), name='inventory-rbac'),
    path('rbac/users/<int:user_id>/role/', views.RBACSetUserRoleView.as_view(), name='inventory-rbac-set-role'),
    path('rbac/builtin-roles/<str:key>/', views.RBACBuiltinRoleOverrideView.as_view(), name='inventory-rbac-builtin-override'),

    # ── Tier 1: replenishment automation ────────────────────────────────
    path('replenishment/', views.ReplenishmentView.as_view(), name='inventory-replenishment'),
    path('replenishment/draft-pos/', views.DraftPurchaseOrdersView.as_view(), name='inventory-draft-pos'),
    path('replenishment/reviewed-pos/', views.ReviewedPurchaseOrdersView.as_view(),
         name='inventory-reviewed-pos'),
    path('replenishment/rfq/', views.RFQFromPlanView.as_view(), name='inventory-rfq-from-plan'),
    path('replenishment/link-supplier/', views.LinkSupplierView.as_view(),
         name='inventory-link-supplier'),
    path('replenishment/supplier-offers/', views.SupplierPickerView.as_view(),
         name='inventory-supplier-offers'),
    path('replenishment/auto-draft/', views.AutoDraftSettingsView.as_view(), name='inventory-auto-draft'),
    path('days-of-cover/', views.DaysOfCoverView.as_view(), name='inventory-days-of-cover'),
    path('cycle-count-plan/', views.CycleCountPlanView.as_view(), name='inventory-cycle-count-plan'),
    path('stock-take/', views.StockTakeBoardView.as_view(), name='inventory-stock-take-board'),
    path('stock-take/pdf/', views.StockTakeRegisterPdfView.as_view(),
         name='inventory-stock-take-pdf'),
    path('planning/refresh/', views.PlanRefreshView.as_view(), name='inventory-plan-refresh'),

    # ── Tier 2: S&OP + tenant policy ────────────────────────────────────
    path('sop/', views.SOPView.as_view(), name='inventory-sop'),
    path('settings/', views.InventorySettingsView.as_view(), name='inventory-settings'),

    # ── Tier 3: quality & compliance ────────────────────────────────────
    path('quality/', views.QualityDashboardView.as_view(), name='inventory-quality'),
    path('quality/batches/<int:batch_id>/certification/', views.BatchCertificationView.as_view(),
         name='inventory-batch-certification'),
    path('compliance/export/', views.ComplianceExportView.as_view(), name='inventory-compliance-export'),

    # ── Tier 4: scanning & labels ───────────────────────────────────────
    path('scan/', views.ScanVerifyView.as_view(), name='inventory-scan'),
    path('labels/', views.LabelPrintView.as_view(), name='inventory-labels'),

    # ── Item traceability: warehouse entry → customer ───────────────────
    path('trace/', views.TraceSearchView.as_view(), name='inventory-trace-search'),
    path('trace/branches/', views.TraceBranchesView.as_view(),
         name='inventory-trace-branches'),
    path('trace/items/<int:pk>/', views.StockTraceView.as_view(),
         name='inventory-trace-item'),
    path('trace/items/<int:pk>/export/', views.StockTraceExportView.as_view(),
         name='inventory-trace-item-export'),
    path('trace/items/<int:pk>/pdf/', views.StockTracePdfView.as_view(),
         name='inventory-trace-item-pdf'),

    # ── Batch (lot) traceability: one lot number → everyone who received it ──
    path('trace/batches/', views.BatchTraceSearchView.as_view(),
         name='inventory-batch-trace-search'),
    path('trace/batch/', views.BatchTraceView.as_view(),
         name='inventory-batch-trace'),
    path('trace/batch/export/', views.BatchTraceExportView.as_view(),
         name='inventory-batch-trace-export'),
    path('trace/batch/pdf/', views.BatchTracePdfView.as_view(),
         name='inventory-batch-trace-pdf'),

    # ── Tier 5 & 6: finance & suppliers ─────────────────────────────────
    path('landed-cost/', views.LandedCostView.as_view(), name='inventory-landed-cost'),
    path('supplier-scorecards/', views.SupplierScorecardView.as_view(),
         name='inventory-supplier-scorecards'),

    # ── Tier 7: executive insights ──────────────────────────────────────
    path('insights/', views.InsightsView.as_view(), name='inventory-insights'),
    path('insights/what-if/', views.WhatIfView.as_view(), name='inventory-what-if'),

    # ── Reporting platform ──────────────────────────────────────────────
    path('reports/catalog/', report_views.ReportCatalogView.as_view(),
         name='inventory-report-catalog'),
    path('reports/preview/', report_views.ReportPreviewView.as_view(),
         name='inventory-report-preview'),
    path('reports/generate/', report_views.ReportGenerateView.as_view(),
         name='inventory-report-generate'),

    # ── Business-Intelligence report pack (premium, section-selectable) ──
    path('reports/bi/catalog/', bi_views.BiReportCatalogView.as_view(),
         name='inventory-bi-report-catalog'),
    path('reports/bi/preview/', bi_views.BiReportPreviewView.as_view(),
         name='inventory-bi-report-preview'),
    path('reports/bi/generate/', bi_views.BiReportGenerateView.as_view(),
         name='inventory-bi-report-generate'),

    # Clinic catalog seed (categories & units) — shared models, clinic schema
    path('catalog/seed/', catalog_seed_views.clinic_seed_catalog, name='clinic-catalog-seed'),
    path('catalog/seed/run/', catalog_seed_views.clinic_run_seed, name='clinic-catalog-seed-run'),
    path('catalog/seed/history/', catalog_seed_views.clinic_seed_history, name='clinic-catalog-seed-history'),
    path('', include(router.urls)),
]
