import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/sale_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Set default date range to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    
    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalyticsData();
    });
  }

  Future<void> _loadAnalyticsData() async {
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    await Future.wait([
      saleProvider.loadSales(),
      saleProvider.loadAnalytics(),
      saleProvider.loadAnalyticsForDateRange(_startDate, _endDate),
      saleProvider.loadDashboardMetrics(), // Load dashboard metrics including today's revenue
      productProvider.loadProducts(),
    ]);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      await saleProvider.loadAnalyticsForDateRange(_startDate, _endDate);
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    saleProvider.clearDateRangeFilter();
  }

  String _formatDateRange() {
    if (_startDate == null || _endDate == null) {
      return 'All Time';
    }
    
    final start = '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}';
    final end = '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Date Range Picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: InkWell(
                          onTap: _selectDateRange,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.date_range,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Date Range',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Text(
                                        _formatDateRange(),
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_startDate != null && _endDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: _clearDateRange,
                                    tooltip: 'Clear filter',
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab Bar
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Sales', icon: Icon(Icons.trending_up)),
                  Tab(text: 'Products', icon: Icon(Icons.inventory_2)),
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesAnalytics(),
          _buildProductAnalytics(),
          _buildOverviewAnalytics(),
        ],
      ),
    );
  }

  Widget _buildSalesAnalytics() {
    return Consumer2<SaleProvider, CurrencyProvider>(
      builder: (context, saleProvider, currencyProvider, child) {
        if (saleProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sales Summary Cards
              _buildSalesSummaryCards(saleProvider, currencyProvider),
              const SizedBox(height: AppConstants.spacingLarge),

              // Daily Sales Chart
              _buildDailySalesChart(saleProvider),
              const SizedBox(height: AppConstants.spacingLarge),

              // Monthly Sales Chart
              _buildMonthlySalesChart(saleProvider),
              const SizedBox(height: AppConstants.spacingLarge),

              // Profit Analytics Section
              _buildProfitAnalyticsSection(saleProvider, currencyProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductAnalytics() {
    return Consumer2<ProductProvider, SaleProvider>(
      builder: (context, productProvider, saleProvider, child) {
        if (productProvider.isLoading || saleProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Summary Cards
              _buildProductSummaryCards(productProvider),
              const SizedBox(height: AppConstants.spacingLarge),

              // Stock Status Chart
              _buildStockStatusChart(productProvider),
              const SizedBox(height: AppConstants.spacingLarge),

              // Top Selling Products
              _buildTopSellingProducts(saleProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewAnalytics() {
    return Consumer3<SaleProvider, ProductProvider, CurrencyProvider>(
      builder: (context, saleProvider, productProvider, currencyProvider, child) {
        if (saleProvider.isLoading || productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key Metrics
              _buildKeyMetrics(saleProvider, productProvider, currencyProvider),
              const SizedBox(height: AppConstants.spacingLarge),

              // Revenue vs Profit Chart
              _buildRevenueProfitChart(saleProvider),
              const SizedBox(height: AppConstants.spacingLarge),

              // Recent Activity
              _buildRecentActivity(saleProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesSummaryCards(SaleProvider saleProvider, CurrencyProvider currencyProvider) {
    final theme = Theme.of(context);
    
    // Use filtered analytics if date range is selected
    final analytics = saleProvider.filteredAnalytics.isNotEmpty 
        ? saleProvider.filteredAnalytics 
        : saleProvider.analytics;
    
    final salesCount = _startDate != null && _endDate != null
        ? (analytics['totalTransactions'] ?? 0).toString()
        : saleProvider.todaySalesCount.toString();
    
    // For revenue, use todayRevenueAmount which includes both sales AND paid credits
    final revenueAmount = _startDate != null && _endDate != null
        ? (analytics['totalSales'] ?? 0.0) as double
        : saleProvider.todayRevenueAmount;
    
    final salesTitle = _startDate != null && _endDate != null
        ? 'Period Sales'
        : 'Today\'s Sales';
    
    final revenueTitle = _startDate != null && _endDate != null
        ? 'Period Revenue'
        : 'Today\'s Revenue';
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            salesTitle,
            salesCount,
            Icons.today,
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppConstants.spacingMedium),
        Expanded(
          child: _buildSummaryCard(
            revenueTitle,
            currencyProvider.formatPrice(revenueAmount),
            Icons.attach_money,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildProductSummaryCards(ProductProvider productProvider) {
    final theme = Theme.of(context);
    final totalProducts = productProvider.products.length;
    final lowStockCount = productProvider.products
        .where((p) => p.stockQuantity <= AppConstants.lowStockThreshold)
        .length;
    final outOfStockCount = productProvider.products
        .where((p) => p.stockQuantity == 0)
        .length;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Products',
                totalProducts.toString(),
                Icons.inventory_2,
                theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingMedium),
            Expanded(
              child: _buildSummaryCard(
                'Low Stock',
                lowStockCount.toString(),
                Icons.warning_amber,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMedium),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Out of Stock',
                outOfStockCount.toString(),
                Icons.error_outline,
                Colors.red,
              ),
            ),
            const SizedBox(width: AppConstants.spacingMedium),
            Expanded(
              child: _buildSummaryCard(
                'In Stock',
                (totalProducts - outOfStockCount).toString(),
                Icons.check_circle_outline,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
      color.withValues(alpha: 0.1),
      color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  Icon(
                    Icons.trending_up,
                    color: Colors.green,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingMedium),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXSmall),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySalesChart(SaleProvider saleProvider) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Sales (Last 7 Days)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            SizedBox(
              height: 200,
              child: _buildDailySalesChartContent(saleProvider, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySalesChart(SaleProvider saleProvider) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Sales',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            SizedBox(
              height: 200,
              child: _buildMonthlySalesChartContent(saleProvider, theme),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateMonthlySalesFromData(SaleProvider saleProvider) {
    // Use real sales data based on date range
    if (_startDate != null && _endDate != null) {
      return _generateMonthlySalesForDateRange(saleProvider, _startDate!, _endDate!);
    } else {
      // Use last 12 months from today
      final now = DateTime.now();
      final endDate = DateTime(now.year, now.month, now.day);
      final startDate = DateTime(now.year - 1, now.month, now.day);
      
      return _generateMonthlySalesForDateRange(saleProvider, startDate, endDate);
    }
  }

  List<BarChartGroupData> _generateMonthlySalesForDateRange(SaleProvider saleProvider, DateTime startDate, DateTime endDate) {
    final groups = <BarChartGroupData>[];
    
    // Get sales data for the date range
    final salesData = saleProvider.sales.where((sale) {
      return sale.saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             sale.saleDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
    
    // Group sales by month and calculate totals
    final monthlyTotals = <String, double>{};
    
    // Initialize months within the date range
    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
    final endMonth = DateTime(endDate.year, endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth.add(const Duration(days: 32)))) {
      final monthKey = '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}';
      monthlyTotals[monthKey] = 0.0;
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    
    // Aggregate sales by month
    for (final sale in salesData) {
      final saleDate = sale.saleDate;
      final monthKey = '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}';
      if (monthlyTotals.containsKey(monthKey)) {
        monthlyTotals[monthKey] = monthlyTotals[monthKey]! + sale.totalAmount;
      }
    }
    
    // Convert to BarChartGroupData list
    int index = 0;
    final sortedEntries = monthlyTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    for (final entry in sortedEntries) {
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: entry.value,
              color: Theme.of(context).colorScheme.primary,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
      index++;
    }
    
    return groups;
  }

  Widget _buildMonthlySalesChartContent(SaleProvider saleProvider, ThemeData theme) {
    final groups = _generateMonthlySalesFromData(saleProvider);
    
    if (groups.isEmpty || groups.every((group) => group.barRods.first.toY == 0)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No sales data found for the selected period',
              style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<CurrencyProvider>(
      builder: (context, currencyProvider, child) {
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: groups.isNotEmpty 
                ? groups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.2
                : 100,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    currencyProvider.formatPrice(rod.toY),
                    theme.textTheme.bodySmall!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      currencyProvider.formatPrice(value),
                      style: theme.textTheme.bodySmall,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    
                    // Calculate which month this represents based on the date range
                    if (_startDate != null && value.toInt() >= 0) {
                      final startMonth = DateTime(_startDate!.year, _startDate!.month, 1);
                      final targetMonth = DateTime(startMonth.year, startMonth.month + value.toInt(), 1);
                      
                      if (targetMonth.month >= 1 && targetMonth.month <= 12) {
                        return Text(
                          months[targetMonth.month - 1],
                          style: theme.textTheme.bodySmall,
                        );
                      }
                    }
                    return const Text('');
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            barGroups: groups,
            gridData: const FlGridData(show: true),
          ),
        );
      },
    );
  }

  Widget _buildRevenueChartContent(SaleProvider saleProvider, ThemeData theme) {
    final spots = _generateRevenueSpots(saleProvider);
    
    if (spots.isEmpty || spots.every((spot) => spot.y == 0)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 48,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No revenue data found for the selected period',
              style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<CurrencyProvider>(
      builder: (context, currencyProvider, child) {
        return LineChart(
          LineChartData(
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      currencyProvider.formatPrice(value),
                      style: theme.textTheme.bodySmall,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    // Calculate number of weeks dynamically
                    final endDate = _endDate ?? DateTime.now();
                    final startDate = _startDate ?? endDate.subtract(const Duration(days: 28));
                    final totalDays = endDate.difference(startDate).inDays + 1;
                    final numberOfWeeks = (totalDays / 7).ceil();
                    
                    if (value.toInt() >= 0 && value.toInt() < numberOfWeeks) {
                      return Text(
                        'Week ${value.toInt() + 1}',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
             lineBarsData: [
               LineChartBarData(
                 spots: spots,
                 isCurved: true,
                 color: Colors.green,
                 barWidth: 3,
                 dotData: const FlDotData(show: true),
               ),
             ],
           ),
         );
       },
     );
  }

  Widget _buildStockStatusChart(ProductProvider productProvider) {
    final theme = Theme.of(context);
    final totalProducts = productProvider.products.length;
    final lowStockCount = productProvider.products
        .where((p) => p.stockQuantity <= AppConstants.lowStockThreshold && p.stockQuantity > 0)
        .length;
    final outOfStockCount = productProvider.products
        .where((p) => p.stockQuantity == 0)
        .length;
    final inStockCount = totalProducts - lowStockCount - outOfStockCount;
    
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stock Status Distribution',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMedium,
                    vertical: AppConstants.paddingSmall,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                  ),
                  child: Text(
                    '$totalProducts Total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingLarge),
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: inStockCount.toDouble(),
                            title: '$inStockCount',
                            color: Colors.green,
                            radius: 80,
                            titleStyle: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PieChartSectionData(
                            value: lowStockCount.toDouble(),
                            title: '$lowStockCount',
                            color: Colors.orange,
                            radius: 80,
                            titleStyle: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PieChartSectionData(
                            value: outOfStockCount.toDouble(),
                            title: '$outOfStockCount',
                            color: Colors.red,
                            radius: 80,
                            titleStyle: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        centerSpaceRadius: 50,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingLarge),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('In Stock', Colors.green, inStockCount, theme),
                        const SizedBox(height: AppConstants.spacingMedium),
                        _buildLegendItem('Low Stock', Colors.orange, lowStockCount, theme),
                        const SizedBox(height: AppConstants.spacingMedium),
                        _buildLegendItem('Out of Stock', Colors.red, outOfStockCount, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
        ),
        const SizedBox(width: AppConstants.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$count items',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopSellingProducts(SaleProvider saleProvider) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Selling Products',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            // Placeholder for top selling products
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text('Product ${index + 1}'),
                  subtitle: Text('${10 - index * 2} units sold'),
                  trailing: Text(
                    Formatters.formatCurrency((100 - index * 20).toDouble()),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetrics(SaleProvider saleProvider, ProductProvider productProvider, CurrencyProvider currencyProvider) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppConstants.spacingMedium,
      mainAxisSpacing: AppConstants.spacingMedium,
      children: [
        _buildMetricCard(
          'Total Revenue',
          currencyProvider.formatPrice(saleProvider.totalSalesAmount),
          Icons.monetization_on,
          Colors.green,
        ),
        _buildMetricCard(
          'Total Products',
          productProvider.products.length.toString(),
          Icons.inventory_2,
          Colors.blue,
        ),
        _buildMetricCard(
          'Total Sales',
          saleProvider.totalSalesCount.toString(),
          Icons.shopping_cart,
          Colors.orange,
        ),
        _buildMetricCard(
          'Low Stock Items',
          productProvider.products
              .where((p) => p.stockQuantity <= AppConstants.lowStockThreshold)
              .length
              .toString(),
          Icons.warning,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: AppConstants.spacingSmall),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              title,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueProfitChart(SaleProvider saleProvider) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Trend',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            SizedBox(
              height: 200,
              child: _buildRevenueChartContent(saleProvider, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(SaleProvider saleProvider) {
    final theme = Theme.of(context);
    final recentSales = saleProvider.sales.take(5).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Sales',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            if (recentSales.isEmpty)
              const Center(
                child: Text('No recent sales'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentSales.length,
                itemBuilder: (context, index) {
                  final sale = recentSales[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('#${sale.id}'),
                    ),
                    title: Text(sale.customerName ?? 'Walk-in Customer'),
                    subtitle: Text(Formatters.formatDateTime(sale.saleDate)),
                    trailing: Text(
                      Formatters.formatCurrency(sale.totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateDailySalesSpots(SaleProvider saleProvider) {
    // Use real sales data based on date range
    if (_startDate != null && _endDate != null) {
      // Use the last 7 days of the selected date range
      final endDate = _endDate!;
      final startDate = endDate.subtract(const Duration(days: 6));
      
      return _generateDailySalesFromData(saleProvider, startDate, endDate);
    } else {
      // Use last 7 days from today
      final now = DateTime.now();
      final endDate = DateTime(now.year, now.month, now.day);
      final startDate = endDate.subtract(const Duration(days: 6));
      
      return _generateDailySalesFromData(saleProvider, startDate, endDate);
    }
  }

  List<FlSpot> _generateDailySalesFromData(SaleProvider saleProvider, DateTime startDate, DateTime endDate) {
    final spots = <FlSpot>[];
    
    // Get sales data for the date range
    final salesData = saleProvider.sales.where((sale) {
      final saleDate = DateTime(sale.saleDate.year, sale.saleDate.month, sale.saleDate.day);
      return saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             saleDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
    
    // Group sales by day and calculate totals
    final dailyTotals = <String, double>{};
    
    // Initialize all 7 days with 0
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyTotals[dateKey] = 0.0;
    }
    
    // Aggregate sales by day
    for (final sale in salesData) {
      final saleDate = sale.saleDate;
      final dateKey = '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}-${saleDate.day.toString().padLeft(2, '0')}';
      if (dailyTotals.containsKey(dateKey)) {
        dailyTotals[dateKey] = dailyTotals[dateKey]! + sale.totalAmount;
      }
    }
    
    // Create weekday mapping for correct chart display
    final weekdayMapping = <int>[];
    DateTime currentDate = startDate;
    for (int i = 0; i < 7; i++) {
      weekdayMapping.add(currentDate.weekday - 1); // Convert to 0-based index (Mon=0, Sun=6)
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Convert to FlSpot list with correct weekday mapping
    currentDate = startDate;
    for (int i = 0; i < 7; i++) {
      final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      final salesAmount = dailyTotals[dateKey] ?? 0.0;
      final weekdayIndex = weekdayMapping[i];
      spots.add(FlSpot(weekdayIndex.toDouble(), salesAmount));
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Sort spots by x-axis to ensure proper display order
    spots.sort((a, b) => a.x.compareTo(b.x));
    
    return spots;
  }

  List<FlSpot> _generateRevenueSpots(SaleProvider saleProvider) {
    final spots = <FlSpot>[];
    
    if (saleProvider.sales.isEmpty) {
      return spots;
    }

    final endDate = _endDate ?? DateTime.now();
    final startDate = _startDate ?? endDate.subtract(const Duration(days: 28));
    
    // Calculate number of weeks in the date range
    final totalDays = endDate.difference(startDate).inDays + 1;
    final numberOfWeeks = (totalDays / 7).ceil();
    
    // Group sales by week
    final weeklyRevenue = <int, double>{};
    
    // Initialize all weeks with 0
    for (int i = 0; i < numberOfWeeks; i++) {
      weeklyRevenue[i] = 0.0;
    }
    
    // Get sales data for the date range
    final salesData = saleProvider.sales.where((sale) {
      return sale.saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             sale.saleDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
    
    // Aggregate sales by week
    for (final sale in salesData) {
      // Calculate week number from start date
      final daysDiff = sale.saleDate.difference(startDate).inDays;
      final weekNumber = (daysDiff / 7).floor();
      
      if (weekNumber >= 0 && weekNumber < numberOfWeeks) {
        weeklyRevenue[weekNumber] = weeklyRevenue[weekNumber]! + sale.totalAmount;
      }
    }
    
    // Convert to FlSpot list
    for (int i = 0; i < numberOfWeeks; i++) {
      final revenue = weeklyRevenue[i] ?? 0;
      spots.add(FlSpot(i.toDouble(), revenue));
    }
    
    return spots;
  }

  Widget _buildDailySalesChartContent(SaleProvider saleProvider, ThemeData theme) {
    final spots = _generateDailySalesSpots(saleProvider);
    
    if (spots.isEmpty || spots.every((spot) => spot.y == 0)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No sales data found for the selected period',
              style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<CurrencyProvider>(
      builder: (context, currencyProvider, child) {
        return LineChart(
          LineChartData(
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      currencyProvider.formatPrice(value),
                      style: theme.textTheme.bodySmall,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    if (value.toInt() >= 0 && value.toInt() < days.length) {
                      return Text(
                        days[value.toInt()],
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: theme.colorScheme.primary,
                barWidth: 3,
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        );
      },
    );
  }

  // Profit Analytics Section
  Widget _buildProfitAnalyticsSection(SaleProvider saleProvider, CurrencyProvider currencyProvider) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profit Analytics',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMedium),
        
        // Profit Summary Cards
        _buildProfitSummaryCards(saleProvider, currencyProvider),
        const SizedBox(height: AppConstants.spacingLarge),

        // Daily Profit Chart
        _buildDailyProfitChart(saleProvider),
        const SizedBox(height: AppConstants.spacingLarge),

        // Monthly Profit Chart
        _buildMonthlyProfitChart(saleProvider),
      ],
    );
  }

  Widget _buildProfitSummaryCards(SaleProvider saleProvider, CurrencyProvider currencyProvider) {
    return FutureBuilder<Map<String, double>>(
      future: _getProfitSummaryData(saleProvider),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final profitData = snapshot.data ?? {};
        final dailyProfit = profitData['daily'] ?? 0.0;
        final weeklyProfit = profitData['weekly'] ?? 0.0;
        final monthlyProfit = profitData['monthly'] ?? 0.0;
        final yearlyProfit = profitData['yearly'] ?? 0.0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildProfitCard(
                    'Today\'s Profit',
                    currencyProvider.formatPrice(dailyProfit),
                    Icons.today,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMedium),
                Expanded(
                  child: _buildProfitCard(
                    'Last 7 Days Profit',
                    currencyProvider.formatPrice(weeklyProfit),
                    Icons.date_range,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: _buildProfitCard(
                    'Monthly Profit',
                    currencyProvider.formatPrice(monthlyProfit),
                    Icons.calendar_month,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMedium),
                Expanded(
                  child: _buildProfitCard(
                    'Yearly Profit',
                    currencyProvider.formatPrice(yearlyProfit),
                    Icons.calendar_today,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfitCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: AppConstants.spacingSmall),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, double>> _getProfitSummaryData(SaleProvider saleProvider) async {
    final now = DateTime.now();
    
    // Always use fixed timeframes, independent of date range filter
    // Today's profit (current day only)
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    // Last 7 days profit (including today)
    final last7DaysStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final last7DaysEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    // Current month profit
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    // Current year profit
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year, 12, 31, 23, 59, 59);

    final dailyProfit = await saleProvider.getTotalProfitAmount(
      startDate: today,
      endDate: todayEnd,
    );
    
    final weeklyProfit = await saleProvider.getTotalProfitAmount(
      startDate: last7DaysStart,
      endDate: last7DaysEnd,
    );
    
    final monthlyProfit = await saleProvider.getTotalProfitAmount(
      startDate: monthStart,
      endDate: monthEnd,
    );
    
    final yearlyProfit = await saleProvider.getTotalProfitAmount(
      startDate: yearStart,
      endDate: yearEnd,
    );

    return {
      'daily': dailyProfit,
      'weekly': weeklyProfit,
      'monthly': monthlyProfit,
      'yearly': yearlyProfit,
    };
  }

  Widget _buildDailyProfitChart(SaleProvider saleProvider) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Profit (Last 7 Days)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            SizedBox(
              height: 200,
              child: _buildDailyProfitChartContent(saleProvider, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProfitChartContent(SaleProvider saleProvider, ThemeData theme) {
    return FutureBuilder<List<FlSpot>>(
      future: _generateDailyProfitSpots(saleProvider),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final spots = snapshot.data ?? [];
        
        if (spots.isEmpty || spots.every((spot) => spot.y == 0)) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 48,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Profit Data Available',
                  style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No profit data found for the selected period',
                  style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return LineChart(
          LineChartData(
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    return Consumer<CurrencyProvider>(
                      builder: (context, currencyProvider, child) {
                        return Text(
                          currencyProvider.formatPrice(value),
                          style: theme.textTheme.bodySmall,
                        );
                      },
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    final index = value.toInt();
                    if (index >= 0 && index < days.length) {
                      return Text(
                        days[index],
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.green,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
        color: Colors.green.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<FlSpot>> _generateDailyProfitSpots(SaleProvider saleProvider) async {
    final now = DateTime.now();
    // Always use last 7 days (including today), independent of date range filter
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final endDate = DateTime(now.year, now.month, now.day);
    
    final dailyProfit = await saleProvider.getDailyProfitForDateRange(startDate, endDate);
    final spots = <FlSpot>[];
    
    // Create a list to map weekdays correctly
    final weekdayMapping = <int>[];
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      weekdayMapping.add(currentDate.weekday - 1); // Convert to 0-based index (Mon=0, Sun=6)
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Generate spots with correct weekday mapping
    currentDate = startDate;
    for (int i = 0; i < 7; i++) {
      final dateStr = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      final profit = dailyProfit[dateStr] ?? 0.0;
      final weekdayIndex = weekdayMapping[i];
      spots.add(FlSpot(weekdayIndex.toDouble(), profit));
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Sort spots by x-axis to ensure proper display order
    spots.sort((a, b) => a.x.compareTo(b.x));
    
    return spots;
  }

  Widget _buildMonthlyProfitChart(SaleProvider saleProvider) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Profit (This Year)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            SizedBox(
              height: 200,
              child: _buildMonthlyProfitChartContent(saleProvider, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyProfitChartContent(SaleProvider saleProvider, ThemeData theme) {
    return FutureBuilder<List<BarChartGroupData>>(
      future: _generateMonthlyProfitBarGroups(saleProvider),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data ?? [];
        
        if (groups.isEmpty || groups.every((group) => group.barRods.first.toY == 0)) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 48,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Profit Data Available',
                  style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No profit data found for the selected period',
                  style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: groups.isNotEmpty 
                ? groups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.2
                : 100,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    Provider.of<CurrencyProvider>(context, listen: false).formatPrice(rod.toY),
                    TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    return Consumer<CurrencyProvider>(
                      builder: (context, currencyProvider, child) {
                        return Text(
                          currencyProvider.formatPrice(value),
                          style: theme.textTheme.bodySmall,
                        );
                      },
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final index = value.toInt();
                    if (index >= 0 && index < months.length) {
                      return Text(
                        months[index],
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            barGroups: groups,
          ),
        );
      },
    );
  }

  Future<List<BarChartGroupData>> _generateMonthlyProfitBarGroups(SaleProvider saleProvider) async {
    final now = DateTime.now();
    // Always use current year months, independent of date range filter
    final startDate = DateTime(now.year, 1, 1);
    final endDate = DateTime(now.year, 12, 31);
    
    final monthlyProfit = await saleProvider.getMonthlyProfitForDateRange(startDate, endDate);
    final barGroups = <BarChartGroupData>[];
    
    // Generate data for all 12 months of the current year
    for (int month = 1; month <= 12; month++) {
      final monthStr = '${now.year}-${month.toString().padLeft(2, '0')}';
      final profit = monthlyProfit[monthStr] ?? 0.0;
      
      barGroups.add(
        BarChartGroupData(
          x: month - 1, // 0-based index for chart
          barRods: [
            BarChartRodData(
              toY: profit,
              color: Colors.green,
              width: 20,
            ),
          ],
        ),
      );
    }
    
    return barGroups;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}