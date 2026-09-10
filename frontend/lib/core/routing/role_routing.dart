import 'package:flutter/material.dart';

import '../../features/auth/domain/models/user_role.dart';
import 'app_routes.dart';

/// Centralized role-to-destination routing service.
///
/// Prevents scattering raw role strings across UI screens and ensures consistent
/// navigation according to backend-assigned user roles.
abstract final class RoleRouting {
  /// Maps a [UserRole] to its designated home dashboard shell route.
  static String getDestinationRoute(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return AppRoutes.customerHome;
      case UserRole.storeStaff:
      case UserRole.storeManager:
        return AppRoutes.storeHome;
      case UserRole.deliveryRider:
        return AppRoutes.riderHome;
      case UserRole.superAdmin:
        return AppRoutes.adminHome;
      case UserRole.unknown:
        return AppRoutes.login;
    }
  }

  /// Navigates the user to their designated role destination shell.
  ///
  /// If [clearStack] is true (default), replaces the entire navigation stack
  /// so that back button doesn't take the user back to the login screen.
  static void navigateForRole(
    BuildContext context,
    UserRole role, {
    bool clearStack = true,
  }) {
    final destination = getDestinationRoute(role);
    if (clearStack) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        destination,
        (route) => false,
      );
    } else {
      Navigator.of(context).pushReplacementNamed(destination);
    }
  }
}
