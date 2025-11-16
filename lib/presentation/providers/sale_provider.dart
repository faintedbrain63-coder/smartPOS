import 'package:flutter/foundation.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../core/services/notification_service.dart';

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
      print('📊 SALE_PROVIDER: Loading sales...');
      _sales = await _saleRepository.getAllSales();
      print('✅ SALE_PROVIDER: Loaded ${_sales.length} sales');
      notifyListeners();
    } catch (e) {
      print('❌ SALE_PROVIDER: Error loading sales: $e');
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

  /// Comprehensive refresh method that updates all sales-related data
  /// This triggers notifyListeners() which causes all Consumer widgets to rebuild
  Future<void> refreshAllData() async {
    try {
      print('🔄 PROVIDER: Starting comprehensive data refresh...');
      await Future.wait([
        loadSales(),
        loadAnalytics(),
        loadTodaySales(),
        loadDashboardMetrics(), // Load new dashboard metrics
      ]);
      print('✅ PROVIDER: Comprehensive refresh complete - all listeners notified');
    } catch (e) {
      print('❌ PROVIDER: Error during comprehensive refresh: $e');
      _setError('Failed to refresh data: ${e.toString()}');
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

      await refreshAllData(); // Refresh all data across app
      try {
        if (sale.transactionStatus == 'credit' && sale.dueDate != null) {
          NotificationService.instance.scheduleCreditDue(
            saleId: saleId,
            customerName: sale.customerName ?? '',
            amount: sale.totalAmount,
            dueDate: sale.dueDate!,
          );
        }
      } catch (_) {}
      return true;
    } catch (e) {
      _setError('Failed to complete sale: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteSale(int id) async {
    _setError(null);

    try {
      print('📱 PROVIDER: Deleting sale $id with inventory restoration...');
      // Use deleteSaleAndRestoreInventory to restore products to stock
      final result = await _saleRepository.deleteSaleAndRestoreInventory(id);
      if (result) {
        print('📱 PROVIDER: Sale deleted, inventory restored, triggering global refresh...');
        await refreshAllData(); // Refresh all data across app
        print('✅ PROVIDER: Sale $id deleted successfully, inventory restored');
        return true;
      }
      print('❌ PROVIDER: Failed to delete sale $id');
      return false;
    } catch (e) {
      _setError('Failed to delete sale: ${e.toString()}');
      print('❌ PROVIDER: Error deleting sale $id: $e');
      return false;
    }
  }

  /// Edit a regular sale (completed or credit) with inventory adjustments
  Future<bool> editSale(int saleId, Sale updatedSale, List<SaleItem> updatedItems) async {
    _setError(null);
    try {
      print('📱 PROVIDER: Initiating edit for sale $saleId with ${updatedItems.length} items');
      
      // Validate items before sending to repository
      for (final item in updatedItems) {
        if (item.quantity <= 0) {
          _setError('Invalid quantity ${item.quantity} for product ${item.productId}');
          print('❌ PROVIDER: Validation failed - invalid quantity');
          return false;
        }
      }
      
      // For credit sales, use the specialized editCreditSale method
      if (updatedSale.transactionStatus == 'credit') {
        return await editCreditSale(saleId, updatedSale, updatedItems);
      }
      
      // For completed sales, use generic edit with inventory adjustment
      final ok = await _saleRepository.editSale(
        saleId: saleId,
        updatedSale: updatedSale,
        updatedItems: updatedItems,
      );
      
      if (ok) {
        print('📱 PROVIDER: Edit successful, refreshing all data...');
        await refreshAllData();
        print('✅ PROVIDER: EditSale completed - sale=$saleId saved; all data refreshed');
        return true;
      } else {
        _setError('Failed to edit sale $saleId - repository returned false');
        print('❌ PROVIDER: Edit returned false for sale $saleId');
        return false;
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to edit sale: ${e.toString()}';
      _setError(errorMsg);
      print('❌ PROVIDER: Edit exception for sale $saleId');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> deleteCreditSale(int id) async {
    _setError(null);
    try {
      print('📱 PROVIDER: Initiating delete for credit sale $id');
      final ok = await _saleRepository.deleteSaleAndRestoreInventory(id);
      if (ok) {
        print('📱 PROVIDER: Delete successful, refreshing state...');
        await refreshAllData();
        try {
          NotificationService.instance.cancelForSale(id);
          print('📱 PROVIDER: Notification cancelled for sale $id');
        } catch (notifError) {
          print('⚠️ PROVIDER: Failed to cancel notification: $notifError');
        }
        print('✅ PROVIDER: DeleteCredit completed - sale=$id removed; state refreshed');
        return true;
      } else {
        _setError('Failed to delete credit sale $id - repository returned false');
        print('❌ PROVIDER: Delete returned false for sale $id');
        return false;
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to delete credit sale: ${e.toString()}';
      _setError(errorMsg);
      print('❌ PROVIDER: Delete exception for sale $id');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> editCreditSale(int id, Sale updated, List<SaleItem> updatedItems) async {
    _setError(null);
    try {
      print('📱 PROVIDER: Initiating edit for credit sale $id with ${updatedItems.length} items');
      
      // Validate items before sending to repository
      for (final item in updatedItems) {
        if (item.quantity <= 0) {
          _setError('Invalid quantity ${item.quantity} for product ${item.productId}');
          print('❌ PROVIDER: Validation failed - invalid quantity');
          return false;
        }
      }
      
      final ok = await _saleRepository.editCreditSale(saleId: id, updatedSale: updated, updatedItems: updatedItems);
      if (ok) {
        print('📱 PROVIDER: Edit successful, refreshing all data...');
        await refreshAllData();
        
        try {
          if (updated.transactionStatus == 'credit' && updated.dueDate != null) {
            NotificationService.instance.rescheduleCreditDue(
              saleId: id,
              customerName: updated.customerName ?? '',
              amount: updated.totalAmount,
              dueDate: updated.dueDate!,
            );
            print('📱 PROVIDER: Notification rescheduled for sale $id');
          } else {
            NotificationService.instance.cancelForSale(id);
            print('📱 PROVIDER: Notification cancelled for sale $id');
          }
        } catch (notifError) {
          print('⚠️ PROVIDER: Notification operation failed (non-critical): $notifError');
        }
        print('✅ PROVIDER: EditCredit completed - sale=$id saved; inventory adjusted; all data refreshed');
        return true;
      } else {
        _setError('Failed to edit credit sale $id - repository returned false');
        print('❌ PROVIDER: Edit returned false for sale $id');
        return false;
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to edit credit sale: ${e.toString()}';
      _setError(errorMsg);
      print('❌ PROVIDER: Edit exception for sale $id');
      print('Error: $e');
      print('Stack trace: $stackTrace');
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

  // Dashboard metrics
  double _todayUnpaidCredits = 0.0;
  double _totalUnpaidCredits = 0.0;
  double _totalRevenue = 0.0;
  double _todayRevenueAmount = 0.0;

  double get todayTotalSales {
    return todaySalesAmount;
  }

  double get todayCreditAmount {
    return _todayUnpaidCredits;
  }

  double get totalUnpaidCredits {
    return _totalUnpaidCredits;
  }

  double get totalRevenue {
    return _totalRevenue;
  }

  double get todayRevenueAmount {
    return _todayRevenueAmount;
  }

  Future<void> loadDashboardMetrics() async {
    try {
      print('📊 PROVIDER: Loading dashboard metrics...');
      
      final results = await Future.wait([
        _saleRepository.getTodayUnpaidCreditsAmount(),
        _saleRepository.getTotalUnpaidCreditsAmount(),
        _saleRepository.getTotalRevenue(),
        _saleRepository.getTodayRevenueAmount(),
      ]);
      
      _todayUnpaidCredits = results[0];
      _totalUnpaidCredits = results[1];
      _totalRevenue = results[2];
      _todayRevenueAmount = results[3];
      
      print('✅ PROVIDER: Dashboard metrics loaded');
      print('   - Today\'s unpaid credits: \$${_todayUnpaidCredits.toStringAsFixed(2)}');
      print('   - Total unpaid credits: \$${_totalUnpaidCredits.toStringAsFixed(2)}');
      print('   - Total revenue: \$${_totalRevenue.toStringAsFixed(2)}');
      print('   - Today\'s revenue (sales + paid credits): \$${_todayRevenueAmount.toStringAsFixed(2)}');
      
      notifyListeners();
    } catch (e) {
      print('❌ PROVIDER: Error loading dashboard metrics: $e');
      _setError('Failed to load dashboard metrics: ${e.toString()}');
    }
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
