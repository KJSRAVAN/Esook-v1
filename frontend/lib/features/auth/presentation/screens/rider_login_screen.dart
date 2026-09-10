import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/role_routing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';
import '../widgets/auth_text_field.dart';

/// Delivery Rider partner login screen for eSOuQ dispatch and order fulfillment.
class RiderLoginScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const RiderLoginScreen({
    super.key,
    this.authRepository,
  });

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
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
      maxWidth: 440.0,
      showBackButton: true,
      onBackPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
      headerBadge: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED), // Amber/Orange-50
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: const Color(0xFFFED7AA)), // Orange-200
        ),
        child: const Icon(
          Icons.delivery_dining_rounded,
          color: Color(0xFFEA580C), // Orange-600
          size: 36,
        ),
      ),
      title: 'Rider Partner Portal',
      subtitle: 'Sign in to accept delivery batches and navigate routes',
      bottomNavigation: _buildBottomLinks(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error banner
            if (_failure != null)
              AuthErrorBanner(
                failure: _failure,
                onDismiss: () => setState(() => _failure = null),
                onRetry: _failure is NetworkFailure ? _handleLogin : null,
              ),

            // Phone Field
            AuthTextField(
              controller: _phoneController,
              label: 'Rider Phone Number',
              hintText: '+968 9123 4567',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              enabled: !_isSubmitting,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your registered rider phone number';
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

            // Submit Button
            AuthPrimaryButton(
              label: 'Rider Login',
              isLoading: _isSubmitting,
              onPressed: _handleLogin,
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
        const SizedBox(height: AppDimensions.spacingSm),
        TextButton.icon(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
          icon: const Icon(Icons.shopping_bag_outlined, size: 16),
          label: const Text('Return to Customer App'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
