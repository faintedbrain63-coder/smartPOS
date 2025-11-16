import '../entities/sale.dart';
import '../entities/sale_item.dart';

abstract class SaleRepository {
  Future<List<Sale>> getAllSales();
  Future<Sale?> getSaleById(int id);
  Future<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate);
  Future<List<Sale>> getSalesToday();
  Future<List<Sale>> getSalesThisWeek();
  Future<List<Sale>> getSalesThisMonth();
  Future<int> insertSale(Sale sale);
  Future<int> updateSale(Sale sale);
  Future<int> deleteSale(int id);
  Future<bool> deleteSaleAndRestoreInventory(int saleId);
  Future<bool> editCreditSale({required int saleId, required Sale updatedSale, required List<SaleItem> updatedItems});
  Future<bool> editSale({required int saleId, required Sale updatedSale, required List<SaleItem> updatedItems});
  
  // Sale Items
  Future<List<SaleItem>> getSaleItems(int saleId);
  Future<int> insertSaleItem(SaleItem saleItem);
  Future<int> updateSaleItem(SaleItem saleItem);
  Future<int> deleteSaleItem(int id);
  
  // Analytics
  Future<double> getTotalSalesAmount({DateTime? startDate, DateTime? endDate});
  Future<int> getTotalSalesCount({DateTime? startDate, DateTime? endDate});
  Future<Map<String, double>> getDailySalesForWeek();
  Future<Map<String, double>> getMonthlySalesForYear();
  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10});
  Future<Map<String, dynamic>> getSalesAnalytics();
  
  // New methods for chart data
  Future<Map<String, double>> getDailySalesForDateRange(DateTime startDate, DateTime endDate);
  Future<Map<String, double>> getMonthlySalesForDateRange(DateTime startDate, DateTime endDate);
  Future<Map<String, double>> getWeeklySalesForDateRange(DateTime startDate, DateTime endDate);
  
  // Profit Analytics methods
  Future<double> getTotalProfitAmount({DateTime? startDate, DateTime? endDate});
  Future<Map<String, double>> getDailyProfitForDateRange(DateTime startDate, DateTime endDate);
  Future<Map<String, double>> getWeeklyProfitForDateRange(DateTime startDate, DateTime endDate);
  Future<Map<String, double>> getMonthlyProfitForDateRange(DateTime startDate, DateTime endDate);
  Future<Map<String, double>> getYearlyProfitForDateRange(DateTime startDate, DateTime endDate);

  Future<List<Sale>> getCreditSales({String? status});
  Future<double> getCustomerTotalCredit(int customerId);
  Future<double> getCustomerTotalPaid(int customerId);
  Future<List<Map<String, dynamic>>> getCustomerLedger(int customerId);
  Future<int> insertCreditPayment({required int saleId, required double amount, required DateTime paidAt, String? note});
  Future<double> getOutstandingForSale(int saleId);
  
  // Enhanced credit queries for tabbed view
  Future<List<Map<String, dynamic>>> getAllCreditsWithDetails({bool includeCompleted = false});
  
  // Dashboard metrics
  Future<double> getTodayUnpaidCreditsAmount();
  Future<double> getTotalUnpaidCreditsAmount();
  Future<double> getTotalRevenue();
  Future<double> getTodayRevenueAmount();
}
