import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/store_model.dart';
import '../../domain/repositories/store_repository.dart';
import 'customer_scope.dart';
import 'store_card.dart';

/// Reusable view presenting the Shop Selection experience.
///
/// Fetches active stores via [StoreRepository] and allows the customer to pick their active market store.
class StoreSelectionView extends StatefulWidget {
  final StoreRepository? storeRepository;
  final StoreModel? currentSelectedStore;
  final ValueChanged<StoreModel> onStoreSelected;
  final VoidCallback? onCancel;

  const StoreSelectionView({
    super.key,
    this.storeRepository,
    this.currentSelectedStore,
    required this.onStoreSelected,
    this.onCancel,
  });

  @override
  State<StoreSelectionView> createState() => _StoreSelectionViewState();
}

class _StoreSelectionViewState extends State<StoreSelectionView> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StoreModel> _stores = [];

  StoreRepository get _repository =>
      widget.storeRepository ?? CustomerScope.storeRepositoryOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStores());
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repository.getStores();

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _isLoading = false;
        _stores = result.dataOrNull ?? [];
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.failureOrNull?.message ?? 'Failed to load stores';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingMd,
            AppDimensions.spacingMd,
            AppDimensions.spacingMd,
            AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacingXs),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Supermarket',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Choose a local store to browse fresh items',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onCancel,
                  tooltip: 'Close',
                ),
            ],
          ),
        ),
        const Divider(),

        // Body Content
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spacing2xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    'Finding nearby stores...',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.store_mall_directory_outlined,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'Could Not Load Stores',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                ElevatedButton.icon(
                  onPressed: _loadStores,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          )
        else if (_stores.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing2xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'No Active Stores Found',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  'There are currently no active supermarkets serving this region.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              itemCount: _stores.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spacingSm),
              itemBuilder: (context, index) {
                final store = _stores[index];
                final isSelected = widget.currentSelectedStore?.id == store.id;
                return StoreCard(
                  store: store,
                  isSelected: isSelected,
                  onTap: () => widget.onStoreSelected(store),
                );
              },
            ),
          ),
      ],
    );
  }
}
