import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../medications/models/medication_model.dart';
import '../../medications/repositories/medication_repository.dart';
import '../../inventory/models/stock_model.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../lab/models/lab_order_model.dart';
import '../../lab/repository/lab_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CatalogManagementScreen extends StatefulWidget {
  const CatalogManagementScreen({super.key});

  @override
  State<CatalogManagementScreen> createState() =>
      _CatalogManagementScreenState();
}

class _CatalogManagementScreenState extends State<CatalogManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _activeTab = 0;

  static const _tabs = [
    (Icons.medication_rounded, 'Medications'),
    (Icons.inventory_2_rounded, 'Pharmacy Stock'),
    (Icons.biotech_rounded, 'Lab Tests'),
  ];

  static const _tabColors = [
    Color(0xFF0D9488),  // teal
    Color(0xFF6366F1),  // indigo
    Color(0xFF8B5CF6),  // purple
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) setState(() => _activeTab = _tab.index);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Color get _headerColor => _tabColors[_activeTab];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Gradient header ─────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(_headerColor, Colors.black, 0.35)!,
                _headerColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.library_books_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Catalog Management',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                            Text('Manage medications, stock & lab test catalog',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Pill tabs row
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: List.generate(_tabs.length, (i) {
                        final active = _activeTab == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tab.animateTo(i);
                              setState(() => _activeTab = i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 9, horizontal: 4),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_tabs[i].$1,
                                      size: 15,
                                      color: active
                                          ? _tabColors[i]
                                          : Colors.white
                                              .withValues(alpha: 0.75)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(_tabs[i].$2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: active
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: active
                                                ? _tabColors[i]
                                                : Colors.white
                                                    .withValues(alpha: 0.8))),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Tab views ────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _MedicationsTab(),
              _StockTab(),
              _LabTestsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Medications Tab
// ─────────────────────────────────────────────────────────────────────────────

class _MedicationsTab extends StatefulWidget {
  const _MedicationsTab();

  @override
  State<_MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends State<_MedicationsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = MedicationRepository();
  final _searchCtrl = TextEditingController();
  PaginatedResponse<Medication>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String? _categoryFilter;

  static const _categories = [
    ('analgesic', 'Analgesic'), ('antibiotic', 'Antibiotic'),
    ('antifungal', 'Antifungal'), ('antiviral', 'Antiviral'),
    ('antimalarial', 'Antimalarial'), ('antihypertensive', 'Antihypertensive'),
    ('antidiabetic', 'Antidiabetic'), ('antihistamine', 'Antihistamine'),
    ('antacid', 'Antacid / GI'), ('cardiovascular', 'Cardiovascular'),
    ('respiratory', 'Respiratory'), ('cns', 'CNS'),
    ('vitamin', 'Vitamin / Supplement'), ('vaccine', 'Vaccine'),
    ('nsaid', 'NSAID'), ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _repo.getMedications(
          page: _page,
          search: _search.isEmpty ? null : _search,
          category: _categoryFilter);
      setState(() { _data = r; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openForm([Medication? med]) {
    showDialog(
      context: context,
      builder: (_) => _MedicationFormDialog(
        existing: med,
        repo: _repo,
        onSaved: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  Future<void> _deactivate(Medication med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(
          name: med.genericName, type: 'medication'),
    ) ?? false;
    if (!ok) return;
    try {
      await _repo.deactivateMedication(med.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _TabToolbar(
          searchCtrl: _searchCtrl,
          hint: 'Search medications…',
          onSearch: (v) { setState(() { _search = v; _page = 1; }); _load(); },
          filterWidget: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _categoryFilter,
              hint: Text('Category',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              isDense: true,
              items: [
                DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All', style: TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                ..._categories.map((c) => DropdownMenuItem<String?>(
                    value: c.$1,
                    child: Text(c.$2,
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary)))),
              ],
              onChanged: (v) {
                setState(() { _categoryFilter = v; _page = 1; });
                _load();
              },
            ),
          ),
          count: _data?.count,
          countLabel: 'medication',
          addLabel: 'Add Medication',
          addColor: const Color(0xFF0D9488),
          onAdd: () => _openForm(),
        ),
        Expanded(
          child: _loading
              ? const LoadingWidget()
              : _error != null
                  ? _ErrorRetry(message: _error!, onRetry: _load)
                  : _data == null || _data!.results.isEmpty
                      ? _EmptyState(
                          icon: Icons.medication_rounded,
                          label: 'No medications found',
                          color: const Color(0xFF0D9488))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: _data!.results.length,
                          itemBuilder: (_, i) {
                            final m = _data!.results[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MedicationCard(
                                med: m,
                                onEdit: () => _openForm(m),
                                onDeactivate: () => _deactivate(m),
                              ),
                            );
                          },
                        ),
        ),
        if (_data != null &&
            (_data!.previous != null || _data!.next != null))
          _Pagination(
            page: _page,
            hasPrev: _data!.previous != null,
            hasNext: _data!.next != null,
            onPrev: () { setState(() => _page--); _load(); },
            onNext: () { setState(() => _page++); _load(); },
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pharmacy Stock Tab
// ─────────────────────────────────────────────────────────────────────────────

class _StockTab extends StatefulWidget {
  const _StockTab();

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = InventoryRepository();
  final _searchCtrl = TextEditingController();
  PaginatedResponse<MedicationStock>? _data;
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  int? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _repo.getStocks(
          page: _page,
          search: _search.isEmpty ? null : _search,
          category: _categoryFilter);
      setState(() { _data = r; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openForm([MedicationStock? stock]) {
    showDialog(
      context: context,
      builder: (_) => _StockFormDialog(
        existing: stock,
        repo: _repo,
        categories: _categories,
        onSaved: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  Future<void> _delete(MedicationStock stock) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(
          name: stock.medicationName, type: 'stock entry'),
    ) ?? false;
    if (!ok) return;
    try {
      await _repo.deleteStock(stock.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _TabToolbar(
          searchCtrl: _searchCtrl,
          hint: 'Search stock items…',
          onSearch: (v) { setState(() { _search = v; _page = 1; }); _load(); },
          filterWidget: _categories.isEmpty
              ? null
              : DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _categoryFilter,
                    hint: Text('Category',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    isDense: true,
                    items: [
                      DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textPrimary))),
                      ..._categories.map((c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary)))),
                    ],
                    onChanged: (v) {
                      setState(() { _categoryFilter = v; _page = 1; });
                      _load();
                    },
                  ),
                ),
          count: _data?.count,
          countLabel: 'stock item',
          addLabel: 'Add Stock',
          addColor: const Color(0xFF6366F1),
          onAdd: () => _openForm(),
        ),
        Expanded(
          child: _loading
              ? const LoadingWidget()
              : _error != null
                  ? _ErrorRetry(message: _error!, onRetry: _load)
                  : _data == null || _data!.results.isEmpty
                      ? _EmptyState(
                          icon: Icons.inventory_2_rounded,
                          label: 'No stock items found',
                          color: const Color(0xFF6366F1))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: _data!.results.length,
                          itemBuilder: (_, i) {
                            final s = _data!.results[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StockCard(
                                stock: s,
                                onEdit: () => _openForm(s),
                                onDelete: () => _delete(s),
                              ),
                            );
                          },
                        ),
        ),
        if (_data != null &&
            (_data!.previous != null || _data!.next != null))
          _Pagination(
            page: _page,
            hasPrev: _data!.previous != null,
            hasNext: _data!.next != null,
            onPrev: () { setState(() => _page--); _load(); },
            onNext: () { setState(() => _page++); _load(); },
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lab Tests Tab
// ─────────────────────────────────────────────────────────────────────────────

class _LabTestsTab extends StatefulWidget {
  const _LabTestsTab();

  @override
  State<_LabTestsTab> createState() => _LabTestsTabState();
}

class _LabTestsTabState extends State<_LabTestsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = LabRepository();
  final _searchCtrl = TextEditingController();
  PaginatedResponse<LabTestCatalog>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _repo.getCatalog(
          page: _page,
          search: _search.isEmpty ? null : _search);
      setState(() { _data = r; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openForm([LabTestCatalog? test]) {
    showDialog(
      context: context,
      builder: (_) => _LabTestFormDialog(
        existing: test,
        repo: _repo,
        onSaved: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  Future<void> _delete(LabTestCatalog test) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(
          name: test.name, type: 'lab test'),
    ) ?? false;
    if (!ok) return;
    try {
      await _repo.deleteCatalogTest(test.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _TabToolbar(
          searchCtrl: _searchCtrl,
          hint: 'Search lab tests…',
          onSearch: (v) { setState(() { _search = v; _page = 1; }); _load(); },
          count: _data?.count,
          countLabel: 'lab test',
          addLabel: 'Add Test',
          addColor: const Color(0xFF8B5CF6),
          onAdd: () => _openForm(),
        ),
        Expanded(
          child: _loading
              ? const LoadingWidget()
              : _error != null
                  ? _ErrorRetry(message: _error!, onRetry: _load)
                  : _data == null || _data!.results.isEmpty
                      ? _EmptyState(
                          icon: Icons.biotech_rounded,
                          label: 'No lab tests found',
                          color: const Color(0xFF8B5CF6))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: _data!.results.length,
                          itemBuilder: (_, i) {
                            final t = _data!.results[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LabTestCard(
                                test: t,
                                onEdit: () => _openForm(t),
                                onDelete: () => _delete(t),
                              ),
                            );
                          },
                        ),
        ),
        if (_data != null &&
            (_data!.previous != null || _data!.next != null))
          _Pagination(
            page: _page,
            hasPrev: _data!.previous != null,
            hasNext: _data!.next != null,
            onPrev: () { setState(() => _page--); _load(); },
            onNext: () { setState(() => _page++); _load(); },
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _TabToolbar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String hint;
  final ValueChanged<String> onSearch;
  final Widget? filterWidget;
  final int? count;
  final String countLabel;
  final String addLabel;
  final Color addColor;
  final VoidCallback onAdd;

  const _TabToolbar({
    required this.searchCtrl,
    required this.hint,
    required this.onSearch,
    this.filterWidget,
    this.count,
    required this.countLabel,
    required this.addLabel,
    required this.addColor,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: searchCtrl,
                    onSubmitted: onSearch,
                    onChanged: (v) { if (v.isEmpty) onSearch(''); },
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search,
                          size: 17, color: AppColors.textSecondary),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.clear,
                                  size: 15,
                                  color: AppColors.textSecondary),
                              onPressed: () {
                                searchCtrl.clear();
                                onSearch('');
                              })
                          : null,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: addColor, width: 1.5)),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),
                ),
              ),
              if (filterWidget != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: filterWidget!,
                ),
              ],
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: addColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(addLabel),
              ),
            ],
          ),
          if (count != null) ...[
            const SizedBox(height: 6),
            Text(
              '$count ${countLabel}${count == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Medication card
// ─────────────────────────────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  final Medication med;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  const _MedicationCard(
      {required this.med, required this.onEdit, required this.onDeactivate});

  static const _catColors = {
    'antibiotic': Color(0xFF22C55E),
    'analgesic': Color(0xFFF59E0B),
    'antihypertensive': Color(0xFF3B82F6),
    'antidiabetic': Color(0xFF8B5CF6),
    'antimalarial': Color(0xFF0D9488),
    'vitamin': Color(0xFF10B981),
    'vaccine': Color(0xFF6366F1),
    'nsaid': Color(0xFFEF4444),
  };

  Color get _color =>
      _catColors[med.category] ?? const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _color),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.medication_rounded,
                            color: _color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(med.genericName,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                ),
                                _CatBadge(
                                    label: med.category
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    color: _color),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                med.dosageForm.replaceAll('_', ' '),
                                if (med.strength?.isNotEmpty == true)
                                  med.strength!,
                              ].join(' · '),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                            if (med.brandNames.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                med.brandNames.take(2).join(', '),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                if (med.requiresPrescription)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppColors.warning
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text('Rx',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.warning)),
                                  ),
                                if (!med.isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Inactive',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.error)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      _ActionMenu(
                          onEdit: onEdit,
                          onDelete: onDeactivate,
                          deleteLabel: 'Deactivate'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pharmacy stock card
// ─────────────────────────────────────────────────────────────────────────────

class _StockCard extends StatelessWidget {
  final MedicationStock stock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _StockCard(
      {required this.stock, required this.onEdit, required this.onDelete});

  static const _accentColor = Color(0xFF6366F1);

  String _ksh(double v) =>
      'KSh ${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    final qty = stock.totalQuantity ?? 0;
    final isLow = stock.isLowStock == true;
    final qtyColor = qty == 0
        ? AppColors.error
        : isLow
            ? AppColors.warning
            : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _accentColor),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.inventory_2_rounded,
                            color: _accentColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stock.medicationName,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                _InfoChip(
                                    label: 'Sell: ${_ksh(stock.sellingPrice)}',
                                    color: AppColors.success),
                                const SizedBox(width: 6),
                                _InfoChip(
                                    label: 'Cost: ${_ksh(stock.costPrice)}',
                                    color: AppColors.textSecondary),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: qtyColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: qtyColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text('Qty: $qty',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: qtyColor)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Reorder @ ${stock.reorderLevel}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary),
                                ),
                                if (stock.categoryName != null) ...[
                                  const SizedBox(width: 6),
                                  _CatBadge(
                                      label: stock.categoryName!,
                                      color: _accentColor),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      _ActionMenu(
                          onEdit: onEdit,
                          onDelete: onDelete,
                          deleteLabel: 'Remove'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lab test card
// ─────────────────────────────────────────────────────────────────────────────

class _LabTestCard extends StatelessWidget {
  final LabTestCatalog test;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _LabTestCard(
      {required this.test, required this.onEdit, required this.onDelete});

  static const _accentColor = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _accentColor),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.biotech_rounded,
                            color: _accentColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(test.name,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _accentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(test.code,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _accentColor)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.science_rounded,
                                    size: 12,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(test.specimenType,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                                if (test.department?.isNotEmpty == true) ...[
                                  const SizedBox(width: 10),
                                  Icon(Icons.local_hospital_rounded,
                                      size: 12,
                                      color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(test.department!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _InfoChip(
                                    label:
                                        'KSh ${test.price.toStringAsFixed(0)}',
                                    color: AppColors.success),
                                if (test.turnaroundTime?.isNotEmpty == true) ...[
                                  const SizedBox(width: 6),
                                  _InfoChip(
                                      label: 'TAT: ${test.turnaroundTime}',
                                      color: AppColors.textSecondary),
                                ],
                                if (!test.isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Inactive',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.error)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      _ActionMenu(
                          onEdit: onEdit,
                          onDelete: onDelete,
                          deleteLabel: 'Delete'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Medication form dialog
// ─────────────────────────────────────────────────────────────────────────────

class _MedicationFormDialog extends StatefulWidget {
  final Medication? existing;
  final MedicationRepository repo;
  final VoidCallback onSaved;
  const _MedicationFormDialog(
      {this.existing, required this.repo, required this.onSaved});

  @override
  State<_MedicationFormDialog> createState() => _MedicationFormDialogState();
}

class _MedicationFormDialogState extends State<_MedicationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sideEffectsCtrl = TextEditingController();
  final _contraindicationsCtrl = TextEditingController();
  String _category = 'other';
  String _form = 'tablet';
  bool _requiresRx = true;
  bool _saving = false;
  String? _error;

  static const _categories = [
    ('analgesic', 'Analgesic'), ('antibiotic', 'Antibiotic'),
    ('antifungal', 'Antifungal'), ('antiviral', 'Antiviral'),
    ('antimalarial', 'Antimalarial'), ('antihypertensive', 'Antihypertensive'),
    ('antidiabetic', 'Antidiabetic'), ('antihistamine', 'Antihistamine'),
    ('antacid', 'Antacid / GI'), ('cardiovascular', 'Cardiovascular'),
    ('respiratory', 'Respiratory'), ('cns', 'CNS'),
    ('vitamin', 'Vitamin / Supplement'), ('vaccine', 'Vaccine'),
    ('nsaid', 'NSAID'), ('other', 'Other'),
  ];

  static const _forms = [
    ('tablet', 'Tablet'), ('capsule', 'Capsule'), ('syrup', 'Syrup'),
    ('injection', 'Injection'), ('cream', 'Cream'), ('ointment', 'Ointment'),
    ('drops', 'Drops'), ('inhaler', 'Inhaler'), ('suspension', 'Suspension'),
    ('solution', 'Solution'), ('powder', 'Powder'), ('spray', 'Spray'),
    ('gel', 'Gel'), ('patch', 'Patch'), ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final m = widget.existing!;
      _nameCtrl.text = m.genericName;
      _strengthCtrl.text = m.strength ?? '';
      _descCtrl.text = m.description ?? '';
      _sideEffectsCtrl.text = m.sideEffects ?? '';
      _contraindicationsCtrl.text = m.contraindications ?? '';
      _category = m.category;
      _form = m.dosageForm;
      _requiresRx = m.requiresPrescription;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _strengthCtrl, _descCtrl,
          _sideEffectsCtrl, _contraindicationsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final data = {
        'generic_name': _nameCtrl.text.trim(),
        'strength': _strengthCtrl.text.trim(),
        'category': _category,
        'dosage_form': _form,
        'requires_prescription': _requiresRx,
        'description': _descCtrl.text.trim(),
        'side_effects': _sideEffectsCtrl.text.trim(),
        'contraindications': _contraindicationsCtrl.text.trim(),
        'brand_names': [],
        'is_active': true,
      };
      if (widget.existing != null) {
        await widget.repo.updateMedication(widget.existing!.id, data);
      } else {
        await widget.repo.createMedication(data);
      }
      widget.onSaved();
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return _FormDialog(
      title: isEdit ? 'Edit Medication' : 'Add Medication',
      accentColor: const Color(0xFF0D9488),
      icon: Icons.medication_rounded,
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _FormField(ctrl: _nameCtrl, label: 'Generic Name *',
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  decoration: _fieldDeco('Category *'),
                  items: _categories.map((c) =>
                      DropdownMenuItem(value: c.$1, child: Text(c.$2, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _form,
                  decoration: _fieldDeco('Dosage Form *'),
                  items: _forms.map((f) =>
                      DropdownMenuItem(value: f.$1, child: Text(f.$2, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _form = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _FormField(ctrl: _strengthCtrl, label: 'Strength (e.g. 500mg)'),
            const SizedBox(height: 12),
            _FormField(ctrl: _descCtrl, label: 'Description', maxLines: 2),
            const SizedBox(height: 12),
            _FormField(
                ctrl: _sideEffectsCtrl, label: 'Side Effects', maxLines: 2),
            const SizedBox(height: 12),
            _FormField(
                ctrl: _contraindicationsCtrl,
                label: 'Contraindications',
                maxLines: 2),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _requiresRx,
                  onChanged: (v) => setState(() => _requiresRx = v ?? true),
                ),
                Text('Requires Prescription',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stock form dialog
// ─────────────────────────────────────────────────────────────────────────────

class _StockFormDialog extends StatefulWidget {
  final MedicationStock? existing;
  final InventoryRepository repo;
  final List<Category> categories;
  final VoidCallback onSaved;
  const _StockFormDialog(
      {this.existing, required this.repo, required this.categories, required this.onSaved});

  @override
  State<_StockFormDialog> createState() => _StockFormDialogState();
}

class _StockFormDialogState extends State<_StockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _medCtrl = TextEditingController();
  final _medNameCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _reorderLevelCtrl = TextEditingController();
  final _reorderQtyCtrl = TextEditingController();
  int? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final s = widget.existing!;
      _medCtrl.text = s.medicationId;
      _medNameCtrl.text = s.medicationName;
      _sellPriceCtrl.text = s.sellingPrice.toString();
      _costPriceCtrl.text = s.costPrice.toString();
      _reorderLevelCtrl.text = s.reorderLevel.toString();
      _reorderQtyCtrl.text = s.reorderQuantity.toString();
      _categoryId = s.category;
    }
  }

  @override
  void dispose() {
    for (final c in [_medCtrl, _medNameCtrl, _sellPriceCtrl, _costPriceCtrl,
          _reorderLevelCtrl, _reorderQtyCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final data = {
        'medication': _medCtrl.text.trim(),
        'medication_name': _medNameCtrl.text.trim(),
        'selling_price': _sellPriceCtrl.text.trim(),
        'cost_price': _costPriceCtrl.text.trim(),
        'reorder_level': int.tryParse(_reorderLevelCtrl.text.trim()) ?? 10,
        'reorder_quantity': int.tryParse(_reorderQtyCtrl.text.trim()) ?? 50,
        if (_categoryId != null) 'category': _categoryId,
      };
      if (widget.existing != null) {
        await widget.repo.updateStock(widget.existing!.id, data);
      } else {
        await widget.repo.createStock(data);
      }
      widget.onSaved();
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return _FormDialog(
      title: isEdit ? 'Edit Stock Item' : 'Add Stock Item',
      accentColor: const Color(0xFF6366F1),
      icon: Icons.inventory_2_rounded,
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _FormField(
              ctrl: _medCtrl,
              label: isEdit ? 'Medication ID' : 'Medication ID *',
              readOnly: isEdit,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _FormField(
              ctrl: _medNameCtrl,
              label: 'Medication Name *',
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _FormField(
                  ctrl: _sellPriceCtrl,
                  label: 'Selling Price (KSh) *',
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(
                  ctrl: _costPriceCtrl,
                  label: 'Cost Price (KSh)',
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _FormField(
                  ctrl: _reorderLevelCtrl,
                  label: 'Reorder Level',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(
                  ctrl: _reorderQtyCtrl,
                  label: 'Reorder Qty',
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration: _fieldDeco('Category'),
                items: [
                  DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                  ...widget.categories.map((c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name, style: const TextStyle(fontSize: 13)))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lab test form dialog
// ─────────────────────────────────────────────────────────────────────────────

class _LabTestFormDialog extends StatefulWidget {
  final LabTestCatalog? existing;
  final LabRepository repo;
  final VoidCallback onSaved;
  const _LabTestFormDialog(
      {this.existing, required this.repo, required this.onSaved});

  @override
  State<_LabTestFormDialog> createState() => _LabTestFormDialogState();
}

class _LabTestFormDialogState extends State<_LabTestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _specimenCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _tatCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final t = widget.existing!;
      _nameCtrl.text = t.name;
      _codeCtrl.text = t.code;
      _departmentCtrl.text = t.department ?? '';
      _specimenCtrl.text = t.specimenType;
      _priceCtrl.text = t.price.toString();
      _tatCtrl.text = t.turnaroundTime ?? '';
      _instructionsCtrl.text = t.instructions ?? '';
      _isActive = t.isActive;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _codeCtrl, _departmentCtrl, _specimenCtrl,
          _priceCtrl, _tatCtrl, _instructionsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim(),
        'department': _departmentCtrl.text.trim(),
        'specimen_type': _specimenCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        'turnaround_time': _tatCtrl.text.trim(),
        'instructions': _instructionsCtrl.text.trim(),
        'is_active': _isActive,
      };
      if (widget.existing != null) {
        await widget.repo.updateCatalogTest(widget.existing!.id, data);
      } else {
        await widget.repo.createCatalogTest(data);
      }
      widget.onSaved();
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return _FormDialog(
      title: isEdit ? 'Edit Lab Test' : 'Add Lab Test',
      accentColor: const Color(0xFF8B5CF6),
      icon: Icons.biotech_rounded,
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _FormField(ctrl: _nameCtrl, label: 'Test Name *',
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _FormField(ctrl: _codeCtrl, label: 'Code *',
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(ctrl: _specimenCtrl, label: 'Specimen Type *',
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _FormField(
                  ctrl: _priceCtrl,
                  label: 'Price (KSh) *',
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(
                    ctrl: _tatCtrl, label: 'Turnaround Time (e.g. 2h)'),
              ),
            ]),
            const SizedBox(height: 12),
            _FormField(ctrl: _departmentCtrl, label: 'Department'),
            const SizedBox(height: 12),
            _FormField(
                ctrl: _instructionsCtrl,
                label: 'Patient Instructions',
                maxLines: 2),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v ?? true),
                ),
                Text('Active',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form shell dialog
// ─────────────────────────────────────────────────────────────────────────────

class _FormDialog extends StatelessWidget {
  final String title;
  final Color accentColor;
  final IconData icon;
  final bool saving;
  final String? error;
  final VoidCallback onSave;
  final Widget child;

  const _FormDialog({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.saving,
    required this.error,
    required this.onSave,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          border: Border(
              bottom: BorderSide(color: accentColor.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 17),
              onPressed: () => Navigator.pop(context),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              if (error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_rounded,
                          size: 15, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(error!,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: saving ? null : onSave,
          style: FilledButton.styleFrom(
            backgroundColor: accentColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm delete dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDeleteDialog extends StatelessWidget {
  final String name;
  final String type;
  const _ConfirmDeleteDialog({required this.name, required this.type});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: 8),
          Text('Confirm Action',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
      content: Text(
        'Are you sure you want to remove "$name" from the $type catalog?',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String deleteLabel;
  const _ActionMenu(
      {required this.onEdit,
      required this.onDelete,
      required this.deleteLabel});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Edit', style: TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded,
                size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            Text(deleteLabel,
                style: TextStyle(
                    fontSize: 13, color: AppColors.error)),
          ]),
        ),
      ],
    );
  }
}

class _CatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _CatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600));
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _EmptyState(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int page;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _Pagination({
    required this.page,
    required this.hasPrev,
    required this.hasNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: hasPrev ? onPrev : null,
            icon: const Icon(Icons.chevron_left),
            iconSize: 20,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6)),
            child: Text('Page $page',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDeco(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;

  const _FormField({
    required this.ctrl,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      validator: validator,
      decoration: _fieldDeco(label),
      style: const TextStyle(fontSize: 13),
    );
  }
}
