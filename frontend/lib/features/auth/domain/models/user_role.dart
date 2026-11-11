/// Enumeration of exact user roles supported by the backend.
enum UserRole {
  customer('customer'),
  storeStaff('store_staff'),
  storeManager('store_manager'),
  deliveryRider('delivery_rider'),
  superAdmin('super_admin'),
  unknown('unknown');

  final String value;
  const UserRole(this.value);

  /// Safe parsing that prevents crashes on unexpected or new backend roles.
  static UserRole fromString(String? role) {
    if (role == null) return UserRole.unknown;
    final normalized = role.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (normalized) {
      case 'customer':
        return UserRole.customer;
      case 'store_staff':
      case 'storestaff':
      case 'staff':
        return UserRole.storeStaff;
      case 'store_manager':
      case 'storemanager':
      case 'manager':
        return UserRole.storeManager;
      case 'delivery_rider':
      case 'deliveryrider':
      case 'driver':
      case 'rider':
        return UserRole.deliveryRider;
      case 'super_admin':
      case 'superadmin':
      case 'admin':
        return UserRole.superAdmin;
      default:
        return UserRole.unknown;
    }
  }

  bool get isCustomer => this == UserRole.customer;
  bool get isStoreStaff =>
      this == UserRole.storeStaff || this == UserRole.storeManager;
  bool get isStoreManager => this == UserRole.storeManager;
  bool get isDeliveryRider => this == UserRole.deliveryRider;
  bool get isSuperAdmin => this == UserRole.superAdmin;
}
