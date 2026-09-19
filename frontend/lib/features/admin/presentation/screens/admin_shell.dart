import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/storage/flutter_secure_storage_impl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/widgets/auth_scope.dart';
import '../../data/repositories/admin_drivers_repository_impl.dart';
import '../../data/repositories/admin_stores_repository_impl.dart';
import '../../data/repositories/admin_users_repository_impl.dart';
import '../../domain/repositories/admin_drivers_repository.dart';
import '../../domain/repositories/admin_stores_repository.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../../../store/data/repositories/store_orders_repository_impl.dart';
import '../../../store/domain/repositories/store_orders_repository.dart';
import '../widgets/admin_scope.dart';
import 'admin_dashboard_screen.dart';
import 'admin_drivers_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_stores_screen.dart';
import 'admin_users_screen.dart';

/// Main navigation shell for the Super Admin console.
class AdminShell extends StatefulWidget {
  final int initialIndex;
  final AuthRepository? authRepository;
  final AdminUsersRepository? usersRepository;
  final AdminDriversRepository? driversRepository;
  final AdminStoresRepository? storesRepository;
  final StoreOrdersRepository? ordersRepository;

  const AdminShell({
    super.key,
    this.initialIndex = 0,
    this.authRepository,
    this.usersRepository,
    this.driversRepository,
    this.storesRepository,
    this.ordersRepository,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late int _currentIndex;

  late final AdminUsersRepository _usersRepository;
  late final AdminDriversRepository _driversRepository;
  late final AdminStoresRepository _storesRepository;
  late final StoreOrdersRepository _ordersRepository;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    final config = AppConfig.fromEnvironment();
    final apiClient = DefaultApiClient(
      baseUrl: config.apiBaseUrl,
      tokenProvider: () =>
          const FlutterSecureStorageImpl().read(key: StorageKeys.authToken),
      timeout: config.connectTimeout,
    );

    _usersRepository =
        widget.usersRepository ??
        AdminUsersRepositoryImpl(apiClient: apiClient);
    _driversRepository =
        widget.driversRepository ??
        AdminDriversRepositoryImpl(apiClient: apiClient);
    _storesRepository =
        widget.storesRepository ??
        AdminStoresRepositoryImpl(apiClient: apiClient);
    _ordersRepository =
        widget.ordersRepository ??
        StoreOrdersRepositoryImpl(apiClient: apiClient);
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  Future<void> _handleLogout() async {
    final authRepo = widget.authRepository ?? AuthScope.of(context);
    await authRepo.logout();
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      usersRepository: _usersRepository,
      driversRepository: _driversRepository,
      storesRepository: _storesRepository,
      ordersRepository: _ordersRepository,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'eSOuQ Console',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('admin_logout_button'),
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign Out',
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            AdminDashboardScreen(
              usersRepository: _usersRepository,
              storesRepository: _storesRepository,
              onNavigateTab: _onTabSelected,
            ),
            AdminStoresScreen(storesRepository: _storesRepository),
            AdminUsersScreen(usersRepository: _usersRepository),
            AdminDriversScreen(driversRepository: _driversRepository),
            AdminOrdersScreen(
              storesRepository: _storesRepository,
              ordersRepository: _ordersRepository,
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
              selectedIcon: Icon(
                Icons.dashboard_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(
                Icons.storefront_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'Stores',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(
                Icons.people_alt_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'Users',
            ),
            NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              selectedIcon: Icon(
                Icons.delivery_dining_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'Drivers',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'Orders',
            ),
          ],
        ),
      ),
    );
  }
}
