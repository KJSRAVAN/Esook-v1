/// Admin area model representing delivery areas from `GET /stores/areas`.
class AdminAreaModel {
  final String id;
  final String name;

  const AdminAreaModel({required this.id, required this.name});

  factory AdminAreaModel.fromJson(Map<String, dynamic> json) {
    return AdminAreaModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
