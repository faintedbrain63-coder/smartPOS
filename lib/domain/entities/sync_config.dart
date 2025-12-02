class SyncConfig {
  final int? id;
  final String deviceId;
  final String deviceMode; // 'disabled', 'server', 'client'
  final String? serverIpAddress;
  final int serverPort;
  final String? apiKey;
  final DateTime? lastSyncTimestamp;
  final String syncStatus; // 'idle', 'syncing', 'error', 'offline'
  final bool autoSyncEnabled;
  final int syncIntervalMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SyncConfig({
    this.id,
    required this.deviceId,
    required this.deviceMode,
    this.serverIpAddress,
    this.serverPort = 8080,
    this.apiKey,
    this.lastSyncTimestamp,
    this.syncStatus = 'idle',
    this.autoSyncEnabled = true,
    this.syncIntervalMinutes = 5,
    this.createdAt,
    this.updatedAt,
  });

  SyncConfig copyWith({
    int? id,
    String? deviceId,
    String? deviceMode,
    String? serverIpAddress,
    int? serverPort,
    String? apiKey,
    DateTime? lastSyncTimestamp,
    String? syncStatus,
    bool? autoSyncEnabled,
    int? syncIntervalMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SyncConfig(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceMode: deviceMode ?? this.deviceMode,
      serverIpAddress: serverIpAddress ?? this.serverIpAddress,
      serverPort: serverPort ?? this.serverPort,
      apiKey: apiKey ?? this.apiKey,
      lastSyncTimestamp: lastSyncTimestamp ?? this.lastSyncTimestamp,
      syncStatus: syncStatus ?? this.syncStatus,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isServerMode => deviceMode == 'server';
  bool get isClientMode => deviceMode == 'client';
  bool get isDisabled => deviceMode == 'disabled';
  bool get isConfigured => deviceMode != 'disabled';
  bool get isSyncing => syncStatus == 'syncing';
  bool get hasError => syncStatus == 'error';
  bool get isOffline => syncStatus == 'offline';
}
