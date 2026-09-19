import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_dimensions.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:esouq/features/customer/cart/domain/cart_item_model.dart';
import 'package:flutter/material.dart';

/// List tile representing a single item in the customer cart.
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

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingXs,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(
          color: isAvailable
              ? AppColors.borderSubtle
              : AppColors.error.withAlpha(80),
          width: 1.0,
        ),
      ),
      color: isAvailable ? AppColors.surface : AppColors.surface.withAlpha(200),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingSm + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product Image / Fallback
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              child: Container(
                width: 64.0,
                height: 64.0,
                color: AppColors.background,
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

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isAvailable
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),
                  Row(
                    children: [
                      Text(
                        '${item.unitPrice.toStringAsFixed(2)} $currency',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.loyaltyPointsPerUnit > 0) ...[
                        const SizedBox(width: AppDimensions.spacingXs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5.0,
                            vertical: 1.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusXs,
                            ),
                          ),
                          child: Text(
                            '+${item.loyaltyPointsPerUnit} pts',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  if (!isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(25),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusXs,
                        ),
                      ),
                      child: Text(
                        'Currently Unavailable',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${item.itemSubtotal.toStringAsFixed(2)} $currency',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),

            // Quantity Stepper or Pending Indicator
            if (isPending)
              const SizedBox(
                width: 32.0,
                height: 32.0,
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
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 22.0,
                ),
                onPressed: onRemove,
                tooltip: 'Remove unavailable item',
              )
            else
              _QuantityStepper(
                quantity: item.quantity,
                onDecrement: () => onQuantityChanged(item.quantity - 1),
                onIncrement: () => onQuantityChanged(item.quantity + 1),
                onRemove: onRemove,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return const Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        color: AppColors.textTertiary,
        size: 28.0,
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  const _QuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('cart_qty_decrement'),
            icon: Icon(
              quantity == 1 ? Icons.delete_outline : Icons.remove,
              size: 16.0,
              color: quantity == 1 ? AppColors.error : AppColors.textPrimary,
            ),
            padding: const EdgeInsets.all(4.0),
            constraints: const BoxConstraints(minWidth: 30.0, minHeight: 30.0),
            onPressed: quantity == 1 ? onRemove : onDecrement,
            tooltip: quantity == 1 ? 'Remove from cart' : 'Decrease quantity',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              '$quantity',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            key: const Key('cart_qty_increment'),
            icon: const Icon(
              Icons.add,
              size: 16.0,
              color: AppColors.textPrimary,
            ),
            padding: const EdgeInsets.all(4.0),
            constraints: const BoxConstraints(minWidth: 30.0, minHeight: 30.0),
            onPressed: onIncrement,
            tooltip: 'Increase quantity',
          ),
        ],
      ),
    );
  }
}
