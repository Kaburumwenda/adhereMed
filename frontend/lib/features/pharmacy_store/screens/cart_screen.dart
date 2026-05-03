import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../providers/cart_provider.dart';
import '../repository/pharmacy_store_repository.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _repo = PharmacyStoreRepository();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _submitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = {
        'pharmacy_tenant_id': cart.pharmacyId,
        'items': cart.items
            .map((item) => {
                  'medication_name': item.product.medicationName,
                  'medication_id': item.product.medicationId,
                  'quantity': item.quantity,
                })
            .toList(),
        'delivery_address': _addressController.text.trim(),
        'payment_method': _paymentMethod,
        'notes': _notesController.text.trim(),
      };
      await _repo.createOrder(data);
      if (mounted) {
        ref.read(cartProvider.notifier).clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Order placed successfully!'),
              backgroundColor: Colors.green),
        );
        context.go('/pharmacy-store/orders');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (cart.pharmacyId != null) {
                    context.go('/pharmacy-store/${cart.pharmacyId}');
                  } else {
                    context.go('/pharmacy-store');
                  }
                },
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Shopping Cart',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              if (cart.items.isNotEmpty)
                TextButton(
                  onPressed: () => ref.read(cartProvider.notifier).clear(),
                  child:
                      Text('Clear All', style: TextStyle(color: AppColors.error)),
                ),
            ],
          ),
          if (cart.pharmacyName != null) ...[
            const SizedBox(height: 4),
            Text('From ${cart.pharmacyName}',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 24),

          if (cart.items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text('Your cart is empty',
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
          else
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildCartItems(cart)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildCheckout(cart)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildCartItems(cart),
                  const SizedBox(height: 24),
                  _buildCheckout(cart),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCartItems(CartState cart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items (${cart.itemCount})',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            ...cart.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.medicationName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            Text(
                                'KSh ${item.product.sellingPrice.toStringAsFixed(2)} each',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      // Quantity controls
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: item.quantity > 1
                                  ? () => ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(
                                          item.product.id, item.quantity - 1)
                                  : null,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                            SizedBox(
                              width: 32,
                              child: Text('${item.quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .updateQuantity(
                                      item.product.id, item.quantity + 1),
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'KSh ${item.total.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: AppColors.error, size: 20),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .removeItem(item.product.id),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckout(CartState cart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Checkout',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 20),

            // Delivery address
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address *',
                hintText: 'Enter your delivery address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Payment method
            const Text('Payment Method',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v!),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Cash on Delivery'),
                    value: 'cash',
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('M-Pesa'),
                    value: 'mpesa',
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any special instructions...',
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Order summary
            const Divider(),
            const SizedBox(height: 12),
            _SummaryRow(label: 'Subtotal',
                value: 'KSh ${cart.subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _SummaryRow(label: 'Delivery Fee',
                value: 'KSh ${cart.deliveryFee.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Total',
              value: 'KSh ${cart.total.toStringAsFixed(2)}',
              bold: true,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _placeOrder,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Place Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow(
      {required this.label, required this.value, this.bold = false});

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
