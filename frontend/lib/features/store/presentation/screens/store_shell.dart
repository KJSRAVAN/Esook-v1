import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/storage/flutter_secure_storage_impl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../data/repositories/store_categories_repository_impl.dart';
import '../../data/repositories/store_orders_repository_impl.dart';
import '../../data/repositories/store_products_repository_impl.dart';
import '../../domain/repositories/store_categories_repository.dart';
import '../../domain/repositories/store_orders_repository.dart';
import '../../domain/repositories/store_products_repository.dart';
import '../widgets/store_scope.dart';
import 'store_account_screen.dart';
import 'store_assignment_required_screen.dart';
import 'store_categories_screen.dart';
import 'store_dashboard_screen.dart';
import 'store_orders_screen.dart';
import 'store_products_screen.dart';

/// Main responsive navigation shell for Store Staff & Manager Portal.
class StoreShell extends StatefulWidget {
  final int initialIndex;
  final AuthRepository? authRepository;
  final StoreOrdersRepository? ordersRepository;
  final StoreProductsRepository? productsRepository;
  final StoreCategoriesRepository? categoriesRepository;
  final UserModel? initialUser;

  const StoreShell({
    super.key,
    this.initialIndex = 0,
    this.authRepository,
    this.ordersRepository,
    this.productsRepository,
    this.categoriesRepository,
    this.initialUser,
  });

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  late int _currentIndex;
  late final AuthRepository _authRepository;
  late final StoreOrdersRepository _ordersRepository;
  late final StoreProductsRepository _productsRepository;
  late final StoreCategoriesRepository _categoriesRepository;

  UserModel? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    final config = AppConfig.fromEnvironment();
    final secureStorage = const FlutterSecureStorageImpl();
    final apiClient = DefaultApiClient(
      baseUrl: config.apiBaseUrl,
      tokenProvider: () => secureStorage.read(key: StorageKeys.authToken),
      timeout: config.connectTimeout,
    );

    _authRepository = widget.authRepository ??
        AuthRepositoryImpl(
          apiClient: apiClient,
          secureStorage: secureStorage,
        );

    _ordersRepository = widget.ordersRepository ??
        StoreOrdersRepositoryImpl(apiClient: apiClient);

    _productsRepository = widget.productsRepository ??
        StoreProductsRepositoryImpl(apiClient: apiClient);

    _categoriesRepository = widget.categoriesRepository ??
        StoreCategoriesRepositoryImpl(apiClient: apiClient);

    if (widget.initialUser != null) {
      _currentUser = widget.initialUser;
      _isLoadingUser = false;
    } else {
      _loadSessionUser();
    }
  }

  Future<void> _loadSessionUser() async {
    final result = await _authRepository.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = result.dataOrNull;
        _isLoadingUser = false;
      });
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  Future<void> _handleLogout() async {
    await _authRepository.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    // Check store context requirement
    final storeId = _currentUser?.storeId;
    if (storeId == null || storeId.isEmpty) {
      return StoreAssignmentRequiredScreen(authRepository: _authRepository);
    }

    return StoreScope(
      ordersRepository: _ordersRepository,
      productsRepository: _productsRepository,
      categoriesRepository: _categoriesRepository,
      authRepository: _authRepository,
      currentUser: _currentUser,
      storeId: storeId,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          if (isWide) {
            return _buildWideLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          StoreDashboardScreen(
            storeId: _currentUser?.storeId,
            ordersRepository: _ordersRepository,
            productsRepository: _productsRepository,
            onNavigateTab: _onTabSelected,
          ),
          StoreOrdersScreen(
            storeId: _currentUser?.storeId,
            ordersRepository: _ordersRepository,
          ),
          StoreProductsScreen(
            storeId: _currentUser?.storeId,
            productsRepository: _productsRepository,
            categoriesRepository: _categoriesRepository,
          ),
          StoreCategoriesScreen(
            storeId: _currentUser?.storeId,
            categoriesRepository: _categoriesRepository,
            productsRepository: _productsRepository,
          ),
          StoreAccountScreen(
            authRepository: _authRepository,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: AppColors.surface,
        elevation: 2,
        indicatorColor: AppColors.primaryLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primaryDark),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primaryDark),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category_rounded, color: AppColors.primaryDark),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryDark),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primaryLight,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'eSOuQ Store',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: IconButton(
                    key: const Key('store_rail_logout_btn'),
                    icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                    tooltip: 'Sign Out',
                    onPressed: _handleLogout,
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primaryDark),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark),
                label: Text('Orders'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primaryDark),
                label: Text('Products'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category_rounded, color: AppColors.primaryDark),
                label: Text('Categories'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryDark),
                label: Text('Account'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                StoreDashboardScreen(
                  storeId: _currentUser?.storeId,
                  ordersRepository: _ordersRepository,
                  productsRepository: _productsRepository,
                  onNavigateTab: _onTabSelected,
                ),
                StoreOrdersScreen(
                  storeId: _currentUser?.storeId,
                  ordersRepository: _ordersRepository,
                ),
                StoreProductsScreen(
                  storeId: _currentUser?.storeId,
                  productsRepository: _productsRepository,
                  categoriesRepository: _categoriesRepository,
                ),
                StoreCategoriesScreen(
                  storeId: _currentUser?.storeId,
                  categoriesRepository: _categoriesRepository,
                  productsRepository: _productsRepository,
                ),
                StoreAccountScreen(
                  authRepository: _authRepository,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
