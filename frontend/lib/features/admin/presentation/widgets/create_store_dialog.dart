import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/widgets/auth_primary_button.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/repositories/admin_stores_repository.dart';

/// Modal dialog for Super Admin to create a new Store.
class CreateStoreDialog extends StatefulWidget {
  final AdminStoresRepository storesRepository;

  const CreateStoreDialog({super.key, required this.storesRepository});

  static Future<AdminStoreModel?> show(
    BuildContext context, {
    required AdminStoresRepository storesRepository,
  }) {
    return showDialog<AdminStoreModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateStoreDialog(storesRepository: storesRepository),
    );
  }

  @override
  State<CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<CreateStoreDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final area = _areaController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();

    final result = await widget.storesRepository.createStore(
      name: name,
      area: area,
      address: address.isNotEmpty ? address : null,
      phone: phone.isNotEmpty ? phone : null,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(result.dataOrNull);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            result.failureOrNull?.message ?? 'Failed to create store';
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
        constraints: const BoxConstraints(maxWidth: 480),
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
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_business_rounded,
                              color: AppColors.primaryDark,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            'Add New Store',
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

                  // Store Name
                  AuthTextField(
                    key: const Key('store_name_field'),
                    controller: _nameController,
                    label: 'Store Name',
                    hintText: 'e.g. Fresh Mart Riyadh North',
                    prefixIcon: Icons.storefront_rounded,
                    enabled: !_isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter store name';
                      }
                      if (val.trim().length < 2) {
                        return 'Store name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Delivery Area
                  AuthTextField(
                    key: const Key('store_area_field'),
                    controller: _areaController,
                    label: 'Delivery Area',
                    hintText: 'e.g. Riyadh-North, Downtown, Olaya',
                    prefixIcon: Icons.location_on_outlined,
                    enabled: !_isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter delivery area';
                      }
                      if (val.trim().length < 2) {
                        return 'Area must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Address
                  AuthTextField(
                    key: const Key('store_address_field'),
                    controller: _addressController,
                    label: 'Physical Address',
                    hintText: 'King Fahd Road, Al-Olaya',
                    prefixIcon: Icons.map_outlined,
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Phone
                  AuthTextField(
                    key: const Key('store_phone_field'),
                    controller: _phoneController,
                    label: 'Contact Phone',
                    hintText: '+966112345678',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    enabled: !_isSubmitting,
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
                          key: const Key('submit_store_button'),
                          label: 'Create Store',
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
