import '../../domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    super.id,
    required super.name,
    super.imagePath,
    required super.categoryId,
    required super.costPrice,
    required super.sellingPrice,
    super.barcode,
    required super.stockQuantity,
    super.description,
    super.createdAt,
    super.updatedAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      imagePath: map['image_path'],
      categoryId: map['category_id']?.toInt() ?? 0,
      costPrice: map['cost_price']?.toDouble() ?? 0.0,
      sellingPrice: map['selling_price']?.toDouble() ?? 0.0,
      barcode: map['barcode'],
      stockQuantity: map['stock_quantity']?.toInt() ?? 0,
      description: map['description'],
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
      'image_path': imagePath,
      'category_id': categoryId,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'barcode': barcode,
      'stock_quantity': stockQuantity,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      imagePath: product.imagePath,
      categoryId: product.categoryId,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      barcode: product.barcode,
      stockQuantity: product.stockQuantity,
      description: product.description,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    );
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? imagePath,
    int? categoryId,
    double? costPrice,
    double? sellingPrice,
    String? barcode,
    int? stockQuantity,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      categoryId: categoryId ?? this.categoryId,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      barcode: barcode ?? this.barcode,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}