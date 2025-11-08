import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/database_helper.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final DatabaseHelper _databaseHelper;

  ProductRepositoryImpl(this._databaseHelper);

  @override
  Future<List<Product>> getAllProducts() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return ProductModel.fromMap(maps[i]);
    });
  }

  @override
  Future<Product?> getProductById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ProductModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (maps.isNotEmpty) {
      return ProductModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return ProductModel.fromMap(maps[i]);
    });
  }

  @override
  Future<int> insertProduct(Product product) async {
    final db = await _databaseHelper.database;
    final productModel = ProductModel.fromEntity(product);
    final now = DateTime.now().toIso8601String();
    
    final map = productModel.toMap();
    map['created_at'] = now;
    map['updated_at'] = now;
    map.remove('id'); // Remove id for auto-increment

    return await db.insert('products', map);
  }

  @override
  Future<int> updateProduct(Product product) async {
    final db = await _databaseHelper.database;
    final productModel = ProductModel.fromEntity(product);
    
    final map = productModel.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    map.remove('created_at'); // Don't update created_at

    return await db.update(
      'products',
      map,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  @override
  Future<int> deleteProduct(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'name LIKE ? OR description LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return ProductModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<Product>> getLowStockProducts({int threshold = 10}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'stock_quantity <= ? AND stock_quantity > 0',
      whereArgs: [threshold],
      orderBy: 'stock_quantity ASC',
    );

    return List.generate(maps.length, (i) {
      return ProductModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<Product>> getOutOfStockProducts() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'stock_quantity <= 0',
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return ProductModel.fromMap(maps[i]);
    });
  }

  @override
  Future<int> updateProductStock(int productId, int newQuantity) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'products',
      {
        'stock_quantity': newQuantity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  @override
  Future<bool> productExists(String name, {int? excludeId}) async {
    final db = await _databaseHelper.database;
    
    String whereClause = 'LOWER(name) = LOWER(?)';
    List<dynamic> whereArgs = [name];
    
    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return maps.isNotEmpty;
  }

  @override
  Future<bool> barcodeExists(String barcode, {int? excludeId}) async {
    final db = await _databaseHelper.database;
    
    String whereClause = 'barcode = ?';
    List<dynamic> whereArgs = [barcode];
    
    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return maps.isNotEmpty;
  }
}