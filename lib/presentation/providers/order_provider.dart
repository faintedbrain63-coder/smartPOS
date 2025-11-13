import 'package:flutter/foundation.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/sale_repository.dart';


enum OrderStatus {
  all,
  completed,
  voided,
}

enum OrderSortBy {
  dateNewest,
  dateOldest,
  amountHighest,
  amountLowest,
}

class OrderProvider with ChangeNotifier {
  final SaleRepository _saleRepository;

  OrderProvider(this._saleRepository);

  List<Sale> _orders = [];
  List<Sale> _filteredOrders = [];
  List<SaleItem> _currentOrderItems = [];
  bool _isLoading = false;
  String? _error;
  
  // Filter and search state
  String _searchQuery = '';
  OrderStatus _statusFilter = OrderStatus.all;
  OrderSortBy _sortBy = OrderSortBy.dateNewest;
  DateTime? _startDate;
  DateTime? _endDate;

  // Getters
  List<Sale> get orders => _filteredOrders;
  List<Sale> get allOrders => _orders;
  List<SaleItem> get currentOrderItems => _currentOrderItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  OrderStatus get statusFilter => _statusFilter;
  OrderSortBy get sortBy => _sortBy;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  // Statistics
  int get totalOrders => _orders.length;
  int get completedOrders => _orders.where((order) => order.transactionStatus == 'completed').length;
  int get voidedOrders => _orders.where((order) => order.transactionStatus == 'voided').length;
  double get totalRevenue => _orders
      .where((order) => order.transactionStatus == 'completed')
      .fold(0.0, (sum, order) => sum + order.totalAmount);

  // Load all orders
  Future<void> loadOrders() async {
    _setLoading(true);
    _setError(null);

    try {
      _orders = await _saleRepository.getAllSales();
      _applyFiltersAndSort();
    } catch (e) {
      _setError('Failed to load orders: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Load order items for a specific order
  Future<void> loadOrderItems(int orderId) async {
    _setError(null);

    try {
      _currentOrderItems = await _saleRepository.getSaleItems(orderId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load order items: ${e.toString()}');
    }
  }

  // Search and filter methods
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
  }

  void setStatusFilter(OrderStatus status) {
    _statusFilter = status;
    _applyFiltersAndSort();
  }

  void setSortBy(OrderSortBy sortBy) {
    _sortBy = sortBy;
    _applyFiltersAndSort();
  }

  void setDateRange(DateTime? startDate, DateTime? endDate) {
    _startDate = startDate;
    _endDate = endDate;
    _applyFiltersAndSort();
  }

  void clearDateRange() {
    _startDate = null;
    _endDate = null;
    _applyFiltersAndSort();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _statusFilter = OrderStatus.all;
    _sortBy = OrderSortBy.dateNewest;
    _startDate = null;
    _endDate = null;
    _applyFiltersAndSort();
  }

  // Apply filters and sorting
  void _applyFiltersAndSort() {
    List<Sale> filtered = List.from(_orders);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        final query = _searchQuery.toLowerCase();
        return order.id.toString().contains(query) ||
               (order.customerName?.toLowerCase().contains(query) ?? false) ||
               order.totalAmount.toString().contains(query);
      }).toList();
    }

    // Apply status filter
    switch (_statusFilter) {
      case OrderStatus.completed:
        filtered = filtered.where((order) => order.transactionStatus == 'completed').toList();
        break;
      case OrderStatus.voided:
        filtered = filtered.where((order) => order.transactionStatus == 'voided').toList();
        break;
      case OrderStatus.all:
        // No filtering needed
        break;
    }

    // Apply date range filter
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((order) {
        final orderDate = order.saleDate;
        return orderDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
               orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case OrderSortBy.dateNewest:
        filtered.sort((a, b) => b.saleDate.compareTo(a.saleDate));
        break;
      case OrderSortBy.dateOldest:
        filtered.sort((a, b) => a.saleDate.compareTo(b.saleDate));
        break;
      case OrderSortBy.amountHighest:
        filtered.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case OrderSortBy.amountLowest:
        filtered.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
        break;
    }

    _filteredOrders = filtered;
    notifyListeners();
  }

  // Order management methods
  Future<bool> voidOrder(int orderId, String reason) async {
    _setError(null);

    try {
      // Find the order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex == -1) {
        _setError('Order not found');
        return false;
      }

      final order = _orders[orderIndex];
      
      // Update order status to voided
      final voidedOrder = order.copyWith(
        transactionStatus: 'voided',
      );

      // Update in database using repository
      await _saleRepository.updateSale(voidedOrder);

      // Add audit entry
      await _insertAuditEntry(orderId, 'voided', reason);

      // Update local state
      _orders[orderIndex] = voidedOrder;
      _applyFiltersAndSort();

      return true;
    } catch (e) {
      _setError('Failed to void order: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteOrder(int orderId) async {
    _setError(null);

    try {
      // Check if order exists
      final orderExists = _orders.any((order) => order.id == orderId);
      if (!orderExists) {
        _setError('Order not found');
        return false;
      }

      // Add audit entry before deletion
      await _insertAuditEntry(orderId, 'deleted', 'Order deleted by user');

      // Delete from database
      await _saleRepository.deleteSale(orderId);

      // Update local state
      _orders.removeWhere((order) => order.id == orderId);
      _applyFiltersAndSort();

      return true;
    } catch (e) {
      _setError('Failed to delete order: ${e.toString()}');
      return false;
    }
  }

  // Get order by ID
  Sale? getOrderById(int orderId) {
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  // Get orders for a specific date range
  List<Sale> getOrdersForDateRange(DateTime startDate, DateTime endDate) {
    return _orders.where((order) {
      final orderDate = order.saleDate;
      return orderDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             orderDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  // Get orders for today
  List<Sale> getTodayOrders() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _orders.where((order) {
      return order.saleDate.isAfter(startOfDay) && order.saleDate.isBefore(endOfDay);
    }).toList();
  }

  // Get orders for this week
  List<Sale> getThisWeekOrders() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfWeekDay.add(const Duration(days: 7));
    
    return _orders.where((order) {
      return order.saleDate.isAfter(startOfWeekDay) && order.saleDate.isBefore(endOfWeek);
    }).toList();
  }

  // Get orders for this month
  List<Sale> getThisMonthOrders() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    
    return _orders.where((order) {
      return order.saleDate.isAfter(startOfMonth) && order.saleDate.isBefore(endOfMonth);
    }).toList();
  }

  // Statistics methods
  Map<String, dynamic> getOrderStatistics() {
    final completedOrdersList = _orders.where((order) => order.transactionStatus == 'completed').toList();
    final voidedOrdersList = _orders.where((order) => order.transactionStatus == 'voided').toList();
    
    return {
      'totalOrders': _orders.length,
      'completedOrders': completedOrdersList.length,
      'voidedOrders': voidedOrdersList.length,
      'totalRevenue': completedOrdersList.fold(0.0, (sum, order) => sum + order.totalAmount),
      'averageOrderValue': completedOrdersList.isNotEmpty 
          ? completedOrdersList.fold(0.0, (sum, order) => sum + order.totalAmount) / completedOrdersList.length
          : 0.0,
      'todayOrders': getTodayOrders().length,
      'thisWeekOrders': getThisWeekOrders().length,
      'thisMonthOrders': getThisMonthOrders().length,
    };
  }

  // Refresh data
  Future<void> refresh() async {
    await loadOrders();
  }

  // Private helper methods
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

  // Insert audit entry for order actions
  Future<void> _insertAuditEntry(int orderId, String action, String reason) async {
    try {
      // For now, just log the audit entry
      // In a full implementation, you would create an audit repository
      debugPrint('Audit: Order $orderId - $action: $reason at ${DateTime.now()}');
    } catch (e) {
      // Log error but don't fail the main operation
      debugPrint('Failed to insert audit entry: $e');
    }
  }

  // Get audit history for an order
  Future<List<Map<String, dynamic>>> getOrderAuditHistory(int orderId) async {
    try {
      // For now, return empty list
      // In a full implementation, you would query from audit repository
      return [];
    } catch (e) {
      _setError('Failed to load audit history: ${e.toString()}');
      return [];
    }
  }
}