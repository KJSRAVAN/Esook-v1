import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../cart/application/cart_notifier.dart';
import '../../domain/models/product_model.dart';
import 'customer_scope.dart';

/// Modal bottom sheet displaying granular product details and cart interaction.
class ProductDetailSheet extends StatelessWidget {
  final ProductModel product;
  final CartNotifier? cartNotifier;
  final String currency;

  const ProductDetailSheet({
    super.key,
    required this.product,
    this.cartNotifier,
    this.currency = AppConstants.defaultCurrency,
  });

  /// Displays the [ProductDetailSheet] as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required ProductModel product,
    CartNotifier? cartNotifier,
    String currency = AppConstants.defaultCurrency,
  }) {
    final effectiveCartNotifier =
        cartNotifier ?? CustomerScope.maybeOf(context)?.cartNotifier;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductDetailSheet(
        product: product,
        cartNotifier: effectiveCartNotifier,
        currency: currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final effectiveCartNotifier =
        cartNotifier ?? CustomerScope.maybeOf(context)?.cartNotifier;

    return Container(
      key: const Key('product_detail_sheet'),
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle & Close Bar
            SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8.0,
                    child: IconButton(
                      key: const Key('detail_close_button'),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image Area
                    _buildImageArea(),

                    const SizedBox(height: AppDimensions.spacingMd),

                    // Category & Availability Chips Row
                    Row(
                      children: [
                        if (product.category != null &&
                            product.category!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.spacingSm,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Text(
                              product.category!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                        ],
                        _buildAvailabilityBadge(),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.spacingSm),

                    // Product Name
                    Text(
                      product.name,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: AppDimensions.spacingSm),

                    // Price Display
                    Text(
                      '${product.price.toStringAsFixed(2)} $currency',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),

                    // Description Section
                    if (product.description != null &&
                        product.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingMd),
                      const Divider(color: AppColors.borderSubtle),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        'Description',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        product.description!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],

                    const SizedBox(height: AppDimensions.spacingLg),
                  ],
                ),
              ),
            ),

            // Bottom Action Area (Cart Integration)
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle, width: 1.0),
                ),
              ),
              child: _buildBottomActionBar(context, effectiveCartNotifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
            Image.network(
              product.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackImage(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            )
          else
            _buildFallbackImage(),

          // Loyalty Points Badge
          if (product.loyaltyPointsPerUnit > 0)
            Positioned(
              top: AppDimensions.spacingSm,
              left: AppDimensions.spacingSm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingSm,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  border: Border.all(color: AppColors.primary.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '+${product.loyaltyPointsPerUnit} pts',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Unavailable Dimmed Overlay
          if (!product.isAvailable)
            Container(
              color: Colors.black.withAlpha(110),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMd,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(
                    'Unavailable',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: AppColors.primaryLight.withAlpha(100),
      child: const Center(
        child: Icon(
          Icons.shopping_basket_outlined,
          color: AppColors.primaryDark,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge() {
    final isAvailable = product.isAvailable;
    final color = isAvailable ? AppColors.success : AppColors.error;
    final label = isAvailable ? 'In Stock' : 'Out of Stock';

    return Container(
      key: isAvailable ? null : const Key('detail_out_of_stock_badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    CartNotifier? effectiveCartNotifier,
  ) {
    if (!product.isAvailable) {
      return SizedBox(
        width: double.infinity,
        height: AppDimensions.buttonHeight,
        child: ElevatedButton(
          key: const Key('detail_unavailable_button'),
          onPressed: null,
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: AppColors.borderSubtle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
          child: Text(
            'Currently Unavailable',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (effectiveCartNotifier == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: effectiveCartNotifier,
      builder: (context, _) {
        final quantity = effectiveCartNotifier.quantityForProduct(product.id);
        final isPending = effectiveCartNotifier.isProductPending(product.id);

        if (quantity == 0) {
          return SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton.icon(
              key: const Key('detail_add_to_cart_button'),
              onPressed: isPending
                  ? null
                  : () async {
                      await effectiveCartNotifier.addItem(product.id, 1);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "${product.name}" to cart'),
                            backgroundColor: AppColors.success,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              icon: isPending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add_shopping_cart, size: 20),
              label: Text(
                isPending
                    ? 'Adding...'
                    : 'Add to Cart — ${product.price.toStringAsFixed(2)} $currency',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'In Cart',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(product.price * quantity).toStringAsFixed(2)} $currency',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('detail_cart_decrement'),
                    onPressed: isPending
                        ? null
                        : () => effectiveCartNotifier.setQuantity(
                            product.id,
                            quantity - 1,
                          ),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.primary,
                    iconSize: 28,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    child: isPending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          )
                        : Text(
                            '$quantity',
                            key: const Key('detail_cart_quantity'),
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  IconButton(
                    key: const Key('detail_cart_increment'),
                    onPressed: isPending
                        ? null
                        : () => effectiveCartNotifier.setQuantity(
                            product.id,
                            quantity + 1,
                          ),
                    icon: const Icon(Icons.add_circle),
                    color: AppColors.primary,
                    iconSize: 28,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
