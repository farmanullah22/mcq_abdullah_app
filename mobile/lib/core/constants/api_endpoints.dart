import '../constants/app_constants.dart';

/// Central place for all API endpoint paths.
class ApiEndpoints {
  ApiEndpoints._();

  static String base(String path) => '${AppConstants.baseUrl}$path';

  // Auth
  static String get login => base('/auth/login');
  static String get logout => base('/auth/logout');
  static String get profile => base('/auth/profile');
  static String get changePassword => base('/auth/change-password');
  static String get managers => base('/auth/managers');

  // Dashboard
  static String get dashboard => base('/dashboard');

  // Shops
  static String get shops => base('/shops');
  static String shop(String id) => base('/shops/$id');
  static String restoreShop(String id) => base('/shops/$id/restore');

  // Categories
  static String get categories => base('/categories');
  static String category(String id) => base('/categories/$id');
  static String restoreCategory(String id) => base('/categories/$id/restore');

  // Products
  static String get products => base('/products');
  static String product(String id) => base('/products/$id');
  static String restoreProduct(String id) => base('/products/$id/restore');
  static String get lowStockProducts => base('/products/low-stock');

  // Inventory
  static String get stockIn => base('/inventory/in');
  static String get stockOut => base('/inventory/out');
  static String get inventoryHistory => base('/inventory/history');

  // Sales
  static String get sales => base('/sales');
  static String sale(String id) => base('/sales/$id');
  static String restoreSale(String id) => base('/sales/$id/restore');

  // Expenses
  static String get expenses => base('/expenses');
  static String expense(String id) => base('/expenses/$id');
  static String restoreExpense(String id) => base('/expenses/$id/restore');

  // Reports
  static String get reports => base('/reports');
  static String get reportsSales => base('/reports/sales');
  static String get reportsExpenses => base('/reports/expenses');
  static String get reportsInventory => base('/reports/inventory');
  static String get reportsExport => base('/reports/export');

  // Analytics
  static String get analytics => base('/analytics');

  // Audit
  static String get audit => base('/audit');
  static String get auditStats => base('/audit/stats');
  static String auditLog(String id) => base('/audit/$id');
  static String restoreAudit(String id) => base('/audit/$id/restore');
  static String get auditExport => base('/audit/export');

  // Notifications
  static String get notifications => base('/notifications');
  static String get notificationsUnread => base('/notifications/unread-count');
  static String get notificationsToken => base('/notifications/token');
  static String get notificationsReadAll => base('/notifications/read-all');
  static String notification(String id) => base('/notifications/$id');
  static String notificationRead(String id) => base('/notifications/$id/read');
}
