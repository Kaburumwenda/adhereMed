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
import '../models/appointment_model.dart';
import '../repository/appointment_repository.dart';

class AppointmentListScreen extends ConsumerStatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  ConsumerState<AppointmentListScreen> createState() =>
      _AppointmentListScreenState();
}

class _AppointmentListScreenState
    extends ConsumerState<AppointmentListScreen> {
  final _repo = AppointmentRepository();
  PaginatedResponse<Appointment>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String _statusFilter = 'all';

  static const _statuses = [
    'all',
    'scheduled',
    'confirmed',
    'in_progress',
    'completed',
    'cancelled',
  ];

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
      String? search = _search.isEmpty ? null : _search;
      if (_statusFilter != 'all') {
        search = search != null ? '$search&status=$_statusFilter' : null;
      }
      final result = await _repo.getList(page: _page, search: search);
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
                      'Appointments',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage appointment schedules',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/appointments/new'),
                icon: const Icon(Icons.add),
                label: const Text('Book Appointment'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Search appointments...',
                  onChanged: (value) {
                    _search = value;
                    _page = 1;
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  decoration:
                      const InputDecoration(labelText: 'Status', isDense: true),
                  items: _statuses
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s == 'all'
                                ? 'All Statuses'
                                : s.replaceAll('_', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    _statusFilter = v ?? 'all';
                    _page = 1;
                    _loadData();
                  },
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
                        message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.calendar_today_outlined,
                            title: 'No appointments found',
                            subtitle: 'Book a new appointment to get started.',
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
                                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Patient', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Doctor', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                        ],
                                        rows: _data!.results.map((a) {
                                          return DataRow(cells: [
                                            DataCell(Text(a.date)),
                                            DataCell(Text(a.startTime)),
                                            DataCell(Text(a.patientName ?? 'ID: ${a.patientId}')),
                                            DataCell(Text(a.doctorName ?? 'ID: ${a.doctorId}')),
                                            DataCell(Text(a.departmentName ?? '-')),
                                            DataCell(StatusBadge(status: a.status)),
                                            DataCell(Text((a.appointmentType ?? '-').replaceAll('_', ' '))),
                                            DataCell(Row(children: [
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                                onPressed: () => context.push('/appointments/${a.id}'),
                                                tooltip: 'View',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 20),
                                                onPressed: () => context.push('/appointments/${a.id}/edit'),
                                                tooltip: 'Edit',
                                              ),
                                            ])),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                _pagination(),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _pagination() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_data!.count} total records',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
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
                style: const TextStyle(fontWeight: FontWeight.w500)),
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
    );
  }
}
