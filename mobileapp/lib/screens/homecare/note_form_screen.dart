import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import 'hc_common.dart';
import 'note_helpers.dart';

final _patientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/', params: {'page_size': 500});
});

final _caregiversProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/caregivers/', params: {'page_size': 500});
});

/// New / edit care note — mirrors the web NoteForm component.
class HomecareNoteFormScreen extends ConsumerStatefulWidget {
  final int? noteId;
  final int? presetPatientId;
  const HomecareNoteFormScreen({super.key, this.noteId, this.presetPatientId});

  @override
  ConsumerState<HomecareNoteFormScreen> createState() =>
      _HomecareNoteFormScreenState();
}

class _HomecareNoteFormScreenState extends ConsumerState<HomecareNoteFormScreen> {
  int? _patient;
  int? _caregiver;
  String? _category;
  DateTime? _recordedDate;
  TimeOfDay? _recordedTime;
  final _content = TextEditingController();
  final List<Map> _existingFiles = [];
  final List<Map> _newFiles = []; // {name, type, size, data}
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.noteId != null;

  @override
  void initState() {
    super.initState();
    _patient = widget.presetPatientId;
    _loadNote();
  }

  Future<void> _loadNote() async {
    if (widget.noteId == null) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/notes/${widget.noteId}/');
      final d = res.data is Map ? res.data as Map : <String, dynamic>{};
      final dt = hcSplitDateTime(d['recorded_at']);
      setState(() {
        _patient = d['patient'] as int?;
        _caregiver = d['caregiver'] as int?;
        _category = d['category']?.toString();
        _content.text = d['content']?.toString() ?? '';
        _recordedDate = DateTime.tryParse('${dt.date}T00:00');
        _recordedTime = dt.time.isNotEmpty ? TimeOfDay.fromDateTime(DateTime.parse('2020-01-01T${dt.time}:00')) : null;
        _existingFiles
            .addAll((d['attached_files'] as List? ?? []).cast<Map>());
      });
    } catch (_) {
      setState(() => _error = 'Could not load note.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, imageQuality: 85);
      if (f == null) return;
      final bytes = await File(f.path).readAsBytes();
      final name = f.name;
      final data = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() => _newFiles.add({'name': name, 'type': 'image/jpeg', 'size': bytes.length, 'data': data}));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not pick image.'), backgroundColor: hcRed));
      }
    }
  }

  Future<void> _save() async {
    if (_patient == null || _caregiver == null || _category == null || _content.text.trim().isEmpty) {
      setState(() => _error = 'Patient, caregiver, category, and note are required.');
      return;
    }
    if (_recordedDate == null) {
      setState(() => _error = 'Please pick the date the event happened.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final t = _recordedTime ?? TimeOfDay.fromDateTime(DateTime.now());
      final dt = DateTime(
        _recordedDate!.year,
        _recordedDate!.month,
        _recordedDate!.day,
        t.hour,
        t.minute,
      );
      final payload = {
        'patient': _patient,
        'caregiver': _caregiver,
        'category': _category,
        'content': _content.text,
        'recorded_at': dt.toUtc().toIso8601String(),
        'attached_files': [..._existingFiles, ..._newFiles],
        'vitals': <String, dynamic>{},
      };
      if (_editing) {
        await dio.patch('/homecare/notes/${widget.noteId}/', data: payload);
      } else {
        await dio.post('/homecare/notes/', data: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_editing ? 'Note updated' : 'Note created'),
            backgroundColor: hcTeal));
        context.go('/homecare/notes');
      }
    } catch (e) {
      String msg = 'Could not save note.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data.isNotEmpty) {
          final first = data.entries.first;
          msg = '${first.key}: ${first.value is List ? (first.value as List).first : first.value}';
        } else if (data is String) {
          msg = data;
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _saving = false;
          _error = msg;
        });
      }
    }
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(_patientsProvider);
    final caregivers = ref.watch(_caregiversProvider);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          HcHero(
            eyebrow: 'HOMECARE · DOCUMENTATION',
            title: _editing ? 'Edit care note' : 'New care note',
            subtitle: _editing
                ? 'Update an existing shift note, observation or incident.'
                : 'Document a new shift note, observation, vitals reading or incident.',
            icon: Icons.note_alt_rounded,
            trailing: TextButton.icon(
              onPressed: () => context.go('/homecare/notes'),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
              label: const Text('Back', style: TextStyle(color: Colors.white70)),
            ),
          ),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Note details',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 12),
                      patients.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Could not load patients'),
                        data: (list) => DropdownButtonFormField<int>(
                          initialValue: _patient,
                          decoration: const InputDecoration(labelText: 'Patient *', prefixIcon: Icon(Icons.person)),
                          items: list
                              .cast<Map>()
                              .map((p) => DropdownMenuItem<int>(
                                    value: p['id'] as int,
                                    child: Text((p['patient_name'] ?? 'Patient #${p['id']}').toString(),
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _patient = v),
                        ),
                      ),
                      const SizedBox(height: 10),
                      caregivers.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Could not load caregivers'),
                        data: (list) => DropdownButtonFormField<int>(
                          initialValue: _caregiver,
                          decoration: const InputDecoration(labelText: 'Caregiver *', prefixIcon: Icon(Icons.medical_services_rounded)),
                          items: list
                              .cast<Map>()
                              .map((c) => DropdownMenuItem<int>(
                                    value: c['id'] as int,
                                    child: Text(
                                        (c['user']?['full_name'] ?? c['user']?['email'] ?? '#${c['id']}')
                                            .toString(),
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _caregiver = v),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: 'Category *'),
                        items: noteCategories
                            .map((c) => DropdownMenuItem<String>(
                                  value: c.value,
                                  child: Row(children: [
                                    Icon(c.icon, color: c.color, size: 18),
                                    const SizedBox(width: 8),
                                    Text(c.label),
                                  ]),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _recordedDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setState(() => _recordedDate = d);
                            },
                            icon: const Icon(Icons.calendar_today_rounded, size: 18),
                            label: Text(_recordedDate == null
                                ? 'Recorded date *'
                                : '${_recordedDate!.day}/${_recordedDate!.month}/${_recordedDate!.year}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _recordedTime ?? TimeOfDay.now(),
                              );
                              if (t != null) setState(() => _recordedTime = t);
                            },
                            icon: const Icon(Icons.schedule_rounded, size: 18),
                            label: Text(_recordedTime == null
                                ? 'Time'
                                : _recordedTime!.format(context)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('Should reflect when the event happened, not when you typed it.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      const Text('Note *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _content,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Write the note here…',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(width: 8),
                        HcStatusChip(label: 'Optional', color: hcSlate),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_rounded, size: 18),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ]),
                      if (_existingFiles.isNotEmpty || _newFiles.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < _existingFiles.length; i++)
                              _attachChip(_existingFiles[i], () => setState(() => _existingFiles.removeAt(i))),
                            for (var i = 0; i < _newFiles.length; i++)
                              _attachChip(_newFiles[i], () => setState(() => _newFiles.removeAt(i))),
                          ],
                        ),
                      ],
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: hcRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!, style: TextStyle(color: hcRed, fontSize: 12.5)),
                        ),
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: () => context.go('/homecare/notes'), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(backgroundColor: hcTeal),
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(_editing ? 'Save changes' : 'Create note'),
                        ),
                      ]),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachChip(Map f, VoidCallback onRemove) {
    return Chip(
      avatar: const Icon(Icons.attach_file_rounded, size: 16),
      label: Text('${f['name'] ?? 'attachment'}${f['size'] != null ? ' (${formatFileSize(f['size'] as num)})' : ''}',
          style: const TextStyle(fontSize: 12)),
      onDeleted: onRemove,
    );
  }
}
