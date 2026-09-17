import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// Screen displayed when an authenticated Staff or Manager user has no assigned store.
class StoreAssignmentRequiredScreen extends StatelessWidget {
  final AuthRepository authRepository;

  const StoreAssignmentRequiredScreen({
    super.key,
    required this.authRepository,
  });

  Future<void> _handleLogout(BuildContext context) async {
    await authRepository.logout();
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
        title: const Text('Store Operations'),
        actions: [
          IconButton(
            key: const Key('store_unassigned_logout_button'),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: const Icon(
                        Icons.store_mall_directory_outlined,
                        color: Color(0xFFD97706),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      'Store Assignment Required',
                      style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      'Your staff account is not currently assigned to a supermarket location. Please contact your system administrator to configure your store assignment.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    ElevatedButton.icon(
                      key: const Key('store_unassigned_signout_btn'),
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
