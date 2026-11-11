import 'package:flutter/foundation.dart';

import '../domain/repositories/order_repository.dart';

/// State holder for authenticated customer loyalty points at the selected store.
class PointsNotifier extends ChangeNotifier {
  final OrderRepository _orderRepository;

  CustomerPointsInfo? _pointsInfo;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentStoreId;

  PointsNotifier({
    required OrderRepository orderRepository,
    CustomerPointsInfo? initialPointsInfo,
  })  : _orderRepository = orderRepository,
        _pointsInfo = initialPointsInfo;

  CustomerPointsInfo? get pointsInfo => _pointsInfo;
  int get balance => _pointsInfo?.balance ?? 0;
  bool get isEnabled => _pointsInfo?.isEnabled ?? false;
  double get monetaryValue => _pointsInfo?.monetaryValue ?? 0.0;
  double get pointsPerCurrencyUnit =>
      _pointsInfo?.pointsPerCurrencyUnit ?? 0.10;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentStoreId => _currentStoreId;

  /// Loads or refreshes loyalty points for a given store.
  Future<void> loadForStore(String storeId) async {
    _currentStoreId = storeId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _orderRepository.getStorePointsInfo(storeId);

    // Stale check: if target store changed during async request, discard
    if (_currentStoreId != storeId) return;

    _isLoading = false;
    result.fold(
      onSuccess: (info) {
        _pointsInfo = info;
        _errorMessage = null;
      },
      onFailure: (failure) {
        _errorMessage = failure.message;
      },
    );

    notifyListeners();
  }

  /// Refreshes points balance for the active store without re-initiating full loading state if already present.
  Future<void> refresh() async {
    if (_currentStoreId != null) {
      await loadForStore(_currentStoreId!);
    }
  }

  /// Manually update points info (e.g. after local transaction or mock injection).
  void setPointsInfo(CustomerPointsInfo info) {
    _pointsInfo = info;
    _errorMessage = null;
    notifyListeners();
  }
}

