import '../entities/sync_config.dart';
import '../entities/sync_log.dart';

abstract class SyncRepository {
  /// Get the current sync configuration
  Future<SyncConfig?> getSyncConfig();

  /// Update sync configuration
  Future<int> updateSyncConfig(SyncConfig config);

  /// Create new sync configuration
  Future<int> insertSyncConfig(SyncConfig config);

  /// Delete sync configuration
  Future<int> deleteSyncConfig();

  /// Add a sync log entry
  Future<int> addSyncLog(SyncLog log);

  /// Get all sync logs
  Future<List<SyncLog>> getAllSyncLogs();

  /// Get recent sync logs (limit)
  Future<List<SyncLog>> getRecentSyncLogs({int limit = 50});

  /// Get sync logs by status
  Future<List<SyncLog>> getSyncLogsByStatus(String status);

  /// Clear old sync logs (older than specified days)
  Future<int> clearOldSyncLogs({int daysToKeep = 30});

  /// Add item to sync queue
  Future<int> addToSyncQueue({
    required String operationType,
    required String tableName,
    int? recordId,
    required Map<String, dynamic> data,
  });

  /// Get all pending sync queue items
  Future<List<Map<String, dynamic>>> getPendingSyncQueue();

  /// Remove item from sync queue
  Future<int> removeFromSyncQueue(int id);

  /// Update sync queue item retry count
  Future<int> updateSyncQueueRetry(int id, String error);

  /// Clear completed sync queue items
  Future<int> clearSyncQueue();
}
