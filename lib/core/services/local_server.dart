import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
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
      final data = jsonDecode(body) as Map<String, dynamic>;
      final providedKey = data['api_key'] as String?;

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
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Authentication failed: $e'}),
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
}
