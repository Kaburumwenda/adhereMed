import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/status_badge.dart';
import '../models/invoice_model.dart';
import '../repository/billing_repository.dart';

double _toDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState
    extends ConsumerState<InvoiceDetailScreen> {
  final _repo = BillingRepository();
  Invoice? _invoice;
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
      final result = await _repo.getDetail(int.parse(widget.invoiceId));
      setState(() {
        _invoice = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmt(double amount) => 'KSh ${amount.toStringAsFixed(2)}';

  Future<void> _showPaymentDialog() async {
    final amountCtrl = TextEditingController();
    String method = 'cash';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Record Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: _invoice!.balanceDue.toStringAsFixed(2),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration:
                    const InputDecoration(labelText: 'Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(
                      value: 'insurance', child: Text('Insurance')),
                  DropdownMenuItem(
                      value: 'bank_transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (v) =>
                    setDialogState(() => method = v ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    try {
      await _repo.recordPayment(int.parse(widget.invoiceId), {
        'amount': amount,
        'payment_method': method,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final inv = _invoice!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invoice ${inv.invoiceNumber ?? '#${inv.id}'}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              StatusBadge(status: inv.status),
              const SizedBox(width: 12),
              if (inv.balanceDue > 0)
                FilledButton.icon(
                  onPressed: _showPaymentDialog,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Record Payment'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success),
                ),
            ],
          ),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final infoCard = _buildInfoCard(inv);
              final summaryCard = _buildSummaryCard(inv);

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: infoCard),
                    const SizedBox(width: 16),
                    Expanded(child: summaryCard),
                  ],
                );
              }
              return Column(
                children: [
                  infoCard,
                  const SizedBox(height: 16),
                  summaryCard,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Items
          if (inv.items != null && inv.items!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice Items',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Divider(height: 24),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(AppColors.background),
                        columns: const [
                          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                          DataColumn(label: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                        ],
                        rows: inv.items!.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item['description']?.toString() ?? '-')),
                            DataCell(Text(item['quantity']?.toString() ?? '-')),
                            DataCell(Text(_fmt(_toDouble(item['unit_price'])))),
                            DataCell(Text(_fmt(_toDouble(item['total'])))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (inv.items != null && inv.items!.isNotEmpty)
            const SizedBox(height: 16),

          // Payments
          if (inv.payments != null && inv.payments!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment History',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Divider(height: 24),
                    ...inv.payments!.map((pay) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _fmt(_toDouble(pay['amount'])),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    (pay['payment_method'] ?? '')
                                        .toString()
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              Text(
                                pay['created_at']
                                        ?.toString()
                                        .split('T')
                                        .first ??
                                    '-',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Invoice inv) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice Info',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Divider(height: 24),
            _row('Invoice #', inv.invoiceNumber ?? '#${inv.id}'),
            _row('Patient', inv.patientName ?? 'ID: ${inv.patientId}'),
            _row('Status', inv.status.toUpperCase()),
            _row('Created', inv.createdAt?.split('T').first ?? '-'),
            _row('Due Date', inv.dueDate ?? '-'),
            if (inv.notes != null && inv.notes!.isNotEmpty)
              _row('Notes', inv.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Invoice inv) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Summary',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Divider(height: 24),
            _summaryRow('Subtotal', _fmt(inv.subtotal)),
            _summaryRow('Tax', _fmt(inv.taxAmount)),
            _summaryRow('Discount', '- ${_fmt(inv.discount)}'),
            const Divider(height: 16),
            _summaryRow('Total', _fmt(inv.totalAmount), bold: true),
            _summaryRow('Paid', _fmt(inv.amountPaid),
                color: AppColors.success),
            _summaryRow('Balance Due', _fmt(inv.balanceDue),
                color: inv.balanceDue > 0
                    ? AppColors.error
                    : AppColors.success,
                bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              )),
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}
