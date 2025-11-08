class OwnerContact {
  final int? id;
  final String name;
  final String contactNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OwnerContact({
    this.id,
    required this.name,
    required this.contactNumber,
    this.createdAt,
    this.updatedAt,
  });

  OwnerContact copyWith({
    int? id,
    String? name,
    String? contactNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OwnerContact(
      id: id ?? this.id,
      name: name ?? this.name,
      contactNumber: contactNumber ?? this.contactNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OwnerContact &&
        other.id == id &&
        other.name == name &&
        other.contactNumber == contactNumber &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        contactNumber.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'OwnerContact(id: $id, name: $name, contactNumber: $contactNumber, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}