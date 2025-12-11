import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sale_item.dart';
import '../../../domain/repositories/sale_repository.dart';

/// Remote implementation of SaleRepository that queries the server
class RemoteSaleRepository implements SaleRepository {
  final String serverUrl;
  final String apiKey;

  RemoteSaleRepository({required this.serverUrl, required this.apiKey});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  List<Sale>? _cachedSales;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(seconds: 5);

  Sale _saleFromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as int?,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      saleDate: json['sale_date'] != null 
          ? DateTime.parse(json['sale_date'].toString()) 
          : (json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now()),
      customerName: json['customer_name'] as String?,
      customerId: json['customer_id'] as int?,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      paymentAmount: (json['payment_amount'] ?? 0).toDouble(),
      changeAmount: (json['change_amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      transactionStatus: json['status'] ?? json['transaction_status'] ?? 'completed',
      isCredit: json['is_credit'] == 1 || json['is_credit'] == true,
    );
  }

  Future<List<Sale>> _fetchAllSales() async {
    // Simple cache to avoid too many requests
    if (_cachedSales != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedSales!;
    }

    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/sales'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final salesList = data['sales'] as List;
        _cachedSales = salesList.map((s) => _saleFromJson(s as Map<String, dynamic>)).toList();
        _cacheTime = DateTime.now();
        return _cachedSales!;
      }
      throw Exception('Failed to get sales: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteSaleRepository._fetchAllSales error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Sale>> getAllSales() async => _fetchAllSales();

  @override
  Future<Sale?> getSaleById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/sales/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _saleFromJson(data['sale'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to get sale: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteSaleRepository.getSaleById error: $e');
      rethrow;
    }
  }

  // Store pending items to be sent with the sale
  List<SaleItem>? _pendingItems;
  
  /// Set items to be included when inserting sale (for atomic operation)
  void setPendingItems(List<SaleItem> items) {
    _pendingItems = items;
  }
  
  @override
  Future<int> insertSale(Sale sale) async {
    try {
      // Convert pending items to JSON format
      final itemsJson = _pendingItems?.map((item) => {
        'product_id': item.productId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'subtotal': item.subtotal,
      }).toList() ?? [];
      
      final saleData = {
        'customer_id': sale.customerId,
        'customer_name': sale.customerName,
        'total_amount': sale.totalAmount,
        'payment_amount': sale.paymentAmount,
        'change_amount': sale.changeAmount,
        'payment_method': sale.paymentMethod,
        'transaction_status': sale.transactionStatus,
        'sale_date': sale.saleDate.toIso8601String(),
        'due_date': sale.dueDate?.toIso8601String(),
        'is_credit': sale.isCredit,
        'items': itemsJson, // Include items for atomic creation + stock update
      };
      
      print('📤 Sending sale to server with ${itemsJson.length} items: $saleData');
      
      // Clear pending items
      _pendingItems = null;
      
      final response = await http.post(
        Uri.parse('$serverUrl/api/sales'),
        headers: _headers,
        body: jsonEncode(saleData),
      ).timeout(const Duration(seconds: 15));

      print('📥 Server response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        _cachedSales = null; // Invalidate cache
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int;
      }
      throw Exception('Failed to create sale: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteSaleRepository.insertSale error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate) async {
    final all = await _fetchAllSales();
    return all.where((s) {
      final saleDate = s.createdAt ?? s.saleDate;
      return saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             saleDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Future<List<Sale>> getSalesToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return getSalesByDateRange(start, now);
  }

  @override
  Future<List<Sale>> getSalesThisWeek() async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    return getSalesByDateRange(DateTime(start.year, start.month, start.day), now);
  }

  @override
  Future<List<Sale>> getSalesThisMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return getSalesByDateRange(start, now);
  }

  @override
  Future<int> updateSale(Sale sale) async {
    throw UnimplementedError('Sale updates should be done on server');
  }

  @override
  Future<int> deleteSale(int id) async {
    throw UnimplementedError('Sale deletes should be done on server');
  }

  @override
  Future<bool> deleteSaleAndRestoreInventory(int saleId) async {
    throw UnimplementedError('Not supported on thin client');
  }

  @override
  Future<bool> editCreditSale({required int saleId, required Sale updatedSale, required List<SaleItem> updatedItems}) async {
    throw UnimplementedError('Not supported on thin client');
  }

  @override
  Future<bool> editSale({required int saleId, required Sale updatedSale, required List<SaleItem> updatedItems}) async {
    throw UnimplementedError('Not supported on thin client');
  }

  @override
  Future<List<SaleItem>> getSaleItems(int saleId) async {
    return []; // Sale items would need their own endpoint
  }

  @override
  Future<int> insertSaleItem(SaleItem saleItem) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/sale_items'),
        headers: _headers,
        body: jsonEncode({
          'sale_id': saleItem.saleId,
          'product_id': saleItem.productId,
          'quantity': saleItem.quantity,
          'unit_price': saleItem.unitPrice,
          'subtotal': saleItem.subtotal,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int;
      }
      throw Exception('Failed to create sale item: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteSaleRepository.insertSaleItem error: $e');
      rethrow;
    }
  }

  @override
  Future<int> updateSaleItem(SaleItem saleItem) async {
    throw UnimplementedError('Not supported on thin client');
  }

  @override
  Future<int> deleteSaleItem(int id) async {
    throw UnimplementedError('Not supported on thin client');
  }

  // Analytics - computed client-side from fetched data
  @override
  Future<double> getTotalSalesAmount({DateTime? startDate, DateTime? endDate}) async {
    final sales = startDate != null && endDate != null 
        ? await getSalesByDateRange(startDate, endDate)
        : await _fetchAllSales();
    return sales.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  @override
  Future<int> getTotalSalesCount({DateTime? startDate, DateTime? endDate}) async {
    final sales = startDate != null && endDate != null 
        ? await getSalesByDateRange(startDate, endDate)
        : await _fetchAllSales();
    return sales.length;
  }

  @override
  Future<Map<String, double>> getDailySalesForWeek() async {
    final result = <String, double>{};
    final sales = await getSalesThisWeek();
    for (final sale in sales) {
      final saleDate = sale.createdAt ?? sale.saleDate;
      final dayKey = '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}-${saleDate.day.toString().padLeft(2, '0')}';
      result[dayKey] = (result[dayKey] ?? 0) + sale.totalAmount;
    }
    return result;
  }

  @override
  Future<Map<String, double>> getMonthlySalesForYear() async {
    final result = <String, double>{};
    final now = DateTime.now();
    final sales = await getSalesByDateRange(DateTime(now.year, 1, 1), now);
    for (final sale in sales) {
      final saleDate = sale.createdAt ?? sale.saleDate;
      final monthKey = '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}';
      result[monthKey] = (result[monthKey] ?? 0) + sale.totalAmount;
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10}) async {
    return []; // Would need aggregation on server
  }

  @override
  Future<Map<String, dynamic>> getSalesAnalytics() async {
    final today = await getSalesToday();
    final thisWeek = await getSalesThisWeek();
    final thisMonth = await getSalesThisMonth();
    return {
      'today_count': today.length,
      'today_amount': today.fold<double>(0, (s, sale) => s + sale.totalAmount),
      'week_count': thisWeek.length,
      'week_amount': thisWeek.fold<double>(0, (s, sale) => s + sale.totalAmount),
      'month_count': thisMonth.length,
      'month_amount': thisMonth.fold<double>(0, (s, sale) => s + sale.totalAmount),
    };
  }

  @override
  Future<Map<String, double>> getDailySalesForDateRange(DateTime startDate, DateTime endDate) async {
    final result = <String, double>{};
    final sales = await getSalesByDateRange(startDate, endDate);
    for (final sale in sales) {
      final saleDate = sale.createdAt ?? sale.saleDate;
      final dayKey = '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}-${saleDate.day.toString().padLeft(2, '0')}';
      result[dayKey] = (result[dayKey] ?? 0) + sale.totalAmount;
    }
    return result;
  }

  @override
  Future<Map<String, double>> getMonthlySalesForDateRange(DateTime startDate, DateTime endDate) async {
    final result = <String, double>{};
    final sales = await getSalesByDateRange(startDate, endDate);
    for (final sale in sales) {
      final saleDate = sale.createdAt ?? sale.saleDate;
      final monthKey = '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}';
      result[monthKey] = (result[monthKey] ?? 0) + sale.totalAmount;
    }
    return result;
  }

  @override
  Future<Map<String, double>> getWeeklySalesForDateRange(DateTime startDate, DateTime endDate) async {
    return getDailySalesForDateRange(startDate, endDate);
  }

  @override
  Future<double> getTotalProfitAmount({DateTime? startDate, DateTime? endDate}) async {
    return 0; // Would need cost data
  }

  @override
  Future<Map<String, double>> getDailyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    return {};
  }

  @override
  Future<Map<String, double>> getWeeklyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    return {};
  }

  @override
  Future<Map<String, double>> getMonthlyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    return {};
  }

  @override
  Future<Map<String, double>> getYearlyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    return {};
  }

  @override
  Future<List<Sale>> getCreditSales({String? status}) async {
    final all = await _fetchAllSales();
    return all.where((s) => s.isCredit && (status == null || s.transactionStatus == status)).toList();
  }

  @override
  Future<double> getCustomerTotalCredit(int customerId) async {
    final all = await _fetchAllSales();
    return all.where((s) => s.customerId == customerId && s.isCredit)
        .fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  @override
  Future<double> getCustomerTotalPaid(int customerId) async {
    return 0; // Would need payment tracking
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerLedger(int customerId) async {
    return [];
  }

  @override
  Future<int> insertCreditPayment({required int saleId, required double amount, required DateTime paidAt, String? note}) async {
    throw UnimplementedError('Not supported on thin client');
  }

  @override
  Future<double> getOutstandingForSale(int saleId) async {
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllCreditsWithDetails({bool includeCompleted = false}) async {
    return [];
  }

  @override
  Future<double> getTodayUnpaidCreditsAmount() async {
    return 0;
  }

  @override
  Future<double> getTotalUnpaidCreditsAmount() async {
    return 0;
  }

  @override
  Future<double> getTotalRevenue() async {
    final all = await _fetchAllSales();
    return all.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  @override
  Future<double> getTodayRevenueAmount() async {
    final today = await getSalesToday();
    return today.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }
}
