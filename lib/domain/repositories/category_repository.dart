import '../entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getAllCategories();
  Future<Category?> getCategoryById(int id);
  Future<int> insertCategory(Category category);
  Future<int> updateCategory(Category category);
  Future<int> deleteCategory(int id);
  Future<List<Category>> searchCategories(String query);
  Future<bool> categoryExists(String name, {int? excludeId});
}