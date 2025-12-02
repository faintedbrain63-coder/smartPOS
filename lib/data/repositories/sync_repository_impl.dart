import 'dart:convert';
import '../../domain/entities/sync_config.dart';
import '../../domain/entities/sync_log.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/database_helper.dart';
import '../models/sync_config_model.dart';
import '../models/sync_log_model.dart';

class SyncRepositoryImpl implements SyncRepository {
  final DatabaseHelper _databaseHelper;

  SyncRepositoryImpl(this._databaseHelper);

  @override
  Future<SyncConfig?> getSyncConfig() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('sync_config', limit: 1);
    
    if (maps.isEmpty) {
      return null;
    }
    
    return SyncConfigModel.fromMap(maps.first);
  }

  @override
  Future<int> updateSyncConfig(SyncConfig config) async {
    final db = await _databaseHelper.database;
    final model = SyncConfigModel.fromEntity(config);
    final map = model.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    
    return await db.update(
      'sync_config',
      map,
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  @override
  Future<int> insertSyncConfig(SyncConfig config) async {
    final db = await _databaseHelper.database;
    final model = SyncConfigModel.fromEntity(config);
    final map = model.toMap();
    map.remove('id'); // Remove ID for auto-increment
    final now = DateTime.now().toIso8601String();
    map['created_at'] = now;
    map['updated_at'] = now;
    
    return await db.insert('sync_config', map);
  }

  @override
  Future<int> deleteSyncConfig() async {
    final db = await _databaseHelper.database;
    return await db.delete('sync_config');
  }

  @override
  Future<int> addSyncLog(SyncLog log) async {
    final db = await _databaseHelper.database;
    final model = SyncLogModel.fromEntity(log);
    final map = model.toMap();
    map.remove('id'); // Remove ID for auto-increment
    
    return await db.insert('sync_logs', map);
  }

  @override
  Future<List<SyncLog>> getAllSyncLogs() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'sync_logs',
      orderBy: 'timestamp DESC',
    );
    
    return maps.map((m) => SyncLogModel.fromMap(m)).toList();
  }

  @override
  Future<List<SyncLog>> getRecentSyncLogs({int limit = 50}) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'sync_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return maps.map((m) => SyncLogModel.fromMap(m)).toList();
  }

  @override
  Future<List<SyncLog>> getSyncLogsByStatus(String status) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'sync_logs',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'timestamp DESC',
    );
    
    return maps.map((m) => SyncLogModel.fromMap(m)).toList();
  }

  @override
  Future<int> clearOldSyncLogs({int daysToKeep = 30}) async {
    final db = await _databaseHelper.database;
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: daysToKeep))
        .toIso8601String();
    
    return await db.delete(
      'sync_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate],
    );
  }

  @override
  Future<int> addToSyncQueue({
    required String operationType,
    required String tableName,
    int? recordId,
    required Map<String, dynamic> data,
  }) async {
    final db = await _databaseHelper.database;
    
    return await db.insert('sync_queue', {
      'operation_type': operationType,
      'table_name': tableName,
      'record_id': recordId,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncQueue() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
    
    return maps.map((m) {
      final map = Map<String, dynamic>.from(m);
      // Decode JSON data
      if (map['data'] != null) {
        map['data'] = jsonDecode(map['data'] as String);
      }
      return map;
    }).toList();
  }

  @override
  Future<int> removeFromSyncQueue(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> updateSyncQueueRetry(int id, String error) async {
    final db = await _databaseHelper.database;
    
    // Get current retry count
    final maps = await db.query(
      'sync_queue',
      columns: ['retry_count'],
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return 0;
    
    final currentRetryCount = maps.first['retry_count'] as int;
    
    return await db.update(
      'sync_queue',
      {
        'retry_count': currentRetryCount + 1,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> clearSyncQueue() async {
    final db = await _databaseHelper.database;
    return await db.delete('sync_queue');
  }
}
