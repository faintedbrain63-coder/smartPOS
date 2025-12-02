import '../../domain/entities/sync_config.dart';

class SyncConfigModel extends SyncConfig {
  const SyncConfigModel({
    super.id,
    required super.deviceId,
    required super.deviceMode,
    super.serverIpAddress,
    super.serverPort,
    super.apiKey,
    super.lastSyncTimestamp,
    super.syncStatus,
    super.autoSyncEnabled,
    super.syncIntervalMinutes,
    super.createdAt,
    super.updatedAt,
  });

  factory SyncConfigModel.fromMap(Map<String, dynamic> map) {
    return SyncConfigModel(
      id: map['id']?.toInt(),
      deviceId: map['device_id'] ?? '',
      deviceMode: map['device_mode'] ?? 'disabled',
      serverIpAddress: map['server_ip_address'],
      serverPort: map['server_port']?.toInt() ?? 8080,
      apiKey: map['api_key'],
      lastSyncTimestamp: map['last_sync_timestamp'] != null
          ? DateTime.parse(map['last_sync_timestamp'])
          : null,
      syncStatus: map['sync_status'] ?? 'idle',
      autoSyncEnabled: (map['auto_sync_enabled'] as int?) == 1,
      syncIntervalMinutes: map['sync_interval_minutes']?.toInt() ?? 5,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'device_mode': deviceMode,
      'server_ip_address': serverIpAddress,
      'server_port': serverPort,
      'api_key': apiKey,
      'last_sync_timestamp': lastSyncTimestamp?.toIso8601String(),
      'sync_status': syncStatus,
      'auto_sync_enabled': autoSyncEnabled ? 1 : 0,
      'sync_interval_minutes': syncIntervalMinutes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SyncConfigModel.fromEntity(SyncConfig config) {
    return SyncConfigModel(
      id: config.id,
      deviceId: config.deviceId,
      deviceMode: config.deviceMode,
      serverIpAddress: config.serverIpAddress,
      serverPort: config.serverPort,
      apiKey: config.apiKey,
      lastSyncTimestamp: config.lastSyncTimestamp,
      syncStatus: config.syncStatus,
      autoSyncEnabled: config.autoSyncEnabled,
      syncIntervalMinutes: config.syncIntervalMinutes,
      createdAt: config.createdAt,
      updatedAt: config.updatedAt,
    );
  }

  @override
  SyncConfigModel copyWith({
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
    return SyncConfigModel(
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
}
