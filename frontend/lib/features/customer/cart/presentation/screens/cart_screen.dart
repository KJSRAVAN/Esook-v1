import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_dimensions.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:esouq/features/customer/cart/presentation/widgets/cart_empty_state.dart';
import 'package:esouq/features/customer/cart/presentation/widgets/cart_item_tile.dart';
import 'package:esouq/features/customer/cart/presentation/widgets/cart_summary_bar.dart';
import 'package:esouq/features/customer/cart/presentation/widgets/cart_unavailable_banner.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/domain/repositories/order_repository.dart';
import 'package:esouq/features/customer/presentation/screens/customer_order_tracking_screen.dart';
import 'package:esouq/features/customer/presentation/widgets/checkout_bottom_sheet.dart';
import 'package:esouq/features/customer/presentation/widgets/customer_scope.dart';
import 'package:flutter/material.dart';

/// Modern, production-quality screen presenting the authenticated customer's store-scoped cart.
class CartScreen extends StatelessWidget {
  final CartNotifier cartNotifier;
  final OrderRepository? orderRepository;
  final String? storeName;
  final String? storeArea;
  final VoidCallback? onExploreMarket;
  final ValueChanged<OrderModel>? onOrderPlaced;
  final String currency;

  const CartScreen({
    super.key,
    required this.cartNotifier,
    this.orderRepository,
    this.storeName,
    this.storeArea,
    this.onExploreMarket,
    this.onOrderPlaced,
    this.currency = AppConstants.defaultCurrency,
  });

  Future<void> _showClearConfirmationDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Clear Cart?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all items from your cart? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_clear_cart_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await cartNotifier.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartNotifier,
      builder: (context, _) {
        final cart = cartNotifier.cart;
        final isLoading = cartNotifier.isLoading;
        final error = cartNotifier.error;
        final scopeStore = CustomerScope.maybeOf(context)?.selectedStoreNotifier.value;
        final storeId = cartNotifier.currentStoreId ?? cart?.storeId ?? scopeStore?.id;
        final effectiveStoreName = storeName ?? scopeStore?.name ?? cart?.store.name;

        // Auto-trigger load if store is known in scope but cart is not yet loaded
        if (cart == null && !isLoading && error == null && storeId != null && storeId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (cartNotifier.cart == null && !cartNotifier.isLoading && cartNotifier.error == null) {
              cartNotifier.loadForStore(storeId);
            }
          });
        }

        // 1. No store selected state (and cart has no items)
        if ((storeId == null || storeId.isEmpty) && (cart == null || cart.isEmpty)) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            appBar: AppBar(
              title: const Text('My Cart', style: TextStyle(fontWeight: FontWeight.w700)),
              centerTitle: false,
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: CartEmptyState(
              storeName: null,
              onExploreMarket: onExploreMarket,
            ),
          );
        }

        // 2. Initial loading state (no cart loaded yet)
        if (isLoading && cart == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            appBar: AppBar(
              title: const Text('My Cart', style: TextStyle(fontWeight: FontWeight.w700)),
              centerTitle: false,
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        // 3. Initial error state (no cart loaded yet)
        if (error != null && cart == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            appBar: AppBar(
              title: const Text('My Cart', style: TextStyle(fontWeight: FontWeight.w700)),
              centerTitle: false,
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 52.0,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      'Unable to load cart',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      error.message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    ElevatedButton.icon(
                      key: const Key('cart_error_retry_button'),
                      onPressed: (storeId != null && storeId.isNotEmpty)
                          ? () => cartNotifier.loadForStore(storeId)
                          : null,
                      icon: const Icon(Icons.refresh_rounded, size: 18.0),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 4. Empty cart state
        if (cart == null || cart.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Cart', style: TextStyle(fontWeight: FontWeight.w700)),
                  if (effectiveStoreName != null && effectiveStoreName.isNotEmpty)
                    Text(
                      effectiveStoreName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
              centerTitle: false,
            ),
            body: CartEmptyState(
              storeName: effectiveStoreName,
              onExploreMarket: onExploreMarket,
            ),
          );
        }

        // Calculate total savings
        final totalSavings = cart.items.fold<double>(
          0.0,
          (sum, item) => sum + (item.hasOffer ? item.totalSavings : 0.0),
        );

        // 5. Populated cart state
        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: onExploreMarket != null
                ? IconButton(
                    key: const Key('cart_continue_shopping_button'),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    tooltip: 'Continue Shopping',
                    onPressed: onExploreMarket,
                  )
                : null,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Cart',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                Text(
                  '${effectiveStoreName ?? cart.store.name}${storeArea != null ? ' • $storeArea' : ''}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            centerTitle: false,
            actions: [
              TextButton.icon(
                key: const Key('cart_clear_action_button'),
                onPressed: cartNotifier.isClearing
                    ? null
                    : () => _showClearConfirmationDialog(context),
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  size: 18.0,
                  color: AppColors.error,
                ),
                label: Text(
                  'Clear',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              if (cart.hasUnavailableItems) const CartUnavailableBanner(),

              // Scrollable Cart content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  children: [
                    // Store Delivery Badge Strip
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                        vertical: 4.0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              size: 16.0,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  effectiveStoreName ?? cart.store.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Delivery & Store Pickup Available',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 3.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Text(
                              '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
                              style: const TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6.0),

                    // List of Cart Items
                    ...cart.items.map((item) {
                      return CartItemTile(
                        key: Key('cart_item_tile_${item.productId}'),
                        item: item,
                        isPending: cartNotifier.isProductPending(item.productId) ||
                            cartNotifier.isProductPending(item.itemId),
                        currency: currency,
                        onQuantityChanged: (newQty) =>
                            cartNotifier.setQuantity(item.itemId.isNotEmpty ? item.itemId : item.productId, newQty, storeId),
                        onRemove: () => cartNotifier.removeItem(item.itemId.isNotEmpty ? item.itemId : item.productId, storeId),
                      );
                    }),

                    const SizedBox(height: 12.0),

                    // Bill Summary Card
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                        vertical: 4.0,
                      ),
                      padding: const EdgeInsets.all(AppDimensions.spacingMd),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Bill Details',
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),

                          // Item Subtotal
                          _buildSummaryRow(
                            'Item Subtotal',
                            '${cart.subtotal.toStringAsFixed(2)} $currency',
                          ),

                          // Discounts (if any)
                          if (totalSavings > 0) ...[
                            const SizedBox(height: 8.0),
                            _buildSummaryRow(
                              'Offer Discounts',
                              '-${totalSavings.toStringAsFixed(2)} $currency',
                              valueColor: const Color(0xFF16A34A),
                            ),
                          ],

                          const SizedBox(height: 8.0),
                          _buildSummaryRow(
                            'Delivery Partner Fee',
                            'Calculated at checkout',
                            valueColor: AppColors.textSecondary,
                            isSubtle: true,
                          ),

                          // Loyalty Points
                          if (cart.totalLoyaltyPoints > 0) ...[
                            const SizedBox(height: 8.0),
                            _buildSummaryRow(
                              'Loyalty Points Earned',
                              '+${cart.totalLoyaltyPoints} pts',
                              valueColor: const Color(0xFFB45309),
                            ),
                          ],

                          const SizedBox(height: 12.0),
                          const Divider(height: 1.0, color: Color(0xFFF3F4F6)),
                          const SizedBox(height: 10.0),

                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'To Pay',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${cart.subtotal.toStringAsFixed(2)} $currency',
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Rewards & Promo Info Note
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                        vertical: 10.0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 18.0,
                            color: Color(0xFF15803D),
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              'Coupons and loyalty points redemption can be applied during checkout.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF15803D),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16.0),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: CartSummaryBar(
            cart: cart,
            currency: currency,
            onProceed: () async {
              final repo =
                  orderRepository ??
                  CustomerScope.maybeOf(context)?.orderRepository;
              if (repo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Unable to initialize checkout. Please try again.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              await CheckoutBottomSheet.show(
                context,
                cart: cart,
                storeId: storeId,
                storeName: effectiveStoreName ?? cart.store.name,
                orderRepository: repo,
                currency: currency,
                onOrderSuccess: (order) async {
                  await cartNotifier.clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Order #${order.orderNumber ?? order.id} placed successfully!',
                        ),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  onOrderPlaced?.call(order);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerOrderTrackingScreen(
                          orderId: order.id,
                          initialOrder: order,
                          orderRepository: repo,
                          currency: currency,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isSubtle = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSubtle ? AppColors.textTertiary : AppColors.textSecondary,
            fontSize: 13.0,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}
