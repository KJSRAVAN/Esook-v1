/// Area entity model matching backend Area schema.
class AreaModel {
  final String id;
  final String name;
  final DateTime? createdAt;

  const AreaModel({required this.id, required this.name, this.createdAt});

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return AreaModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AreaModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'AreaModel(id: $id, name: $name)';
}
