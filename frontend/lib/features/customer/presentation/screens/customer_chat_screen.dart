import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Professional, polished "Coming Soon" screen for the Customer Support & Store Chat section.
class CustomerChatScreen extends StatelessWidget {
  final VoidCallback? onBackToMarket;

  const CustomerChatScreen({super.key, this.onBackToMarket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Customer Support',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: onBackToMarket != null
            ? IconButton(
                key: const Key('chat_back_button'),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                tooltip: 'Back to Market',
                onPressed: onBackToMarket,
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    key: const Key('chat_back_button'),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXl,
              vertical: AppDimensions.spacingLg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated / Stylized Icon Container
                  Container(
                    width: 110.0,
                    height: 110.0,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDCFCE7), Color(0xFFE0F2FE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          blurRadius: 28.0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.mark_chat_unread_rounded,
                            size: 50.0,
                            color: AppColors.primary,
                          ),
                          Positioned(
                            top: 26,
                            right: 24,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28.0),

                  // Pill Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 5.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14.0,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 5.0),
                        Text(
                          'FEATURE IN PROGRESS',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16.0),

                  // Heading
                  Text(
                    'Chat Coming Soon',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 24.0,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10.0),

                  // Description
                  Text(
                    'We are currently preparing real-time customer support chat. Soon, you will be able to message store staff directly about order substitutions, request special grocery items, and communicate with your delivery rider.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14.0,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30.0),

                  // Upcoming Capabilities Card
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WHAT TO EXPECT',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontSize: 11.0,
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        _buildFeatureRow(
                          icon: Icons.support_agent_rounded,
                          title: 'Live Store Staff Support',
                          subtitle: 'Direct answers on product availability and substitutions.',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1.0, color: Color(0xFFF3F4F6)),
                        ),
                        _buildFeatureRow(
                          icon: Icons.delivery_dining_rounded,
                          title: 'Rider In-App Communication',
                          subtitle: 'Coordinate drop-off location and delivery updates effortlessly.',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1.0, color: Color(0xFFF3F4F6)),
                        ),
                        _buildFeatureRow(
                          icon: Icons.bolt_rounded,
                          title: 'Instant Resolution',
                          subtitle: 'No phone hold times — fast help right inside the app.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32.0),

                  // Return CTA Button
                  if (onBackToMarket != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50.0,
                      child: ElevatedButton.icon(
                        key: const Key('chat_return_to_market_btn'),
                        onPressed: onBackToMarket,
                        icon: const Icon(Icons.storefront_rounded, size: 19.0),
                        label: const Text(
                          'Continue Shopping',
                          style: TextStyle(
                            fontSize: 15.0,
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
                  ] else if (Navigator.of(context).canPop()) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50.0,
                      child: ElevatedButton.icon(
                        key: const Key('chat_return_to_market_btn'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 19.0),
                        label: const Text(
                          'Back to Market',
                          style: TextStyle(
                            fontSize: 15.0,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7.0),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, size: 17.0, color: AppColors.primary),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.0,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
