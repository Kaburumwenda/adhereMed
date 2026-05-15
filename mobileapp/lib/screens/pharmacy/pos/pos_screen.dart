import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common.dart';

const _kPosStateKey = 'pos_cart_state_v1';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// All active inventory stock items
final _productsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/stocks/',
      queryParameters: {'page_size': 5000, 'is_active': true, 'ordering': '-created_at'});
  final data = res.data;
  final list = data is List ? data : (data?['results'] as List?) ?? [];
  return List<Map<String, dynamic>>.from(list);
});

/// Today's transaction stats
final _todayStatsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/transactions/', queryParameters: {'page_size': 500});
  final data = res.data;
  final list = data is List ? data : (data?['results'] as List?) ?? [];
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final todayTx = list.where((t) => (t['created_at'] ?? '').toString().startsWith(today)).toList();
  final count = todayTx.length;
  final revenue = todayTx.fold<double>(
      0, (s, t) => s + (double.tryParse('${t['total']}') ?? 0));
  return {'count': count, 'revenue': revenue};
});

/// Parked sales count
final _parkedCountProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/parked-sales/', queryParameters: {'page_size': 1});
  final data = res.data;
  if (data is Map && data['count'] != null) return data['count'] as int;
  return 0;
});

/// Pharmacy branches
final _branchesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pharmacy-profile/branches/');
  final data = res.data;
  final list = data is List ? data : (data?['results'] as List?) ?? [];
  return List<Map<String, dynamic>>.from(list);
});

final _searchProvider = StateProvider.autoDispose((_) => '');
final _categoryFilter = StateProvider.autoDispose<String?>((_) => null);

// ═══════════════════════════════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

const _paymentMethods = [
  {'value': 'cash', 'label': 'Cash', 'icon': Icons.payments_rounded},
  {'value': 'mpesa', 'label': 'M-Pesa', 'icon': Icons.phone_android_rounded},
  {'value': 'card', 'label': 'Card', 'icon': Icons.credit_card_rounded},
  {'value': 'insurance', 'label': 'Insurance', 'icon': Icons.health_and_safety_rounded},
  {'value': 'credit', 'label': 'Credit', 'icon': Icons.account_balance_wallet_rounded},
];

const _partialPaymentMethods = [
  {'value': 'none', 'label': 'None'},
  {'value': 'cash', 'label': 'Cash'},
  {'value': 'mpesa', 'label': 'M-Pesa'},
  {'value': 'card', 'label': 'Card'},
  {'value': 'insurance', 'label': 'Insurance'},
];

String _fmtMoney(dynamic v) {
  final n = double.tryParse('$v') ?? 0;
  return NumberFormat.currency(symbol: 'KES ', decimalDigits: 0).format(n);
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

Color _paymentColor(String? m) => switch (m?.toLowerCase()) {
      'cash' => const Color(0xFF10B981),
      'mpesa' => const Color(0xFF059669),
      'card' => const Color(0xFF3B82F6),
      'insurance' => const Color(0xFFF59E0B),
      'credit' => const Color(0xFFEC4899),
      _ => const Color(0xFF6B7280),
    };

IconData _paymentIcon(String? m) => switch (m?.toLowerCase()) {
      'cash' => Icons.payments_rounded,
      'mpesa' => Icons.phone_android_rounded,
      'card' => Icons.credit_card_rounded,
      'insurance' => Icons.health_and_safety_rounded,
      'credit' => Icons.account_balance_wallet_rounded,
      _ => Icons.payment_rounded,
    };

// ═══════════════════════════════════════════════════════════════════════════
//  POS SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});
  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> with TickerProviderStateMixin {
  // Cart state
  final List<Map<String, dynamic>> _cart = [];
  String _paymentMethod = 'cash';
  String _customerName = '';
  double _discount = 0;
  bool _checkingOut = false;

  // Branch state
  int? _selectedBranchId;

  // Credit sale state
  String _creditPhone = '';
  String _creditDueDate = '';
  double _creditPartial = 0;
  String _creditPartialMethod = 'none';
  String _creditReference = '';
  String _creditNotes = '';

  // Server search
  List<Map<String, dynamic>> _serverResults = [];
  Timer? _searchTimer;

  late final AnimationController _cartBounce;

  @override
  void initState() {
    super.initState();
    _cartBounce = AnimationController(vsync: this, duration: 200.ms);
    _restoreState();
  }

  // ── Persistence ──
  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPosStateKey);
    if (raw == null) return;
    try {
      final s = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _cart.clear();
        for (final it in (s['cart'] as List?) ?? []) {
          _cart.add(Map<String, dynamic>.from(it));
        }
        _customerName = (s['customerName'] as String?) ?? '';
        _discount = (s['discount'] as num?)?.toDouble() ?? 0;
        _paymentMethod = (s['paymentMethod'] as String?) ?? 'cash';
        _creditPhone = (s['creditPhone'] as String?) ?? '';
        _creditDueDate = (s['creditDueDate'] as String?) ?? '';
        _creditPartial = (s['creditPartial'] as num?)?.toDouble() ?? 0;
        _creditPartialMethod = (s['creditPartialMethod'] as String?) ?? 'none';
        _creditReference = (s['creditReference'] as String?) ?? '';
        _creditNotes = (s['creditNotes'] as String?) ?? '';
        _selectedBranchId = s['branchId'] as int?;
      });
    } catch (_) {}
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPosStateKey, jsonEncode({
      'cart': _cart,
      'customerName': _customerName,
      'discount': _discount,
      'paymentMethod': _paymentMethod,
      'creditPhone': _creditPhone,
      'creditDueDate': _creditDueDate,
      'creditPartial': _creditPartial,
      'creditPartialMethod': _creditPartialMethod,
      'creditReference': _creditReference,
      'creditNotes': _creditNotes,
      'branchId': _selectedBranchId,
    }));
  }

  Future<void> _clearPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPosStateKey);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _cartBounce.dispose();
    super.dispose();
  }

  // ── Cart helpers ──
  int get _itemCount => _cart.fold(0, (s, it) => s + (it['quantity'] as int));
  double get _subtotal => _cart.fold(0.0,
      (s, it) => s + (it['quantity'] as int) * (double.tryParse('${it['selling_price']}') ?? 0));
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);
  double get _tax => _total * (0.16 / 1.16);
  bool get _isCredit => _paymentMethod == 'credit';
  double get _creditBalance => (_total - _creditPartial).clamp(0, double.infinity);

  bool get _creditValid {
    if (!_isCredit) return true;
    if (_customerName.trim().length < 2) return false;
    if (_creditDueDate.isEmpty) return false;
    if (_creditPartial > _total) return false;
    if (_creditPartial > 0 && _creditPartialMethod == 'none') return false;
    return true;
  }

  void _addToCart(Map<String, dynamic> product) {
    final stock = (product['total_quantity'] ?? product['quantity'] ?? 0) as num;
    if (stock <= 0) return;

    final idx = _cart.indexWhere((it) => it['id'] == product['id']);
    setState(() {
      if (idx >= 0) {
        if (_cart[idx]['quantity'] < stock) {
          _cart[idx]['quantity'] = (_cart[idx]['quantity'] as int) + 1;
        } else {
          _snack('Stock limit reached', isError: true);
          return;
        }
      } else {
        _cart.add({
          'id': product['id'],
          'name': product['medication_name'] ?? product['name'] ?? 'Unnamed',
          'selling_price': product['selling_price'],
          'quantity': 1,
          'max_qty': stock.toInt(),
          'rx': (product['prescription_required'] ?? 'none').toString().toLowerCase(),
        });
      }
    });
    HapticFeedback.lightImpact();
    _cartBounce.forward().then((_) => _cartBounce.reverse());
    _persistState();
  }

  void _incrementItem(int i) {
    setState(() {
      final it = _cart[i];
      if ((it['quantity'] as int) < (it['max_qty'] as int)) {
        it['quantity'] = (it['quantity'] as int) + 1;
      }
    });
    _persistState();
  }

  void _decrementItem(int i) {
    setState(() {
      if ((_cart[i]['quantity'] as int) > 1) {
        _cart[i]['quantity'] = (_cart[i]['quantity'] as int) - 1;
      } else {
        _cart.removeAt(i);
      }
    });
    _persistState();
  }

  void _removeItem(int i) {
    setState(() => _cart.removeAt(i));
    _persistState();
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _customerName = '';
      _discount = 0;
      _paymentMethod = 'cash';
      _creditPhone = '';
      _creditDueDate = '';
      _creditPartial = 0;
      _creditPartialMethod = 'none';
      _creditReference = '';
      _creditNotes = '';
      _selectedBranchId = null;
    });
    _clearPersistedState();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.red.shade700 : null,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Server search when local yields few results ──
  void _onSearchChanged(String q, List<Map<String, dynamic>> products) {
    _searchTimer?.cancel();
    _serverResults = [];
    if (q.trim().length < 2) return;

    _searchTimer = Timer(400.ms, () async {
      // Check local matches
      final localCount = products.where((p) {
        final name = (p['medication_name'] ?? p['name'] ?? '').toString().toLowerCase();
        final abbr = (p['abbreviation'] ?? '').toString().toLowerCase();
        final barcode = (p['barcode'] ?? p['sku'] ?? '').toString().toLowerCase();
        return name.contains(q.toLowerCase()) ||
            abbr.contains(q.toLowerCase()) ||
            barcode.contains(q.toLowerCase());
      }).length;

      if (localCount > 3) return;

      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/inventory/stocks/',
            queryParameters: {'search': q, 'is_active': true, 'page_size': 20});
        final data = res.data;
        final list = data is List ? data : (data?['results'] as List?) ?? [];
        if (mounted) setState(() => _serverResults = List<Map<String, dynamic>>.from(list));
      } catch (_) {}
    });
  }

  // ── Checkout ──
  Future<void> _checkout() async {
    if (_cart.isEmpty || _checkingOut) return;
    if (!_creditValid) {
      _snack('Complete credit sale details first', isError: true);
      return;
    }

    setState(() => _checkingOut = true);
    try {
      final dio = ref.read(dioProvider);
      final items = _cart.map((c) {
        return {'stock_id': c['id'], 'quantity': c['quantity']};
      }).toList();

      final payload = <String, dynamic>{
        'payment_method': _paymentMethod,
        'customer_name': _customerName.isEmpty ? 'Walk-in' : _customerName,
        'discount': _discount,
        'items': items,
        if (_selectedBranchId != null) 'branch_id': _selectedBranchId,
      };

      if (_isCredit) {
        payload['customer_phone'] = _creditPhone;
        payload['credit_due_date'] = _creditDueDate.isNotEmpty ? _creditDueDate : null;
        payload['credit_notes'] = _creditNotes;
        payload['partial_paid_amount'] = _creditPartial;
        payload['partial_payment_method'] =
            _creditPartial > 0 ? _creditPartialMethod : 'none';

        final refBits = <String>[];
        if (_creditReference.isNotEmpty) refBits.add('Ref: $_creditReference');
        if (_creditDueDate.isNotEmpty) refBits.add('Due: $_creditDueDate');
        if (_creditPartial > 0) {
          refBits.add('Partial: ${_creditPartial.toStringAsFixed(0)} via $_creditPartialMethod');
        }
        if (_creditNotes.isNotEmpty) refBits.add(_creditNotes);
        if (refBits.isNotEmpty) {
          payload['payment_reference'] = refBits.join(' | ').substring(
              0, refBits.join(' | ').length.clamp(0, 100));
        }
      }

      final res = await dio.post('/pos/transactions/', data: payload);
      final txn = res.data;

      if (!mounted) return;
      _showReceiptDialog(txn);
      _clearCart();
      ref.invalidate(_productsProvider);
      ref.invalidate(_todayStatsProvider);
      ref.invalidate(_parkedCountProvider);
    } catch (e) {
      String msg = 'Failed to complete sale';
      if (e is Exception) {
        try {
          final dioErr = e as dynamic;
          final data = dioErr.response?.data;
          if (data is Map) {
            final parts = <String>[];
            data.forEach((k, v) {
              final text = v is List ? v.join(', ') : '$v';
              parts.add(k == 'non_field_errors' ? text : '$k: $text');
            });
            if (parts.isNotEmpty) msg = parts.join(' — ');
          }
        } catch (_) {}
      }
      _snack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  // ── Hold sale ──
  Future<void> _holdSale() async {
    if (_cart.isEmpty) return;

    final nameCtrl = TextEditingController(text: _customerName);
    final phoneCtrl = TextEditingController(text: _creditPhone);
    final notesCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.pause_circle_filled_rounded,
                    color: Colors.orange.shade700, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hold Sale',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Save this cart for later',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_itemCount items · ${_fmtMoney(_total)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer)),
              ),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Customer Name *',
                prefixIcon: const Icon(Icons.person_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: const Icon(Icons.phone_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: const Icon(Icons.note_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.pause_circle_filled_rounded),
                  label: const Text('Hold Sale'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ]),
        );
      },
    );

    if (confirmed != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/pos/parked-sales/', data: {
        'customer_name': nameCtrl.text.trim(),
        'customer_phone': phoneCtrl.text.trim(),
        'payment_method': _paymentMethod,
        'discount': _discount,
        'notes': notesCtrl.text.trim(),
        'items': _cart
            .map((it) {
              return {
                'stock_id': it['id'],
                'name': it['name'],
                'sku': it['sku'] ?? '',
                'category': it['category'] ?? '',
                'selling_price': double.tryParse('${it['selling_price']}') ?? 0,
                'quantity': it['quantity'],
                'max_qty': it['max_qty'] ?? 9999,
              };
            })
            .toList(),
      });
      _snack('Sale held under "${nameCtrl.text.trim()}"');
      _clearCart();
      ref.invalidate(_parkedCountProvider);
    } catch (e) {
      _snack('Failed to hold sale', isError: true);
    }
  }

  // ── Parked sales list ──
  Future<void> _showParkedSales() async {
    final dio = ref.read(dioProvider);
    List<Map<String, dynamic>> parked = [];
    bool loading = true;
    String? error;

    try {
      final res = await dio.get('/pos/parked-sales/',
          queryParameters: {'page_size': 200});
      final data = res.data;
      final list = data is List ? data : (data?['results'] as List?) ?? [];
      parked = List<Map<String, dynamic>>.from(list);
    } catch (e) {
      error = 'Failed to load parked sales';
    }
    loading = false;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cs = Theme.of(ctx).colorScheme;
            return Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.pause_circle_filled_rounded,
                          color: Colors.orange.shade700, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Parked Sales',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              '${parked.length} sale(s) on hold',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12),
                            ),
                          ]),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                // Body
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : error != null
                          ? Center(
                              child: Text(error!,
                                  style: TextStyle(color: cs.error)))
                          : parked.isEmpty
                              ? Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.inbox_rounded,
                                            size: 56,
                                            color: cs.onSurfaceVariant
                                                .withValues(alpha: 0.3)),
                                        const SizedBox(height: 12),
                                        Text('No parked sales',
                                            style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Parked sales appear when you hold a sale',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurfaceVariant
                                                  .withValues(alpha: 0.7)),
                                        ),
                                      ]))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: parked.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final p = parked[i];
                                    final items =
                                        (p['items'] as List?) ?? [];
                                    final total =
                                        double.tryParse('${p['total']}') ??
                                            0;
                                    final name = (p['customer_name'] ??
                                            'Walk-in')
                                        .toString();
                                    final phone =
                                        (p['customer_phone'] ?? '')
                                            .toString();
                                    final cashier =
                                        (p['cashier_name'] ?? '')
                                            .toString();
                                    final parkNum =
                                        (p['park_number'] ?? '')
                                            .toString();
                                    final createdAt =
                                        p['created_at'] != null
                                            ? DateTime.tryParse(
                                                p['created_at'].toString())
                                            : null;
                                    final timeStr = createdAt != null
                                        ? DateFormat('MMM d, h:mm a')
                                            .format(createdAt.toLocal())
                                        : '';
                                    final itemCount = p['item_count'] ??
                                        items.length;
                                    final notes =
                                        (p['notes'] ?? '').toString();
                                    final discount = double.tryParse(
                                            '${p['discount']}') ??
                                        0;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerLow,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                            color: cs.outlineVariant
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Column(children: [
                                        // Header
                                        Container(
                                          padding:
                                              const EdgeInsets.fromLTRB(
                                                  16, 14, 16, 10),
                                          decoration: BoxDecoration(
                                            color: Colors.orange
                                                .withValues(alpha: 0.06),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(
                                                        16)),
                                          ),
                                          child: Row(children: [
                                            Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Row(children: [
                                                      Text(parkNum,
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: Colors
                                                                  .orange
                                                                  .shade700)),
                                                      const SizedBox(
                                                          width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    8,
                                                                vertical:
                                                                    2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .orange
                                                              .withValues(
                                                                  alpha:
                                                                      0.15),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12),
                                                        ),
                                                        child: Text(
                                                            '$itemCount items',
                                                            style: TextStyle(
                                                                fontSize:
                                                                    10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .orange
                                                                    .shade800)),
                                                      ),
                                                    ]),
                                                    const SizedBox(
                                                        height: 4),
                                                    Row(children: [
                                                      Icon(
                                                          Icons
                                                              .person_rounded,
                                                          size: 14,
                                                          color: cs
                                                              .primary),
                                                      const SizedBox(
                                                          width: 4),
                                                      Flexible(
                                                        child: Text(name,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize:
                                                                    13),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                      ),
                                                      if (phone
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                            width: 6),
                                                        Text('· $phone',
                                                            style: TextStyle(
                                                                fontSize:
                                                                    11,
                                                                color: cs
                                                                    .onSurfaceVariant)),
                                                      ],
                                                    ]),
                                                  ]),
                                            ),
                                            Text(_fmtMoney(total),
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 15,
                                                    color: cs.primary)),
                                          ]),
                                        ),
                                        // Item preview
                                        Padding(
                                          padding:
                                              const EdgeInsets.fromLTRB(
                                                  16, 8, 16, 4),
                                          child: Column(
                                              children: [
                                            ...items
                                                .take(3)
                                                .map((it) {
                                              final qty =
                                                  it['quantity'] ?? 1;
                                              final price =
                                                  double.tryParse(
                                                          '${it['selling_price']}') ??
                                                      0;
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        bottom: 3),
                                                child: Row(children: [
                                                  Expanded(
                                                    child: Text(
                                                        '$qty × ${it['name'] ?? 'Item'}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: cs
                                                                .onSurface),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis),
                                                  ),
                                                  Text(
                                                      _fmtMoney(
                                                          price * qty),
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: cs
                                                              .onSurfaceVariant)),
                                                ]),
                                              );
                                            }),
                                            if (items.length > 3)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        top: 2),
                                                child: Text(
                                                    '+ ${items.length - 3} more item(s)',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: cs
                                                            .onSurfaceVariant
                                                            .withValues(
                                                                alpha:
                                                                    0.7))),
                                              ),
                                          ]),
                                        ),
                                        // Meta row
                                        Padding(
                                          padding:
                                              const EdgeInsets.fromLTRB(
                                                  16, 4, 16, 4),
                                          child: Row(children: [
                                            if (cashier.isNotEmpty) ...[
                                              Icon(
                                                  Icons
                                                      .badge_rounded,
                                                  size: 12,
                                                  color: cs
                                                      .onSurfaceVariant),
                                              const SizedBox(width: 3),
                                              Text(cashier,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: cs
                                                          .onSurfaceVariant)),
                                              const SizedBox(width: 10),
                                            ],
                                            if (timeStr.isNotEmpty) ...[
                                              Icon(
                                                  Icons
                                                      .access_time_rounded,
                                                  size: 12,
                                                  color: cs
                                                      .onSurfaceVariant),
                                              const SizedBox(width: 3),
                                              Text(timeStr,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: cs
                                                          .onSurfaceVariant)),
                                            ],
                                            if (discount > 0) ...[
                                              const SizedBox(width: 10),
                                              Text(
                                                  'Disc: ${_fmtMoney(discount)}',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.red
                                                          .shade400)),
                                            ],
                                          ]),
                                        ),
                                        if (notes.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.fromLTRB(
                                                    16, 0, 16, 4),
                                            child: Row(children: [
                                              Icon(
                                                  Icons
                                                      .note_rounded,
                                                  size: 12,
                                                  color: cs
                                                      .onSurfaceVariant),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(notes,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontStyle:
                                                            FontStyle
                                                                .italic,
                                                        color: cs
                                                            .onSurfaceVariant),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis),
                                              ),
                                            ]),
                                          ),
                                        // Action buttons
                                        Padding(
                                          padding:
                                              const EdgeInsets.fromLTRB(
                                                  12, 4, 12, 12),
                                          child: Row(children: [
                                            Expanded(
                                              child: FilledButton.icon(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _resumeParkedSale(p);
                                                },
                                                icon: const Icon(
                                                    Icons
                                                        .play_arrow_rounded,
                                                    size: 18),
                                                label: const Text(
                                                    'Resume'),
                                                style:
                                                    FilledButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(
                                                          0xFF10B981),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 10),
                                                  shape:
                                                      RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      10)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              height: 40,
                                              width: 40,
                                              child: IconButton(
                                                onPressed: () async {
                                                  final confirm =
                                                      await showDialog<
                                                          bool>(
                                                    context: ctx,
                                                    builder: (dlg) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Delete parked sale?'),
                                                      content: Text(
                                                          'Remove $parkNum for $name?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  dlg,
                                                                  false),
                                                          child:
                                                              const Text(
                                                                  'Cancel'),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  dlg,
                                                                  true),
                                                          style: FilledButton
                                                              .styleFrom(
                                                                  backgroundColor:
                                                                      Colors.red),
                                                          child:
                                                              const Text(
                                                                  'Delete'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    try {
                                                      await dio.delete(
                                                          '/pos/parked-sales/${p['id']}/');
                                                      setSheetState(() =>
                                                          parked
                                                              .removeAt(
                                                                  i));
                                                      ref.invalidate(
                                                          _parkedCountProvider);
                                                      _snack(
                                                          'Parked sale deleted');
                                                    } catch (_) {
                                                      _snack(
                                                          'Failed to delete',
                                                          isError: true);
                                                    }
                                                  }
                                                },
                                                icon: Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: cs.error,
                                                    size: 20),
                                                style:
                                                    IconButton.styleFrom(
                                                  backgroundColor: cs
                                                      .error
                                                      .withValues(
                                                          alpha: 0.1),
                                                  shape:
                                                      RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      10)),
                                                ),
                                              ),
                                            ),
                                          ]),
                                        ),
                                      ]),
                                    );
                                  },
                                ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  void _resumeParkedSale(Map<String, dynamic> p) async {
    final items = (p['items'] as List?) ?? [];
    setState(() {
      _cart.clear();
      for (final it in items) {
        _cart.add({
          'id': it['stock_id'] ?? it['id'],
          'name': it['name'] ?? 'Item',
          'sku': it['sku'] ?? '',
          'category': it['category'] ?? '',
          'selling_price': it['selling_price'],
          'quantity': it['quantity'] ?? 1,
          'max_qty': it['max_qty'] ?? 9999,
        });
      }
      _customerName = (p['customer_name'] ?? '').toString();
      _creditPhone = (p['customer_phone'] ?? '').toString();
      if (p['payment_method'] != null &&
          p['payment_method'].toString().isNotEmpty) {
        _paymentMethod = p['payment_method'].toString();
      }
      _discount = double.tryParse('${p['discount']}') ?? 0;
    });
    _persistState();

    // Delete from server
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/pos/parked-sales/${p['id']}/');
    } catch (_) {}
    ref.invalidate(_parkedCountProvider);

    _snack('Resumed sale for "${p['customer_name'] ?? 'Walk-in'}"');
  }

  // ── Receipt dialog ──
  void _showReceiptDialog(Map<String, dynamic> txn) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.15),
                    const Color(0xFF10B981).withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 48),
            )
                .animate()
                .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text('Sale Completed!',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '#${txn['transaction_number'] ?? txn['id'] ?? '—'} · ${DateFormat.jm().format(DateTime.now())}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...(_cart.isEmpty
                ? ((txn['items'] as List?)?.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(
                                    '${it['quantity']}× ${it['medication_name'] ?? ''}',
                                    style: const TextStyle(fontSize: 13))),
                            Text(_fmtMoney(it['total_price']),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    )) ??
                    [])
                : _cart.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(
                                    '${c['quantity']}× ${c['name']}',
                                    style: const TextStyle(fontSize: 13))),
                            Text(
                                _fmtMoney((c['quantity'] as int) *
                                    (double.tryParse('${c['selling_price']}') ??
                                        0)),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ))),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total Paid',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(_fmtMoney(txn['total'] ?? _total),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: cs.primary)),
            ]),
            const SizedBox(height: 4),
            Text(
              'via ${_cap(txn['payment_method'] ?? _paymentMethod)}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('New Sale'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Credit dialog ──
  Future<void> _showCreditDialog() async {
    final nameCtrl = TextEditingController(text: _customerName);
    final phoneCtrl = TextEditingController(text: _creditPhone);
    final dueDateCtrl = TextEditingController(text: _creditDueDate);
    final partialCtrl =
        TextEditingController(text: _creditPartial > 0 ? _creditPartial.toStringAsFixed(0) : '');
    final refCtrl = TextEditingController(text: _creditReference);
    final notesCtrl = TextEditingController(text: _creditNotes);
    String selectedPartialMethod = _creditPartialMethod;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final cs = Theme.of(ctx).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.amber.shade800, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Credit Sale Details',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text('Capture due date & partial payment',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                        ]),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildField(nameCtrl, 'Customer Name *', Icons.person_rounded,
                    ctx,
                    cap: true, autofocus: true),
                const SizedBox(height: 12),
                _buildField(
                    phoneCtrl, 'Phone', Icons.phone_rounded, ctx,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(
                  controller: dueDateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Due Date *',
                    prefixIcon: const Icon(Icons.calendar_month_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      dueDateCtrl.text =
                          DateFormat('yyyy-MM-dd').format(picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildField(
                    partialCtrl, 'Partial Payment', Icons.attach_money_rounded,
                    ctx,
                    keyboard: TextInputType.number, suffix: 'KES'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPartialMethod,
                  decoration: InputDecoration(
                    labelText: 'Partial Payment Method',
                    prefixIcon:
                        const Icon(Icons.credit_card_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  items: _partialPaymentMethods
                      .map((m) => DropdownMenuItem(
                            value: m['value'] as String,
                            child: Text(m['label'] as String),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => selectedPartialMethod = v ?? 'none'),
                ),
                const SizedBox(height: 12),
                _buildField(
                    refCtrl, 'Reference / Account #', Icons.tag_rounded, ctx),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: const Icon(Icons.note_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Balance',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 13)),
                        Text(
                            _fmtMoney((_total -
                                    (double.tryParse(partialCtrl.text) ?? 0))
                                .clamp(0, double.infinity)),
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.primary)),
                      ]),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        if (dueDateCtrl.text.isEmpty) return;
                        Navigator.pop(ctx, true);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Details'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );

    if (confirmed == true) {
      setState(() {
        _customerName = nameCtrl.text.trim();
        _creditPhone = phoneCtrl.text.trim();
        _creditDueDate = dueDateCtrl.text;
        _creditPartial = double.tryParse(partialCtrl.text) ?? 0;
        _creditPartialMethod = _creditPartial > 0
            ? (selectedPartialMethod != 'none'
                ? selectedPartialMethod
                : 'none')
            : 'none';
        _creditReference = refCtrl.text.trim();
        _creditNotes = notesCtrl.text.trim();
      });
      _persistState();
      // Auto-checkout the credit sale
      await _checkout();
    } else if (_creditDueDate.isEmpty || _customerName.trim().isEmpty) {
      setState(() => _paymentMethod = 'cash');
      _persistState();
    }
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      BuildContext ctx,
      {TextInputType? keyboard,
      bool cap = false,
      String? suffix,
      bool autofocus = false}) {
    final cs = Theme.of(ctx).colorScheme;
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: cs.surfaceContainerLow,
      ),
      keyboardType: keyboard,
      textCapitalization: cap ? TextCapitalization.words : TextCapitalization.none,
      autofocus: autofocus,
    );
  }

  // ── Payment method sheet ──
  void _showPaymentMethodSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Payment Method',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ..._paymentMethods.map((m) {
              final val = m['value'] as String;
              final selected = val == _paymentMethod;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? cs.primaryContainer.withValues(alpha: 0.5)
                      : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() => _paymentMethod = val);
                      _persistState();
                      Navigator.pop(ctx);
                      if (val == 'credit') {
                        Future.microtask(() => _showCreditDialog());
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _paymentColor(val).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(m['icon'] as IconData,
                              color: _paymentColor(val), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text(m['label'] as String,
                                style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 15))),
                        if (selected)
                          Icon(Icons.check_circle_rounded,
                              color: cs.primary, size: 22),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ]),
        );
      },
    );
  }

  // ── Discount sheet ──
  void _showDiscountSheet() {
    final ctrl = TextEditingController(
        text: _discount > 0 ? _discount.toStringAsFixed(0) : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Apply Discount',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Subtotal: ${_fmtMoney(_subtotal)}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Discount Amount',
                prefixIcon: const Icon(Icons.discount_rounded),
                suffixText: 'KES',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
            ),
            const SizedBox(height: 12),
            // Quick percent buttons
            Row(
              children: [5, 10, 15, 20].map((pct) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      onPressed: () {
                        ctrl.text =
                            (_subtotal * pct / 100).toStringAsFixed(0);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('$pct%',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _discount = 0);
                    _persistState();
                    Navigator.pop(ctx);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    final v = double.tryParse(ctrl.text) ?? 0;
                    setState(() => _discount = v.clamp(0, _subtotal));
                    _persistState();
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = ref.watch(_productsProvider);
    final todayStats = ref.watch(_todayStatsProvider);
    final parkedCount = ref.watch(_parkedCountProvider);
    final branches = ref.watch(_branchesProvider);
    final search = ref.watch(_searchProvider);
    final catFilter = ref.watch(_categoryFilter);
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Column(children: [
        // ── Top bar ──
        _buildTopBar(cs, isDark, auth, todayStats, parkedCount, branches),
        // ── Body ──
        Expanded(
          child: products.when(
            loading: () => const Center(child: LoadingShimmer(lines: 6)),
            error: (e, _) => ErrorRetry(
              message: 'Failed to load products',
              onRetry: () => ref.invalidate(_productsProvider),
            ),
            data: (prods) => _buildBody(prods, search, catFilter, cs, isDark),
          ),
        ),
      ]),
      // ── Cart FAB ──
      floatingActionButton: _cart.isNotEmpty
          ? ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: _cartBounce, curve: Curves.elasticOut),
              ),
              child: FloatingActionButton.extended(
                onPressed: _showCartSheet,
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                icon: Badge(
                  label: Text('$_itemCount',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  backgroundColor: cs.errorContainer,
                  textColor: cs.onErrorContainer,
                  child: const Icon(Icons.shopping_cart_rounded),
                ),
                label: Text(_fmtMoney(_total),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTopBar(ColorScheme cs, bool isDark, AuthState auth,
      AsyncValue<Map<String, dynamic>> todayStats, AsyncValue<int> parkedCount,
      AsyncValue<List<Map<String, dynamic>>> branches) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row 1: title + actions
            Row(children: [
              GestureDetector(
                onTap: () => context.go('/'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 20, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.point_of_sale_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Point of Sale',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          )),
                      Text(
                        '${DateFormat('EEE, MMM d').format(DateTime.now())} · ${auth.user?.firstName ?? 'Staff'}',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ]),
              ),
              // Parked badge
              parkedCount.when(
                data: (count) => count > 0
                    ? GestureDetector(
                        onTap: _showParkedSales,
                        child: Badge(
                          label: Text('$count',
                              style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w700)),
                          backgroundColor: Colors.orange,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.pause_circle_filled_rounded,
                                size: 18, color: cs.onSurfaceVariant),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => context.go('/sales'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.history_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // Row 2: today stats + branch selector
            Row(children: [
              todayStats.when(
                data: (stats) => Row(mainAxisSize: MainAxisSize.min, children: [
                  _statChip(Icons.receipt_long_rounded, 'Today: ${stats['count']}',
                      cs.primary, cs),
                  const SizedBox(width: 8),
                  _statChip(Icons.attach_money_rounded,
                      _fmtMoney(stats['revenue']), const Color(0xFF10B981), cs),
                ]),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const Spacer(),
              // Branch selector
              branches.when(
                data: (branchList) {
                  if (branchList.length <= 1) return const SizedBox.shrink();
                  final selected = branchList.where((b) => b['id'] == _selectedBranchId).firstOrNull;
                  final label = selected != null ? (selected['name'] ?? 'Branch') : 'All branches';
                  return GestureDetector(
                    onTap: () => _showBranchSelector(branchList),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.store_rounded, size: 13, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(label,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B5CF6)),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 14, color: Color(0xFF8B5CF6)),
                      ]),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  void _showBranchSelector(List<Map<String, dynamic>> branches) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Select Branch',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            // "All branches" option
            _branchTile(ctx, cs, null, 'All Branches', null, _selectedBranchId == null),
            const SizedBox(height: 6),
            ...branches.where((b) => b['is_active'] == true).map((b) {
              final id = b['id'] as int;
              final name = (b['name'] ?? 'Branch').toString();
              final subtitle = (b['place_name'] ?? b['address'] ?? '').toString();
              final isMain = b['is_main'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _branchTile(ctx, cs, id, name, subtitle.isNotEmpty ? subtitle : null,
                    _selectedBranchId == id, isMain: isMain),
              );
            }),
          ]),
        );
      },
    );
  }

  Widget _branchTile(BuildContext ctx, ColorScheme cs, int? id, String name,
      String? subtitle, bool selected, {bool isMain = false}) {
    return Material(
      color: selected
          ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
          : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selectedBranchId = id);
          _persistState();
          Navigator.pop(ctx);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                id == null ? Icons.store_mall_directory_rounded : Icons.store_rounded,
                color: const Color(0xFF8B5CF6), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(name, style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14)),
                  if (isMain) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Main', style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: Color(0xFF059669))),
                    ),
                  ],
                ]),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF8B5CF6), size: 22),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PRODUCT GRID
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBody(List<Map<String, dynamic>> allProducts, String search,
      String? catFilter, ColorScheme cs, bool isDark) {
    // Combine with server results
    final combined = [
      ...allProducts,
      ..._serverResults.where(
          (sr) => !allProducts.any((p) => p['id'] == sr['id'])),
    ];

    // Filter
    var filtered = combined;
    if (catFilter != null) {
      filtered = filtered
          .where((p) =>
              (p['category_name'] ?? p['category'] ?? 'Other') == catFilter)
          .toList();
    }
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      filtered = filtered.where((p) {
        final name =
            (p['medication_name'] ?? p['name'] ?? '').toString().toLowerCase();
        final abbr = (p['abbreviation'] ?? '').toString().toLowerCase();
        final barcode =
            (p['barcode'] ?? p['sku'] ?? '').toString().toLowerCase();
        return name.contains(q) || abbr.contains(q) || barcode.contains(q);
      }).toList();
    }

    // Categories
    final cats = <String, int>{};
    for (final p in allProducts) {
      final c = (p['category_name'] ?? p['category'] ?? 'Other').toString();
      cats[c] = (cats[c] ?? 0) + 1;
    }

    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: TextField(
          onChanged: (v) {
            ref.read(_searchProvider.notifier).state = v;
            _onSearchChanged(v, allProducts);
          },
          decoration: InputDecoration(
            hintText: 'Search products by name or SKU…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: cs.onSurface.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ),
      // Category chips
      if (cats.isNotEmpty)
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            children: [
              _catChip('All', null, catFilter == null, cs),
              ...cats.entries.map((e) =>
                  _catChip('${e.key} (${e.value})', e.key, catFilter == e.key, cs)),
            ],
          ),
        ),
      // Product grid
      Expanded(
        child: filtered.isEmpty
            ? const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No products found',
                subtitle: 'Try a different search term or category.',
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.88,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) =>
                    _ProductCard(product: filtered[i], onTap: _addToCart),
              ),
      ),
    ]);
  }

  Widget _catChip(String label, String? value, bool selected, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant)),
        selected: selected,
        onSelected: (_) =>
            ref.read(_categoryFilter.notifier).state = selected ? null : value,
        selectedColor: cs.primary,
        checkmarkColor: cs.onPrimary,
        backgroundColor: cs.onSurface.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CART SHEET
  // ═══════════════════════════════════════════════════════════════════════

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final cs = Theme.of(ctx).colorScheme;
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child:
                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(Icons.shopping_cart_rounded, color: cs.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Sale',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            if (_customerName.isNotEmpty)
                              Text(_customerName,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant)),
                          ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$_itemCount items',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimaryContainer)),
                    ),
                  ]),
                ),
                // Customer field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _customerName = v),
                    controller:
                        TextEditingController.fromValue(TextEditingValue(
                      text: _customerName,
                      selection: TextSelection.collapsed(
                          offset: _customerName.length),
                    )),
                    decoration: InputDecoration(
                      hintText: 'Walk-in customer',
                      prefixIcon:
                          const Icon(Icons.person_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      isDense: true,
                      filled: true,
                      fillColor: cs.surfaceContainerLow,
                    ),
                    style: const TextStyle(fontSize: 13),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const Divider(height: 16),
                // Cart items
                Expanded(
                  child: _cart.isEmpty
                      ? const EmptyState(
                          icon: Icons.shopping_cart_outlined,
                          title: 'Cart is empty',
                          subtitle: 'Tap a product to start a sale.',
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _cart.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: cs.outlineVariant.withValues(alpha: 0.2)),
                          itemBuilder: (_, i) {
                            final it = _cart[i];
                            final price =
                                double.tryParse('${it['selling_price']}') ?? 0;
                            final qty = it['quantity'] as int;
                            final rx = (it['rx'] ?? 'none').toString();
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Row(children: [
                                // Product info
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Flexible(
                                            child: Text(it['name'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                          if (rx != 'none') ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: rx == 'required'
                                                    ? Colors.red.shade50
                                                    : Colors.orange.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                rx == 'required'
                                                    ? 'Rx'
                                                    : 'Rx?',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: rx == 'required'
                                                        ? Colors.red.shade700
                                                        : Colors
                                                            .orange.shade700),
                                              ),
                                            ),
                                          ],
                                        ]),
                                        Text('${_fmtMoney(price)} ea',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant)),
                                      ]),
                                ),
                                // Qty controls
                                Container(
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _qtyBtn(Icons.remove_rounded, () {
                                          _decrementItem(i);
                                          setSheetState(() {});
                                        }, cs),
                                        Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8),
                                          child: Text('$qty',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  fontSize: 13)),
                                        ),
                                        _qtyBtn(Icons.add_rounded, () {
                                          _incrementItem(i);
                                          setSheetState(() {});
                                        }, cs, primary: true),
                                      ]),
                                ),
                                const SizedBox(width: 8),
                                // Line total
                                SizedBox(
                                  width: 70,
                                  child: Text(_fmtMoney(qty * price),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ),
                                // Remove
                                IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      size: 16,
                                      color: cs.error.withValues(alpha: 0.7)),
                                  onPressed: () {
                                    _removeItem(i);
                                    setSheetState(() {});
                                    if (_cart.isEmpty) Navigator.pop(ctx);
                                  },
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                ),
                              ]),
                            );
                          },
                        ),
                ),
                // Footer
                if (_cart.isNotEmpty) _buildCartFooter(ctx, cs, isDark, setSheetState),
              ]),
            ),
          );
        });
      },
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, ColorScheme cs,
      {bool primary = false}) {
    return Material(
      color: primary ? cs.primary.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 16, color: primary ? cs.primary : cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildCartFooter(
      BuildContext ctx, ColorScheme cs, bool isDark, StateSetter setSheetState) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Subtotal
        _summaryRow('Subtotal', _fmtMoney(_subtotal), cs),
        const SizedBox(height: 4),
        // Discount
        InkWell(
          onTap: () {
            Navigator.pop(ctx);
            _showDiscountSheet();
          },
          child: _summaryRow(
            'Discount',
            _discount > 0 ? '- ${_fmtMoney(_discount)}' : _fmtMoney(0),
            cs,
            valueColor: _discount > 0 ? Colors.red : null,
            trailing: Icon(Icons.edit_rounded,
                size: 13, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 4),
        _summaryRow('VAT (incl. 16%)', _fmtMoney(_tax), cs),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(_fmtMoney(_total),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary)),
        ]),
        const SizedBox(height: 12),
        // Payment method selector
        InkWell(
          onTap: () {
            Navigator.pop(ctx);
            _showPaymentMethodSheet();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(_paymentIcon(_paymentMethod),
                  size: 18, color: _paymentColor(_paymentMethod)),
              const SizedBox(width: 10),
              Text(
                  _paymentMethods
                      .firstWhere(
                          (m) => m['value'] == _paymentMethod)['label'] as String,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ]),
          ),
        ),
        // Credit info banner
        if (_isCredit) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Text('Credit sale',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.amber.shade900)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCreditDialog();
                      },
                      child: Text('Edit',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.primary)),
                    ),
                  ]),
                  if (_creditDueDate.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_customerName.isEmpty ? 'Customer' : _customerName} · Due: $_creditDueDate'
                        '${_creditPartial > 0 ? ' · Partial: ${_fmtMoney(_creditPartial)}' : ''}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.amber.shade800),
                      ),
                    ),
                  if (!_creditValid)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Customer name and due date are required',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red.shade700)),
                    ),
                ]),
          ),
        ],
        const SizedBox(height: 12),
        // Action buttons
        Row(children: [
          // Hold
          SizedBox(
            height: 48,
            width: 44,
            child: IconButton.outlined(
              onPressed: () {
                Navigator.pop(ctx);
                _holdSale();
              },
              icon: const Icon(Icons.pause_circle_filled_rounded, size: 20),
              tooltip: 'Hold Sale',
              style: IconButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Clear
          SizedBox(
            height: 48,
            width: 44,
            child: IconButton.outlined(
              onPressed: () {
                Navigator.pop(ctx);
                _clearCart();
              },
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: cs.error),
              tooltip: 'Clear Cart',
              style: IconButton.styleFrom(
                side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Checkout
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed:
                    _cart.isNotEmpty && _creditValid && !_checkingOut
                        ? () {
                            Navigator.pop(ctx);
                            _checkout();
                          }
                        : null,
                icon: _checkingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.shopping_cart_checkout_rounded,
                        size: 18),
                label: Text(
                    _isCredit
                        ? 'Credit ${_fmtMoney(_total)}'
                        : 'Charge ${_fmtMoney(_total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, ColorScheme cs,
      {Color? valueColor, Widget? trailing}) {
    return Row(children: [
      Text(label,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? cs.onSurface)),
      if (trailing != null) ...[const SizedBox(width: 4), trailing],
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRODUCT CARD
// ═══════════════════════════════════════════════════════════════════════════

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final ValueChanged<Map<String, dynamic>> onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name =
        (product['medication_name'] ?? product['name'] ?? 'Unnamed').toString();
    final price = double.tryParse('${product['selling_price']}') ?? 0;
    final stock =
        (product['total_quantity'] ?? product['quantity'] ?? 0) as num;
    final isOut = stock <= 0;
    final isLow = !isOut && stock <= (product['reorder_level'] ?? 0);
    final rx =
        (product['prescription_required'] ?? 'none').toString().toLowerCase();
    final abbr = (product['abbreviation'] ?? '').toString();
    final category = (product['category_name'] ?? product['category'] ?? '').toString();

    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final headerBg = isDark ? const Color(0xFF252538) : const Color(0xFFF8F9FB);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isOut ? null : () => onTap(product),
        splashColor: cs.primary.withValues(alpha: 0.1),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: Opacity(
          opacity: isOut ? 0.5 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              border: Border.all(
                color: isOut
                    ? cs.error.withValues(alpha: 0.25)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE8ECF0),
              ),
              boxShadow: isOut
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Column(children: [
              // ── Top: Header with medicine icon ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  color: headerBg,
                ),
                child: Column(children: [
                  // Badges row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Stock badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOut
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : isLow
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                  : const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOut ? 'OUT' : isLow ? 'LOW · $stock' : '$stock in stock',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: isOut
                                ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                : isLow
                                    ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706))
                                    : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669)),
                          ),
                        ),
                      ),
                      // Rx badges
                      if (rx == 'required')
                        _rxBadge('Rx', Colors.red, isDark)
                      else if (rx == 'recommended')
                        _rxBadge('Rx?', Colors.orange, isDark),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Medicine icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      size: 24,
                      color: cs.primary,
                    ),
                  ),
                ]),
              ),
              // ── Bottom: Info section ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: isDark ? const Color(0xFFF0F0F5) : const Color(0xFF111118),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      // Category / abbreviation
                      if (abbr.isNotEmpty || category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            abbr.isNotEmpty ? abbr : category,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const Spacer(),
                      // Price row
                      Row(children: [
                        Expanded(
                          child: Text(
                            _fmtMoney(price),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isOut
                                ? cs.surfaceContainerHighest
                                : cs.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isOut ? Icons.block_rounded : Icons.add_rounded,
                            size: 16,
                            color: isOut ? cs.onSurfaceVariant : cs.primary,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _rxBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.medical_information_rounded, size: 9, color: color.shade700),
        const SizedBox(width: 2),
        Text(text,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: color.shade700)),
      ]),
    );
  }
}

extension _ColorShade on Color {
  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness * 0.6).clamp(0, 1)).toColor();
  }
}
