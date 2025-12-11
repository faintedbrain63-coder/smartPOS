import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../domain/entities/sync_config.dart';
import '../../domain/entities/sync_log.dart';
import '../utils/network_helper.dart';
import 'local_server.dart';
import 'sync_client.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final LocalServer _localServer = LocalServer();
  final SyncClient _syncClient = SyncClient();
  final NetworkHelper _networkHelper = NetworkHelper();
  
  late final SyncRepositoryImpl _syncRepository;
  
  SyncConfig? _currentConfig;
  Timer? _autoSyncTimer;
  Timer? _heartbeatTimer;
  bool _isInitialized = false;

  SyncService._internal() {
    _syncRepository = SyncRepositoryImpl(_databaseHelper);
  }

  factory SyncService() => _instance;

  SyncConfig? get currentConfig => _currentConfig;
  bool get isServerMode => _currentConfig?.isServerMode ?? false;
  bool get isClientMode => _currentConfig?.isClientMode ?? false;
  bool get isConfigured => _currentConfig?.isConfigured ?? false;
  bool get isConnected => isClientMode && _syncClient.isConnected;
  String? get lastServerError => _localServer.lastError;
  String? _lastServiceError;
  String? get lastServiceError => _lastServiceError;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load existing configuration
      _currentConfig = await _syncRepository.getSyncConfig();

      // If no config exists, create default one
      if (_currentConfig == null) {
        final deviceId = await _getDeviceId();
        _currentConfig = SyncConfig(
          deviceId: deviceId,
          deviceMode: 'disabled',
        );
        await _syncRepository.insertSyncConfig(_currentConfig!);
      }

      // If server mode was active, restart server
      if (_currentConfig!.isServerMode && _localServer.apiKey == null) {
        await _startServerMode(_currentConfig!.apiKey);
      }

      // If client mode was active, reconnect
      if (_currentConfig!.isClientMode) {
        await _connectClientMode(
          _currentConfig!.serverIpAddress!,
          _currentConfig!.serverPort,
          _currentConfig!.apiKey!,
        );
      }

      _isInitialized = true;
      print('✅ Sync service initialized');
    } catch (e) {
      print('❌ Failed to initialize sync service: $e');
    }
  }

  /// Get unique device ID
  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        return 'device_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Enable server mode
  Future<bool> enableServerMode({String? existingApiKey}) async {
    try {
      // Stop client mode if active
      if (isClientMode) {
        await disableSync();
      }

      // Start server
      final started = await _startServerMode(existingApiKey);
      if (!started) {
        return false;
      }

      // Update configuration
      _currentConfig = (_currentConfig ?? SyncConfig(
        deviceId: await _getDeviceId(),
        deviceMode: 'server',
      )).copyWith(
        deviceMode: 'server',
        apiKey: _localServer.apiKey,
        serverPort: _localServer.port,
        syncStatus: 'idle',
      );

      try {
        if (_currentConfig!.id == null) {
          // Check if config already exists for this device (to avoid UNIQUE constraint error)
          final existingConfig = await _syncRepository.getSyncConfig();
          if (existingConfig != null) {
             _currentConfig = existingConfig.copyWith(
                deviceMode: 'server',
                apiKey: _localServer.apiKey,
                serverPort: _localServer.port,
                syncStatus: 'idle',
             );
             await _syncRepository.updateSyncConfig(_currentConfig!);
          } else {
             await _syncRepository.insertSyncConfig(_currentConfig!);
          }
        } else {
          await _syncRepository.updateSyncConfig(_currentConfig!);
        }
      } catch (e) {
        // If insert failed (e.g. race condition or unique constraint), try to recover by updating
        print('⚠️ Insert failed, trying update: $e');
        final existingConfig = await _syncRepository.getSyncConfig();
        if (existingConfig != null) {
           _currentConfig = existingConfig.copyWith(
              deviceMode: 'server',
              apiKey: _localServer.apiKey,
              serverPort: _localServer.port,
              syncStatus: 'idle',
           );
           await _syncRepository.updateSyncConfig(_currentConfig!);
        } else {
           rethrow; // Genuine error
        }
      }

      await _logSync('server_enabled', 'success');
      _lastServiceError = null;
      return true;
    } catch (e) {
      print('❌ Failed to enable server mode: $e');
      _lastServiceError = e.toString();
      await _logSync('server_enabled', 'failed', errorMessage: e.toString());
      return false;
    }
  }

  /// Start server
  Future<bool> _startServerMode(String? apiKey) async {
    return await _localServer.startServer(
      port: 8080,
      apiKey: apiKey,
    );
  }

  /// Enable client mode
  Future<bool> enableClientMode({
    required String serverIp,
    required int serverPort,
    required String apiKey,
  }) async {
    try {
      // Stop server mode if active
      if (isServerMode) {
        await disableSync();
      }

      // Connect to server
      final connected = await _connectClientMode(serverIp, serverPort, apiKey);
      if (!connected) {
        return false;
      }

      // Update configuration
      _currentConfig = (_currentConfig ?? SyncConfig(
        deviceId: await _getDeviceId(),
        deviceMode: 'client',
      )).copyWith(
        deviceMode: 'client',
        serverIpAddress: serverIp,
        serverPort: serverPort,
        apiKey: apiKey,
        syncStatus: 'idle',
      );

      if (_currentConfig!.id == null) {
        await _syncRepository.insertSyncConfig(_currentConfig!);
      } else {
        await _syncRepository.updateSyncConfig(_currentConfig!);
      }

      // Start auto-sync if enabled
      if (_currentConfig!.autoSyncEnabled) {
        _startAutoSync();
      }

      // Start heartbeat
      _startHeartbeat();

      await _logSync('client_enabled', 'success');
      return true;
    } catch (e) {
      print('❌ Failed to enable client mode: $e');
      await _logSync('client_enabled', 'failed', errorMessage: e.toString());
      return false;
    }
  }

  /// Connect to server as client
  Future<bool> _connectClientMode(String serverIp, int serverPort, String apiKey) async {
    // Validate inputs
    final networkHelper = NetworkHelper();
    if (!networkHelper.isValidIpAddress(serverIp)) {
      _lastServiceError = 'Invalid IP address format. Please enter a valid IP address (e.g., 192.168.1.100).';
      return false;
    }
    
    if (!networkHelper.isValidPort(serverPort)) {
      _lastServiceError = 'Invalid port number. Port must be between 1 and 65535.';
      return false;
    }
    
    if (apiKey.isEmpty) {
      _lastServiceError = 'API key cannot be empty.';
      return false;
    }

    _syncClient.configure(
      serverIp: serverIp,
      port: serverPort,
      apiKey: apiKey,
    );

    final authenticated = await _syncClient.authenticate();
    if (!authenticated) {
      _lastServiceError = _syncClient.lastError ?? 'Failed to authenticate with server.';
    }
    return authenticated;
  }

  /// Disable sync (server or client mode)
  Future<void> disableSync() async {
    try {
      // Stop auto-sync timer
      _stopAutoSync();
      
      // Stop heartbeat timer
      _stopHeartbeat();

      // Stop server if running
      if (_localServer.isRunning) {
        await _localServer.stopServer();
      }

      // Disconnect client
      _syncClient.clearConfiguration();

      // Update configuration
      if (_currentConfig != null) {
        _currentConfig = _currentConfig!.copyWith(
          deviceMode: 'disabled',
          syncStatus: 'idle',
        );
        await _syncRepository.updateSyncConfig(_currentConfig!);
      }

      await _logSync('sync_disabled', 'success');
    } catch (e) {
      print('❌ Error disabling sync: $e');
    }
  }

  /// Perform manual sync (client mode)
  Future<bool> performSync() async {
    if (!isClientMode) {
      print('⚠️ Not in client mode');
      return false;
    }

    if (!_syncClient.isConnected) {
      print('⚠️ Not connected to server');
      // Try to reconnect
      final reconnected = await _syncClient.authenticate();
      if (!reconnected) {
        await _updateSyncStatus('offline');
        return false;
      }
    }

    try {
      await _updateSyncStatus('syncing');

      // Step 1: Pull inventory from server
      final inventoryData = await _syncClient.getInventory();
      if (inventoryData != null) {
        await _syncInventory(inventoryData);
      }

      // Step 2: Pull customers from server
      final customersData = await _syncClient.getCustomers();
      if (customersData != null) {
        await _syncCustomers(customersData);
      }

      // Step 3: Push any pending sales to server
      await _pushPendingSales();

      // Step 4: Push any pending categories to server
      await _pushPendingCategories();

      // Update last sync timestamp
      _currentConfig = _currentConfig!.copyWith(
        lastSyncTimestamp: DateTime.now(),
        syncStatus: 'idle',
      );
      await _syncRepository.updateSyncConfig(_currentConfig!);

      await _logSync('full_sync', 'success');
      return true;
    } catch (e) {
      print('❌ Sync failed: $e');
      await _updateSyncStatus('error');
      await _logSync('full_sync', 'failed', errorMessage: e.toString());
      return false;
    }
  }

  /// Sync inventory (categories + products)
  Future<void> _syncInventory(Map<String, dynamic> data) async {
    final db = await _databaseHelper.database;
    
    try {
      await db.transaction((txn) async {
        // Sync categories
        final categories = data['categories'] as List<dynamic>;
        for (final category in categories) {
          final catMap = category as Map<String, dynamic>;
          final id = catMap['id'];
          
          // Check if exists
          final existing = await txn.query(
            'categories',
            where: 'id = ?',
            whereArgs: [id],
          );

          if (existing.isEmpty) {
            await txn.insert('categories', catMap);
          } else {
            await txn.update(
              'categories',
              catMap,
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }

        // Sync products
        final products = data['products'] as List<dynamic>;
        for (final product in products) {
          final prodMap = product as Map<String, dynamic>;
          final id = prodMap['id'];
          
          // Check if exists
          final existing = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [id],
          );

          if (existing.isEmpty) {
            await txn.insert('products', prodMap);
          } else {
            await txn.update(
              'products',
              prodMap,
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      });

      await _logSync(
        'inventory_pull',
        'success',
        recordsSynced: (data['products'] as List).length + (data['categories'] as List).length,
      );
    } catch (e) {
      print('❌ Error syncing inventory: $e');
      await _logSync('inventory_pull', 'failed', errorMessage: e.toString());
      rethrow;
    }
  }

  /// Sync customers
  Future<void> _syncCustomers(List<Map<String, dynamic>> customers) async {
    final db = await _databaseHelper.database;
    
    try {
      await db.transaction((txn) async {
        for (final customer in customers) {
          final id = customer['id'];
          
          // Check if exists
          final existing = await txn.query(
            'customers',
            where: 'id = ?',
            whereArgs: [id],
          );

          if (existing.isEmpty) {
            await txn.insert('customers', customer);
          } else {
            await txn.update(
              'customers',
              customer,
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      });

      await _logSync('customers_pull', 'success', recordsSynced: customers.length);
    } catch (e) {
      print('❌ Error syncing customers: $e');
      await _logSync('customers_pull', 'failed', errorMessage: e.toString());
      rethrow;
    }
  }

  /// Push pending sales to server
  Future<void> _pushPendingSales() async {
    // Get sales from sync queue
    final queueItems = await _syncRepository.getPendingSyncQueue();
    
    if (queueItems.isEmpty) {
      print('📤 No pending sales to push');
      return;
    }

    final salesToPush = <Map<String, dynamic>>[];
    
    for (final item in queueItems) {
      if (item['table_name'] == 'sales') {
        salesToPush.add(item['data'] as Map<String, dynamic>);
      }
    }

    if (salesToPush.isNotEmpty) {
      final success = await _syncClient.submitSales(salesToPush);
      
      if (success) {
        // Remove from queue
        for (final item in queueItems) {
          await _syncRepository.removeFromSyncQueue(item['id'] as int);
        }
        await _logSync('sales_push', 'success', recordsSynced: salesToPush.length);
      } else {
        await _logSync('sales_push', 'failed', errorMessage: 'Failed to submit sales');
      }
    }
  }

  /// Add sale to sync queue (for offline mode)
  Future<void> queueSaleForSync(Map<String, dynamic> saleData) async {
    await _syncRepository.addToSyncQueue(
      operationType: 'create',
      tableName: 'sales',
      recordId: saleData['id'] as int?,
      data: saleData,
    );
    print('📥 Sale queued for sync');
  }

  /// Push category to server (create or update)
  Future<bool> pushCategory(Map<String, dynamic> category, {bool isUpdate = false}) async {
    if (!isClientMode) {
      print('⚠️ Not in client mode, cannot push category');
      return false;
    }

    if (!_syncClient.isConnected) {
      print('⚠️ Not connected to server, queueing category for later');
      // Queue for later sync
      await _syncRepository.addToSyncQueue(
        operationType: isUpdate ? 'update' : 'create',
        tableName: 'categories',
        recordId: category['id'] as int?,
        data: category,
      );
      return false;
    }

    try {
      final success = await _syncClient.submitCategory(category, isUpdate: isUpdate);
      if (success) {
        await _logSync(
          isUpdate ? 'category_update_push' : 'category_create_push',
          'success',
          recordsSynced: 1,
        );
      } else {
        await _logSync(
          isUpdate ? 'category_update_push' : 'category_create_push',
          'failed',
          errorMessage: 'Failed to ${isUpdate ? 'update' : 'create'} category on server',
        );
      }
      return success;
    } catch (e) {
      print('❌ Error pushing category: $e');
      await _logSync(
        isUpdate ? 'category_update_push' : 'category_create_push',
        'failed',
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Push pending categories to server
  Future<void> _pushPendingCategories() async {
    final queueItems = await _syncRepository.getPendingSyncQueue();
    
    final categoriesToPush = queueItems.where((item) => item['table_name'] == 'categories').toList();
    
    if (categoriesToPush.isEmpty) {
      return;
    }

    for (final item in categoriesToPush) {
      final category = item['data'] as Map<String, dynamic>;
      final isUpdate = item['operation_type'] == 'update';
      
      final success = await _syncClient.submitCategory(category, isUpdate: isUpdate);
      
      if (success) {
        await _syncRepository.removeFromSyncQueue(item['id'] as int);
        await _logSync(
          isUpdate ? 'category_update_push' : 'category_create_push',
          'success',
          recordsSynced: 1,
        );
      } else {
        await _logSync(
          isUpdate ? 'category_update_push' : 'category_create_push',
          'failed',
          errorMessage: 'Failed to ${isUpdate ? 'update' : 'create'} category',
        );
      }
    }
  }

  /// Start auto-sync timer
  void _startAutoSync() {
    _stopAutoSync(); // Stop any existing timer
    
    final intervalMinutes = _currentConfig?.syncIntervalMinutes ?? 5;
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => performSync(),
    );
    print('⏱️ Auto-sync started (interval: $intervalMinutes minutes)');
  }

  /// Stop auto-sync timer
  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _stopHeartbeat(); // Stop any existing timer
    
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        final alive = await _syncClient.sendHeartbeat();
        if (!alive) {
          await _updateSyncStatus('offline');
        }
      },
    );
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Update sync status
  Future<void> _updateSyncStatus(String status) async {
    if (_currentConfig != null) {
      _currentConfig = _currentConfig!.copyWith(syncStatus: status);
      await _syncRepository.updateSyncConfig(_currentConfig!);
    }
  }

  /// Log sync operation
  Future<void> _logSync(
    String operationType,
    String status, {
    int recordsSynced = 0,
    String? errorMessage,
  }) async {
    final log = SyncLog(
      operationType: operationType,
      timestamp: DateTime.now(),
      status: status,
      recordsSynced: recordsSynced,
      errorMessage: errorMessage,
      deviceId: _currentConfig?.deviceId,
    );

    await _syncRepository.addSyncLog(log);
  }

  /// Get local IP address
  Future<String?> getLocalIpAddress() async {
    return await _networkHelper.getLocalIpAddress();
  }

  /// Test connection to server
  Future<Map<String, dynamic>> testConnection(String serverIp, int port, String apiKey) async {
    // Validate inputs
    final networkHelper = NetworkHelper();
    if (!networkHelper.isValidIpAddress(serverIp)) {
      return {
        'success': false,
        'error': 'Invalid IP address format. Please enter a valid IP address (e.g., 192.168.1.100).',
        'step': 'Validation',
      };
    }
    
    if (!networkHelper.isValidPort(port)) {
      return {
        'success': false,
        'error': 'Invalid port number. Port must be between 1 and 65535.',
        'step': 'Validation',
      };
    }
    
    if (apiKey.isEmpty) {
      return {
        'success': false,
        'error': 'API key cannot be empty.',
        'step': 'Validation',
      };
    }

    return await _syncClient.testConnection(serverIp, port, apiKey);
  }

  /// Get sync logs
  Future<List<SyncLog>> getSyncLogs({int limit = 50}) async {
    return await _syncRepository.getRecentSyncLogs(limit: limit);
  }

  /// Clear old sync logs
  Future<void> clearOldLogs({int daysToKeep = 30}) async {
    await _syncRepository.clearOldSyncLogs(daysToKeep: daysToKeep);
  }
}
