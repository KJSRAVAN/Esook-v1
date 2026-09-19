import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_dimensions.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Empty state widget for customer cart.
class CartEmptyState extends StatelessWidget {
  final String? storeName;
  final VoidCallback? onExploreMarket;

  const CartEmptyState({super.key, this.storeName, this.onExploreMarket});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingXl),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                size: 56.0,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Your Cart is Empty',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              storeName != null
                  ? 'Discover fresh groceries and essentials from $storeName and add them to your cart.'
                  : 'Select a supermarket and add items to your cart to get started.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onExploreMarket != null) ...[
              const SizedBox(height: AppDimensions.spacingLg),
              ElevatedButton.icon(
                key: const Key('cart_explore_market_button'),
                onPressed: onExploreMarket,
                icon: const Icon(Icons.storefront_outlined, size: 18.0),
                label: const Text('Explore Market'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingLg,
                    vertical: AppDimensions.spacingSm + 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
