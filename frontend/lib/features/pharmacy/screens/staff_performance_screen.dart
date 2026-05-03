import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../pos/models/pos_transaction_model.dart';
import '../../pos/repository/pos_repository.dart';

class StaffPerformanceScreen extends ConsumerStatefulWidget {
  const StaffPerformanceScreen({super.key});

  @override
  ConsumerState<StaffPerformanceScreen> createState() =>
      _StaffPerformanceScreenState();
}

class _StaffPerformanceScreenState
    extends ConsumerState<StaffPerformanceScreen> {
  final _repo = POSRepository();

  List<_StaffStats>? _stats;
  bool _loading = true;
  String? _error;
  _SortBy _sortBy = _SortBy.revenue;
  String _period = '30'; // days

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
      // Load up to 500 recent transactions to aggregate
      final result =
          await _repo.getTransactions(page: 1, pageSize: 500);
      if (mounted) {
        setState(() {
          _stats = _aggregate(result.results);
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

  List<_StaffStats> _aggregate(List<POSTransaction> txs) {
    final cutoff = DateTime.now()
        .subtract(Duration(days: int.parse(_period)));
    final filtered = txs.where((t) {
      if (t.createdAt == null) return false;
      try {
        return DateTime.parse(t.createdAt!).isAfter(cutoff);
      } catch (_) {
        return false;
      }
    }).toList();

    final map = <String, _StaffStats>{};
    for (final t in filtered) {
      final name = t.servedBy ?? 'Unknown';
      if (!map.containsKey(name)) {
        map[name] = _StaffStats(name: name);
      }
      map[name]!.transactions++;
      map[name]!.revenue += t.totalAmount;
      map[name]!.discount += t.discount;
      map[name]!.items += t.items.length;
    }

    final list = map.values.toList();
    switch (_sortBy) {
      case _SortBy.revenue:
        list.sort((a, b) => b.revenue.compareTo(a.revenue));
      case _SortBy.transactions:
        list.sort((a, b) => b.transactions.compareTo(a.transactions));
      case _SortBy.items:
        list.sort((a, b) => b.items.compareTo(a.items));
    }
    return list;
  }

  String _formatCurrency(double amount) =>
      'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Staff Performance',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    'Sales & dispensing metrics by staff member',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh'),
            ],
          ),
          const SizedBox(height: 16),

          // Filters
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Period:', style: TextStyle(color: AppColors.textSecondary)),
              ...['7', '30', '90'].map((d) => ChoiceChip(
                    label: Text('$d days'),
                    selected: _period == d,
                    onSelected: (_) => setState(() {
                      _period = d;
                      if (_stats != null) {
                        // re-aggregate from cached data
                        _loadData();
                      }
                    }),
                  )),
              const SizedBox(width: 12),
              Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
              ..._SortBy.values.map((s) => ChoiceChip(
                    label: Text(s.label),
                    selected: _sortBy == s,
                    onSelected: (_) => setState(() {
                      _sortBy = s;
                      if (_stats != null) {
                        _stats!.sort((a, b) {
                          switch (s) {
                            case _SortBy.revenue:
                              return b.revenue.compareTo(a.revenue);
                            case _SortBy.transactions:
                              return b.transactions.compareTo(a.transactions);
                            case _SortBy.items:
                              return b.items.compareTo(a.items);
                          }
                        });
                      }
                    }),
                  )),
            ],
          ),
          const SizedBox(height: 16),

          // Summary row
          if (!_loading && _stats != null && _stats!.isNotEmpty)
            _buildSummaryRow(),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: LoadingWidget())
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : _stats == null || _stats!.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.people_outline,
                            title: 'No Data',
                            subtitle:
                                'No transactions found for this period.',
                          )
                        : _buildStaffList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final totalRevenue =
        _stats!.fold<double>(0, (s, e) => s + e.revenue);
    final totalTx = _stats!.fold<int>(0, (s, e) => s + e.transactions);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth > 600
          ? (constraints.maxWidth - 32) / 3
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          SizedBox(
            width: w,
            child: _MiniStatCard(
              icon: Icons.attach_money,
              label: 'Total Revenue',
              value: _formatCurrency(totalRevenue),
              color: AppColors.success,
            ),
          ),
          SizedBox(
            width: w,
            child: _MiniStatCard(
              icon: Icons.receipt_long,
              label: 'Transactions',
              value: '$totalTx',
              color: AppColors.primary,
            ),
          ),
          SizedBox(
            width: w,
            child: _MiniStatCard(
              icon: Icons.people,
              label: 'Active Staff',
              value: '${_stats!.length}',
              color: AppColors.secondary,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildStaffList() {
    final maxRevenue =
        _stats!.isEmpty ? 1.0 : _stats!.first.revenue.clamp(1, double.infinity);

    return ListView.separated(
      itemCount: _stats!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final staff = _stats![i];
        final revenuePct = (staff.revenue / maxRevenue).clamp(0.0, 1.0);
        final rank = i + 1;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  // Rank badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: rank <= 3
                          ? _rankColor(rank).withValues(alpha: 0.15)
                          : AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: rank <= 3
                              ? _rankColor(rank)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        staff.name
                            .trim()
                            .split(' ')
                            .take(2)
                            .map((w) =>
                                w.isNotEmpty ? w[0].toUpperCase() : '')
                            .join(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        Text(
                          '${staff.transactions} transactions · ${staff.items} items sold',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(staff.revenue),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.success),
                      ),
                      if (staff.discount > 0)
                        Text(
                          'Discounts: ${_formatCurrency(staff.discount)}',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11),
                        ),
                    ],
                  ),
                ]),
                const SizedBox(height: 10),
                // Revenue bar
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: revenuePct,
                        minHeight: 6,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            rank <= 3
                                ? _rankColor(rank)
                                : AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(revenuePct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // gold
    if (rank == 2) return const Color(0xFFC0C0C0); // silver
    return const Color(0xFFCD7F32); // bronze
  }
}

// ─── Staff aggregation model ─────────────────────────────────────────────────

class _StaffStats {
  final String name;
  int transactions = 0;
  double revenue = 0;
  double discount = 0;
  int items = 0;

  _StaffStats({required this.name});
}

enum _SortBy {
  revenue,
  transactions,
  items;

  String get label {
    switch (this) {
      case _SortBy.revenue:
        return 'Revenue';
      case _SortBy.transactions:
        return 'Transactions';
      case _SortBy.items:
        return 'Items Sold';
    }
  }
}

// ─── Mini Stat Card ───────────────────────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: color)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
