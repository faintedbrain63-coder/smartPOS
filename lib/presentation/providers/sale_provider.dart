import 'package:flutter/foundation.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/sale_repository.dart';

class SaleProvider with ChangeNotifier {
  final SaleRepository _saleRepository;

  SaleProvider(this._saleRepository);

  List<Sale> _sales = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = false;
  String? _error;
  
  // Date range filtering
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, dynamic> _filteredAnalytics = {};

  List<Sale> get sales => _sales;
  Map<String, dynamic> get analytics => _analytics;
  Map<String, dynamic> get filteredAnalytics => _filteredAnalytics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  Future<void> loadSales() async {
    _setLoading(true);
    _setError(null);

    try {
      _sales = await _saleRepository.getAllSales();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load sales: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAnalytics() async {
    _setError(null);

    try {
      _analytics = await _saleRepository.getSalesAnalytics();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load analytics: ${e.toString()}');
    }
  }

  // New method for date range analytics
  Future<void> loadAnalyticsForDateRange(DateTime? startDate, DateTime? endDate) async {
    _setError(null);
    _startDate = startDate;
    _endDate = endDate;

    try {
      if (startDate != null && endDate != null) {
        final totalAmount = await _saleRepository.getTotalSalesAmount(
          startDate: startDate,
          endDate: endDate,
        );
        final totalCount = await _saleRepository.getTotalSalesCount(
          startDate: startDate,
          endDate: endDate,
        );
        
        _filteredAnalytics = {
          'totalSales': totalAmount,
          'totalTransactions': totalCount,
          'startDate': startDate,
          'endDate': endDate,
        };
      } else {
        // If no date range, use regular analytics
        _filteredAnalytics = _analytics;
      }
      notifyListeners();
    } catch (e) {
      _setError('Failed to load filtered analytics: ${e.toString()}');
    }
  }

  // Clear date range filter
  void clearDateRangeFilter() {
    _startDate = null;
    _endDate = null;
    _filteredAnalytics = _analytics;
    notifyListeners();
  }

  Future<void> loadTodaySales() async {
    try {
      await loadSales();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> loadSalesAnalytics() async {
    try {
      await loadAnalytics();
    } catch (e) {
      // Handle error
    }
  }

  Future<List<Sale>> getSalesToday() async {
    try {
      return await _saleRepository.getSalesToday();
    } catch (e) {
      _setError('Failed to load today\'s sales: ${e.toString()}');
      return [];
    }
  }

  Future<List<Sale>> getSalesThisWeek() async {
    try {
      return await _saleRepository.getSalesThisWeek();
    } catch (e) {
      _setError('Failed to load this week\'s sales: ${e.toString()}');
      return [];
    }
  }

  Future<List<Sale>> getSalesThisMonth() async {
    try {
      return await _saleRepository.getSalesThisMonth();
    } catch (e) {
      _setError('Failed to load this month\'s sales: ${e.toString()}');
      return [];
    }
  }

  Future<Map<String, double>> getDailySalesForWeek() async {
    try {
      return await _saleRepository.getDailySalesForWeek();
    } catch (e) {
      _setError('Failed to load daily sales: ${e.toString()}');
      return {};
    }
  }

  Future<Map<String, double>> getMonthlySalesForYear() async {
    try {
      return await _saleRepository.getMonthlySalesForYear();
    } catch (e) {
      _setError('Failed to load monthly sales: ${e.toString()}');
      return {};
    }
  }

  // New methods for chart data based on date range
  Future<Map<String, double>> getDailySalesForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      return await _saleRepository.getDailySalesForDateRange(startDate, endDate);
    } catch (e) {
      _setError('Failed to load daily sales for date range: ${e.toString()}');
      return {};
    }
  }

  Future<Map<String, double>> getMonthlySalesForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      return await _saleRepository.getMonthlySalesForDateRange(startDate, endDate);
    } catch (e) {
      _setError('Failed to load monthly sales for date range: ${e.toString()}');
      return {};
    }
  }

  Future<Map<String, double>> getWeeklySalesForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      return await _saleRepository.getWeeklySalesForDateRange(startDate, endDate);
    } catch (e) {
      _setError('Failed to load weekly sales for date range: ${e.toString()}');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10}) async {
    try {
      return await _saleRepository.getTopSellingProducts(limit: limit);
    } catch (e) {
      _setError('Failed to load top selling products: ${e.toString()}');
      return [];
    }
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    try {
      return await _saleRepository.getSaleItems(saleId);
    } catch (e) {
      _setError('Failed to load sale items: ${e.toString()}');
      return [];
    }
  }

  Future<bool> completeSale(Sale sale, List<SaleItem> saleItems) async {
    _setError(null);

    try {
      // Insert the sale
      final saleId = await _saleRepository.insertSale(sale);
      if (saleId <= 0) {
        _setError('Failed to create sale');
        return false;
      }

      // Insert all sale items
      for (final item in saleItems) {
        final updatedItem = item.copyWith(saleId: saleId);
        await _saleRepository.insertSaleItem(updatedItem);
      }

      await loadSales(); // Reload sales list
      await loadAnalytics(); // Reload analytics
      return true;
    } catch (e) {
      _setError('Failed to complete sale: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteSale(int id) async {
    _setError(null);

    try {
      final result = await _saleRepository.deleteSale(id);
      if (result > 0) {
        await loadSales(); // Reload to get updated list
        await loadAnalytics(); // Reload analytics
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to delete sale: ${e.toString()}');
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Computed properties for analytics
  double get totalSalesAmount {
    return _sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  int get totalSalesCount {
    return _sales.length;
  }

  double get todaySalesAmount {
    final today = DateTime.now();
    final todaySales = _sales.where((sale) {
      return sale.createdAt != null &&
             sale.createdAt!.year == today.year &&
             sale.createdAt!.month == today.month &&
             sale.createdAt!.day == today.day;
    });
    return todaySales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  int get todaySalesCount {
    final today = DateTime.now();
    final todaySales = _sales.where((sale) {
      return sale.createdAt != null &&
             sale.createdAt!.year == today.year &&
             sale.createdAt!.month == today.month &&
             sale.createdAt!.day == today.day;
    });
    return todaySales.length;
  }

  double get todayTotalSales {
    return todaySalesAmount;
  }

  // Sales Analytics methods
  Future<double> getTotalSalesAmount({DateTime? startDate, DateTime? endDate}) async {
    try {
      return await _saleRepository.getTotalSalesAmount(startDate: startDate, endDate: endDate);
    } catch (e) {
      _setError('Failed to load total sales amount: ${e.toString()}');
      return 0.0;
    }
  }

  // Profit Analytics methods
  Future<double> getTotalProfitAmount({DateTime? startDate, DateTime? endDate}) async {
    try {
      return await _saleRepository.getTotalProfitAmount(startDate: startDate, endDate: endDate);
    } catch (e) {
      _setError('Failed to load total profit: ${e.toString()}');
      return 0.0;
    }
  }

  Future<Map<String, double>> getDailyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      return await _saleRepository.getDailyProfitForDateRange(startDate, endDate);
    } catch (e) {
      _setError('Failed to load daily profit for date range: ${e.toString()}');
      return {};
    }
  }

  Future<Map<String, double>> getWeeklyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      return await _saleRepository.getWeeklyProfitForDateRange(startDate, endDate);
    } catch (e) {
      _setError('Failed to load weekly profit for date range: ${e.toString()}');
      return {};
    }
  }

  Future<Map<String, double>> getMonthlyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      return await _saleRepository.getMonthlyProfitForDateRange(startDate, endDate);
    } catch (e) {
      _setError('Failed to load monthly profit for date range: ${e.toString()}');
      return {};
    }
  }

  Future<Map<String, double>> getYearlyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      return await _saleRepository.getYearlyProfitForDateRange(startDate, endDate);
    } catch (e) {
      _setError('Failed to load yearly profit for date range: ${e.toString()}');
      return {};
    }
  }

  // Computed properties for profit analytics
  Future<double> get todayProfitAmount async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return await getTotalProfitAmount(startDate: startOfDay, endDate: endOfDay);
  }
}