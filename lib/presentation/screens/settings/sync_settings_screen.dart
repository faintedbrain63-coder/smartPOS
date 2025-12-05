import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../providers/sync_provider.dart';
import 'qr_scan_screen.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _serverIpController = TextEditingController();
  final _serverPortController = TextEditingController(text: '8080');
  final _apiKeyController = TextEditingController();

  @override
  void dispose() {
    _serverIpController.dispose();
    _serverPortController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Synchronization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SyncProvider>().refresh();
            },
          ),
        ],
      ),
      body: Consumer<SyncProvider>(
        builder: (context, syncProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mode selection card
                _buildModeSelectionCard(syncProvider),
                
                const SizedBox(height: 16),
                
                // Configuration card based on mode
                if (syncProvider.isServerMode) ...[
                  _buildServerModeCard(syncProvider),
                ] else if (syncProvider.isClientMode) ...[
                  _buildClientModeCard(syncProvider),
                ] else ...[
                  _buildDisabledCard(),
                ],
                
                const SizedBox(height: 16),
                
                // Sync history card
                if (syncProvider.config != null && !syncProvider.isDisabled) ...[
                  _buildSyncHistoryCard(syncProvider),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeSelectionCard(SyncProvider syncProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Sync Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Server mode button
            ListTile(
              leading: Radio<String>(
                value: 'server',
                groupValue: syncProvider.isServerMode ? 'server'
                    : syncProvider.isClientMode ? 'client'
                    : 'disabled',
                onChanged: (value) {
                  if (value == 'server') {
                    _enableServerMode(syncProvider);
                  }
                },
              ),
              title: const Text('Server Mode'),
              subtitle: const Text('This device hosts data for clients'),
              onTap: () => _enableServerMode(syncProvider),
            ),
            
            // Client mode button
            ListTile(
              leading: Radio<String>(
                value: 'client',
                groupValue: syncProvider.isServerMode ? 'server'
                    : syncProvider.isClientMode ? 'client'
                    : 'disabled',
                onChanged: (value) {
                  if (value == 'client') {
                    _showClientModeDialog(syncProvider);
                  }
                },
              ),
              title: const Text('Client Mode'),
              subtitle: const Text('Connect to a server to sync data'),
              onTap: () => _showClientModeDialog(syncProvider),
            ),
            
            // Disabled button
            ListTile(
              leading: Radio<String>(
                value: 'disabled',
                groupValue: syncProvider.isServerMode ? 'server'
                    : syncProvider.isClientMode ? 'client'
                    : 'disabled',
                onChanged: (value) {
                  if (value == 'disabled') {
                    _disableSync(syncProvider);
                  }
                },
              ),
              title: const Text('Disabled'),
              subtitle: const Text('Turn off synchronization'),
              onTap: () => _disableSync(syncProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerModeCard(SyncProvider syncProvider) {
    final qrData = jsonEncode({
      'ip': syncProvider.localIpAddress,
      'port': syncProvider.config?.serverPort ?? 8080,
      'apiKey': syncProvider.config?.apiKey,
    });

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Server Active',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Local IP Address
            _buildInfoRow(
              icon: Icons.computer,
              label: 'Local IP',
              value: syncProvider.localIpAddress ?? 'Loading...',
            ),
            
            // Port
            _buildInfoRow(
              icon: Icons.settings_ethernet,
              label: 'Port',
              value: '${syncProvider.config?.serverPort ?? 8080}',
            ),
            
            // API Key
            _buildInfoRow(
              icon: Icons.vpn_key,
              label: 'API Key',
              value: syncProvider.config?.apiKey ?? '',
              copyable: true,
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // QR Code
            Center(
              child: Column(
                children: [
                  const Text(
                    'Scan to Connect',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientModeCard(SyncProvider syncProvider) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  syncProvider.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: syncProvider.isConnected ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  syncProvider.statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: syncProvider.isConnected ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Server IP
            _buildInfoRow(
              icon: Icons.dns,
              label: 'Server IP',
              value: syncProvider.config?.serverIpAddress ?? 'Not set',
            ),
            
            // Port
            _buildInfoRow(
              icon: Icons.settings_ethernet,
              label: 'Port',
              value: '${syncProvider.config?.serverPort ?? 8080}',
            ),
            
            // Last sync
            if (syncProvider.lastSyncTime != null)
              _buildInfoRow(
                icon: Icons.schedule,
                label: 'Last Sync',
                value: syncProvider.lastSyncTime!,
              ),
            
            const SizedBox(height: 16),
            
            // Sync button
            if (syncProvider.isConnected) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: syncProvider.isSyncing
                      ? null
                      : () => _performSync(syncProvider),
                  icon: syncProvider.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(syncProvider.isSyncing ? 'Syncing...' : 'Sync Now'),
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Disconnect button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showClientModeDialog(syncProvider),
                icon: const Icon(Icons.edit),
                label: const Text('Reconnect'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Synchronization Disabled',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a mode above to enable sync',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncHistoryCard(SyncProvider syncProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Sync History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (syncProvider.recentLogs.isEmpty) ...[
              Center(
                child: Text(
                  'No sync history yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ] else ...[
              ...syncProvider.recentLogs.take(5).map((log) {
                return ListTile(
                  leading: Icon(
                    log.isSuccess ? Icons.check_circle : Icons.error,
                    color: log.isSuccess ? Colors.green : Colors.red,
                  ),
                  title: Text(log.operationType.replaceAll('_', ' ').toUpperCase()),
                  subtitle: Text(
                    '${log.recordsSynced} records • ${_formatTimestamp(log.timestamp)}',
                  ),
                  dense: true,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (copyable) ...[
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                // Copy to clipboard
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Future<void> _enableServerMode(SyncProvider syncProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Server Mode'),
        content: const Text(
          'This device will act as the server and clients can connect to sync data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await syncProvider.enableServerMode();
      
      if (mounted) {
        final errorMsg = syncProvider.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Server mode enabled successfully'
                : errorMsg ?? 'Failed to enable server mode'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showClientModeDialog(SyncProvider syncProvider) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Client Mode'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Close dialog temporarily to scan
                    Navigator.pop(context);
                    await _scanQrCode();
                    // Re-open dialog with populated values
                    if (mounted) _showClientModeDialog(syncProvider);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Server QR Code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _serverIpController,
                decoration: const InputDecoration(
                  labelText: 'Server IP Address',
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.dns),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _serverPortController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '8080',
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _connectClient(syncProvider);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectClient(SyncProvider syncProvider) async {
    final serverIp = _serverIpController.text.trim();
    final serverPort = int.tryParse(_serverPortController.text.trim()) ?? 8080;
    final apiKey = _apiKeyController.text.trim();

    if (serverIp.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter server IP and API key'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show testing dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Testing connection...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    try {
      // First test the connection
      print('🔍 Testing connection to $serverIp:$serverPort');
      final testResult = await syncProvider.testConnection(serverIp, serverPort, apiKey);
      
      print('📊 Test result: ${testResult['success']}');
      if (testResult['error'] != null) {
        print('❌ Test error: ${testResult['error']}');
      }

      if (!testResult['success']) {
        if (mounted) {
          Navigator.pop(context); // Close testing dialog
          
          final errorMsg = testResult['error'] ?? 'Connection test failed';
          print('❌ Showing error to user: $errorMsg');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      // If test passed, proceed with full connection
      if (mounted) {
        // Update dialog text
        Navigator.pop(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Establishing connection...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      print('🔗 Establishing full connection...');
      final success = await syncProvider.enableClientMode(
        serverIp: serverIp,
        serverPort: serverPort,
        apiKey: apiKey,
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        
        if (success) {
          print('✅ Connection successful');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to server successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          final errorMsg = syncProvider.error ?? 'Failed to connect to server';
          print('❌ Connection failed: $errorMsg');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _connectClient: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.pop(context); // Close dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QrScanScreen(),
      ),
    );

    if (result != null) {
      try {
        final data = jsonDecode(result) as Map<String, dynamic>;
        if (data.containsKey('ip') && data.containsKey('port') && data.containsKey('apiKey')) {
          setState(() {
            _serverIpController.text = data['ip'];
            _serverPortController.text = data['port'].toString();
            _apiKeyController.text = data['apiKey'];
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('QR Code scanned successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw FormatException('Invalid QR code format');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid QR code. Please scan a valid Server QR.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _disableSync(SyncProvider syncProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Sync'),
        content: const Text('Are you sure you want to disable synchronization?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await syncProvider.disableSync();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronization disabled'),
          ),
        );
      }
    }
  }

  Future<void> _performSync(SyncProvider syncProvider) async {
    final success = await syncProvider.performSync();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Sync completed successfully'
              : 'Sync failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
