import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../../data/datasources/database_helper.dart';
import 'mobile_server_bridge.dart';

class LocalServer {
  static final LocalServer _instance = LocalServer._internal();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  HttpServer? _server;
  MobileServerBridge? _mobileBridge;
  Handler? _handler;
  
  String? _apiKey;
  String? _lastError;
  int _port = 8080;
  bool _isRunning = false;

  LocalServer._internal() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _mobileBridge = MobileServerBridge(this);
    }
  }

  factory LocalServer() => _instance;

  bool get isRunning => _isRunning;
  String? get apiKey => _apiKey;
  String? get lastError => _lastError;
  int get port => _port;

  /// Check if server mode is supported on this platform
  bool get isServerModeSupported {
    if (kIsWeb) {
      return false; // Web cannot host servers
    }
    // Supported on Desktop (Dart HTTP) and Mobile (Native Bridge)
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux || 
           Platform.isAndroid || Platform.isIOS;
  }

  /// Generate a cryptographically secure API key
  String generateApiKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final apiKey = base64Url.encode(values).substring(0, 32);
    _apiKey = apiKey;
    return apiKey;
  }

  /// Validate API key from request
  bool validateApiKey(String? providedKey) {
    if (_apiKey == null || providedKey == null) return false;
    return _apiKey == providedKey;
  }

  /// Build the request handler pipeline
  Handler _buildHandler() {
    if (_handler != null) return _handler!;
    
    final router = _createRouter();
    
    // Add middleware for CORS and API key validation
    _handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addHandler(router);
        
    return _handler!;
  }

  /// Handle incoming request (used by both shelf server and mobile bridge)
  Future<Response> handleRequest(Request request) async {
    print('🔍 LocalServer handling: ${request.method} ${request.url.path}');
    if (_handler == null) {
      print('❌ Server handler not initialized');
      return Response.internalServerError(
        body: 'Server not initialized',
      );
    }
    final response = await _handler!(request);
    print('✅ Response status: ${response.statusCode}');
    return response;
  }

  /// Start the HTTP server
  Future<bool> startServer({int port = 8080, String? apiKey}) async {
    // Check platform compatibility first
    if (!isServerModeSupported) {
      print('❌ Server mode is not supported on this platform');
      return false;
    }

    if (_isRunning) {
      print('⚠️ Server already running on port $_port');
      return false;
    }

    try {
      _port = port;
      _apiKey = apiKey ?? generateApiKey();
      
      // Reset handler to ensure fresh state
      _handler = null;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Use Native Bridge for Mobile
        // Initialize handler BEFORE starting native server
        _buildHandler();
        
        if (_mobileBridge != null) {
          final error = await _mobileBridge!.startServer(_port, _apiKey!);
          if (error == null) {
            _isRunning = true;
            print('✅ Native mobile server started on port $_port');
            print('🔑 API Key: $_apiKey');
            return true;
          } else {
            print('❌ Native server failed: $error');
            _lastError = error;
            return false;
          }
        }
        _lastError = "Mobile bridge not initialized";
        return false;
      } else {
        // Use Dart HTTP Server for Desktop
        _server = await shelf_io.serve(
          _buildHandler(),
          InternetAddress.anyIPv4,
          _port,
        );

        _isRunning = true;
        print('✅ Local server started on port $_port');
        print('🔑 API Key: $_apiKey');
        return true;
      }
    } catch (e) {
      print('❌ Failed to start server: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Stop the HTTP server
  Future<void> stopServer() async {
    if (!_isRunning) {
      print('⚠️ Server is not running');
      return;
    }

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Stop Native Bridge
        if (_mobileBridge != null) {
          await _mobileBridge!.stopServer();
        }
      } else {
        // Stop Dart HTTP Server
        await _server?.close(force: true);
        _server = null;
      }
      
      _isRunning = false;
      _apiKey = null;
      _handler = null;
      print('✅ Local server stopped');
    } catch (e) {
      print('❌ Error stopping server: $e');
    }
  }

  /// Create router with all endpoints
  Router _createRouter() {
    final router = Router();

    // Health check endpoint (no auth required)
    router.get('/api/health', (Request request) {
      return Response.ok(
        jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // Authentication endpoint (no auth required for this)
    router.post('/api/authenticate', _handleAuthenticate);

    // Heartbeat endpoint
    router.post('/api/heartbeat', _handleHeartbeat);

    // Sync status endpoint
    router.get('/api/sync/status', _handleSyncStatus);

    // Get inventory (products + categories)
    router.get('/api/sync/inventory', _handleGetInventory);

    // Submit sales from client
    router.post('/api/sync/sales', _handlePostSales);

    // Get all sales (for full sync)
    router.get('/api/sync/sales', _handleGetSales);

    // Get customers
    router.get('/api/sync/customers', _handleGetCustomers);

    // ======= CATEGORY CRUD ENDPOINTS =======
    router.get('/api/categories', _handleGetCategories);
    router.get('/api/categories/<id>', _handleGetCategoryById);
    router.post('/api/categories', _handleCreateCategory);
    router.put('/api/categories/<id>', _handleUpdateCategory);
    router.delete('/api/categories/<id>', _handleDeleteCategory);

    // ======= PRODUCT CRUD ENDPOINTS =======
    router.get('/api/products', _handleGetProducts);
    router.get('/api/products/<id>', _handleGetProductById);
    router.post('/api/products', _handleCreateProduct);
    router.put('/api/products/<id>', _handleUpdateProduct);
    router.delete('/api/products/<id>', _handleDeleteProduct);
    router.get('/api/products/search', _handleSearchProducts);

    // ======= SALES CRUD ENDPOINTS =======
    router.get('/api/sales', _handleGetAllSales);
    router.get('/api/sales/<id>', _handleGetSaleById);
    router.post('/api/sales', _handleCreateSale);
    router.post('/api/sale_items', _handleCreateSaleItem);

    // ======= IMAGE ENDPOINTS =======
    router.get('/api/images', _handleGetImage);

    return router;
  }

  /// CORS middleware
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders());
        }
        
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  Map<String, String> _corsHeaders() {
    return {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, X-API-Key',
    };
  }

  /// Authentication middleware
  Middleware _authMiddleware() {
    return createMiddleware(
      requestHandler: (Request request) {
        // Skip auth for health and authenticate endpoints
        if (request.url.path == 'api/health' || 
            request.url.path == 'api/authenticate') {
          return null;
        }

        // Check API key in header
        final apiKey = request.headers['x-api-key'];
        if (!validateApiKey(apiKey)) {
          return Response.forbidden(
            jsonEncode({'error': 'Invalid or missing API key'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        return null; // Continue to handler
      },
    );
  }

  /// Handle authentication request
  Future<Response> _handleAuthenticate(Request request) async {
    try {
      final body = await request.readAsString();
      
      if (body.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({
            'authenticated': false,
            'error': 'Request body is empty',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({
            'authenticated': false,
            'error': 'Invalid JSON format: $e',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final providedKey = data['api_key'] as String?;

      if (providedKey == null || providedKey.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({
            'authenticated': false,
            'error': 'API key is required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (validateApiKey(providedKey)) {
        return Response.ok(
          jsonEncode({
            'authenticated': true,
            'message': 'Authentication successful',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.forbidden(
        jsonEncode({
          'authenticated': false,
          'message': 'Invalid API key',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('❌ Authentication error: $e');
      print('Stack trace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Internal server error during authentication',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle heartbeat request
  Future<Response> _handleHeartbeat(Request request) async {
    return Response.ok(
      jsonEncode({
        'status': 'alive',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Handle sync status request
  Future<Response> _handleSyncStatus(Request request) async {
    try {
      final db = await _databaseHelper.database;
      
      // Get counts
      final productsCount = sqflite.Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products')
      ) ?? 0;
      final categoriesCount = sqflite.Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM categories')
      ) ?? 0;
      final salesCount = sqflite.Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sales')
      ) ?? 0;

      return Response.ok(
        jsonEncode({
          'status': 'online',
          'timestamp': DateTime.now().toIso8601String(),
          'counts': {
            'products': productsCount,
            'categories': categoriesCount,
            'sales': salesCount,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get sync status: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle get inventory request
  Future<Response> _handleGetInventory(Request request) async {
    try {
      final db = await _databaseHelper.database;
      
      // Get all products and categories
      final products = await db.query('products', orderBy: 'id ASC');
      final categories = await db.query('categories', orderBy: 'id ASC');

      return Response.ok(
        jsonEncode({
          'products': products,
          'categories': categories,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get inventory: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle post sales request
  Future<Response> _handlePostSales(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final sales = data['sales'] as List<dynamic>;

      final db = await _databaseHelper.database;
      int imported = 0;

      await db.transaction((txn) async {
        for (final saleData in sales) {
          final saleMap = saleData as Map<String, dynamic>;
          final saleItems = saleMap['items'] as List<dynamic>?;
          
          // Remove items from sale map before insertion
          saleMap.remove('items');
          saleMap.remove('id'); // Let server auto-generate ID

          // Insert sale
          final saleId = await txn.insert('sales', saleMap);

          // Insert sale items
          if (saleItems != null) {
            for (final item in saleItems) {
              final itemMap = Map<String, dynamic>.from(item as Map);
              itemMap['sale_id'] = saleId;
              itemMap.remove('id');
              await txn.insert('sale_items', itemMap);
            }
          }

          imported++;
        }
      });

      return Response.ok(
        jsonEncode({
          'success': true,
          'imported': imported,
          'message': '$imported sales imported successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to import sales: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle get sales request
  Future<Response> _handleGetSales(Request request) async {
    try {
      final db = await _databaseHelper.database;
      
      // Get all sales with their items
      final sales = await db.query('sales', orderBy: 'id ASC');
      
      // For each sale, get its items
      final salesWithItems = <Map<String, dynamic>>[];
      for (final sale in sales) {
        final saleId = sale['id'];
        final items = await db.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );
        
        final saleMap = Map<String, dynamic>.from(sale);
        saleMap['items'] = items;
        salesWithItems.add(saleMap);
      }

      return Response.ok(
        jsonEncode({
          'sales': salesWithItems,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get sales: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle get customers request
  Future<Response> _handleGetCustomers(Request request) async {
    try {
      final db = await _databaseHelper.database;
      final customers = await db.query('customers', orderBy: 'id ASC');

      return Response.ok(
        jsonEncode({
          'customers': customers,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get customers: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ======= CATEGORY CRUD HANDLERS =======

  Future<Response> _handleGetCategories(Request request) async {
    try {
      final db = await _databaseHelper.database;
      final categories = await db.query('categories', orderBy: 'name ASC');
      return Response.ok(
        jsonEncode({'categories': categories}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get categories: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleGetCategoryById(Request request, String id) async {
    try {
      final db = await _databaseHelper.database;
      final categories = await db.query('categories', where: 'id = ?', whereArgs: [int.parse(id)]);
      if (categories.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Category not found'}));
      }
      return Response.ok(
        jsonEncode({'category': categories.first}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get category: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleCreateCategory(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final db = await _databaseHelper.database;
      final id = await db.insert('categories', {
        'name': data['name'],
        'description': data['description'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return Response.ok(
        jsonEncode({'id': id, 'message': 'Category created'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create category: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleUpdateCategory(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final db = await _databaseHelper.database;
      data['updated_at'] = DateTime.now().toIso8601String();
      await db.update('categories', data, where: 'id = ?', whereArgs: [int.parse(id)]);
      return Response.ok(
        jsonEncode({'message': 'Category updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update category: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleDeleteCategory(Request request, String id) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('categories', where: 'id = ?', whereArgs: [int.parse(id)]);
      return Response.ok(
        jsonEncode({'message': 'Category deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete category: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ======= PRODUCT CRUD HANDLERS =======

  Future<Response> _handleGetProducts(Request request) async {
    try {
      final db = await _databaseHelper.database;
      final products = await db.query('products', orderBy: 'name ASC');
      return Response.ok(
        jsonEncode({'products': products}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get products: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleGetProductById(Request request, String id) async {
    try {
      final db = await _databaseHelper.database;
      final products = await db.query('products', where: 'id = ?', whereArgs: [int.parse(id)]);
      if (products.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Product not found'}));
      }
      return Response.ok(
        jsonEncode({'product': products.first}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get product: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleSearchProducts(Request request) async {
    try {
      final query = request.url.queryParameters['q'] ?? '';
      final db = await _databaseHelper.database;
      final products = await db.query(
        'products',
        where: 'name LIKE ? OR barcode LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name ASC',
      );
      return Response.ok(
        jsonEncode({'products': products}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to search products: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleCreateProduct(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final db = await _databaseHelper.database;
      final id = await db.insert('products', {
        'name': data['name'],
        'barcode': data['barcode'],
        'category_id': data['category_id'],
        'price': data['price'],
        'cost': data['cost'],
        'quantity': data['quantity'] ?? 0,
        'image_path': data['image_path'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return Response.ok(
        jsonEncode({'id': id, 'message': 'Product created'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create product: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleUpdateProduct(Request request, String id) async {
    try {
      final body = await request.readAsString();
      print('📥 Update product request: $body');
      final data = jsonDecode(body) as Map<String, dynamic>;
      final db = await _databaseHelper.database;
      
      // Map client field names to database column names
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (data.containsKey('name')) updateData['name'] = data['name'];
      if (data.containsKey('barcode')) updateData['barcode'] = data['barcode'];
      if (data.containsKey('category_id')) updateData['category_id'] = data['category_id'];
      if (data.containsKey('image_path')) updateData['image_path'] = data['image_path'];
      if (data.containsKey('description')) updateData['description'] = data['description'];
      
      // Handle price fields (client sends 'price'/'cost', DB uses 'selling_price'/'cost_price')
      if (data.containsKey('price')) updateData['selling_price'] = data['price'];
      if (data.containsKey('selling_price')) updateData['selling_price'] = data['selling_price'];
      if (data.containsKey('cost')) updateData['cost_price'] = data['cost'];
      if (data.containsKey('cost_price')) updateData['cost_price'] = data['cost_price'];
      
      // Handle stock fields (client sends 'quantity', DB uses 'stock_quantity')
      if (data.containsKey('quantity')) updateData['stock_quantity'] = data['quantity'];
      if (data.containsKey('stock_quantity')) updateData['stock_quantity'] = data['stock_quantity'];
      
      print('📝 Mapped update data: $updateData');
      
      await db.update('products', updateData, where: 'id = ?', whereArgs: [int.parse(id)]);
      return Response.ok(
        jsonEncode({'message': 'Product updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('❌ Failed to update product: $e');
      print('Stack trace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update product: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleDeleteProduct(Request request, String id) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('products', where: 'id = ?', whereArgs: [int.parse(id)]);
      return Response.ok(
        jsonEncode({'message': 'Product deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete product: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ======= SALES CRUD HANDLERS =======

  Future<Response> _handleGetAllSales(Request request) async {
    try {
      final db = await _databaseHelper.database;
      final sales = await db.query('sales', orderBy: 'created_at DESC');
      
      // Get items for each sale
      final salesWithItems = <Map<String, dynamic>>[];
      for (final sale in sales) {
        final saleId = sale['id'];
        final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        final saleMap = Map<String, dynamic>.from(sale);
        saleMap['items'] = items;
        salesWithItems.add(saleMap);
      }
      
      return Response.ok(
        jsonEncode({'sales': salesWithItems}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get sales: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleGetSaleById(Request request, String id) async {
    try {
      final db = await _databaseHelper.database;
      final sales = await db.query('sales', where: 'id = ?', whereArgs: [int.parse(id)]);
      if (sales.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Sale not found'}));
      }
      final sale = Map<String, dynamic>.from(sales.first);
      final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [int.parse(id)]);
      sale['items'] = items;
      return Response.ok(
        jsonEncode({'sale': sale}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get sale: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleCreateSale(Request request) async {
    try {
      final body = await request.readAsString();
      print('📥 Create sale request body: $body');
      final data = jsonDecode(body) as Map<String, dynamic>;
      final db = await _databaseHelper.database;
      
      final now = DateTime.now().toIso8601String();
      
      // Insert sale with all required fields
      final saleId = await db.insert('sales', {
        'customer_id': data['customer_id'],
        'customer_name': data['customer_name'],
        'total_amount': data['total_amount'] ?? 0.0,
        'payment_amount': data['payment_amount'] ?? 0.0,
        'change_amount': data['change_amount'] ?? 0.0,
        'payment_method': data['payment_method'] ?? 'cash',
        'transaction_status': data['status'] ?? data['transaction_status'] ?? 'completed',
        'sale_date': data['sale_date'] ?? now, // Required field
        'due_date': data['due_date'],
        'is_credit': data['is_credit'] == true || data['is_credit'] == 1 ? 1 : 0,
        'created_at': now,
      });
      
      print('✅ Sale created with ID: $saleId');
      
      // Insert sale items
      final items = data['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        await db.insert('sale_items', {
          'sale_id': saleId,
          'product_id': itemMap['product_id'],
          'quantity': itemMap['quantity'],
          'unit_price': itemMap['unit_price'] ?? itemMap['price'] ?? 0.0,
          'subtotal': itemMap['subtotal'] ?? itemMap['total'] ?? 0.0,
        });
        
        // Update product stock
        final productId = itemMap['product_id'];
        final qty = itemMap['quantity'];
        await db.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [qty, productId],
        );
      }
      
      print('✅ Inserted ${items.length} sale items');
      
      return Response.ok(
        jsonEncode({'id': saleId, 'message': 'Sale created'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('❌ Failed to create sale: $e');
      print('Stack trace: $stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create sale: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Create a sale item (for clients inserting items after sale creation)
  Future<Response> _handleCreateSaleItem(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final db = await _databaseHelper.database;
      
      final saleItemId = await db.insert('sale_items', {
        'sale_id': data['sale_id'],
        'product_id': data['product_id'],
        'quantity': data['quantity'],
        'unit_price': data['unit_price'],
        'subtotal': data['subtotal'],
      });
      
      // Update product stock  
      await db.rawUpdate(
        'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
        [data['quantity'], data['product_id']],
      );
      
      return Response.ok(
        jsonEncode({'id': saleItemId, 'message': 'Sale item created'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create sale item: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Serve product images
  Future<Response> _handleGetImage(Request request) async {
    try {
      final path = request.url.queryParameters['path'];
      if (path == null || path.isEmpty) {
        return Response.badRequest(body: 'Missing path parameter');
      }

      final file = File(path);
      if (!await file.exists()) {
        return Response.notFound('Image not found');
      }
      
      final bytes = await file.readAsBytes();
      final ext = path.split('.').last.toLowerCase();
      String contentType = 'application/octet-stream';
      
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
      }
      
      return Response.ok(
        bytes,
        headers: {'Content-Type': contentType},
      );
    } catch (e) {
      return Response.internalServerError(
        body: 'Failed to serve image: $e',
      );
    }
  }
}
