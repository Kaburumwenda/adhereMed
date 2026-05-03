import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/pharmacy_store_models.dart';
import '../repository/pharmacy_store_repository.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _repo = PharmacyStoreRepository();
  List<PatientOrder> _orders = [];
  bool _loading = true;
  int _page = 1;
  String? _nextPage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (!append) setState(() => _loading = true);
    try {
      final result = await _repo.getOrders(page: _page);
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/pharmacy-store'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text('My Orders',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const LoadingWidget()
          else if (_orders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text('No orders yet',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/pharmacy-store'),
                      child: const Text('Browse Pharmacies'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ..._orders.map((order) => _OrderCard(order: order)),
            if (_nextPage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: OutlinedButton(
                    onPressed: () {
                      _page++;
                      _load(append: true);
                    },
                    child: const Text('Load More'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final PatientOrder order;
  const _OrderCard({required this.order});

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/pharmacy-store/orders/${order.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('#${order.orderNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(order.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(order.pharmacyName,
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('${order.items.length} items',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  Text('KSh ${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
