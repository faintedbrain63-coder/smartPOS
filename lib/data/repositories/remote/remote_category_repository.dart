import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../domain/entities/category.dart' as entities;
import '../../../domain/repositories/category_repository.dart';

/// Remote implementation of CategoryRepository that queries the server
class RemoteCategoryRepository implements CategoryRepository {
  final String serverUrl;
  final String apiKey;

  RemoteCategoryRepository({required this.serverUrl, required this.apiKey});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  entities.Category _categoryFromJson(Map<String, dynamic> json) {
    return entities.Category(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  @override
  Future<List<entities.Category>> getAllCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/categories'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final categoriesList = data['categories'] as List;
        return categoriesList
            .map((c) => _categoryFromJson(c as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to get categories: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteCategoryRepository.getAllCategories error: $e');
      rethrow;
    }
  }

  @override
  Future<entities.Category?> getCategoryById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/categories/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _categoryFromJson(data['category'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to get category: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteCategoryRepository.getCategoryById error: $e');
      rethrow;
    }
  }

  @override
  Future<int> insertCategory(entities.Category category) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/categories'),
        headers: _headers,
        body: jsonEncode({
          'name': category.name,
          'description': category.description,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int;
      }
      throw Exception('Failed to create category: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteCategoryRepository.insertCategory error: $e');
      rethrow;
    }
  }

  @override
  Future<int> updateCategory(entities.Category category) async {
    try {
      final response = await http.put(
        Uri.parse('$serverUrl/api/categories/${category.id}'),
        headers: _headers,
        body: jsonEncode({
          'name': category.name,
          'description': category.description,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return 1;
      }
      throw Exception('Failed to update category: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteCategoryRepository.updateCategory error: $e');
      rethrow;
    }
  }

  @override
  Future<int> deleteCategory(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$serverUrl/api/categories/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return 1;
      }
      throw Exception('Failed to delete category: ${response.statusCode}');
    } catch (e) {
      print('❌ RemoteCategoryRepository.deleteCategory error: $e');
      rethrow;
    }
  }

  @override
  Future<List<entities.Category>> searchCategories(String query) async {
    final all = await getAllCategories();
    return all.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();
  }

  @override
  Future<bool> categoryExists(String name, {int? excludeId}) async {
    final all = await getAllCategories();
    return all.any((c) => c.name.toLowerCase() == name.toLowerCase() && c.id != excludeId);
  }
}
