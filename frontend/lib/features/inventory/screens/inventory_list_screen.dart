import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../models/stock_model.dart';
import '../repository/inventory_repository.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _repo = InventoryRepository();
  PaginatedResponse<MedicationStock>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  bool _lowStockOnly = false;
  int? _selectedCategory;
  List<Category> _categories = [];

  bool _exporting = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadData();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = _lowStockOnly
          ? await _repo.getLowStock(
              page: _page, search: _search.isEmpty ? null : _search)
          : await _repo.getStocks(
              page: _page,
              search: _search.isEmpty ? null : _search,
              category: _selectedCategory);
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

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
  }

  int get _lowStockCount =>
      _data?.results.where((s) => s.isLowStock == true).length ?? 0;
  int get _outOfStockCount =>
      _data?.results.where((s) => (s.totalQuantity ?? 0) == 0).length ?? 0;

  Future<void> _exportStocks(String format) async {
    setState(() => _exporting = true);
    try {
      final bytes = await _repo.exportStocks(format: format);
      final ext = format == 'excel' ? 'xlsx' : format;
      final now = DateTime.now();
      final fname = 'inventory_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.$ext';
      if (kIsWeb) {
        // Web: not supported via path_provider; show snack
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Web download: open the export URL directly from your browser.')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fname');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Inventory Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importStocks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access file path.')),
        );
      }
      return;
    }

    setState(() => _importing = true);
    try {
      final summary = await _repo.importStocks(file.path!, file.name);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => _ImportResultDialog(summary: summary),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage medication stock levels',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/inventory/categories'),
                icon: const Icon(Icons.category_outlined, size: 16),
                label: const Text('Categories'),
              ),
              const SizedBox(width: 10),
              // Export menu
              _exporting
                  ? const SizedBox(
                      width: 32, height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : PopupMenuButton<String>(
                      onSelected: _exportStocks,
                      tooltip: 'Export',
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart_outlined, size: 18), SizedBox(width: 8), Text('Export CSV')])),
                        PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.grid_on_outlined, size: 18), SizedBox(width: 8), Text('Export Excel')])),
                        PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18), SizedBox(width: 8), Text('Export PDF')])),
                      ],
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Export'),
                      ),
                    ),
              const SizedBox(width: 10),
              // Import button
              _importing
                  ? const SizedBox(
                      width: 32, height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : OutlinedButton.icon(
                      onPressed: _importStocks,
                      icon: const Icon(Icons.upload_outlined, size: 16),
                      label: const Text('Import'),
                    ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => context.push('/inventory/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Stock Item'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Summary stat cards ───────────────────────────────────────────────
          if (!_loading && _data != null)
            _SummaryRow(
              total: _data!.count,
              lowStock: _lowStockCount,
              outOfStock: _outOfStockCount,
            ),
          if (!_loading && _data != null) const SizedBox(height: 16),

          // ── Filter bar ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    hintText: 'Search medications...',
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
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text('All Categories')),
                      ..._categories.map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedCategory = v;
                        _page = 1;
                      });
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  avatar: Icon(Icons.warning_amber_rounded,
                      size: 14,
                      color: _lowStockOnly
                          ? AppColors.error
                          : AppColors.textSecondary),
                  label: const Text('Low Stock Only'),
                  selected: _lowStockOnly,
                  onSelected: (val) {
                    setState(() {
                      _lowStockOnly = val;
                      _page = 1;
                    });
                    _loadData();
                  },
                  selectedColor: AppColors.error.withValues(alpha: 0.12),
                  checkmarkColor: AppColors.error,
                  labelStyle: TextStyle(
                    color: _lowStockOnly
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontWeight: _lowStockOnly
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Table ────────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!,
                        onRetry: _loadData,
                      )
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.inventory_2_outlined,
                            title: 'No stock items found',
                            subtitle:
                                'Add a stock item to get started or clear your filters.',
                          )
                        : _StockTable(
                            stocks: _data!,
                            formatCurrency: _formatCurrency,
                            onView: (id) => context.push('/inventory/$id'),
                            onEdit: (id) =>
                                context.push('/inventory/$id/edit'),
                            page: _page,
                            onPrev: _data!.previous != null
                                ? () {
                                    _page--;
                                    _loadData();
                                  }
                                : null,
                            onNext: _data!.next != null
                                ? () {
                                    _page++;
                                    _loadData();
                                  }
                                : null,
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int total;
  final int lowStock;
  final int outOfStock;
  const _SummaryRow(
      {required this.total,
      required this.lowStock,
      required this.outOfStock});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(
          icon: Icons.inventory_2_outlined,
          label: 'Total Items',
          value: '$total',
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _Stat(
          icon: Icons.warning_amber_rounded,
          label: 'Low Stock',
          value: '$lowStock',
          color: AppColors.warning,
        ),
        const SizedBox(width: 12),
        _Stat(
          icon: Icons.remove_shopping_cart_outlined,
          label: 'Out of Stock',
          value: '$outOfStock',
          color: AppColors.error,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Stat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stock Table ──────────────────────────────────────────────────────────────

class _StockTable extends StatelessWidget {
  final PaginatedResponse<MedicationStock> stocks;
  final String Function(double) formatCurrency;
  final void Function(int) onView;
  final void Function(int) onEdit;
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _StockTable({
    required this.stocks,
    required this.formatCurrency,
    required this.onView,
    required this.onEdit,
    required this.page,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: AppColors.border)),
            ),
            child: _TableHeader(),
          ),
          // Table rows
          Expanded(
            child: ListView.separated(
              itemCount: stocks.results.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.divider),
              itemBuilder: (ctx, i) => _StockRow(
                stock: stocks.results[i],
                formatCurrency: formatCurrency,
                onView: () => onView(stocks.results[i].id),
                onEdit: () => onEdit(stocks.results[i].id),
              ),
            ),
          ),
          // Pagination
          if (stocks.count > stocks.results.length)
            _Pagination(page: page, onPrev: onPrev, onNext: onNext),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
            flex: 4,
            child: Text('MEDICATION', style: style)),
        Expanded(
            flex: 2,
            child: Text('CATEGORY', style: style)),
        Expanded(
            flex: 2,
            child: Text('SELL PRICE', style: style)),
        Expanded(
            flex: 2,
            child: Text('QUANTITY', style: style)),
        Expanded(
            flex: 2,
            child: Text('REORDER LVL', style: style)),
        Expanded(
            flex: 2,
            child: Text('STATUS', style: style)),
        SizedBox(width: 88, child: Text('', style: style)),
      ]),
    );
  }
}

class _StockRow extends StatefulWidget {
  final MedicationStock stock;
  final String Function(double) formatCurrency;
  final VoidCallback onView;
  final VoidCallback onEdit;
  const _StockRow({
    required this.stock,
    required this.formatCurrency,
    required this.onView,
    required this.onEdit,
  });

  @override
  State<_StockRow> createState() => _StockRowState();
}

class _StockRowState extends State<_StockRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final isLow = stock.isLowStock == true;
    final isOut = (stock.totalQuantity ?? 0) == 0;
    final qty = stock.totalQuantity ?? 0;

    Color rowBg;
    if (isOut) {
      rowBg = _hovered
          ? AppColors.error.withValues(alpha: 0.08)
          : AppColors.error.withValues(alpha: 0.04);
    } else if (isLow) {
      rowBg = _hovered
          ? AppColors.warning.withValues(alpha: 0.08)
          : AppColors.warning.withValues(alpha: 0.03);
    } else {
      rowBg = _hovered
          ? AppColors.primary.withValues(alpha: 0.04)
          : Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: rowBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Medication name + location
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.medicationName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (stock.locationInStore != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          stock.locationInStore!,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Category
            Expanded(
              flex: 2,
              child: Text(
                stock.categoryName ?? '—',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            // Sell price
            Expanded(
              flex: 2,
              child: Text(
                widget.formatCurrency(stock.sellingPrice),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            // Quantity
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Text(
                    '$qty',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOut
                          ? AppColors.error
                          : isLow
                              ? AppColors.warning
                              : AppColors.textPrimary,
                    ),
                  ),
                  if (stock.unitAbbreviation != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      stock.unitAbbreviation!,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            // Reorder level
            Expanded(
              flex: 2,
              child: Text(
                '${stock.reorderLevel}',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            // Status badge
            Expanded(
              flex: 2,
              child: _StatusBadge(isOut: isOut, isLow: isLow),
            ),
            // Actions
            SizedBox(
              width: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionIcon(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View Details',
                    onTap: widget.onView,
                  ),
                  const SizedBox(width: 4),
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onTap: widget.onEdit,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOut;
  final bool isLow;
  const _StatusBadge({required this.isOut, required this.isLow});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;
    if (isOut) {
      bg = AppColors.error.withValues(alpha: 0.1);
      fg = AppColors.error;
      icon = Icons.remove_circle_outline;
      label = 'Out of Stock';
    } else if (isLow) {
      bg = AppColors.warning.withValues(alpha: 0.12);
      fg = AppColors.warning;
      icon = Icons.warning_amber_rounded;
      label = 'Low Stock';
    } else {
      bg = AppColors.success.withValues(alpha: 0.1);
      fg = AppColors.success;
      icon = Icons.check_circle_outline;
      label = 'In Stock';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  const _ActionIcon(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 18,
              color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pagination(
      {required this.page, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Previous'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Page $page',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Next'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8)),
          ),
        ],
      ),
    );
  }
}

class _ImportResultDialog extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _ImportResultDialog({required this.summary});

  @override
  Widget build(BuildContext context) {
    final created = summary['created'] ?? 0;
    final updated = summary['updated'] ?? 0;
    final errors = summary['errors'] ?? 0;
    final errorDetails = (summary['error_details'] as List?)?.cast<String>() ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          const Text('Import Complete'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ResultChip(label: 'Created', value: created, color: AppColors.success),
                const SizedBox(width: 8),
                _ResultChip(label: 'Updated', value: updated, color: AppColors.primary),
                const SizedBox(width: 8),
                _ResultChip(label: 'Errors', value: errors, color: errors > 0 ? AppColors.error : AppColors.textSecondary),
              ],
            ),
            if (errorDetails.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Issues:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: errorDetails.length,
                  itemBuilder: (_, i) => Text(
                    '• ${errorDetails[i]}',
                    style: TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ResultChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
