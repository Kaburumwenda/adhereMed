import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../models/messaging_model.dart';
import '../repository/messaging_repository.dart';
import '../../auth/providers/auth_provider.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final _repo = MessagingRepository();
  List<Conversation>? _conversations;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getConversations();
      setState(() {
        _conversations = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).valueOrNull;
    final isDoctor = currentUser?.role == 'doctor';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDoctor
                          ? 'Patient consultations'
                          : 'Your doctor consultations',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!isDoctor)
                FilledButton.icon(
                  onPressed: () => context.push('/doctors'),
                  icon: const Icon(Icons.person_search),
                  label: const Text('Find a Doctor'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : _conversations == null || _conversations!.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.chat_outlined,
                            title: 'No conversations yet',
                            subtitle: isDoctor
                                ? 'Patients will appear here when they start a consultation'
                                : 'Find a doctor to start a consultation',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              itemCount: _conversations!.length,
                              itemBuilder: (context, index) {
                                final conv = _conversations![index];
                                return _ConversationTile(
                                  conversation: conv,
                                  isDoctor: isDoctor,
                                  onTap: () => context
                                      .push('/messages/${conv.id}'),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isDoctor;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.isDoctor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherName =
        isDoctor ? conversation.patientName : 'Dr. ${conversation.doctorName}';
    final lastMsg = conversation.lastMessage;
    final hasUnread = conversation.unreadCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherName,
                style: TextStyle(
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (lastMsg != null)
              Text(
                _formatTime(lastMsg['created_at']),
                style: TextStyle(
                  fontSize: 12,
                  color: hasUnread ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
          ],
        ),
        subtitle: lastMsg != null
            ? Text(
                lastMsg['content'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasUnread
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      hasUnread ? FontWeight.w500 : FontWeight.normal,
                ),
              )
            : const Text('No messages yet'),
        trailing: hasUnread
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  String _formatTime(String? isoDate) {
    if (isoDate == null) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
