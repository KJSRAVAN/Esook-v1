import 'dart:async';
import 'package:esouq/core/error/failures.dart';
import 'package:flutter/foundation.dart';

import '../domain/cart_model.dart';
import '../domain/cart_repository.dart';

/// State holder for the active customer cart belonging to the selected supermarket store.
class CartNotifier extends ChangeNotifier {
  final CartRepository _cartRepository;

  CartModel? _cart;
  bool _isLoading = false;
  AppFailure? _error;
  String? _currentStoreId;

  final Set<String> _pendingProductIds = <String>{};
  bool _isClearing = false;

  Future<void> _mutationQueue = Future.value();

  CartNotifier({required CartRepository cartRepository})
    : _cartRepository = cartRepository;

  CartModel? get cart => _cart;
  bool get isLoading => _isLoading;
  AppFailure? get error => _error;
  String? get currentStoreId => _currentStoreId;
  bool get isClearing => _isClearing;

  /// Total number of items in the cart for the active store.
  int get itemCount => _cart?.itemCount ?? 0;

  /// Server-calculated subtotal for the active store cart.
  double get subtotal => _cart?.subtotal ?? 0.0;

  /// Whether the active cart contains any unavailable products.
  bool get hasUnavailableItems => _cart?.hasUnavailableItems ?? false;

  /// Returns whether a mutation is currently in-flight for a specific product.
  bool isProductPending(String productId) {
    if (_pendingProductIds.contains(productId)) return true;
    if (_cart != null) {
      for (final item in _cart!.items) {
        if (item.productId == productId &&
            _pendingProductIds.contains(item.itemId)) {
          return true;
        }
        if (item.itemId == productId &&
            _pendingProductIds.contains(item.productId)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Helper to get the quantity of a specific product currently in the cart.
  int quantityForProduct(String productId) {
    if (_cart == null || _cart!.items.isEmpty) return 0;
    for (final item in _cart!.items) {
      if (item.itemId == productId || item.productId == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  /// Clears any transient error state.
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Loads or refreshes the cart for a given store. Discards stale responses.
  Future<void> loadForStore(String storeId) async {
    _currentStoreId = storeId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _cartRepository.getCart(storeId: storeId);

    // Stale check: if store changed while network request was pending, discard result
    if (_currentStoreId != storeId) return;

    _isLoading = false;
    result.fold(
      onSuccess: (loadedCart) {
        _cart = loadedCart;
        _error = null;
      },
      onFailure: (failure) {
        _error = failure;
      },
    );

    notifyListeners();
  }

  /// Adds a product to the cart or increments its count.
  Future<void> addItem(String productId, [int quantity = 1, String? storeId]) {
    if ((_currentStoreId == null || _currentStoreId!.isEmpty) &&
        storeId != null &&
        storeId.isNotEmpty) {
      _currentStoreId = storeId;
    }
    return _enqueueMutation(
      productId,
      (targetStoreId) async {
        final result = await _cartRepository.addItem(
          itemId: productId,
          productId: productId,
          storeId: targetStoreId,
          quantity: quantity,
        );

        result.fold(
          onSuccess: (updatedCart) {
            _cart = updatedCart;
            if (updatedCart.storeId != null && updatedCart.storeId!.isNotEmpty) {
              _currentStoreId = updatedCart.storeId;
            }
            _error = null;
          },
          onFailure: (failure) {
            _error = failure;
          },
        );
      },
      fallbackStoreId: storeId,
    );
  }

  /// Sets absolute quantity. If quantity <= 0, automatically routes to removeItem.
  Future<void> setQuantity(String productId, int quantity, [String? storeId]) {
    if (quantity <= 0) {
      return removeItem(productId, storeId);
    }

    if ((_currentStoreId == null || _currentStoreId!.isEmpty) &&
        storeId != null &&
        storeId.isNotEmpty) {
      _currentStoreId = storeId;
    }

    return _enqueueMutation(
      productId,
      (targetStoreId) async {
        final result = await _cartRepository.setItemQuantity(
          itemId: productId,
          productId: productId,
          storeId: targetStoreId,
          quantity: quantity,
        );

        result.fold(
          onSuccess: (updatedCart) {
            _cart = updatedCart;
            if (updatedCart.storeId != null && updatedCart.storeId!.isNotEmpty) {
              _currentStoreId = updatedCart.storeId;
            }
            _error = null;
          },
          onFailure: (failure) {
            _error = failure;
          },
        );
      },
      fallbackStoreId: storeId,
    );
  }

  /// Removes an individual product from the cart.
  Future<void> removeItem(String productId, [String? storeId]) {
    if ((_currentStoreId == null || _currentStoreId!.isEmpty) &&
        storeId != null &&
        storeId.isNotEmpty) {
      _currentStoreId = storeId;
    }

    return _enqueueMutation(
      productId,
      (targetStoreId) async {
        final result = await _cartRepository.removeItem(
          itemId: productId,
          productId: productId,
          storeId: targetStoreId,
        );

        result.fold(
          onSuccess: (updatedCart) {
            _cart = updatedCart;
            if (updatedCart.storeId != null && updatedCart.storeId!.isNotEmpty) {
              _currentStoreId = updatedCart.storeId;
            }
            _error = null;
          },
          onFailure: (failure) {
            _error = failure;
          },
        );
      },
      fallbackStoreId: storeId,
    );
  }

  /// Clears all items from the active customer cart.
  Future<void> clear() {
    _isClearing = true;
    notifyListeners();

    final completer = Completer<void>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        final storeId = _currentStoreId ?? _cart?.storeId;
        final result = await _cartRepository.clearCart(storeId: storeId);
        result.fold(
          onSuccess: (clearedCart) {
            _cart = clearedCart;
            _error = null;
          },
          onFailure: (failure) {
            _error = failure;
          },
        );
      } finally {
        _isClearing = false;
        notifyListeners();
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Completely resets in-memory cart state (used on logout, account switch, or fresh start).
  void reset() {
    _cart = null;
    _currentStoreId = null;
    _error = null;
    _isLoading = false;
    _isClearing = false;
    _pendingProductIds.clear();
    notifyListeners();
  }

  /// Enqueues an operation to run strictly sequentially after previous mutations finish.
  Future<void> _enqueueMutation(
    String productId,
    Future<void> Function(String storeId) action, {
    String? fallbackStoreId,
  }) {
    if ((_currentStoreId == null || _currentStoreId!.isEmpty) &&
        fallbackStoreId != null &&
        fallbackStoreId.isNotEmpty) {
      _currentStoreId = fallbackStoreId;
    }
    final storeId = _currentStoreId ?? _cart?.storeId ?? fallbackStoreId;
    if (storeId == null || storeId.isEmpty) {
      _error = const ValidationFailure(message: 'No store currently selected.');
      notifyListeners();
      return Future.value();
    }
    if (_currentStoreId == null || _currentStoreId!.isEmpty) {
      _currentStoreId = storeId;
    }

    _pendingProductIds.add(productId);
    notifyListeners();

    final completer = Completer<void>();

    _mutationQueue = _mutationQueue.then((_) async {
      try {
        if (_currentStoreId == storeId || _currentStoreId == null) {
          await action(storeId);
        }
      } finally {
        _pendingProductIds.remove(productId);
        notifyListeners();
        completer.complete();
      }
    });

    return completer.future;
  }
}
