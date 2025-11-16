import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/currency_provider.dart';
import '../../../data/repositories/sale_repository_impl.dart';
import '../../providers/sale_provider.dart';
import '../../providers/product_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../domain/entities/sale_item.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> with SingleTickerProviderStateMixin {
  DateTime? _startDateRange;
  DateTime? _endDateRange;
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;
  List<Map<String, dynamic>> _allCredits = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild when tab changes
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCredits();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCredits() async {
    setState(() => _isLoading = true);
    try {
      final repo = Provider.of<SaleRepositoryImpl>(context, listen: false);
      // Load all credits including completed ones
      final credits = await repo.getAllCreditsWithDetails(includeCompleted: true);
      setState(() {
        _allCredits = credits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading credits: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredCredits() {
    if (_tabController == null) return [];
    
    List<Map<String, dynamic>> filtered = List.from(_allCredits);
    
    // Filter by tab (unpaid vs paid)
    if (_tabController!.index == 0) {
      // Unpaid tab: show credits with outstanding > 0
      filtered = filtered.where((credit) {
        final outstanding = (credit['outstanding'] as num?)?.toDouble() ?? 0.0;
        return outstanding > 0;
      }).toList();
    } else {
      // Paid tab: show credits with outstanding <= 0 or status = completed
      filtered = filtered.where((credit) {
        final outstanding = (credit['outstanding'] as num?)?.toDouble() ?? 0.0;
        final status = credit['transaction_status'] as String?;
        return outstanding <= 0 || status == 'completed';
      }).toList();
    }
    
    // Filter by date range
    if (_startDateRange != null || _endDateRange != null) {
      filtered = filtered.where((credit) {
        final saleDateStr = credit['sale_date'] as String?;
        if (saleDateStr == null) return false;
        
        try {
          final saleDate = DateTime.parse(saleDateStr);
          
          if (_startDateRange != null) {
            final start = DateTime(_startDateRange!.year, _startDateRange!.month, _startDateRange!.day);
            if (saleDate.isBefore(start)) return false;
          }
          
          if (_endDateRange != null) {
            final end = DateTime(_endDateRange!.year, _endDateRange!.month, _endDateRange!.day, 23, 59, 59);
            if (saleDate.isAfter(end)) return false;
          }
          
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    // Filter by customer name
    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((credit) {
        final customerName = (credit['customer_name'] as String? ?? '').toLowerCase();
        return customerName.contains(searchQuery);
      }).toList();
    }
    
    return filtered;
  }

  double _calculateTotal(List<Map<String, dynamic>> credits) {
    if (_tabController == null) return 0.0;
    
    if (_tabController!.index == 0) {
      // Unpaid tab: sum of outstanding amounts
      return credits.fold(0.0, (sum, credit) {
        final outstanding = (credit['outstanding'] as num?)?.toDouble() ?? 0.0;
        return sum + outstanding;
      });
    } else {
      // Paid tab: sum of total amounts (fully paid)
      return credits.fold(0.0, (sum, credit) {
        final totalAmount = (credit['total_amount'] as num?)?.toDouble() ?? 0.0;
        return sum + totalAmount;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard against accessing TabController before initialization
    if (_tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final theme = Theme.of(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final filteredCredits = _getFilteredCredits();
    final total = _calculateTotal(filteredCredits);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credits'),
        actions: [
          IconButton(
            onPressed: _loadCredits,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController!,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Unpaid / Due',
            ),
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'Paid',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by customer name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          
          // Date range filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDateRange ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDateRange = DateTime(picked.year, picked.month, picked.day);
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _startDateRange == null
                          ? 'Start Date'
                          : DateFormat('MMM dd, yyyy').format(_startDateRange!),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDateRange ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _endDateRange = DateTime(picked.year, picked.month, picked.day);
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _endDateRange == null
                          ? 'End Date'
                          : DateFormat('MMM dd, yyyy').format(_endDateRange!),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_startDateRange != null || _endDateRange != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _startDateRange = null;
                        _endDateRange = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear dates',
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Total amount card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _tabController!.index == 0
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _tabController!.index == 0 ? Colors.orange : Colors.green,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tabController!.index == 0 ? 'Total Unpaid Amount' : 'Total Paid Amount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${filteredCredits.length} ${filteredCredits.length == 1 ? 'credit' : 'credits'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                Text(
                  currencyProvider.formatPrice(total),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _tabController!.index == 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Credits list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCredits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _tabController!.index == 0
                                  ? Icons.check_circle_outline
                                  : Icons.credit_card_off,
                              size: 64,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _tabController!.index == 0
                                  ? 'No unpaid credits'
                                  : 'No paid credits',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: filteredCredits.length,
                        itemBuilder: (context, index) {
                          final credit = filteredCredits[index];
                          return _buildCreditCard(credit, theme, currencyProvider);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(Map<String, dynamic> credit, ThemeData theme, CurrencyProvider currencyProvider) {
    final customerName = credit['customer_name'] as String? ?? 'Walk-in';
    final totalAmount = (credit['total_amount'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (credit['outstanding'] as num?)?.toDouble() ?? 0.0;
    final saleDateStr = credit['sale_date'] as String?;
    final lastPaymentDateStr = credit['last_payment_date'] as String?;
    final dueDateStr = credit['due_date'] as String?;
    final status = credit['transaction_status'] as String?;
    
    final isPaid = outstanding <= 0 || status == 'completed';
    final isOverdue = !isPaid && dueDateStr != null && DateTime.parse(dueDateStr).isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: isOverdue
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.red, width: 2),
            )
          : null,
      child: InkWell(
        onTap: () => _showCreditDetails(credit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customerName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(isPaid, isOverdue, theme),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Amount row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    currencyProvider.formatPrice(totalAmount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              
              if (!isPaid) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Outstanding:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      currencyProvider.formatPrice(outstanding),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Dates section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date Credited',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(saleDateStr),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isPaid && lastPaymentDateStr != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date Paid',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDate(lastPaymentDateStr),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              if (!isPaid && dueDateStr != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isOverdue ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${_formatDate(dueDateStr)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOverdue ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Action buttons
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showCreditDetails(credit),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isPaid, bool isOverdue, ThemeData theme) {
    Color color;
    String label;
    IconData icon;
    
    if (isPaid) {
      color = Colors.green;
      label = 'Paid';
      icon = Icons.check_circle;
    } else if (isOverdue) {
      color = Colors.red;
      label = 'Overdue';
      icon = Icons.warning;
    } else {
      color = Colors.orange;
      label = 'Due';
      icon = Icons.pending;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreditDetails(Map<String, dynamic> credit) {
    final saleId = credit['sale_id'] as int;
    final currency = Provider.of<CurrencyProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final outstanding = (credit['outstanding'] as num?)?.toDouble() ?? 0.0;
          final isPaid = outstanding <= 0;
          
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  'Credit Details - Sale #$saleId',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (!isPaid)
                        ElevatedButton.icon(
                          onPressed: () => _recordPayment(saleId, outstanding),
                          icon: const Icon(Icons.payment, size: 18),
                          label: const Text('Record Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (!isPaid)
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _markAsPaidConfirm(saleId);
                          },
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Mark as Paid'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _editCreditFlow(saleId, credit);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteCreditConfirm(saleId);
                        },
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Credit info (you can expand this to show more details)
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDetailRow('Customer', credit['customer_name'] ?? 'Walk-in'),
                      _buildDetailRow('Total Amount', currency.formatPrice((credit['total_amount'] as num?)?.toDouble() ?? 0.0)),
                      _buildDetailRow('Outstanding', currency.formatPrice(outstanding)),
                      _buildDetailRow('Date Credited', _formatDate(credit['sale_date'] as String?)),
                      if (credit['due_date'] != null)
                        _buildDetailRow('Due Date', _formatDate(credit['due_date'] as String?)),
                      if (credit['last_payment_date'] != null)
                        _buildDetailRow('Date Paid', _formatDate(credit['last_payment_date'] as String?)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  void _recordPayment(int saleId, double outstanding) async {
    final repo = Provider.of<SaleRepositoryImpl>(context, listen: false);
    final controller = TextEditingController(text: outstanding.toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₱ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0.0;
              if (amount > 0) {
                await repo.insertCreditPayment(
                  saleId: saleId,
                  amount: amount,
                  paidAt: DateTime.now(),
                  note: null,
                );
                if (mounted) {
                  Navigator.pop(context);
                  await _loadCredits();
                  // Trigger global state refresh for Dashboard and other screens
                  final saleProvider = Provider.of<SaleProvider>(context, listen: false);
                  final productProvider = Provider.of<ProductProvider>(context, listen: false);
                  await Future.wait([
                    saleProvider.refreshAllData(),
                    productProvider.refreshInventory(),
                  ]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment recorded successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsPaidConfirm(int saleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: const Text(
          'This will mark the credit as fully paid by recording a payment for the outstanding amount.\n\n'
          'The credit will be moved to the Paid tab.\n\n'
          'This is NOT the same as deleting the credit (which would restore inventory).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = Provider.of<SaleRepositoryImpl>(context, listen: false);
      final outstanding = await repo.getOutstandingForSale(saleId);
      if (outstanding > 0) {
        await repo.insertCreditPayment(
          saleId: saleId,
          amount: outstanding,
          paidAt: DateTime.now(),
          note: 'Marked as paid',
        );
      }
      
      try {
        NotificationService.instance.cancelForSale(saleId);
      } catch (_) {}
      
      await _loadCredits();
      
      // Trigger global state refresh for Dashboard and other screens
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      await Future.wait([
        saleProvider.refreshAllData(),
        productProvider.refreshInventory(),
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Credit marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteCreditConfirm(int saleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Delete Credit'),
        content: const Text(
          'Are you sure you want to DELETE this credit?\n\n'
          'This will:\n'
          '✓ PERMANENTLY REMOVE the credit from database\n'
          '✓ Restore items to inventory\n'
          '✓ Update all totals\n'
          '✓ Cancel notifications\n\n'
          'This is NOT the same as marking as paid.\n'
          'This action CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      final ok = await saleProvider.deleteCreditSale(saleId);
      
      if (ok) {
        await _loadCredits();
        // Note: refreshAllData() is already called inside deleteCreditSale()
        // Also refresh inventory since items were restored
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        await productProvider.refreshInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Credit DELETED successfully. Inventory restored.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          final errorMsg = saleProvider.error ?? 'Failed to delete credit';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✗ DELETE FAILED: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _editCreditFlow(int saleId, Map<String, dynamic> credit) async {
    final currency = Provider.of<CurrencyProvider>(context, listen: false);
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final repo = Provider.of<SaleRepositoryImpl>(context, listen: false);
    
    final sale = await repo.getSaleById(saleId);
    final items = await repo.getSaleItems(saleId);
    
    if (sale == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        DateTime? dueDate = sale.dueDate;
        final nameController = TextEditingController(text: sale.customerName ?? '');
        final itemControllers = items.map((i) => TextEditingController(text: i.quantity.toString())).toList();
        double total = items.fold(0.0, (sum, it) => sum + it.subtotal);
        
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void recalcTotal() {
              total = 0.0;
              for (int i = 0; i < items.length; i++) {
                final qty = int.tryParse(itemControllers[i].text) ?? items[i].quantity;
                total += qty * items[i].unitPrice;
              }
              setModalState(() {});
            }
            
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Edit Credit', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Customer Name'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? 'No due date'
                              : 'Due: ${DateFormat('MMM dd, yyyy').format(dueDate!)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            dueDate = DateTime(picked.year, picked.month, picked.day, 8);
                            setModalState(() {});
                          }
                        },
                        child: const Text('Change Due Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (c, i) {
                        final it = items[i];
                        return ListTile(
                          title: Text('Product #${it.productId}'),
                          subtitle: Text('Price: ${currency.formatPrice(it.unitPrice)}'),
                          trailing: SizedBox(
                            width: 80,
                            child: TextField(
                              controller: itemControllers[i],
                              keyboardType: TextInputType.number,
                              onChanged: (_) => recalcTotal(),
                              decoration: const InputDecoration(labelText: 'Qty'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Total: ${currency.formatPrice(total)}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // Validate quantities
                            for (int i = 0; i < items.length; i++) {
                              final qty = int.tryParse(itemControllers[i].text) ?? 0;
                              if (qty <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Invalid quantity for item ${i + 1}'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                            }
                            
                            final updatedItems = <SaleItem>[];
                            for (int i = 0; i < items.length; i++) {
                              final qty = int.tryParse(itemControllers[i].text) ?? items[i].quantity;
                              updatedItems.add(items[i].copyWith(
                                quantity: qty,
                                subtotal: qty * items[i].unitPrice,
                              ));
                            }
                            
                            final updatedSale = sale.copyWith(
                              customerName: nameController.text.trim().isEmpty
                                  ? sale.customerName
                                  : nameController.text.trim(),
                              totalAmount: total,
                              dueDate: dueDate,
                              transactionStatus: 'credit',
                            );
                            
                            final ok = await saleProvider.editCreditSale(saleId, updatedSale, updatedItems);
                            
                            if (ctx.mounted) {
                              if (ok) {
                                Navigator.pop(ctx);
                                await _loadCredits();
                                // Note: refreshAllData() is already called inside editCreditSale()
                                // Also refresh inventory since quantities changed
                                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                                await productProvider.refreshInventory();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✓ Credit updated successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                final errorMsg = saleProvider.error ?? 'Failed to update credit';
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('✗ $errorMsg'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
