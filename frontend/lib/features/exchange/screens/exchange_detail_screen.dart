import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/status_badge.dart';
import '../models/exchange_model.dart';
import '../repository/exchange_repository.dart';

class ExchangeDetailScreen extends ConsumerStatefulWidget {
  final int exchangeId;

  const ExchangeDetailScreen({super.key, required this.exchangeId});

  @override
  ConsumerState<ExchangeDetailScreen> createState() =>
      _ExchangeDetailScreenState();
}

class _ExchangeDetailScreenState extends ConsumerState<ExchangeDetailScreen> {
  final _repo = ExchangeRepository();
  PrescriptionExchange? _exchange;
  List<PharmacyQuote> _quotes = [];
  bool _loading = true;
  String? _error;
  bool _accepting = false;
  bool _generatingQuote = false;

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
      final results = await Future.wait([
        _repo.getExchange(widget.exchangeId),
        _repo.getQuotes(widget.exchangeId),
      ]);
      setState(() {
        _exchange = results[0] as PrescriptionExchange;
        _quotes = results[1] as List<PharmacyQuote>;
        _quotes.sort((a, b) => a.totalCost.compareTo(b.totalCost));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _acceptQuote(PharmacyQuote quote) async {
    setState(() => _accepting = true);
    try {
      await _repo.acceptQuote(widget.exchangeId, quote.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Quote from ${quote.pharmacyName} accepted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept quote: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _showPharmacyPicker() async {
    // Fetch pharmacies
    List<Map<String, dynamic>> pharmacies = [];
    try {
      pharmacies = await _repo.getPharmacies();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load pharmacies: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (pharmacies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pharmacies available.')),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show selection dialog
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _PharmacyPickerDialog(
        pharmacies: pharmacies,
        existingQuotePharmacyIds:
            _quotes.map((q) => q.pharmacyTenantId).toSet(),
      ),
    );

    if (selected == null || !mounted) return;

    // Generate quote
    setState(() => _generatingQuote = true);
    try {
      await _repo.generateQuote(widget.exchangeId, selected['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quote generated from ${selected['name']}!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is DioException && e.response?.data is Map) {
          msg = (e.response!.data as Map)['detail'] ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingQuote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    if (_exchange == null) {
      return const app_error.AppErrorWidget(message: 'Exchange not found');
    }

    final exchange = _exchange!;
    final isAccepted =
        exchange.status == 'accepted' || exchange.status == 'completed';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescription Details',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exchange.prescriptionRef,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: exchange.status),
            ],
          ),
          const SizedBox(height: 24),

          // Prescription Info Card
          _buildInfoCard(exchange),
          const SizedBox(height: 20),

          // Medication Items
          _buildItemsSection(exchange),
          const SizedBox(height: 20),

          // Get Quote from Pharmacy button
          if (!isAccepted) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generatingQuote ? null : _showPharmacyPicker,
                icon: _generatingQuote
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_business_rounded, size: 20),
                label: Text(_generatingQuote
                    ? 'Generating Quote...'
                    : 'Get Quote from Pharmacy'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Selected Pharmacy (if accepted)
          if (isAccepted) ...[
            _buildAcceptedSection(),
            const SizedBox(height: 20),
          ],

          // Price Comparison
          _buildQuotesSection(isAccepted),
        ],
      ),
    );
  }

  Widget _buildInfoCard(PrescriptionExchange exchange) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prescription Info',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _infoRow('Reference', exchange.prescriptionRef),
            _infoRow('Status', exchange.status.replaceAll('_', ' ')),
            _infoRow('Date', exchange.createdAt ?? 'N/A'),
            if (exchange.expiresAt != null)
              _infoRow('Expires', exchange.expiresAt!),
            _infoRow('Items', '${exchange.items.length} medication(s)'),
            _infoRow('Quotes Received', '${_quotes.length}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(PrescriptionExchange exchange) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medications',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...exchange.items.map((item) {
              final med = item is Map ? item : <String, dynamic>{};
              final name =
                  med['medication_name'] ?? med['custom_medication_name'] ?? '';
              final dosage = med['dosage'] ?? '';
              final frequency = med['frequency'] ?? '';
              final duration = med['duration'] ?? '';
              final qty = med['quantity'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.medication_outlined,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [dosage, frequency, duration]
                                .where((s) => s.toString().isNotEmpty)
                                .join(' · '),
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (qty.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Qty: $qty',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedSection() {
    final accepted = _quotes.where((q) => q.status == 'accepted').toList();
    if (accepted.isEmpty) return const SizedBox.shrink();
    final quote = accepted.first;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.success, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Selected Pharmacy',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow('Pharmacy', quote.pharmacyName),
            _infoRow('Total Cost', 'KSh ${quote.totalCost.toStringAsFixed(2)}'),
            if (quote.deliveryAvailable)
              _infoRow(
                  'Delivery Fee', 'KSh ${quote.deliveryFee.toStringAsFixed(2)}'),
            if (quote.validUntil != null)
              _infoRow('Valid Until', quote.validUntil!),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesSection(bool isAccepted) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Price Comparison',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                Text(
                  '${_quotes.length} quote(s)',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_quotes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_empty_rounded,
                          size: 40,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        'Waiting for pharmacy quotes...',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._quotes.asMap().entries.map((entry) {
                final index = entry.key;
                final quote = entry.value;
                final isLowest = index == 0;
                return _QuoteCard(
                  quote: quote,
                  isLowest: isLowest,
                  isAccepted: quote.status == 'accepted',
                  showAcceptButton: !isAccepted && !_accepting,
                  onAccept: () => _acceptQuote(quote),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final PharmacyQuote quote;
  final bool isLowest;
  final bool isAccepted;
  final bool showAcceptButton;
  final VoidCallback onAccept;

  const _QuoteCard({
    required this.quote,
    required this.isLowest,
    required this.isAccepted,
    required this.showAcceptButton,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isAccepted ? AppColors.success : (isLowest ? AppColors.primary : AppColors.border);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: isLowest || isAccepted ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
        color: isLowest && !isAccepted
            ? AppColors.primary.withValues(alpha: 0.03)
            : isAccepted
                ? AppColors.success.withValues(alpha: 0.03)
                : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_pharmacy_outlined,
                      size: 20, color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.pharmacyName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (quote.deliveryAvailable)
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Delivery available',
                              style: TextStyle(
                                  color: AppColors.primary, fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (isLowest && !isAccepted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'BEST PRICE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isAccepted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'ACCEPTED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Item prices
            if (quote.itemsPricing.isNotEmpty) ...[
              ...quote.itemsPricing.map((item) {
                final pricing = item is Map ? item : <String, dynamic>{};
                final name = pricing['name'] ?? pricing['medication_name'] ?? '';
                final price = pricing['unit_price'] ?? pricing['price'] ?? 0;
                final qty = pricing['quantity'] ?? '';
                final lineTotal = pricing['total'] ?? pricing['line_total'] ?? 0;
                final isAvailable = pricing['available'] != false;
                final reason = pricing['reason'] ?? '';
                final itemColor = isAvailable
                    ? AppColors.textSecondary
                    : AppColors.error;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '$name',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: itemColor,
                                      decoration: isAvailable
                                          ? null
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                if (!isAvailable) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'UNAVAILABLE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              'x$qty',
                              style: TextStyle(
                                  fontSize: 12, color: itemColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              isAvailable
                                  ? 'KSh ${_parseNum(price).toStringAsFixed(0)}'
                                  : '-',
                              style: TextStyle(
                                  fontSize: 12, color: itemColor),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              isAvailable
                                  ? 'KSh ${_parseNum(lineTotal).toStringAsFixed(0)}'
                                  : '-',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isAvailable
                                    ? null
                                    : AppColors.error,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      if (!isAvailable && reason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, left: 2),
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.error.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
            ],

            // Totals
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _totalRow('Subtotal',
                          'KSh ${quote.subtotal.toStringAsFixed(2)}'),
                      if (quote.deliveryAvailable && quote.deliveryFee > 0)
                        _totalRow('Delivery',
                            'KSh ${quote.deliveryFee.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      'KSh ${quote.totalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isLowest ? AppColors.success : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (quote.validUntil != null) ...[
              const SizedBox(height: 8),
              Text(
                'Valid until ${quote.validUntil}',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],

            // Accept button
            if (showAcceptButton) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(isLowest
                      ? 'Accept Best Price'
                      : 'Accept This Quote'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isLowest ? AppColors.success : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static num _parseNum(dynamic v) =>
      v is num ? v : (num.tryParse(v.toString()) ?? 0);
}

class _PharmacyPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> pharmacies;
  final Set<int> existingQuotePharmacyIds;

  const _PharmacyPickerDialog({
    required this.pharmacies,
    required this.existingQuotePharmacyIds,
  });

  @override
  State<_PharmacyPickerDialog> createState() => _PharmacyPickerDialogState();
}

class _PharmacyPickerDialogState extends State<_PharmacyPickerDialog> {
  String _search = '';

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return widget.pharmacies;
    final q = _search.toLowerCase();
    return widget.pharmacies
        .where((p) =>
            (p['name'] ?? '').toString().toLowerCase().contains(q) ||
            (p['city'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.local_pharmacy_rounded,
                            size: 20, color: AppColors.secondary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Choose a Pharmacy',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.background,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search pharmacies...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Flexible(
              child: _filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No pharmacies found',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final pharmacy = _filtered[i];
                        final hasQuote = widget.existingQuotePharmacyIds
                            .contains(pharmacy['id']);
                        final productCount = pharmacy['product_count'] ?? 0;
                        return ListTile(
                          onTap: () => Navigator.pop(context, pharmacy),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: Icon(Icons.local_pharmacy_outlined,
                                color: AppColors.primary, size: 20),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pharmacy['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                              ),
                              if (hasQuote)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'QUOTED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            [
                              if ((pharmacy['city'] ?? '').toString().isNotEmpty)
                                pharmacy['city'],
                              if (productCount > 0)
                                '$productCount products',
                            ].join(' · '),
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: AppColors.textSecondary),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
