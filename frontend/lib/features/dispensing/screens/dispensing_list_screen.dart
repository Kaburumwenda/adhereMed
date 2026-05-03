import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../models/dispensing_model.dart';
import '../repository/dispensing_repository.dart';

class DispensingListScreen extends ConsumerStatefulWidget {
  const DispensingListScreen({super.key});

  @override
  ConsumerState<DispensingListScreen> createState() =>
      _DispensingListScreenState();
}

class _DispensingListScreenState extends ConsumerState<DispensingListScreen> {
  final _repo = DispensingRepository();
  PaginatedResponse<DispensingRecord>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String? _statusFilter;

  static const _statuses = ['pending', 'dispensed', 'partial', 'cancelled'];

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
      final result = await _repo.getRecords(
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'dispensed':
        return AppColors.success;
      case 'partial':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dispensing',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage medication dispensing records',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Search dispensing records...',
                  onChanged: (value) {
                    _search = value;
                    _page = 1;
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    hint: const Text('All Statuses'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Statuses')),
                      ..._statuses.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s[0].toUpperCase() + s.substring(1)))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _statusFilter = val;
                        _page = 1;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!,
                        onRetry: _loadData,
                      )
                    : _data == null || _filteredResults.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.medication_liquid_outlined,
                            title: 'No dispensing records found',
                            subtitle:
                                'Dispensing records will appear here.',
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
                                          DataColumn(
                                              label: Text('Patient',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Exchange ID',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Status',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Dispensed By',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Date',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Actions',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                        ],
                                        rows: _filteredResults
                                            .map(_buildRow)
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_data!.count > _data!.results.length)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton(
                                          onPressed: _data!.previous != null
                                              ? () {
                                                  _page--;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: Text('Page $_page'),
                                        ),
                                        TextButton(
                                          onPressed: _data!.next != null
                                              ? () {
                                                  _page++;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Next'),
                                        ),
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

  List<DispensingRecord> get _filteredResults {
    if (_data == null) return [];
    if (_statusFilter == null) return _data!.results;
    return _data!.results
        .where((r) => r.status.toLowerCase() == _statusFilter)
        .toList();
  }

  DataRow _buildRow(DispensingRecord r) {
    final color = _statusColor(r.status);
    return DataRow(cells: [
      DataCell(Text(r.patientName ?? '-')),
      DataCell(Text(r.prescriptionExchangeId != null
          ? '#${r.prescriptionExchangeId}'
          : '-')),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            r.status[0].toUpperCase() + r.status.substring(1),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      DataCell(Text(r.dispensedBy ?? '-')),
      DataCell(Text(_formatDate(r.createdAt))),
      DataCell(
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20),
          onPressed: () => context.push('/dispensing/${r.id}'),
          tooltip: 'View',
        ),
      ),
    ]);
  }
}
