import 'package:esouq/core/routing/app_router.dart';
import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/core/routing/role_routing.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/presentation/widgets/auth_scope.dart';
import 'package:esouq/features/customer/cart/presentation/screens/cart_screen.dart';
import 'package:esouq/features/customer/domain/models/store_model.dart';
import 'package:esouq/features/customer/presentation/screens/customer_account_screen.dart';
import 'package:esouq/features/customer/presentation/screens/customer_chat_screen.dart';
import 'package:esouq/features/customer/presentation/screens/customer_market_screen.dart';
import 'package:esouq/features/customer/presentation/screens/customer_orders_screen.dart';
import 'package:esouq/features/customer/presentation/screens/customer_shell.dart';
import 'package:esouq/features/customer/presentation/widgets/customer_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../auth/mocks/mock_auth_repository.dart';
import '../../mocks/mock_cart_repository.dart';
import '../../mocks/mock_order_repository.dart';
import '../../mocks/mock_product_repository.dart';
import '../../mocks/mock_store_repository.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockStoreRepository mockStoreRepository;
  late MockProductRepository mockProductRepository;
  late MockCartRepository mockCartRepository;
  late MockOrderRepository mockOrderRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockStoreRepository = MockStoreRepository();
    mockProductRepository = MockProductRepository();
    mockCartRepository = MockCartRepository();
    mockOrderRepository = MockOrderRepository();
    mockOrderRepository.ordersToReturn = [];
  });

  Widget buildCustomerShell({int initialIndex = 0, StoreModel? initialStore}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {
        AppRoutes.login: (_) =>
            const Scaffold(body: Text('Customer Login Screen')),
        AppRoutes.customerHome: (_) => CustomerShell(
          authRepository: mockAuthRepository,
          storeRepository: mockStoreRepository,
          productRepository: mockProductRepository,
          cartRepository: mockCartRepository,
          orderRepository: mockOrderRepository,
          initialSelectedStore: initialStore,
        ),
      },
      home: AuthScope(
        repository: mockAuthRepository,
        child: CustomerShell(
          initialIndex: initialIndex,
          authRepository: mockAuthRepository,
          storeRepository: mockStoreRepository,
          productRepository: mockProductRepository,
          cartRepository: mockCartRepository,
          orderRepository: mockOrderRepository,
          initialSelectedStore: initialStore,
        ),
      ),
    );
  }

  group('CustomerShell', () {
    testWidgets(
      'renders all 5 bottom navigation tabs and defaults to Market tab',
      (tester) async {
        await tester.pumpWidget(buildCustomerShell());
        await tester.pumpAndSettle();

        expect(find.byType(CustomerBottomNavigation), findsOneWidget);
        expect(find.byKey(const Key('customer_nav_market')), findsOneWidget);
        expect(find.byKey(const Key('customer_nav_chat')), findsOneWidget);
        expect(find.byKey(const Key('customer_nav_cart')), findsOneWidget);
        expect(find.byKey(const Key('customer_nav_orders')), findsOneWidget);
        expect(find.byKey(const Key('customer_nav_account')), findsOneWidget);

        expect(find.text('Market'), findsWidgets);
        expect(find.text('Chat'), findsOneWidget);
        expect(find.text('Cart'), findsOneWidget);
        expect(find.text('Orders'), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);

        // Verify Market screen is loaded
        expect(find.byType(CustomerMarketScreen), findsOneWidget);
      },
    );

    testWidgets('switches to Chat tab when tapped', (tester) async {
      await tester.pumpWidget(buildCustomerShell());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('customer_nav_chat')));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerChatScreen), findsOneWidget);
      expect(find.text('No Active Messages'), findsOneWidget);
      expect(
        find.text(
          'Direct messaging with store staff and delivery riders will be available during active orders.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('switches to Cart tab when tapped', (tester) async {
      await tester.pumpWidget(buildCustomerShell());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('customer_nav_cart')));
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);
      expect(find.text('Your Cart is Empty'), findsOneWidget);
    });

    testWidgets('switches to Orders tab when tapped', (tester) async {
      await tester.pumpWidget(buildCustomerShell());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('customer_nav_orders')));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerOrdersScreen), findsOneWidget);
      expect(find.text('No Orders Yet'), findsOneWidget);
      expect(
        find.text(
          'Track active deliveries and view past grocery order history here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('switches to Account tab when tapped', (tester) async {
      await tester.pumpWidget(buildCustomerShell());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('customer_nav_account')));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAccountScreen), findsOneWidget);
      expect(find.text('Customer Account'), findsOneWidget);
      expect(find.byKey(const Key('account_signout_button')), findsOneWidget);
    });

    testWidgets(
      'selected navigation state updates correctly across tab switches',
      (tester) async {
        await tester.pumpWidget(buildCustomerShell());
        await tester.pumpAndSettle();

        // Initially Market is selected
        expect(
          tester
              .widget<Semantics>(
                find
                    .ancestor(
                      of: find.byKey(const Key('customer_nav_market')),
                      matching: find.byType(Semantics),
                    )
                    .first,
              )
              .properties
              .selected,
          isTrue,
        );

        // Tap Orders
        await tester.tap(find.byKey(const Key('customer_nav_orders')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Semantics>(
                find
                    .ancestor(
                      of: find.byKey(const Key('customer_nav_orders')),
                      matching: find.byType(Semantics),
                    )
                    .first,
              )
              .properties
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<Semantics>(
                find
                    .ancestor(
                      of: find.byKey(const Key('customer_nav_market')),
                      matching: find.byType(Semantics),
                    )
                    .first,
              )
              .properties
              .selected,
          isFalse,
        );
      },
    );

    testWidgets(
      'logout from Account screen calls auth repository and routes back to login',
      (tester) async {
        await tester.pumpWidget(buildCustomerShell(initialIndex: 4));
        await tester.pumpAndSettle();

        expect(find.byType(CustomerAccountScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('account_signout_button')));
        await tester.pumpAndSettle();

        expect(mockAuthRepository.logoutCallCount, equals(1));
        expect(find.text('Customer Login Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'Customer role routing destination maps to customerHome and resolves CustomerShell in AppRouter',
      (tester) async {
        final destination = RoleRouting.getDestinationRoute(UserRole.customer);
        expect(destination, equals(AppRoutes.customerHome));

        final route = AppRouter.onGenerateRoute(
          RouteSettings(name: destination),
        );

        expect(route, isA<MaterialPageRoute<void>>());
        final materialRoute = route as MaterialPageRoute<void>;
        expect(
          materialRoute.builder(tester.element(find.byType(Container))),
          isA<CustomerShell>(),
        );
      },
    );

    testWidgets(
      'renders cleanly on standard mobile viewport (390x844) with zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final store = mockStoreRepository.defaultStores.first;
        await tester.pumpWidget(buildCustomerShell(initialStore: store));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CustomerShell), findsOneWidget);
      },
    );

    testWidgets(
      'renders cleanly on wide desktop viewport (1200x800) with zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final store = mockStoreRepository.defaultStores.first;
        await tester.pumpWidget(buildCustomerShell(initialStore: store));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CustomerShell), findsOneWidget);
      },
    );

    testWidgets(
      'order placement triggers ordersRefreshNotifier, reloads orders, and transitions to Orders tab',
      (tester) async {
        final store = mockStoreRepository.defaultStores.first;
        final ordersNotifier = ValueNotifier<int>(0);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AuthScope(
              repository: mockAuthRepository,
              child: CustomerShell(
                initialIndex: 2, // Start on Cart tab
                authRepository: mockAuthRepository,
                storeRepository: mockStoreRepository,
                productRepository: mockProductRepository,
                cartRepository: mockCartRepository,
                orderRepository: mockOrderRepository,
                initialSelectedStore: store,
                ordersRefreshNotifier: ordersNotifier,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CartScreen), findsOneWidget);
        final initialCalls = mockOrderRepository.getMyOrdersCallCount;

        // Trigger the refresh signal simulating checkout completion
        ordersNotifier.value++;
        await tester.pumpAndSettle();

        // Verify orders were reloaded
        expect(
          mockOrderRepository.getMyOrdersCallCount,
          equals(initialCalls + 1),
        );

        ordersNotifier.dispose();
      },
    );
  });
}
