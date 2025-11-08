import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/database_helper.dart';
import '../models/sale_model.dart';
import '../models/sale_item_model.dart';

class SaleRepositoryImpl implements SaleRepository {
  final DatabaseHelper _databaseHelper;

  SaleRepositoryImpl(this._databaseHelper);

  @override
  Future<List<Sale>> getAllSales() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      orderBy: 'sale_date DESC',
    );

    return List.generate(maps.length, (i) {
      return SaleModel.fromMap(maps[i]);
    });
  }

  @override
  Future<Sale?> getSaleById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SaleModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'DATE(sale_date) BETWEEN DATE(?) AND DATE(?)',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'sale_date DESC',
    );

    return List.generate(maps.length, (i) {
      return SaleModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<Sale>> getSalesToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    return getSalesByDateRange(startOfDay, endOfDay);
  }

  @override
  Future<List<Sale>> getSalesThisWeek() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return getSalesByDateRange(startOfWeek, endOfWeek);
  }

  @override
  Future<List<Sale>> getSalesThisMonth() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    return getSalesByDateRange(startOfMonth, endOfMonth);
  }

  @override
  Future<int> insertSale(Sale sale) async {
    final db = await _databaseHelper.database;
    final saleModel = SaleModel.fromEntity(sale);
    final now = DateTime.now().toIso8601String();
    
    final map = saleModel.toMap();
    map['created_at'] = now;
    map.remove('id'); // Remove id for auto-increment

    return await db.insert('sales', map);
  }

  @override
  Future<int> updateSale(Sale sale) async {
    final db = await _databaseHelper.database;
    final saleModel = SaleModel.fromEntity(sale);
    
    final map = saleModel.toMap();
    map.remove('created_at'); // Don't update created_at

    return await db.update(
      'sales',
      map,
      where: 'id = ?',
      whereArgs: [sale.id],
    );
  }

  @override
  Future<int> deleteSale(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Sale Items
  @override
  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );

    return List.generate(maps.length, (i) {
      return SaleItemModel.fromMap(maps[i]);
    });
  }

  @override
  Future<int> insertSaleItem(SaleItem saleItem) async {
    final db = await _databaseHelper.database;
    final saleItemModel = SaleItemModel.fromEntity(saleItem);
    
    final map = saleItemModel.toMap();
    map.remove('id'); // Remove id for auto-increment

    return await db.insert('sale_items', map);
  }

  @override
  Future<int> updateSaleItem(SaleItem saleItem) async {
    final db = await _databaseHelper.database;
    final saleItemModel = SaleItemModel.fromEntity(saleItem);

    return await db.update(
      'sale_items',
      saleItemModel.toMap(),
      where: 'id = ?',
      whereArgs: [saleItem.id],
    );
  }

  @override
  Future<int> deleteSaleItem(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'sale_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Analytics
  @override
  Future<double> getTotalSalesAmount({DateTime? startDate, DateTime? endDate}) async {
    final db = await _databaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE DATE(sale_date) BETWEEN DATE(?) AND DATE(?)';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }
    
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM sales $whereClause',
      whereArgs,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<int> getTotalSalesCount({DateTime? startDate, DateTime? endDate}) async {
    final db = await _databaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE DATE(sale_date) BETWEEN DATE(?) AND DATE(?)';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sales $whereClause',
      whereArgs,
    );

    return (result.first['count'] as int?) ?? 0;
  }

  @override
  Future<Map<String, double>> getDailySalesForWeek() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: 6));
    
    final result = await db.rawQuery('''
      SELECT DATE(sale_date) as date, COALESCE(SUM(total_amount), 0) as total
      FROM sales 
      WHERE DATE(sale_date) >= DATE(?)
      GROUP BY DATE(sale_date)
      ORDER BY DATE(sale_date)
    ''', [startOfWeek.toIso8601String()]);

    final Map<String, double> dailySales = {};
    
    // Initialize all days with 0
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailySales[dateStr] = 0.0;
    }
    
    // Fill in actual sales data
    for (final row in result) {
      final dateStr = row['date'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      dailySales[dateStr] = total;
    }

    return dailySales;
  }

  @override
  Future<Map<String, double>> getMonthlySalesForYear() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    
    final result = await db.rawQuery('''
      SELECT strftime('%Y-%m', sale_date) as month, COALESCE(SUM(total_amount), 0) as total
      FROM sales 
      WHERE DATE(sale_date) >= DATE(?)
      GROUP BY strftime('%Y-%m', sale_date)
      ORDER BY strftime('%Y-%m', sale_date)
    ''', [startOfYear.toIso8601String()]);

    final Map<String, double> monthlySales = {};
    
    // Initialize all months with 0
    for (int i = 1; i <= 12; i++) {
      final monthStr = '${now.year}-${i.toString().padLeft(2, '0')}';
      monthlySales[monthStr] = 0.0;
    }
    
    // Fill in actual sales data
    for (final row in result) {
      final monthStr = row['month'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      monthlySales[monthStr] = total;
    }

    return monthlySales;
  }

  @override
  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10}) async {
    final db = await _databaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.selling_price,
        SUM(si.quantity) as total_sold,
        SUM(si.subtotal) as total_revenue
      FROM products p
      INNER JOIN sale_items si ON p.id = si.product_id
      GROUP BY p.id, p.name, p.selling_price
      ORDER BY total_sold DESC
      LIMIT ?
    ''', [limit]);

    return result;
  }

  @override
  Future<Map<String, dynamic>> getSalesAnalytics() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    
    // Today's sales
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todaySales = await getTotalSalesAmount(startDate: todayStart, endDate: todayEnd);
    final todayCount = await getTotalSalesCount(startDate: todayStart, endDate: todayEnd);
    
    // This week's sales
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekSales = await getTotalSalesAmount(startDate: weekStart, endDate: weekEnd);
    
    // This month's sales
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final monthSales = await getTotalSalesAmount(startDate: monthStart, endDate: monthEnd);
    
    // Total products sold today
    final todayProductsSold = await db.rawQuery('''
      SELECT COALESCE(SUM(si.quantity), 0) as total
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      WHERE DATE(s.sale_date) = DATE(?)
    ''', [now.toIso8601String()]);
    
    final productsSoldToday = (todayProductsSold.first['total'] as int?) ?? 0;

    return {
      'todaySales': todaySales,
      'todayTransactions': todayCount,
      'todayProductsSold': productsSoldToday,
      'weekSales': weekSales,
      'monthSales': monthSales,
    };
  }

  @override
  Future<Map<String, double>> getDailySalesForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _databaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT DATE(sale_date) as date, COALESCE(SUM(total_amount), 0) as total
      FROM sales 
      WHERE DATE(sale_date) BETWEEN DATE(?) AND DATE(?)
      GROUP BY DATE(sale_date)
      ORDER BY DATE(sale_date)
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final Map<String, double> dailySales = {};
    
    // Initialize all days in the range with 0
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final dateStr = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      dailySales[dateStr] = 0.0;
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Fill in actual sales data
    for (final row in result) {
      final dateStr = row['date'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      dailySales[dateStr] = total;
    }

    return dailySales;
  }

  @override
  Future<Map<String, double>> getMonthlySalesForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _databaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT strftime('%Y-%m', sale_date) as month, COALESCE(SUM(total_amount), 0) as total
      FROM sales 
      WHERE DATE(sale_date) BETWEEN DATE(?) AND DATE(?)
      GROUP BY strftime('%Y-%m', sale_date)
      ORDER BY strftime('%Y-%m', sale_date)
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final Map<String, double> monthlySales = {};
    
    // Initialize all months in the range with 0
    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
    final endMonth = DateTime(endDate.year, endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth.add(const Duration(days: 32))) || 
           currentMonth.isAtSameMomentAs(endMonth)) {
      final monthStr = '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}';
      monthlySales[monthStr] = 0.0;
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    
    // Fill in actual sales data
    for (final row in result) {
      final monthStr = row['month'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      monthlySales[monthStr] = total;
    }

    return monthlySales;
  }

  @override
  Future<Map<String, double>> getWeeklySalesForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _databaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        strftime('%Y-%W', sale_date) as week,
        COALESCE(SUM(total_amount), 0) as total
      FROM sales 
      WHERE DATE(sale_date) BETWEEN DATE(?) AND DATE(?)
      GROUP BY strftime('%Y-%W', sale_date)
      ORDER BY strftime('%Y-%W', sale_date)
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final Map<String, double> weeklySales = {};
    
    // Initialize all weeks in the range with 0
    DateTime currentWeek = _getStartOfWeek(startDate);
    final endWeek = _getStartOfWeek(endDate);
    
    while (currentWeek.isBefore(endWeek.add(const Duration(days: 7))) || 
           currentWeek.isAtSameMomentAs(endWeek)) {
      final weekStr = 'Week ${_getWeekNumber(currentWeek)}';
      weeklySales[weekStr] = 0.0;
      currentWeek = currentWeek.add(const Duration(days: 7));
    }
    
    // Fill in actual sales data
    int weekIndex = 1;
    for (final row in result) {
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      weeklySales['Week $weekIndex'] = total;
      weekIndex++;
    }

    return weeklySales;
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  int _getWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final daysDifference = date.difference(startOfYear).inDays;
    return (daysDifference / 7).ceil();
  }

  // Profit Analytics methods implementation
  @override
  Future<double> getTotalProfitAmount({DateTime? startDate, DateTime? endDate}) async {
    final db = await _databaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE DATE(s.sale_date) BETWEEN DATE(?) AND DATE(?)';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }
    
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM((si.unit_price - p.cost_price) * si.quantity), 0) as total_profit
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      INNER JOIN products p ON si.product_id = p.id
      $whereClause
    ''', whereArgs);

    return (result.first['total_profit'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<Map<String, double>> getDailyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _databaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        DATE(s.sale_date) as date, 
        COALESCE(SUM((si.unit_price - p.cost_price) * si.quantity), 0) as total_profit
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      INNER JOIN products p ON si.product_id = p.id
      WHERE DATE(s.sale_date) BETWEEN DATE(?) AND DATE(?)
      GROUP BY DATE(s.sale_date)
      ORDER BY DATE(s.sale_date)
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final Map<String, double> dailyProfit = {};
    
    // Initialize all days in the range with 0
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final dateStr = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      dailyProfit[dateStr] = 0.0;
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Fill in actual profit data
    for (final row in result) {
      final dateStr = row['date'] as String;
      final profit = (row['total_profit'] as num?)?.toDouble() ?? 0.0;
      dailyProfit[dateStr] = profit;
    }

    return dailyProfit;
  }

  @override
  Future<Map<String, double>> getWeeklyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _databaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        strftime('%Y-%W', s.sale_date) as week,
        COALESCE(SUM((si.unit_price - p.cost_price) * si.quantity), 0) as total_profit
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      INNER JOIN products p ON si.product_id = p.id
      WHERE DATE(s.sale_date) BETWEEN DATE(?) AND DATE(?)
      GROUP BY strftime('%Y-%W', s.sale_date)
      ORDER BY strftime('%Y-%W', s.sale_date)
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final Map<String, double> weeklyProfit = {};
    
    // Initialize all weeks in the range with 0
    DateTime currentWeek = _getStartOfWeek(startDate);
    final endWeek = _getStartOfWeek(endDate);
    
    while (currentWeek.isBefore(endWeek.add(const Duration(days: 7))) || 
           currentWeek.isAtSameMomentAs(endWeek)) {
      final weekStr = 'Week ${_getWeekNumber(currentWeek)}';
      weeklyProfit[weekStr] = 0.0;
      currentWeek = currentWeek.add(const Duration(days: 7));
    }
    
    // Fill in actual profit data
    int weekIndex = 1;
    for (final row in result) {
      final profit = (row['total_profit'] as num?)?.toDouble() ?? 0.0;
      weeklyProfit['Week $weekIndex'] = profit;
      weekIndex++;
    }

    return weeklyProfit;
  }

  @override
  Future<Map<String, double>> getMonthlyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _databaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', s.sale_date) as month, 
        COALESCE(SUM((si.unit_price - p.cost_price) * si.quantity), 0) as total_profit
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      INNER JOIN products p ON si.product_id = p.id
      WHERE DATE(s.sale_date) BETWEEN DATE(?) AND DATE(?)
      GROUP BY strftime('%Y-%m', s.sale_date)
      ORDER BY strftime('%Y-%m', s.sale_date)
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final Map<String, double> monthlyProfit = {};
    
    // Initialize all months in the range with 0
    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
    final endMonth = DateTime(endDate.year, endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth.add(const Duration(days: 32))) || 
           currentMonth.isAtSameMomentAs(endMonth)) {
      final monthStr = '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}';
      monthlyProfit[monthStr] = 0.0;
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    
    // Fill in actual profit data
    for (final row in result) {
      final monthStr = row['month'] as String;
      final profit = (row['total_profit'] as num?)?.toDouble() ?? 0.0;
      monthlyProfit[monthStr] = profit;
    }

    return monthlyProfit;
  }

  @override
  Future<Map<String, double>> getYearlyProfitForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _databaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        strftime('%Y', s.sale_date) as year, 
        COALESCE(SUM((si.unit_price - p.cost_price) * si.quantity), 0) as total_profit
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      INNER JOIN products p ON si.product_id = p.id
      WHERE DATE(s.sale_date) BETWEEN DATE(?) AND DATE(?)
      GROUP BY strftime('%Y', s.sale_date)
      ORDER BY strftime('%Y', s.sale_date)
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final Map<String, double> yearlyProfit = {};
    
    // Initialize all years in the range with 0
    for (int year = startDate.year; year <= endDate.year; year++) {
      yearlyProfit[year.toString()] = 0.0;
    }
    
    // Fill in actual profit data
    for (final row in result) {
      final yearStr = row['year'] as String;
      final profit = (row['total_profit'] as num?)?.toDouble() ?? 0.0;
      yearlyProfit[yearStr] = profit;
    }

    return yearlyProfit;
  }
}