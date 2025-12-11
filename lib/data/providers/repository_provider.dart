import 'package:flutter/foundation.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/sale_repository.dart';
import '../repositories/category_repository_impl.dart';
import '../repositories/product_repository_impl.dart';
import '../repositories/sale_repository_impl.dart';
import '../repositories/remote/remote_category_repository.dart';
import '../repositories/remote/remote_product_repository.dart';
import '../repositories/remote/remote_sale_repository.dart';
import '../datasources/database_helper.dart';

/// Manages repository instances and switches between local and remote based on sync mode
class RepositoryProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  
  bool _isClientMode = false;
  String? _serverUrl;
  String? _apiKey;
  
  // Local repositories
  late final CategoryRepositoryImpl _localCategoryRepo;
  late final ProductRepositoryImpl _localProductRepo;
  late final SaleRepositoryImpl _localSaleRepo;
  
  // Remote repositories (created on demand when in client mode)
  RemoteCategoryRepository? _remoteCategoryRepo;
  RemoteProductRepository? _remoteProductRepo;
  RemoteSaleRepository? _remoteSaleRepo;
  
  RepositoryProvider(this._databaseHelper) {
    _localCategoryRepo = CategoryRepositoryImpl(_databaseHelper);
    _localProductRepo = ProductRepositoryImpl(_databaseHelper);
    _localSaleRepo = SaleRepositoryImpl(_databaseHelper);
  }
  
  bool get isClientMode => _isClientMode;
  String? get serverUrl => _serverUrl;
  
  /// Get the appropriate CategoryRepository based on current mode
  CategoryRepository get categoryRepository {
    if (_isClientMode && _remoteCategoryRepo != null) {
      return _remoteCategoryRepo!;
    }
    return _localCategoryRepo;
  }
  
  /// Get the appropriate ProductRepository based on current mode
  ProductRepository get productRepository {
    if (_isClientMode && _remoteProductRepo != null) {
      return _remoteProductRepo!;
    }
    return _localProductRepo;
  }
  
  /// Get the appropriate SaleRepository based on current mode
  SaleRepository get saleRepository {
    if (_isClientMode && _remoteSaleRepo != null) {
      return _remoteSaleRepo!;
    }
    return _localSaleRepo;
  }
  
  /// Switch to client mode with server connection details
  void enableClientMode(String serverUrl, String apiKey) {
    _isClientMode = true;
    _serverUrl = serverUrl;
    _apiKey = apiKey;
    
    // Create remote repositories
    _remoteCategoryRepo = RemoteCategoryRepository(serverUrl: serverUrl, apiKey: apiKey);
    _remoteProductRepo = RemoteProductRepository(serverUrl: serverUrl, apiKey: apiKey);
    _remoteSaleRepo = RemoteSaleRepository(serverUrl: serverUrl, apiKey: apiKey);
    
    print('📡 Switched to CLIENT MODE - querying server at $serverUrl');
    notifyListeners();
  }
  
  /// Switch back to local/standalone mode
  void disableClientMode() {
    _isClientMode = false;
    _serverUrl = null;
    _apiKey = null;
    _remoteCategoryRepo = null;
    _remoteProductRepo = null;
    _remoteSaleRepo = null;
    
    print('💾 Switched to LOCAL MODE - using local database');
    notifyListeners();
  }
}
