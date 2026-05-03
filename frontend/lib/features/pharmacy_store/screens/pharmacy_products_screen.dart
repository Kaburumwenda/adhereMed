import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/pharmacy_store_models.dart';
import '../providers/cart_provider.dart';
import '../repository/pharmacy_store_repository.dart';

class PharmacyProductsScreen extends ConsumerStatefulWidget {
  final String pharmacyId;
  const PharmacyProductsScreen({super.key, required this.pharmacyId});

  @override
  ConsumerState<PharmacyProductsScreen> createState() =>
      _PharmacyProductsScreenState();
}

class _PharmacyProductsScreenState
    extends ConsumerState<PharmacyProductsScreen> {
  final _repo = PharmacyStoreRepository();
  final _searchController = TextEditingController();

  List<PharmacyProduct> _products = [];
  List<ProductCategory> _categories = [];
  String _pharmacyName = '';
  bool _loading = true;
  int _page = 1;
  int _totalCount = 0;
  String? _nextPage;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (!append) setState(() => _loading = true);
    try {
      final result = await _repo.getProducts(
        widget.pharmacyId,
        page: _page,
        search: _searchController.text.isEmpty ? null : _searchController.text,
        categoryId: _selectedCategory,
      );
      setState(() {
        if (append) {
          _products.addAll(result.products);
        } else {
          _products = result.products;
        }
        _totalCount = result.count;
        _nextPage = result.next;
        _pharmacyName = result.pharmacyName;
        _categories = result.categories;
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

  void _search() {
    _page = 1;
    _load();
  }

  void _selectCategory(String? id) {
    _selectedCategory = id;
    _page = 1;
    _load();
  }

  void _loadMore() {
    if (_nextPage != null) {
      _page++;
      _load(append: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartItemCount = cart.itemCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () => context.go('/pharmacy-store'),
                    icon:
                        const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Back to pharmacies',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pharmacyName.isNotEmpty
                            ? _pharmacyName
                            : 'Pharmacy',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      if (_totalCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$_totalCount products available',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Cart button
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            context.go('/pharmacy-store/cart'),
                        icon: Icon(Icons.shopping_cart_rounded,
                            color: AppColors.primary),
                        tooltip: 'View cart',
                      ),
                    ),
                    if (cartItemCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '$cartItemCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Search bar ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                hintStyle: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _search();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Category filters ──
          if (_categories.isNotEmpty)
            SizedBox(
              height: 38,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: _selectedCategory == null,
                      onTap: () => _selectCategory(null),
                    ),
                    ..._categories.map((c) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _CategoryChip(
                            label: c.name,
                            selected: _selectedCategory == c.id,
                            onTap: () => _selectCategory(c.id),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),

          // ── Products ──
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: LoadingWidget(),
            )
          else if (_products.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.medication_outlined,
                          size: 48, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Text('No products found',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text('Try a different search or category',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            LayoutBuilder(builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900
                  ? 4
                  : constraints.maxWidth > 600
                      ? 3
                      : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) => _ProductCard(
                  product: _products[index],
                  pharmacyId: widget.pharmacyId,
                  pharmacyName: _pharmacyName,
                ),
              );
            }),
            if (_nextPage != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: FilledButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more_rounded, size: 20),
                    label: const Text('Load More Products'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
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

class _ProductCard extends ConsumerWidget {
  final PharmacyProduct product;
  final String pharmacyId;
  final String pharmacyName;

  const _ProductCard({
    required this.product,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final inCart =
        cart.items.any((item) => item.product.id == product.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inCart
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + stock badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (product.inStock
                            ? AppColors.primary
                            : AppColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.medication_rounded,
                      size: 18,
                      color: product.inStock
                          ? AppColors.primary
                          : AppColors.error),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: product.inStock
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    product.inStock
                        ? '${product.availableQty} in stock'
                        : 'Out of stock',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: product.inStock
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Medicine name
            Text(product.medicationName,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),

            // Category + unit row
            if (product.categoryName.isNotEmpty ||
                product.unitName.isNotEmpty)
              Text(
                [
                  if (product.categoryName.isNotEmpty)
                    product.categoryName,
                  if (product.unitName.isNotEmpty) product.unitName,
                ].join(' · '),
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            const Spacer(),

            // Price
            Text('KSh ${product.sellingPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                )),
            const SizedBox(height: 10),

            // Add to cart button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: inCart
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: Icon(Icons.check_rounded,
                          size: 16, color: AppColors.success),
                      label: Text('In Cart',
                          style: TextStyle(color: AppColors.success)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color:
                                AppColors.success.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: product.inStock
                          ? () {
                              final notifier =
                                  ref.read(cartProvider.notifier);
                              if (cart.pharmacyId != pharmacyId) {
                                notifier.setPharmacy(
                                  pharmacyId: pharmacyId,
                                  pharmacyName: pharmacyName,
                                  deliveryFee: 0,
                                );
                              }
                              notifier.addItem(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${product.medicationName} added to cart'),
                                  duration:
                                      const Duration(seconds: 1),
                                  behavior:
                                      SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 16),
                      label: const Text('Add to Cart'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
