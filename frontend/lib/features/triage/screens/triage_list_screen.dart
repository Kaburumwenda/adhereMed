import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/triage_model.dart';
import '../repository/triage_repository.dart';

class TriageListScreen extends ConsumerStatefulWidget {
  const TriageListScreen({super.key});

  @override
  ConsumerState<TriageListScreen> createState() => _TriageListScreenState();
}

class _TriageListScreenState extends ConsumerState<TriageListScreen> {
  final _repo = TriageRepository();
  PaginatedResponse<TriageRecord>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';

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
      final result = await _repo.getList(
        page: _page,
        search: _search.isEmpty ? null : _search,
      );
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _categoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'emergency':
        return AppColors.error;
      case 'urgent':
        return AppColors.warning;
      case 'standard':
        return AppColors.primary;
      case 'non_urgent':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
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
                      'Triage',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patient vitals and triage records',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/triage/new'),
                icon: const Icon(Icons.add),
                label: const Text('Record Vitals'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SearchField(
            hintText: 'Search triage records...',
            onChanged: (value) {
              _search = value;
              _page = 1;
              _loadData();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.monitor_heart_outlined,
                            title: 'No triage records found',
                            subtitle: 'Record patient vitals to get started.',
                          )
                        : Card(
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                                AppColors.background),
                                        columns: const [
                                          DataColumn(label: Text('Patient', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Temp (°C)', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                                          DataColumn(label: Text('BP', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Pulse', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                                          DataColumn(label: Text('O₂ Sat (%)', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                        ],
                                        rows: _data!.results.map((t) {
                                          final bp = t.systolicBp != null && t.diastolicBp != null
                                              ? '${t.systolicBp}/${t.diastolicBp}'
                                              : '-';
                                          return DataRow(cells: [
                                            DataCell(Text(t.patientName ?? 'ID: ${t.patientId}')),
                                            DataCell(StatusBadge(
                                              status: t.triageCategory ?? '-',
                                              overrideColor: _categoryColor(t.triageCategory),
                                            )),
                                            DataCell(Text(t.temperature?.toStringAsFixed(1) ?? '-')),
                                            DataCell(Text(bp)),
                                            DataCell(Text(t.pulseRate?.toString() ?? '-')),
                                            DataCell(Text(t.oxygenSaturation?.toStringAsFixed(0) ?? '-')),
                                            DataCell(Text(t.createdAt?.split('T').first ?? '-')),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                                onPressed: () => context.push('/triage/${t.id}'),
                                                tooltip: 'View',
                                              ),
                                            ),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${_data!.count} total records',
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13)),
                                      Row(children: [
                                        TextButton(
                                          onPressed: _data!.previous != null
                                              ? () {
                                                  _page--;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Page $_page',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: _data!.next != null
                                              ? () {
                                                  _page++;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Next'),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
