import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../models/stock_model.dart';
import '../repository/inventory_repository.dart';

class UnitListScreen extends ConsumerStatefulWidget {
  const UnitListScreen({super.key});

  @override
  ConsumerState<UnitListScreen> createState() => _UnitListScreenState();
}

class _UnitListScreenState extends ConsumerState<UnitListScreen> {
  final _repo = InventoryRepository();
  List<Unit> _units = [];
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
      final result = await _repo.getUnits();
      setState(() {
        _units = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showFormDialog({Unit? unit}) async {
    final nameCtrl = TextEditingController(text: unit?.name ?? '');
    final abbrCtrl = TextEditingController(text: unit?.abbreviation ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(unit != null ? 'Edit Unit' : 'Add Unit'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Tablet, Bottle, Strip',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: abbrCtrl,
                decoration: const InputDecoration(
                  labelText: 'Abbreviation',
                  hintText: 'e.g. tab, btl, str',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'abbreviation': abbrCtrl.text.trim(),
                };
                if (unit != null) {
                  await _repo.updateUnit(unit.id, data);
                } else {
                  await _repo.createUnit(data);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text(unit != null ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteUnit(Unit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit'),
        content: Text('Delete "${unit.name}"? Stock items using this unit will be unlinked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _repo.deleteUnit(unit.id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      'Units',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage measurement units for medications',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showFormDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Unit'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!,
                        onRetry: _loadData,
                      )
                    : _units.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.straighten_outlined,
                            title: 'No units yet',
                            subtitle: 'Add a unit to describe medication measurements.',
                          )
                        : Card(
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(AppColors.background),
                                columns: const [
                                  DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w600))),
                                  DataColumn(label: Text('Abbreviation', style: TextStyle(fontWeight: FontWeight.w600))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                ],
                                rows: _units.map((u) {
                                  return DataRow(cells: [
                                    DataCell(Text(u.name)),
                                    DataCell(Text(u.abbreviation ?? '-')),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          tooltip: 'Edit',
                                          onPressed: () => _showFormDialog(unit: u),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                          tooltip: 'Delete',
                                          onPressed: () => _deleteUnit(u),
                                        ),
                                      ],
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
