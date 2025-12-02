import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkHelper {
  static final NetworkHelper _instance = NetworkHelper._internal();
  final NetworkInfo _networkInfo = NetworkInfo();

  NetworkHelper._internal();

  factory NetworkHelper() => _instance;

  /// Get the local IP address of the device
  /// Returns null if not connected to a network
  Future<String?> getLocalIpAddress() async {
    try {
      // Try to get WiFi IP first
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP != null && isValidIpAddress(wifiIP)) {
        return wifiIP;
      }

      // Fall back to network interfaces if WiFi IP not available
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Skip loopback addresses
          if (!addr.isLoopback && isValidIpAddress(addr.address)) {
            return addr.address;
          }
        }
      }

      return null;
    } catch (e) {
      print('Error getting local IP address: $e');
      return null;
    }
  }

  /// Validate IP address format
  bool isValidIpAddress(String ipAddress) {
    if (ipAddress.isEmpty) return false;

    final parts = ipAddress.split('.');
    if (parts.length != 4) return false;

    try {
      for (final part in parts) {
        final num = int.parse(part);
        if (num < 0 || num > 255) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate port number
  bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }

  /// Format server address with port
  String formatServerAddress(String ipAddress, int port) {
    return 'http://$ipAddress:$port';
  }

  /// Parse server address to get IP and port
  Map<String, dynamic>? parseServerAddress(String address) {
    try {
      final uri = Uri.parse(address);
      return {
        'ip': uri.host,
        'port': uri.port > 0 ? uri.port : 8080,
      };
    } catch (e) {
      print('Error parsing server address: $e');
      return null;
    }
  }

  /// Check if device is connected to a network
  Future<bool> isConnectedToNetwork() async {
    try {
      final ip = await getLocalIpAddress();
      return ip != null;
    } catch (e) {
      return false;
    }
  }

  /// Get WiFi SSID (network name)
  Future<String?> getWifiSSID() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (e) {
      print('Error getting WiFi SSID: $e');
      return null;
    }
  }

  /// Check if port is available on this device
  Future<bool> isPortAvailable(int port) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await server.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get a list of local network interfaces
  Future<List<Map<String, String>>> getNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      return interfaces
          .expand((interface) => interface.addresses.map((addr) => {
                'name': interface.name,
                'address': addr.address,
                'type': addr.type.name,
              }))
          .where((info) => isValidIpAddress(info['address']!))
          .toList();
    } catch (e) {
      print('Error getting network interfaces: $e');
      return [];
    }
  }
}
