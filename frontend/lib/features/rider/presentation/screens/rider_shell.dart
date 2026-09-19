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
import '../../data/repositories/rider_repository_impl.dart';
import '../../domain/repositories/rider_repository.dart';
import '../widgets/rider_scope.dart';
import 'rider_account_screen.dart';
import 'rider_active_order_screen.dart';
import 'rider_available_orders_screen.dart';

/// Main responsive navigation shell for the Rider (Delivery Driver) Portal.
///
/// Mobile: BottomNavigationBar
/// Tablet/Desktop (>= 720px): NavigationRail
///
/// Tabs:
/// 0 — Active Delivery
/// 1 — Available Orders
/// 2 — Account
class RiderShell extends StatefulWidget {
  final int initialIndex;
  final AuthRepository? authRepository;
  final RiderRepository? riderRepository;
  final UserModel? initialUser;

  const RiderShell({
    super.key,
    this.initialIndex = 0,
    this.authRepository,
    this.riderRepository,
    this.initialUser,
  });

  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  late int _currentIndex;
  late final AuthRepository _authRepository;
  late final RiderRepository _riderRepository;

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

    _authRepository =
        widget.authRepository ??
        AuthRepositoryImpl(apiClient: apiClient, secureStorage: secureStorage);

    _riderRepository =
        widget.riderRepository ?? RiderRepositoryImpl(apiClient: apiClient);

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
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
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

    return RiderScope(
      riderRepository: _riderRepository,
      authRepository: _authRepository,
      currentUser: _currentUser,
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
      body: IndexedStack(index: _currentIndex, children: _buildScreens()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: AppColors.surface,
        elevation: 2,
        indicatorColor: const Color(0xFFFFF7ED),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(
              Icons.delivery_dining_rounded,
              color: Color(0xFFEA580C),
            ),
            label: 'Active',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(
              Icons.list_alt_rounded,
              color: Color(0xFFEA580C),
            ),
            label: 'Available',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFFEA580C)),
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
            indicatorColor: const Color(0xFFFFF7ED),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: Color(0xFFEA580C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'eSOuQ Rider',
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
                    key: const Key('rider_rail_logout_btn'),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Sign Out',
                    onPressed: _handleLogout,
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.delivery_dining_outlined),
                selectedIcon: Icon(
                  Icons.delivery_dining_rounded,
                  color: Color(0xFFEA580C),
                ),
                label: Text('Active'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(
                  Icons.list_alt_rounded,
                  color: Color(0xFFEA580C),
                ),
                label: Text('Available'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(
                  Icons.person_rounded,
                  color: Color(0xFFEA580C),
                ),
                label: Text('Account'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _buildScreens(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScreens() {
    return [
      RiderActiveOrderScreen(
        riderRepository: _riderRepository,
        onOrderCompleted: () {
          // After completing a delivery, rider may want to see available orders
        },
      ),
      RiderAvailableOrdersScreen(
        riderRepository: _riderRepository,
        onOrderAccepted: () {
          // Switch to Active tab after accepting an order
          _onTabSelected(0);
        },
      ),
      RiderAccountScreen(
        authRepository: _authRepository,
        currentUser: _currentUser,
      ),
    ];
  }
}
