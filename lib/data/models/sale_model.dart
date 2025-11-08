import '../../domain/entities/sale.dart';

class SaleModel extends Sale {
  const SaleModel({
    super.id,
    required super.totalAmount,
    super.customerName,
    required super.saleDate,
    super.createdAt,
    super.paymentAmount = 0.0,
    super.changeAmount = 0.0,
    super.paymentMethod = 'cash',
    super.transactionStatus = 'completed',
  });

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    return SaleModel(
      id: map['id']?.toInt(),
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      customerName: map['customer_name'],
      saleDate: DateTime.parse(map['sale_date']),
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'])
          : null,
      paymentAmount: map['payment_amount']?.toDouble() ?? 0.0,
      changeAmount: map['change_amount']?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] ?? 'cash',
      transactionStatus: map['transaction_status'] ?? 'completed',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total_amount': totalAmount,
      'customer_name': customerName,
      'sale_date': saleDate.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'payment_amount': paymentAmount,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'transaction_status': transactionStatus,
    };
  }

  factory SaleModel.fromEntity(Sale sale) {
    return SaleModel(
      id: sale.id,
      totalAmount: sale.totalAmount,
      customerName: sale.customerName,
      saleDate: sale.saleDate,
      createdAt: sale.createdAt,
      paymentAmount: sale.paymentAmount,
      changeAmount: sale.changeAmount,
      paymentMethod: sale.paymentMethod,
      transactionStatus: sale.transactionStatus,
    );
  }

  @override
  SaleModel copyWith({
    int? id,
    double? totalAmount,
    String? customerName,
    DateTime? saleDate,
    DateTime? createdAt,
    double? paymentAmount,
    double? changeAmount,
    String? paymentMethod,
    String? transactionStatus,
  }) {
    return SaleModel(
      id: id ?? this.id,
      totalAmount: totalAmount ?? this.totalAmount,
      customerName: customerName ?? this.customerName,
      saleDate: saleDate ?? this.saleDate,
      createdAt: createdAt ?? this.createdAt,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionStatus: transactionStatus ?? this.transactionStatus,
    );
  }
}