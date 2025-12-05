import 'package:flutter/foundation.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/local_server.dart';
import '../../domain/entities/sync_config.dart';
import '../../domain/entities/sync_log.dart';

class SyncProvider with ChangeNotifier {
  final SyncService _syncService = SyncService();
  
  SyncConfig? _config;
  List<SyncLog> _recentLogs = [];
  bool _isSyncing = false;
  String? _error;
  String? _localIpAddress;

  SyncProvider() {
    _initialize();
  }

  // Getters
  SyncConfig? get config => _config;
  List<SyncLog> get recentLogs => _recentLogs;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  String? get localIpAddress => _localIpAddress;
  
  bool get isServerMode => _config?.isServerMode ?? false;
  bool get isClientMode => _config?.isClientMode ?? false;
  bool get isDisabled => _config?.isDisabled ?? true;
  bool get isConnected => _syncService.isConnected;
  
  String get statusText {
    if (_isSyncing) return 'Syncing...';
    if (_config == null) return 'Not configured';
    
    switch (_config!.syncStatus) {
      case 'syncing':
        return 'Syncing...';
      case 'error':
        return 'Error';
      case 'offline':
        return 'Offline';
      case 'idle':
        if (isServerMode) return 'Server Active';
        if (isClientMode && isConnected) return 'Connected';
        if (isClientMode) return 'Disconnected';
        return 'Disabled';
      default:
        return _config!.syncStatus;
    }
  }

  String? get lastSyncTime {
    if (_config?.lastSyncTimestamp == null) return null;
    
    final now = DateTime.now();
    final diff = now.difference(_config!.lastSyncTimestamp!);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  /// Initialize sync service
  Future<void> _initialize() async {
    try {
      await _syncService.initialize();
      _config = _syncService.currentConfig;
      await _loadLocalIp();
      await _loadRecentLogs();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load local IP address
  Future<void> _loadLocalIp() async {
    try {
      _localIpAddress = await _syncService.getLocalIpAddress();
    } catch (e) {
      print('Error loading local IP: $e');
    }
  }

  /// Load recent sync logs
  Future<void> _loadRecentLogs() async {
    try {
      _recentLogs = await _syncService.getSyncLogs(limit: 20);
      notifyListeners();
    } catch (e) {
      print('Error loading sync logs: $e');
    }
  }

  /// Enable server mode
  Future<bool> enableServerMode({String? existingApiKey}) async {
    _error = null;
    notifyListeners();
    
    // Check if server mode is supported on this platform
    final localServer = LocalServer();
    if (!localServer.isServerModeSupported) {
      _error = 'Server mode is only supported on desktop platforms (Windows, macOS, Linux). Use this device as a client instead.';
      notifyListeners();
      return false;
    }
    
    try {
      final success = await _syncService.enableServerMode(existingApiKey: existingApiKey);
      
      if (success) {
        _config = _syncService.currentConfig;
        await _loadLocalIp();
        await _loadRecentLogs();
        notifyListeners();
      } else {
        _error = _syncService.lastServerError ?? _syncService.lastServiceError ?? 'Failed to start server';
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Enable client mode
  Future<bool> enableClientMode({
    required String serverIp,
    required int serverPort,
    required String apiKey,
  }) async {
    _error = null;
    notifyListeners();
    
    try {
      final success = await _syncService.enableClientMode(
        serverIp: serverIp,
        serverPort: serverPort,
        apiKey: apiKey,
      );
      
      if (success) {
        _config = _syncService.currentConfig;
        await _loadRecentLogs();
        notifyListeners();
      } else {
        // Get detailed error message from service
        _error = _syncService.lastServiceError ?? 
                 'Failed to connect to server. Please check the IP address, port, and API key.';
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _error = 'Connection error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Disable sync
  Future<void> disableSync() async {
    _error = null;
    notifyListeners();
    
    try {
      await _syncService.disableSync();
      _config = _syncService.currentConfig;
      await _loadRecentLogs();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Perform manual sync
  Future<bool> performSync() async {
    if (_isSyncing) return false;
    
    _isSyncing = true;
    _error = null;
    notifyListeners();
    
    try {
      final success = await _syncService.performSync();
      
      _config = _syncService.currentConfig;
      await _loadRecentLogs();
      
      if (!success) {
        _error = 'Sync failed';
      }
      
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Test connection to server
  Future<Map<String, dynamic>> testConnection(String serverIp, int port, String apiKey) async {
    _error = null;
    notifyListeners();
    
    try {
      final result = await _syncService.testConnection(serverIp, port, apiKey);
      if (!result['success']) {
        _error = result['error'] ?? 'Connection test failed';
        notifyListeners();
      }
      return result;
    } catch (e) {
      _error = 'Connection test error: ${e.toString()}';
      notifyListeners();
      return {
        'success': false,
        'error': _error,
        'step': 'Error',
      };
    }
  }

  /// Queue sale for sync (when in offline mode)
  Future<void> queueSaleForSync(Map<String, dynamic> saleData) async {
    try {
      await _syncService.queueSaleForSync(saleData);
      notifyListeners();
    } catch (e) {
      print('Error queuing sale: $e');
    }
  }

  /// Refresh configuration and logs
  Future<void> refresh() async {
    await _initialize();
  }

  /// Clear old logs
  Future<void> clearOldLogs({int daysToKeep = 30}) async {
    try {
      await _syncService.clearOldLogs(daysToKeep: daysToKeep);
      await _loadRecentLogs();
      notifyListeners();
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }
}
