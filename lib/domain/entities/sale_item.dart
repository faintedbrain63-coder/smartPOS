class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  SaleItem copyWith({
    int? id,
    int? saleId,
    int? productId,
    int? quantity,
    double? unitPrice,
    double? subtotal,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaleItem &&
        other.id == id &&
        other.saleId == saleId &&
        other.productId == productId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ saleId.hashCode ^ productId.hashCode;
  }

  @override
  String toString() {
    return 'SaleItem(id: $id, productId: $productId, qty: $quantity, subtotal: \$${subtotal.toStringAsFixed(2)})';
  }
}