import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/widgets/auth_primary_button.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/repositories/admin_stores_repository.dart';

/// Modal dialog for Super Admin to edit an existing Store.
class EditStoreDialog extends StatefulWidget {
  final AdminStoreModel store;
  final AdminStoresRepository storesRepository;

  const EditStoreDialog({
    super.key,
    required this.store,
    required this.storesRepository,
  });

  static Future<AdminStoreModel?> show(
    BuildContext context, {
    required AdminStoreModel store,
    required AdminStoresRepository storesRepository,
  }) {
    return showDialog<AdminStoreModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditStoreDialog(
        store: store,
        storesRepository: storesRepository,
      ),
    );
  }

  @override
  State<EditStoreDialog> createState() => _EditStoreDialogState();
}

class _EditStoreDialogState extends State<EditStoreDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _areaController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late bool _isActive;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.name);
    _areaController = TextEditingController(text: widget.store.area);
    _addressController = TextEditingController(text: widget.store.address ?? '');
    _phoneController = TextEditingController(text: widget.store.phone ?? '');
    _isActive = widget.store.isActive;
  }

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

    final result = await widget.storesRepository.updateStore(
      storeId: widget.store.id,
      name: name,
      area: area.isNotEmpty ? area : null,
      address: address.isNotEmpty ? address : null,
      phone: phone.isNotEmpty ? phone : null,
      isActive: _isActive,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(result.dataOrNull);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result.failureOrNull?.message ?? 'Failed to update store';
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
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: const Icon(
                              Icons.edit_location_alt_rounded,
                              color: AppColors.primaryDark,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            'Edit Store',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingSm),
                      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                      ),
                    ),

                  // Store Name
                  AuthTextField(
                    key: const Key('edit_store_name_field'),
                    controller: _nameController,
                    label: 'Store Name',
                    prefixIcon: Icons.storefront_rounded,
                    enabled: !_isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter store name';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Delivery Area
                  AuthTextField(
                    key: const Key('edit_store_area_field'),
                    controller: _areaController,
                    label: 'Delivery Area',
                    prefixIcon: Icons.location_on_outlined,
                    enabled: !_isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter delivery area';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Address
                  AuthTextField(
                    key: const Key('edit_store_address_field'),
                    controller: _addressController,
                    label: 'Address',
                    prefixIcon: Icons.map_outlined,
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Phone
                  AuthTextField(
                    key: const Key('edit_store_phone_field'),
                    controller: _phoneController,
                    label: 'Phone',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Active Switch
                  SwitchListTile(
                    key: const Key('edit_store_active_switch'),
                    value: _isActive,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Store Active Status'),
                    subtitle: Text(
                      _isActive
                          ? 'Store is open and visible to customers'
                          : 'Store is disabled and hidden from customers',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    onChanged: _isSubmitting ? null : (val) => setState(() => _isActive = val),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      SizedBox(
                        width: 140,
                        child: AuthPrimaryButton(
                          key: const Key('submit_edit_store_button'),
                          label: 'Save Changes',
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
