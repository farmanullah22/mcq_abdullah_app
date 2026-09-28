import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';

import '../core/theme/app_colors.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/audit/presentation/audit_logs_screen.dart';
import '../features/audit/presentation/recent_activity_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/categories/presentation/category_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/expenses/presentation/expense_list_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/managers/presentation/managers_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/products/presentation/product_list_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/sales/presentation/sales_list_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shops/presentation/shops_screen.dart';
import '../features/suppliers/presentation/suppliers_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _routes = ['dashboard', 'sales', 'inventory', 'customers', 'suppliers'];

  int _index = 0;
  final Map<String, Widget> _cache = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _screenFor(String route) => _cache.putIfAbsent(route, () {
        switch (route) {
          case 'dashboard':
            return DashboardScreen(
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            );
          case 'sales':
            return const SalesListScreen();
          case 'inventory':
            return const InventoryScreen();
          case 'customers':
            return const CustomersScreen();
          case 'suppliers':
            return const SuppliersScreen();
        }
        return const SizedBox.shrink();
      });

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final index = _index < _routes.length ? _index : _routes.length - 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Showroom backdrop so the admin dashboard image shows through
        // behind the bottom navigation bar on every tab.
        const _ShellBackdrop(),
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: index,
            children: [for (final route in _routes) _screenFor(route)],
          ),
          drawer: _buildDrawer(context, isAdmin),
          bottomNavigationBar: _PremiumBottomNav(
            currentIndex: index,
            routes: _routes,
            onTap: (i) => setState(() => _index = i),
          ),
        ),
      ],
    );
  }

  Drawer _buildDrawer(BuildContext context, bool isAdmin) {
    final theme = Theme.of(context);
    final user = ref.read(currentUserProvider);
    final scope = isAdmin ? 'Administrator' : (user?.assignedShopName ?? 'Shop Manager');

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 22),
            decoration: const BoxDecoration(
              gradient: AppColors.emeraldGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      child: Text(
                        (user?.name ?? 'M').characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            scope,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _DrawerSection('Navigation'),
          _DrawerItem(icon: Icons.dashboard_outlined, label: 'Dashboard', onTap: () => _go('dashboard')),
          _DrawerItem(icon: Icons.point_of_sale_outlined, label: 'Sales', onTap: () => _go('sales')),
          _DrawerItem(icon: Icons.inventory_2_outlined, label: 'Inventory', onTap: () => _go('inventory')),
          _DrawerItem(icon: Icons.people_outline, label: 'Customers', onTap: () => _go('customers')),
          _DrawerItem(icon: Icons.local_shipping_outlined, label: 'Suppliers', onTap: () => _go('suppliers')),
          const Divider(),
          const _DrawerSection('Modules'),
          _DrawerItem(icon: Icons.shopping_bag_outlined, label: 'Products', onTap: () => _open(const ProductListScreen())),
          _DrawerItem(icon: Icons.receipt_long_outlined, label: 'Expenses', onTap: () => _open(const ExpenseListScreen())),
          _DrawerItem(icon: Icons.category_outlined, label: 'Categories', onTap: () => _open(const CategoryScreen())),
          if (isAdmin) ...[
            const Divider(),
            const _DrawerSection('Administration'),
            _DrawerItem(icon: Icons.bar_chart_outlined, label: 'Reports', onTap: () => _open(const ReportsScreen())),
            _DrawerItem(icon: Icons.storefront_outlined, label: 'Outlets', onTap: () => _open(const ShopsScreen())),
            _DrawerItem(icon: Icons.assessment_outlined, label: 'Analytics', onTap: () => _open(const AnalyticsScreen())),
            _DrawerItem(icon: Icons.manage_accounts_outlined, label: 'Managers', onTap: () => _open(const ManagersScreen())),
            _DrawerItem(icon: Icons.history_outlined, label: 'Audit Logs', onTap: () => _open(const AuditLogsScreen())),
          ],
          const Divider(),
          const _DrawerSection('General'),
          _DrawerItem(icon: Icons.history_outlined, label: 'Recent Activity', onTap: () => _open(const RecentActivityScreen())),
          _DrawerItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () => _open(const NotificationsScreen())),
          _DrawerItem(icon: Icons.person_outline, label: 'Profile', onTap: () => _open(const ProfileScreen())),
          _DrawerItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () => _open(const SettingsScreen())),
          _DrawerItem(
            icon: Icons.logout,
            label: 'Logout',
            color: theme.colorScheme.error,
            onTap: () async {
              final navigator = Navigator.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 32),
                  title: const Text('Sign out?'),
                  content: const Text('You will need to sign in again to access your account.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: Colors.white),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              navigator.pop();
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }

  void _go(String route) {
    Navigator.of(context).pop();
    setState(() => _index = _routes.indexOf(route));
  }

  void _open(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: AppColors.goldDark,
        ),
      ),
    );
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'lib/images/admin_dashboard.jfif',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x50050505),
                Color(0x99050505),
                Color(0xB8050505),
              ],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumBottomNav extends StatelessWidget {
  const _PremiumBottomNav({required this.currentIndex, required this.routes, required this.onTap});

  final int currentIndex;
  final List<String> routes;
  final ValueChanged<int> onTap;

  static (IconData, IconData, String) _meta(String route) => switch (route) {
        'dashboard' => (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
        'sales' => (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'Sales'),
        'inventory' => (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Inventory'),
        'customers' => (Icons.people_outline, Icons.people_rounded, 'Customers'),
        'suppliers' => (Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'Suppliers'),
        _ => (Icons.circle_outlined, Icons.circle, ''),
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.16),
              blurRadius: 22,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x1FFFFFFF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: List.generate(routes.length, (i) {
                  final (icon, selectedIcon, label) = _meta(routes[i]);
                  return Expanded(
                    child: _NavItem(
                      icon: icon,
                      selectedIcon: selectedIcon,
                      label: label,
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idleColor = AppColors.goldLight;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 46 : 40,
              height: selected ? 32 : 28,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.goldGradient : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 19,
                  color: selected ? AppColors.deepBlack : idleColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.gold : idleColor.withValues(alpha: 0.85),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: color ?? AppColors.goldDark, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 14)),
      onTap: onTap,
    );
  }
}
