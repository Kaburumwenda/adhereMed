import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api.dart';
import 'hc_common.dart';

final _folderProvider = StateProvider.autoDispose((_) => 'INBOX');

final _messagesProvider = FutureProvider.autoDispose((ref) async {
  final folder = ref.watch(_folderProvider);
  final dio = ref.read(dioProvider);
  final res = await dio
      .get('/homecare/mail/messages/', queryParameters: {'folder': folder});
  final data = res.data;
  if (data is List) return data;
  return (data?['results'] as List?) ?? (data?['messages'] as List?) ?? [];
});

/// Tenant mailbox: inbox / sent, read + compose.
class HomecareMailScreen extends ConsumerWidget {
  const HomecareMailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(_messagesProvider);
    final folder = ref.watch(_folderProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'compose-mail',
        onPressed: () => _openCompose(context, ref),
        backgroundColor: hcTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Compose'),
      ),
      body: HcAsyncBody(
        value: messages,
        onRefresh: () async => ref.refresh(_messagesProvider.future),
        builder: (list) {
          final rows = list.cast<Map>();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              HcHero(
                eyebrow: 'COMMUNICATION',
                title: 'Mail',
                subtitle: 'Your organisation mailbox',
                icon: Icons.mail_rounded,
                chips: [
                  HcHeroChip(
                      icon: Icons.inbox_rounded,
                      label: '${rows.length} in $folder'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'INBOX',
                            label: Text('Inbox'),
                            icon: Icon(Icons.inbox_rounded, size: 16)),
                        ButtonSegment(
                            value: 'Sent',
                            label: Text('Sent'),
                            icon: Icon(Icons.send_rounded, size: 16)),
                      ],
                      selected: {folder},
                      onSelectionChanged: (s) => ref
                          .read(_folderProvider.notifier)
                          .state = s.first,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Mail account settings',
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: () => _openAccountSettings(context, ref),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No messages.')),
                )
              else
                ...rows.take(50).map((m) {
                  final seen = m['seen'] == true || m['is_read'] == true;
                  final at = DateTime.tryParse(
                          (m['date'] ?? m['received_at'] ?? '').toString())
                      ?.toLocal();
                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ListTile(
                      onTap: () => _openMessage(context, ref, m),
                      leading: HcAvatar(
                          name: (m['from_name'] ?? m['from'] ?? '?')
                              .toString(),
                          size: 40,
                          color: seen ? hcSlate : hcTeal),
                      title: Text(
                          (m['subject'] ?? '(no subject)').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight:
                                  seen ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 13.5)),
                      subtitle: Text(
                          (m['from'] ?? m['to'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5)),
                      trailing: Text(at != null ? timeago.format(at) : '',
                          style: const TextStyle(fontSize: 10.5)),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openMessage(
      BuildContext context, WidgetRef ref, Map m) async {
    final uid = (m['uid'] ?? m['id'] ?? '').toString();
    Map detail = m;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/mail/messages/$uid/');
      detail = (res.data as Map?) ?? m;
      // Mark seen (best-effort)
      dio.post('/homecare/mail/messages/$uid/seen/').ignore();
    } catch (_) {/* fall back to list data */}
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Text((detail['subject'] ?? '(no subject)').toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                  'From ${detail['from'] ?? '—'} · ${hcDateTime(detail['date'])}',
                  style: const TextStyle(fontSize: 12)),
              const Divider(height: 24),
              Text(
                  (detail['body_text'] ??
                          detail['body'] ??
                          detail['snippet'] ??
                          '')
                      .toString(),
                  style: const TextStyle(fontSize: 13.5, height: 1.5)),
            ],
          ),
        ),
      ),
    ).whenComplete(() => ref.invalidate(_messagesProvider));
  }

  Future<void> _openAccountSettings(
      BuildContext context, WidgetRef ref) async {
    Map current = {};
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/mail/account/');
      current = (res.data as Map?) ?? {};
    } catch (_) {}
    if (!context.mounted) return;
    final email =
        TextEditingController(text: (current['email'] ?? '').toString());
    final imapHost = TextEditingController(
        text: (current['imap_host'] ?? '').toString());
    final imapPort = TextEditingController(
        text: (current['imap_port'] ?? '993').toString());
    final smtpHost = TextEditingController(
        text: (current['smtp_host'] ?? '').toString());
    final smtpPort = TextEditingController(
        text: (current['smtp_port'] ?? '587').toString());
    final password = TextEditingController();
    bool saving = false;
    bool testing = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mail account settings',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Email address')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      flex: 2,
                      child: TextField(
                          controller: imapHost,
                          decoration: const InputDecoration(
                              labelText: 'IMAP host'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: imapPort,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Port'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      flex: 2,
                      child: TextField(
                          controller: smtpHost,
                          decoration: const InputDecoration(
                              labelText: 'SMTP host'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: smtpPort,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Port'))),
                ]),
                const SizedBox(height: 10),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Password (leave blank to keep)')),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: testing
                          ? null
                          : () async {
                              setSheetState(() => testing = true);
                              try {
                                final dio = ref.read(dioProvider);
                                await dio.post(
                                    '/homecare/mail/account/test/');
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Connection OK.')));
                                }
                              } catch (_) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Connection failed.')));
                                }
                              } finally {
                                setSheetState(() => testing = false);
                              }
                            },
                      icon: testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.wifi_tethering_rounded,
                              size: 16),
                      label: const Text('Test'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style:
                          FilledButton.styleFrom(backgroundColor: hcTeal),
                      onPressed: saving
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              try {
                                final dio = ref.read(dioProvider);
                                await dio.post('/homecare/mail/account/',
                                    data: {
                                      'email': email.text.trim(),
                                      'imap_host': imapHost.text.trim(),
                                      'imap_port': int.tryParse(
                                              imapPort.text) ??
                                          993,
                                      'smtp_host': smtpHost.text.trim(),
                                      'smtp_port': int.tryParse(
                                              smtpPort.text) ??
                                          587,
                                      if (password.text.isNotEmpty)
                                        'password': password.text,
                                    });
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Mail settings saved.')));
                                }
                              } catch (_) {
                                setSheetState(() => saving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Could not save settings.')));
                                }
                              }
                            },
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Save'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCompose(BuildContext context, WidgetRef ref) {
    final to = TextEditingController();
    final subject = TextEditingController();
    final body = TextEditingController();
    bool sending = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Compose',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                  controller: to,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'To *')),
              const SizedBox(height: 10),
              TextField(
                  controller: subject,
                  decoration:
                      const InputDecoration(labelText: 'Subject *')),
              const SizedBox(height: 10),
              TextField(
                  controller: body,
                  maxLines: 5,
                  decoration:
                      const InputDecoration(labelText: 'Message *')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: hcTeal),
                  onPressed: sending
                      ? null
                      : () async {
                          if (to.text.trim().isEmpty ||
                              subject.text.trim().isEmpty ||
                              body.text.trim().isEmpty) {
                            return;
                          }
                          setSheetState(() => sending = true);
                          try {
                            final dio = ref.read(dioProvider);
                            await dio.post('/homecare/mail/send/', data: {
                              'to': to.text.trim(),
                              'subject': subject.text.trim(),
                              'body': body.text.trim(),
                            });
                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Message sent.')));
                            }
                          } catch (_) {
                            setSheetState(() => sending = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not send (check mail account settings).')));
                            }
                          }
                        },
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
