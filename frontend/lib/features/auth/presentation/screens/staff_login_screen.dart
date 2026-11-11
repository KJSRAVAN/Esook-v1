import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/role_routing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/auth_phone_helper.dart';
import '../../domain/models/auth_response_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_scope.dart';
import '../widgets/auth_text_field.dart';

/// Supported authentication credential types for Store Staff and Managers.
enum StaffLoginMethod { phone, email }

/// Store Staff & Manager login screen for eSOuQ inventory and fulfillment operations.
///
/// Supports both Phone + Password (canonical international E.164) and
/// Email + Password against the production `POST /auth/staff/login` contract.
class StaffLoginScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const StaffLoginScreen({super.key, this.authRepository});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  StaffLoginMethod _method = StaffLoginMethod.phone;
  bool _isSubmitting = false;
  AppFailure? _failure;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void dispose() {
    _phoneController.dispose();
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

    final password = _passwordController.text;
    final Result<AuthResponseModel> result;

    if (_method == StaffLoginMethod.phone) {
      final normalizedPhone =
          AuthPhoneHelper.normalizeAuthPhone(_phoneController.text)!;
      result = await _repository.login(
        phoneNumber: normalizedPhone,
        password: password,
      );
    } else {
      final email = _emailController.text.trim().toLowerCase();
      result = await _repository.login(
        email: email,
        password: password,
      );
    }

    if (!mounted) return;

    if (result.isSuccess) {
      final authResponse = result.dataOrNull!;
      final role = authResponse.user.role;

      if (!role.isStoreStaff && !role.isSuperAdmin) {
        setState(() {
          _isSubmitting = false;
          _failure = const ForbiddenFailure(
            message:
                'Access denied. Store Staff or Store Manager privileges required.',
          );
        });
        return;
      }

      setState(() => _isSubmitting = false);
      // Route according to the authoritative role returned by the backend
      RoleRouting.navigateForRole(
        context,
        role,
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
          color: const Color(0xFFEFF6FF), // Blue-50
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: const Color(0xFFBFDBFE)), // Blue-200
        ),
        child: const Icon(
          Icons.storefront_rounded,
          color: Color(0xFF2563EB), // Blue-600
          size: 34,
        ),
      ),
      title: 'Store Operations',
      subtitle: 'Staff & Store Manager sign-in for orders, stock & inventory',
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

            // Login Method Toggle (Phone / Email)
            _buildMethodSelector(),

            const SizedBox(height: AppDimensions.spacingMd),

            // Phone or Email Field based on selected method
            if (_method == StaffLoginMethod.phone)
              AuthTextField(
                key: const Key('staff_phone_field'),
                controller: _phoneController,
                label: 'Staff Phone Number',
                hintText: '+966 50 123 4567',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                letterSpacing: 0.0,
                enabled: !_isSubmitting,
                validator: (value) => AuthPhoneHelper.validateAuthPhone(
                  value,
                  requiredMessage:
                      'Please enter your registered staff phone number',
                ),
              )
            else
              AuthTextField(
                key: const Key('staff_email_field'),
                controller: _emailController,
                label: 'Staff Email',
                hintText: 'staff@esook.store',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_isSubmitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your registered staff email';
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
              key: const Key('staff_password_field'),
              controller: _passwordController,
              label: 'Password',
              hintText: 'Enter your staff account password',
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
              label: 'Staff Login',
              isLoading: _isSubmitting,
              onPressed: _handleLogin,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate-100
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'Phone Number',
              icon: Icons.phone_outlined,
              isSelected: _method == StaffLoginMethod.phone,
              onTap: _isSubmitting
                  ? null
                  : () {
                      if (_method != StaffLoginMethod.phone) {
                        setState(() {
                          _method = StaffLoginMethod.phone;
                          _failure = null;
                        });
                      }
                    },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              title: 'Email Address',
              icon: Icons.email_outlined,
              isSelected: _method == StaffLoginMethod.email,
              onTap: _isSubmitting
                  ? null
                  : () {
                      if (_method != StaffLoginMethod.email) {
                        setState(() {
                          _method = StaffLoginMethod.email;
                          _failure = null;
                        });
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF2563EB) // Blue-600
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : AppColors.textSecondary,
              ),
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
