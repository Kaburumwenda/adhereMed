import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/tenant_register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/shell/shell_screen.dart';

// Dashboards
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/doctor_dashboard_screen.dart';
import '../features/dashboard/screens/hospital_dashboard_screen.dart';
import '../features/dashboard/screens/pharmacy_dashboard_screen.dart';
import '../features/dashboard/screens/lab_dashboard_screen.dart';
import '../features/dashboard/screens/patient_dashboard_screen.dart';
// Hospital screens
import '../features/patients/screens/patient_list_screen.dart';
import '../features/patients/screens/patient_form_screen.dart';
import '../features/patients/screens/patient_detail_screen.dart';
import '../features/patients/screens/patient_profile_screen.dart';
import '../features/appointments/screens/appointment_list_screen.dart';
import '../features/appointments/screens/appointment_form_screen.dart';
import '../features/consultations/screens/consultation_list_screen.dart';
import '../features/consultations/screens/consultation_detail_screen.dart';
import '../features/consultations/screens/consultation_form_screen.dart';
import '../features/departments/screens/department_list_screen.dart';
import '../features/departments/screens/department_form_screen.dart';
import '../features/prescriptions/screens/prescription_list_screen.dart';
import '../features/prescriptions/screens/prescription_detail_screen.dart';
import '../features/prescriptions/screens/prescription_form_screen.dart';
import '../features/prescriptions/screens/pharmacy_prescription_screen.dart';
import '../features/lab/screens/lab_order_list_screen.dart';
import '../features/lab/screens/lab_order_detail_screen.dart';
import '../features/lab/screens/lab_order_form_screen.dart';
import '../features/lab/screens/lab_exchange_list_screen.dart';
import '../features/lab/screens/lab_exchange_detail_screen.dart';
import '../features/triage/screens/triage_list_screen.dart';
import '../features/triage/screens/triage_form_screen.dart';
import '../features/billing/screens/invoice_list_screen.dart';
import '../features/billing/screens/invoice_detail_screen.dart';
import '../features/billing/screens/invoice_form_screen.dart';

// Wards & Radiology
import '../features/wards/screens/ward_list_screen.dart';
import '../features/wards/screens/ward_detail_screen.dart';
import '../features/wards/screens/ward_form_screen.dart';
import '../features/wards/screens/admission_form_screen.dart';
import '../features/radiology/screens/radiology_order_list_screen.dart';
import '../features/radiology/screens/radiology_order_detail_screen.dart';
import '../features/radiology/screens/radiology_order_form_screen.dart';

// Pharmacy screens
import '../features/inventory/screens/inventory_list_screen.dart';
import '../features/inventory/screens/stock_form_screen.dart';
import '../features/inventory/screens/stock_detail_screen.dart';
import '../features/inventory/screens/stock_adjustment_screen.dart';
import '../features/inventory/screens/stock_analysis_screen.dart';
import '../features/inventory/screens/category_list_screen.dart';
import '../features/inventory/screens/unit_list_screen.dart';
import '../features/suppliers/screens/supplier_list_screen.dart';
import '../features/suppliers/screens/supplier_form_screen.dart';
import '../features/purchase_orders/screens/purchase_order_list_screen.dart';
import '../features/purchase_orders/screens/purchase_order_detail_screen.dart';
import '../features/purchase_orders/screens/purchase_order_form_screen.dart';
import '../features/purchase_orders/screens/goods_received_note_screen.dart';
import '../features/pos/screens/pos_screen.dart';
import '../features/pos/screens/pos_history_screen.dart';
import '../features/pos/screens/customer_history_screen.dart';
import '../features/dispensing/screens/dispensing_list_screen.dart';
import '../features/dispensing/screens/dispensing_detail_screen.dart';
import '../features/pharmacy/screens/pharmacy_analytics_screen.dart';
import '../features/pharmacy/screens/category_sales_screen.dart';
import '../features/pharmacy/screens/top_product_sales_screen.dart';
import '../features/pharmacy/screens/pharmacy_reports_screen.dart';
import '../features/pharmacy/screens/branches_screen.dart';
import '../features/pharmacy/screens/customer_list_screen.dart';
import '../features/pharmacy/screens/delivery_list_screen.dart';
import '../features/pharmacy/screens/staff_list_screen.dart';
import '../features/pharmacy/screens/staff_form_screen.dart';
import '../features/pharmacy/screens/specialization_list_screen.dart';
import '../features/pharmacy/screens/pharmacy_settings_screen.dart';
import '../features/pharmacy/screens/staff_performance_screen.dart';
import '../features/inventory/screens/pharmacy_alerts_screen.dart';
import '../features/medications/screens/medication_catalog_screen.dart';
import '../features/admin_catalog/screens/catalog_management_screen.dart';

// Super Admin screens
import '../features/superadmin/screens/superadmin_dashboard_screen.dart';
import '../features/clinical_catalog/screens/clinical_catalog_screen.dart';
import '../features/superadmin/screens/tenant_management_screen.dart';
import '../features/superadmin/screens/tenant_detail_screen.dart';
import '../features/superadmin/screens/tenant_form_screen.dart';
import '../features/superadmin/screens/user_management_screen.dart';
import '../features/superadmin/screens/user_detail_screen.dart';
import '../features/superadmin/screens/seed_data_screen.dart';

// Patient / Exchange screens
import '../features/exchange/screens/exchange_list_screen.dart';
import '../features/exchange/screens/exchange_detail_screen.dart';

// Doctor screens
import '../features/doctors/screens/doctor_register_screen.dart';
import '../features/doctors/screens/doctor_directory_screen.dart';
import '../features/doctors/screens/doctor_detail_screen.dart';
import '../features/doctors/screens/doctor_profile_screen.dart';

// Messaging screens
import '../features/messaging/screens/conversation_list_screen.dart';
import '../features/messaging/screens/chat_screen.dart';
import '../features/messaging/screens/start_chat_screen.dart';

// Pharmacy Store screens (patient portal)
import '../features/pharmacy_store/screens/pharmacy_list_screen.dart';
import '../features/pharmacy_store/screens/pharmacy_products_screen.dart';
import '../features/pharmacy_store/screens/cart_screen.dart';
import '../features/pharmacy_store/screens/order_list_screen.dart';
import '../features/pharmacy_store/screens/order_detail_screen.dart';
import '../features/pharmacy_store/screens/pharmacy_orders_screen.dart';

/// Notifier that fires when auth state changes, used by GoRouter.refreshListenable
/// so the router re-evaluates its redirect without being recreated.
class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final _authChangeNotifier = _AuthChangeNotifier();

final routerProvider = Provider<GoRouter>((ref) {
  // Listen (not watch) to auth changes and just trigger a router refresh
  ref.listen(authProvider, (_, __) {
    _authChangeNotifier.notify();
  });

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: _authChangeNotifier,
    redirect: (context, state) {
      // Read the current auth state at redirect-time
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/register-facility' ||
          state.matchedLocation == '/register-doctor' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password';

      if (!isLoggedIn && !isAuthRoute) return '/welcome';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/register-facility',
        builder: (context, state) => const TenantRegisterScreen(),
      ),
      GoRoute(
        path: '/register-doctor',
        builder: (context, state) => const DoctorRegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final uid = state.uri.queryParameters['uid'] ?? '';
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordScreen(uid: uid, token: token);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          // ─── General ───
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const _SmartDashboard(),
          ),
          GoRoute(
            path: '/hospital-dashboard',
            builder: (context, state) => const HospitalDashboardScreen(),
          ),
          GoRoute(
            path: '/pharmacy-dashboard',
            builder: (context, state) => const PharmacyDashboardScreen(),
          ),
          GoRoute(
            path: '/lab-dashboard',
            builder: (context, state) => const LabDashboardScreen(),
          ),

          // ─── Patients ───
          GoRoute(
            path: '/patients',
            builder: (context, state) => const PatientListScreen(),
          ),
          GoRoute(
            path: '/patients/new',
            builder: (context, state) => const PatientFormScreen(),
          ),
          GoRoute(
            path: '/patients/:id',
            builder: (context, state) => PatientDetailScreen(
              patientId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/patients/:id/edit',
            builder: (context, state) => PatientFormScreen(
              patientId: state.pathParameters['id']!,
            ),
          ),

          // ─── Appointments ───
          GoRoute(
            path: '/appointments',
            builder: (context, state) => const AppointmentListScreen(),
          ),
          GoRoute(
            path: '/appointments/new',
            builder: (context, state) => const AppointmentFormScreen(),
          ),
          GoRoute(
            path: '/appointments/:id/edit',
            builder: (context, state) => AppointmentFormScreen(
              appointmentId: state.pathParameters['id']!,
            ),
          ),

          // ─── Consultations ───
          GoRoute(
            path: '/consultations',
            builder: (context, state) => const ConsultationListScreen(),
          ),
          GoRoute(
            path: '/consultations/new',
            builder: (context, state) => const ConsultationFormScreen(),
          ),
          GoRoute(
            path: '/consultations/:id',
            builder: (context, state) => ConsultationDetailScreen(
              consultationId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/consultations/:id/edit',
            builder: (context, state) => ConsultationFormScreen(
              consultationId: state.pathParameters['id']!,
            ),
          ),

          // ─── Departments ───
          GoRoute(
            path: '/departments',
            builder: (context, state) => const DepartmentListScreen(),
          ),
          GoRoute(
            path: '/departments/new',
            builder: (context, state) => const DepartmentFormScreen(),
          ),
          GoRoute(
            path: '/departments/:id/edit',
            builder: (context, state) => DepartmentFormScreen(
              departmentId: state.pathParameters['id']!,
            ),
          ),

          // ─── Prescriptions ───
          GoRoute(
            path: '/prescriptions',
            builder: (context, state) => const PrescriptionListScreen(),
          ),
          GoRoute(
            path: '/prescriptions/new',
            builder: (context, state) => const PrescriptionFormScreen(),
          ),
          GoRoute(
            path: '/prescriptions/:id',
            builder: (context, state) => PrescriptionDetailScreen(
              prescriptionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/prescriptions/:id/edit',
            builder: (context, state) => PrescriptionFormScreen(
              prescriptionId: state.pathParameters['id']!,
            ),
          ),

          // ─── Pharmacy Prescriptions ───
          GoRoute(
            path: '/pharmacy-rx',
            builder: (context, state) => const PharmacyPrescriptionListScreen(),
          ),
          GoRoute(
            path: '/pharmacy-rx/new',
            builder: (context, state) => const PharmacyPrescriptionFormScreen(),
          ),
          GoRoute(
            path: '/pharmacy-rx/:id',
            builder: (context, state) => PharmacyPrescriptionFormScreen(
              rxId: state.pathParameters['id']!,
            ),
          ),

          // ─── Lab ───
          GoRoute(
            path: '/lab-orders',
            builder: (context, state) => const LabOrderListScreen(),
          ),
          GoRoute(
            path: '/lab-orders/new',
            builder: (context, state) => const LabOrderFormScreen(),
          ),
          GoRoute(
            path: '/lab-orders/:id',
            builder: (context, state) => LabOrderDetailScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/lab-orders/:id/edit',
            builder: (context, state) => LabOrderFormScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),

          // ─── Lab Exchange (independent lab tenants) ───
          GoRoute(
            path: '/lab-exchange',
            builder: (context, state) => const LabExchangeListScreen(),
          ),
          GoRoute(
            path: '/lab-exchange/:id',
            builder: (context, state) => LabExchangeDetailScreen(
              exchangeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/lab-catalog',
            builder: (context, state) => const LabOrderListScreen(),
          ),

          // ─── Triage ───
          GoRoute(
            path: '/triage',
            builder: (context, state) => const TriageListScreen(),
          ),
          GoRoute(
            path: '/triage/new',
            builder: (context, state) => const TriageFormScreen(),
          ),

          // ─── Billing ───
          GoRoute(
            path: '/billing',
            builder: (context, state) => const InvoiceListScreen(),
          ),
          GoRoute(
            path: '/billing/new',
            builder: (context, state) => const InvoiceFormScreen(),
          ),
          GoRoute(
            path: '/billing/:id',
            builder: (context, state) => InvoiceDetailScreen(
              invoiceId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/billing/:id/edit',
            builder: (context, state) => InvoiceFormScreen(
              invoiceId: state.pathParameters['id']!,
            ),
          ),

          // ─── Wards ───
          GoRoute(
            path: '/wards',
            builder: (context, state) => const WardListScreen(),
          ),
          GoRoute(
            path: '/wards/new',
            builder: (context, state) => const WardFormScreen(),
          ),
          GoRoute(
            path: '/wards/:id',
            builder: (context, state) => WardDetailScreen(
              wardId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/wards/:id/edit',
            builder: (context, state) => WardFormScreen(
              wardId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/wards/admissions/new',
            builder: (context, state) => const AdmissionFormScreen(),
          ),
          GoRoute(
            path: '/wards/admissions/:id',
            builder: (context, state) => AdmissionFormScreen(
              admissionId: state.pathParameters['id']!,
            ),
          ),

          // ─── Radiology ───
          GoRoute(
            path: '/radiology',
            builder: (context, state) => const RadiologyOrderListScreen(),
          ),
          GoRoute(
            path: '/radiology/new',
            builder: (context, state) => const RadiologyOrderFormScreen(),
          ),
          GoRoute(
            path: '/radiology/:id',
            builder: (context, state) => RadiologyOrderDetailScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/radiology/:id/edit',
            builder: (context, state) => RadiologyOrderFormScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),

          // ─── Inventory ───
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryListScreen(),
          ),
          GoRoute(
            path: '/inventory/stock-analysis',
            builder: (context, state) => const StockAnalysisScreen(),
          ),
          GoRoute(
            path: '/inventory/new',
            builder: (context, state) => const StockFormScreen(),
          ),
          GoRoute(
            path: '/inventory/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id']!);
              if (id == null) return const StockAnalysisScreen();
              return StockDetailScreen(stockId: id);
            },
          ),
          GoRoute(
            path: '/inventory/:id/edit',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id']!);
              if (id == null) return const InventoryListScreen();
              return StockFormScreen(stockId: id);
            },
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoryListScreen(),
          ),
          GoRoute(
            path: '/units',
            builder: (context, state) => const UnitListScreen(),
          ),

          // ─── Suppliers ───
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => const SupplierListScreen(),
          ),
          GoRoute(
            path: '/suppliers/new',
            builder: (context, state) => const SupplierFormScreen(),
          ),
          GoRoute(
            path: '/suppliers/:id/edit',
            builder: (context, state) => SupplierFormScreen(
              supplierId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // ─── Purchase Orders ───
          GoRoute(
            path: '/purchase-orders',
            builder: (context, state) => const PurchaseOrderListScreen(),
          ),
          GoRoute(
            path: '/purchase-orders/new',
            builder: (context, state) => const PurchaseOrderFormScreen(),
          ),
          GoRoute(
            path: '/purchase-orders/:id',
            builder: (context, state) => PurchaseOrderDetailScreen(
              orderId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/purchase-orders/:id/grn',
            builder: (context, state) => GoodsReceivedNoteScreen(
              orderId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // ─── POS ───
          GoRoute(
            path: '/pos',
            builder: (context, state) => const POSScreen(),
          ),
          GoRoute(
            path: '/pos/history',
            builder: (context, state) => const POSHistoryScreen(),
          ),

          // ─── Dispensing ───
          GoRoute(
            path: '/dispensing',
            builder: (context, state) => const DispensingListScreen(),
          ),
          GoRoute(
            path: '/dispensing/:id',
            builder: (context, state) => DispensingDetailScreen(
              recordId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // ─── Pharmacy Orders (incoming from patients) ───
          GoRoute(
            path: '/pharmacy-orders',
            builder: (context, state) => const PharmacyOrdersScreen(),
          ),

          // ─── Analytics & Reports ───
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const PharmacyAnalyticsScreen(),
          ),
          GoRoute(
            path: '/analytics/categories',
            builder: (context, state) => const CategorySalesScreen(),
          ),
          GoRoute(
            path: '/analytics/top-products',
            builder: (context, state) => const TopProductSalesScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const PharmacyReportsScreen(),
          ),
          GoRoute(
            path: '/branches',
            builder: (context, state) => const BranchesScreen(),
          ),

          // ─── Customers ───
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomerListScreen(),
          ),
          GoRoute(
            path: '/customers/history',
            builder: (context, state) {
              final phone =
                  state.uri.queryParameters['phone'] ?? '';
              final name =
                  state.uri.queryParameters['name'] ?? 'Customer';
              return CustomerHistoryScreen(
                  customerPhone: phone, customerName: name);
            },
          ),

          // ─── Deliveries ───
          GoRoute(
            path: '/deliveries',
            builder: (context, state) => const DeliveryListScreen(),
          ),

          // ─── Stock Adjustments ───
          GoRoute(
            path: '/adjustments',
            builder: (context, state) => const StockAdjustmentScreen(),
          ),

          // ─── Pharmacy Alerts ───
          GoRoute(
            path: '/alerts',
            builder: (context, state) => const PharmacyAlertsScreen(),
          ),

          // ─── Medication Catalog ───
          GoRoute(
            path: '/medications',
            builder: (context, state) => const MedicationCatalogScreen(),
          ),

          // ─── Admin Catalog Management ───
          GoRoute(
            path: '/admin/catalog',
            builder: (context, state) => const CatalogManagementScreen(),
          ),

          // ─── Staff Performance ───
          GoRoute(
            path: '/staff-performance',
            builder: (context, state) => const StaffPerformanceScreen(),
          ),

          // ─── Staff ───
          GoRoute(
            path: '/staff',
            builder: (context, state) => const StaffListScreen(),
          ),
          GoRoute(
            path: '/staff/new',
            builder: (context, state) => const StaffFormScreen(),
          ),
          GoRoute(
            path: '/staff/:id/edit',
            builder: (context, state) => StaffFormScreen(
              staffId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // ─── Specializations ───
          GoRoute(
            path: '/specializations',
            builder: (context, state) => const SpecializationListScreen(),
          ),

          // ─── Settings ───
          GoRoute(
            path: '/settings',
            builder: (context, state) => const PharmacySettingsScreen(),
          ),

          // ─── Patient Portal / Exchange ───
          GoRoute(
            path: '/my-prescriptions',
            builder: (context, state) => const ExchangeListScreen(),
          ),
          GoRoute(
            path: '/my-profile',
            builder: (context, state) => const PatientProfileScreen(),
          ),
          GoRoute(
            path: '/exchange/:id',
            builder: (context, state) => ExchangeDetailScreen(
              exchangeId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // ─── Doctors ───
          GoRoute(
            path: '/doctor-profile',
            builder: (context, state) => const DoctorProfileScreen(),
          ),
          GoRoute(
            path: '/doctors',
            builder: (context, state) => const DoctorDirectoryScreen(),
          ),
          GoRoute(
            path: '/doctors/:id',
            builder: (context, state) => DoctorDetailScreen(
              doctorId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/doctors/:id/chat',
            builder: (context, state) => StartChatScreen(
              doctorId: state.pathParameters['id']!,
            ),
          ),

          // ─── Messaging ───
          GoRoute(
            path: '/messages',
            builder: (context, state) => const ConversationListScreen(),
          ),
          GoRoute(
            path: '/messages/:id',
            builder: (context, state) => ChatScreen(
              conversationId: state.pathParameters['id']!,
            ),
          ),

          // ─── Super Admin ───
          GoRoute(
            path: '/superadmin',
            builder: (context, state) => const SuperAdminDashboardScreen(),
          ),
          GoRoute(
            path: '/superadmin/tenants',
            builder: (context, state) => const TenantManagementScreen(),
          ),
          GoRoute(
            path: '/superadmin/tenants/new',
            builder: (context, state) => const TenantFormScreen(),
          ),
          GoRoute(
            path: '/superadmin/tenants/:id',
            builder: (context, state) => TenantDetailScreen(
              tenantId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/superadmin/users',
            builder: (context, state) {
              final tenantId = state.uri.queryParameters['tenant_id'];
              return UserManagementScreen(initialTenantId: tenantId);
            },
          ),
          GoRoute(
            path: '/superadmin/users/:id',
            builder: (context, state) => UserDetailScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/superadmin/seed',
            builder: (context, state) => const SeedDataScreen(),
          ),
          GoRoute(
            path: '/superadmin/clinical-catalog',
            builder: (context, state) => const ClinicalCatalogScreen(),
          ),

          // ─── Pharmacy Store (Patient Portal) ───
          GoRoute(
            path: '/pharmacy-store',
            builder: (context, state) => const PharmacyListScreen(),
          ),
          GoRoute(
            path: '/pharmacy-store/cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: '/pharmacy-store/orders',
            builder: (context, state) => const OrderListScreen(),
          ),
          GoRoute(
            path: '/pharmacy-store/orders/:id',
            builder: (context, state) => OrderDetailScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/pharmacy-store/:id',
            builder: (context, state) => PharmacyProductsScreen(
              pharmacyId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
});

class _SmartDashboard extends ConsumerWidget {
  const _SmartDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final role = user?.role;
    final tenantType = user?.tenantType;

    if (role == 'super_admin') {
      return const SuperAdminDashboardScreen();
    }

    // Doctors get their own dashboard regardless of tenant type
    if (role == 'doctor' || role == 'clinical_officer' || role == 'dentist') {
      return const DoctorDashboardScreen();
    }
    // Patients get their own health dashboard
    if (role == 'patient') {
      return const PatientDashboardScreen();
    }
    if (tenantType == 'pharmacy') {
      return const PharmacyDashboardScreen();
    } else if (tenantType == 'lab') {
      return const LabDashboardScreen();
    } else if (tenantType == 'hospital') {
      return const HospitalDashboardScreen();
    }
    return const DashboardScreen();
  }
}
