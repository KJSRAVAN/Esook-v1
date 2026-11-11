import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/flutter_secure_storage_impl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Modal dialog for Super Admin or Store Manager to configure store-level
/// loyalty points settings.
class StoreLoyaltyDialog extends StatefulWidget {
  final String storeId;
  final String storeName;
  final ApiClient? apiClient;

  const StoreLoyaltyDialog({
    super.key,
    required this.storeId,
    required this.storeName,
    this.apiClient,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String storeId,
    required String storeName,
    ApiClient? apiClient,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StoreLoyaltyDialog(
        storeId: storeId,
        storeName: storeName,
        apiClient: apiClient,
      ),
    );
  }

  @override
  State<StoreLoyaltyDialog> createState() => _StoreLoyaltyDialogState();
}

class _StoreLoyaltyDialogState extends State<StoreLoyaltyDialog> {
  final _formKey = GlobalKey<FormState>();

  late final ApiClient _apiClient;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  bool _isEnabled = true;
  late final TextEditingController _redemptionValueController;
  late final TextEditingController _maxDiscountPercentController;

  @override
  void initState() {
    super.initState();
    if (widget.apiClient != null) {
      _apiClient = widget.apiClient!;
    } else {
      final config = AppConfig.fromEnvironment();
      final secureStorage = const FlutterSecureStorageImpl();
      _apiClient = DefaultApiClient(
        baseUrl: config.apiBaseUrl,
        tokenProvider: () => secureStorage.read(key: StorageKeys.authToken),
        secureStorage: secureStorage,
        timeout: config.connectTimeout,
      );
    }

    _redemptionValueController = TextEditingController(text: '0.10');
    _maxDiscountPercentController = TextEditingController(text: '50');

    _loadConfig();
  }

  @override
  void dispose() {
    _redemptionValueController.dispose();
    _maxDiscountPercentController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiClient.get<dynamic>(
        '/stores/${widget.storeId}/points/config',
      );

      if (mounted) {
        if (res.data is Map<String, dynamic>) {
          final data = res.data as Map<String, dynamic>;
          _isEnabled = data['isEnabled'] as bool? ?? true;
          if (data['pointsPerCurrencyUnit'] != null) {
            _redemptionValueController.text = data['pointsPerCurrencyUnit'].toString();
          }
          if (data['maxDiscountPercent'] != null) {
            _maxDiscountPercentController.text = data['maxDiscountPercent'].toString();
          }
        }
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final redemptionValue = double.tryParse(_redemptionValueController.text.trim()) ?? 0.10;
      final maxDiscount = double.tryParse(_maxDiscountPercentController.text.trim()) ?? 100.0;

      ApiResponse<dynamic> res;
      final payload = {
        'isEnabled': _isEnabled,
        'pointsPerCurrencyUnit': redemptionValue,
        'pointsEarnedPerCurrency': 1.0,
        'minPointsToRedeem': 0,
        'maxDiscountPercent': maxDiscount,
        'maxPointsPerOrder': null,
      };

      try {
        res = await _apiClient.post<dynamic>(
          '/stores/${widget.storeId}/points/config',
          body: payload,
        );
      } catch (e) {
        if (e is AppException && (e.statusCode == 404 || e.statusCode == 405)) {
          // Gracefully fallback to PUT if endpoint only supports PUT (e.g. partner backend remote)
          res = await _apiClient.put<dynamic>(
            '/stores/${widget.storeId}/points/config',
            body: payload,
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      if (res.isSuccess) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loyalty points configuration saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to update loyalty settings (status ${res.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to update loyalty settings: $e';
        if (e is AppException) {
          msg = 'Failed to update loyalty settings: ${e.message}';
        }
        setState(() {
          _isSaving = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final dialogWidth = (screenWidth - 32.0).clamp(280.0, 480.0);
    final dialogMaxHeight = (screenHeight - 48.0).clamp(320.0, 680.0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480.0,
          maxHeight: dialogMaxHeight,
        ),
        child: SizedBox(
          width: dialogWidth,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: _isLoading
                ? const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFFEF3C7),
                              child: Icon(
                                Icons.stars_rounded,
                                color: Color(0xFFD97706),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Loyalty Points Settings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    widget.storeName,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        const Divider(),
                        const SizedBox(height: AppDimensions.spacingSm),

                        // Info banner on product-based earning
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.spacingSm),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(
                              color: const Color(0xFFD97706).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Point Earning: Customers earn points configured on each product upon delivery.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: const Color(0xFF92400E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppDimensions.spacingSm),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingSm),
                        ],

                        // 1. Enable / Disable toggle
                        SwitchListTile.adaptive(
                          key: const Key('loyalty_is_enabled_switch'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Enable Loyalty Programme',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _isEnabled
                                ? 'Customers earn and redeem points in this store'
                                : 'Loyalty points are deactivated for this store',
                            style: AppTextStyles.bodySmall,
                          ),
                          value: _isEnabled,
                          activeTrackColor: AppColors.primary,
                          onChanged: _isSaving ? null : (val) => setState(() => _isEnabled = val),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),

                        // 2. Conversion rate (SAR discount per point)
                        TextFormField(
                          key: const Key('loyalty_redemption_rate_input'),
                          controller: _redemptionValueController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Points Conversion Rate (SAR per 1 pt)',
                            hintText: 'e.g. 0.10 (10 points = 1 SAR discount)',
                            helperText: 'Discount value per point. E.g. 0.10 = 10 pts give 1 SAR discount',
                            prefixIcon: Icon(Icons.discount_outlined, size: 20),
                          ),
                          validator: (v) {
                            final val = double.tryParse(v ?? '');
                            if (val == null || val <= 0) return 'Must be a positive number';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),

                        // 3. Max discount percent
                        TextFormField(
                          key: const Key('loyalty_max_discount_percent_input'),
                          controller: _maxDiscountPercentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Maximum Order Discount (%)',
                            hintText: 'e.g. 50.0 (or 100 for no cap)',
                            helperText: 'Maximum percentage of order total discounted by points',
                            prefixIcon: Icon(Icons.percent_rounded, size: 20),
                          ),
                          validator: (v) {
                            final val = double.tryParse(v ?? '');
                            if (val == null || val <= 0 || val > 100) return 'Must be between 1 and 100';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),

                        // Actions
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppDimensions.spacingSm,
                          runSpacing: AppDimensions.spacingSm,
                          children: [
                            TextButton(
                              key: const Key('loyalty_cancel_btn'),
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              key: const Key('loyalty_save_btn'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(130, 44),
                              ),
                              onPressed: _isSaving ? null : _handleSave,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save Settings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
  }
}
