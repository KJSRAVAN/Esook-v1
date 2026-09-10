import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/widgets/auth_scope.dart';

/// Minimal production-structured entry point for the Customer Account section.
///
/// Features a logout action that cleanly invokes session invalidation via [AuthRepository]
/// and navigates back to the customer login screen.
class CustomerAccountScreen extends StatelessWidget {
  final AuthRepository? authRepository;

  const CustomerAccountScreen({
    super.key,
    this.authRepository,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final repository = authRepository ?? AuthScope.of(context);
    await repository.logout();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingXl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 36,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingMd),
                          const Text(
                            'Customer Account',
                            style: AppTextStyles.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.spacingSm),
                          Text(
                            'Profile settings, addresses, payment options, points, and credit management will be available here.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  OutlinedButton.icon(
                    key: const Key('account_signout_button'),
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
