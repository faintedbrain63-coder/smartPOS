import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/sale_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/product_provider.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sale_item.dart';
import '../../../data/repositories/sale_repository_impl.dart';
import '../../../core/constants/app_constants.dart';
import 'new_sale_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSales();
    });
  }

  Future<void> _loadSales() async {
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    await saleProvider.loadSales();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer2<SaleProvider, CurrencyProvider>(
        builder: (context, saleProvider, currencyProvider, child) {
          if (saleProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (saleProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppConstants.spacingMedium),
                  Text(
                    'Error loading sales',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppConstants.spacingSmall),
                  Text(
                    saleProvider.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingLarge),
                  ElevatedButton(
                    onPressed: _loadSales,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Sales Summary
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(AppConstants.spacingMedium),
                padding: const EdgeInsets.all(AppConstants.spacingMedium),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Today\'s Sales',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          saleProvider.todaySalesCount.toString(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(0.3),
                    ),
                    Column(
                      children: [
                        Text(
                          'Today\'s Revenue',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          currencyProvider.formatPrice(saleProvider.todaySalesAmount),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sales List
              Expanded(
                child: saleProvider.sales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sales yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMedium),
                        itemCount: saleProvider.sales.length,
                        itemBuilder: (context, index) {
                          final sale = saleProvider.sales[index];
                          return _buildSaleCard(sale, theme, currencyProvider);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewSaleScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
      ),
    );
  }

  Widget _buildSaleCard(Sale sale, ThemeData theme, CurrencyProvider currencyProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingMedium),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            '#${sale.id}',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          'Sale #${sale.id}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDateTime(sale.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Customer: ${sale.customerName ?? 'Walk-in'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyProvider.formatPrice(sale.totalAmount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            _statusChip(sale, theme),
          ],
        ),
        onTap: () {
          _showSaleDetails(sale);
        },
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    }
  }

  void _showSaleDetails(Sale sale) async {
    final repo = Provider.of<SaleRepositoryImpl>(context, listen: false);
    final currency = Provider.of<CurrencyProvider>(context, listen: false);
    
    // Fetch sale items
    final items = await repo.getSaleItems(sale.id!);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
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
                  'Sale #${sale.id}',
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
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _editSale(sale, items);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Sale'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteSaleConfirm(sale.id!);
                        },
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('Delete Sale'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Sale info
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDetailRow('Customer', sale.customerName ?? 'Walk-in'),
                      _buildDetailRow('Date', _formatDateTime(sale.createdAt)),
                      _buildDetailRow('Total Amount', currency.formatPrice(sale.totalAmount)),
                      _buildDetailRow('Payment Method', sale.paymentMethod.toUpperCase()),
                      _buildDetailRow('Status', sale.transactionStatus.toUpperCase()),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Items (${items.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...items.map((item) => Card(
                        child: ListTile(
                          title: Text('Product #${item.productId}'),
                          subtitle: Text('Qty: ${item.quantity} × ${currency.formatPrice(item.unitPrice)}'),
                          trailing: Text(
                            currency.formatPrice(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      )),
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

  Future<void> _editSale(Sale sale, List<SaleItem> items) async {
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final currency = Provider.of<CurrencyProvider>(context, listen: false);
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Edit Sale #${sale.id}', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Items:', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (c, i) {
                          final it = items[i];
                          return Card(
                            child: ListTile(
                              title: Text('Product #${it.productId}'),
                              subtitle: Text('Price: ${currency.formatPrice(it.unitPrice)}'),
                              trailing: SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: itemControllers[i],
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => recalcTotal(),
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total: ${currency.formatPrice(total)}',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
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
                              );
                              
                              final ok = await saleProvider.editSale(sale.id!, updatedSale, updatedItems);
                              
                              if (ctx.mounted) {
                                if (ok) {
                                  Navigator.pop(ctx);
                                  // Trigger inventory refresh
                                  final productProvider = Provider.of<ProductProvider>(context, listen: false);
                                  await productProvider.refreshInventory();
                                  
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✓ Sale updated successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else {
                                  final errorMsg = saleProvider.error ?? 'Failed to update sale';
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSaleConfirm(int saleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Delete Sale'),
        content: const Text(
          'Are you sure you want to DELETE this sale?\n\n'
          'This will:\n'
          '✓ PERMANENTLY REMOVE the sale from database\n'
          '✓ Update all totals and analytics\n\n'
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
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      final ok = await saleProvider.deleteSale(saleId);
      
      if (ok) {
        // Trigger inventory refresh
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        await productProvider.refreshInventory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Sale DELETED successfully. Inventory restored.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          final errorMsg = saleProvider.error ?? 'Failed to delete sale';
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

  Widget _statusChip(Sale sale, ThemeData theme) {
    final status = sale.transactionStatus.toLowerCase();
    Color color;
    String label;
    switch (status) {
      case 'credit':
        color = Colors.orange;
        label = 'Credit';
        break;
      case 'completed':
      default:
        color = Colors.green;
        label = 'Completed';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
