import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';

class FastMovingProductsScreen extends StatefulWidget {
  const FastMovingProductsScreen({super.key});

  @override
  State<FastMovingProductsScreen> createState() => _FastMovingProductsScreenState();
}

class _FastMovingProductsScreenState extends State<FastMovingProductsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      // Fetch top 1000 selling products to practically get all moving products
      final products = await saleProvider.getTopSellingProducts(limit: 1000);
      
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fast Moving Products'),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64, 
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No sales data available yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          final rank = index + 1;
          final name = product['name'] as String;
          final totalSold = (product['total_sold'] as num).toInt();
          final totalRevenue = (product['total_revenue'] as num).toDouble();
          
          // Calculate velocity color (top 3 gets special highlight)
          Color? rankColor;
          if (rank == 1) rankColor = Colors.amber;
          else if (rank == 2) rankColor = Colors.grey[400]; // Silver
          else if (rank == 3) rankColor = Colors.brown[300]; // Bronze
          else rankColor = Theme.of(context).colorScheme.primaryContainer;

          return Card(
            elevation: AppConstants.cardElevation,
            margin: const EdgeInsets.only(bottom: AppConstants.spacingSmall),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMedium,
                vertical: AppConstants.paddingSmall,
              ),
              leading: CircleAvatar(
                backgroundColor: rankColor,
                foregroundColor: rank <= 3 ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer,
                child: Text('#$rank'),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined, 
                      size: 14, 
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalSold units sold',
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                    ),
                  ],
                ),
              ),
              trailing: Consumer<CurrencyProvider>(
                builder: (context, currencyProvider, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyProvider.formatPrice(totalRevenue),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Revenue',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
