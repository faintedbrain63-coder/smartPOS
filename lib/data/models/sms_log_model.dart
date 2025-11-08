import '../../domain/entities/sms_log.dart';

class SmsLogModel extends SmsLog {
  const SmsLogModel({
    super.id,
    super.contactId,
    required super.messageContent,
    super.status = 'pending',
    super.sentAt,
    super.createdAt,
  });

  factory SmsLogModel.fromMap(Map<String, dynamic> map) {
    return SmsLogModel(
      id: map['id']?.toInt(),
      contactId: map['contact_id']?.toInt(),
      messageContent: map['message_content'] ?? '',
      status: map['status'] ?? 'pending',
      sentAt: map['sent_at'] != null 
          ? DateTime.parse(map['sent_at']) 
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contact_id': contactId,
      'message_content': messageContent,
      'status': status,
      'sent_at': sentAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory SmsLogModel.fromEntity(SmsLog smsLog) {
    return SmsLogModel(
      id: smsLog.id,
      contactId: smsLog.contactId,
      messageContent: smsLog.messageContent,
      status: smsLog.status,
      sentAt: smsLog.sentAt,
      createdAt: smsLog.createdAt,
    );
  }

  @override
  SmsLogModel copyWith({
    int? id,
    int? contactId,
    String? messageContent,
    String? status,
    DateTime? sentAt,
    DateTime? createdAt,
  }) {
    return SmsLogModel(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      messageContent: messageContent ?? this.messageContent,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}