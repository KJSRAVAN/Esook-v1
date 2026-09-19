import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/order_model.dart';
import '../../../customer/domain/models/product_model.dart';
import '../../domain/repositories/store_orders_repository.dart';
import '../../domain/repositories/store_products_repository.dart';
import '../widgets/store_scope.dart';

/// Store operations overview dashboard for Staff and Managers.
class StoreDashboardScreen extends StatefulWidget {
  final String? storeId;
  final StoreOrdersRepository? ordersRepository;
  final StoreProductsRepository? productsRepository;
  final ValueChanged<int>? onNavigateTab;

  const StoreDashboardScreen({
    super.key,
    this.storeId,
    this.ordersRepository,
    this.productsRepository,
    this.onNavigateTab,
  });

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<OrderModel> _orders = const [];
  List<ProductModel> _products = const [];

  String? get _effectiveStoreId =>
      widget.storeId ?? StoreScope.storeIdOf(context);

  StoreOrdersRepository get _ordersRepo =>
      widget.ordersRepository ?? StoreScope.ordersRepositoryOf(context);

  StoreProductsRepository get _productsRepo =>
      widget.productsRepository ?? StoreScope.productsRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final storeId = _effectiveStoreId;
    if (storeId == null || storeId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Store ID is not available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ordersFuture = _ordersRepo.getStoreOrders(
      storeId: storeId,
      limit: 100,
    );
    final productsFuture = _productsRepo.getStoreProducts(storeId);

    final results = await Future.wait([ordersFuture, productsFuture]);
    final ordersRes = results[0] as dynamic;
    final productsRes = results[1] as dynamic;

    if (!mounted) return;

    if (ordersRes.isSuccess && productsRes.isSuccess) {
      setState(() {
        _orders = ordersRes.dataOrNull ?? [];
        _products = productsRes.dataOrNull ?? [];
        _isLoading = false;
      });
    } else {
      final error =
          ordersRes.failureOrNull?.message ??
          productsRes.failureOrNull?.message ??
          'Failed to load store metrics';
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = StoreScope.currentUserOf(context);
    final isManager = currentUser?.role.isStoreManager ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Operations'),
        actions: [
          IconButton(
            key: const Key('store_dashboard_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDashboardData,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(isManager)),
    );
  }

  Widget _buildBody(bool isManager) {
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
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Dashboard Error',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('store_dashboard_retry_btn'),
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final pendingCount = _orders
        .where((o) => o.status == OrderStatus.pending)
        .length;
    final preparingCount = _orders
        .where(
          (o) =>
              o.status == OrderStatus.preparing ||
              o.status == OrderStatus.accepted,
        )
        .length;
    final readyCount = _orders
        .where(
          (o) =>
              o.status == OrderStatus.ready ||
              o.status == OrderStatus.outForDelivery,
        )
        .length;
    final completedCount = _orders
        .where((o) => o.status == OrderStatus.delivered)
        .length;
    final availableProductsCount = _products.where((p) => p.isAvailable).length;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Status Banner
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _orders.isNotEmpty &&
                                    _orders.first.storeName != null
                                ? _orders.first.storeName!
                                : 'Assigned Store',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isManager
                                ? 'Store Manager Console'
                                : 'Store Staff Operations',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF15803D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // Operational Metrics Grid
            Text(
              'Order Pipeline',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: AppDimensions.spacingSm,
              mainAxisSpacing: AppDimensions.spacingSm,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  title: 'Pending Action',
                  count: '$pendingCount',
                  subtitle: 'Awaiting acceptance',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                _buildStatCard(
                  title: 'In Preparation',
                  count: '$preparingCount',
                  subtitle: 'Cooking / Packing',
                  icon: Icons.outdoor_grill_outlined,
                  color: const Color(0xFF6D28D9),
                  bgColor: const Color(0xFFF5F3FF),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                _buildStatCard(
                  title: 'Ready / Out',
                  count: '$readyCount',
                  subtitle: 'Pickup / Transit',
                  icon: Icons.delivery_dining_rounded,
                  color: const Color(0xFFEA580C),
                  bgColor: const Color(0xFFFFF7ED),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                _buildStatCard(
                  title: 'Completed',
                  count: '$completedCount',
                  subtitle: 'Delivered orders',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF15803D),
                  bgColor: const Color(0xFFDCFCE7),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),

            // Catalog Overview
            Text(
              'Catalog Status',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),

            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Store Products',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '$availableProductsCount of ${_products.length} items currently available',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => widget.onNavigateTab?.call(2),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),

            // Quick Actions
            Text(
              'Quick Actions',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Store Orders Stream'),
                    subtitle: const Text(
                      'View incoming customer orders and update status',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.category_outlined,
                      color: Color(0xFF7C3AED),
                    ),
                    title: const Text('Categories & Sections'),
                    subtitle: const Text(
                      'View and manage catalog category aisles',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                ],
              ),
              Text(
                count,
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
