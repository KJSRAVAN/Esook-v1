import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/models/admin_user_model.dart';
import '../../domain/repositories/admin_stores_repository.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../widgets/admin_scope.dart';
import '../widgets/admin_stat_card.dart';

/// Super Admin console overview dashboard showing real system statistics.
class AdminDashboardScreen extends StatefulWidget {
  final AdminUsersRepository? usersRepository;
  final AdminStoresRepository? storesRepository;
  final ValueChanged<int>? onNavigateTab;

  const AdminDashboardScreen({
    super.key,
    this.usersRepository,
    this.storesRepository,
    this.onNavigateTab,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<AdminUserModel> _users = const [];
  List<AdminStoreModel> _stores = const [];
  int _totalUsersCount = 0;

  AdminUsersRepository get _usersRepo =>
      widget.usersRepository ?? AdminScope.usersRepositoryOf(context);

  AdminStoresRepository get _storesRepo =>
      widget.storesRepository ?? AdminScope.storesRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final usersResult = await _usersRepo.getUsers(page: 1, limit: 100);
    final storesResult = await _storesRepo.getStores();

    if (!mounted) return;

    if (usersResult.isSuccess && storesResult.isSuccess) {
      final userPage = usersResult.dataOrNull!;
      setState(() {
        _users = userPage.users;
        _totalUsersCount = userPage.total;
        _stores = storesResult.dataOrNull ?? [];
        _isLoading = false;
      });
    } else {
      final error = usersResult.failureOrNull?.message ??
          storesResult.failureOrNull?.message ??
          'Failed to load dashboard metrics';
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            key: const Key('dashboard_refresh_button'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDashboardData,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Dashboard Error',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('dashboard_retry_button'),
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final customerCount = _users.where((u) => u.role.isCustomer).length;
    final staffCount = _users.where((u) => u.role.isStoreStaff).length;
    final driverCount = _users.where((u) => u.role.isDeliveryRider || u.rawRole?.toUpperCase() == 'DRIVER').length;
    final activeStoreCount = _stores.where((s) => s.isActive).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Live platform state and core entities',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Stat Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800
                  ? 4
                  : constraints.maxWidth > 500
                      ? 2
                      : 2;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppDimensions.spacingMd,
                mainAxisSpacing: AppDimensions.spacingMd,
                childAspectRatio: 1.3,
                children: [
                  AdminStatCard(
                    title: 'Stores',
                    value: '${_stores.length}',
                    subtitle: '$activeStoreCount Active',
                    icon: Icons.storefront_rounded,
                    iconColor: AppColors.primary,
                    iconBgColor: AppColors.primaryLight,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  AdminStatCard(
                    title: 'Total Users',
                    value: '$_totalUsersCount',
                    subtitle: '$customerCount Customers',
                    icon: Icons.people_alt_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBgColor: const Color(0xFFEFF6FF),
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                  AdminStatCard(
                    title: 'Drivers',
                    value: '$driverCount',
                    subtitle: 'Delivery Fleet',
                    icon: Icons.delivery_dining_rounded,
                    iconColor: const Color(0xFFEA580C),
                    iconBgColor: const Color(0xFFFFF7ED),
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                  AdminStatCard(
                    title: 'Staff / Mgrs',
                    value: '$staffCount',
                    subtitle: 'Store Operations',
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    iconBgColor: const Color(0xFFF5F3FF),
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppDimensions.spacingLg),

          // Quick Navigation Links
          Text(
            'Management Portals',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacingSm),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: const Text('Store Management'),
                  subtitle: const Text('Onboard new supermarket locations, update addresses and status'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  title: const Text('User Directory'),
                  subtitle: const Text('View customer accounts, staff rosters, and role assignments'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => widget.onNavigateTab?.call(2),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFEA580C), size: 20),
                  ),
                  title: const Text('Rider / Driver Management'),
                  subtitle: const Text('Register new delivery partners and manage fleet credentials'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => widget.onNavigateTab?.call(3),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF334155), size: 20),
                  ),
                  title: const Text('Orders Oversight'),
                  subtitle: const Text('Monitor store fulfillment and active deliveries'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => widget.onNavigateTab?.call(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
