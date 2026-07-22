import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'hc_common.dart';
import 'note_helpers.dart';

final _notesProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/notes/', params: {'page_size': 1000});
});

final _caregiversProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/caregivers/', params: {'page_size': 500});
});

final _patientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/', params: {'page_size': 500});
});

/// Care notes index — mirrors the web /homecare/notes page.
class HomecareNotesScreen extends ConsumerStatefulWidget {
  const HomecareNotesScreen({super.key});

  @override
  ConsumerState<HomecareNotesScreen> createState() =>
      _HomecareNotesScreenState();
}

class _HomecareNotesScreenState extends ConsumerState<HomecareNotesScreen> {
  final _search = TextEditingController();
  int? _patientFilter;
  int? _caregiverFilter;
  String? _categoryFilter;
  DateTime? _dateFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map> _filtered(List<dynamic> rows) {
    var out = rows.cast<Map>().toList()
      ..sort((a, b) => (b['recorded_at'] ?? '').toString().compareTo((a['recorded_at'] ?? '').toString()));
    final q = _search.text.trim().toLowerCase();
    return out.where((n) {
      if (_patientFilter != null && n['patient'] != _patientFilter) return false;
      if (_caregiverFilter != null && n['caregiver'] != _caregiverFilter) return false;
      if (_categoryFilter != null && n['category'] != _categoryFilter) return false;
      if (_dateFilter != null &&
          (n['recorded_at'] ?? '').toString().substring(0, 10) !=
              '${_dateFilter!.year}-${_dateFilter!.month.toString().padLeft(2, '0')}-${_dateFilter!.day.toString().padLeft(2, '0')}') {
        return false;
      }
      if (q.isEmpty) return true;
      return (n['content'] ?? '').toString().toLowerCase().contains(q) ||
          (n['patient_name'] ?? '').toString().toLowerCase().contains(q) ||
          (n['caregiver_name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _delete(Map n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This care note will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: hcRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/homecare/notes/${n['id']}/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted'), backgroundColor: hcTeal));
      }
      ref.invalidate(_notesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to delete'), backgroundColor: hcRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(_notesProvider);
    final caregivers = ref.watch(_caregiversProvider);
    final patients = ref.watch(_patientsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-note',
        onPressed: () => context.go('/homecare/notes/new'),
        backgroundColor: hcTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
      body: HcAsyncBody(
        value: notes,
        onRefresh: () async => ref.refresh(_notesProvider.future),
        builder: (list) {
          final rows = _filtered(list);
          final cgCount = caregivers.valueOrNull?.length ?? 0;
          final ptCount = patients.valueOrNull?.length ?? 0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              HcHero(
                eyebrow: 'HOMECARE · DOCUMENTATION',
                title: 'Care Notes',
                subtitle: 'Shift notes, observations, incidents, and patient updates.',
                icon: Icons.note_alt_rounded,
                chips: [
                  HcHeroChip(icon: Icons.notes_rounded, label: '${rows.length} notes'),
                  HcHeroChip(icon: Icons.medical_services_rounded, label: '$cgCount caregivers'),
                  HcHeroChip(icon: Icons.person_rounded, label: '$ptCount patients'),
                ],
              ),
              _filters(caregivers, patients),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.note_alt_outlined, size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 10),
                      const Text('No notes found.'),
                    ]),
                  ),
                )
              else
                ...rows.map((n) => _NoteCard(
                      n: n,
                      onView: () => context.go('/homecare/notes/${n['id']}'),
                      onEdit: () => context.go('/homecare/notes/${n['id']}/edit'),
                      onDelete: () => _delete(n),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _filters(AsyncValue cgs, AsyncValue pts) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              hintText: 'Search notes…',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterDropdown<int?>(
                label: 'Patient',
                value: _patientFilter,
                items: (pts.valueOrNull as List? ?? [])
                    .cast<Map>()
                    .map((p) => _Opt(p['id'] as int?,
                        (p['patient_name'] ?? 'Patient #${p['id']}').toString()))
                    .toList(),
                onChanged: (v) => setState(() => _patientFilter = v),
              ),
              _FilterDropdown<int?>(
                label: 'Caregiver',
                value: _caregiverFilter,
                items: (cgs.valueOrNull as List? ?? [])
                    .cast<Map>()
                    .map((c) => _Opt(c['id'] as int?,
                        (c['user']?['full_name'] ?? c['user']?['email'] ?? '#${c['id']}')
                            .toString()))
                    .toList(),
                onChanged: (v) => setState(() => _caregiverFilter = v),
              ),
              _FilterDropdown<String?>(
                label: 'Category',
                value: _categoryFilter,
                items: noteCategories.map((c) => _Opt(c.value, c.label)).toList(),
                onChanged: (v) => setState(() => _categoryFilter = v),
              ),
              FilterChip(
                label: Text(_dateFilter == null
                    ? 'Date'
                    : '${_dateFilter!.day}/${_dateFilter!.month}/${_dateFilter!.year}'),
                avatar: const Icon(Icons.event_rounded, size: 16),
                selected: _dateFilter != null,
                onSelected: (_) async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _dateFilter = d);
                },
                onDeleted: _dateFilter == null
                    ? null
                    : () => setState(() => _dateFilter = null),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// A single note card — mirrors the web table row.
class _NoteCard extends StatelessWidget {
  final Map n;
  final VoidCallback onView, onEdit, onDelete;
  const _NoteCard({required this.n, required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cat = noteCategoryMeta(n['category']?.toString());
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              HcAvatar(name: n['patient_name']?.toString(), size: 32, color: hcTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n['patient_name']?.toString() ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(hcDateTime(n['recorded_at']),
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
              HcStatusChip(label: cat.label, color: cat.color, icon: cat.icon),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.medical_services_rounded, size: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(n['caregiver_name']?.toString().isEmpty == true
                      ? '—'
                      : n['caregiver_name'].toString(),
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            Text(noteContentPreview(n['content']),
                maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                  tooltip: 'View',
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: hcTeal)),
              IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18, color: hcBlue)),
              IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: hcRed)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Opt<T> {
  final T value;
  final String label;
  const _Opt(this.value, this.label);
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<_Opt<T>> items;
  final ValueChanged<T?> onChanged;
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T?>(
        underline: const SizedBox(),
        isDense: true,
        value: value,
        hint: Text(label, style: const TextStyle(fontSize: 13)),
        items: [
          DropdownMenuItem<T?>(value: null, child: Text(label)),
          ...items.map((o) => DropdownMenuItem<T?>(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
