import '../../domain/entities/sync_log.dart';

class SyncLogModel extends SyncLog {
  const SyncLogModel({
    super.id,
    required super.operationType,
    required super.timestamp,
    required super.status,
    super.recordsSynced,
    super.errorMessage,
    super.deviceId,
    super.details,
  });

  factory SyncLogModel.fromMap(Map<String, dynamic> map) {
    return SyncLogModel(
      id: map['id']?.toInt(),
      operationType: map['operation_type'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      recordsSynced: map['records_synced']?.toInt() ?? 0,
      errorMessage: map['error_message'],
      deviceId: map['device_id'],
      details: map['details'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operation_type': operationType,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'records_synced': recordsSynced,
      'error_message': errorMessage,
      'device_id': deviceId,
      'details': details,
    };
  }

  factory SyncLogModel.fromEntity(SyncLog log) {
    return SyncLogModel(
      id: log.id,
      operationType: log.operationType,
      timestamp: log.timestamp,
      status: log.status,
      recordsSynced: log.recordsSynced,
      errorMessage: log.errorMessage,
      deviceId: log.deviceId,
      details: log.details,
    );
  }

  @override
  SyncLogModel copyWith({
    int? id,
    String? operationType,
    DateTime? timestamp,
    String? status,
    int? recordsSynced,
    String? errorMessage,
    String? deviceId,
    String? details,
  }) {
    return SyncLogModel(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      recordsSynced: recordsSynced ?? this.recordsSynced,
      errorMessage: errorMessage ?? this.errorMessage,
      deviceId: deviceId ?? this.deviceId,
      details: details ?? this.details,
    );
  }
}
