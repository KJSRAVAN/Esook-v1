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

/// Customer signup step for OTP registration flow.
enum CustomerSignupStep { detailsInput, otpVerification }

/// Customer registration screen for eSOuQ aligned with the OTP authentication architecture.
class CustomerSignupScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const CustomerSignupScreen({super.key, this.authRepository});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _detailsFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  CustomerSignupStep _step = CustomerSignupStep.detailsInput;
  bool _isSubmitting = false;
  AppFailure? _failure;
  String? _infoMessage;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp({bool isResend = false}) async {
    setState(() {
      _failure = null;
      if (!isResend) _infoMessage = null;
    });

    if (!isResend && !_detailsFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    final result = await _repository.sendOtp(
      phone: phone,
      email: email.isNotEmpty ? email : null,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final message = result.dataOrNull ?? 'Verification code sent';
      setState(() {
        _isSubmitting = false;
        _step = CustomerSignupStep.otpVerification;
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
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();

    // 1. Verify OTP with phone + code (strictly passwordless OTP challenge)
    final verifyResult = await _repository.verifyOtp(phone: phone, code: code);

    if (!mounted) return;

    if (verifyResult.isFailure) {
      setState(() {
        _isSubmitting = false;
        _failure = verifyResult.failureOrNull;
      });
      return;
    }

    final authResponse = verifyResult.dataOrNull!;

    // 2. Persist real customer profile (name + optional backup email) via PATCH /users/me
    final profileResult = await _repository.updateProfile(
      name: fullName,
      email: email.isNotEmpty ? email : null,
    );

    if (!mounted) return;

    if (profileResult.isFailure) {
      setState(() {
        _isSubmitting = false;
        _failure = profileResult.failureOrNull ??
            const ServerFailure(
              message: 'Failed to save customer profile. Please try again.',
            );
      });
      return;
    }

    // 3. Navigate to Customer Home on successful completion
    setState(() => _isSubmitting = false);
    RoleRouting.navigateForRole(
      context,
      authResponse.user.role,
      clearStack: true,
    );
  }

  void _handleChangeDetails() {
    setState(() {
      _step = CustomerSignupStep.detailsInput;
      _otpController.clear();
      _failure = null;
      _infoMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDetailsStep = _step == CustomerSignupStep.detailsInput;

    return AuthScaffold(
      title: isDetailsStep ? 'Create Account' : 'Verify Code',
      subtitle: isDetailsStep
          ? 'Join eSOuQ for fast delivery of fresh essentials'
          : 'Enter the 6-digit code sent to ${_phoneController.text.trim()}',
      showBackButton: true,
      onBackPressed: isDetailsStep
          ? () => Navigator.of(context).maybePop()
          : _handleChangeDetails,
      bottomNavigation: isDetailsStep ? _buildBottomSignInLink(context) : null,
      child: isDetailsStep ? _buildDetailsForm() : _buildOtpForm(),
    );
  }

  Widget _buildDetailsForm() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Backend / Validation Error Banner
          if (_failure != null)
            AuthErrorBanner(
              failure: _failure,
              onDismiss: () => setState(() => _failure = null),
              onRetry: _failure is NetworkFailure
                  ? () => _handleSendOtp()
                  : null,
            ),

          // Full Name Field
          AuthTextField(
            key: const Key('signup_name_field'),
            controller: _fullNameController,
            label: 'Full Name',
            hintText: 'Ahmed Al-Harthy',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            enabled: !_isSubmitting,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Phone Number Field
          AuthTextField(
            key: const Key('signup_phone_field'),
            controller: _phoneController,
            label: 'Phone Number',
            hintText: '+966 50 123 4567',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !_isSubmitting,
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

          const SizedBox(height: AppDimensions.spacingMd),

          // Optional Email Field (Backup OTP delivery)
          AuthTextField(
            key: const Key('signup_email_field'),
            controller: _emailController,
            label: 'Email Address (optional)',
            hintText: 'Used as backup OTP delivery',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !_isSubmitting,
            onFieldSubmitted: (_) => _handleSendOtp(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              }
              final email = value.trim();
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(email)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacingLg),

          // Primary Signup CTA Button
          AuthPrimaryButton(
            label: 'Create Account',
            isLoading: _isSubmitting,
            onPressed: () => _handleSendOtp(),
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
            label: 'Verify & Continue',
            isLoading: _isSubmitting,
            onPressed: _handleVerifyOtp,
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Secondary actions: Edit Details & Resend Code
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _isSubmitting ? null : _handleChangeDetails,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Details'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              TextButton.icon(
                onPressed:
                    _isSubmitting ? null : () => _handleSendOtp(isResend: true),
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

  Widget _buildBottomSignInLink(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text(
            'Sign In',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
