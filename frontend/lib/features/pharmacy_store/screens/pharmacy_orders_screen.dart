import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/pharmacy_store_models.dart';
import '../repository/pharmacy_store_repository.dart';

class PharmacyOrdersScreen extends ConsumerStatefulWidget {
  const PharmacyOrdersScreen({super.key});

  @override
  ConsumerState<PharmacyOrdersScreen> createState() =>
      _PharmacyOrdersScreenState();
}

class _PharmacyOrdersScreenState extends ConsumerState<PharmacyOrdersScreen> {
  final _repo = PharmacyStoreRepository();

  List<PatientOrder> _orders = [];
  bool _loading = true;
  int _page = 1;
  String? _nextPage;
  String? _statusFilter;
  String _search = '';

  final _statuses = [
    null,
    'pending',
    'confirmed',
    'processing',
    'ready',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (!append) setState(() => _loading = true);
    try {
      final result = await _repo.getPharmacyOrders(
        page: _page,
        status: _statusFilter,
        search: _search.isEmpty ? null : _search,
      );
      setState(() {
        if (append) {
          _orders.addAll(result.results);
        } else {
          _orders = result.results;
        }
        _nextPage = result.next;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateStatus(PatientOrder order, String newStatus) async {
    try {
      final updated = await _repo.updateOrderStatus(order.id, newStatus);
      setState(() {
        final idx = _orders.indexWhere((o) => o.id == updated.id);
        if (idx >= 0) _orders[idx] = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} → ${newStatus.toUpperCase()}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.indigo;
      case 'ready':
        return Colors.teal;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'processing':
        return Icons.autorenew_rounded;
      case 'ready':
        return Icons.inventory_rounded;
      case 'completed':
        return Icons.done_all_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  String? _nextStatusFor(String current) {
    const flow = ['pending', 'confirmed', 'processing', 'ready', 'completed'];
    final idx = flow.indexOf(current);
    if (idx >= 0 && idx < flow.length - 1) return flow[idx + 1];
    return null;
  }

  String _nextStatusLabel(String next) {
    switch (next) {
      case 'confirmed':
        return 'Confirm';
      case 'processing':
        return 'Start Processing';
      case 'ready':
        return 'Mark Ready';
      case 'completed':
        return 'Complete';
      default:
        return next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded,
                    color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patient Orders',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Manage incoming medicine orders',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  _page = 1;
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Search + Filter ──
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by order # or patient name...',
                      hintStyle: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) {
                      _search = v;
                      _page = 1;
                      _load();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Status filter chips ──
          SizedBox(
            height: 38,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((s) {
                  final selected = _statusFilter == s;
                  final label = s == null ? 'All' : s[0].toUpperCase() + s.substring(1);
                  return Padding(
                    padding: EdgeInsets.only(left: s == null ? 0 : 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _statusFilter = s);
                        _page = 1;
                        _load();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? (s != null
                                  ? _statusColor(s)
                                  : AppColors.primary)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Orders list ──
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.border.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.receipt_long_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            Text('No orders found',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Text(
                              _statusFilter != null
                                  ? 'No $_statusFilter orders'
                                  : 'Orders from patients will appear here',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount:
                            _orders.length + (_nextPage != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _orders.length) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    _page++;
                                    _load(append: true);
                                  },
                                  icon: const Icon(
                                      Icons.expand_more_rounded,
                                      size: 20),
                                  label: const Text('Load More'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    foregroundColor: AppColors.primary,
                                  ),
                                ),
                              ),
                            );
                          }
                          return _buildOrderCard(_orders[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(PatientOrder order) {
    final color = _statusColor(order.status);
    final nextStatus = _nextStatusFor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_statusIcon(order.status),
                size: 20, color: color),
          ),
          title: Row(
            children: [
              Text('#${order.orderNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(order.patientName,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  'KSh ${order.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Order info
            _infoRow(Icons.calendar_today_rounded,
                _formatDate(order.createdAt)),
            if (order.deliveryAddress.isNotEmpty)
              _infoRow(
                  Icons.location_on_outlined, order.deliveryAddress),
            _infoRow(Icons.payment_rounded,
                order.paymentMethod == 'mpesa' ? 'M-Pesa' : 'Cash on Delivery'),
            if (order.notes.isNotEmpty)
              _infoRow(Icons.notes_rounded, order.notes),
            const SizedBox(height: 12),

            // Items
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items (${order.items.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...order.items.map((item) {
                    final name =
                        item['medication_name'] ?? item['name'] ?? '';
                    final qty = item['quantity'] ?? 1;
                    final total = item['total'] ?? '0';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('$name × $qty',
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text('KSh $total',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        'KSh ${order.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                if (order.status != 'cancelled' &&
                    order.status != 'completed') ...[
                  if (nextStatus != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _updateStatus(order, nextStatus),
                        icon: Icon(_statusIcon(nextStatus), size: 18),
                        label: Text(_nextStatusLabel(nextStatus)),
                        style: FilledButton.styleFrom(
                          backgroundColor: _statusColor(nextStatus),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        _updateStatus(order, 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color:
                              AppColors.error.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
                if (order.status == 'completed' ||
                    order.status == 'cancelled')
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(order.status),
                            size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(
                          order.status == 'completed'
                              ? 'Order Completed'
                              : 'Order Cancelled',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} at $h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }
}
