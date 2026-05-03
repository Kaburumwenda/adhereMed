import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/models/stock_model.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../pharmacy/providers/branch_provider.dart';
import '../repository/pos_repository.dart';

class _CartItem {
  final int stockId;
  final String name;
  int quantity = 1;
  final double unitPrice;

  _CartItem({
    required this.stockId,
    required this.name,
    required this.unitPrice,
  });

  double get lineTotal => quantity * unitPrice;
}

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> {
  final _inventoryRepo = InventoryRepository();
  final _posRepo = POSRepository();

  // Product search state
  List<MedicationStock> _products = [];
  bool _searchLoading = false;
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  String _currentQuery = '';

  // Category filter state
  List<Category> _categories = [];
  int? _selectedCategory;

  // Cart state
  final List<_CartItem> _cart = [];

  // Payment state
  String _paymentMethod = 'cash';
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _amountTenderedCtrl = TextEditingController();

  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _searchProducts('');
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _inventoryRepo.getCategories();
      setState(() => _categories = cats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _discountCtrl.dispose();
    _amountTenderedCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query, {int page = 1}) async {
    setState(() {
      _searchLoading = true;
      _currentQuery = query;
    });
    try {
      final result = await _inventoryRepo.getStocks(
        search: query.isEmpty ? null : query,
        page: page,
        category: _selectedCategory,
      );
      setState(() {
        _products = result.results;
        _totalCount = result.count;
        _hasNext = result.next != null;
        _hasPrev = result.previous != null;
        _currentPage = page;
        _searchLoading = false;
      });
    } catch (_) {
      setState(() => _searchLoading = false);
    }
  }

  void _addToCart(MedicationStock stock) {
    setState(() {
      final existing = _cart.indexWhere((c) => c.stockId == stock.id);
      if (existing >= 0) {
        _cart[existing].quantity++;
      } else {
        _cart.add(_CartItem(
          stockId: stock.id,
          name: stock.medicationName,
          unitPrice: stock.sellingPrice,
        ));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateQty(int index, int delta) {
    setState(() {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  double get _subtotal =>
      _cart.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get _discount =>
      double.tryParse(_discountCtrl.text) ?? 0;

  double get _tax => (_subtotal - _discount) * 0.0; // Tax rate: adjust as needed

  double get _grandTotal => _subtotal - _discount + _tax;

  double get _amountTendered =>
      double.tryParse(_amountTenderedCtrl.text) ?? 0;

  double get _change => _amountTendered - _grandTotal;

  Future<void> _completeSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cart is empty'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_paymentMethod == 'cash' && _amountTendered < _grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount tendered is less than total'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _completing = true);
    try {
      final activeBranch = ref.read(activeBranchProvider);
      final data = {
        'customer_name': _customerNameCtrl.text.trim(),
        'customer_phone': _customerPhoneCtrl.text.trim(),
        'payment_method': _paymentMethod,
        'discount': _discount,
        if (activeBranch != null) 'branch_id': activeBranch.id,
        'items': _cart
            .map((item) => {
                  'stock_id': item.stockId,
                  'quantity': item.quantity,
                })
            .toList(),
      };

      final result = await _posRepo.createTransaction(data);

      if (mounted) {
        // Capture snapshot before clearing
        final cartSnapshot = List<_CartItem>.from(_cart);
        final storeName = ref.read(authProvider).valueOrNull?.tenantName ?? 'AfyaOne Pharmacy';
        _showReceiptDialog(
          receiptNumber: result.receiptNumber ?? 'N/A',
          total: result.totalAmount,
          cartItems: cartSnapshot,
          storeName: storeName,
        );
        setState(() {
          _cart.clear();
          _customerNameCtrl.clear();
          _customerPhoneCtrl.clear();
          _discountCtrl.text = '0';
          _amountTenderedCtrl.clear();
          _completing = false;
        });
      }
    } catch (e) {
      setState(() => _completing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showReceiptDialog({
    required String receiptNumber,
    required double total,
    required List<_CartItem> cartItems,
    required String storeName,
  }) {
    final paymentMethod = _paymentMethod;
    final amountTendered = _amountTendered;
    final change = _change > 0 ? _change : 0.0;
    final discount = _discount;
    final customerName = _customerNameCtrl.text.trim();
    final customerPhone = _customerPhoneCtrl.text.trim();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Dialog header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Sale Completed',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Thermal receipt preview ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ThermalReceiptWidget(
                    storeName: storeName,
                    receiptNumber: receiptNumber,
                    total: total,
                    cartItems: cartItems,
                    paymentMethod: paymentMethod,
                    amountTendered: amountTendered,
                    change: change,
                    discount: discount,
                    customerName: customerName,
                    customerPhone: customerPhone,
                    formatCurrency: _formatCurrency,
                  ),
                ),
              ),
              // ── Actions ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _printReceipt(
                          storeName: storeName,
                          receiptNumber: receiptNumber,
                          total: total,
                          cartItems: cartItems,
                          paymentMethod: paymentMethod,
                          amountTendered: amountTendered,
                          change: change,
                          discount: discount,
                          customerName: customerName,
                          customerPhone: customerPhone,
                        ),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt({
    required String storeName,
    required String receiptNumber,
    required double total,
    required List<_CartItem> cartItems,
    required String paymentMethod,
    required double amountTendered,
    required double change,
    required double discount,
    required String customerName,
    required String customerPhone,
  }) async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
          marginAll: 6 * PdfPageFormat.mm),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                storeName,
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
                child: pw.Text('SALES RECEIPT',
                    style: const pw.TextStyle(fontSize: 10))),
            pw.Divider(),
            _pdfRow('Receipt #', receiptNumber),
            _pdfRow('Date', dateStr),
            if (customerName.isNotEmpty) _pdfRow('Customer', customerName),
            if (customerPhone.isNotEmpty) _pdfRow('Phone', customerPhone),
            pw.Divider(),
            pw.Row(
              children: [
                pw.Expanded(
                    flex: 4,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 9))),
                pw.Expanded(
                    flex: 1,
                    child: pw.Text('Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 9))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('Price',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 9))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('Total',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 9))),
              ],
            ),
            pw.Divider(height: 4),
            ...cartItems.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                          flex: 4,
                          child: pw.Text(item.name,
                              style: const pw.TextStyle(fontSize: 9),
                              maxLines: 2)),
                      pw.Expanded(
                          flex: 1,
                          child: pw.Text('${item.quantity}',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                              item.unitPrice.toStringAsFixed(2),
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                              item.lineTotal.toStringAsFixed(2),
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                )),
            pw.Divider(),
            if (discount > 0) _pdfRow('Discount', '-${discount.toStringAsFixed(2)}'),
            _pdfRow('TOTAL', 'KSh ${total.toStringAsFixed(2)}', bold: true),
            if (paymentMethod == 'cash') ...[
              _pdfRow('Tendered', 'KSh ${amountTendered.toStringAsFixed(2)}'),
              _pdfRow('Change', 'KSh ${change.toStringAsFixed(2)}'),
            ],
            _pdfRow('Payment', paymentMethod.toUpperCase()),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
                child: pw.Text('Thank you for your purchase!',
                    style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 4),
            pw.Center(
                child: pw.Text('Powered by AdhereMed',
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey))),

          ],
        );
      },
    ));

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)
        : const pw.TextStyle(fontSize: 9);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.point_of_sale_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Point of Sale',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Search products & process sales',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              const Spacer(),
              // cart item count badge
              if (_cart.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${_cart.fold<int>(0, (s, i) => s + i.quantity)} items',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Body: Products + Cart ──
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ════ LEFT: Product Catalog ════
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      // Search bar
                      SearchField(
                        hintText: 'Search by name or barcode...',
                        onChanged: (value) => _searchProducts(value),
                      ),
                      const SizedBox(height: 12),
                      // Category filter chips
                      SizedBox(
                        height: 38,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _CategoryChip(
                                label: 'All',
                                selected: _selectedCategory == null,
                                onTap: () {
                                  setState(() => _selectedCategory = null);
                                  _searchProducts(_currentQuery);
                                },
                              ),
                              ..._categories.map((cat) => Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: _CategoryChip(
                                      label: cat.name,
                                      selected: _selectedCategory == cat.id,
                                      onTap: () {
                                        setState(() => _selectedCategory = cat.id);
                                        _searchProducts(_currentQuery);
                                      },
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Product grid
                      Expanded(
                        child: _searchLoading
                            ? const LoadingWidget()
                            : _products.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search_off_rounded,
                                            size: 48,
                                            color: AppColors.border),
                                        const SizedBox(height: 12),
                                        Text('No products found',
                                            style: TextStyle(
                                                color:
                                                    AppColors.textSecondary,
                                                fontSize: 15)),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 260,
                                      mainAxisExtent: 120,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: _products.length,
                                    itemBuilder: (context, index) {
                                      final product = _products[index];
                                      return _ProductCard(
                                        product: product,
                                        onTap: () => _addToCart(product),
                                        formatCurrency: _formatCurrency,
                                      );
                                    },
                                  ),
                      ),
                      // Pagination bar
                      if (_totalCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${((_currentPage - 1) * _products.length) + 1}'
                                '–${((_currentPage - 1) * _products.length) + _products.length}'
                                ' of $_totalCount',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _hasPrev
                                        ? () => _searchProducts(
                                            _currentQuery,
                                            page: _currentPage - 1)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    iconSize: 20,
                                    tooltip: 'Previous',
                                    style: IconButton.styleFrom(
                                      backgroundColor: _hasPrev
                                          ? AppColors.primary
                                              .withValues(alpha: 0.1)
                                          : null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Text(
                                      'Page $_currentPage',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _hasNext
                                        ? () => _searchProducts(
                                            _currentQuery,
                                            page: _currentPage + 1)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                    iconSize: 20,
                                    tooltip: 'Next',
                                    style: IconButton.styleFrom(
                                      backgroundColor: _hasNext
                                          ? AppColors.primary
                                              .withValues(alpha: 0.1)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // ════ RIGHT: Cart & Checkout ════
                SizedBox(
                  width: 380,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        // Cart header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Current Order',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              if (_cart.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${_cart.length}',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ),
                              if (_cart.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() => _cart.clear()),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.delete_outline,
                                        size: 18, color: AppColors.error),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Cart items
                        Expanded(
                          child: _cart.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                            Icons.shopping_cart_outlined,
                                            size: 36,
                                            color: AppColors.border),
                                      ),
                                      const SizedBox(height: 12),
                                      Text('No items yet',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Click on products to add them',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondary)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  itemCount: _cart.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = _cart[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Item info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(item.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 13),
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis),
                                                const SizedBox(height: 2),
                                                Text(
                                                    '${_formatCurrency(item.unitPrice)} each',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary)),
                                              ],
                                            ),
                                          ),
                                          // Qty controls
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _qtyButton(Icons.remove,
                                                    () => _updateQty(index, -1)),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10),
                                                  child: Text(
                                                      '${item.quantity}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13)),
                                                ),
                                                _qtyButton(Icons.add,
                                                    () => _updateQty(index, 1)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Line total
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                  _formatCurrency(
                                                      item.lineTotal),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13)),
                                              const SizedBox(height: 2),
                                              InkWell(
                                                onTap: () =>
                                                    _removeFromCart(index),
                                                child: Text('Remove',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.error)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // ── Checkout section ──
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Totals
                              _totalRow(
                                  'Subtotal', _formatCurrency(_subtotal)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Discount',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13)),
                                  const Spacer(),
                                  SizedBox(
                                    width: 90,
                                    height: 30,
                                    child: TextField(
                                      controller: _discountCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        isDense: true,
                                        prefixText: 'KSh ',
                                        prefixStyle:
                                            const TextStyle(fontSize: 12),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              if (_tax > 0) ...[
                                const SizedBox(height: 4),
                                _totalRow('Tax', _formatCurrency(_tax)),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                  Text(_formatCurrency(_grandTotal),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                          color: AppColors.primary)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Customer
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customerNameCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Customer name',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 10),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _customerPhoneCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Phone',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 10),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Payment method
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: 'cash',
                                      label: Text('Cash'),
                                      icon: Icon(Icons.payments_outlined,
                                          size: 16)),
                                  ButtonSegment(
                                      value: 'card',
                                      label: Text('Card'),
                                      icon: Icon(
                                          Icons.credit_card_rounded,
                                          size: 16)),
                                  ButtonSegment(
                                      value: 'mpesa',
                                      label: Text('M-Pesa'),
                                      icon: Icon(
                                          Icons.phone_android_rounded,
                                          size: 16)),
                                ],
                                selected: {_paymentMethod},
                                onSelectionChanged: (val) =>
                                    setState(() =>
                                        _paymentMethod = val.first),
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  textStyle: WidgetStateProperty.all(
                                      const TextStyle(fontSize: 12)),
                                ),
                              ),
                              if (_paymentMethod == 'cash') ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _amountTenderedCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Amount tendered (KSh)',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                    filled: true,
                                    fillColor: AppColors.surface,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                                if (_amountTendered > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Change',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: AppColors.success,
                                                  fontSize: 13)),
                                          Text(
                                            _formatCurrency(_change > 0
                                                ? _change
                                                : 0),
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.success,
                                                fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 16),
                              // Complete button
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: FilledButton.icon(
                                  onPressed:
                                      _completing ? null : _completeSale,
                                  icon: _completing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white),
                                        )
                                      : const Icon(
                                          Icons.check_circle_rounded),
                                  label: Text(
                                      _completing
                                          ? 'Processing...'
                                          : 'Complete Sale  •  ${_formatCurrency(_grandTotal)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 14, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              fontSize: large ? 16 : 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: large ? 18 : 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thermal Receipt Preview Widget ───────────────────────────────────────────

class _ThermalReceiptWidget extends StatelessWidget {
  final String storeName;
  final String receiptNumber;
  final double total;
  final List<_CartItem> cartItems;
  final String paymentMethod;
  final double amountTendered;
  final double change;
  final double discount;
  final String customerName;
  final String customerPhone;
  final String Function(double) formatCurrency;

  const _ThermalReceiptWidget({
    required this.storeName,
    required this.receiptNumber,
    required this.total,
    required this.cartItems,
    required this.paymentMethod,
    required this.amountTendered,
    required this.change,
    required this.discount,
    required this.customerName,
    required this.customerPhone,
    required this.formatCurrency,
  });

  static const _mono = TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black);
  static const _monoSm = TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black);
  static const _monoBold = TextStyle(
      fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black);
  static const _monoLg = TextStyle(
      fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black);

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy  HH:mm').format(DateTime.now());
    final subtotal = cartItems.fold(0.0, (s, i) => s + i.lineTotal);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store name
          Center(
            child: Text(storeName.toUpperCase(),
                style: _monoLg, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text('** SALES RECEIPT **',
                style: _monoSm.copyWith(color: Colors.black54),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 6),
          _Dashes(),
          _metaRow('Date:', dateStr),
          _metaRow('Receipt#:', receiptNumber),
          if (customerName.isNotEmpty) _metaRow('Customer:', customerName),
          if (customerPhone.isNotEmpty) _metaRow('Phone:', customerPhone),
          _Dashes(),
          // Items header
          Row(children: [
            Expanded(
                flex: 4,
                child: Text('ITEM', style: _monoBold)),
            SizedBox(
                width: 28,
                child: Text('QTY',
                    style: _monoBold, textAlign: TextAlign.center)),
            SizedBox(
                width: 60,
                child: Text('PRICE',
                    style: _monoBold, textAlign: TextAlign.right)),
            SizedBox(
                width: 60,
                child: Text('TOTAL',
                    style: _monoBold, textAlign: TextAlign.right)),
          ]),
          _Dashes(dashed: false),
          // Line items
          ...cartItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: _mono,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Row(children: [
                      const Spacer(),
                      SizedBox(
                          width: 28,
                          child: Text('${item.quantity}',
                              style: _monoSm,
                              textAlign: TextAlign.center)),
                      SizedBox(
                          width: 60,
                          child: Text(
                              item.unitPrice.toStringAsFixed(2),
                              style: _monoSm,
                              textAlign: TextAlign.right)),
                      SizedBox(
                          width: 60,
                          child: Text(
                              item.lineTotal.toStringAsFixed(2),
                              style: _monoSm,
                              textAlign: TextAlign.right)),
                    ]),
                  ],
                ),
              )),
          _Dashes(),
          // Subtotal
          _totalsRow('Subtotal', formatCurrency(subtotal)),
          if (discount > 0)
            _totalsRow('Discount', '-${formatCurrency(discount)}',
                color: Colors.red[700]),
          _Dashes(dashed: false),
          // Grand total
          _totalsRow('TOTAL', formatCurrency(total), bold: true, large: true),
          const SizedBox(height: 4),
          _Dashes(),
          // Payment info
          _totalsRow('Payment', paymentMethod.toUpperCase()),
          if (paymentMethod == 'cash') ...[
            _totalsRow('Tendered', formatCurrency(amountTendered)),
            _totalsRow('Change', formatCurrency(change),
                bold: true, color: Colors.green[700]),
          ],
          _Dashes(),
          const SizedBox(height: 6),
          Center(
            child: Text('Thank you for your purchase!',
                style: _monoSm.copyWith(color: Colors.black54),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text('--- Powered by AdhereMed ---',
                style: _monoSm.copyWith(
                    color: Colors.black38, fontSize: 11),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 72,
                child: Text(label, style: _monoSm)),
            Expanded(child: Text(value, style: _monoSm)),
          ],
        ),
      );

  Widget _totalsRow(String label, String value,
      {bool bold = false, bool large = false, Color? color}) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: large ? 14 : 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color ?? Colors.black,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _Dashes extends StatelessWidget {
  final bool dashed;
  const _Dashes({this.dashed = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        dashed ? '- ' * 22 : '─' * 32,
        style: const TextStyle(
            fontFamily: 'monospace', fontSize: 12, color: Colors.black45),
        overflow: TextOverflow.clip,
        maxLines: 1,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final MedicationStock product;
  final VoidCallback onTap;
  final String Function(double) formatCurrency;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final inStock = (product.totalQuantity ?? 0) > 0;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: inStock ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: inStock ? AppColors.border : AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (inStock ? AppColors.primary : AppColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.medication_rounded,
                        size: 16,
                        color: inStock ? AppColors.primary : AppColors.error),
                  ),
                  const Spacer(),
                  if (product.prescriptionRequired != 'none') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: product.prescriptionRequired == 'required'
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: product.prescriptionRequired == 'required'
                              ? AppColors.error.withValues(alpha: 0.4)
                              : AppColors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 10,
                            color: product.prescriptionRequired == 'required'
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            product.prescriptionRequired == 'required'
                                ? 'Rx'
                                : 'Rx?',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: product.prescriptionRequired == 'required'
                                  ? AppColors.error
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: inStock
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      inStock ? '${product.totalQuantity} in stock' : 'Out',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: inStock ? AppColors.success : AppColors.error),
                    ),
                  ),
                ],
              ),
              Text(product.medicationName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              Text(formatCurrency(product.sellingPrice),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
