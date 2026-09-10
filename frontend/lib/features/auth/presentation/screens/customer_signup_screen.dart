import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/role_routing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';
import '../widgets/auth_text_field.dart';

/// Customer self-registration screen for eSOuQ.
class CustomerSignupScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const CustomerSignupScreen({
    super.key,
    this.authRepository,
  });

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isSubmitting = false;
  AppFailure? _failure;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    setState(() => _failure = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final address = _addressController.text.trim();

    final result = await _repository.signupCustomer(
      phoneNumber: phone,
      fullName: fullName,
      password: password,
      address: address.isNotEmpty ? address : null,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final authResponse = result.dataOrNull!;
      setState(() => _isSubmitting = false);
      RoleRouting.navigateForRole(context, authResponse.user.role, clearStack: true);
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Backend / Validation Error Banner
            if (_failure != null)
              AuthErrorBanner(
                failure: _failure,
                onDismiss: () => setState(() => _failure = null),
                onRetry: _failure is NetworkFailure ? _handleSignup : null,
              ),

            // Full Name Field
            AuthTextField(
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
              controller: _phoneController,
              label: 'Phone Number',
              hintText: '+968 9123 4567',
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

            // Password Field (Backend strictly requires >= 8 characters)
            AuthPasswordField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Minimum 8 characters',
              textInputAction: TextInputAction.next,
              enabled: !_isSubmitting,
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

            const SizedBox(height: AppDimensions.spacingMd),

            // Delivery Address Field (Optional)
            AuthTextField(
              controller: _addressController,
              label: 'Delivery Address (Optional)',
              hintText: 'Building, Street, Area / Muscat',
              prefixIcon: Icons.location_on_outlined,
              textInputAction: TextInputAction.done,
              enabled: !_isSubmitting,
              onFieldSubmitted: (_) => _handleSignup(),
            ),

            const SizedBox(height: AppDimensions.spacingLg),

            // Primary Signup CTA Button
            AuthPrimaryButton(
              label: 'Create Account',
              isLoading: _isSubmitting,
              onPressed: _handleSignup,
            ),
          ],
        ),
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
