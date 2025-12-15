import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SyncClient {
  static final SyncClient _instance = SyncClient._internal();
  
  String? _serverUrl;
  String? _apiKey;
  bool _isConnected = false;
  DateTime? _lastHeartbeat;
  String? _lastError;

  SyncClient._internal();

  factory SyncClient() => _instance;

  bool get isConnected => _isConnected;
  String? get serverUrl => _serverUrl;
  DateTime? get lastHeartbeat => _lastHeartbeat;
  String? get lastError => _lastError;

  /// Configure client with server details
  void configure({required String serverIp, required int port, required String apiKey}) {
    _serverUrl = 'http://$serverIp:$port';
    _apiKey = apiKey;
    _isConnected = false;
    _lastError = null;
  }

  /// Clear configuration
  void clearConfiguration() {
    _serverUrl = null;
    _apiKey = null;
    _isConnected = false;
    _lastHeartbeat = null;
    _lastError = null;
  }

  /// Authenticate with server
  Future<bool> authenticate() async {
    if (_serverUrl == null || _apiKey == null) {
      _lastError = 'Server not configured';
      print('❌ Server not configured');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': _apiKey}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _isConnected = data['authenticated'] == true;
        
        if (_isConnected) {
          print('✅ Authentication successful');
          _lastHeartbeat = DateTime.now();
          _lastError = null;
        } else {
          _lastError = 'Invalid API key. Please check your API key and try again.';
          print('❌ Authentication failed: Invalid API key');
        }
        
        return _isConnected;
      } else if (response.statusCode == 403) {
        _lastError = 'Invalid API key. Please check your API key and try again.';
        print('❌ Authentication failed: Invalid API key (403)');
        _isConnected = false;
        return false;
      } else if (response.statusCode == 404) {
        _lastError = 'Server endpoint not found. Please verify the server is running and the port is correct.';
        print('❌ Authentication failed: Endpoint not found (404)');
        _isConnected = false;
        return false;
      } else if (response.statusCode == 500) {
        _lastError = 'Server internal error (500). The server is running but encountered an error. Please check server logs or try again.';
        print('❌ Authentication failed: Server internal error (500)');
        _isConnected = false;
        return false;
      } else {
        _lastError = 'Server returned error (${response.statusCode}). Please check server status.';
        print('❌ Authentication failed: ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } on TimeoutException {
      _lastError = 'Connection timeout. Please check if the server is reachable and the IP address and port are correct.';
      print('❌ Authentication timeout');
      _isConnected = false;
      return false;
    } on SocketException catch (e) {
      print('❌ SocketException details: ${e.runtimeType}');
      print('   Message: ${e.message}');
      print('   OS Error: ${e.osError?.message}');
      print('   Address: ${e.address}');
      print('   Port: ${e.port}');
      
      if (e.message.contains('Failed host lookup') || e.message.contains('nodename nor servname provided')) {
        _lastError = 'Cannot resolve server address. Please check the IP address is correct.';
      } else if (e.message.contains('Connection refused')) {
        _lastError = 'Connection refused. Please check if the server is running and the port is correct.';
      } else if (e.osError?.message.contains('Network is unreachable') == true) {
        _lastError = 'Network is unreachable. Please check that both devices are on the same WiFi network.';
      } else if (e.osError?.message.contains('No route to host') == true) {
        _lastError = 'No route to host. Please check that server IP is accessible from this device.';
      } else {
        _lastError = 'Network error: ${e.osError?.message ?? e.message}. Please check your network connection.';
      }
      _isConnected = false;
      return false;
    } on http.ClientException catch (e) {
      print('❌ ClientException: ${e.message}');
      print('   URI: ${e.uri}');
      _lastError = 'Connection failed: ${e.message}. Please verify server is running and accessible.';
      _isConnected = false;
      return false;
    } on HttpException catch (e) {
      _lastError = 'HTTP error: ${e.message}. Please check server configuration.';
      print('❌ HTTP error: $e');
      _isConnected = false;
      return false;
    } catch (e, stackTrace) {
      print('❌ Authentication error: $e');
      print('   Type: ${e.runtimeType}');
      print('   StackTrace: $stackTrace');
      _lastError = 'Connection failed: ${e.toString()}. Please verify server IP, port, and API key.';
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

  /// Submit category to server (create or update)
  Future<bool> submitCategory(Map<String, dynamic> category, {bool isUpdate = false}) async {
    if (_serverUrl == null || _apiKey == null) {
      print('❌ Server not configured');
      return false;
    }

    try {
      final url = isUpdate 
          ? Uri.parse('$_serverUrl/api/categories/${category['id']}')
          : Uri.parse('$_serverUrl/api/categories');
      
      final response = isUpdate
          ? await http.put(
              url,
              headers: {
                'Content-Type': 'application/json',
                'X-API-Key': _apiKey!,
              },
              body: jsonEncode(category),
            ).timeout(const Duration(seconds: 10))
          : await http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'X-API-Key': _apiKey!,
              },
              body: jsonEncode(category),
            ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ ${isUpdate ? 'Updated' : 'Created'} category successfully');
        return true;
      }

      print('❌ Failed to ${isUpdate ? 'update' : 'create'} category: ${response.statusCode}');
      print('   Response: ${response.body}');
      return false;
    } catch (e) {
      print('❌ Error ${isUpdate ? 'updating' : 'creating'} category: $e');
      return false;
    }
  }

  /// Test connection to server
  Future<Map<String, dynamic>> testConnection(String serverIp, int port, String apiKey) async {
    final testUrl = 'http://$serverIp:$port';
    final result = <String, dynamic>{
      'success': false,
      'error': null,
      'step': null,
    };
    
    print('🔍 testConnection: Testing $testUrl');
    print('   IP: $serverIp, Port: $port, API Key: ${apiKey.substring(0, apiKey.length > 8 ? 8 : apiKey.length)}...');
    
    try {
      // First check health endpoint
      result['step'] = 'Checking server health...';
      print('📡 Step 1: Checking health endpoint at $testUrl/api/health');
      
      final healthResponse = await http.get(
        Uri.parse('$testUrl/api/health'),
      ).timeout(const Duration(seconds: 30));

      print('📊 Health check response: ${healthResponse.statusCode}');
      if (healthResponse.statusCode != 200) {
        print('   Response body: ${healthResponse.body}');
      }

      if (healthResponse.statusCode == 200) {
        // Health check passed, continue
        print('✅ Health check passed');
      } else if (healthResponse.statusCode == 500) {
        result['error'] = 'Server internal error (500). The server is running but encountered an error. Please check server logs or try again.';
        print('❌ Health check failed with 500');
        return result;
      } else {
        result['error'] = 'Server health check failed (${healthResponse.statusCode}). Please verify the server is running and accessible.';
        print('❌ Health check failed with ${healthResponse.statusCode}');
        return result;
      }

      // Then try to authenticate
      result['step'] = 'Authenticating...';
      print('🔐 Step 2: Authenticating at $testUrl/api/authenticate');
      
      final authResponse = await http.post(
        Uri.parse('$testUrl/api/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': apiKey}),
      ).timeout(const Duration(seconds: 30));

      print('📊 Auth response: ${authResponse.statusCode}');
      print('   Response body: ${authResponse.body}');

      if (authResponse.statusCode == 200) {
        final data = jsonDecode(authResponse.body) as Map<String, dynamic>;
        if (data['authenticated'] == true) {
          result['success'] = true;
          result['step'] = 'Connection successful';
          print('✅ Authentication successful');
          return result;
        } else {
          result['error'] = 'Invalid API key. Please check your API key.';
          print('❌ Authentication failed: API key not authenticated');
          return result;
        }
      } else if (authResponse.statusCode == 403) {
        result['error'] = 'Invalid API key. Please check your API key.';
        print('❌ Authentication failed: 403 Forbidden');
        return result;
      } else if (authResponse.statusCode == 500) {
        result['error'] = 'Server internal error (500). The server is running but encountered an error. Please check server logs or try again.';
        print('❌ Authentication failed: 500 Internal Server Error');
        return result;
      } else {
        result['error'] = 'Authentication failed (${authResponse.statusCode}). Please check server configuration.';
        print('❌ Authentication failed: ${authResponse.statusCode}');
        return result;
      }
    } on TimeoutException catch (e) {
      result['error'] = 'Connection timeout. Please check if the server is reachable and the IP address and port are correct.';
      print('❌ Connection timeout: $e');
      return result;
    } on SocketException catch (e) {
      print('❌ SocketException: ${e.runtimeType} - ${e.message}');
      print('   OS Error: ${e.osError?.message}');
      print('   Address: ${e.address}');
      print('   Port: ${e.port}');
      
      if (e.message.contains('Failed host lookup') || e.message.contains('nodename nor servname provided')) {
        result['error'] = 'Cannot resolve server address. Please check the IP address is correct.';
      } else if (e.message.contains('Connection refused')) {
        result['error'] = 'Connection refused. Please check if the server is running and the port is correct.';
      } else if (e.osError?.message.contains('Network is unreachable') == true) {
        result['error'] = 'Network is unreachable. Please check that both devices are on the same WiFi network.';
      } else if (e.osError?.message.contains('No route to host') == true) {
        result['error'] = 'No route to host. Please check that server IP is accessible from this device.';
      } else {
        result['error'] = 'Network error: ${e.osError?.message ?? e.message}. Please check your network connection.';
      }
      return result;
    } on http.ClientException catch (e) {
      print('❌ ClientException in testConnection: ${e.message}');
      print('   URI: ${e.uri}');
      result['error'] = 'Connection failed: ${e.message}. Please verify server is running and accessible.';
      return result;
    } catch (e, stackTrace) {
      print('❌ Unexpected error in testConnection: $e');
      print('   Type: ${e.runtimeType}');
      print('   Stack trace: $stackTrace');
      result['error'] = 'Connection test failed: ${e.toString()}';
      return result;
    }
  }
}
