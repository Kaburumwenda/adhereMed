import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../models/paginated_response.dart';
import '../theme.dart';
import 'empty_state_widget.dart';
import 'error_widget.dart';
import 'loading_widget.dart';
import 'search_field.dart';

class DataTablePage<T> extends StatefulWidget {
  final String title;
  final List<DataColumn> columns;
  final Future<PaginatedResponse<T>> Function(int page, String? search) fetchData;
  final DataRow Function(T item) buildRow;
  final VoidCallback? onAdd;
  final String addLabel;

  const DataTablePage({
    super.key,
    required this.title,
    required this.columns,
    required this.fetchData,
    required this.buildRow,
    this.onAdd,
    this.addLabel = 'Add',
  });

  @override
  State<DataTablePage<T>> createState() => _DataTablePageState<T>();
}

class _DataTablePageState<T> extends State<DataTablePage<T>> {
  int _currentPage = 1;
  String? _search;
  PaginatedResponse<T>? _data;
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
      final data = await widget.fetchData(_currentPage, _search);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onSearch(String value) {
    _search = value;
    _currentPage = 1;
    _loadData();
  }

  void _goToPage(int page) {
    _currentPage = page;
    _loadData();
  }

  int get _totalPages {
    if (_data == null || _data!.count == 0) return 1;
    return (_data!.count / (_data!.results.length.clamp(1, _data!.count))).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (widget.onAdd != null)
                FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(widget.addLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Search
          SizedBox(
            width: 360,
            child: SearchField(
              onChanged: _onSearch,
              hintText: 'Search ${widget.title.toLowerCase()}...',
            ),
          ),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Card(
              child: _buildContent(),
            ),
          ),

          // Pagination
          if (_data != null && !_loading) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    if (_data == null || _data!.results.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.inbox_rounded,
        title: 'No ${widget.title.toLowerCase()} found',
        subtitle: _search != null && _search!.isNotEmpty
            ? 'Try adjusting your search terms'
            : null,
      );
    }

    return DataTable2(
      columnSpacing: 16,
      horizontalMargin: 16,
      minWidth: 600,
      headingRowColor: WidgetStateProperty.all(AppColors.background),
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
      dataTextStyle: TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      columns: widget.columns,
      rows: _data!.results.map(widget.buildRow).toList(),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_data!.count} total records',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _data!.previous != null
                    ? () => _goToPage(_currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous page',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $_currentPage of $_totalPages',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _data!.next != null
                    ? () => _goToPage(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
