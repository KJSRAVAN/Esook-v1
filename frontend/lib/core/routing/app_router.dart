import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/admin/presentation/screens/admin_shell.dart';
import '../../features/auth/presentation/screens/admin_magic_link_pending_screen.dart';
import '../../features/auth/presentation/screens/admin_magic_link_request_screen.dart';
import '../../features/auth/presentation/screens/admin_verify_screen.dart';
import '../../features/auth/presentation/screens/customer_login_screen.dart';
import '../../features/auth/presentation/screens/customer_signup_screen.dart';
import '../../features/auth/presentation/screens/rider_login_screen.dart';
import '../../features/auth/presentation/screens/session_bootstrap_screen.dart';
import '../../features/auth/presentation/screens/staff_login_screen.dart';
import '../../features/customer/presentation/screens/customer_shell.dart';
import '../../features/rider/presentation/screens/rider_shell.dart';
import '../../features/store/presentation/screens/store_shell.dart';
import 'app_routes.dart';

/// Centralized route generator.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '');
    final path = uri.path;

    // Development-only preview route (strictly unreachable in release mode)
    if (kDebugMode && path == AppRoutes.devCustomerPreview) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const CustomerShell(),
      );
    }

    switch (path) {
      case AppRoutes.initial:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SessionBootstrapScreen(),
        );

      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CustomerLoginScreen(),
        );

      case AppRoutes.signup:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CustomerSignupScreen(),
        );

      case AppRoutes.staffLogin:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const StaffLoginScreen(),
        );

      case AppRoutes.riderLogin:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const RiderLoginScreen(),
        );

      case AppRoutes.adminMagicLink:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdminMagicLinkRequestScreen(),
        );

      case AppRoutes.adminPending:
        final args = settings.arguments as Map<String, dynamic>?;
        final email = args?['email'] as String? ?? uri.queryParameters['email'] ?? 'admin@esouq.com';
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AdminMagicLinkPendingScreen(email: email),
        );

      case AppRoutes.adminVerify:
        final args = settings.arguments as Map<String, dynamic>?;
        final token = args?['token'] as String? ?? uri.queryParameters['token'];
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AdminVerifyScreen(token: token),
        );

      // Customer authenticated shell
      case AppRoutes.customerHome:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CustomerShell(),
        );

      case AppRoutes.storeHome:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const StoreShell(),
        );

      case AppRoutes.riderHome:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const RiderShell(),
        );

      case AppRoutes.adminHome:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdminShell(),
        );

      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _NotFoundScreen(routeName: settings.name),
        );
    }
  }
}

/// Fallback screen for undefined routes.
class _NotFoundScreen extends StatelessWidget {
  final String? routeName;

  const _NotFoundScreen({this.routeName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No route defined for "$routeName"',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
