import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/auth_phone_helper.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';
import '../widgets/auth_text_field.dart';

/// Customer registration screen for eSOuQ aligned with the production email/password contract.
///
/// Collects name, email, phone, and password against `POST /auth/customer/signup`.
class CustomerSignupScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const CustomerSignupScreen({super.key, this.authRepository});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  AppFailure? _failure;
  String? _successMessage;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    setState(() {
      _failure = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone =
        AuthPhoneHelper.normalizeAuthPhone(_phoneController.text) ??
        _phoneController.text.trim();
    final password = _passwordController.text;

    final result = await _repository.signupCustomer(
      fullName: fullName,
      email: email,
      phoneNumber: phone,
      password: password,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final message =
          result.dataOrNull ?? 'Account created successfully. You can now log in.';
      setState(() {
        _isSubmitting = false;
        _successMessage = message;
        _failure = null;
      });
    } else {
      setState(() {
        _isSubmitting = false;
        _failure = result.failureOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create Account',
      subtitle: 'Join eSOuQ for fast delivery of fresh essentials',
      showBackButton: true,
      onBackPressed: () => Navigator.of(context).maybePop(),
      bottomNavigation: _buildBottomSignInLink(context),
      child: _successMessage != null
          ? _buildSuccessConfirmation()
          : _buildSignupForm(),
    );
  }

  Widget _buildSuccessConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.primaryDark,
                size: 48,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'Account Created!',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                _successMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        AuthPrimaryButton(
          key: const Key('signup_proceed_to_login_button'),
          label: 'Proceed to Sign In',
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          },
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Backend / Network Error Banner
          if (_failure != null)
            AuthErrorBanner(
              failure: _failure,
              onDismiss: () => setState(() => _failure = null),
              onRetry: _failure is NetworkFailure ? _handleSignup : null,
            ),

          // Full Name Field
          AuthTextField(
            key: const Key('signup_name_field'),
            controller: _fullNameController,
            label: 'Full Name',
            hintText: 'Ahmed Ali',
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
            validator: (value) => AuthPhoneHelper.validateAuthPhone(
              value,
              requiredMessage: 'Please enter your phone number',
            ),
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Email Address Field
          AuthTextField(
            key: const Key('signup_email_field'),
            controller: _emailController,
            label: 'Email Address',
            hintText: 'ahmed@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_isSubmitting,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              final email = value.trim();
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(email)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Password Field
          AuthPasswordField(
            key: const Key('signup_password_field'),
            controller: _passwordController,
            label: 'Password',
            hintText: 'At least 8 characters',
            textInputAction: TextInputAction.done,
            enabled: !_isSubmitting,
            onFieldSubmitted: (_) => _handleSignup(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: AppDimensions.spacingLg),

          // Primary Signup CTA Button
          AuthPrimaryButton(
            key: const Key('signup_submit_button'),
            label: 'Create Account',
            isLoading: _isSubmitting,
            onPressed: _handleSignup,
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
          key: const Key('signup_to_login_button'),
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
