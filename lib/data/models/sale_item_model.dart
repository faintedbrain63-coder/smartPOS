import '../../domain/entities/sale_item.dart';

class SaleItemModel extends SaleItem {
  const SaleItemModel({
    super.id,
    required super.saleId,
    required super.productId,
    required super.quantity,
    required super.unitPrice,
    required super.subtotal,
  });

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      id: map['id']?.toInt(),
      saleId: map['sale_id']?.toInt() ?? 0,
      productId: map['product_id']?.toInt() ?? 0,
      quantity: map['quantity']?.toInt() ?? 0,
      unitPrice: map['unit_price']?.toDouble() ?? 0.0,
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }

  factory SaleItemModel.fromEntity(SaleItem saleItem) {
    return SaleItemModel(
      id: saleItem.id,
      saleId: saleItem.saleId,
      productId: saleItem.productId,
      quantity: saleItem.quantity,
      unitPrice: saleItem.unitPrice,
      subtotal: saleItem.subtotal,
    );
  }

  @override
  SaleItemModel copyWith({
    int? id,
    int? saleId,
    int? productId,
    int? quantity,
    double? unitPrice,
    double? subtotal,
  }) {
    return SaleItemModel(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}