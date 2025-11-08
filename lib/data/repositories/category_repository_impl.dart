import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/database_helper.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final DatabaseHelper _databaseHelper;

  CategoryRepositoryImpl(this._databaseHelper);

  @override
  Future<List<Category>> getAllCategories() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return CategoryModel.fromMap(maps[i]);
    });
  }

  @override
  Future<Category?> getCategoryById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return CategoryModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<int> insertCategory(Category category) async {
    final db = await _databaseHelper.database;
    final categoryModel = CategoryModel.fromEntity(category);
    final now = DateTime.now().toIso8601String();
    
    final map = categoryModel.toMap();
    map['created_at'] = now;
    map['updated_at'] = now;
    map.remove('id'); // Remove id for auto-increment

    return await db.insert('categories', map);
  }

  @override
  Future<int> updateCategory(Category category) async {
    final db = await _databaseHelper.database;
    final categoryModel = CategoryModel.fromEntity(category);
    
    final map = categoryModel.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    map.remove('created_at'); // Don't update created_at

    return await db.update(
      'categories',
      map,
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<int> deleteCategory(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Category>> searchCategories(String query) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return CategoryModel.fromMap(maps[i]);
    });
  }

  @override
  Future<bool> categoryExists(String name, {int? excludeId}) async {
    final db = await _databaseHelper.database;
    
    String whereClause = 'LOWER(name) = LOWER(?)';
    List<dynamic> whereArgs = [name];
    
    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return maps.isNotEmpty;
  }
}