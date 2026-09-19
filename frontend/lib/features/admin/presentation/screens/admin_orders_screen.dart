import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/flutter_secure_storage_impl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/order_model.dart';
import '../../../customer/presentation/widgets/order_details_sheet.dart';
import '../../../store/data/repositories/store_orders_repository_impl.dart';
import '../../../store/domain/repositories/store_orders_repository.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/repositories/admin_stores_repository.dart';
import '../widgets/admin_scope.dart';

/// Orders oversight screen for Super Admin.
///
/// Connects to StoreOrdersRepository (`GET /orders/store/:storeId`) to provide
/// a real-time oversight feed of actual store orders with status inspection.
class AdminOrdersScreen extends StatefulWidget {
  final AdminStoresRepository? storesRepository;
  final StoreOrdersRepository? ordersRepository;

  const AdminOrdersScreen({
    super.key,
    this.storesRepository,
    this.ordersRepository,
  });

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  bool _isLoadingStores = true;
  String? _storesErrorMessage;
  List<AdminStoreModel> _stores = const [];
  String? _selectedStoreId;

  bool _isLoadingOrders = false;
  String? _ordersErrorMessage;
  List<OrderModel> _orders = const [];
  String? _lastLoadedStoreId;
  bool _hasInitialized = false;

  AdminStoresRepository get _storesRepo =>
      widget.storesRepository ?? AdminScope.storesRepositoryOf(context);

  StoreOrdersRepository get _ordersRepo {
    if (widget.ordersRepository != null) return widget.ordersRepository!;
    final scopeRepo = AdminScope.maybeOf(context)?.ordersRepository;
    if (scopeRepo != null) return scopeRepo;

    final config = AppConfig.fromEnvironment();
    final apiClient = DefaultApiClient(
      baseUrl: config.apiBaseUrl,
      tokenProvider: () =>
          const FlutterSecureStorageImpl().read(key: StorageKeys.authToken),
      timeout: config.connectTimeout,
    );
    return StoreOrdersRepositoryImpl(apiClient: apiClient);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _loadStores();
    }
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoadingStores = true;
      _storesErrorMessage = null;
    });

    final result = await _storesRepo.getStores();

    if (!mounted) return;

    if (result.isSuccess) {
      final stores = result.dataOrNull ?? [];
      setState(() {
        _stores = stores;
        _isLoadingStores = false;
        if (stores.isNotEmpty) {
          _selectedStoreId = stores.first.id;
        }
      });
      if (stores.isNotEmpty) {
        _loadOrders(stores.first.id);
      }
    } else {
      setState(() {
        _isLoadingStores = false;
        _storesErrorMessage =
            result.failureOrNull?.message ?? 'Failed to load stores';
      });
    }
  }

  Future<void> _loadOrders(String? storeId, {bool force = false}) async {
    if (storeId == null || storeId.isEmpty) {
      setState(() {
        _isLoadingOrders = false;
        _orders = const [];
        _ordersErrorMessage = null;
      });
      return;
    }

    // Prevent duplicate requests from ordinary rebuilds unless explicitly forced
    if (!force &&
        _lastLoadedStoreId == storeId &&
        !_isLoadingOrders &&
        _ordersErrorMessage == null &&
        _orders.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingOrders = true;
      _ordersErrorMessage = null;
    });

    _lastLoadedStoreId = storeId;
    final result = await _ordersRepo.getStoreOrders(storeId: storeId);

    if (!mounted) return;

    // Stale check: discard response if store selection changed while request was in-flight
    if (_selectedStoreId != storeId) return;

    if (result.isSuccess) {
      setState(() {
        _orders = result.dataOrNull ?? [];
        _isLoadingOrders = false;
        _ordersErrorMessage = null;
      });
    } else {
      setState(() {
        _isLoadingOrders = false;
        _ordersErrorMessage =
            result.failureOrNull?.message ?? 'Failed to load store orders';
      });
    }
  }

  Color _getStatusBgColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFEF3C7);
      case OrderStatus.accepted:
        return const Color(0xFFEFF6FF);
      case OrderStatus.preparing:
        return const Color(0xFFF5F3FF);
      case OrderStatus.ready:
        return const Color(0xFFFAF5FF);
      case OrderStatus.outForDelivery:
        return const Color(0xFFFFF7ED);
      case OrderStatus.delivered:
        return const Color(0xFFDCFCE7);
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return const Color(0xFFFEE2E2);
    }
  }

  Color _getStatusTextColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFB45309);
      case OrderStatus.accepted:
        return const Color(0xFF1D4ED8);
      case OrderStatus.preparing:
        return const Color(0xFF6D28D9);
      case OrderStatus.ready:
        return const Color(0xFF7E22CE);
      case OrderStatus.outForDelivery:
        return const Color(0xFFC2410C);
      case OrderStatus.delivered:
        return const Color(0xFF15803D);
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return const Color(0xFFB91C1C);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final selectedStore = _stores.where((s) => s.id == _selectedStoreId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Orders Oversight')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (_selectedStoreId != null) {
              await _loadOrders(_selectedStoreId, force: true);
            } else {
              await _loadStores();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Notice Card (preserves existing architecture guidance)
                Card(
                  color: const Color(0xFFF8FAFC),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF3B82F6),
                          size: 24,
                        ),
                        const SizedBox(width: AppDimensions.spacingSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Orders Oversight Architecture',
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The production backend provides order querying via `GET /orders`, supporting both platform-wide order oversight and store-specific scoping (`GET /orders?store_id=:storeId`). Store staff and riders manage operational order fulfillment directly in their designated portals.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
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

                // Store Selector Area
                if (_isLoadingStores)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.spacingLg),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  )
                else if (_storesErrorMessage != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingLg),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: AppDimensions.spacingSm),
                          Text(
                            'Failed to Load Stores',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _storesErrorMessage!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.spacingMd),
                          ElevatedButton.icon(
                            onPressed: _loadStores,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_stores.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingLg),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.store_mall_directory_outlined,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppDimensions.spacingSm),
                          Text(
                            'No Stores Available',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create store locations first to inspect store-specific orders.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Select Store for Order Stream',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  DropdownButtonFormField<String>(
                    key: const Key('admin_orders_store_dropdown'),
                    value: _selectedStoreId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                    ),
                    items: _stores.map((s) {
                      return DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(s.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedStoreId) {
                        setState(() => _selectedStoreId = val);
                        _loadOrders(val, force: true);
                      }
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),

                  // Feed Header with Store Name & Refresh Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Orders Feed',
                            style: AppTextStyles.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (selectedStore != null) ...[
                            const SizedBox(width: AppDimensions.spacingSm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusFull,
                                ),
                              ),
                              child: Text(
                                selectedStore.name,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      IconButton(
                        key: const Key('admin_orders_refresh_button'),
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh Orders',
                        onPressed: () => _loadOrders(_selectedStoreId, force: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Orders Stream Content
                  if (_isLoadingOrders)
                    const Padding(
                      key: Key('admin_orders_loading_indicator'),
                      padding: EdgeInsets.all(AppDimensions.spacing2xl),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  else if (_ordersErrorMessage != null)
                    Card(
                      key: const Key('admin_orders_error_card'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.spacingLg),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 40,
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              'Failed to Load Orders',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _ordersErrorMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDimensions.spacingMd),
                            ElevatedButton.icon(
                              key: const Key('admin_orders_retry_button'),
                              onPressed: () =>
                                  _loadOrders(_selectedStoreId, force: true),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_orders.isEmpty)
                    Card(
                      key: const Key('admin_orders_empty_state'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.spacingXl),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inbox_outlined,
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
                              'This store does not have any orders recorded yet.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDimensions.spacingMd),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _loadOrders(_selectedStoreId, force: true),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    ..._orders.map((order) => _buildOrderCard(order)),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusBg = _getStatusBgColor(order.status);
    final statusColor = _getStatusTextColor(order.status);
    final isPickup = order.fulfillment == FulfillmentType.pickup;
    final orderDisplayId = order.orderNumber?.isNotEmpty == true
        ? order.orderNumber!
        : (order.id.length > 8 ? order.id.substring(0, 8) : order.id);

    return Card(
      key: Key('admin_order_card_${order.id}'),
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () {
          OrderDetailsSheet.show(context, order: order);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order ID & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #$orderDisplayId',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),

              // Fulfillment Type & Creation Timestamp
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isPickup
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPickup
                              ? Icons.storefront_outlined
                              : Icons.delivery_dining_outlined,
                          size: 14,
                          color: isPickup
                              ? const Color(0xFF475569)
                              : AppColors.primaryDark,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isPickup ? 'PICKUP' : 'DELIVERY',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isPickup
                                ? const Color(0xFF475569)
                                : AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (order.createdAt != null) ...[
                    const SizedBox(width: AppDimensions.spacingSm),
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _formatDateTime(order.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),

              // Items Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.items.isNotEmpty
                          ? '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}: ${order.items.map((i) => i.name).take(2).join(', ')}${order.items.length > 2 ? '...' : ''}'
                          : 'No items',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${order.total.toStringAsFixed(2)} ${AppConstants.defaultCurrency}',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
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
}
