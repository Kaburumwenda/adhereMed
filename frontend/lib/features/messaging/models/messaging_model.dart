class Conversation {
  final int id;
  final int patientId;
  final String patientName;
  final int doctorId;
  final String doctorName;
  final String subject;
  final bool isActive;
  final Map<String, dynamic>? lastMessage;
  final int unreadCount;
  final String? createdAt;
  final String? updatedAt;

  Conversation({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    this.subject = '',
    this.isActive = true,
    this.lastMessage,
    this.unreadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      patientId: json['patient'] ?? 0,
      patientName: json['patient_name'] ?? '',
      doctorId: json['doctor'] ?? 0,
      doctorName: json['doctor_name'] ?? '',
      subject: json['subject'] ?? '',
      isActive: json['is_active'] ?? true,
      lastMessage: json['last_message'] as Map<String, dynamic>?,
      unreadCount: json['unread_count'] ?? 0,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String content;
  final bool isRead;
  final String? createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.isRead = false,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      conversationId: json['conversation'] ?? 0,
      senderId: json['sender'] ?? 0,
      senderName: json['sender_name'] ?? '',
      content: json['content'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'],
    );
  }
}
