import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/order_model.dart';
import '../../domain/repositories/store_orders_repository.dart';
import '../widgets/store_order_card.dart';
import '../widgets/store_order_details_sheet.dart';
import '../widgets/store_scope.dart';

/// Orders management screen for Store Staff and Managers.
class StoreOrdersScreen extends StatefulWidget {
  final String? storeId;
  final StoreOrdersRepository? ordersRepository;

  const StoreOrdersScreen({super.key, this.storeId, this.ordersRepository});

  @override
  State<StoreOrdersScreen> createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends State<StoreOrdersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<OrderModel> _orders = const [];
  String _selectedStatusFilter = 'ALL';
  String _searchQuery = '';

  String? get _effectiveStoreId =>
      widget.storeId ?? StoreScope.storeIdOf(context);

  StoreOrdersRepository get _ordersRepo =>
      widget.ordersRepository ?? StoreScope.ordersRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
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

    final statusParam = _selectedStatusFilter == 'ALL'
        ? null
        : _selectedStatusFilter;
    final result = await _ordersRepo.getStoreOrders(
      storeId: storeId,
      status: statusParam,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _orders = result.dataOrNull ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result.failureOrNull?.message ?? 'Failed to load store orders';
      });
    }
  }

  Future<void> _handleQuickStatusChange(
    OrderModel order,
    OrderStatus newStatus,
  ) async {
    final result = await _ordersRepo.updateOrderStatus(
      orderId: order.id,
      status: newStatus,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final updated = result.dataOrNull!;
      setState(() {
        _orders = _orders.map((o) => o.id == updated.id ? updated : o).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order #${order.orderNumber ?? order.id.substring(0, 6)} is now ${updated.status.displayName}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureOrNull?.message ?? 'Failed to update order status',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openOrderDetails(OrderModel order) {
    StoreOrderDetailsSheet.show(
      context,
      order: order,
      ordersRepository: _ordersRepo,
    ).then((updated) {
      if (updated != null && mounted) {
        setState(() {
          _orders = _orders
              .map((o) => o.id == updated.id ? updated : o)
              .toList();
        });
      }
    });
  }

  List<OrderModel> get _filteredOrders {
    var list = _orders;

    if (_selectedStatusFilter != 'ALL') {
      final targetStatus = OrderStatus.fromString(_selectedStatusFilter);
      list = list.where((o) => o.status == targetStatus).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((o) {
        final matchNum = o.orderNumber?.toLowerCase().contains(q) ?? false;
        final matchId = o.id.toLowerCase().contains(q);
        final matchCustomer = o.customerId.toLowerCase().contains(q);
        final matchAddress =
            o.deliveryAddress?.toLowerCase().contains(q) ?? false;
        return matchNum || matchId || matchCustomer || matchAddress;
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Orders'),
        actions: [
          IconButton(
            key: const Key('store_orders_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadOrders,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Filter Header
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingMd,
                AppDimensions.spacingSm,
                AppDimensions.spacingMd,
                AppDimensions.spacingSm,
              ),
              child: Column(
                children: [
                  TextField(
                    key: const Key('store_orders_search_input'),
                    decoration: InputDecoration(
                      hintText: 'Search order number or address...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('ALL', 'All Orders'),
                        _buildFilterChip('PENDING', 'Pending'),
                        _buildFilterChip('ACCEPTED', 'Accepted'),
                        _buildFilterChip('PREPARING', 'Preparing'),
                        _buildFilterChip('READY', 'Ready'),
                        _buildFilterChip(
                          'OUT_FOR_DELIVERY',
                          'Out for Delivery',
                        ),
                        _buildFilterChip('DELIVERED', 'Completed'),
                        _buildFilterChip('REJECTED', 'Rejected / Cancelled'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Orders list or states
            Expanded(child: _buildListBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedStatusFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        key: Key('orders_filter_$filterKey'),
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primaryDark,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedStatusFilter = filterKey);
          }
        },
      ),
    );
  }

  Widget _buildListBody() {
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
              Text('Failed to Load Orders', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('orders_retry_btn'),
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final displayOrders = _filteredOrders;

    if (displayOrders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      'No Orders Found',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedStatusFilter == 'ALL'
                          ? 'There are currently no orders for this store'
                          : 'No orders matching the selected status filter',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        itemCount: displayOrders.length,
        itemBuilder: (context, index) {
          final order = displayOrders[index];
          return StoreOrderCard(
            key: Key('store_order_card_${order.id}'),
            order: order,
            onTap: () => _openOrderDetails(order),
            onQuickStatusChange: (newStatus) =>
                _handleQuickStatusChange(order, newStatus),
          );
        },
      ),
    );
  }
}
