import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../cart/application/cart_notifier.dart';
import '../../domain/models/product_model.dart';
import 'customer_scope.dart';

/// Card widget presenting a single product in the Market catalog grid with shared cart integration.
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final String currency;
  final CartNotifier? cartNotifier;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.currency = AppConstants.defaultCurrency,
    this.cartNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveCartNotifier =
        cartNotifier ?? CustomerScope.maybeOf(context)?.cartNotifier;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(
          color: AppColors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image / Fallback Area
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.background,
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackImage(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
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
                        : _buildFallbackImage(),
                  ),

                  // Loyalty Points Badge
                  if (product.loyaltyPointsPerUnit > 0)
                    Positioned(
                      top: AppDimensions.spacingSm,
                      left: AppDimensions.spacingSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingSm,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              size: 12,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '+${product.loyaltyPointsPerUnit} pts',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Unavailable Dimmed Overlay
                  if (!product.isAvailable)
                    Container(
                      color: Colors.black.withAlpha(115),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacingSm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Text(
                            'Unavailable',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Details Area
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingSm + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.category != null && product.category!.isNotEmpty)
                          Text(
                            product.category!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          product.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            '${product.price.toStringAsFixed(2)} $currency',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (effectiveCartNotifier != null && product.isAvailable)
                          _buildCartControl(effectiveCartNotifier),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartControl(CartNotifier notifier) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final quantity = notifier.quantityForProduct(product.id);
        final isPending = notifier.isProductPending(product.id);

        if (isPending) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (quantity == 0) {
          return InkWell(
            key: Key('add_to_cart_${product.id}'),
            onTap: () => notifier.addItem(product.id, 1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    'Add',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                key: Key('cart_decrement_${product.id}'),
                onTap: () => notifier.setQuantity(product.id, quantity - 1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Icon(Icons.remove, size: 12, color: AppColors.textPrimary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Text(
                  '$quantity',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
              ),
              InkWell(
                key: Key('cart_increment_${product.id}'),
                onTap: () => notifier.setQuantity(product.id, quantity + 1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Icon(Icons.add, size: 12, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: AppColors.primaryLight.withAlpha(100),
      child: const Center(
        child: Icon(
          Icons.shopping_basket_outlined,
          color: AppColors.primaryDark,
          size: 32,
        ),
      ),
    );
  }
}
