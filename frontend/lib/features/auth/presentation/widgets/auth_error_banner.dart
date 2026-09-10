import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// User-facing error banner for authentication screens.
///
/// Maps domain failures to clear, friendly, and actionable messages without exposing
/// sensitive server internals or stack traces.
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  final AppFailure? failure;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const AuthErrorBanner({
    super.key,
    this.message,
    this.failure,
    this.onDismiss,
    this.onRetry,
  }) : assert(message != null || failure != null, 'Must provide either message or failure');

  String _resolveMessage() {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }

    final f = failure;
    if (f == null) return 'An unexpected error occurred. Please try again.';

    return switch (f) {
      UnauthorizedFailure() => f.message.isNotEmpty ? f.message : 'Invalid credentials. Please check your phone number and password.',
      ForbiddenFailure() => 'Access restricted. You do not have permission to access this portal.',
      ValidationFailure() => f.message.isNotEmpty ? f.message : 'Please correct the highlighted errors and try again.',
      ConflictFailure() => f.message.isNotEmpty ? f.message : 'An account with these details already exists.',
      RateLimitFailure() => 'Too many attempts. Please wait a moment before trying again.',
      NetworkFailure() => 'Network connection error. Please check your internet connection and try again.',
      ServerFailure() => 'Our servers are experiencing issues. Please try again shortly.',
      NotFoundFailure() => 'Resource not found. Please try again.',
      UnknownFailure() => f.message.isNotEmpty ? f.message : 'An unexpected error occurred. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final displayMessage = _resolveMessage();

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm + 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Red-50 tint
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: const Color(0xFFFCA5A5)), // Red-300
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              displayMessage,
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF991B1B), // Red-800
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (onRetry != null) ...[
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: AppColors.error,
              ),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
          if (onDismiss != null) ...[
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF991B1B)),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
              tooltip: 'Dismiss',
            ),
          ],
        ],
      ),
    );
  }
}
