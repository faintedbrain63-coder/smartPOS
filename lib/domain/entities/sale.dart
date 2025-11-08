class Sale {
  final int? id;
  final double totalAmount;
  final DateTime saleDate;
  final String? customerName;
  final DateTime? createdAt;
  final double paymentAmount;
  final double changeAmount;
  final String paymentMethod;
  final String transactionStatus;

  const Sale({
    this.id,
    required this.totalAmount,
    required this.saleDate,
    this.customerName,
    this.createdAt,
    this.paymentAmount = 0.0,
    this.changeAmount = 0.0,
    this.paymentMethod = 'cash',
    this.transactionStatus = 'completed',
  });

  Sale copyWith({
    int? id,
    double? totalAmount,
    DateTime? saleDate,
    String? customerName,
    DateTime? createdAt,
    double? paymentAmount,
    double? changeAmount,
    String? paymentMethod,
    String? transactionStatus,
  }) {
    return Sale(
      id: id ?? this.id,
      totalAmount: totalAmount ?? this.totalAmount,
      saleDate: saleDate ?? this.saleDate,
      customerName: customerName ?? this.customerName,
      createdAt: createdAt ?? this.createdAt,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionStatus: transactionStatus ?? this.transactionStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Sale &&
        other.id == id &&
        other.totalAmount == totalAmount &&
        other.saleDate == saleDate &&
        other.customerName == customerName &&
        other.paymentAmount == paymentAmount &&
        other.changeAmount == changeAmount &&
        other.paymentMethod == paymentMethod &&
        other.transactionStatus == transactionStatus;
  }

  @override
  int get hashCode {
    return id.hashCode ^ 
        totalAmount.hashCode ^ 
        saleDate.hashCode ^ 
        customerName.hashCode ^
        paymentAmount.hashCode ^
        changeAmount.hashCode ^
        paymentMethod.hashCode ^
        transactionStatus.hashCode;
  }

  @override
  String toString() {
    return 'Sale(id: $id, total: \$${totalAmount.toStringAsFixed(2)}, date: $saleDate)';
  }
}