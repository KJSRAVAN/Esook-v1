import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';

/// Super Admin pending screen (displays "Check your email" with throttled resend).
class AdminMagicLinkPendingScreen extends StatefulWidget {
  final String email;
  final AuthRepository? authRepository;

  const AdminMagicLinkPendingScreen({
    super.key,
    required this.email,
    this.authRepository,
  });

  @override
  State<AdminMagicLinkPendingScreen> createState() =>
      _AdminMagicLinkPendingScreenState();
}

class _AdminMagicLinkPendingScreenState
    extends State<AdminMagicLinkPendingScreen> {
  static const int _resendCooldownSeconds = 30;
  int _cooldownRemaining = _resendCooldownSeconds;
  Timer? _timer;

  bool _isResending = false;
  AppFailure? _failure;
  String? _successNotification;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownRemaining = _resendCooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownRemaining > 1) {
        setState(() => _cooldownRemaining--);
      } else {
        setState(() => _cooldownRemaining = 0);
        timer.cancel();
      }
    });
  }

  Future<void> _handleResend() async {
    if (_cooldownRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _failure = null;
      _successNotification = null;
    });

    final result = await _repository.requestAdminMagicLink(email: widget.email);

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _isResending = false;
        _successNotification = 'A fresh login link has been sent to your email.';
      });
      _startCooldown();
    } else {
      setState(() {
        _isResending = false;
        _failure = result.failureOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 480.0,
      showBackButton: true,
      onBackPressed: () =>
          Navigator.of(context).pushReplacementNamed(AppRoutes.adminMagicLink),
      headerBadge: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Icon(
          Icons.mark_email_read_rounded,
          color: AppColors.primary,
          size: 34,
        ),
      ),
      title: 'Check Your Email',
      subtitle: 'We sent a secure single-use login link to your inbox',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error or Success Banner
          if (_failure != null)
            AuthErrorBanner(
              failure: _failure,
              onDismiss: () => setState(() => _failure = null),
            ),

          if (_successNotification != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
              padding: const EdgeInsets.all(AppDimensions.spacingSm + 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: Text(
                      _successNotification!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: const Color(0xFF065F46),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Recipient Email Card
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                Text(
                  'Sent to:',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'Click the link in the email to automatically sign in to the Super Admin console. The link expires in 15 minutes.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacingLg),

          // Throttled Resend Action
          SizedBox(
            height: AppDimensions.buttonHeight,
            child: OutlinedButton(
              onPressed: _cooldownRemaining > 0 || _isResending ? null : _handleResend,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _cooldownRemaining > 0 ? AppColors.borderSubtle : AppColors.primary,
                ),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
              child: _isResending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _cooldownRemaining > 0
                          ? 'Resend Link in ${_cooldownRemaining}s'
                          : 'Resend Login Link',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: _cooldownRemaining > 0
                            ? AppColors.textTertiary
                            : AppColors.primary,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Return to change email
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(AppRoutes.adminMagicLink);
            },
            child: const Text('Use a different email address'),
          ),
        ],
      ),
    );
  }
}
