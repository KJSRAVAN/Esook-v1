import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/core/routing/role_routing.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoleRouting', () {
    test('maps UserRole.customer to customerHome route', () {
      expect(
        RoleRouting.getDestinationRoute(UserRole.customer),
        equals(AppRoutes.customerHome),
      );
    });

    test('maps UserRole.storeStaff to storeHome route', () {
      expect(
        RoleRouting.getDestinationRoute(UserRole.storeStaff),
        equals(AppRoutes.storeHome),
      );
    });

    test('maps UserRole.storeManager to storeHome route', () {
      expect(
        RoleRouting.getDestinationRoute(UserRole.storeManager),
        equals(AppRoutes.storeHome),
      );
    });

    test('maps UserRole.deliveryRider to riderHome route', () {
      expect(
        RoleRouting.getDestinationRoute(UserRole.deliveryRider),
        equals(AppRoutes.riderHome),
      );
    });

    test('maps UserRole.superAdmin to adminHome route', () {
      expect(
        RoleRouting.getDestinationRoute(UserRole.superAdmin),
        equals(AppRoutes.adminHome),
      );
    });

    test('maps UserRole.unknown to login route fallback', () {
      expect(
        RoleRouting.getDestinationRoute(UserRole.unknown),
        equals(AppRoutes.login),
      );
    });
  });
}
