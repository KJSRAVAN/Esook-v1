import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/flutter_secure_storage_impl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/store_repository_impl.dart';
import '../../domain/models/store_model.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/store_repository.dart';
import '../widgets/customer_bottom_navigation.dart';
import '../widgets/customer_scope.dart';
import 'customer_account_screen.dart';
import 'customer_cart_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_market_screen.dart';
import 'customer_orders_screen.dart';

/// Main application shell for authenticated customer users.
///
/// Features:
/// - Persistent bottom navigation across the 5 primary customer tabs:
///   1. Market
///   2. Chat
///   3. Cart
///   4. Orders
///   5. Account
/// - Indexed state retention across tab switches
/// - Scoped selected store state and catalog providers
/// - Responsive layout handling with proper SafeArea support
class CustomerShell extends StatefulWidget {
  final int initialIndex;
  final AuthRepository? authRepository;
  final StoreRepository? storeRepository;
  final ProductRepository? productRepository;
  final StoreModel? initialSelectedStore;
  final ValueNotifier<StoreModel?>? selectedStoreNotifier;

  const CustomerShell({
    super.key,
    this.initialIndex = 0,
    this.authRepository,
    this.storeRepository,
    this.productRepository,
    this.initialSelectedStore,
    this.selectedStoreNotifier,
  });

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int _currentIndex;
  late final ValueNotifier<StoreModel?> _storeNotifier;
  late final bool _ownsNotifier;

  late final StoreRepository _storeRepository;
  late final ProductRepository _productRepository;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (widget.selectedStoreNotifier != null) {
      _storeNotifier = widget.selectedStoreNotifier!;
      _ownsNotifier = false;
    } else {
      _storeNotifier = ValueNotifier<StoreModel?>(widget.initialSelectedStore);
      _ownsNotifier = true;
    }

    final config = AppConfig.fromEnvironment();
    final defaultApiClient = DefaultApiClient(
      baseUrl: config.apiBaseUrl,
      tokenProvider: () => const FlutterSecureStorageImpl().read(key: StorageKeys.authToken),
      timeout: config.connectTimeout,
    );

    _storeRepository = widget.storeRepository ?? StoreRepositoryImpl(apiClient: defaultApiClient);
    _productRepository = widget.productRepository ?? ProductRepositoryImpl(apiClient: defaultApiClient);
  }

  @override
  void dispose() {
    if (_ownsNotifier) {
      _storeNotifier.dispose();
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
    return CustomerScope(
      storeRepository: _storeRepository,
      productRepository: _productRepository,
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
            ),
            const CustomerChatScreen(),
            const CustomerCartScreen(),
            const CustomerOrdersScreen(),
            CustomerAccountScreen(authRepository: widget.authRepository),
          ],
        ),
        bottomNavigationBar: CustomerBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _onNavigationTabSelected,
        ),
      ),
    );
  }
}
