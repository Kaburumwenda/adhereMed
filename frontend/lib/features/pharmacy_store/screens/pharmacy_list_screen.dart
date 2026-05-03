import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/pharmacy_store_models.dart';
import '../repository/pharmacy_store_repository.dart';

class PharmacyListScreen extends ConsumerStatefulWidget {
  const PharmacyListScreen({super.key});

  @override
  ConsumerState<PharmacyListScreen> createState() => _PharmacyListScreenState();
}

class _PharmacyListScreenState extends ConsumerState<PharmacyListScreen> {
  final _repo = PharmacyStoreRepository();
  List<PharmacyInfo> _pharmacies = [];
  List<PharmacyInfo> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _pharmacies = await _repo.getPharmacies();
      _applySearch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applySearch() {
    if (_search.isEmpty) {
      _filtered = _pharmacies;
    } else {
      final q = _search.toLowerCase();
      _filtered = _pharmacies
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.city.toLowerCase().contains(q))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse Pharmacies',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Find medicines and order from nearby pharmacies',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search pharmacies by name or city...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surface,
            ),
            onChanged: (v) => setState(() {
              _search = v;
              _applySearch();
            }),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const LoadingWidget()
          else if (_filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.local_pharmacy_outlined,
                        size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text('No pharmacies found',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.6,
                ),
                itemCount: _filtered.length,
                itemBuilder: (context, index) =>
                    _PharmacyCard(pharmacy: _filtered[index]),
              );
            }),
        ],
      ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final PharmacyInfo pharmacy;
  const _PharmacyCard({required this.pharmacy});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/pharmacy-store/${pharmacy.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.local_pharmacy,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pharmacy.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16),
                            overflow: TextOverflow.ellipsis),
                        if (pharmacy.city.isNotEmpty)
                          Text(pharmacy.city,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (pharmacy.description.isNotEmpty)
                Expanded(
                  child: Text(pharmacy.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              const Spacer(),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.medication_outlined,
                    label: '${pharmacy.productCount} products',
                  ),
                  const SizedBox(width: 8),
                  if (pharmacy.deliveryFee > 0)
                    _InfoChip(
                      icon: Icons.delivery_dining,
                      label: 'KSh ${pharmacy.deliveryFee.toStringAsFixed(0)}',
                    ),
                  if (pharmacy.acceptsInsurance) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.verified_outlined,
                      label: 'Insurance',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
