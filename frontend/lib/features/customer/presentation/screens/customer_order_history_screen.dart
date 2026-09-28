import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../cart/application/cart_notifier.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../widgets/customer_scope.dart';
import '../widgets/order_details_sheet.dart';

/// Screen presenting the authenticated customer's comprehensive order history,
/// highlighting latest pending and completed orders, with filtering for
/// Pending, Completed (Delivered), Cancelled, and Rejected orders.
class CustomerOrderHistoryScreen extends StatefulWidget {
  final OrderRepository? orderRepository;
  final CartNotifier? cartNotifier;

  const CustomerOrderHistoryScreen({
    super.key,
    this.orderRepository,
    this.cartNotifier,
  });

  @override
  State<CustomerOrderHistoryScreen> createState() =>
      _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState
    extends State<CustomerOrderHistoryScreen> {
  OrderRepository? _repository;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<OrderModel> _orders = const [];
  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _hasMore = true;
  String _selectedStatusFilter = 'ALL';
  bool _isInitialized = false;

  static const List<String> _statusFilters = [
    'ALL',
    'PENDING',
    'DELIVERED',
    'CANCELLED',
    'REJECTED',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _repository =
          widget.orderRepository ??
          CustomerScope.maybeOf(context)?.orderRepository;
      _isInitialized = true;
      if (_repository != null) {
        _loadOrders();
      }
    }
  }

  OrderRepository? get _effectiveRepo =>
      _repository ??
      widget.orderRepository ??
      CustomerScope.maybeOf(context)?.orderRepository;

  CartNotifier? get _effectiveCartNotifier =>
      widget.cartNotifier ?? CustomerScope.maybeOf(context)?.cartNotifier;

  Future<void> _loadOrders({bool refresh = false}) async {
    final repo = _effectiveRepo;
    if (repo == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (refresh) {
        _currentPage = 1;
        _hasMore = true;
      }
    });

    final OrderStatus? statusParam;
    if (_selectedStatusFilter == 'ALL') {
      statusParam = null;
    } else {
      statusParam = OrderStatus.fromString(_selectedStatusFilter);
    }

    final result = await repo.getMyOrders(
      page: 1,
      limit: _pageSize,
      status: statusParam,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (orders) {
        setState(() {
          _orders = orders;
          _isLoading = false;
          _currentPage = 1;
          _hasMore = orders.length >= _pageSize;
        });
      },
      onFailure: (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMore) return;
    final repo = _effectiveRepo;
    if (repo == null) return;

    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final OrderStatus? statusParam =
        _selectedStatusFilter == 'ALL'
            ? null
            : OrderStatus.fromString(_selectedStatusFilter);

    final result = await repo.getMyOrders(
      page: nextPage,
      limit: _pageSize,
      status: statusParam,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (newOrders) {
        setState(() {
          _orders = [..._orders, ...newOrders];
          _currentPage = nextPage;
          _isLoadingMore = false;
          _hasMore = newOrders.length >= _pageSize;
        });
      },
      onFailure: (failure) {
        setState(() => _isLoadingMore = false);
      },
    );
  }

  void _onFilterChanged(String filter) {
    if (_selectedStatusFilter != filter) {
      setState(() => _selectedStatusFilter = filter);
      _loadOrders(refresh: true);
    }
  }

  OrderModel? get _latestPendingOrder {
    final pendingOrders = _orders.where(
      (o) =>
          o.status == OrderStatus.pending ||
          o.status == OrderStatus.accepted ||
          o.status == OrderStatus.preparing,
    );
    if (pendingOrders.isEmpty) return null;
    return pendingOrders.first;
  }

  OrderModel? get _latestCompletedOrder {
    final completedOrders = _orders.where(
      (o) => o.status == OrderStatus.delivered,
    );
    if (completedOrders.isEmpty) return null;
    return completedOrders.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order History'),
        actions: [
          IconButton(
            key: const Key('order_history_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : () => _loadOrders(refresh: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusFilters.map((status) {
            final isSelected = _selectedStatusFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingSm),
              child: ChoiceChip(
                key: Key('order_history_chip_$status'),
                label: Text(
                  _formatStatusChipLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.background,
                onSelected: (_) => _onFilterChanged(status),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null && _orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48.0,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'Unable to load order history',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              ElevatedButton.icon(
                key: const Key('order_history_retry_btn'),
                onPressed: () => _loadOrders(refresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 18.0),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedStatusFilter == 'ALL'
                    ? 'You have not placed any orders yet.'
                    : 'No orders found matching the "${_formatStatusChipLabel(_selectedStatusFilter)}" status.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final latestPending = _latestPendingOrder;
    final latestCompleted = _latestCompletedOrder;

    return RefreshIndicator(
      onRefresh: () => _loadOrders(refresh: true),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        itemCount: _orders.length + (_hasHighlightSection ? 1 : 0) + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (_hasHighlightSection && index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (latestPending != null &&
                    (_selectedStatusFilter == 'ALL' ||
                        _selectedStatusFilter == 'PENDING'))
                  _buildHighlightCard(
                    key: const Key('latest_pending_order_card'),
                    title: 'Latest Pending Order',
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                    order: latestPending,
                  ),
                if (latestCompleted != null &&
                    (_selectedStatusFilter == 'ALL' ||
                        _selectedStatusFilter == 'DELIVERED'))
                  _buildHighlightCard(
                    key: const Key('latest_completed_order_card'),
                    title: 'Latest Completed Order',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF15803D),
                    bgColor: const Color(0xFFDCFCE7),
                    order: latestCompleted,
                  ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'All Recent Orders (${_orders.length})',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
              ],
            );
          }

          final orderIndex = _hasHighlightSection ? index - 1 : index;

          if (orderIndex >= _orders.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: _isLoadingMore
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton(
                        key: const Key('order_history_load_more_btn'),
                        onPressed: _loadMoreOrders,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text('Load More Orders'),
                      ),
              ),
            );
          }

          final order = _orders[orderIndex];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  bool get _hasHighlightSection =>
      _latestPendingOrder != null || _latestCompletedOrder != null;

  Widget _buildHighlightCard({
    required Key key,
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required OrderModel order,
  }) {
    final orderNum = order.orderNumber ?? '#${order.id.takeLast(8)}';

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${order.total.toStringAsFixed(2)} SAR',
                style: AppTextStyles.titleMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order $orderNum',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (order.createdAt != null)
                Text(
                  _formatDate(order.createdAt!),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (order.storeName != null) ...[
            const SizedBox(height: 2),
            Text(
              'Store: ${order.storeName}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('highlight_view_details_${order.id}'),
              onPressed: () => _openOrderDetails(order),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('View Order Details'),
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final orderNum = order.orderNumber ?? '#${order.id.takeLast(8)}';
    final statusColor = _getStatusColor(order.status);
    final statusBgColor = _getStatusBgColor(order.status);

    return Card(
      key: Key('history_order_card_${order.id}'),
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () => _openOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header: Order # and Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order $orderNum',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    key: Key('order_status_badge_${order.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Store and timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.storeName ?? 'eSOuQ Supermarket',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (order.createdAt != null)
                    Text(
                      _formatDate(order.createdAt!),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),

              // Rejection reason banner (if rejected)
              if (order.status == OrderStatus.rejected) ...[
                const SizedBox(height: 8),
                Container(
                  key: Key('rejected_reason_${order.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cancel_outlined,
                        size: 16,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.rejectedReason != null &&
                                  order.rejectedReason!.isNotEmpty
                              ? 'Rejected: ${order.rejectedReason}'
                              : 'Order was rejected by store staff.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 18),

              // Badges row and total price
              Row(
                children: [
                  // Fulfillment badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.fulfillment == FulfillmentType.pickup
                              ? Icons.storefront_rounded
                              : Icons.delivery_dining_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.fulfillment.displayName,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Payment method badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.paymentMethod == PaymentMethod.cash
                              ? Icons.payments_outlined
                              : Icons.credit_card_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.paymentMethod.displayName,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Item count and Total
                  Text(
                    '${order.itemCount} ${order.itemCount == 1 ? "item" : "items"}  •  ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    '${order.total.toStringAsFixed(2)} SAR',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openOrderDetails(OrderModel order) {
    OrderDetailsSheet.show(
      context,
      order: order,
      orderRepository: _effectiveRepo,
      cartNotifier: _effectiveCartNotifier,
    );
  }

  Color _getStatusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => const Color(0xFFD97706),
      OrderStatus.accepted ||
      OrderStatus.preparing ||
      OrderStatus.ready ||
      OrderStatus.outForDelivery => const Color(0xFF1D4ED8),
      OrderStatus.delivered => const Color(0xFF15803D),
      OrderStatus.cancelled => const Color(0xFF64748B),
      OrderStatus.rejected => const Color(0xFFDC2626),
    };
  }

  Color _getStatusBgColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => const Color(0xFFFEF3C7),
      OrderStatus.accepted ||
      OrderStatus.preparing ||
      OrderStatus.ready ||
      OrderStatus.outForDelivery => const Color(0xFFDBEAFE),
      OrderStatus.delivered => const Color(0xFFDCFCE7),
      OrderStatus.cancelled => const Color(0xFFF1F5F9),
      OrderStatus.rejected => const Color(0xFFFEE2E2),
    };
  }

  String _formatStatusChipLabel(String status) {
    return switch (status) {
      'ALL' => 'All Orders',
      'PENDING' => 'Pending',
      'DELIVERED' => 'Completed',
      'CANCELLED' => 'Cancelled',
      'REJECTED' => 'Rejected',
      _ => status,
    };
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

extension _StringExt on String {
  String takeLast(int n) {
    if (length <= n) return this;
    return substring(length - n);
  }
}
