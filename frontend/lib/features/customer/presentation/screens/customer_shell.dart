import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/flutter_secure_storage_impl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../application/points_notifier.dart';
import '../../cart/application/cart_notifier.dart';
import '../../cart/data/cart_repository_impl.dart';
import '../../cart/domain/cart_repository.dart';
import '../../cart/presentation/screens/cart_screen.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/store_repository_impl.dart';
import '../../domain/models/store_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/store_repository.dart';
import '../widgets/customer_bottom_navigation.dart';
import '../widgets/customer_scope.dart';
import 'customer_account_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_market_screen.dart';
import 'customer_orders_screen.dart';

/// Main application shell for authenticated customer users.
class CustomerShell extends StatefulWidget {
  final int initialIndex;
  final AuthRepository? authRepository;
  final StoreRepository? storeRepository;
  final ProductRepository? productRepository;
  final CartRepository? cartRepository;
  final OrderRepository? orderRepository;
  final CartNotifier? cartNotifier;
  final PointsNotifier? pointsNotifier;
  final StoreModel? initialSelectedStore;
  final ValueNotifier<StoreModel?>? selectedStoreNotifier;
  final ValueNotifier<int>? ordersRefreshNotifier;

  const CustomerShell({
    super.key,
    this.initialIndex = 0,
    this.authRepository,
    this.storeRepository,
    this.productRepository,
    this.cartRepository,
    this.orderRepository,
    this.cartNotifier,
    this.pointsNotifier,
    this.initialSelectedStore,
    this.selectedStoreNotifier,
    this.ordersRefreshNotifier,
  });

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int _currentIndex;
  late final ValueNotifier<StoreModel?> _storeNotifier;
  late final bool _ownsNotifier;
  late final ValueNotifier<int> _ordersRefreshNotifier;
  late final bool _ownsOrdersNotifier;

  late final StoreRepository _storeRepository;
  late final ProductRepository _productRepository;
  late final CartRepository _cartRepository;
  late final OrderRepository _orderRepository;
  late final CartNotifier _cartNotifier;
  late final bool _ownsCartNotifier;
  late final PointsNotifier _pointsNotifier;
  late final bool _ownsPointsNotifier;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (widget.ordersRefreshNotifier != null) {
      _ordersRefreshNotifier = widget.ordersRefreshNotifier!;
      _ownsOrdersNotifier = false;
    } else {
      _ordersRefreshNotifier = ValueNotifier<int>(0);
      _ownsOrdersNotifier = true;
    }

    if (widget.selectedStoreNotifier != null) {
      _storeNotifier = widget.selectedStoreNotifier!;
      _ownsNotifier = false;
    } else {
      _storeNotifier = ValueNotifier<StoreModel?>(widget.initialSelectedStore);
      _ownsNotifier = true;
    }

    final config = AppConfig.fromEnvironment();
    const secureStorage = FlutterSecureStorageImpl();
    final defaultApiClient = DefaultApiClient(
      baseUrl: config.apiBaseUrl,
      tokenProvider: () => secureStorage.read(key: StorageKeys.authToken),
      secureStorage: secureStorage,
      timeout: config.connectTimeout,
    );

    _storeRepository =
        widget.storeRepository ??
        StoreRepositoryImpl(apiClient: defaultApiClient);
    _productRepository =
        widget.productRepository ??
        ProductRepositoryImpl(apiClient: defaultApiClient);
    _cartRepository =
        widget.cartRepository ??
        CartRepositoryImpl(apiClient: defaultApiClient);
    _orderRepository =
        widget.orderRepository ??
        OrderRepositoryImpl(apiClient: defaultApiClient);

    if (widget.cartNotifier != null) {
      _cartNotifier = widget.cartNotifier!;
      _ownsCartNotifier = false;
    } else {
      _cartNotifier = CartNotifier(cartRepository: _cartRepository);
      _ownsCartNotifier = true;
    }

    if (widget.pointsNotifier != null) {
      _pointsNotifier = widget.pointsNotifier!;
      _ownsPointsNotifier = false;
    } else {
      _pointsNotifier = PointsNotifier(orderRepository: _orderRepository);
      _ownsPointsNotifier = true;
    }

    _storeNotifier.addListener(_onStoreChanged);

    final initialStore = _storeNotifier.value;
    if (initialStore != null) {
      _cartNotifier.loadForStore(initialStore.id);
      _pointsNotifier.loadForStore(initialStore.id);
    }
  }

  void _onStoreChanged() {
    final store = _storeNotifier.value;
    if (store != null) {
      _cartNotifier.loadForStore(store.id);
      _pointsNotifier.loadForStore(store.id);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _storeNotifier.removeListener(_onStoreChanged);
    if (_ownsPointsNotifier) {
      _pointsNotifier.dispose();
    }
    if (_ownsCartNotifier) {
      _cartNotifier.dispose();
    }
    if (_ownsNotifier) {
      _storeNotifier.dispose();
    }
    if (_ownsOrdersNotifier) {
      _ordersRefreshNotifier.dispose();
    }
    super.dispose();
  }

  void _onNavigationTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedStore = _storeNotifier.value;

    return CustomerScope(
      storeRepository: _storeRepository,
      productRepository: _productRepository,
      cartRepository: _cartRepository,
      orderRepository: _orderRepository,
      cartNotifier: _cartNotifier,
      pointsNotifier: _pointsNotifier,
      selectedStoreNotifier: _storeNotifier,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            CustomerMarketScreen(
              storeRepository: _storeRepository,
              productRepository: _productRepository,
              selectedStoreNotifier: _storeNotifier,
              cartNotifier: _cartNotifier,
              pointsNotifier: _pointsNotifier,
              onViewCart: () => _onNavigationTabSelected(2),
            ),
            CustomerChatScreen(
              onBackToMarket: () => _onNavigationTabSelected(0),
            ),
            CartScreen(
              cartNotifier: _cartNotifier,
              orderRepository: _orderRepository,
              storeName: selectedStore?.name,
              storeArea: selectedStore?.area,
              onExploreMarket: () => _onNavigationTabSelected(0),
              onOrderPlaced: (_) {
                _ordersRefreshNotifier.value++;
                _pointsNotifier.refresh();
                _onNavigationTabSelected(3);
              },
            ),
            CustomerOrdersScreen(
              orderRepository: _orderRepository,
              refreshSignal: _ordersRefreshNotifier,
            ),
            CustomerAccountScreen(
              authRepository: widget.authRepository,
              pointsNotifier: _pointsNotifier,
            ),
          ],
        ),
        bottomNavigationBar: CustomerBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _onNavigationTabSelected,
          cartNotifier: _cartNotifier,
        ),
      ),
    );
  }
}
