import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../repository/department_repository.dart';

class DepartmentFormScreen extends ConsumerStatefulWidget {
  final String? departmentId;

  const DepartmentFormScreen({super.key, this.departmentId});

  @override
  ConsumerState<DepartmentFormScreen> createState() =>
      _DepartmentFormScreenState();
}

class _DepartmentFormScreenState
    extends ConsumerState<DepartmentFormScreen> {
  final _repo = DepartmentRepository();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _isActive = true;
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.departmentId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _initialLoading = true);
    try {
      final d = await _repo.getDetail(int.parse(widget.departmentId!));
      _nameCtrl.text = d.name;
      _descriptionCtrl.text = d.description ?? '';
      _isActive = d.isActive;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load department: $e')),
        );
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'is_active': _isActive,
    };

    try {
      if (_isEditing) {
        await _repo.update(int.parse(widget.departmentId!), data);
      } else {
        await _repo.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Department ${_isEditing ? 'updated' : 'created'} successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
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
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Edit Department' : 'Add Department',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Department Name'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active'),
                      subtitle: Text(
                        _isActive
                            ? 'Department is active'
                            : 'Department is inactive',
                        style:
                            TextStyle(color: AppColors.textSecondary),
                      ),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(
                    _isEditing ? 'Update Department' : 'Create Department'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
