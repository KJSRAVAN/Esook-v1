import 'package:esouq/core/routing/app_router.dart';
import 'package:esouq/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRouter', () {
    test('generates MaterialPageRoute for initial route', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.initial),
      );

      expect(route, isA<MaterialPageRoute<void>>());
      expect(route.settings.name, equals(AppRoutes.initial));
    });

    test('generates fallback route for unknown routes', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: '/some-undefined-route'),
      );

      expect(route, isA<MaterialPageRoute<void>>());
      expect(route.settings.name, equals('/some-undefined-route'));
    });
  });
}
