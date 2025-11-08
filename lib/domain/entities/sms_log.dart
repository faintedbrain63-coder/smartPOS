class SmsLog {
  final int? id;
  final int? contactId;
  final String messageContent;
  final String status;
  final DateTime? sentAt;
  final DateTime? createdAt;

  const SmsLog({
    this.id,
    this.contactId,
    required this.messageContent,
    this.status = 'pending',
    this.sentAt,
    this.createdAt,
  });

  SmsLog copyWith({
    int? id,
    int? contactId,
    String? messageContent,
    String? status,
    DateTime? sentAt,
    DateTime? createdAt,
  }) {
    return SmsLog(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      messageContent: messageContent ?? this.messageContent,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmsLog &&
        other.id == id &&
        other.contactId == contactId &&
        other.messageContent == messageContent &&
        other.status == status &&
        other.sentAt == sentAt &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        contactId.hashCode ^
        messageContent.hashCode ^
        status.hashCode ^
        sentAt.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'SmsLog(id: $id, contactId: $contactId, messageContent: $messageContent, status: $status, sentAt: $sentAt, createdAt: $createdAt)';
  }
}