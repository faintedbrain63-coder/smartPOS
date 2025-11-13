import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../data/datasources/database_helper.dart';

class BackupService {
  final DatabaseHelper _databaseHelper;

  BackupService(this._databaseHelper);

  /// Export all data to JSON format
  Future<String?> exportData() async {
    try {
      final db = await _databaseHelper.database;
      
      // Get all data from tables
      final categories = await db.query('categories', orderBy: 'id ASC');
      final products = await db.query('products', orderBy: 'id ASC');
      final sales = await db.query('sales', orderBy: 'id ASC');
      final saleItems = await db.query('sale_items', orderBy: 'id ASC');
      
      // Create backup data structure
      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'categories': categories,
          'products': products,
          'sales': sales,
          'sale_items': saleItems,
        }
      };
      
      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      
      // Save to file
      final fileName = 'smartpos_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      
      // Use file_picker to save on all platforms - let user choose location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(jsonString),
      );
      return result;
    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }

  /// Import data from JSON file
  Future<bool> importData(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }
      
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate backup structure
      if (!_validateBackupStructure(backupData)) {
        throw Exception('Invalid backup file format');
      }
      
      final db = await _databaseHelper.database;
      
      // Start transaction
      await db.transaction((txn) async {
        // Clear existing data
        await txn.delete('sale_items');
        await txn.delete('sales');
        await txn.delete('products');
        await txn.delete('categories');
        
        // Reset auto-increment counters
        await txn.execute('DELETE FROM sqlite_sequence WHERE name IN ("categories", "products", "sales", "sale_items")');
        
        final data = backupData['data'] as Map<String, dynamic>;
        
        // Import categories first (due to foreign key constraints)
        final categories = data['categories'] as List<dynamic>;
        for (final category in categories) {
          await txn.insert('categories', category as Map<String, dynamic>);
        }
        
        // Import products
        final products = data['products'] as List<dynamic>;
        for (final product in products) {
          await txn.insert('products', product as Map<String, dynamic>);
        }
        
        // Import sales
        final sales = data['sales'] as List<dynamic>;
        for (final sale in sales) {
          await txn.insert('sales', sale as Map<String, dynamic>);
        }
        
        // Import sale items
        final saleItems = data['sale_items'] as List<dynamic>;
        for (final saleItem in saleItems) {
          await txn.insert('sale_items', saleItem as Map<String, dynamic>);
        }
      });
      
      return true;
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }

  /// Pick and import backup file
  Future<bool> pickAndImportData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        return await importData(result.files.single.path!);
      }
      
      return false;
    } catch (e) {
      throw Exception('Failed to pick and import data: $e');
    }
  }

  /// Clear all data from database
  Future<bool> clearAllData() async {
    try {
      final db = await _databaseHelper.database;
      
      await db.transaction((txn) async {
        // Delete all data in correct order (respecting foreign keys)
        await txn.delete('sale_items');
        await txn.delete('sales');
        await txn.delete('products');
        await txn.delete('categories');
        
        // Reset auto-increment counters
        await txn.execute('DELETE FROM sqlite_sequence WHERE name IN ("categories", "products", "sales", "sale_items")');
      });
      
      return true;
    } catch (e) {
      throw Exception('Failed to clear data: $e');
    }
  }

  /// Validate backup file structure
  bool _validateBackupStructure(Map<String, dynamic> backupData) {
    try {
      // Check required fields
      if (!backupData.containsKey('version') || 
          !backupData.containsKey('timestamp') || 
          !backupData.containsKey('data')) {
        return false;
      }
      
      final data = backupData['data'] as Map<String, dynamic>;
      
      // Check required tables
      if (!data.containsKey('categories') || 
          !data.containsKey('products') || 
          !data.containsKey('sales') || 
          !data.containsKey('sale_items')) {
        return false;
      }
      
      // Check if data is in list format
      return data['categories'] is List &&
             data['products'] is List &&
             data['sales'] is List &&
             data['sale_items'] is List;
    } catch (e) {
      return false;
    }
  }

  /// Get backup file info
  Future<Map<String, dynamic>?> getBackupInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      if (!_validateBackupStructure(backupData)) {
        return null;
      }
      
      final data = backupData['data'] as Map<String, dynamic>;
      
      return {
        'version': backupData['version'],
        'timestamp': backupData['timestamp'],
        'categories_count': (data['categories'] as List).length,
        'products_count': (data['products'] as List).length,
        'sales_count': (data['sales'] as List).length,
        'sale_items_count': (data['sale_items'] as List).length,
      };
    } catch (e) {
      return null;
    }
  }
}