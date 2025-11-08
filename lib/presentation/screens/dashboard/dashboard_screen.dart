import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/constants/app_constants.dart';
import '../sales/sales_screen.dart';
import '../inventory/inventory_screen.dart';
import '../analytics/analytics_screen.dart';
import '../categories/categories_screen.dart';
import '../barcode_scanner_screen.dart';
import '../inventory/add_edit_product_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);

    await Future.wait([
      productProvider.loadProducts(),
      productProvider.loadLowStockProducts(),
      productProvider.loadOutOfStockProducts(),
      saleProvider.loadTodaySales(),
      saleProvider.loadSalesAnalytics(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: themeProvider.toggleTheme,
                tooltip: themeProvider.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              const SizedBox(height: AppConstants.spacingLarge),

              // Statistics Cards
              _buildStatisticsSection(),
              const SizedBox(height: AppConstants.spacingLarge),

              // Quick Actions
              _buildQuickActionsSection(theme),
              const SizedBox(height: AppConstants.spacingLarge),

              // Alerts Section
              _buildAlertsSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeProvider.storeName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSmall),
              Text(
                'efficiently',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsSection() {
    return Consumer3<ProductProvider, SaleProvider, CurrencyProvider>(
      builder: (context, productProvider, saleProvider, currencyProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: AppConstants.spacingMedium,
              mainAxisSpacing: AppConstants.spacingMedium,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  title: 'Today\'s Sales',
                  value: currencyProvider.formatPrice(saleProvider.todayTotalSales ?? 0.0),
                  icon: Icons.attach_money,
                  color: Colors.green,
                  isLoading: saleProvider.isLoading,
                ),
                _buildStatCard(
                  title: 'Total Products',
                  value: productProvider.products.length.toString(),
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                  isLoading: productProvider.isLoading,
                ),
                _buildStatCard(
                  title: 'Low Stock Items',
                  value: productProvider.lowStockCount.toString(),
                  icon: Icons.warning,
                  color: Colors.orange,
                  isLoading: productProvider.isLoading,
                ),
                _buildStatCard(
                  title: 'Out of Stock',
                  value: productProvider.outOfStockCount.toString(),
                  icon: Icons.error,
                  color: Colors.red,
                  isLoading: productProvider.isLoading,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isLoading,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            const SizedBox(height: AppConstants.spacingSmall),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMedium),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppConstants.spacingMedium,
          mainAxisSpacing: AppConstants.spacingMedium,
          childAspectRatio: 1.8,
          children: [
            _buildQuickActionCard(
              title: 'New Sale',
              icon: Icons.shopping_cart,
              color: Colors.purple,
              onTap: () => _navigateToSales(),
            ),
            _buildQuickActionCard(
              title: 'Categories',
              icon: Icons.category,
              color: Colors.brown,
              onTap: () => _navigateToCategories(),
            ),
            _buildQuickActionCard(
              title: 'Add Product',
              icon: Icons.add_box,
              color: Colors.grey,
              onTap: () => _navigateToInventory(),
            ),
            _buildQuickActionCard(
              title: 'Scan Barcode',
              icon: Icons.qr_code_scanner,
              color: Colors.red,
              onTap: () => _showBarcodeScanner(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: color,
              ),
              const SizedBox(height: AppConstants.spacingSmall),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsSection(ThemeData theme) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final lowStockCount = productProvider.lowStockProducts.length;
        final outOfStockCount = productProvider.outOfStockProducts.length;

        if (lowStockCount == 0 && outOfStockCount == 0) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alerts',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            if (outOfStockCount > 0)
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.error,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Out of Stock Items',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '$outOfStockCount products are out of stock',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  onTap: () => _navigateToInventory(),
                ),
              ),
            if (outOfStockCount > 0 && lowStockCount > 0)
              const SizedBox(height: AppConstants.spacingSmall),
            if (lowStockCount > 0)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.warning,
                    color: Colors.orange,
                  ),
                  title: Text(
                    'Low Stock Items',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '$lowStockCount products are running low',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  onTap: () => _navigateToInventory(),
                ),
              ),
          ],
        );
      },
    );
  }

  void _navigateToSales() {
    // Navigate to Sales tab
    final mainScreenState = context.findAncestorStateOfType<State<StatefulWidget>>();
    if (mainScreenState != null && mainScreenState.mounted) {
      // This is a simple way to switch tabs - in a real app you might use a more sophisticated navigation
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SalesScreen()),
      );
    }
  }

  void _navigateToInventory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const InventoryScreen()),
    );
  }

  void _navigateToAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
    );
  }

  void _navigateToCategories() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CategoriesScreen()),
    );
  }

  void _showBarcodeScanner() async {
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      );
      
      if (result != null && result.isNotEmpty) {
        // Navigate to add product screen with scanned barcode
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddEditProductScreen(barcode: result),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening barcode scanner: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}