import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_dimensions.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Modern, production-quality empty state widget for customer cart.
class CartEmptyState extends StatelessWidget {
  final String? storeName;
  final VoidCallback? onExploreMarket;

  const CartEmptyState({super.key, this.storeName, this.onExploreMarket});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingXl,
          vertical: AppDimensions.spacingLg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero Illustration Container
              Container(
                width: 120.0,
                height: 120.0,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 24.0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 54.0,
                        color: AppColors.primary,
                      ),
                      Positioned(
                        right: 28,
                        bottom: 28,
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            size: 14.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28.0),

              // Title
              Text(
                'Your Cart is Empty',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22.0,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10.0),

              // Description
              Text(
                storeName != null
                    ? 'Discover fresh groceries, fresh produce, and daily essentials from $storeName and add them to your cart.'
                    : 'Choose your neighborhood supermarket and add items to your cart to enjoy fast home delivery.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14.0,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28.0),

              // Feature Highlights Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFeatureItem(Icons.bolt_rounded, 'Fast Delivery'),
                    _buildFeatureDivider(),
                    _buildFeatureItem(Icons.verified_outlined, 'Best Prices'),
                    _buildFeatureDivider(),
                    _buildFeatureItem(Icons.stars_rounded, 'Earn Points'),
                  ],
                ),
              ),
              const SizedBox(height: 32.0),

              // Primary Action
              if (onExploreMarket != null)
                SizedBox(
                  width: double.infinity,
                  height: 50.0,
                  child: ElevatedButton.icon(
                    key: const Key('cart_explore_market_button'),
                    onPressed: onExploreMarket,
                    icon: const Icon(Icons.storefront_rounded, size: 20.0),
                    label: const Text(
                      'Explore Market',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20.0, color: AppColors.primaryDark),
          const SizedBox(height: 4.0),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDivider() {
    return Container(
      width: 1.0,
      height: 24.0,
      color: const Color(0xFFE5E7EB),
    );
  }
}
