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
  bool isProductPending(String productId) =>
      _pendingProductIds.contains(productId);

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
  Future<void> addItem(String productId, [int quantity = 1]) {
    return _enqueueMutation(productId, (storeId) async {
      final result = await _cartRepository.addItem(
        itemId: productId,
        productId: productId,
        storeId: storeId,
        quantity: quantity,
      );

      result.fold(
        onSuccess: (updatedCart) {
          _cart = updatedCart;
          _error = null;
        },
        onFailure: (failure) {
          _error = failure;
        },
      );
    });
  }

  /// Sets absolute quantity. If quantity <= 0, automatically routes to removeItem.
  Future<void> setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      return removeItem(productId);
    }

    return _enqueueMutation(productId, (storeId) async {
      final result = await _cartRepository.setItemQuantity(
        itemId: productId,
        productId: productId,
        storeId: storeId,
        quantity: quantity,
      );

      result.fold(
        onSuccess: (updatedCart) {
          _cart = updatedCart;
          _error = null;
        },
        onFailure: (failure) {
          _error = failure;
        },
      );
    });
  }

  /// Removes an individual product from the cart.
  Future<void> removeItem(String productId) {
    return _enqueueMutation(productId, (storeId) async {
      final result = await _cartRepository.removeItem(
        itemId: productId,
        productId: productId,
        storeId: storeId,
      );

      result.fold(
        onSuccess: (updatedCart) {
          _cart = updatedCart;
          _error = null;
        },
        onFailure: (failure) {
          _error = failure;
        },
      );
    });
  }

  /// Clears all items from the active store cart.
  Future<void> clear() {
    final storeId = _currentStoreId;
    if (storeId == null || storeId.isEmpty) return Future.value();

    _isClearing = true;
    notifyListeners();

    final completer = Completer<void>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        final result = await _cartRepository.clearCart(storeId: storeId);
        if (_currentStoreId == storeId) {
          result.fold(
            onSuccess: (clearedCart) {
              _cart = clearedCart;
              _error = null;
            },
            onFailure: (failure) {
              _error = failure;
            },
          );
        }
      } finally {
        _isClearing = false;
        notifyListeners();
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Enqueues an operation to run strictly sequentially after previous mutations finish.
  Future<void> _enqueueMutation(
    String productId,
    Future<void> Function(String storeId) action,
  ) {
    final storeId = _currentStoreId;
    if (storeId == null || storeId.isEmpty) {
      _error = const ValidationFailure(message: 'No store currently selected.');
      notifyListeners();
      return Future.value();
    }

    _pendingProductIds.add(productId);
    notifyListeners();

    final completer = Completer<void>();

    _mutationQueue = _mutationQueue.then((_) async {
      try {
        if (_currentStoreId == storeId) {
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
