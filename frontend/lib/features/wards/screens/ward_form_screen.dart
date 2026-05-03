import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_widget.dart';
import '../repository/ward_repository.dart';

class WardFormScreen extends ConsumerStatefulWidget {
  final String? wardId;
  const WardFormScreen({super.key, this.wardId});

  @override
  ConsumerState<WardFormScreen> createState() => _WardFormScreenState();
}

class _WardFormScreenState extends ConsumerState<WardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = WardRepository();

  final _nameCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _availableBedsCtrl = TextEditingController();
  final _dailyRateCtrl = TextEditingController();
  String _type = 'general';
  bool _isActive = true;
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.wardId != null;

  static const _wardTypes = [
    ('general', 'General'),
    ('icu', 'ICU'),
    ('maternity', 'Maternity'),
    ('pediatric', 'Pediatric'),
    ('surgical', 'Surgical'),
    ('emergency', 'Emergency'),
    ('private', 'Private'),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadWard();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _floorCtrl.dispose();
    _capacityCtrl.dispose();
    _availableBedsCtrl.dispose();
    _dailyRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWard() async {
    setState(() => _initialLoading = true);
    try {
      final w = await _repo.getWard(int.parse(widget.wardId!));
      _nameCtrl.text = w.name;
      _type = w.type;
      _floorCtrl.text = w.floor ?? '';
      _capacityCtrl.text = '${w.capacity}';
      _availableBedsCtrl.text = w.availableBeds != null ? '${w.availableBeds}' : '';
      _dailyRateCtrl.text = '${w.dailyRate}';
      _isActive = w.isActive;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading ward: $e')));
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = {
        'name': _nameCtrl.text,
        'type': _type,
        'floor': _floorCtrl.text,
        'capacity': int.tryParse(_capacityCtrl.text) ?? 0,
        if (_availableBedsCtrl.text.isNotEmpty)
          'available_beds': int.tryParse(_availableBedsCtrl.text) ?? 0,
        'daily_rate': double.tryParse(_dailyRateCtrl.text) ?? 0,
        'is_active': _isActive,
      };
      if (_isEditing) {
        await _repo.updateWard(int.parse(widget.wardId!), data);
      } else {
        await _repo.createWard(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? 'Ward updated' : 'Ward created')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const LoadingWidget();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop()),
                const SizedBox(width: 8),
                Text(_isEditing ? 'Edit Ward' : 'New Ward',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Ward Name'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: _wardTypes
                            .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                            .toList(),
                        onChanged: (v) => setState(() => _type = v ?? 'general'),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextFormField(
                        controller: _floorCtrl,
                        decoration: const InputDecoration(labelText: 'Floor'),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _capacityCtrl,
                        decoration: const InputDecoration(labelText: 'Capacity'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _availableBedsCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Available Beds'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final n = int.tryParse(v);
                          if (n == null || n < 0) return 'Invalid number';
                          final cap = int.tryParse(_capacityCtrl.text);
                          if (cap != null && n > cap) {
                            return 'Cannot exceed capacity';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _dailyRateCtrl,
                        decoration: const InputDecoration(labelText: 'Daily Rate'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: SwitchListTile(
                        title: const Text('Active'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEditing ? 'Update Ward' : 'Create Ward'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
