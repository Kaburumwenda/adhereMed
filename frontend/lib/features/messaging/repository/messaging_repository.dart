import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/messaging_model.dart';

class MessagingRepository {
  final Dio _dio = ApiClient.instance;

  /// List all conversations for the current user.
  Future<List<Conversation>> getConversations() async {
    final response = await _dio.get('/messaging/conversations/');
    final data = response.data;
    final List results = data is Map ? (data['results'] ?? []) : data;
    return results.map((j) => Conversation.fromJson(j)).toList();
  }

  /// Start or resume a conversation with a doctor.
  Future<Conversation> startConversation({
    required int doctorId,
    required String message,
    String subject = '',
  }) async {
    final response = await _dio.post('/messaging/conversations/', data: {
      'doctor_id': doctorId,
      'message': message,
      'subject': subject,
    });
    return Conversation.fromJson(response.data);
  }

  /// Get messages for a conversation.
  Future<List<ChatMessage>> getMessages(int conversationId) async {
    final response = await _dio.get(
      '/messaging/conversations/$conversationId/messages/',
    );
    final data = response.data;
    final List results = data is Map ? (data['results'] ?? []) : data;
    return results.map((j) => ChatMessage.fromJson(j)).toList();
  }

  /// Send a message in a conversation.
  Future<ChatMessage> sendMessage(int conversationId, String content) async {
    final response = await _dio.post(
      '/messaging/conversations/$conversationId/messages/',
      data: {'content': content},
    );
    return ChatMessage.fromJson(response.data);
  }
}
