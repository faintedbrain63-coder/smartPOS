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

  @override
  Future<bool> deleteSaleAndRestoreInventory(int saleId) async {
    final db = await _databaseHelper.database;
    try {
      print('🗑️ DELETE CREDIT: Starting deletion for sale_id=$saleId');
      
      // Verify sale exists before attempting deletion
      final saleCheck = await db.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (saleCheck.isEmpty) {
        print('❌ DELETE CREDIT: Sale $saleId does not exist');
        throw Exception('Sale $saleId does not exist');
      }
      
      await db.transaction((txn) async {
        // Business rule: delete must behave as if the credit never existed
        // 1) Restore inventory quantities for all items in this sale
        final items = await txn.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );

        print('🗑️ DELETE CREDIT: Found ${items.length} items to restore');

        if (items.isEmpty) {
          print('⚠️ DELETE CREDIT: No items found for sale $saleId');
        }

        for (final row in items) {
          final productId = row['product_id'] as int;
          final qty = (row['quantity'] as int?) ?? 0;
          if (qty > 0) {
            // First check current stock
            final productRows = await txn.query(
              'products',
              columns: ['stock_quantity', 'name'],
              where: 'id = ?',
              whereArgs: [productId],
            );
            
            if (productRows.isEmpty) {
              print('⚠️ DELETE CREDIT: Product $productId not found, skipping');
              continue;
            }
            
            final currentStock = (productRows.first['stock_quantity'] as int?) ?? 0;
            final productName = productRows.first['name'] as String?;
            
            final updatedCount = await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [qty, productId],
            );
            
            if (updatedCount > 0) {
              print('✅ DELETE CREDIT: Inventory restored for "$productName" (ID: $productId): $currentStock → ${currentStock + qty} (+$qty)');
            } else {
              print('❌ DELETE CREDIT: Failed to update inventory for product $productId');
            }
          }
        }

        // 2) Delete credit payments first (to respect foreign key constraints even though CASCADE should handle it)
        final deletedPayments = await txn.delete(
          'credit_payments',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );
        print('🗑️ DELETE CREDIT: Deleted $deletedPayments payment records');

        // 3) Delete sale items (should cascade, but explicitly delete for clarity)
        final deletedItems = await txn.delete(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );
        print('🗑️ DELETE CREDIT: Deleted $deletedItems sale items');

        // 4) Delete the sale record itself
        final deletedRows = await txn.delete(
          'sales',
          where: 'id = ?',
          whereArgs: [saleId],
        );
        
        if (deletedRows == 0) {
          throw Exception('Failed to delete sale $saleId from sales table');
        }
        
        print('✅ DELETE CREDIT: Sale $saleId deleted from database (affected rows: $deletedRows)');

        // 5) Audit (for traceability)
        try {
          await txn.insert('order_audit', {
            'sale_id': saleId,
            'action': 'deleted',
            'user_info': 'system',
            'details': 'Credit sale deleted and inventory restored: ${items.length} items, $deletedPayments payments',
            'timestamp': DateTime.now().toIso8601String(),
          });
          print('✅ DELETE CREDIT: Audit entry created');
        } catch (auditError) {
          // Audit is optional, don't fail the transaction
          print('⚠️ DELETE CREDIT: Audit failed (non-critical): $auditError');
        }
      });
      
      print('🎉 DELETE CREDIT: Transaction completed successfully for sale_id=$saleId');
      return true;
    } catch (e, stackTrace) {
      print('❌ DELETE CREDIT FAILED for sale_id=$saleId');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  @override
  Future<bool> editCreditSale({required int saleId, required Sale updatedSale, required List<SaleItem> updatedItems}) async {
    final db = await _databaseHelper.database;
    try {
      print('✏️ EDIT CREDIT: Starting edit for sale_id=$saleId with ${updatedItems.length} items');
      
      // Verify sale exists before attempting edit
      final saleCheck = await db.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (saleCheck.isEmpty) {
        print('❌ EDIT CREDIT: Sale $saleId does not exist');
        throw Exception('Sale $saleId does not exist');
      }
      
      // Validate input
      if (updatedItems.isEmpty) {
        print('❌ EDIT CREDIT: Cannot update sale with zero items');
        throw Exception('Sale must have at least one item');
      }
      
      await db.transaction((txn) async {
        // Business rule: edit must persist and adjust inventory by delta in one transaction
        // 1) Load existing quantities for delta computation
        final oldItemRows = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        
        if (oldItemRows.isEmpty) {
          print('⚠️ EDIT CREDIT: Sale $saleId has no items in database');
          throw Exception('Sale $saleId has no items - cannot edit');
        }
        
        final Map<int, int> oldQtyByProduct = {};
        for (final r in oldItemRows) {
          final pid = r['product_id'] as int;
          final qty = (r['quantity'] as int?) ?? 0;
          oldQtyByProduct[pid] = (oldQtyByProduct[pid] ?? 0) + qty;
        }
        print('✏️ EDIT CREDIT: Old quantities: $oldQtyByProduct');

        final Map<int, int> newQtyByProduct = {};
        for (final item in updatedItems) {
          if (item.quantity <= 0) {
            throw Exception('Invalid quantity ${item.quantity} for product ${item.productId}');
          }
          newQtyByProduct[item.productId] = (newQtyByProduct[item.productId] ?? 0) + item.quantity;
        }
        print('✏️ EDIT CREDIT: New quantities: $newQtyByProduct');

        // 2) Apply inventory delta per product
        final Set<int> productIds = {...oldQtyByProduct.keys, ...newQtyByProduct.keys};
        print('✏️ EDIT CREDIT: Processing ${productIds.length} unique products for inventory adjustments');
        
        for (final pid in productIds) {
          final oldQty = oldQtyByProduct[pid] ?? 0;
          final newQty = newQtyByProduct[pid] ?? 0;
          final delta = newQty - oldQty;
          
          if (delta == 0) {
            print('✏️ EDIT CREDIT: Product $pid - no quantity change (qty=$newQty)');
            continue;
          }

          // Get product info for logging and validation
          final productRows = await txn.query(
            'products',
            columns: ['stock_quantity', 'name'],
            where: 'id = ?',
            whereArgs: [pid],
          );
          
          if (productRows.isEmpty) {
            print('❌ EDIT CREDIT: Product $pid not found in database');
            throw Exception('Product ID $pid not found');
          }
          
          final currentStock = (productRows.first['stock_quantity'] as int?) ?? 0;
          final productName = productRows.first['name'] as String?;

          if (delta > 0) {
            // Need more items - reduce stock
            if (currentStock < delta) {
              print('❌ EDIT CREDIT: Insufficient stock for "$productName" (ID: $pid) - need +$delta, have $currentStock');
              throw Exception('Insufficient stock for "$productName" - need $delta more, but only $currentStock available');
            }
            final updatedCount = await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
              [delta, pid],
            );
            if (updatedCount > 0) {
              print('✅ EDIT CREDIT: Stock decreased for "$productName" (ID: $pid): $currentStock → ${currentStock - delta} (-$delta)');
            }
          } else {
            // Need fewer items - increase stock (return to inventory)
            final returnQty = delta.abs();
            final updatedCount = await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [returnQty, pid],
            );
            if (updatedCount > 0) {
              print('✅ EDIT CREDIT: Stock increased for "$productName" (ID: $pid): $currentStock → ${currentStock + returnQty} (+$returnQty)');
            }
          }
        }

        // 3) Recompute sale total from updated items
        double newTotal = 0.0;
        for (final item in updatedItems) {
          newTotal += item.subtotal;
        }
        print('✏️ EDIT CREDIT: New total calculated: $newTotal (from ${updatedItems.length} items)');

        // 4) Persist sale changes
        final updatedMap = SaleModel.fromEntity(
          updatedSale.copyWith(id: saleId, totalAmount: newTotal),
        ).toMap();
        updatedMap.remove('created_at'); // Don't change created_at timestamp

        final updatedRows = await txn.update('sales', updatedMap, where: 'id = ?', whereArgs: [saleId]);
        if (updatedRows == 0) {
          throw Exception('Failed to update sale $saleId in sales table');
        }
        print('✅ EDIT CREDIT: Sale record updated (affected rows: $updatedRows)');

        // 5) Replace items with updated set
        final deletedItems = await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        print('✏️ EDIT CREDIT: Deleted $deletedItems old sale items');
        
        int insertedCount = 0;
        for (final item in updatedItems) {
          final map = SaleItemModel.fromEntity(item.copyWith(saleId: saleId)).toMap();
          map.remove('id'); // Let database auto-generate new IDs
          await txn.insert('sale_items', map);
          insertedCount++;
        }
        print('✅ EDIT CREDIT: Inserted $insertedCount new sale items');

        // 6) Audit
        try {
          final deltasSummary = productIds.map((pid) {
            final oldQ = oldQtyByProduct[pid] ?? 0;
            final newQ = newQtyByProduct[pid] ?? 0;
            final d = newQ - oldQ;
            return 'P$pid: $oldQ→$newQ (${d > 0 ? '+' : ''}$d)';
          }).join(', ');
          
          await txn.insert('order_audit', {
            'sale_id': saleId,
            'action': 'updated',
            'user_info': 'system',
            'details': 'Credit sale edited: $deltasSummary',
            'timestamp': DateTime.now().toIso8601String(),
          });
          print('✅ EDIT CREDIT: Audit entry created with delta summary');
        } catch (auditError) {
          // Audit is optional, don't fail the transaction
          print('⚠️ EDIT CREDIT: Audit failed (non-critical): $auditError');
        }
      });
      
      print('🎉 EDIT CREDIT: Transaction completed successfully for sale_id=$saleId');
      return true;
    } catch (e, stackTrace) {
      print('❌ EDIT CREDIT FAILED for sale_id=$saleId');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
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
  Future<List<Sale>> getCreditSales({String? status}) async {
    final db = await _databaseHelper.database;
    final where = status != null ? 'transaction_status = ?' : 'transaction_status = ?';
    final args = status != null ? [status] : ['credit'];
    final maps = await db.query('sales', where: where, whereArgs: args, orderBy: 'due_date ASC');
    return maps.map((m) => SaleModel.fromMap(m)).toList();
  }

  @override
  Future<double> getCustomerTotalCredit(int customerId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('SELECT COALESCE(SUM(total_amount),0) as total FROM sales WHERE customer_id = ? AND transaction_status = "credit"', [customerId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<double> getCustomerTotalPaid(int customerId) async {
    final db = await _databaseHelper.database;
    final saleInitial = await db.rawQuery('SELECT COALESCE(SUM(payment_amount),0) as total FROM sales WHERE customer_id = ? AND transaction_status = "credit"', [customerId]);
    final payments = await db.rawQuery('SELECT COALESCE(SUM(cp.amount),0) as total FROM credit_payments cp JOIN sales s ON s.id = cp.sale_id WHERE s.customer_id = ? AND s.transaction_status = "credit"', [customerId]);
    final initPaid = (saleInitial.first['total'] as num?)?.toDouble() ?? 0.0;
    final laterPaid = (payments.first['total'] as num?)?.toDouble() ?? 0.0;
    return initPaid + laterPaid;
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerLedger(int customerId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery('''
      SELECT s.id as sale_id, s.total_amount, s.payment_amount, s.due_date, s.sale_date,
             COALESCE((SELECT SUM(amount) FROM credit_payments WHERE sale_id = s.id),0) as later_paid,
             (s.total_amount - s.payment_amount - COALESCE((SELECT SUM(amount) FROM credit_payments WHERE sale_id = s.id),0)) as outstanding
      FROM sales s
      WHERE s.customer_id = ? AND s.transaction_status = 'credit'
      ORDER BY s.sale_date DESC
    ''', [customerId]);
    return rows;
  }

  @override
  Future<int> insertCreditPayment({required int saleId, required double amount, required DateTime paidAt, String? note}) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('credit_payments', {
      'sale_id': saleId,
      'amount': amount,
      'paid_at': paidAt.toIso8601String(),
      'note': note,
    });
    final outstanding = await getOutstandingForSale(saleId);
    if (outstanding <= 0) {
      await db.update('sales', {'transaction_status': 'completed'}, where: 'id = ?', whereArgs: [saleId]);
    }
    return id;
  }

  @override
  Future<double> getOutstandingForSale(int saleId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT (s.total_amount - s.payment_amount - COALESCE(SUM(cp.amount),0)) as outstanding
      FROM sales s
      LEFT JOIN credit_payments cp ON cp.sale_id = s.id
      WHERE s.id = ?
    ''', [saleId]);
    return (result.first['outstanding'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllCreditsWithDetails({bool includeCompleted = false}) async {
    final db = await _databaseHelper.database;
    
    String whereClause = includeCompleted 
        ? 's.transaction_status IN ("credit", "completed")' 
        : 's.transaction_status = "credit"';
    
    final rows = await db.rawQuery('''
      SELECT 
        s.id as sale_id, 
        s.total_amount, 
        s.payment_amount, 
        s.due_date, 
        s.sale_date,
        s.transaction_status,
        s.customer_name,
        s.customer_id,
        s.created_at,
        COALESCE((SELECT SUM(amount) FROM credit_payments WHERE sale_id = s.id),0) as later_paid,
        (s.total_amount - s.payment_amount - COALESCE((SELECT SUM(amount) FROM credit_payments WHERE sale_id = s.id),0)) as outstanding,
        (SELECT MAX(paid_at) FROM credit_payments WHERE sale_id = s.id) as last_payment_date
      FROM sales s
      WHERE $whereClause
      ORDER BY s.sale_date DESC
    ''');
    
    return rows;
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
