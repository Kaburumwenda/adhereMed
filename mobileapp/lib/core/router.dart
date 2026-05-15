import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/shell/shell_screen.dart';
import '../screens/pharmacy/dashboard_screen.dart';
import '../screens/pharmacy/inventory/inventory_screen.dart';
import '../screens/pharmacy/inventory/stock_detail_screen.dart';
import '../screens/pharmacy/inventory/add_stock_screen.dart';
import '../screens/pharmacy/inventory/edit_stock_screen.dart';
import '../screens/pharmacy/inventory/categories_screen.dart';
import '../screens/pharmacy/inventory/adjustments_screen.dart';
import '../screens/pharmacy/inventory/add_adjustment_screen.dart';
import '../screens/pharmacy/inventory/stock_take_screen.dart';
import '../screens/pharmacy/inventory/transfers_screen.dart';
import '../screens/pharmacy/accounts/accounts_screen.dart';
import '../screens/pharmacy/accounts/expenses_screen.dart';
import '../screens/pharmacy/accounts/add_expense_screen.dart';
import '../screens/pharmacy/analytics/analytics_screen.dart';
import '../screens/pharmacy/dispensing/dispensing_screen.dart';
import '../screens/pharmacy/dispensing/dispense_returns_screen.dart';
import '../screens/pharmacy/staff/staff_screen.dart';
import '../screens/pharmacy/staff/staff_performance_screen.dart';
import '../screens/pharmacy/staff/customers_screen.dart';
import '../screens/pharmacy/staff/suppliers_screen.dart';
import '../screens/pharmacy/referral/referral_screen.dart';
import '../screens/pharmacy/referral/referral_performance_screen.dart';
import '../screens/pharmacy/reports/reports_screen.dart';
import '../screens/pharmacy/deliveries/deliveries_screen.dart';
import '../screens/pharmacy/settings/settings_screen.dart';
import '../screens/pharmacy/billing/billing_screen.dart';
import '../screens/pharmacy/alerts/alerts_screen.dart';
import '../screens/pharmacy/prescriptions/prescriptions_screen.dart';
import '../screens/pharmacy/insurance/insurance_screen.dart';
import '../screens/pharmacy/branches/branches_screen.dart';
import '../screens/pharmacy/catalog/medication_catalog_screen.dart';
import '../screens/pharmacy/purchase_orders/purchase_orders_screen.dart';
import '../screens/pharmacy/purchase_orders/new_purchase_order_screen.dart';
import '../screens/pharmacy/purchase_orders/purchase_order_detail_screen.dart';
import '../screens/pharmacy/sales/sales_history_screen.dart';
import '../screens/pharmacy/pos/pos_screen.dart';
import '../screens/pharmacy/pos/smart_pos_screen.dart';
import '../screens/pharmacy/pos/pos_selector_screen.dart';
import '../screens/pharmacy/credit/credit_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Use a ValueNotifier so GoRouter re-evaluates redirect without being recreated
  final authNotifier = ValueNotifier<AuthState>(ref.read(authProvider));
  ref.listen(authProvider, (_, next) {
    authNotifier.value = next;
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = authNotifier.value;
      if (!auth.initialized) return null;
      final loggedIn = auth.isLoggedIn;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/welcome';
      if (!loggedIn && !isAuthRoute) return '/welcome';
      if (loggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          // Inventory
          GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
          GoRoute(path: '/inventory/add', builder: (_, __) => const AddStockScreen()),
          GoRoute(path: '/inventory/:id', builder: (_, s) => StockDetailScreen(id: int.parse(s.pathParameters['id']!))),
          GoRoute(path: '/inventory/:id/edit', builder: (_, s) => EditStockScreen(id: int.parse(s.pathParameters['id']!))),
          GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
          GoRoute(path: '/adjustments', builder: (_, __) => const AdjustmentsScreen()),
          GoRoute(path: '/inventory/adjustments/add', builder: (_, __) => const AddAdjustmentScreen()),
          GoRoute(path: '/stock-take', builder: (_, __) => const StockTakeScreen()),
          GoRoute(path: '/transfers', builder: (_, __) => const TransfersScreen()),
          // Accounts & Finance
          GoRoute(path: '/accounts', builder: (_, __) => const AccountsScreen()),
          GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
          GoRoute(path: '/expenses/add', builder: (_, __) => const AddExpenseScreen()),
          // Analytics & Reports
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          // Dispensing
          GoRoute(path: '/dispensing', builder: (_, __) => const DispensingScreen()),
          GoRoute(path: '/dispensing/returns', builder: (_, __) => const DispenseReturnsScreen()),
          // Credits
          GoRoute(path: '/credits', builder: (_, __) => const CreditScreen()),
          // Staff & Customers
          GoRoute(path: '/staff', builder: (_, __) => const StaffScreen()),
          GoRoute(path: '/staff/performance', builder: (_, __) => const StaffPerformanceScreen()),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersScreen()),
          // Referral
          GoRoute(path: '/referral', builder: (_, __) => const ReferralScreen()),
          GoRoute(path: '/referral/performance', builder: (_, __) => const ReferralPerformanceScreen()),
          // Other
          GoRoute(path: '/deliveries', builder: (_, __) => const DeliveriesScreen()),
          GoRoute(path: '/prescriptions', builder: (_, __) => const PrescriptionsScreen()),
          GoRoute(path: '/insurance', builder: (_, __) => const InsuranceScreen()),
          GoRoute(path: '/billing', builder: (_, __) => const BillingScreen()),
          GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
          GoRoute(path: '/branches', builder: (_, __) => const BranchesScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/catalog', builder: (_, __) => const MedicationCatalogScreen()),
          // Purchase Orders
          GoRoute(path: '/purchase-orders', builder: (_, __) => const PurchaseOrdersScreen()),
          GoRoute(path: '/purchase-orders/new', builder: (_, __) => const NewPurchaseOrderScreen()),
          GoRoute(path: '/purchase-orders/:id', builder: (_, s) => PurchaseOrderDetailScreen(id: int.parse(s.pathParameters['id']!))),
          GoRoute(path: '/sales', builder: (_, __) => const SalesHistoryScreen()),
          GoRoute(path: '/pos', builder: (_, __) => const POSSelectorScreen()),
          GoRoute(path: '/pos/pharmacy', builder: (_, __) => const POSScreen()),
          GoRoute(path: '/pos/smart', builder: (_, __) => const SmartPOSScreen()),
        ],
      ),
    ],
  );
});
