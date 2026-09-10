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
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';
import '../widgets/auth_text_field.dart';

/// Customer login screen for eSOuQ.
class CustomerLoginScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const CustomerLoginScreen({
    super.key,
    this.authRepository,
  });

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  AppFailure? _failure;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Clear previous error
    setState(() => _failure = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    final result = await _repository.login(
      phoneNumber: phone,
      password: password,
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
      title: 'Welcome Back',
      subtitle: 'Sign in to continue ordering fresh groceries',
      bottomNavigation: _buildBottomLinks(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Backend / Network Error Banner
            if (_failure != null)
              AuthErrorBanner(
                failure: _failure,
                onDismiss: () => setState(() => _failure = null),
                onRetry: _failure is NetworkFailure ? _handleLogin : null,
              ),

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

            // Password Field
            AuthPasswordField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Enter your password',
              textInputAction: TextInputAction.done,
              enabled: !_isSubmitting,
              onFieldSubmitted: (_) => _handleLogin(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),

            const SizedBox(height: AppDimensions.spacingLg),

            // Primary Login CTA Button
            AuthPrimaryButton(
              label: 'Login',
              isLoading: _isSubmitting,
              onPressed: _handleLogin,
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
                  : () => Navigator.of(context).pushNamed(AppRoutes.adminMagicLink),
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
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.devCustomerPreview),
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
