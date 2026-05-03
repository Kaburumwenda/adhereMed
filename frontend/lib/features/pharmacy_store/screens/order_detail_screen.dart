import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/pharmacy_store_models.dart';
import '../repository/pharmacy_store_repository.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _repo = PharmacyStoreRepository();
  PatientOrder? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _order = await _repo.getOrder(widget.orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
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
                onPressed: () => context.go('/pharmacy-store/orders'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text('Order Details',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const LoadingWidget()
          else if (_order == null)
            Center(
              child: Text('Order not found',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            _buildOrderDetail(_order!),
        ],
      ),
    );
  }

  Widget _buildOrderDetail(PatientOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order header card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order #${order.orderNumber}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(order.pharmacyName,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(order.status)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _statusColor(order.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (order.createdAt != null)
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year} at ${order.createdAt!.hour}:${order.createdAt!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                if (order.deliveryAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(order.deliveryAddress,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Items card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Items (${order.items.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 16),
                ...order.items.map((item) {
                  final name = item['medication_name'] ?? '';
                  final qty = item['quantity'] ?? 0;
                  final unitPrice =
                      double.tryParse('${item['unit_price']}') ?? 0;
                  final total = double.tryParse('${item['total']}') ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              Text(
                                  '$qty × KSh ${unitPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        Text('KSh ${total.toStringAsFixed(2)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
                const Divider(),
                const SizedBox(height: 8),
                _Row(label: 'Subtotal',
                    value: 'KSh ${order.subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                _Row(label: 'Delivery Fee',
                    value: 'KSh ${order.deliveryFee.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _Row(
                  label: 'Total',
                  value: 'KSh ${order.total.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Payment & Notes
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Payment: ${order.paymentMethod.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(order.notes)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            )),
        Text(value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 16 : 14,
              color: bold ? AppColors.primary : null,
            )),
      ],
    );
  }
}
