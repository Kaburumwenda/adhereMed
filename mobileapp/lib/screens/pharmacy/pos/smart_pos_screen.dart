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
import '../inventory/barcode_scanner_dialog.dart';

const _kSmartPosKey = 'smart_pos_state_v1';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final _smartProductsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/stocks/',
      queryParameters: {'page_size': 5000, 'is_active': true});
  final data = res.data;
  final list = data is List ? data : (data?['results'] as List?) ?? [];
  return List<Map<String, dynamic>>.from(list);
});

final _smartStatsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/transactions/',
      queryParameters: {'page_size': 500});
  final data = res.data;
  final list = data is List ? data : (data?['results'] as List?) ?? [];
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final todayTx = list
      .where((t) => (t['created_at'] ?? '').toString().startsWith(today))
      .toList();
  return {
    'count': todayTx.length,
    'revenue': todayTx.fold<double>(
        0, (s, t) => s + (double.tryParse('${t['total']}') ?? 0)),
  };
});

final _smartParkedProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/parked-sales/',
      queryParameters: {'page_size': 1});
  final data = res.data;
  if (data is Map && data['count'] != null) return data['count'] as int;
  return 0;
});

final _smartBranchesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pharmacy-profile/branches/');
  final data = res.data;
  final list = data is List ? data : (data?['results'] as List?) ?? [];
  return List<Map<String, dynamic>>.from(list);
});

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

String _fmt(dynamic v) {
  final n = double.tryParse('$v') ?? 0;
  return NumberFormat.currency(symbol: 'KES ', decimalDigits: 0).format(n);
}

Color _pmColor(String? m) => switch (m?.toLowerCase()) {
      'cash' => const Color(0xFF10B981),
      'mpesa' => const Color(0xFF059669),
      'card' => const Color(0xFF3B82F6),
      'insurance' => const Color(0xFFF59E0B),
      'credit' => const Color(0xFFEC4899),
      _ => const Color(0xFF6B7280),
    };

IconData _pmIcon(String? m) => switch (m?.toLowerCase()) {
      'cash' => Icons.payments_rounded,
      'mpesa' => Icons.phone_android_rounded,
      'card' => Icons.credit_card_rounded,
      'insurance' => Icons.health_and_safety_rounded,
      'credit' => Icons.account_balance_wallet_rounded,
      _ => Icons.payment_rounded,
    };

const _payMethods = [
  {'value': 'cash', 'label': 'Cash', 'icon': Icons.payments_rounded},
  {'value': 'mpesa', 'label': 'M-Pesa', 'icon': Icons.phone_android_rounded},
  {'value': 'card', 'label': 'Card', 'icon': Icons.credit_card_rounded},
  {
    'value': 'insurance',
    'label': 'Insurance',
    'icon': Icons.health_and_safety_rounded
  },
  {
    'value': 'credit',
    'label': 'Credit',
    'icon': Icons.account_balance_wallet_rounded
  },
];

// ═══════════════════════════════════════════════════════════════════════════
//  SMART POS SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class SmartPOSScreen extends ConsumerStatefulWidget {
  const SmartPOSScreen({super.key});
  @override
  ConsumerState<SmartPOSScreen> createState() => _SmartPOSScreenState();
}

class _SmartPOSScreenState extends ConsumerState<SmartPOSScreen> {
  final List<Map<String, dynamic>> _cart = [];
  String _paymentMethod = 'cash';
  String _customerName = '';
  double _discount = 0;
  bool _checkingOut = false;
  int? _selectedBranchId;

  // Credit
  String _creditPhone = '';
  String _creditDueDate = '';
  double _creditPartial = 0;
  String _creditPartialMethod = 'none';
  String _creditReference = '';
  String _creditNotes = '';

  // Search
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _serverResults = [];
  Timer? _serverSearchTimer;
  bool _searchOpen = false;
  int _activeIdx = 0;

  // Flash animation for newly added items
  final Set<int> _flashIds = {};

  @override
  void initState() {
    super.initState();
    _restoreState();
    _scanCtrl.addListener(_onScanChanged);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _serverSearchTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSmartPosKey);
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
        _creditPartialMethod =
            (s['creditPartialMethod'] as String?) ?? 'none';
        _creditReference = (s['creditReference'] as String?) ?? '';
        _creditNotes = (s['creditNotes'] as String?) ?? '';
        _selectedBranchId = s['branchId'] as int?;
      });
    } catch (_) {}
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kSmartPosKey,
        jsonEncode({
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
    await prefs.remove(_kSmartPosKey);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  COMPUTED
  // ═══════════════════════════════════════════════════════════════════════

  int get _itemCount =>
      _cart.fold<int>(0, (s, it) => s + ((it['quantity'] as int?) ?? 1));

  double get _subtotal => _cart.fold<double>(
      0,
      (s, it) =>
          s +
          (double.tryParse('${it['selling_price']}') ?? 0) *
              ((it['quantity'] as int?) ?? 1));

  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  bool get _creditValid {
    if (_paymentMethod != 'credit') return true;
    return _customerName.isNotEmpty && _creditDueDate.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SEARCH / SCAN
  // ═══════════════════════════════════════════════════════════════════════

  void _onScanChanged() {
    final q = _scanCtrl.text.trim().toLowerCase();
    _activeIdx = 0;
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchOpen = false;
      });
      return;
    }
    setState(() => _searchOpen = true);

    final products = ref.read(_smartProductsProvider).valueOrNull ?? [];
    final local = products.where((p) {
      final name = (p['medication_name'] ?? p['name'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      final barcode = (p['barcode'] ?? '').toString().toLowerCase();
      final abbr = (p['abbreviation'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          sku.contains(q) ||
          barcode.contains(q) ||
          abbr.contains(q);
    }).take(8).toList();

    setState(() => _searchResults = [...local, ..._serverResults]);

    // Server fallback if local < 4
    _serverSearchTimer?.cancel();
    if (local.length < 4 && q.length >= 2) {
      _serverSearchTimer = Timer(const Duration(milliseconds: 400), () async {
        try {
          final dio = ref.read(dioProvider);
          final res = await dio.get('/inventory/stocks/',
              queryParameters: {'search': q, 'page_size': 10, 'is_active': true});
          final data = res.data;
          final list = data is List
              ? data
              : (data?['results'] as List?) ?? [];
          final existing = local.map((p) => p['id']).toSet();
          final extra = list
              .where((p) => !existing.contains(p['id']))
              .take(6)
              .toList();
          if (mounted && _scanCtrl.text.trim().toLowerCase() == q) {
            setState(() {
              _serverResults = List<Map<String, dynamic>>.from(extra);
              _searchResults = [...local, ..._serverResults];
            });
          }
        } catch (_) {}
      });
    }
  }

  void _handleScan() {
    final code = _scanCtrl.text.trim();
    if (code.isEmpty) return;

    final products = ref.read(_smartProductsProvider).valueOrNull ?? [];

    // Exact barcode/SKU match first
    final exact = products.where((p) {
      final barcode = (p['barcode'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      return barcode == code.toLowerCase() || sku == code.toLowerCase();
    }).firstOrNull;

    if (exact != null) {
      _addToCart(exact);
      _clearSearch();
      return;
    }

    // Fallback: first search result
    if (_searchResults.isNotEmpty) {
      final pick = _searchResults[_activeIdx.clamp(0, _searchResults.length - 1)];
      _addToCart(pick);
      _clearSearch();
      return;
    }

    _snack('No product matches "$code"', isError: true);
  }

  void _clearSearch() {
    _scanCtrl.clear();
    _serverResults.clear();
    setState(() {
      _searchResults = [];
      _searchOpen = false;
      _activeIdx = 0;
    });
    _scanFocus.requestFocus();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CART
  // ═══════════════════════════════════════════════════════════════════════

  void _addToCart(Map<String, dynamic> product) {
    final id = product['id'];
    final stock = int.tryParse('${product['total_quantity']}') ?? 0;
    if (stock <= 0) {
      _snack('${product['medication_name'] ?? product['name']} is out of stock',
          isError: true);
      return;
    }
    final idx = _cart.indexWhere((c) => c['id'] == id);
    if (idx >= 0) {
      final maxQty = _cart[idx]['max_qty'] as int? ?? 9999;
      if ((_cart[idx]['quantity'] as int) >= maxQty) {
        _snack('Stock limit reached', isError: true);
        return;
      }
      setState(() => _cart[idx]['quantity'] = (_cart[idx]['quantity'] as int) + 1);
    } else {
      setState(() {
        _cart.insert(0, {
          'id': id,
          'name': product['medication_name'] ?? product['name'] ?? 'Item',
          'sku': product['sku'] ?? '',
          'category': product['category_name'] ?? product['category'] ?? '',
          'selling_price': product['selling_price'],
          'quantity': 1,
          'max_qty': stock,
        });
        _flashIds.add(id);
        Future.delayed(600.ms, () {
          if (mounted) setState(() => _flashIds.remove(id));
        });
      });
    }
    _persistState();
    HapticFeedback.lightImpact();
  }

  void _incrementItem(int idx) {
    final maxQty = _cart[idx]['max_qty'] as int? ?? 9999;
    if ((_cart[idx]['quantity'] as int) >= maxQty) return;
    setState(() => _cart[idx]['quantity'] = (_cart[idx]['quantity'] as int) + 1);
    _persistState();
  }

  void _decrementItem(int idx) {
    if ((_cart[idx]['quantity'] as int) <= 1) {
      _removeItem(idx);
      return;
    }
    setState(
        () => _cart[idx]['quantity'] = (_cart[idx]['quantity'] as int) - 1);
    _persistState();
  }

  void _removeItem(int idx) {
    setState(() => _cart.removeAt(idx));
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
    _scanFocus.requestFocus();
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

  // ═══════════════════════════════════════════════════════════════════════
  //  CHECKOUT
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _checkout() async {
    if (_cart.isEmpty || _checkingOut) return;
    if (!_creditValid) {
      _snack('Customer name and due date required for credit', isError: true);
      return;
    }
    setState(() => _checkingOut = true);
    try {
      final dio = ref.read(dioProvider);
      final items = _cart
          .map((it) {
            return {'stock_id': it['id'], 'quantity': it['quantity']};
          })
          .toList();
      final payload = <String, dynamic>{
        'payment_method': _paymentMethod,
        'customer_name': _customerName.isEmpty ? 'Walk-in' : _customerName,
        'discount': _discount,
        'items': items,
        if (_selectedBranchId != null) 'branch_id': _selectedBranchId,
      };
      if (_paymentMethod == 'credit') {
        payload['customer_phone'] = _creditPhone;
        payload['credit_due_date'] = _creditDueDate;
        payload['credit_notes'] = _creditNotes;
        if (_creditPartial > 0 && _creditPartialMethod != 'none') {
          payload['partial_paid_amount'] = _creditPartial;
          payload['partial_payment_method'] = _creditPartialMethod;
        }
        if (_creditReference.isNotEmpty) {
          payload['payment_reference'] = _creditReference;
        }
      }
      final res = await dio.post('/pos/transactions/', data: payload);
      final txn = res.data as Map<String, dynamic>;
      _showReceiptDialog(txn);
      _clearCart();
      ref.invalidate(_smartProductsProvider);
      ref.invalidate(_smartStatsProvider);
      ref.invalidate(_smartParkedProvider);
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

  // ═══════════════════════════════════════════════════════════════════════
  //  HOLD SALE
  // ═══════════════════════════════════════════════════════════════════════

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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12)),
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
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$_itemCount items · ${_fmt(_total)}',
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                          borderRadius: BorderRadius.circular(12))),
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
                          borderRadius: BorderRadius.circular(12))),
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
                'selling_price':
                    double.tryParse('${it['selling_price']}') ?? 0,
                'quantity': it['quantity'],
                'max_qty': it['max_qty'] ?? 9999,
              };
            })
            .toList(),
      });
      _snack('Sale held under "${nameCtrl.text.trim()}"');
      _clearCart();
      ref.invalidate(_smartParkedProvider);
    } catch (e) {
      _snack('Failed to hold sale', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PARKED SALES
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _showParkedSales() async {
    final dio = ref.read(dioProvider);
    List<Map<String, dynamic>> parked = [];
    try {
      final res = await dio.get('/pos/parked-sales/',
          queryParameters: {'page_size': 200});
      final data = res.data;
      final list = data is List ? data : (data?['results'] as List?) ?? [];
      parked = List<Map<String, dynamic>>.from(list);
    } catch (_) {}
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
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
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12)),
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
                          Text('${parked.length} sale(s) on hold',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                        ]),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: parked.isEmpty
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
                          ]))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: parked.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = parked[i];
                          final items = (p['items'] as List?) ?? [];
                          final total =
                              double.tryParse('${p['total']}') ?? 0;
                          final name =
                              (p['customer_name'] ?? 'Walk-in').toString();
                          final parkNum =
                              (p['park_number'] ?? '').toString();
                          final createdAt = p['created_at'] != null
                              ? DateTime.tryParse(
                                  p['created_at'].toString())
                              : null;
                          final timeStr = createdAt != null
                              ? DateFormat('MMM d, h:mm a')
                                  .format(createdAt.toLocal())
                              : '';

                          return Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: cs.outlineVariant
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Column(children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 14, 16, 10),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.orange.withValues(alpha: 0.06),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                ),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Text(parkNum,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: Colors
                                                        .orange.shade700)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                              ),
                                              child: Text(
                                                  '${items.length} items',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.orange
                                                          .shade800)),
                                            ),
                                          ]),
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            Icon(Icons.person_rounded,
                                                size: 14,
                                                color: cs.primary),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13),
                                                  overflow: TextOverflow
                                                      .ellipsis),
                                            ),
                                            if (timeStr.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text('· $timeStr',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: cs
                                                          .onSurfaceVariant)),
                                            ],
                                          ]),
                                        ]),
                                  ),
                                  Text(_fmt(total),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: cs.primary)),
                                ]),
                              ),
                              // Items preview
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 4),
                                child: Column(children: [
                                  ...items.take(3).map((it) {
                                    final qty = it['quantity'] ?? 1;
                                    final price = double.tryParse(
                                            '${it['selling_price']}') ??
                                        0;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 3),
                                      child: Row(children: [
                                        Expanded(
                                          child: Text(
                                              '$qty × ${it['name'] ?? 'Item'}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.onSurface),
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        ),
                                        Text(_fmt(price * qty),
                                            style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    cs.onSurfaceVariant)),
                                      ]),
                                    );
                                  }),
                                  if (items.length > 3)
                                    Text(
                                        '+ ${items.length - 3} more item(s)',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant
                                                .withValues(alpha: 0.7))),
                                ]),
                              ),
                              // Actions
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 4, 12, 12),
                                child: Row(children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _resumeParkedSale(p);
                                      },
                                      icon: const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 18),
                                      label: const Text('Resume'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF10B981),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
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
                                            await showDialog<bool>(
                                          context: ctx,
                                          builder: (dlg) => AlertDialog(
                                            title: const Text(
                                                'Delete parked sale?'),
                                            content: Text(
                                                'Remove $parkNum for $name?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dlg, false),
                                                  child:
                                                      const Text('Cancel')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dlg, true),
                                                  style:
                                                      FilledButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red),
                                                  child:
                                                      const Text('Delete')),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await dio.delete(
                                                '/pos/parked-sales/${p['id']}/');
                                            setSheet(() =>
                                                parked.removeAt(i));
                                            ref.invalidate(
                                                _smartParkedProvider);
                                            _snack('Parked sale deleted');
                                          } catch (_) {
                                            _snack('Failed to delete',
                                                isError: true);
                                          }
                                        }
                                      },
                                      icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: cs.error,
                                          size: 20),
                                      style: IconButton.styleFrom(
                                        backgroundColor: cs.error
                                            .withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
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
        });
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
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/pos/parked-sales/${p['id']}/');
    } catch (_) {}
    ref.invalidate(_smartParkedProvider);
    _snack('Resumed sale for "${p['customer_name'] ?? 'Walk-in'}"');
    _scanFocus.requestFocus();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  RECEIPT
  // ═══════════════════════════════════════════════════════════════════════

  void _showReceiptDialog(Map<String, dynamic> txn) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 48),
            ),
            const SizedBox(height: 16),
            Text('Sale Complete!',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('#${txn['receipt_number'] ?? txn['id']}',
                style:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                _receiptRow(
                    'Customer', txn['customer_name'] ?? 'Walk-in', cs),
                _receiptRow(
                    'Payment', (txn['payment_method'] ?? '').toString().toUpperCase(), cs),
                _receiptRow('Total', _fmt(txn['total']), cs,
                    bold: true),
                if ((double.tryParse('${txn['change_amount']}') ?? 0) > 0)
                  _receiptRow(
                      'Change', _fmt(txn['change_amount']), cs),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _scanFocus.requestFocus();
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('NEW SALE'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, ColorScheme cs,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CREDIT DIALOG
  // ═══════════════════════════════════════════════════════════════════════

  void _showCreditDialog() {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: _customerName);
    final phoneCtrl = TextEditingController(text: _creditPhone);
    final dueDateCtrl = TextEditingController(text: _creditDueDate);
    final partialCtrl =
        TextEditingController(text: _creditPartial > 0 ? '$_creditPartial' : '');
    final refCtrl = TextEditingController(text: _creditReference);
    final notesCtrl = TextEditingController(text: _creditNotes);
    String partialMethod = _creditPartialMethod;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
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
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('Credit Sale Details',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Customer Name *',
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dueDateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Due Date *',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 7)),
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
                TextField(
                  controller: partialCtrl,
                  decoration: InputDecoration(
                    labelText: 'Partial Payment (optional)',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: partialMethod,
                  decoration: InputDecoration(
                    labelText: 'Partial Payment Method',
                    prefixIcon: const Icon(Icons.payment_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(
                        value: 'insurance', child: Text('Insurance')),
                  ],
                  onChanged: (v) => setSheet(() => partialMethod = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: 'Payment Reference (optional)',
                    prefixIcon: const Icon(Icons.receipt_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                ),
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
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Cancel')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _customerName = nameCtrl.text.trim();
                          _creditPhone = phoneCtrl.text.trim();
                          _creditDueDate = dueDateCtrl.text.trim();
                          _creditPartial =
                              double.tryParse(partialCtrl.text) ?? 0;
                          _creditPartialMethod = partialMethod;
                          _creditReference = refCtrl.text.trim();
                          _creditNotes = notesCtrl.text.trim();
                          _paymentMethod = 'credit';
                        });
                        _persistState();
                        Navigator.pop(ctx);
                        if (_creditValid) _checkout();
                      },
                      style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Confirm Credit'),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  TENDER DIALOG (Cash checkout with change calculation)
  // ═══════════════════════════════════════════════════════════════════════

  void _showTenderDialog() {
    if (_cart.isEmpty) return;
    final cs = Theme.of(context).colorScheme;
    final amountCtrl = TextEditingController(text: _total.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final tendered = double.tryParse(amountCtrl.text) ?? 0;
          final change = tendered - _total;

          // Quick tender amounts
          final quickAmounts = <int>[];
          for (final base in [50, 100, 200, 500, 1000, 2000, 5000]) {
            if (base >= _total) quickAmounts.add(base);
          }
          // Round up to nearest 100, 500, 1000
          final roundUp100 = ((_total / 100).ceil() * 100);
          final roundUp500 = ((_total / 500).ceil() * 500);
          final roundUp1000 = ((_total / 1000).ceil() * 1000);
          for (final r in [roundUp100, roundUp500, roundUp1000]) {
            if (r >= _total && !quickAmounts.contains(r)) {
              quickAmounts.add(r.toInt());
            }
          }
          quickAmounts.sort();
          final displayQuick = quickAmounts.take(4).toList();

          bool canCharge = false;
          if (_paymentMethod == 'cash') {
            canCharge = change >= 0;
          } else if (_paymentMethod == 'credit') {
            canCharge = _creditValid;
          } else {
            canCharge = true;
          }

          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.point_of_sale_rounded,
                      color: cs.onPrimaryContainer, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tender',
                            style: Theme.of(ctx)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text('$_itemCount items · ${_fmt(_total)}',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12)),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _pmColor(_paymentMethod).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_pmIcon(_paymentMethod),
                        size: 14, color: _pmColor(_paymentMethod)),
                    const SizedBox(width: 4),
                    Text(
                        _paymentMethod[0].toUpperCase() +
                            _paymentMethod.substring(1),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _pmColor(_paymentMethod))),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),

              // Total due
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Text('TOTAL DUE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 1)),
                  Text(_fmt(_total),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: cs.primary)),
                ]),
              ),
              const SizedBox(height: 16),

              if (_paymentMethod == 'cash') ...[
                // Amount tendered input
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Amount Tendered',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  onChanged: (_) => setSheet(() {}),
                ),
                const SizedBox(height: 12),

                // Quick tender buttons
                if (displayQuick.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Exact
                      ActionChip(
                        label: Text('EXACT',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                        avatar: Icon(Icons.check_rounded,
                            size: 16, color: cs.primary),
                        onPressed: () {
                          amountCtrl.text =
                              _total.toStringAsFixed(0);
                          setSheet(() {});
                        },
                      ),
                      ...displayQuick.map((a) => ActionChip(
                            label: Text(_fmt(a),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            onPressed: () {
                              amountCtrl.text = '$a';
                              setSheet(() {});
                            },
                          )),
                    ],
                  ),
                const SizedBox(height: 16),

                // Change display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: change >= 0
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: change >= 0
                            ? const Color(0xFF10B981)
                            : Colors.red,
                        width: 1.5),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(change >= 0 ? 'CHANGE' : 'SHORT',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: change >= 0
                                    ? const Color(0xFF10B981)
                                    : Colors.red)),
                        Text(_fmt(change.abs()),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: change >= 0
                                    ? const Color(0xFF10B981)
                                    : Colors.red)),
                      ]),
                ),
              ],
              const SizedBox(height: 20),

              // Action buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: canCharge && !_checkingOut
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
                        : const Icon(Icons.check_circle_rounded),
                    label: const Text('COMPLETE SALE'),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ]),
            ]),
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  DISCOUNT SHEET
  // ═══════════════════════════════════════════════════════════════════════

  void _showDiscountSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Quick Discount',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [0, 5, 10, 15, 20].map((pct) {
                final amount = _subtotal * pct / 100;
                final selected = (_discount - amount).abs() < 0.01;
                return ChoiceChip(
                  label: Text('$pct%',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : null)),
                  selected: selected,
                  selectedColor: cs.primary,
                  onSelected: (_) {
                    setState(() => _discount = amount);
                    _persistState();
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Custom amount',
                prefixIcon: const Icon(Icons.edit_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
              onSubmitted: (v) {
                final amt = double.tryParse(v) ?? 0;
                setState(() => _discount = amt.clamp(0, _subtotal));
                _persistState();
                Navigator.pop(ctx);
              },
            ),
          ]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BRANCH SELECTOR
  // ═══════════════════════════════════════════════════════════════════════

  void _showBranchSelector(List<Map<String, dynamic>> branches) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Select Branch',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _branchTile(ctx, cs, null, 'All Branches', null,
                _selectedBranchId == null),
            const SizedBox(height: 6),
            ...branches
                .where((b) => b['is_active'] == true)
                .map((b) {
              final id = b['id'] as int;
              final name = (b['name'] ?? 'Branch').toString();
              final subtitle =
                  (b['place_name'] ?? b['address'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _branchTile(
                    ctx,
                    cs,
                    id,
                    name,
                    subtitle.isNotEmpty ? subtitle : null,
                    _selectedBranchId == id,
                    isMain: b['is_main'] == true),
              );
            }),
          ]),
        );
      },
    );
  }

  Widget _branchTile(BuildContext ctx, ColorScheme cs, int? id, String name,
      String? subtitle, bool selected,
      {bool isMain = false}) {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color:
                      const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  id == null
                      ? Icons.store_mall_directory_rounded
                      : Icons.store_rounded,
                  color: const Color(0xFF8B5CF6),
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(name,
                          style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 14)),
                      if (isMain) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('Main',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669))),
                        ),
                      ],
                    ]),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = ref.watch(_smartProductsProvider);
    final stats = ref.watch(_smartStatsProvider);
    final parkedCount = ref.watch(_smartParkedProvider);
    final branches = ref.watch(_smartBranchesProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F17) : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(cs, isDark, auth, stats, parkedCount, branches),
          _buildScanBar(cs, isDark, products),
          Expanded(
            child: _cart.isEmpty
                ? _buildIdleHero(cs, isDark)
                : _buildCartList(cs, isDark),
          ),
          if (_cart.isNotEmpty) _buildFooter(cs, isDark),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTopBar(
      ColorScheme cs,
      bool isDark,
      AuthState auth,
      AsyncValue<Map<String, dynamic>> stats,
      AsyncValue<int> parkedCount,
      AsyncValue<List<Map<String, dynamic>>> branches) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // Row 1: back, title, actions
        Row(children: [
          GestureDetector(
            onTap: () => context.go('/'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_back_rounded,
                  size: 18, color: cs.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.flash_on_rounded,
                        size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text('Smart POS',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: cs.onSurface)),
                  ]),
                  Text(
                    '${DateFormat('EEE, MMM d').format(DateTime.now())} · ${auth.user?.firstName ?? 'Staff'}',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
                            borderRadius: BorderRadius.circular(10)),
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
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.receipt_long_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // Row 2: today stats + branch
        Row(children: [
          stats.when(
            data: (s) => Row(mainAxisSize: MainAxisSize.min, children: [
              _chip(Icons.receipt_long_rounded, 'Today: ${s['count']}',
                  cs.primary),
              const SizedBox(width: 8),
              _chip(Icons.attach_money_rounded, _fmt(s['revenue']),
                  const Color(0xFF10B981)),
            ]),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Spacer(),
          branches.when(
            data: (bl) {
              if (bl.length <= 1) return const SizedBox.shrink();
              final sel =
                  bl.where((b) => b['id'] == _selectedBranchId).firstOrNull;
              final label = sel != null
                  ? (sel['name'] ?? 'Branch')
                  : 'All branches';
              return GestureDetector(
                onTap: () => _showBranchSelector(bl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color:
                          const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.store_rounded,
                        size: 13, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SCAN BAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildScanBar(
      ColorScheme cs, bool isDark, AsyncValue<List<Map<String, dynamic>>> products) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Scan input
        Row(children: [
          Expanded(
            child: TextField(
              controller: _scanCtrl,
              focusNode: _scanFocus,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Scan barcode or type name / SKU...',
                hintStyle:
                    TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.qr_code_scanner_rounded,
                    color: cs.primary, size: 22),
                suffixIcon: _scanCtrl.text.isNotEmpty
                    ? IconButton(
                        icon:
                            const Icon(Icons.close_rounded, size: 20),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E1E2E)
                    : cs.surfaceContainerLow,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _handleScan(),
              onTap: () {
                if (_scanCtrl.text.trim().isNotEmpty) {
                  setState(() => _searchOpen = true);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: () async {
                final result = await showBarcodeScannerDialog(context);
                if (result != null && mounted) {
                  _scanCtrl.text = result;
                  _handleScan();
                }
              },
              icon: Icon(Icons.camera_alt_rounded, color: cs.onPrimaryContainer, size: 22),
              tooltip: 'Scan with camera',
            ),
          ),
        ]),

        // Dropdown results
        if (_searchOpen && _searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.3)),
              itemBuilder: (_, i) {
                final p = _searchResults[i];
                final name =
                    (p['medication_name'] ?? p['name'] ?? '').toString();
                final sku = (p['sku'] ?? '').toString();
                final barcode = (p['barcode'] ?? '').toString();
                final price =
                    double.tryParse('${p['selling_price']}') ?? 0;
                final stock = int.tryParse(
                        '${p['total_quantity']}') ??
                    0;
                final isOut = stock <= 0;
                final isActive = i == _activeIdx;

                return Material(
                  color: isActive
                      ? cs.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: isOut
                        ? null
                        : () {
                            _addToCart(p);
                            _clearSearch();
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isOut
                                ? Colors.grey.withValues(alpha: 0.15)
                                : cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.medication_rounded,
                            size: 18,
                            color: isOut
                                ? Colors.grey
                                : cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isOut
                                            ? cs.onSurfaceVariant
                                            : cs.onSurface),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Row(children: [
                                  if (sku.isNotEmpty)
                                    Text('SKU: $sku',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                cs.onSurfaceVariant)),
                                  if (sku.isNotEmpty &&
                                      barcode.isNotEmpty)
                                    Text(' · ',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                cs.onSurfaceVariant)),
                                  if (barcode.isNotEmpty)
                                    Text(barcode,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                cs.onSurfaceVariant)),
                                ]),
                              ]),
                        ),
                        const SizedBox(width: 8),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_fmt(price),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: isOut
                                          ? Colors.grey
                                          : const Color(0xFF10B981))),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : const Color(0xFF10B981)
                                          .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(
                                    isOut ? 'Out' : '$stock in stock',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: isOut
                                            ? Colors.red
                                            : const Color(0xFF10B981))),
                              ),
                            ]),
                        if (!isOut)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.add_circle_rounded,
                                color: cs.primary, size: 22),
                          ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  IDLE HERO (empty cart)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildIdleHero(ColorScheme cs, bool isDark) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child:
              Icon(Icons.qr_code_scanner_rounded, size: 64, color: cs.primary),
        ),
        const SizedBox(height: 24),
        Text('Ready to Scan',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface)),
        const SizedBox(height: 8),
        Text('Scan a barcode or search by name / SKU',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        const SizedBox(height: 32),
        // Quick hints
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _hintChip(Icons.qr_code_scanner_rounded, 'Scan barcode', cs),
            _hintChip(Icons.search_rounded, 'Search by name', cs),
            _hintChip(Icons.tag_rounded, 'Search by SKU', cs),
          ],
        ),
      ]).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
    );
  }

  Widget _hintChip(IconData icon, String label, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CART LIST
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCartList(ColorScheme cs, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _cart.length,
      itemBuilder: (_, i) {
        final it = _cart[i];
        final name = (it['name'] ?? '').toString();
        final price = double.tryParse('${it['selling_price']}') ?? 0;
        final qty = (it['quantity'] as int?) ?? 1;
        final lineTotal = price * qty;
        final isFlashing = _flashIds.contains(it['id']);

        return Dismissible(
          key: ValueKey('${it['id']}_$i'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _removeItem(i),
          background: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isFlashing
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: isFlashing
                  ? Border.all(
                      color:
                          const Color(0xFF10B981).withValues(alpha: 0.4))
                  : null,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              // Product info
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${_fmt(price)} each',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
              ),
              // Qty stepper
              Container(
                decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      onPressed: () => _decrementItem(i),
                      icon: const Icon(Icons.remove_rounded, size: 16),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('$qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      onPressed: () => _incrementItem(i),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ]),
              ),
              // Line total
              SizedBox(
                width: 80,
                child: Text(_fmt(lineTotal),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.primary)),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  FOOTER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFooter(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4))
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Summary rows
        _summaryRow('Subtotal', _fmt(_subtotal), cs),
        if (_discount > 0) _summaryRow('Discount', '-${_fmt(_discount)}', cs, color: Colors.red),
        _summaryRow('Total', _fmt(_total), cs,
            bold: true, fontSize: 18),
        const SizedBox(height: 12),
        // Payment + Discount row
        Row(children: [
          // Payment method selector
          Expanded(
            child: GestureDetector(
              onTap: () => _showPaymentMethodPicker(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _pmColor(_paymentMethod).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _pmColor(_paymentMethod).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(_pmIcon(_paymentMethod),
                      size: 16, color: _pmColor(_paymentMethod)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        _paymentMethod[0].toUpperCase() +
                            _paymentMethod.substring(1),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: _pmColor(_paymentMethod)),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: _pmColor(_paymentMethod)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Discount button
          GestureDetector(
            onTap: _showDiscountSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.discount_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 4),
                Text(_discount > 0 ? _fmt(_discount) : 'Disc',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: cs.onSurface)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Action buttons
        Row(children: [
          // Hold
          SizedBox(
            height: 48,
            width: 44,
            child: IconButton.outlined(
              onPressed: _holdSale,
              icon: const Icon(Icons.pause_circle_filled_rounded, size: 20),
              tooltip: 'Hold',
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
              onPressed: _clearCart,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: cs.error),
              tooltip: 'Clear',
              style: IconButton.styleFrom(
                side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // PAY NOW
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _cart.isNotEmpty && _creditValid && !_checkingOut
                    ? _showTenderDialog
                    : null,
                icon: _checkingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.point_of_sale_rounded, size: 20),
                label: Text('PAY NOW · ${_fmt(_total)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
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
      {bool bold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: fontSize,
                color: color ?? cs.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        Text(value,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: color ?? (bold ? cs.primary : cs.onSurface))),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PAYMENT METHOD PICKER
  // ═══════════════════════════════════════════════════════════════════════

  void _showPaymentMethodPicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Payment Method',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ..._payMethods.map((m) {
              final val = m['value'] as String;
              final label = m['label'] as String;
              final icon = m['icon'] as IconData;
              final selected = _paymentMethod == val;
              final color = _pmColor(val);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _paymentMethod = val);
                      _persistState();
                      if (val == 'credit') _showCreditDialog();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(label,
                              style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14)),
                        ),
                        if (selected)
                          Icon(Icons.check_circle_rounded,
                              color: color, size: 22),
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
}
