import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/messaging_repository.dart';
import '../models/messaging_model.dart';

final messagingRepositoryProvider = Provider((ref) => MessagingRepository());

final conversationListProvider = FutureProvider<List<Conversation>>(
  (ref) => ref.read(messagingRepositoryProvider).getConversations(),
);

final messagesProvider = FutureProvider.family<List<ChatMessage>, int>(
  (ref, conversationId) =>
      ref.read(messagingRepositoryProvider).getMessages(conversationId),
);
