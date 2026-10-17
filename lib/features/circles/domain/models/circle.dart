enum CircleStatus {
  active,
  archived;

  static CircleStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
        return CircleStatus.active;
      case 'archived':
        return CircleStatus.archived;
      default:
        throw ArgumentError('Unknown CircleStatus: $value');
    }
  }

  String toDbString() => name;
}

class Circle {
  final String id;
  final String name;
  final String ownerId;
  final String? description;
  final CircleStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Circle({
    required this.id,
    required this.name,
    required this.ownerId,
    this.description,
    this.status = CircleStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  Circle copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? description,
    CircleStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Circle(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String,
      description: json['description'] as String?,
      status: CircleStatus.fromString((json['status'] as String?) ?? 'active'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      if (description != null) 'description': description,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
