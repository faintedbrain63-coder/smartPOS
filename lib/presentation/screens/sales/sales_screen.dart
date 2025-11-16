import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../domain/entities/sale.dart';
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
                child: ListView.builder(
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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showSaleDetails(Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale #${sale.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${sale.customerName ?? 'Walk-in'}'),
            Text('Date: ${_formatDateTime(sale.createdAt)}'),
            Text('Total: ${Provider.of<CurrencyProvider>(context, listen: false).formatPrice(sale.totalAmount)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
