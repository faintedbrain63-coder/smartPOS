import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
  Future<Product?> getProductById(int id);
  Future<Product?> getProductByBarcode(String barcode);
  Future<List<Product>> getProductsByCategory(int categoryId);
  Future<int> insertProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<List<Product>> searchProducts(String query);
  Future<List<Product>> getLowStockProducts({int threshold = 10});
  Future<List<Product>> getOutOfStockProducts();
  Future<int> updateProductStock(int productId, int newQuantity);
  Future<bool> productExists(String name, {int? excludeId});
  Future<bool> barcodeExists(String barcode, {int? excludeId});
}