import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../../domain/entities/product.dart';
import '../../../core/constants/app_constants.dart';
import '../barcode_scanner_screen.dart';
import '../checkout/checkout_screen.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  
  double _discount = 0.0;
  double _tax = 0.0;

  @override
  void initState() {
    super.initState();
    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    
    await Future.wait([
      productProvider.loadProducts(),
      categoryProvider.loadCategories(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
            tooltip: 'Scan Barcode',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use responsive layout based on screen width
          if (constraints.maxWidth > 800) {
            // Desktop/Tablet layout - side by side
            return Row(
              children: [
                // Product Selection Panel
                Expanded(
                  flex: 3,
                  child: _buildProductPanel(theme),
                ),
                
                // Cart Panel
                Expanded(
                  flex: 2,
                  child: _buildCartPanel(),
                ),
              ],
            );
          } else {
            // Mobile layout - stacked with tabs or drawer
            // Mobile Layout - Stack vertically
            return Column(
              children: [
                // Product Panel - Takes most of the space
                Expanded(
                  flex: 4, // Increased to give more space to products
                  child: _buildProductPanel(theme),
                ),
                
                // Cart Panel - Flexible height with proper scrolling
                Expanded(
                  flex: 3, // Increased to give more space to cart
                  child: _buildCartPanel(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildProductPanel(ThemeData theme) {
    return Column(
      children: [
        // Search and Barcode Input
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Products',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  Provider.of<ProductProvider>(context, listen: false)
                      .searchProducts(value);
                },
              ),
              const SizedBox(height: AppConstants.spacingSmall),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Scan or Enter Barcode',
                        prefixIcon: const Icon(Icons.qr_code),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addProductByBarcode,
                        ),
                      ),
                      onSubmitted: (value) => _addProductByBarcode(),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSmall),
                  ElevatedButton.icon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Product List
        Expanded(
          child: Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              if (productProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = productProvider.searchQuery.isEmpty
                  ? productProvider.products
                  : productProvider.searchResults;

              if (products.isEmpty) {
                return const Center(
                  child: Text(
                    'No products found',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(products[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final theme = Theme.of(context);
    final isLowStock = product.stockQuantity <= AppConstants.lowStockThreshold;
    final isOutOfStock = product.stockQuantity == 0;
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOutOfStock 
              ? theme.colorScheme.error.withOpacity(0.3)
              : isLowStock 
                  ? Colors.orange.withOpacity(0.3)
                  : theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isOutOfStock ? null : () => _addProductToCart(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: product.imagePath != null && product.imagePath!.isNotEmpty
                            ? Image.file(
                                File(product.imagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildProductPlaceholder(theme, isOutOfStock);
                                },
                              )
                            : _buildProductPlaceholder(theme, isOutOfStock),
                      ),
                      
                      // Status badges
                      if (isLowStock || isOutOfStock)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOutOfStock ? theme.colorScheme.error : Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOutOfStock ? 'OUT' : 'LOW',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Product Details
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock ? theme.colorScheme.onSurface.withOpacity(0.5) : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Price and Stock info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Consumer<CurrencyProvider>(
                          builder: (context, currencyProvider, child) {
                            return Text(
                              currencyProvider.formatPrice(product.sellingPrice),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock ? theme.colorScheme.onSurface.withOpacity(0.5) : theme.colorScheme.primary,
                              ),
                            );
                          },
                        ),
                        
                        // Stock info
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${product.stockQuantity}',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final theme = Theme.of(context);
        final items = cartProvider.items;
        final subtotal = cartProvider.totalAmount;
        final discountAmount = subtotal * (_discount / 100);
        final taxAmount = (subtotal - discountAmount) * (_tax / 100);
        final total = subtotal - discountAmount + taxAmount;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
        color: theme.colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Cart Header - Ultra compact
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Further reduced padding
                decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      size: 14, // Reduced icon size
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4), // Reduced spacing
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Shopping Cart',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 10, // Further reduced font size
                            ),
                          ),
                          Text(
                            '${items.length} items',
                            style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 8, // Further reduced font size
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty)
                      IconButton(
                        onPressed: _clearCart,
                        icon: const Icon(Icons.clear_all),
                        iconSize: 14, // Reduced icon size
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20), // Reduced constraints
                        tooltip: 'Clear Cart',
                        style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.3),
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),

              // Cart Items List - Scrollable
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 32,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cart is empty',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add products to start',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder( // Changed back to ListView.builder for better scrolling
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Column(
                            children: [
                              _buildCartItem(item, theme),
                              if (index < items.length - 1) const Divider(height: 1),
                            ],
                          );
                        },
                      ),
              ),
              
              // Customer Information Section - Fixed at bottom
              _buildCustomerSection(),
              
              // Cart Summary with checkout buttons - Fixed at bottom
              if (items.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Discount and Tax Controls - Ultra compact
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 32, // Reduced height
                              child: TextField(
                                controller: _discountController,
                                decoration: InputDecoration(
                                  labelText: 'Discount (%)',
                                  labelStyle: TextStyle(fontSize: 10), // Reduced font size
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8), // Reduced border radius
                                  ),
                                  prefixIcon: const Icon(Icons.discount_outlined, size: 16), // Reduced icon size
                                  filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.8),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
                                ),
                                style: TextStyle(fontSize: 11), // Reduced font size
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _discount = double.tryParse(value) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8), // Reduced spacing
                          Expanded(
                            child: SizedBox(
                              height: 32, // Reduced height
                              child: TextField(
                                controller: _taxController,
                                decoration: InputDecoration(
                                  labelText: 'Tax (%)',
                                  labelStyle: TextStyle(fontSize: 10), // Reduced font size
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8), // Reduced border radius
                                  ),
                                  prefixIcon: const Icon(Icons.receipt_long_outlined, size: 16), // Reduced icon size
                                  filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.8),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
                                ),
                                style: TextStyle(fontSize: 11), // Reduced font size
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _tax = double.tryParse(value) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Summary totals - Ultra compact
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal:',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                              ),
                              Consumer<CurrencyProvider>(
                                builder: (context, currencyProvider, child) {
                                  return Text(
                                    currencyProvider.formatPrice(subtotal),
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (_discount > 0) ...[
                            const SizedBox(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Discount:',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontSize: 9,
                                  ),
                                ),
                                Consumer<CurrencyProvider>(
                                  builder: (context, currencyProvider, child) {
                                    return Text(
                                      '-${currencyProvider.formatPrice(discountAmount)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.error,
                                        fontSize: 9,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                          if (_tax > 0) ...[
                            const SizedBox(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tax:',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                                ),
                                Consumer<CurrencyProvider>(
                                  builder: (context, currencyProvider, child) {
                                    return Text(
                                      currencyProvider.formatPrice(taxAmount),
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
        color: theme.colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total:',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                Consumer<CurrencyProvider>(
                                  builder: (context, currencyProvider, child) {
                                    return Text(
                                      currencyProvider.formatPrice(total),
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                        fontSize: 11,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Checkout Button - Ultra compact
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed: cartProvider.isEmpty ? null : _navigateToCheckout,
                          icon: const Icon(Icons.payment, size: 14),
                          label: const Text(
                            'Checkout',
                            style: TextStyle(fontSize: 10), // Smaller text
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartItem(CartItem cartItem, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Reduced margin
      padding: const EdgeInsets.all(8), // Reduced padding
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8), // Reduced border radius
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product info and remove button row
          Row(
            children: [
              // Product image
              Container(
                width: 40, // Reduced size
                height: 40, // Reduced size
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: cartItem.product.imagePath != null && cartItem.product.imagePath!.isNotEmpty
                      ? Image.file(
                          File(cartItem.product.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.inventory_2_outlined,
                              size: 16, // Reduced size
                              color: theme.colorScheme.primary.withOpacity(0.6),
                            );
                          },
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          size: 16, // Reduced size
                          color: theme.colorScheme.primary.withOpacity(0.6),
                        ),
                ),
              ),
              
              const SizedBox(width: 8), // Reduced spacing
              
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cartItem.product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12, // Reduced font size
                      ),
                      maxLines: 1, // Reduced max lines
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '\$${cartItem.product.sellingPrice.toStringAsFixed(2)} each',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10, // Reduced font size
                      ),
                    ),
                  ],
                ),
              ),
              // Remove button
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: theme.colorScheme.error,
                ),
                onPressed: () {
                  Provider.of<CartProvider>(context, listen: false)
                      .removeProduct(cartItem.product.id!);
                },
                iconSize: 16, // Reduced size
                padding: const EdgeInsets.all(2), // Reduced padding
                constraints: const BoxConstraints(
                  minWidth: 24, // Reduced size
                  minHeight: 24, // Reduced size
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6), // Reduced spacing
          
          // Quantity controls and subtotal row
          Row(
            children: [
              // Quantity controls
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8), // Reduced border radius
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.remove_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        Provider.of<CartProvider>(context, listen: false)
                            .decrementQuantity(cartItem.product.id!);
                      },
                      iconSize: 14, // Reduced size
                      padding: const EdgeInsets.all(4), // Reduced padding
                      constraints: const BoxConstraints(
                        minWidth: 28, // Reduced size
                        minHeight: 28, // Reduced size
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced padding
                      child: Text(
                        cartItem.quantity.toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12, // Reduced font size
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        Provider.of<CartProvider>(context, listen: false)
                            .incrementQuantity(cartItem.product.id!);
                      },
                      iconSize: 14, // Reduced size
                      padding: const EdgeInsets.all(4), // Reduced padding
                      constraints: const BoxConstraints(
                        minWidth: 28, // Reduced size
                        minHeight: 28, // Reduced size
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Subtotal
              Consumer<CurrencyProvider>(
                builder: (context, currencyProvider, child) {
                  return Text(
                    currencyProvider.formatPrice(cartItem.product.sellingPrice * cartItem.quantity),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 12, // Reduced font size
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    final theme = Theme.of(context);
    
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduced padding
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
      title: Text(
        'Customer Information',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 11, // Reduced font size
        ),
      ),
      leading: Container(
        padding: const EdgeInsets.all(4), // Reduced padding
        decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6), // Reduced border radius
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: 16, // Reduced icon size
          color: theme.colorScheme.primary,
        ),
      ),
      children: [
        Column(
          children: [
            SizedBox(
              height: 32, // Reduced height
              child: TextField(
                controller: _customerNameController,
                decoration: InputDecoration(
                  labelText: 'Customer Name (Optional)',
                  labelStyle: TextStyle(fontSize: 10), // Reduced font size
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), // Reduced border radius
                  ),
                  prefixIcon: const Icon(Icons.person_outline, size: 16), // Reduced icon size
                  filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
                ),
                style: TextStyle(fontSize: 11), // Reduced font size
              ),
            ),
            const SizedBox(height: 6), // Reduced spacing
            SizedBox(
              height: 32, // Reduced height
              child: TextField(
                controller: _customerPhoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  labelStyle: TextStyle(fontSize: 10), // Reduced font size
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), // Reduced border radius
                  ),
                  prefixIcon: const Icon(Icons.phone_outlined, size: 16), // Reduced icon size
                  filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
                ),
                style: TextStyle(fontSize: 11), // Reduced font size
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildSummaryRow(String label, String value, ThemeData theme, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isDiscount 
                ? theme.colorScheme.error 
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _addProductToCart(Product product) {
    if (product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product is out of stock'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final currentQuantity = cartProvider.getProductQuantity(product.id!);
    
    if (currentQuantity >= product.stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
          'Cannot add more items than available stock',
          overflow: TextOverflow.ellipsis,
        ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    cartProvider.addProduct(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} added to cart',
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _addProductByBarcode() async {
    final messenger = ScaffoldMessenger.of(context);
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    // Show loading indicator
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Searching for product...',
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final product = await productProvider.getProductByBarcode(barcode);

      if (product == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Product with barcode "$barcode" not found',
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Clear',
              textColor: Colors.white,
              onPressed: () {
                _barcodeController.clear();
              },
            ),
          ),
        );
        return;
      }

      // Check if product is out of stock
      if (product.stockQuantity <= 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${product.name} is out of stock',
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.orange,
          ),
        );
        _barcodeController.clear();
        return;
      }

      _addProductToCart(product);
      _barcodeController.clear();
      
      // Show success feedback
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} added to cart',
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error searching for product: $e',
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scanBarcode() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Import mobile_scanner at the top of the file
      final result = await navigator.push(
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      );
      
      if (result != null && result is String) {
        _barcodeController.text = result;
        _addProductByBarcode();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error scanning barcode: $e',
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to clear all items from the cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false).clearCart();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _navigateToCheckout() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final checkoutProvider = Provider.of<CheckoutProvider>(context, listen: false);
    
    // Validate cart is not empty
    if (cartProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cart is empty. Add products to complete sale.',
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Transfer cart items to checkout provider
    checkoutProvider.clearCart();
    for (final cartItem in cartProvider.items) {
      checkoutProvider.addItem(cartItem.product, quantity: cartItem.quantity);
    }

    // Set customer name if provided
    final customerName = _customerNameController.text.trim();
    if (customerName.isNotEmpty) {
      checkoutProvider.setCustomerName(customerName);
    }

    // Parse and pass discount/tax percentages
    final discountText = _discountController.text.trim();
    final taxText = _taxController.text.trim();

    final discountPercent = double.tryParse(discountText) ?? 0.0;
    final taxPercent = double.tryParse(taxText) ?? 0.0;

    // Clamp values between 0 and 100 for safety
    checkoutProvider.setDiscountPercent(discountPercent.clamp(0.0, 100.0));
    checkoutProvider.setTaxPercent(taxPercent.clamp(0.0, 100.0));

    // Navigate to checkout screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  // Placeholder implementations to maintain structure; can be expanded later.
  Widget _buildDiscountTaxSection() {
    return const SizedBox.shrink();
  }

  Widget _buildTotalSection() {
    return const SizedBox.shrink();
  }

  Widget _buildProductPlaceholder(ThemeData theme, bool isOutOfStock) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
        theme.colorScheme.primaryContainer.withOpacity(0.3),
        theme.colorScheme.secondaryContainer.withOpacity(0.3),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: 20, // Reduced size
            color: isOutOfStock 
        ? theme.colorScheme.onSurface.withOpacity(0.4)
        : theme.colorScheme.primary.withOpacity(0.6),
          ),
        ),
      );
    }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }
}