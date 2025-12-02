import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SyncClient {
  static final SyncClient _instance = SyncClient._internal();
  
  String? _serverUrl;
  String? _apiKey;
  bool _isConnected = false;
  DateTime? _lastHeartbeat;

  SyncClient._internal();

  factory SyncClient() => _instance;

  bool get isConnected => _isConnected;
  String? get serverUrl => _serverUrl;
  DateTime? get lastHeartbeat => _lastHeartbeat;

  /// Configure client with server details
  void configure({required String serverIp, required int port, required String apiKey}) {
    _serverUrl = 'http://$serverIp:$port';
    _apiKey = apiKey;
    _isConnected = false;
  }

  /// Clear configuration
  void clearConfiguration() {
    _serverUrl = null;
    _apiKey = null;
    _isConnected = false;
    _lastHeartbeat = null;
  }

  /// Authenticate with server
  Future<bool> authenticate() async {
    if (_serverUrl == null || _apiKey == null) {
      print('❌ Server not configured');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': _apiKey}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _isConnected = data['authenticated'] == true;
        
        if (_isConnected) {
          print('✅ Authentication successful');
          _lastHeartbeat = DateTime.now();
        }
        
        return _isConnected;
      }

      print('❌ Authentication failed: ${response.statusCode}');
      _isConnected = false;
      return false;
    } catch (e) {
      print('❌ Authentication error: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Send heartbeat to server
  Future<bool> sendHeartbeat() async {
    if (_serverUrl == null || _apiKey == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey!,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _lastHeartbeat = DateTime.now();
        _isConnected = true;
        return true;
      }

      _isConnected = false;
      return false;
    } catch (e) {
      print('❌ Heartbeat failed: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Get sync status from server
  Future<Map<String, dynamic>?> getSyncStatus() async {
    if (_serverUrl == null || _apiKey == null) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/sync/status'),
        headers: {'X-API-Key': _apiKey!},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      print('❌ Failed to get sync status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error getting sync status: $e');
      return null;
    }
  }

  /// Get inventory from server (products + categories)
  Future<Map<String, dynamic>?> getInventory() async {
    if (_serverUrl == null || _apiKey == null) {
      print('❌ Server not configured');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/sync/inventory'),
        headers: {'X-API-Key': _apiKey!},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ Retrieved ${(data['products'] as List).length} products, ${(data['categories'] as List).length} categories');
        return data;
      }

      print('❌ Failed to get inventory: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error getting inventory: $e');
      return null;
    }
  }

  /// Submit sales to server
  Future<bool> submitSales(List<Map<String, dynamic>> sales) async {
    if (_serverUrl == null || _apiKey == null) {
      print('❌ Server not configured');
      return false;
    }

    if (sales.isEmpty) {
      print('⚠️ No sales to submit');
      return true; // Not an error
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/sync/sales'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey!,
        },
        body: jsonEncode({'sales': sales}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ Submitted ${data['imported']} sales successfully');
        return true;
      }

      print('❌ Failed to submit sales: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error submitting sales: $e');
      return false;
    }
  }

  /// Get all sales from server
  Future<List<Map<String, dynamic>>?> getSales() async {
    if (_serverUrl == null || _apiKey == null) {
      print('❌ Server not configured');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/sync/sales'),
        headers: {'X-API-Key': _apiKey!},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sales = (data['sales'] as List)
            .map((s) => s as Map<String, dynamic>)
            .toList();
        print('✅ Retrieved ${sales.length} sales from server');
        return sales;
      }

      print('❌ Failed to get sales: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error getting sales: $e');
      return null;
    }
  }

  /// Get customers from server
  Future<List<Map<String, dynamic>>?> getCustomers() async {
    if (_serverUrl == null || _apiKey == null) {
      print('❌ Server not configured');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/sync/customers'),
        headers: {'X-API-Key': _apiKey!},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final customers = (data['customers'] as List)
            .map((c) => c as Map<String, dynamic>)
            .toList();
        print('✅ Retrieved ${customers.length} customers from server');
        return customers;
      }

      print('❌ Failed to get customers: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error getting customers: $e');
      return null;
    }
  }

  /// Test connection to server
  Future<bool> testConnection(String serverIp, int port, String apiKey) async {
    final testUrl = 'http://$serverIp:$port';
    
    try {
      // First check health endpoint
      final healthResponse = await http.get(
        Uri.parse('$testUrl/api/health'),
      ).timeout(const Duration(seconds: 5));

      if (healthResponse.statusCode != 200) {
        return false;
      }

      // Then try to authenticate
      final authResponse = await http.post(
        Uri.parse('$testUrl/api/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': apiKey}),
      ).timeout(const Duration(seconds: 5));

      if (authResponse.statusCode == 200) {
        final data = jsonDecode(authResponse.body) as Map<String, dynamic>;
        return data['authenticated'] == true;
      }

      return false;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }
}
