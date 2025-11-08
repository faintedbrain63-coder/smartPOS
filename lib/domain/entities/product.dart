class Product {
  final int? id;
  final String name;
  final String? imagePath;
  final int categoryId;
  final double costPrice;
  final double sellingPrice;
  final String? barcode;
  final int stockQuantity;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    this.id,
    required this.name,
    this.imagePath,
    required this.categoryId,
    required this.costPrice,
    required this.sellingPrice,
    this.barcode,
    required this.stockQuantity,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  Product copyWith({
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
    return Product(
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

  double get profit => sellingPrice - costPrice;
  double get profitMargin => profit / sellingPrice * 100;
  bool get isLowStock => stockQuantity <= 10;
  bool get isOutOfStock => stockQuantity <= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.id == id &&
        other.name == name &&
        other.barcode == barcode;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ barcode.hashCode;
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: \$${sellingPrice.toStringAsFixed(2)}, stock: $stockQuantity)';
  }
}