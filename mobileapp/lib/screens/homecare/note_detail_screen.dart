import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import 'hc_common.dart';
import 'note_helpers.dart';

/// Care note detail view — mirrors the web /homecare/notes/[id] page.
class HomecareNoteDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const HomecareNoteDetailScreen({super.key, required this.id});

  @override
  ConsumerState<HomecareNoteDetailScreen> createState() =>
      _HomecareNoteDetailScreenState();
}

class _HomecareNoteDetailScreenState
    extends ConsumerState<HomecareNoteDetailScreen> {
  Map? _note;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/notes/${widget.id}/');
      setState(() => _note = res.data is Map ? res.data as Map : null);
    } catch (_) {
      setState(() => _error = 'Could not load this note.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _note == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Care note')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error ?? 'Not found'),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
    }
    final n = _note!;
    final cat = noteCategoryMeta(n['category']?.toString());
    final vitals = (n['vitals'] as Map?) ?? const {};
    final attachments = (n['attached_files'] as List?)?.cast<Map>() ?? const [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'HOMECARE · NOTE DETAILS',
              title: '${cat.label} note',
              subtitle: 'For ${n['patient_name'] ?? 'patient'} · by ${n['caregiver_name'] ?? 'caregiver'}',
              icon: cat.icon,
              chips: [
                HcHeroChip(icon: Icons.event_rounded, label: hcDateTime(n['recorded_at'])),
                HcHeroChip(icon: Icons.attach_file_rounded, label: '${attachments.length} attachment${attachments.length == 1 ? '' : 's'}'),
              ],
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton.icon(
                  onPressed: () => context.go('/homecare/notes'),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
                  label: const Text('Back', style: TextStyle(color: Colors.white70)),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/homecare/notes/${widget.id}/edit'),
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  label: const Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            HcPanel(
              title: '${cat.label} note',
              subtitle: 'Recorded ${hcDateTime(n['recorded_at'])}'
                  '${n['created_at'] != null ? ' · Created ${hcDateTime(n['created_at'])}' : ''}',
              icon: cat.icon,
              color: cat.color,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Note', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                SelectableText(n['content']?.toString().isNotEmpty == true
                        ? n['content'].toString()
                        : 'No content.',
                    style: const TextStyle(fontSize: 14, height: 1.5)),
                if (vitals.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Vitals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in vitals.keys)
                        HcStatusChip(
                            label: '${k.toString().toUpperCase()}: ${vitals[k]}',
                            color: hcTeal),
                    ],
                  ),
                ],
              ]),
            ),
            HcPanel(
              title: 'Attachments',
              subtitle: null,
              icon: Icons.attach_file_rounded,
              color: hcTeal,
              child: attachments.isEmpty
                  ? Text('No files attached to this note.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
                  : Column(
                      children: [
                        for (final file in attachments) _AttachmentTile(file: file),
                      ],
                    ),
            ),
            HcPanel(
              title: 'People',
              subtitle: null,
              icon: Icons.people_alt_rounded,
              color: hcBlue,
              child: Column(children: [
                _personRow('Patient', n['patient_name']?.toString(), hcTeal),
                const SizedBox(height: 10),
                _personRow('Caregiver', n['caregiver_name']?.toString(), hcIndigo),
              ]),
            ),
            HcPanel(
              title: 'Timeline',
              subtitle: null,
              icon: Icons.schedule_rounded,
              color: hcSlate,
              child: Column(children: [
                _metaRow('Recorded at', hcDateTime(n['recorded_at']), Icons.event_rounded),
                const SizedBox(height: 8),
                _metaRow('Created at', hcDateTime(n['created_at']), Icons.history_rounded),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personRow(String label, String? name, Color color) {
    return Row(children: [
      HcAvatar(name: name, size: 40, color: color),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(name?.isNotEmpty == true ? name! : '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      ]),
    ]);
  }

  Widget _metaRow(String label, String value, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: hcTeal),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      ]),
    ]);
  }
}

class _AttachmentTile extends StatelessWidget {
  final Map file;
  const _AttachmentTile({required this.file});

  bool get _isImage {
    final t = (file['type'] ?? '').toString().toLowerCase();
    return t.startsWith('image/') || RegExp(r'\.(png|jpe?g|gif|webp|bmp|svg)$', caseSensitive: false)
        .hasMatch((file['name'] ?? '').toString());
  }

  bool get _isPdf {
    final t = (file['type'] ?? '').toString().toLowerCase();
    return t.contains('pdf') || (file['name'] ?? '').toString().toLowerCase().endsWith('.pdf');
  }

  ImageProvider? get _imageProvider {
    final src = file['data'] ?? file['url'] ?? file['src'];
    if (src is String && src.startsWith('data:')) {
      final comma = src.indexOf(',');
      final b64 = src.substring(comma + 1);
      return MemoryImage(base64Decode(b64));
    }
    if (src is String && src.startsWith('http')) return NetworkImage(src);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = file['name']?.toString() ?? 'attachment';
    final size = formatFileSize(file['size'] as num?);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: _isImage && _imageProvider != null
                ? Image(image: _imageProvider!, fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(_isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_outlined,
                        color: _isPdf ? hcRed : hcSlate, size: 24),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (size.isNotEmpty)
              Text(size, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () {
            final src = file['data'] ?? file['url'] ?? file['src'];
            if (src is String && src.isNotEmpty) {
              launchUrl(Uri.parse(src), mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Download'),
        ),
      ]),
    );
  }
}
