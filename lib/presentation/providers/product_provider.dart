import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductProvider with ChangeNotifier {
  final ProductRepository _productRepository;

  ProductProvider(this._productRepository);

  List<Product> _products = [];
  List<Product> _lowStockProducts = [];
  List<Product> _outOfStockProducts = [];
  List<Product> _searchResults = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Product> get lowStockProducts => _lowStockProducts;
  List<Product> get outOfStockProducts => _outOfStockProducts;
  List<Product> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalProducts => _products.length;
  int get lowStockCount => _lowStockProducts.length;
  int get outOfStockCount => _outOfStockProducts.length;

  Future<void> loadProducts() async {
    _setLoading(true);
    _setError(null);

    try {
      _products = await _productRepository.getAllProducts();
      await _loadStockAlerts();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load products: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadStockAlerts() async {
    try {
      _lowStockProducts = await _productRepository.getLowStockProducts();
      _outOfStockProducts = await _productRepository.getOutOfStockProducts();
    } catch (e) {
      // Handle silently for stock alerts
    }
  }

  /// Silent refresh for inventory updates (called after sales/credits)
  /// Does not show loading state to avoid UI flicker
  Future<void> refreshInventory() async {
    try {
      print('🔄 PRODUCT_PROVIDER: Refreshing inventory after sales/credit operation...');
      _products = await _productRepository.getAllProducts();
      await _loadStockAlerts();
      notifyListeners();
      print('✅ PRODUCT_PROVIDER: Inventory refreshed successfully');
    } catch (e) {
      print('⚠️ PRODUCT_PROVIDER: Failed to refresh inventory: $e');
      // Don't set error to avoid disrupting user flow
    }
  }

  Future<List<Product>> getProductsByCategory(int categoryId) async {
    try {
      return await _productRepository.getProductsByCategory(categoryId);
    } catch (e) {
      _setError('Failed to load products by category: ${e.toString()}');
      return [];
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      return await _productRepository.getProductByBarcode(barcode);
    } catch (e) {
      _setError('Failed to find product by barcode: ${e.toString()}');
      return null;
    }
  }

  Future<bool> addProduct(Product product) async {
    _setError(null);

    try {
      // Check if product name already exists
      final nameExists = await _productRepository.productExists(product.name);
      if (nameExists) {
        _setError('Product with this name already exists');
        return false;
      }

      // Check if barcode already exists (if provided)
      if (product.barcode != null && product.barcode!.isNotEmpty) {
        final barcodeExists = await _productRepository.barcodeExists(product.barcode!);
        if (barcodeExists) {
          _setError('Product with this barcode already exists');
          return false;
        }
      }

      final id = await _productRepository.insertProduct(product);
      if (id > 0) {
        await loadProducts(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to add product: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    _setError(null);

    try {
      // Check if product name already exists (excluding current product)
      final nameExists = await _productRepository.productExists(
        product.name,
        excludeId: product.id,
      );
      if (nameExists) {
        _setError('Product with this name already exists');
        return false;
      }

      // Check if barcode already exists (excluding current product)
      if (product.barcode != null && product.barcode!.isNotEmpty) {
        final barcodeExists = await _productRepository.barcodeExists(
          product.barcode!,
          excludeId: product.id,
        );
        if (barcodeExists) {
          _setError('Product with this barcode already exists');
          return false;
        }
      }

      final result = await _productRepository.updateProduct(product);
      if (result > 0) {
        await loadProducts(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update product: ${e.toString()}');
      return false;
    }
  }

  Future<bool> checkProductNameExists(String name, {int? excludeId}) async {
    try {
      return await _productRepository.productExists(name, excludeId: excludeId);
    } catch (e) {
      _setError('Failed to check product name: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    _setError(null);

    try {
      final result = await _productRepository.deleteProduct(id);
      if (result > 0) {
        await loadProducts(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to delete product: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateProductStock(int productId, int newQuantity) async {
    _setError(null);

    try {
      final result = await _productRepository.updateProductStock(productId, newQuantity);
      if (result > 0) {
        await loadProducts(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update product stock: ${e.toString()}');
      return false;
    }
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      _searchResults = await _productRepository.searchProducts(query);
      notifyListeners();
    } catch (e) {
      _setError('Failed to search products: ${e.toString()}');
      _searchResults = [];
    }
  }

  Product? getProductById(int id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> checkBarcodeExists(String barcode, {int? excludeId}) async {
    try {
      return await _productRepository.barcodeExists(barcode, excludeId: excludeId);
    } catch (e) {
      _setError('Failed to check barcode: ${e.toString()}');
      return false;
    }
  }

  Future<void> loadOutOfStockProducts() async {
    try {
      _outOfStockProducts = await _productRepository.getOutOfStockProducts();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load out of stock products: ${e.toString()}');
    }
  }

  Future<void> loadLowStockProducts() async {
    try {
      _lowStockProducts = await _productRepository.getLowStockProducts();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load low stock products: ${e.toString()}');
    }
  }

  Future<bool> updateStock(int productId, int newQuantity) async {
    return await updateProductStock(productId, newQuantity);
  }
}