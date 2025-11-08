import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/category.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import 'add_edit_product_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategoryName();
    });
  }

  Future<void> _loadCategoryName() async {
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    await categoryProvider.loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentProduct.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editProduct,
            tooltip: 'Edit Product',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'update_stock',
                child: ListTile(
                  leading: Icon(Icons.add_box),
                  title: Text('Update Stock'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete Product', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image and Basic Info
            _buildProductHeader(theme),
            const SizedBox(height: AppConstants.spacingLarge),

            // Stock Status Card
            _buildStockStatusCard(theme),
            const SizedBox(height: AppConstants.spacingLarge),

            // Pricing Information
            _buildPricingCard(theme),
            const SizedBox(height: AppConstants.spacingLarge),

            // Product Details
            _buildDetailsCard(theme),
            const SizedBox(height: AppConstants.spacingLarge),

            // Category Information
            _buildCategoryCard(theme),
            
            if (_currentProduct.barcode != null) ...[
              const SizedBox(height: AppConstants.spacingLarge),
              _buildBarcodeCard(theme),
            ],

            if (_currentProduct.description != null) ...[
              const SizedBox(height: AppConstants.spacingLarge),
              _buildDescriptionCard(theme),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "product_details_fab",
        onPressed: _editProduct,
        icon: const Icon(Icons.edit),
        label: const Text('Edit Product'),
      ),
    );
  }

  Widget _buildProductHeader(ThemeData theme) {
    final isLowStock = _currentProduct.isLowStock;
    final isOutOfStock = _currentProduct.isOutOfStock;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            // Product Image
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              ),
              child: _currentProduct.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                      child: File(_currentProduct.imagePath!).existsSync()
                          ? Image.file(
                              File(_currentProduct.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.image_not_supported,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant,
                                );
                              },
                            )
                          : Image.asset(
                              _currentProduct.imagePath!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.image_not_supported,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant,
                                );
                              },
                            ),
                    )
                  : Icon(
                      Icons.inventory_2,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),

            // Product Name
            Text(
              _currentProduct.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingSmall),

            // Stock Status Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMedium,
                vertical: AppConstants.paddingSmall,
              ),
              decoration: BoxDecoration(
                color: isOutOfStock
                    ? theme.colorScheme.errorContainer
                    : isLowStock
                        ? Colors.orange.withOpacity(0.2)
                        : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOutOfStock
                        ? Icons.error
                        : isLowStock
                            ? Icons.warning
                            : Icons.check_circle,
                    size: 16,
                    color: isOutOfStock
                        ? theme.colorScheme.error
                        : isLowStock
                            ? Colors.orange
                            : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppConstants.spacingSmall),
                  Text(
                    isOutOfStock
                        ? 'Out of Stock'
                        : isLowStock
                            ? 'Low Stock'
                            : 'In Stock',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOutOfStock
                          ? theme.colorScheme.error
                          : isLowStock
                              ? Colors.orange
                              : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
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

  Widget _buildStockStatusCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingSmall),
                Text(
                  'Stock Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Stock',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXSmall),
                    Text(
                      '${_currentProduct.stockQuantity} units',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _currentProduct.isOutOfStock
                            ? theme.colorScheme.error
                            : _currentProduct.isLowStock
                                ? Colors.orange
                                : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showUpdateStockDialog,
                  icon: const Icon(Icons.add_box),
                  label: const Text('Update Stock'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard(ThemeData theme) {
    final profit = _currentProduct.profit;
    final profitMargin = _currentProduct.costPrice > 0 
        ? (profit / _currentProduct.costPrice) * 100 
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingSmall),
                Text(
                  'Pricing Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: Consumer<CurrencyProvider>(
                    builder: (context, currencyProvider, child) {
                      return _buildPriceItem(
                        'Cost Price',
                        currencyProvider.formatPrice(_currentProduct.costPrice),
                        theme.colorScheme.error,
                        theme,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Consumer<CurrencyProvider>(
                    builder: (context, currencyProvider, child) {
                      return _buildPriceItem(
                        'Selling Price',
                        currencyProvider.formatPrice(_currentProduct.sellingPrice),
                        theme.colorScheme.primary,
                        theme,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profit per Unit',
                        style: theme.textTheme.bodySmall,
                      ),
                      Consumer<CurrencyProvider>(
                        builder: (context, currencyProvider, child) {
                          return Text(
                            currencyProvider.formatPrice(profit),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: profit >= 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Profit Margin',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '${profitMargin.toStringAsFixed(1)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: profitMargin >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceItem(String label, String value, Color color, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXSmall),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingSmall),
                Text(
                  'Product Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            _buildDetailRow('Product ID', _currentProduct.id?.toString() ?? 'N/A', theme),
            _buildDetailRow('Created', _currentProduct.createdAt != null ? Formatters.formatDate(_currentProduct.createdAt!) : 'N/A', theme),
            _buildDetailRow('Last Updated', _currentProduct.updatedAt != null ? Formatters.formatDate(_currentProduct.updatedAt!) : 'N/A', theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(ThemeData theme) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        final category = categoryProvider.categories
            .where((cat) => cat.id == _currentProduct.categoryId)
            .firstOrNull;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.category,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppConstants.spacingSmall),
                    Text(
                      'Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingMedium),
                if (category != null) ...[
                  Text(
                    category.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (category.description != null) ...[
                    const SizedBox(height: AppConstants.spacingSmall),
                    Text(
                      category.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ] else
                  Text(
                    'Category not found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarcodeCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.qr_code,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingSmall),
                Text(
                  'Barcode',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: Text(
                _currentProduct.barcode!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingSmall),
                Text(
                  'Description',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Text(
              _currentProduct.description!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'update_stock':
        _showUpdateStockDialog();
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  void _editProduct() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(product: _currentProduct),
      ),
    ).then((result) {
      // Refresh product data if it was updated
      if (result == true) {
        _refreshProductData();
      }
    });
  }

  void _showUpdateStockDialog() {
    final controller = TextEditingController(text: _currentProduct.stockQuantity.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock - ${_currentProduct.name}'),
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
                await productProvider.updateProductStock(_currentProduct.id!, newStock);
                
                if (productProvider.error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock updated successfully')),
                  );
                  _refreshProductData();
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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${_currentProduct.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              await productProvider.deleteProduct(_currentProduct.id!);
              
              if (productProvider.error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted successfully')),
                );
                Navigator.of(context).pop(); // Go back to inventory screen
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

  Future<void> _refreshProductData() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    await productProvider.loadProducts();
    
    // Find the updated product
    final updatedProduct = productProvider.products
        .where((p) => p.id == _currentProduct.id)
        .firstOrNull;
    
    if (updatedProduct != null) {
      setState(() {
        _currentProduct = updatedProduct;
      });
    }
  }
}