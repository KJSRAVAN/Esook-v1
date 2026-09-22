/// Canonical delivery area mapping and resolver for eSOuQ launch.
///
/// Production backend contract requires the Area CUID in the `areaId` field:
/// - Riyadh: `cmu5u0i810000vy8ilejcv1rz`
/// - Jeddah: `cmu5u0ink0001vy8i7hu36wkg`
abstract final class StoreDeliveryArea {
  static const String riyadhName = 'Riyadh';
  static const String riyadhId = 'cmu5u0i810000vy8ilejcv1rz';

  static const String jeddahName = 'Jeddah';
  static const String jeddahId = 'cmu5u0ink0001vy8i7hu36wkg';

  /// Supported launch delivery areas for UI selection.
  static const List<StoreDeliveryAreaOption> supportedAreas = [
    StoreDeliveryAreaOption(name: riyadhName, areaId: riyadhId),
    StoreDeliveryAreaOption(name: jeddahName, areaId: jeddahId),
  ];

  /// Resolves the backend Area CUID from either an existing CUID or an area name string.
  static String? resolveAreaId(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();

    // Direct CUID match
    if (trimmed == riyadhId) return riyadhId;
    if (trimmed == jeddahId) return jeddahId;

    // Case-insensitive name match
    final lower = trimmed.toLowerCase();
    if (lower == 'riyadh' || lower.contains('riyadh')) return riyadhId;
    if (lower == 'jeddah' || lower.contains('jeddah')) return jeddahId;

    return null;
  }

  /// Resolves the human-readable display name ('Riyadh' or 'Jeddah') from a CUID or name.
  static String? resolveAreaName(String? value) {
    final id = resolveAreaId(value);
    if (id == riyadhId) return riyadhName;
    if (id == jeddahId) return jeddahName;
    return null;
  }
}

/// Represents a delivery area option in the UI selector.
class StoreDeliveryAreaOption {
  final String name;
  final String areaId;

  const StoreDeliveryAreaOption({required this.name, required this.areaId});
}
