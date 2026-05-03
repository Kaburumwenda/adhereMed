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
import '../models/consultation_model.dart';
import '../repository/consultation_repository.dart';

class ConsultationListScreen extends ConsumerStatefulWidget {
  const ConsultationListScreen({super.key});

  @override
  ConsumerState<ConsultationListScreen> createState() =>
      _ConsultationListScreenState();
}

class _ConsultationListScreenState
    extends ConsumerState<ConsultationListScreen> {
  final _repo = ConsultationRepository();
  PaginatedResponse<Consultation>? _data;
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
                      'Consultations',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage patient consultations',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/consultations/new'),
                icon: const Icon(Icons.add),
                label: const Text('New Consultation'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SearchField(
            hintText: 'Search consultations...',
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
                            icon: Icons.medical_services_outlined,
                            title: 'No consultations found',
                            subtitle: 'Start a new consultation to get started.',
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
                                          DataColumn(label: Text('Doctor', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Chief Complaint', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                        ],
                                        rows: _data!.results.map((c) {
                                          final complaint =
                                              c.chiefComplaint ?? '-';
                                          return DataRow(cells: [
                                            DataCell(Text(c.patientName ?? 'ID: ${c.patientId}')),
                                            DataCell(Text(c.doctorName ?? 'ID: ${c.doctorId}')),
                                            DataCell(Text(
                                              complaint.length > 40
                                                  ? '${complaint.substring(0, 40)}...'
                                                  : complaint,
                                            )),
                                            DataCell(StatusBadge(status: c.status)),
                                            DataCell(Text(c.createdAt?.split('T').first ?? '-')),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                                onPressed: () => context.push('/consultations/${c.id}'),
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
