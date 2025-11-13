import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../domain/entities/product.dart';
import '../../../core/constants/app_constants.dart';
import 'add_edit_product_screen.dart';
import 'product_details_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

    await Future.wait([
      productProvider.loadProducts(),
      productProvider.loadLowStockProducts(),
      productProvider.loadOutOfStockProducts(),
      categoryProvider.loadCategories(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Products', icon: Icon(Icons.inventory_2)),
            Tab(text: 'Low Stock', icon: Icon(Icons.warning)),
            Tab(text: 'Out of Stock', icon: Icon(Icons.error)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilter(theme),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllProductsTab(),
                _buildLowStockTab(),
                _buildOutOfStockTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "inventory_fab",
        onPressed: () => _navigateToAddProduct(),
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: AppConstants.spacingMedium),
          
          // Category Filter
          Consumer<CategoryProvider>(
            builder: (context, categoryProvider, child) {
              return DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Filter by Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...categoryProvider.categories.map(
                    (category) => DropdownMenuItem<String>(
                      value: category.id?.toString(),
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAllProductsTab() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (productProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppConstants.spacingMedium),
                Text(
                  'Error: ${productProvider.error}',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingMedium),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final filteredProducts = _filterProducts(productProvider.products);

        if (filteredProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppConstants.spacingMedium),
                Text(
                  _searchQuery.isNotEmpty || _selectedCategoryId != null
                      ? 'No products found matching your criteria'
                      : 'No products available',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingMedium),
                ElevatedButton(
                  onPressed: () => _navigateToAddProduct(),
                  child: const Text('Add First Product'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return _buildProductCard(product);
            },
          ),
        );
      },
    );
  }

  Widget _buildLowStockTab() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final lowStockProducts = productProvider.lowStockProducts;

        if (lowStockProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: AppConstants.spacingMedium),
                Text(
                  'No low stock items',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppConstants.spacingSmall),
                Text(
                  'All products have sufficient stock',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            itemCount: lowStockProducts.length,
            itemBuilder: (context, index) {
              final product = lowStockProducts[index];
              return _buildProductCard(product, showStockAlert: true);
            },
          ),
        );
      },
    );
  }

  Widget _buildOutOfStockTab() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final outOfStockProducts = productProvider.outOfStockProducts;

        if (outOfStockProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: AppConstants.spacingMedium),
                Text(
                  'No out of stock items',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppConstants.spacingSmall),
                Text(
                  'All products are in stock',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            itemCount: outOfStockProducts.length,
            itemBuilder: (context, index) {
              final product = outOfStockProducts[index];
              return _buildProductCard(product, showStockAlert: true);
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product, {bool showStockAlert = false}) {
    final theme = Theme.of(context);
    final isLowStock = product.isLowStock;
    final isOutOfStock = product.isOutOfStock;

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingMedium),
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        side: BorderSide(
          color: isOutOfStock 
              ? theme.colorScheme.error.withOpacity(0.3)
              : isLowStock
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.transparent,
          width: isOutOfStock || isLowStock ? 1.5 : 0,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToProductDetails(product),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Row(
            children: [
              // Product Image with enhanced styling
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: product.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                        child: File(product.imagePath!).existsSync()
                            ? Image.file(
                                File(product.imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.image_not_supported,
                                    size: AppConstants.iconLarge,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                  );
                                },
                              )
                            : Image.asset(
                                product.imagePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.image_not_supported,
                                    size: AppConstants.iconLarge,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                  );
                                },
                              ),
                      )
                    : Icon(
                        Icons.inventory_2_outlined,
                        size: AppConstants.iconLarge,
                        color: theme.colorScheme.primary.withOpacity(0.7),
                      ),
              ),
              const SizedBox(width: AppConstants.spacingMedium),
              
              // Product Info with enhanced layout
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name with better typography
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppConstants.spacingXSmall),
                    
                    // Price with enhanced styling
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Consumer<CurrencyProvider>(
                        builder: (context, currencyProvider, child) {
                          return Text(
                            currencyProvider.formatPrice(product.sellingPrice),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXSmall),
                    
                    // Category with enhanced chip design
                    Consumer<CategoryProvider>(
                      builder: (context, categoryProvider, child) {
                        final category = categoryProvider.categories
                            .where((cat) => cat.id == product.categoryId)
                            .firstOrNull;
                        
                        if (category == null) return const SizedBox.shrink();
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Stock status and actions with enhanced design
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Stock status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? theme.colorScheme.errorContainer
                          : isLowStock
                              ? Colors.orange.withOpacity(0.1)
                              : theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOutOfStock
                            ? theme.colorScheme.error.withOpacity(0.3)
                            : isLowStock
                                ? Colors.orange.withOpacity(0.3)
                                : theme.colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOutOfStock
                              ? Icons.error_outline
                              : isLowStock
                                  ? Icons.warning_amber_outlined
                                  : Icons.check_circle_outline,
                          size: 14,
                          color: isOutOfStock
                              ? theme.colorScheme.error
                              : isLowStock
                                  ? Colors.orange
                                  : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.stockQuantity}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock
                                ? theme.colorScheme.error
                                : isLowStock
                                    ? Colors.orange
                                    : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSmall),
                  
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => _navigateToEditProduct(product),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          tooltip: 'Edit Product',
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Delete button
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () => _showDeleteConfirmation(product),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          tooltip: 'Delete Product',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    var filtered = products;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (product.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (product.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Filter by category
    if (_selectedCategoryId != null) {
      filtered = filtered.where((product) {
        return product.categoryId == _selectedCategoryId;
      }).toList();
    }

    return filtered;
  }

  void _handleProductAction(String action, Product product) {
    switch (action) {
      case 'view':
        _navigateToProductDetails(product);
        break;
      case 'edit':
        _navigateToEditProduct(product);
        break;
      case 'stock':
        _showUpdateStockDialog(product);
        break;
      case 'delete':
        _showDeleteConfirmation(product);
        break;
    }
  }

  void _navigateToAddProduct() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddEditProductScreen(),
      ),
    ).then((_) => _refreshData());
  }

  void _navigateToEditProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(product: product),
      ),
    ).then((_) => _refreshData());
  }

  void _navigateToProductDetails(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }

  void _showUpdateStockDialog(Product product) {
    final controller = TextEditingController(text: product.stockQuantity.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock - ${product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stock Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(controller.text);
              if (newStock != null && newStock >= 0) {
                Navigator.of(context).pop();
                
                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                await productProvider.updateStock(product.id!, newStock);
                
                if (productProvider.error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock updated successfully')),
                  );
                  _refreshData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${productProvider.error}')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              await productProvider.deleteProduct(product.id!);
              
              if (productProvider.error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted successfully')),
                );
                _refreshData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${productProvider.error}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
