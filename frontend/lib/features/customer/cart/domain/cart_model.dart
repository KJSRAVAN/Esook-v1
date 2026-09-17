import 'cart_item_model.dart';

/// Store reference within the cart response.
class CartStoreRef {
  final String id;
  final String name;
  final String area;
  final bool isActive;

  const CartStoreRef({
    required this.id,
    this.name = '',
    this.area = '',
    this.isActive = true,
  });

  factory CartStoreRef.fromJson(Map<String, dynamic> json) {
    return CartStoreRef(
      id: json['id'] as String? ?? json['storeId'] as String? ?? json['store_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      area: json['area'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'area': area,
      'isActive': isActive,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartStoreRef &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          area == other.area &&
          isActive == other.isActive;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ area.hashCode ^ isActive.hashCode;
}

/// Immutable model representing the customer's active cart matching backend Cart schema.
class CartModel {
  final String userId;
  final String? storeId;
  final List<CartItemModel> items;
  final double subtotal;
  final DateTime? updatedAt;
  final CartStoreRef store;

  const CartModel({
    String? userId,
    String? cartId,
    this.storeId,
    required this.items,
    required this.subtotal,
    this.updatedAt,
    this.store = const CartStoreRef(id: ''),
    int? itemCount,
    bool? hasUnavailableItems,
  }) : userId = userId ?? cartId ?? '';

  /// Creates an empty cart model.
  factory CartModel.empty({
    String userId = '',
    String? storeId,
    CartStoreRef? store,
  }) {
    final resolvedStoreId = storeId ?? store?.id;
    return CartModel(
      userId: userId,
      storeId: resolvedStoreId,
      items: const [],
      subtotal: 0.0,
      updatedAt: null,
      store: store ?? CartStoreRef(id: resolvedStoreId ?? ''),
    );
  }

  /// Backward compatibility cartId getter.
  String? get cartId => userId.isNotEmpty ? userId : null;

  /// Total count of item quantities in the cart.
  int get itemCount => items.fold<int>(0, (sum, i) => sum + i.quantity);

  /// Calculates total loyalty points that will be earned across all items in cart.
  int get totalLoyaltyPoints =>
      items.fold<int>(0, (sum, item) => sum + item.subtotalPoints);

  /// Whether the cart contains any items marked as unavailable.
  bool get hasUnavailableItems => items.any((i) => !i.isAvailable);

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  factory CartModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    double parseSubtotal(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(CartItemModel.fromJson)
        .toList();

    final storeId = json['storeId'] as String? ?? json['store_id'] as String?;
    final storeMap = json['store'] as Map<String, dynamic>?;
    final storeRef = storeMap != null
        ? CartStoreRef.fromJson(storeMap)
        : CartStoreRef(id: storeId ?? '');

    return CartModel(
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? json['cart_id'] as String? ?? '',
      storeId: storeId ?? (storeRef.id.isNotEmpty ? storeRef.id : null),
      items: items,
      subtotal: parseSubtotal(json['subtotal']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      store: storeRef,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'user_id': userId,
      if (storeId != null) 'storeId': storeId,
      if (storeId != null) 'store_id': storeId,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
      'store': store.toJson(),
    };
  }

  CartModel copyWith({
    String? userId,
    String? storeId,
    List<CartItemModel>? items,
    double? subtotal,
    DateTime? updatedAt,
    CartStoreRef? store,
    int? itemCount,
    bool? hasUnavailableItems,
    String? cartId,
  }) {
    return CartModel(
      userId: userId ?? cartId ?? this.userId,
      storeId: storeId ?? this.storeId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      updatedAt: updatedAt ?? this.updatedAt,
      store: store ?? this.store,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          storeId == other.storeId &&
          subtotal == other.subtotal;

  @override
  int get hashCode => userId.hashCode ^ storeId.hashCode ^ subtotal.hashCode;

  @override
  String toString() =>
      'CartModel(userId: $userId, storeId: $storeId, items: ${items.length}, subtotal: $subtotal)';
}
