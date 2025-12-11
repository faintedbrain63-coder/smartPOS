import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../domain/entities/product.dart';
import '../../../domain/repositories/product_repository.dart';

/// Remote implementation of ProductRepository that queries the server
class RemoteProductRepository implements ProductRepository {
  final String serverUrl;
  final String apiKey;

  RemoteProductRepository({required this.serverUrl, required this.apiKey});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  Product _productFromJson(Map<String, dynamic> json) {
    // Convert local image paths to server URLs
    String? imagePath = json['image_path'] as String?;
    if (imagePath != null && imagePath.isNotEmpty && !imagePath.startsWith('http')) {
      // Convert local path to server image URL
      imagePath = '$serverUrl/api/images?path=${Uri.encodeComponent(imagePath)}';
    }
    
    return Product(
      id: json['id'] as int?,
      name: json['name'] as String,
      imagePath: imagePath,
      categoryId: json['category_id'] as int,
      costPrice: (json['cost_price'] ?? json['cost'] ?? 0).toDouble(),
      sellingPrice: (json['selling_price'] ?? json['price'] ?? 0).toDouble(),
      barcode: json['barcode'] as String?,
      stockQuantity: json['stock_quantity'] ?? json['quantity'] ?? 0,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> _productToJson(Product product) {
    return {
      'name': product.name,
      'barcode': product.barcode,
      'category_id': product.categoryId,
      'price': product.sellingPrice,
      'cost': product.costPrice,
      'quantity': product.stockQuantity,
      'image_path': product.imagePath,
    };
  }

  @override
  Future<List<Product>> getAllProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/products'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final productsList = data['products'] as List;
        return productsList
            .map((p) => _productFromJson(p as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to get products: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteProductRepository.getAllProducts error: $e');
      rethrow;
    }
  }

  @override
  Future<Product?> getProductById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/products/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _productFromJson(data['product'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to get product: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteProductRepository.getProductById error: $e');
      rethrow;
    }
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final all = await getAllProducts();
    try {
      return all.firstWhere((p) => p.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    final all = await getAllProducts();
    return all.where((p) => p.categoryId == categoryId).toList();
  }

  @override
  Future<int> insertProduct(Product product) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/products'),
        headers: _headers,
        body: jsonEncode(_productToJson(product)),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int;
      }
      throw Exception('Failed to create product: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteProductRepository.insertProduct error: $e');
      rethrow;
    }
  }

  @override
  Future<int> updateProduct(Product product) async {
    try {
      final response = await http.put(
        Uri.parse('$serverUrl/api/products/${product.id}'),
        headers: _headers,
        body: jsonEncode(_productToJson(product)),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return 1;
      }
      throw Exception('Failed to update product: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteProductRepository.updateProduct error: $e');
      rethrow;
    }
  }

  @override
  Future<int> deleteProduct(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$serverUrl/api/products/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return 1;
      }
      throw Exception('Failed to delete product: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteProductRepository.deleteProduct error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/products/search?q=${Uri.encodeComponent(query)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final productsList = data['products'] as List;
        return productsList
            .map((p) => _productFromJson(p as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to search products: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteProductRepository.searchProducts error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Product>> getLowStockProducts({int threshold = 10}) async {
    final all = await getAllProducts();
    return all.where((p) => p.stockQuantity > 0 && p.stockQuantity <= threshold).toList();
  }

  @override
  Future<List<Product>> getOutOfStockProducts() async {
    final all = await getAllProducts();
    return all.where((p) => p.stockQuantity == 0).toList();
  }

  @override
  Future<int> updateProductStock(int productId, int newQuantity) async {
    final product = await getProductById(productId);
    if (product != null) {
      return await updateProduct(product.copyWith(stockQuantity: newQuantity));
    }
    return 0;
  }

  @override
  Future<bool> productExists(String name, {int? excludeId}) async {
    final all = await getAllProducts();
    return all.any((p) => p.name.toLowerCase() == name.toLowerCase() && p.id != excludeId);
  }

  @override
  Future<bool> barcodeExists(String barcode, {int? excludeId}) async {
    final all = await getAllProducts();
    return all.any((p) => p.barcode == barcode && p.id != excludeId);
  }
}
