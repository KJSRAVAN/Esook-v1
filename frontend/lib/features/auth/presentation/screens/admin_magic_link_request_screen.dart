import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/role_routing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';
import '../widgets/auth_text_field.dart';

/// Super Admin login screen using staff authentication contract (POST /auth/staff/login).
class AdminMagicLinkRequestScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const AdminMagicLinkRequestScreen({super.key, this.authRepository});

  @override
  State<AdminMagicLinkRequestScreen> createState() =>
      _AdminMagicLinkRequestScreenState();
}

class _AdminMagicLinkRequestScreenState
    extends State<AdminMagicLinkRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  AppFailure? _failure;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _failure = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await _repository.login(email: email, password: password);

    if (!mounted) return;

    if (result.isSuccess) {
      final authResponse = result.dataOrNull!;
      if (authResponse.user.role != UserRole.superAdmin) {
        setState(() {
          _isSubmitting = false;
          _failure = const ForbiddenFailure(
            message: 'Access denied. Super Administrator privileges required.',
          );
        });
        return;
      }

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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 480.0,
      showBackButton: true,
      onBackPressed: () =>
          Navigator.of(context).pushReplacementNamed(AppRoutes.login),
      headerBadge: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // Slate-100
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: const Color(0xFFCBD5E1)), // Slate-300
        ),
        child: const Icon(
          Icons.admin_panel_settings_rounded,
          color: Color(0xFF334155), // Slate-700
          size: 36,
        ),
      ),
      title: 'Admin Portal',
      subtitle:
          'Sign in with your administrator credentials to access the console',
      bottomNavigation: _buildBottomLinks(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error Banner
            if (_failure != null)
              AuthErrorBanner(
                failure: _failure,
                onDismiss: () => setState(() => _failure = null),
                onRetry: _failure is NetworkFailure ? _handleLogin : null,
              ),

            // Email Address Field
            AuthTextField(
              controller: _emailController,
              label: 'Administrator Email',
              hintText: 'admin@esook.store',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_isSubmitting,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your administrator email';
                }
                final emailRegex = RegExp(
                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                );
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: AppDimensions.spacingMd),

            // Password Field
            AuthPasswordField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Enter your administrator password',
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

            // Primary Sign In Button
            AuthPrimaryButton(
              label: 'Admin Sign In',
              isLoading: _isSubmitting,
              icon: Icons.login_rounded,
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
              : () =>
                    Navigator.of(context).pushReplacementNamed(AppRoutes.login),
          icon: const Icon(Icons.shopping_bag_outlined, size: 16),
          label: const Text('Return to Customer App'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }
}
