class SyncLog {
  final int? id;
  final String operationType; // 'inventory_pull', 'inventory_push', 'sales_push', 'full_sync'
  final DateTime timestamp;
  final String status; // 'pending', 'success', 'failed'
  final int recordsSynced;
  final String? errorMessage;
  final String? deviceId;
  final String? details;

  const SyncLog({
    this.id,
    required this.operationType,
    required this.timestamp,
    required this.status,
    this.recordsSynced = 0,
    this.errorMessage,
    this.deviceId,
    this.details,
  });

  SyncLog copyWith({
    int? id,
    String? operationType,
    DateTime? timestamp,
    String? status,
    int? recordsSynced,
    String? errorMessage,
    String? deviceId,
    String? details,
  }) {
    return SyncLog(
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

  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';
}
