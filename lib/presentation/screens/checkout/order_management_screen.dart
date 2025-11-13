import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../domain/entities/sale.dart';
import '../main_screen.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    
    // Load orders when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.loadOrders();
    });
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.setSearchQuery(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: () => _navigateToHome(),
            icon: const Icon(Icons.home),
          ),
        ],
      ),
      body: Consumer2<OrderProvider, CurrencyProvider>(
        builder: (context, orderProvider, currencyProvider, child) {
          return Column(
            children: [
              // Search and statistics section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[50],
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search orders by ID, customer, or amount...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Statistics cards
                    _buildStatisticsSection(orderProvider, currencyProvider),
                  ],
                ),
              ),
              
              // Filter chips
              if (_hasActiveFilters(orderProvider))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildFilterChips(orderProvider),
                ),
              
              // Orders list
              Expanded(
                child: orderProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : orderProvider.orders.isEmpty
                        ? _buildEmptyState()
                        : _buildOrdersList(orderProvider, currencyProvider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToNewSale(),
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add_shopping_cart, color: Colors.white),
      ),
    );
  }

  Widget _buildStatisticsSection(OrderProvider orderProvider, CurrencyProvider currencyProvider) {
    final stats = orderProvider.getOrderStatistics();
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Orders',
            stats['totalOrders'].toString(),
            Icons.receipt_long,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Completed',
            stats['completedOrders'].toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Revenue',
            currencyProvider.formatPrice(stats['totalRevenue']),
            Icons.attach_money,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(OrderProvider orderProvider) {
    return Wrap(
      spacing: 8,
      children: [
        if (orderProvider.searchQuery.isNotEmpty)
          Chip(
            label: Text('Search: "${orderProvider.searchQuery}"'),
            onDeleted: () {
              _searchController.clear();
            },
          ),
        if (orderProvider.statusFilter != OrderStatus.all)
          Chip(
            label: Text('Status: ${orderProvider.statusFilter.name}'),
            onDeleted: () {
              orderProvider.setStatusFilter(OrderStatus.all);
            },
          ),
        if (orderProvider.startDate != null && orderProvider.endDate != null)
          Chip(
            label: Text('Date: ${_formatDateRange(orderProvider.startDate!, orderProvider.endDate!)}'),
            onDeleted: () {
              orderProvider.clearDateRange();
            },
          ),
        ActionChip(
          label: const Text('Clear All'),
          onPressed: () {
            _searchController.clear();
            orderProvider.clearAllFilters();
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here once you make sales',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(OrderProvider orderProvider, CurrencyProvider currencyProvider) {
    return RefreshIndicator(
      onRefresh: () => orderProvider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orderProvider.orders.length,
        itemBuilder: (context, index) {
          final order = orderProvider.orders[index];
          return _buildOrderCard(order, orderProvider, currencyProvider);
        },
      ),
    );
  }

  Widget _buildOrderCard(Sale order, OrderProvider orderProvider, CurrencyProvider currencyProvider) {
    final isVoided = order.transactionStatus == 'voided';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showOrderDetails(order, orderProvider, currencyProvider),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVoided ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.transactionStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isVoided ? Colors.red[700] : Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Order details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order.customerName != null)
                          Text(
                            'Customer: ${order.customerName}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        Text(
                          _formatDateTime(order.saleDate),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Payment: ${_formatPaymentMethod(order.paymentMethod)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyProvider.formatPrice(order.totalAmount),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isVoided ? Colors.red : Colors.blue[600],
                          decoration: isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (order.changeAmount > 0)
                        Text(
                          'Change: ${currencyProvider.formatPrice(order.changeAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              // Action buttons
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showOrderDetails(order, orderProvider, currencyProvider),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                  ),
                  if (!isVoided) ...[
                    TextButton.icon(
                      onPressed: () => _showVoidOrderDialog(order, orderProvider),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Void'),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: () => _showDeleteOrderDialog(order, orderProvider),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilters(OrderProvider orderProvider) {
    return orderProvider.searchQuery.isNotEmpty ||
           orderProvider.statusFilter != OrderStatus.all ||
           (orderProvider.startDate != null && orderProvider.endDate != null);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateRange(DateTime start, DateTime end) {
    return '${start.day}/${start.month} - ${end.day}/${end.month}';
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'mobile':
        return 'Mobile';
      default:
        return method;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        currentStatus: Provider.of<OrderProvider>(context, listen: false).statusFilter,
        currentSortBy: Provider.of<OrderProvider>(context, listen: false).sortBy,
        startDate: _startDate,
        endDate: _endDate,
        onApply: (status, sortBy, startDate, endDate) {
          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
          orderProvider.setStatusFilter(status);
          orderProvider.setSortBy(sortBy);
          orderProvider.setDateRange(startDate, endDate);
          setState(() {
            _startDate = startDate;
            _endDate = endDate;
          });
        },
      ),
    );
  }

  void _showOrderDetails(Sale order, OrderProvider orderProvider, CurrencyProvider currencyProvider) {
    showDialog(
      context: context,
      builder: (context) => _OrderDetailsDialog(
        order: order,
        orderProvider: orderProvider,
        currencyProvider: currencyProvider,
      ),
    );
  }

  void _showVoidOrderDialog(Sale order, OrderProvider orderProvider) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to void Order #${order.id}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for voiding',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              final success = await orderProvider.voidOrder(order.id!, reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Order voided successfully' : 'Failed to void order'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Void Order'),
          ),
        ],
      ),
    );
  }

  void _showDeleteOrderDialog(Sale order, OrderProvider orderProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text('Are you sure you want to permanently delete Order #${order.id}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final success = await orderProvider.deleteOrder(order.id!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Order deleted successfully' : 'Failed to delete order'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToNewSale() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialIndex: 1), // Sales tab
      ),
      (route) => false,
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialIndex: 0), // Dashboard tab
      ),
      (route) => false,
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final OrderStatus currentStatus;
  final OrderSortBy currentSortBy;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(OrderStatus, OrderSortBy, DateTime?, DateTime?) onApply;

  const _FilterDialog({
    required this.currentStatus,
    required this.currentSortBy,
    required this.startDate,
    required this.endDate,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late OrderStatus _selectedStatus;
  late OrderSortBy _selectedSortBy;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _selectedSortBy = widget.currentSortBy;
    _selectedStartDate = widget.startDate;
    _selectedEndDate = widget.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Orders'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status filter
            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<OrderStatus>(
              value: _selectedStatus,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: OrderStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Sort by
            const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<OrderSortBy>(
              value: _selectedSortBy,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: OrderSortBy.values.map((sortBy) {
                String label;
                switch (sortBy) {
                  case OrderSortBy.dateNewest:
                    label = 'Date (Newest First)';
                    break;
                  case OrderSortBy.dateOldest:
                    label = 'Date (Oldest First)';
                    break;
                  case OrderSortBy.amountHighest:
                    label = 'Amount (Highest First)';
                    break;
                  case OrderSortBy.amountLowest:
                    label = 'Amount (Lowest First)';
                    break;
                }
                return DropdownMenuItem(
                  value: sortBy,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSortBy = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Date range
            const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedStartDate = date;
                        });
                      }
                    },
                    child: Text(_selectedStartDate != null
                        ? '${_selectedStartDate!.day}/${_selectedStartDate!.month}/${_selectedStartDate!.year}'
                        : 'Start Date'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedEndDate = date;
                        });
                      }
                    },
                    child: Text(_selectedEndDate != null
                        ? '${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}'
                        : 'End Date'),
                  ),
                ),
              ],
            ),
            if (_selectedStartDate != null || _selectedEndDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStartDate = null;
                      _selectedEndDate = null;
                    });
                  },
                  child: const Text('Clear Date Range'),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_selectedStatus, _selectedSortBy, _selectedStartDate, _selectedEndDate);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _OrderDetailsDialog extends StatefulWidget {
  final Sale order;
  final OrderProvider orderProvider;
  final CurrencyProvider currencyProvider;

  const _OrderDetailsDialog({
    required this.order,
    required this.orderProvider,
    required this.currencyProvider,
  });

  @override
  State<_OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<_OrderDetailsDialog> {
  @override
  void initState() {
    super.initState();
    // Load order items when dialog opens
    widget.orderProvider.loadOrderItems(widget.order.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${widget.order.id}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            
            // Order information
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(),
                    const SizedBox(height: 24),
                    _buildItemsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        _buildInfoRow('Date & Time', _formatDateTime(widget.order.saleDate)),
        if (widget.order.customerName != null)
          _buildInfoRow('Customer', widget.order.customerName!),
        _buildInfoRow('Payment Method', _formatPaymentMethod(widget.order.paymentMethod)),
        _buildInfoRow('Status', widget.order.transactionStatus.toUpperCase()),
        
        const SizedBox(height: 16),
        
        _buildInfoRow('Subtotal', widget.currencyProvider.formatPrice(widget.order.totalAmount)),
        _buildInfoRow('Amount Paid', widget.currencyProvider.formatPrice(widget.order.paymentAmount)),
        _buildInfoRow('Change', widget.currencyProvider.formatPrice(widget.order.changeAmount)),
        
        const Divider(),
        
        _buildInfoRow(
          'Total',
          widget.currencyProvider.formatPrice(widget.order.totalAmount),
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        if (orderProvider.currentOrderItems.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            ...orderProvider.currentOrderItems.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product ID: ${item.productId}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('Quantity: ${item.quantity}'),
                            Text('Unit Price: ${widget.currencyProvider.formatPrice(item.unitPrice)}'),
                          ],
                        ),
                      ),
                      Text(
                        widget.currencyProvider.formatPrice(item.subtotal),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.blue[600] : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card Payment';
      case 'mobile':
        return 'Mobile Payment';
      default:
        return method;
    }
  }
}