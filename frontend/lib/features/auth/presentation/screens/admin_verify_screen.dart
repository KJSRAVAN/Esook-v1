import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/role_routing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';

/// Super Admin magic link verification handler screen (Step 2).
///
/// Automatically redeems token passed via route argument or deep-link query parameter.
class AdminVerifyScreen extends StatefulWidget {
  final String? token;
  final AuthRepository? authRepository;

  const AdminVerifyScreen({super.key, this.token, this.authRepository});

  @override
  State<AdminVerifyScreen> createState() => _AdminVerifyScreenState();
}

class _AdminVerifyScreenState extends State<AdminVerifyScreen> {
  bool _isVerifying = true;
  AppFailure? _failure;
  bool _isSuccess = false;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyToken());
  }

  Future<void> _verifyToken() async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      setState(() {
        _isVerifying = false;
        _failure = const ValidationFailure(
          message: 'No verification token was provided in the magic link.',
        );
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _failure = null;
    });

    final result = await _repository.verifyAdminMagicLink(token: token.trim());

    if (!mounted) return;

    if (result.isSuccess) {
      final authResponse = result.dataOrNull!;
      setState(() {
        _isVerifying = false;
        _isSuccess = true;
      });
      RoleRouting.navigateForRole(
        context,
        authResponse.user.role,
        clearStack: true,
      );
    } else {
      setState(() {
        _isVerifying = false;
        _failure = result.failureOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 480.0,
      headerBadge: _buildStatusBadge(),
      title: _buildTitle(),
      subtitle: _buildSubtitle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isVerifying) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: AppDimensions.spacingLg,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ] else if (_failure != null) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                children: [
                  Text(
                    _failure?.message ??
                        'Magic link is invalid or has expired.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF991B1B),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    'For security reasons, magic links are single-use and valid for 15 minutes only.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF7F1D1D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            AuthPrimaryButton(
              label: 'Request New Link',
              onPressed: () {
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.adminMagicLink);
              },
            ),
          ] else if (_isSuccess) ...[
            const Center(
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_isVerifying) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: const Icon(
          Icons.vpn_key_rounded,
          color: AppColors.primary,
          size: 32,
        ),
      );
    }

    if (_failure != null) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Icon(
          Icons.link_off_rounded,
          color: AppColors.error,
          size: 34,
        ),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: const Icon(
        Icons.verified_user_rounded,
        color: AppColors.primary,
        size: 34,
      ),
    );
  }

  String _buildTitle() {
    if (_isVerifying) return 'Verifying Link';
    if (_failure != null) return 'Link Expired or Invalid';
    return 'Authentication Successful';
  }

  String? _buildSubtitle() {
    if (_isVerifying) {
      return 'Please wait while we authenticate your administrator session';
    }
    if (_failure != null) {
      return 'This single-use login link is no longer valid';
    }
    return 'Redirecting to Super Admin Console...';
  }
}
