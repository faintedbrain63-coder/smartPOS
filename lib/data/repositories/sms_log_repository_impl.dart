import '../../domain/entities/sms_log.dart';
import '../../domain/repositories/sms_log_repository.dart';
import '../datasources/database_helper.dart';
import '../models/sms_log_model.dart';

class SmsLogRepositoryImpl implements SmsLogRepository {
  final DatabaseHelper _databaseHelper;

  SmsLogRepositoryImpl(this._databaseHelper);

  @override
  Future<int> insertSmsLog(SmsLog smsLog) async {
    final db = await _databaseHelper.database;
    final smsLogModel = SmsLogModel.fromEntity(smsLog);
    
    final smsLogMap = smsLogModel.toMap();
    smsLogMap.remove('id'); // Remove id for auto-increment
    smsLogMap['created_at'] = DateTime.now().toIso8601String();
    
    return await db.insert('sms_logs', smsLogMap);
  }

  @override
  Future<List<SmsLog>> getSmsLogsByContactId(int contactId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_logs',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return SmsLogModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<SmsLog>> getAllSmsLogs() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_logs',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return SmsLogModel.fromMap(maps[i]);
    });
  }

  @override
  Future<List<SmsLog>> getSmsLogsByStatus(String status) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_logs',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return SmsLogModel.fromMap(maps[i]);
    });
  }

  @override
  Future<int> updateSmsLogStatus(int id, String status) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'sms_logs',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}