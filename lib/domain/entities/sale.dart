class Sale {
  final int? id;
  final double totalAmount;
  final DateTime saleDate;
  final String? customerName;
  final int? customerId;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final double paymentAmount;
  final double changeAmount;
  final String paymentMethod;
  final String transactionStatus;
  final bool isCredit; // true = credit transaction, false = regular sale

  const Sale({
    this.id,
    required this.totalAmount,
    required this.saleDate,
    this.customerName,
    this.customerId,
    this.dueDate,
    this.createdAt,
    this.paymentAmount = 0.0,
    this.changeAmount = 0.0,
    this.paymentMethod = 'cash',
    this.transactionStatus = 'completed',
    this.isCredit = false, // Default to false for regular sales
  });

  Sale copyWith({
    int? id,
    double? totalAmount,
    DateTime? saleDate,
    String? customerName,
    int? customerId,
    DateTime? dueDate,
    DateTime? createdAt,
    double? paymentAmount,
    double? changeAmount,
    String? paymentMethod,
    String? transactionStatus,
    bool? isCredit,
  }) {
    return Sale(
      id: id ?? this.id,
      totalAmount: totalAmount ?? this.totalAmount,
      saleDate: saleDate ?? this.saleDate,
      customerName: customerName ?? this.customerName,
      customerId: customerId ?? this.customerId,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionStatus: transactionStatus ?? this.transactionStatus,
      isCredit: isCredit ?? this.isCredit,
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
        other.transactionStatus == transactionStatus &&
        other.isCredit == isCredit;
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
        transactionStatus.hashCode ^
        isCredit.hashCode;
  }

  @override
  String toString() {
    return 'Sale(id: $id, total: \$${totalAmount.toStringAsFixed(2)}, date: $saleDate)';
  }
}
