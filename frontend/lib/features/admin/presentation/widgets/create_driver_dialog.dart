import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/widgets/auth_password_field.dart';
import '../../../auth/presentation/widgets/auth_primary_button.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../domain/models/admin_user_model.dart';
import '../../domain/repositories/admin_drivers_repository.dart';

/// Modal dialog for Super Admin to provision a new Delivery Driver.
class CreateDriverDialog extends StatefulWidget {
  final AdminDriversRepository driversRepository;

  const CreateDriverDialog({super.key, required this.driversRepository});

  static Future<AdminUserModel?> show(
    BuildContext context, {
    required AdminDriversRepository driversRepository,
  }) {
    return showDialog<AdminUserModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          CreateDriverDialog(driversRepository: driversRepository),
    );
  }

  @override
  State<CreateDriverDialog> createState() => _CreateDriverDialogState();
}

class _CreateDriverDialogState extends State<CreateDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    final result = await widget.driversRepository.registerDriver(
      name: name,
      phone: phone,
      password: password,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(result.dataOrNull);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            result.failureOrNull?.message ?? 'Failed to register driver';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: Color(0xFFEA580C),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            'Register Driver',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    'Create credentials for a new delivery driver partner. The driver can immediately sign in with phone & password.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingSm),
                      margin: const EdgeInsets.only(
                        bottom: AppDimensions.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),

                  // Name Field
                  AuthTextField(
                    key: const Key('driver_name_field'),
                    controller: _nameController,
                    label: 'Driver Full Name',
                    hintText: 'e.g. Mohammed Al-Rashid',
                    prefixIcon: Icons.person_outline_rounded,
                    enabled: !_isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter driver name';
                      }
                      if (val.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Phone Field
                  AuthTextField(
                    key: const Key('driver_phone_field'),
                    controller: _phoneController,
                    label: 'Phone Number (E.164)',
                    hintText: '+966501234567',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    enabled: !_isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (val.trim().length < 8) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Password Field
                  AuthPasswordField(
                    key: const Key('driver_password_field'),
                    controller: _passwordController,
                    label: 'Temporary Password',
                    hintText: 'Min 8 characters',
                    enabled: !_isSubmitting,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (val.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Confirm Password Field
                  AuthPasswordField(
                    key: const Key('driver_confirm_password_field'),
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hintText: 'Re-type password',
                    enabled: !_isSubmitting,
                    validator: (val) {
                      if (val != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      SizedBox(
                        width: 140,
                        child: AuthPrimaryButton(
                          key: const Key('submit_driver_button'),
                          label: 'Create Driver',
                          isLoading: _isSubmitting,
                          onPressed: _handleSubmit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
