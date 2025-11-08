import '../entities/sms_log.dart';

abstract class SmsLogRepository {
  Future<int> insertSmsLog(SmsLog smsLog);
  Future<List<SmsLog>> getSmsLogsByContactId(int contactId);
  Future<List<SmsLog>> getAllSmsLogs();
  Future<List<SmsLog>> getSmsLogsByStatus(String status);
  Future<int> updateSmsLogStatus(int id, String status);
}