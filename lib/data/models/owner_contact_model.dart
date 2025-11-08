import '../../domain/entities/owner_contact.dart';

class OwnerContactModel extends OwnerContact {
  const OwnerContactModel({
    super.id,
    required super.name,
    required super.contactNumber,
    super.createdAt,
    super.updatedAt,
  });

  factory OwnerContactModel.fromMap(Map<String, dynamic> map) {
    return OwnerContactModel(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      contactNumber: map['contact_number'] ?? '',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact_number': contactNumber,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory OwnerContactModel.fromEntity(OwnerContact contact) {
    return OwnerContactModel(
      id: contact.id,
      name: contact.name,
      contactNumber: contact.contactNumber,
      createdAt: contact.createdAt,
      updatedAt: contact.updatedAt,
    );
  }

  @override
  OwnerContactModel copyWith({
    int? id,
    String? name,
    String? contactNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OwnerContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      contactNumber: contactNumber ?? this.contactNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}