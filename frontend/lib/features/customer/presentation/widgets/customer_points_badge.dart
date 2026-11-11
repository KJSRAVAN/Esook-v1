import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/points_notifier.dart';
import 'customer_scope.dart';

/// Compact top-right loyalty points badge for authenticated customers.
///
/// Tapping the badge opens a lightweight details dialog showing current balance
/// and redemption policy.
class CustomerPointsBadge extends StatelessWidget {
  final PointsNotifier? pointsNotifier;
  final String currency;

  const CustomerPointsBadge({
    super.key,
    this.pointsNotifier,
    this.currency = AppConstants.defaultCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = pointsNotifier ?? CustomerScope.pointsNotifierOf(context);

    if (notifier == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('customer_points_badge'),
                onTap: () => _showPointsDetails(context, notifier),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7), // Warm amber background
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusFull,
                    ),
                    border: Border.all(
                      color: const Color(0xFFFDE68A),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        size: 14.0,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4.0),
                      if (notifier.isLoading && notifier.pointsInfo == null)
                        const SizedBox(
                          width: 10.0,
                          height: 10.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFD97706),
                            ),
                          ),
                        )
                      else
                        Text(
                          '${notifier.balance} pts',
                          key: const Key('customer_points_badge_text'),
                          style: const TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                            letterSpacing: -0.2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPointsDetails(BuildContext context, PointsNotifier notifier) {
    final info = notifier.pointsInfo;
    final balance = notifier.balance;
    final monetaryVal = info?.monetaryValue ?? 0.0;
    final rate = info?.pointsPerCurrencyUnit ?? 0.10;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          key: const Key('customer_points_detail_dialog'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFD97706),
                    size: 36.0,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  'Loyalty Points',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  '$balance points',
                  key: const Key('dialog_points_balance_text'),
                  style: const TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    'Worth ${monetaryVal.toStringAsFixed(2)} $currency (1 pt = ${rate.toStringAsFixed(2)} $currency)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppDimensions.spacingMd),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    'Earn points on eligible purchases and redeem them during checkout for an instant discount on your order payable total.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('dialog_points_close_btn'),
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
