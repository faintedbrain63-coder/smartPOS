import 'package:flutter/foundation.dart';
import '../../domain/entities/category.dart' as entities;
import '../../domain/repositories/category_repository.dart';

class CategoryProvider with ChangeNotifier {
  final CategoryRepository _categoryRepository;

  CategoryProvider(this._categoryRepository);

  List<entities.Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<entities.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCategories() async {
    _setLoading(true);
    _setError(null);

    try {
      _categories = await _categoryRepository.getAllCategories();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load categories: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addCategory(entities.Category category) async {
    _setError(null);

    try {
      // Check if category name already exists
      final exists = await _categoryRepository.categoryExists(category.name);
      if (exists) {
        _setError('Category with this name already exists');
        return false;
      }

      final id = await _categoryRepository.insertCategory(category);
      if (id > 0) {
        await loadCategories(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to add category: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateCategory(entities.Category category) async {
    _setError(null);

    try {
      // Check if category name already exists (excluding current category)
      final exists = await _categoryRepository.categoryExists(
        category.name,
        excludeId: category.id,
      );
      if (exists) {
        _setError('Category with this name already exists');
        return false;
      }

      final result = await _categoryRepository.updateCategory(category);
      if (result > 0) {
        await loadCategories(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update category: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    _setError(null);

    try {
      final result = await _categoryRepository.deleteCategory(id);
      if (result > 0) {
        await loadCategories(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to delete category: ${e.toString()}');
      return false;
    }
  }

  Future<List<entities.Category>> searchCategories(String query) async {
    if (query.isEmpty) {
      return _categories;
    }

    try {
      return await _categoryRepository.searchCategories(query);
    } catch (e) {
      _setError('Failed to search categories: ${e.toString()}');
      return [];
    }
  }

  entities.Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
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
}