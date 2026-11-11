import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_dimensions.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:flutter/material.dart';

/// Modern, production-quality summary bar docked at the bottom of the Cart screen.
class CartSummaryBar extends StatelessWidget {
  final CartModel cart;
  final String currency;
  final VoidCallback? onProceed;

  const CartSummaryBar({
    super.key,
    required this.cart,
    this.currency = AppConstants.defaultCurrency,
    this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnavailable = cart.hasUnavailableItems;

    // Calculate total savings across all cart items
    final totalSavings = cart.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.hasOffer ? item.totalSavings : 0.0),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: 12.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Savings strip if applicable
              if (totalSavings > 0 && !hasUnavailable) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  margin: const EdgeInsets.only(bottom: 10.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.discount_outlined,
                        size: 15.0,
                        color: Color(0xFF15803D),
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        'Total Discount Savings: ${totalSavings.toStringAsFixed(2)} $currency',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: const Color(0xFF15803D),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Main Action Row
              Row(
                children: [
                  // Left: Price & item count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Total (${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'})',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            if (cart.totalLoyaltyPoints > 0) ...[
                              const SizedBox(width: 6.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5.0,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  '+${cart.totalLoyaltyPoints} pts',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          '${cart.subtotal.toStringAsFixed(2)} $currency',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            fontSize: 20.0,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right: Proceed to Checkout Button
                  ElevatedButton(
                    key: const Key('cart_checkout_button'),
                    onPressed: hasUnavailable ? null : onProceed,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48.0),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22.0,
                        vertical: 14.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasUnavailable
                              ? 'Remove Unavailable Items'
                              : 'Proceed to Checkout',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: hasUnavailable
                                ? const Color(0xFF9CA3AF)
                                : Colors.white,
                          ),
                        ),
                        if (!hasUnavailable) ...[
                          const SizedBox(width: 6.0),
                          const Icon(Icons.arrow_forward_rounded, size: 18.0),
                        ],
                      ],
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
