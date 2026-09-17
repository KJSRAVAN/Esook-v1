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
import 'package:esouq/features/customer/presentation/widgets/checkout_bottom_sheet.dart';
import 'package:esouq/features/customer/presentation/widgets/customer_scope.dart';
import 'package:flutter/material.dart';

/// Screen presenting the authenticated customer's store-scoped cart.
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
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: const Text('Clear Cart?'),
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
        final storeId = cartNotifier.currentStoreId;

        // 1. No store selected state
        if (storeId == null || storeId.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Cart'),
              centerTitle: false,
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
            appBar: AppBar(
              title: const Text('My Cart'),
              centerTitle: false,
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
            appBar: AppBar(
              title: const Text('My Cart'),
              centerTitle: false,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48.0, color: AppColors.error),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      'Unable to load cart',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      error.message,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    ElevatedButton.icon(
                      key: const Key('cart_error_retry_button'),
                      onPressed: () => cartNotifier.loadForStore(storeId),
                      icon: const Icon(Icons.refresh, size: 18.0),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Cart'),
                  if (storeName != null)
                    Text(
                      storeName!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.0,
                      ),
                    ),
                ],
              ),
              centerTitle: false,
            ),
            body: CartEmptyState(
              storeName: storeName,
              onExploreMarket: onExploreMarket,
            ),
          );
        }

        // 5. Populated cart state
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Cart'),
                Text(
                  storeName ?? cart.store.name,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                  ),
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
                icon: const Icon(Icons.delete_sweep_outlined, size: 18.0, color: AppColors.error),
                label: Text(
                  'Clear',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (cart.hasUnavailableItems) const CartUnavailableBanner(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return CartItemTile(
                      key: Key('cart_item_tile_${item.productId}'),
                      item: item,
                      isPending: cartNotifier.isProductPending(item.productId),
                      currency: currency,
                      onQuantityChanged: (newQty) =>
                          cartNotifier.setQuantity(item.productId, newQty),
                      onRemove: () => cartNotifier.removeItem(item.productId),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: CartSummaryBar(
            cart: cart,
            currency: currency,
            onProceed: () async {
              final repo = orderRepository ?? CustomerScope.maybeOf(context)?.orderRepository;
              if (repo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to initialize checkout. Please try again.'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              await CheckoutBottomSheet.show(
                context,
                cart: cart,
                storeName: storeName ?? cart.store.name,
                orderRepository: repo,
                currency: currency,
                onOrderSuccess: (order) async {
                  final sid = cart.storeId ?? cart.store.id;
                  if (sid.isNotEmpty) {
                    await cartNotifier.loadForStore(sid);
                  } else {
                    await cartNotifier.clear();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order #${order.orderNumber ?? order.id} placed successfully!'),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  onOrderPlaced?.call(order);
                },
              );
            },
          ),
        );
      },
    );
  }
}
