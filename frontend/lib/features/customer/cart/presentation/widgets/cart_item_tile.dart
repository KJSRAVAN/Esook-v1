import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_dimensions.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:esouq/features/customer/cart/domain/cart_item_model.dart';
import 'package:flutter/material.dart';

/// Modern, production-quality list tile representing an item in the customer cart.
class CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final bool isPending;
  final String currency;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    this.isPending = false,
    this.currency = AppConstants.defaultCurrency,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = item.isAvailable;
    final hasOffer = item.hasOffer;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: isAvailable ? AppColors.surface : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isAvailable
              ? AppColors.borderSubtle
              : AppColors.error.withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: isAvailable
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8.0,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    width: 72.0,
                    height: 72.0,
                    color: const Color(0xFFF3F4F6),
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),

                // 2. Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        item.productName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: isAvailable
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4.0),

                      // Variant & Points Badges Row
                      Row(
                        children: [
                          if (item.variantName != null &&
                              item.variantName!.isNotEmpty &&
                              item.variantName!.toLowerCase() != 'default') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                item.variantName!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6.0),
                          ],
                          if (item.loyaltyPointsPerUnit > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    size: 11.0,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 2.0),
                                  Text(
                                    '+${item.loyaltyPointsPerUnit} pts',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6.0),

                      // Pricing Row
                      if (hasOffer) ...[
                        Row(
                          children: [
                            Text(
                              '${item.price.toStringAsFixed(2)} $currency',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626), // Bold red
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              '${item.regularPrice.toStringAsFixed(2)} $currency',
                              style: AppTextStyles.bodySmall.copyWith(
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.textTertiary,
                                color: AppColors.textTertiary,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                '-${item.discountPercent}%',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: const Color(0xFFDC2626),
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          '${item.price.toStringAsFixed(2)} $currency',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontSize: 14.0,
                          ),
                        ),
                      ],

                      if (!isAvailable) ...[
                        const SizedBox(height: 4.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            'Currently Unavailable',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12.0),
            const Divider(height: 1.0, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10.0),

            // Bottom Action Row: Subtotal & Quantity Stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Item Subtotal with savings notice
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Subtotal',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11.0,
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6.0,
                        children: [
                          Text(
                            '${item.itemSubtotal.toStringAsFixed(2)} $currency',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isAvailable
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                              fontSize: 15.0,
                            ),
                          ),
                          if (hasOffer && isAvailable)
                            Text(
                              'Saved ${item.totalSavings.toStringAsFixed(2)} $currency',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF16A34A),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),

                // Quantity Controls or Pending
                if (isPending)
                  const SizedBox(
                    width: 36.0,
                    height: 36.0,
                    child: Center(
                      child: SizedBox(
                        width: 18.0,
                        height: 18.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (!isAvailable)
                  IconButton(
                    key: Key('cart_remove_unavailable_${item.productId}'),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 22.0,
                    ),
                    onPressed: onRemove,
                    tooltip: 'Remove unavailable item',
                  )
                else
                  _QuantityStepper(
                    productId: item.productId,
                    quantity: item.quantity,
                    onDecrement: () => onQuantityChanged(item.quantity - 1),
                    onIncrement: () => onQuantityChanged(item.quantity + 1),
                    onRemove: onRemove,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return const Center(
      child: Icon(
        Icons.shopping_basket_outlined,
        color: AppColors.textTertiary,
        size: 30.0,
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final String productId;
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  const _QuantityStepper({
    this.productId = '',
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final canIncrement = quantity < 99;

    return Container(
      height: 36.0,
      constraints: const BoxConstraints(minWidth: 104.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('cart_qty_decrement'),
              onTap: quantity == 1 ? onRemove : onDecrement,
              borderRadius: BorderRadius.circular(16.0),
              child: SizedBox(
                width: 32.0,
                height: 32.0,
                child: Center(
                  child: Icon(
                    quantity == 1 ? Icons.delete_outline_rounded : Icons.remove,
                    size: 18.0,
                    color: quantity == 1 ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 26.0),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              '$quantity',
              key: const Key('cart_qty_value'),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: 14.0,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('cart_qty_increment'),
              onTap: canIncrement ? onIncrement : null,
              borderRadius: BorderRadius.circular(16.0),
              child: SizedBox(
                width: 32.0,
                height: 32.0,
                child: Center(
                  child: Icon(
                    Icons.add,
                    size: 18.0,
                    color: canIncrement ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
