import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'local_server.dart';

class MobileServerBridge {
  static const platform = MethodChannel('com.smartpos/server');
  final LocalServer _localServer;

  MobileServerBridge(this._localServer) {
    platform.setMethodCallHandler(_handleMethodCall);
  }

  /// Start native server
  /// Returns null if successful, or error message if failed
  Future<String?> startServer(int port, String apiKey) async {
    try {
      await platform.invokeMethod('startServer', {
        'port': port,
        'apiKey': apiKey,
      });
      return null; // Success
    } on PlatformException catch (e) {
      print("Failed to start native server: '${e.message}'.");
      return e.message ?? "Unknown native error";
    }
  }

  /// Stop native server
  Future<bool> stopServer() async {
    try {
      final bool result = await platform.invokeMethod('stopServer');
      return result;
    } on PlatformException catch (e) {
      print("Failed to stop native server: '${e.message}'.");
      return false;
    }
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'handleRequest':
        return await _handleRequest(call.arguments);
      default:
        throw MissingPluginException();
    }
  }

  /// Handle incoming HTTP request from native
  Future<Map<String, dynamic>> _handleRequest(dynamic arguments) async {
    try {
      final args = Map<String, dynamic>.from(arguments);
      final method = args['method'] as String;
      final path = args['path'] as String;
      final headers = Map<String, String>.from(args['headers'] ?? {});
      final body = args['body'] as String?;

      // Create Shelf Request
      print('📥 Native request: $method $path');
      print('   Headers: $headers');
      print('   Body: ${body ?? "(empty)"}');
      
      final request = Request(
        method,
        Uri.parse('http://localhost$path'), // Host doesn't matter for internal logic
        headers: headers,
        body: body,
      );

      // Process request using LocalServer's handler
      final response = await _localServer.handleRequest(request);

      // Convert Shelf Response to Map for native
      final responseBody = await response.readAsString();
      
      print('📤 Response: ${response.statusCode} - ${responseBody.substring(0, responseBody.length > 100 ? 100 : responseBody.length)}...');
      
      // Don't pass headers to native - they generate them automatically
      // This prevents duplicate Content-Length and other header issues
      return {
        'statusCode': response.statusCode,
        'headers': <String, String>{},  // Empty headers - let native handle them
        'body': responseBody,
        'contentType': response.headers['content-type'] ?? 'application/json',
      };
    } catch (e) {
      print('Error handling native request: $e');
      return {
        'statusCode': 500,
        'body': jsonEncode({'error': 'Internal Server Error: $e'}),
        'contentType': 'application/json',
      };
    }
  }
}
