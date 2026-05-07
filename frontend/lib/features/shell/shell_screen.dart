import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../auth/providers/auth_provider.dart';
import '../exchange/repository/exchange_repository.dart';
import '../pharmacy/models/branch_model.dart';
import '../pharmacy/providers/branch_provider.dart';
import '../pharmacy_store/repository/pharmacy_store_repository.dart';

/// Pending prescription exchange count for patients – auto-refreshes every 30s.
final _pendingPrescriptionCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final repo = ExchangeRepository();
  while (true) {
    try {
      final pending = await repo.getExchanges(status: 'pending');
      final quoted = await repo.getExchanges(status: 'quoted');
      yield pending.count + quoted.count;
    } catch (_) {
      yield 0;
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

/// Pending pharmacy order count – auto-refreshes every 30s.
final _pendingOrderCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final repo = PharmacyStoreRepository();
  while (true) {
    try {
      final result = await repo.getPharmacyOrders(status: 'pending');
      yield result.count;
    } catch (_) {
      yield 0;
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

/// User-controlled sidebar collapse. `null` means "follow screen width".
final sidebarCollapsedProvider = StateProvider<bool?>((ref) => null);

class _NavSection {
  final String label;
  final List<_NavItemData> items;
  const _NavSection({required this.label, required this.items});
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? path;
  final List<_NavItemData> children;
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.path,
    this.children = const [],
  });
  bool get hasChildren => children.isNotEmpty;
}

List<_NavSection> _getNavSections(String role, String? tenantType) {
  final sections = <_NavSection>[];

  final isSuperAdmin = role == 'super_admin';

  // Super Admin gets its own section first
  if (isSuperAdmin) {
    sections.add(const _NavSection(label: 'SUPER ADMIN', items: [
      _NavItemData(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'Overview', path: '/superadmin'),
      _NavItemData(icon: Icons.business_outlined, activeIcon: Icons.business, label: 'Tenants', path: '/superadmin/tenants'),
      _NavItemData(icon: Icons.people_outline, activeIcon: Icons.people, label: 'All Users', path: '/superadmin/users'),
      _NavItemData(icon: Icons.storage_outlined, activeIcon: Icons.storage, label: 'Seed Data', path: '/superadmin/seed'),
      _NavItemData(icon: Icons.health_and_safety_outlined, activeIcon: Icons.health_and_safety, label: 'Clinical Catalog', path: '/superadmin/clinical-catalog'),
      _NavItemData(icon: Icons.library_books_outlined, activeIcon: Icons.library_books, label: 'Catalog Manager', path: '/admin/catalog'),
      _NavItemData(icon: Icons.add_business_outlined, activeIcon: Icons.add_business, label: 'New Tenant', path: '/superadmin/tenants/new'),
    ]));
    return sections; // Super admin only sees the super admin section
  }

  // Everyone else gets dashboard
  sections.add(const _NavSection(label: '', items: [
    _NavItemData(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', path: '/dashboard'),
  ]));

  // Hospital section: show if tenant is hospital
  final isHospitalTenant = tenantType == 'hospital';
  if (isHospitalTenant) {
    if (['tenant_admin', 'hospital_admin', 'doctor', 'clinical_officer', 'dentist', 'nurse', 'midwife', 'receptionist', 'lab_tech', 'radiologist', 'pharmacist', 'cashier', 'admin'].contains(role)) {
      sections.add(const _NavSection(label: 'HOSPITAL', items: [
        _NavItemData(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Patients', path: '/patients'),
        _NavItemData(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Appointments', path: '/appointments'),
        _NavItemData(icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services, label: 'Consultations', path: '/consultations'),
        _NavItemData(icon: Icons.medication_outlined, activeIcon: Icons.medication, label: 'Prescriptions', path: '/prescriptions', children: [
          _NavItemData(icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt, label: 'View Prescriptions', path: '/prescriptions'),
          _NavItemData(icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note, label: 'Write Prescription', path: '/prescriptions/new'),
        ]),
        _NavItemData(icon: Icons.biotech_outlined, activeIcon: Icons.biotech, label: 'Lab Orders', path: '/lab-orders'),
        _NavItemData(icon: Icons.image_outlined, activeIcon: Icons.image, label: 'Radiology', path: '/radiology'),
        _NavItemData(icon: Icons.monitor_heart_outlined, activeIcon: Icons.monitor_heart, label: 'Triage', path: '/triage'),
        _NavItemData(icon: Icons.local_hotel_outlined, activeIcon: Icons.local_hotel, label: 'Wards', path: '/wards'),
        _NavItemData(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Billing', path: '/billing'),
        _NavItemData(icon: Icons.business_outlined, activeIcon: Icons.business, label: 'Departments', path: '/departments'),
      ]));  
    }
  }

  // Pharmacy section: show if tenant is pharmacy
  final isPharmacyTenant = tenantType == 'pharmacy';
  if (isPharmacyTenant) {
    if (['tenant_admin', 'pharmacy_admin', 'pharmacist', 'pharmacy_tech', 'cashier', 'admin'].contains(role)) {
      sections.add(const _NavSection(label: 'PHARMACY', items: [
        _NavItemData(icon: Icons.point_of_sale_outlined, activeIcon: Icons.point_of_sale, label: 'POS', path: '/pos'),
        _NavItemData(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Patient Orders', path: '/pharmacy-orders'),
        _NavItemData(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Inventory', path: '/inventory', children: [
          _NavItemData(icon: Icons.medication_outlined, activeIcon: Icons.medication, label: 'Stock Items', path: '/inventory'),
          _NavItemData(icon: Icons.category_outlined, activeIcon: Icons.category, label: 'Categories', path: '/categories'),
          _NavItemData(icon: Icons.straighten_outlined, activeIcon: Icons.straighten, label: 'Units', path: '/units'),
          _NavItemData(icon: Icons.tune_outlined, activeIcon: Icons.tune, label: 'Adjustments', path: '/adjustments'),
          _NavItemData(icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: 'Stock Analysis', path: '/inventory/stock-analysis'),
        ]),
        _NavItemData(icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: 'Analytics', path: '/analytics', children: [
          _NavItemData(icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: 'Overview', path: '/analytics'),
          _NavItemData(icon: Icons.category_outlined, activeIcon: Icons.category, label: 'Category Sales', path: '/analytics/categories'),
          _NavItemData(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: 'Top Products', path: '/analytics/top-products'),
        ]),
        _NavItemData(icon: Icons.assessment_outlined, activeIcon: Icons.assessment, label: 'Reports', path: '/reports'),
        _NavItemData(icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping, label: 'Deliveries', path: '/deliveries'),
        _NavItemData(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Purchase Orders', path: '/purchase-orders'),
        _NavItemData(icon: Icons.assignment_turned_in_outlined, activeIcon: Icons.assignment_turned_in, label: 'Dispensing', path: '/dispensing'),
        _NavItemData(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Sales History', path: '/pos/history'),
        _NavItemData(icon: Icons.medication_liquid_outlined, activeIcon: Icons.medication_liquid, label: 'Prescriptions', path: '/pharmacy-rx'),
        _NavItemData(icon: Icons.notification_important_outlined, activeIcon: Icons.notification_important, label: 'Alerts', path: '/alerts', children: [
          _NavItemData(icon: Icons.warning_amber_outlined, activeIcon: Icons.warning_amber, label: 'Pharmacy Alerts', path: '/alerts'),
        ]),
        _NavItemData(icon: Icons.medication_outlined, activeIcon: Icons.medication, label: 'Medication Catalog', path: '/medications'),
        _NavItemData(icon: Icons.manage_accounts_outlined, activeIcon: Icons.manage_accounts, label: 'IAM', path: '/staff', children: [
          _NavItemData(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Customers', path: '/customers'),
          _NavItemData(icon: Icons.badge_outlined, activeIcon: Icons.badge, label: 'Staff', path: '/staff', children: [
            _NavItemData(icon: Icons.people_outline, activeIcon: Icons.people, label: 'All Staff', path: '/staff'),
            _NavItemData(icon: Icons.school_outlined, activeIcon: Icons.school, label: 'Specializations', path: '/specializations'),
            _NavItemData(icon: Icons.leaderboard_outlined, activeIcon: Icons.leaderboard, label: 'Performance', path: '/staff-performance'),
          ]),
          _NavItemData(icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping, label: 'Suppliers', path: '/suppliers'),
        ]),
        _NavItemData(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings', path: '/settings'),
        _NavItemData(icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance, label: 'Branches', path: '/branches'),
      ]));
    }
  }

  // Lab section: show if tenant is lab
  final isLabTenant = tenantType == 'lab';
  if (isLabTenant) {
    if (['tenant_admin', 'lab_admin', 'lab_tech', 'admin'].contains(role)) {
      sections.add(const _NavSection(label: 'LABORATORY', items: [
        _NavItemData(icon: Icons.pending_actions_outlined, activeIcon: Icons.pending_actions, label: 'Lab Requests', path: '/lab-exchange'),
      ]));    
    }
  }

  // Patient role
  if (['patient', 'admin'].contains(role)) {
    sections.add(const _NavSection(label: 'MY HEALTH', items: [
      _NavItemData(icon: Icons.account_circle_outlined, activeIcon: Icons.account_circle, label: 'My Profile', path: '/my-profile'),
      _NavItemData(icon: Icons.receipt_outlined, activeIcon: Icons.receipt, label: 'My Prescriptions', path: '/my-prescriptions'),
      _NavItemData(icon: Icons.local_pharmacy_outlined, activeIcon: Icons.local_pharmacy, label: 'Pharmacies', path: '/pharmacy-store', children: [
        _NavItemData(icon: Icons.store_outlined, activeIcon: Icons.store, label: 'Browse Pharmacies', path: '/pharmacy-store'),
        _NavItemData(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'My Orders', path: '/pharmacy-store/orders'),
      ]),
      _NavItemData(icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Find Doctors', path: '/doctors'),
      _NavItemData(icon: Icons.chat_outlined, activeIcon: Icons.chat, label: 'Messages', path: '/messages'),
    ]));
  }

  // Doctor role
  if (['doctor', 'clinical_officer', 'dentist'].contains(role)) {
    sections.add(const _NavSection(label: 'MY PRACTICE', items: [
      _NavItemData(icon: Icons.account_circle_outlined, activeIcon: Icons.account_circle, label: 'My Profile', path: '/doctor-profile'),
      _NavItemData(icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Doctor Directory', path: '/doctors'),
      _NavItemData(icon: Icons.medication_outlined, activeIcon: Icons.medication, label: 'Prescriptions', path: '/prescriptions', children: [
        _NavItemData(icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt, label: 'View Prescriptions', path: '/prescriptions'),
        _NavItemData(icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note, label: 'Write Prescription', path: '/prescriptions/new'),
      ]),
      _NavItemData(icon: Icons.chat_outlined, activeIcon: Icons.chat, label: 'Messages', path: '/messages'),
    ]));
  }

  return sections;
}

class ShellScreen extends ConsumerWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final manualCollapse = ref.watch(sidebarCollapsedProvider);
    final isCollapsed = manualCollapse ?? (screenWidth < 1100);

    return Scaffold(
      drawer: isMobile
          ? _SideNav(
              currentPath: GoRouterState.of(context).matchedLocation,
              userName: '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
              userRole: user?.role ?? '',
              tenantType: user?.tenantType,
              isCollapsed: false,
              onToggleCollapse: null,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            _SideNav(
              currentPath: GoRouterState.of(context).matchedLocation,
              userName: '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
              userRole: user?.role ?? '',
              tenantType: user?.tenantType,
              isCollapsed: isCollapsed,
              onToggleCollapse: () {
                ref.read(sidebarCollapsedProvider.notifier).state =
                    !isCollapsed;
              },
            ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  userName: user?.firstName ?? 'User',
                  userRole: user?.role ?? '',
                  showMenuButton: isMobile,
                  tenantType: user?.tenantType,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNav extends ConsumerWidget {
  final String currentPath;
  final String userName;
  final String userRole;
  final String? tenantType;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const _SideNav({
    required this.currentPath,
    required this.userName,
    required this.userRole,
    required this.tenantType,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navWidth = isCollapsed ? 72.0 : 260.0;
    final sections = _getNavSections(userRole, tenantType);

    return Container(
      width: navWidth,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 68,
            padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 10 : 16),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 20),
                ),
                if (!isCollapsed) ...[  
                  const SizedBox(width: 12),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Adhere',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Color(0xFF0F766E),
                            letterSpacing: -0.4,
                          ),
                        ),
                        TextSpan(
                          text: 'Med',
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 17,
                            color: Color(0xFF0F766E),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Nav Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final section in sections) ...[
                    if (section.label.isNotEmpty && !isCollapsed) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              section.label,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (section.label.isNotEmpty && isCollapsed)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Divider(height: 1),
                      ),
                    for (final item in section.items)
                      if (item.hasChildren)
                        _NavGroup(
                          icon: item.icon,
                          activeIcon: item.activeIcon,
                          label: item.label,
                          children: item.children,
                          currentPath: currentPath,
                          isCollapsed: isCollapsed,
                        )
                      else
                        Builder(builder: (context) {
                          int badge = 0;
                          if (item.path == '/pharmacy-orders') {
                            badge = ref.watch(_pendingOrderCountProvider).valueOrNull ?? 0;
                          } else if (item.path == '/my-prescriptions') {
                            badge = ref.watch(_pendingPrescriptionCountProvider).valueOrNull ?? 0;
                          }
                          return _NavItem(
                            icon: item.icon,
                            activeIcon: item.activeIcon,
                            label: item.label,
                            path: item.path!,
                            currentPath: currentPath,
                            isCollapsed: isCollapsed,
                            badgeCount: badge,
                          );
                        }),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Theme switcher + collapse toggle row
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 12, vertical: 4),
            child: isCollapsed
                ? Column(
                    children: [
                      _ThemeToggleButton(isCollapsed: true),
                      if (onToggleCollapse != null)
                        _CollapseButton(
                            isCollapsed: true,
                            onTap: onToggleCollapse!),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                          child:
                              _ThemeToggleButton(isCollapsed: false)),
                      if (onToggleCollapse != null) ...[
                        const SizedBox(width: 4),
                        _CollapseButton(
                            isCollapsed: false,
                            onTap: onToggleCollapse!),
                      ],
                    ],
                  ),
          ),
          // User section
          Container(
            margin: const EdgeInsets.all(12),
            padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12)),
            ),
            child: isCollapsed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _handleLogout(context, ref),
                        child: Tooltip(
                          message: 'Logout',
                          child: Icon(Icons.logout_rounded,
                              size: 18, color: AppColors.error),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F766E)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                userRole
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.logout_rounded,
                            size: 18, color: AppColors.error),
                        onPressed: () => _handleLogout(context, ref),
                        tooltip: 'Logout',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    ref.read(authProvider.notifier).logout();
    context.go('/login');
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final String currentPath;
  final bool isCollapsed;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.isCollapsed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentPath == path;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              context.go(path);
              if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                Navigator.of(context).pop();
              }
            },
            child: SizedBox(
              height: 44,
              child: Center(
                child: Tooltip(
                  message: label,
                  child: Badge(
                    label: Text('$badgeCount'),
                    isLabelVisible: badgeCount > 0,
                    child: Icon(
                      isActive ? activeIcon : icon,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Material(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  context.go(path);
                  if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                    Navigator.of(context).pop();
                  }
                },
                child: SizedBox(
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isActive ? activeIcon : icon,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        if (badgeCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavGroup extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final List<_NavItemData> children;
  final String currentPath;
  final bool isCollapsed;

  const _NavGroup({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.children,
    required this.currentPath,
    required this.isCollapsed,
  });

  @override
  State<_NavGroup> createState() => _NavGroupState();
}

class _NavGroupState extends State<_NavGroup> {
  late bool _expanded;

  bool get _isChildActive => _anyActive(widget.children, widget.currentPath);

  static bool _anyActive(List<_NavItemData> items, String path) {
    for (final c in items) {
      if (c.path == path) return true;
      if (c.hasChildren && _anyActive(c.children, path)) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _expanded = _isChildActive;
  }

  @override
  void didUpdateWidget(_NavGroup old) {
    super.didUpdateWidget(old);
    if (_isChildActive && !_expanded) _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isChildActive;

    if (widget.isCollapsed) {
      // In collapsed mode show a popup menu
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: PopupMenuButton<String>(
          tooltip: widget.label,
          offset: const Offset(56, 0),
          onSelected: (path) {
            context.go(path);
            if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
              Navigator.of(context).pop();
            }
          },
          itemBuilder: (_) {
            // Flatten children + grandchildren for the collapsed popup
            final flat = <_NavItemData>[];
            for (final c in widget.children) {
              if (c.hasChildren) {
                flat.addAll(c.children);
              } else {
                flat.add(c);
              }
            }
            return flat
              .map((c) => PopupMenuItem(
                    value: c.path,
                    child: Row(
                      children: [
                        Icon(widget.currentPath == c.path ? c.activeIcon : c.icon,
                            size: 18,
                            color: widget.currentPath == c.path
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(c.label),
                      ],
                    ),
                  ))
              .toList();
          },
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isActive ? widget.activeIcon : widget.icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Material(
                  color: isActive && !_expanded
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: SizedBox(
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                isActive ? widget.activeIcon : widget.icon,
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.label,
                                style: TextStyle(
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                children: widget.children.map((c) {
                  if (c.hasChildren) {
                    return _NavGroup(
                      icon: c.icon,
                      activeIcon: c.activeIcon,
                      label: c.label,
                      children: c.children,
                      currentPath: widget.currentPath,
                      isCollapsed: false,
                    );
                  }
                  return _NavItem(
                    icon: c.icon,
                    activeIcon: c.activeIcon,
                    label: c.label,
                    path: c.path!,
                    currentPath: widget.currentPath,
                    isCollapsed: false,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final String userName;
  final String userRole;
  final bool showMenuButton;
  final String? tenantType;

  const _TopBar({
    required this.userName,
    required this.userRole,
    required this.showMenuButton,
    this.tenantType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPharmacy = tenantType == 'pharmacy';
    final branchesAsync = isPharmacy ? ref.watch(branchesProvider) : null;
    final activeBranch = isPharmacy ? ref.watch(activeBranchProvider) : null;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const SizedBox(width: 8),
          Text(
            'Welcome back, $userName',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (isPharmacy && branchesAsync != null)
            branchesAsync.when(
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (branches) {
                if (branches.length <= 1) return const SizedBox.shrink();
                // Seed active branch on first load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (activeBranch == null && branches.isNotEmpty) {
                    ref.read(activeBranchProvider.notifier).select(
                          branches.firstWhere((b) => b.isMain,
                              orElse: () => branches.first),
                        );
                  }
                });
                return _BranchDropdown(
                  branches: branches,
                  activeBranch: activeBranch,
                  onChanged: (b) => ref.read(activeBranchProvider.notifier).select(b),
                );
              },
            ),
          if (isPharmacy && branchesAsync != null) const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  final List<Branch> branches;
  final Branch? activeBranch;
  final ValueChanged<Branch> onChanged;

  const _BranchDropdown({
    required this.branches,
    required this.activeBranch,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.background,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Branch>(
          value: activeBranch,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          hint: const Text('Select Branch'),
          items: branches
              .map(
                (b) => DropdownMenuItem(
                  value: b,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        b.isMain ? Icons.store : Icons.storefront_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(b.name),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (b) {
            if (b != null) onChanged(b);
          },
        ),
      ),
    );
  }
}

// ─── Sidebar helper widgets ───

class _CollapseButton extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onTap;
  const _CollapseButton({required this.isCollapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 36,
          width: isCollapsed ? double.infinity : 36,
          alignment: Alignment.center,
          child: Icon(
            isCollapsed
                ? Icons.chevron_right_rounded
                : Icons.chevron_left_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  final bool isCollapsed;
  const _ThemeToggleButton({required this.isCollapsed});

  static const _themes = [
    (AppThemeMode.light, Icons.light_mode_rounded, 'Light', Color(0xFF0D9488)),
    (AppThemeMode.dark, Icons.dark_mode_rounded, 'Dark', Color(0xFF2DD4BF)),
    (AppThemeMode.ocean, Icons.water_rounded, 'Ocean', Color(0xFF0284C7)),
    (AppThemeMode.sunset, Icons.wb_twilight_rounded, 'Sunset', Color(0xFFDB2777)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeModeProvider);

    return PopupMenuButton<AppThemeMode>(
      tooltip: 'Change theme',
      offset: isCollapsed ? const Offset(56, 0) : const Offset(0, -180),
      onSelected: (mode) =>
          ref.read(appThemeModeProvider.notifier).setTheme(mode),
      itemBuilder: (_) => _themes
          .map((t) => PopupMenuItem(
                value: t.$1,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: t.$4,
                        shape: BoxShape.circle,
                        border: current == t.$1
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: current == t.$1
                            ? [BoxShadow(color: t.$4.withValues(alpha: 0.5), blurRadius: 6)]
                            : null,
                      ),
                      child: current == t.$1
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Icon(t.$2, size: 18, color: t.$4),
                    const SizedBox(width: 8),
                    Text(t.$3),
                  ],
                ),
              ))
          .toList(),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 10),
          child: isCollapsed
              ? Icon(Icons.palette_outlined, size: 18, color: AppColors.textSecondary)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('Theme',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
        ),
      ),
    );
  }
}
