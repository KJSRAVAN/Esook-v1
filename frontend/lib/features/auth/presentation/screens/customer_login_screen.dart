import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/role_routing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';
import '../widgets/auth_text_field.dart';

/// Customer login step for phone-based OTP authentication flow.
enum CustomerLoginStep { phoneInput, otpVerification }

/// Customer login screen for eSOuQ using phone OTP authentication.
class CustomerLoginScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const CustomerLoginScreen({super.key, this.authRepository});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  CustomerLoginStep _step = CustomerLoginStep.phoneInput;
  bool _isSubmitting = false;
  AppFailure? _failure;
  String? _infoMessage;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp({bool isResend = false}) async {
    setState(() {
      _failure = null;
      if (!isResend) _infoMessage = null;
    });

    if (!isResend && !_phoneFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final phone = _phoneController.text.trim();

    final result = await _repository.sendOtp(phone: phone);

    if (!mounted) return;

    if (result.isSuccess) {
      final message = result.dataOrNull ?? 'Verification code sent';
      setState(() {
        _isSubmitting = false;
        _step = CustomerLoginStep.otpVerification;
        _infoMessage = message;
        _failure = null;
      });
    } else {
      setState(() {
        _isSubmitting = false;
        _failure = result.failureOrNull;
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() => _failure = null);

    if (!_otpFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final phone = _phoneController.text.trim();
    final code = _otpController.text.trim();

    final result = await _repository.verifyOtp(phone: phone, code: code);

    if (!mounted) return;

    if (result.isSuccess) {
      final authResponse = result.dataOrNull!;
      setState(() => _isSubmitting = false);
      RoleRouting.navigateForRole(
        context,
        authResponse.user.role,
        clearStack: true,
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _failure = result.failureOrNull;
      });
    }
  }

  void _handleChangePhone() {
    setState(() {
      _step = CustomerLoginStep.phoneInput;
      _otpController.clear();
      _failure = null;
      _infoMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneStep = _step == CustomerLoginStep.phoneInput;

    return AuthScaffold(
      title: isPhoneStep ? 'Welcome Back' : 'Verify Code',
      subtitle: isPhoneStep
          ? 'Sign in to continue ordering fresh groceries'
          : 'Enter the 6-digit code sent to ${_phoneController.text.trim()}',
      bottomNavigation: _buildBottomLinks(context),
      child: isPhoneStep ? _buildPhoneForm() : _buildOtpForm(),
    );
  }

  Widget _buildPhoneForm() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Backend / Network Error Banner
          if (_failure != null)
            AuthErrorBanner(
              failure: _failure,
              onDismiss: () => setState(() => _failure = null),
              onRetry: _failure is NetworkFailure
                  ? () => _handleSendOtp()
                  : null,
            ),

          // Phone Number Field
          AuthTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hintText: '+966 50 123 4567',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            enabled: !_isSubmitting,
            onFieldSubmitted: (_) => _handleSendOtp(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.trim().length < 8) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacingLg),

          // Primary Send OTP CTA Button
          AuthPrimaryButton(
            label: 'Send OTP',
            isLoading: _isSubmitting,
            onPressed: () => _handleSendOtp(),
          ),

          const SizedBox(height: AppDimensions.spacingLg),

          // Navigation to Signup
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account?",
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        Navigator.of(context).pushNamed(AppRoutes.signup);
                      },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpForm() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Backend / Network Error Banner
          if (_failure != null)
            AuthErrorBanner(
              failure: _failure,
              onDismiss: () => setState(() => _failure = null),
              onRetry: _failure is NetworkFailure ? _handleVerifyOtp : null,
            ),

          // Status / Channel Banner
          if (_infoMessage != null && _failure == null)
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: Text(
                      _infoMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 6-Digit OTP Field
          AuthTextField(
            key: const Key('otp_code_field'),
            controller: _otpController,
            label: '6-Digit OTP Code',
            hintText: '123456',
            prefixIcon: Icons.security_rounded,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enabled: !_isSubmitting,
            onFieldSubmitted: (_) => _handleVerifyOtp(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the 6-digit OTP code';
              }
              final clean = value.trim();
              if (clean.length != 6 || !RegExp(r'^\d{6}$').hasMatch(clean)) {
                return 'OTP must be exactly 6 digits';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacingLg),

          // Primary Verify CTA Button
          AuthPrimaryButton(
            key: const Key('verify_otp_button'),
            label: 'Verify & Sign In',
            isLoading: _isSubmitting,
            onPressed: _handleVerifyOtp,
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Secondary Actions: Change Phone & Resend Code
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _isSubmitting ? null : _handleChangePhone,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Change Phone'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              TextButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _handleSendOtp(isResend: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Resend Code'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLinks(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: AppDimensions.spacingMd),
        Text(
          'Looking for a partner or staff portal?',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppDimensions.spacingSm,
          children: [
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pushNamed(AppRoutes.staffLogin),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Store Staff'),
            ),
            const Text('•', style: TextStyle(color: AppColors.borderStrong)),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pushNamed(AppRoutes.riderLogin),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Delivery Rider'),
            ),
            const Text('•', style: TextStyle(color: AppColors.borderStrong)),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.adminMagicLink),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Admin'),
            ),
          ],
        ),
        if (kDebugMode) ...[
          const SizedBox(height: AppDimensions.spacingMd),
          OutlinedButton.icon(
            key: const Key('dev_customer_preview_button'),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.devCustomerPreview),
            icon: const Icon(Icons.preview_rounded, size: 18),
            label: const Text('Developer Preview: Customer Shell'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primary, width: 1),
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}
