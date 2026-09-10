/// Centralized route name constants for eSOuQ.
abstract final class AppRoutes {
  static const String initial = '/';

  // Authentication Routes
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String staffLogin = '/auth/staff/login';
  static const String riderLogin = '/auth/rider/login';
  static const String adminMagicLink = '/auth/admin/magic-link';
  static const String adminPending = '/auth/admin/pending';
  static const String adminVerify = '/auth/admin/verify';

  // Role Home Dashboards (temporary placeholders for subsequent phases)
  static const String customerHome = '/customer/home';
  static const String riderHome = '/rider/home';
  static const String storeHome = '/store/home';
  static const String adminHome = '/admin/home';

  // Development/Debug-Only Routes (guarded by kDebugMode)
  static const String devCustomerPreview = '/dev/customer-preview';
}
