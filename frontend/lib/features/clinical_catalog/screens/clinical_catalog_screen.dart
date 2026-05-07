import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/clinical_catalog_models.dart';
import '../repository/clinical_catalog_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category metadata
// ─────────────────────────────────────────────────────────────────────────────

const _allergyCategories = [
  ('drug', 'Drug / Medication', Icons.medication, Color(0xFF7C3AED)),
  ('food', 'Food', Icons.restaurant, Color(0xFF059669)),
  ('environmental', 'Environmental', Icons.eco, Color(0xFF0284C7)),
  ('insect', 'Insect / Venom', Icons.bug_report, Color(0xFFD97706)),
  ('latex', 'Latex', Icons.back_hand, Color(0xFFDB2777)),
  ('contrast', 'Contrast Agent', Icons.science, Color(0xFF2563EB)),
  ('chemical', 'Chemical', Icons.water_drop, Color(0xFFDC2626)),
  ('other', 'Other', Icons.more_horiz, Color(0xFF6B7280)),
];

const _conditionCategories = [
  ('cardiovascular', 'Cardiovascular', Icons.favorite, Color(0xFFDC2626)),
  ('endocrine', 'Endocrine / Metabolic', Icons.show_chart, Color(0xFFD97706)),
  ('respiratory', 'Respiratory', Icons.air, Color(0xFF0284C7)),
  ('neurological', 'Neurological', Icons.psychology, Color(0xFF7C3AED)),
  ('musculoskeletal', 'Musculoskeletal', Icons.accessibility_new, Color(0xFF92400E)),
  ('gastrointestinal', 'Gastrointestinal', Icons.medical_services, Color(0xFF059669)),
  ('renal', 'Renal / Urological', Icons.water_drop, Color(0xFF0369A1)),
  ('hematological', 'Hematological', Icons.bloodtype, Color(0xFFBE123C)),
  ('immunological', 'Immunological', Icons.shield, Color(0xFF6D28D9)),
  ('mental_health', 'Mental Health', Icons.self_improvement, Color(0xFF0891B2)),
  ('oncological', 'Oncological', Icons.coronavirus, Color(0xFF9D174D)),
  ('dermatological', 'Dermatological', Icons.face_retouching_natural, Color(0xFFB45309)),
  ('ophthalmological', 'Ophthalmological', Icons.remove_red_eye, Color(0xFF1D4ED8)),
  ('other', 'Other', Icons.more_horiz, Color(0xFF6B7280)),
];

typedef _AllergyMeta = (String, String, IconData, Color);
typedef _ConditionMeta = (String, String, IconData, Color);

_AllergyMeta _allergyMeta(String key) =>
    _allergyCategories.firstWhere((e) => e.$1 == key,
        orElse: () => _allergyCategories.last);

_ConditionMeta _conditionMeta(String key) =>
    _conditionCategories.firstWhere((e) => e.$1 == key,
        orElse: () => _conditionCategories.last);

// ─────────────────────────────────────────────────────────────────────────────
// Export / Import helpers
// ─────────────────────────────────────────────────────────────────────────────

String _dateTag() {
  final n = DateTime.now();
  return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
}

String _escapeCsv(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""').replaceAll('\n', ' ')}"';
  }
  return v;
}

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  for (final line
      in input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    if (line.trim().isEmpty) continue;
    final cells = <String>[];
    final buf = StringBuffer();
    bool inQ = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQ) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQ = false;
          }
        } else {
          buf.write(ch);
        }
      } else {
        if (ch == '"') {
          inQ = true;
        } else if (ch == ',') {
          cells.add(buf.toString());
          buf.clear();
        } else {
          buf.write(ch);
        }
      }
    }
    cells.add(buf.toString());
    rows.add(cells);
  }
  return rows;
}

// ── Allergy CSV / JSON ────────────────────────────────────────────────────────

const _allergyCsvHeader = 'name,category,description,common_symptoms,is_active';

String _allergyToCsvRow(AllergyModel item) => [
      _escapeCsv(item.name),
      item.category,
      _escapeCsv(item.description),
      _escapeCsv(item.commonSymptoms),
      item.isActive.toString(),
    ].join(',');

Map<String, dynamic>? _allergyFromCsvRow(List<String> c) {
  if (c.isEmpty || c[0].trim().isEmpty) return null;
  return {
    'name': c[0].trim(),
    'category': c.length > 1 ? c[1].trim() : 'other',
    'description': c.length > 2 ? c[2].trim() : '',
    'common_symptoms': c.length > 3 ? c[3].trim() : '',
    'is_active': c.length > 4 ? c[4].trim().toLowerCase() != 'false' : true,
  };
}

String _allergiesToJson(List<AllergyModel> items) =>
    const JsonEncoder.withIndent('  ').convert({
      'type': 'clinical_catalog_allergies',
      'exported_at': DateTime.now().toIso8601String(),
      'count': items.length,
      'data': items.map((e) => e.toJson()).toList(),
    });

List<Map<String, dynamic>>? _parseAllergyJson(String content) {
  try {
    final d = jsonDecode(content);
    if (d is Map<String, dynamic> && d['data'] is List) {
      return (d['data'] as List).cast<Map<String, dynamic>>();
    }
    if (d is List) return d.cast<Map<String, dynamic>>();
    return null;
  } catch (_) {
    return null;
  }
}

// ── Condition CSV / JSON ──────────────────────────────────────────────────────

const _conditionCsvHeader = 'name,category,icd_code,description,is_active';

String _conditionToCsvRow(ChronicConditionModel item) => [
      _escapeCsv(item.name),
      item.category,
      item.icdCode,
      _escapeCsv(item.description),
      item.isActive.toString(),
    ].join(',');

Map<String, dynamic>? _conditionFromCsvRow(List<String> c) {
  if (c.isEmpty || c[0].trim().isEmpty) return null;
  return {
    'name': c[0].trim(),
    'category': c.length > 1 ? c[1].trim() : 'other',
    'icd_code': c.length > 2 ? c[2].trim() : '',
    'description': c.length > 3 ? c[3].trim() : '',
    'is_active': c.length > 4 ? c[4].trim().toLowerCase() != 'false' : true,
  };
}

String _conditionsToJson(List<ChronicConditionModel> items) =>
    const JsonEncoder.withIndent('  ').convert({
      'type': 'clinical_catalog_conditions',
      'exported_at': DateTime.now().toIso8601String(),
      'count': items.length,
      'data': items.map((e) => e.toJson()).toList(),
    });

List<Map<String, dynamic>>? _parseConditionJson(String content) {
  try {
    final d = jsonDecode(content);
    if (d is Map<String, dynamic> && d['data'] is List) {
      return (d['data'] as List).cast<Map<String, dynamic>>();
    }
    if (d is List) return d.cast<Map<String, dynamic>>();
    return null;
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class ClinicalCatalogScreen extends StatefulWidget {
  const ClinicalCatalogScreen({super.key});

  @override
  State<ClinicalCatalogScreen> createState() => _ClinicalCatalogScreenState();
}

class _ClinicalCatalogScreenState extends State<ClinicalCatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  // Counts updated by child tabs via callback
  int _allergyCount = 0;
  int _conditionCount = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Gradient header ──────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Back row + title
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.health_and_safety,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Clinical Catalog',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2)),
                            Text('Global reference data · managed by super admin',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _StatChip(
                        icon: Icons.warning_amber_rounded,
                        label: '$_allergyCount Allergies',
                        color: const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        icon: Icons.monitor_heart_outlined,
                        label: '$_conditionCount Conditions',
                        color: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),

                // Pill tab selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        _TabPill(
                          label: 'Allergies',
                          icon: Icons.warning_amber_rounded,
                          active: _tab.index == 0,
                          onTap: () => _tab.animateTo(0),
                        ),
                        _TabPill(
                          label: 'Chronic Conditions',
                          icon: Icons.monitor_heart_outlined,
                          active: _tab.index == 1,
                          onTap: () => _tab.animateTo(1),
                        ),
                      ],
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
            children: [
              _AllergiesTab(
                onCountChanged: (n) =>
                    setState(() => _allergyCount = n),
              ),
              _ConditionsTab(
                onCountChanged: (n) =>
                    setState(() => _conditionCount = n),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip for header
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill tab widget
// ─────────────────────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TabPill(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: active ? const Color(0xFF1D4ED8) : Colors.white70),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w400,
                      color: active
                          ? const Color(0xFF1D4ED8)
                          : Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Allergies Tab
// ─────────────────────────────────────────────────────────────────────────────

class _AllergiesTab extends StatefulWidget {
  final ValueChanged<int> onCountChanged;
  const _AllergiesTab({required this.onCountChanged});

  @override
  State<_AllergiesTab> createState() => _AllergiesTabState();
}

class _AllergiesTabState extends State<_AllergiesTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = ClinicalCatalogRepository();
  final _searchCtrl = TextEditingController();

  List<AllergyModel> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _category = '';

  @override
  bool get wantKeepAlive => true;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.getAllergies(q: _search, category: _category);
      if (mounted) {
        setState(() => _items = items);
        widget.onCountChanged(items.length);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String v) {
    _search = v;
    _load();
  }

  Future<void> _showForm({AllergyModel? item}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AllergyFormDialog(item: item),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(AllergyModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteDialog(
        title: 'Delete Allergy',
        name: item.name,
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteAllergy(item.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    try {
      final all = await _repo.getAllergies(pageSize: 10000);
      final tag = _dateTag();
      final filename = 'allergies_$tag.csv';
      final content = '$_allergyCsvHeader\n${all.map(_allergyToCsvRow).join('\n')}';
      final path = await downloadTextFile(filename, content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(path != null
              ? 'Saved to $path'
              : '${all.length} allergies exported as $filename'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _exportJson() async {
    try {
      final all = await _repo.getAllergies(pageSize: 10000);
      final tag = _dateTag();
      final filename = 'allergies_$tag.json';
      final path = await downloadTextFile(filename, _allergiesToJson(all));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(path != null
              ? 'Saved to $path'
              : '${all.length} allergies exported as $filename'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final content = utf8.decode(file.bytes!);
    final ext = (file.extension ?? '').toLowerCase();

    List<Map<String, dynamic>> records = [];
    if (ext == 'json') {
      final parsed = _parseAllergyJson(content);
      if (parsed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Invalid JSON — expected allergy data'),
            backgroundColor: AppColors.error,
          ));
        }
        return;
      }
      records = parsed;
    } else {
      final rows = _parseCsv(content);
      final start =
          rows.isNotEmpty && rows[0].first.toLowerCase() == 'name' ? 1 : 0;
      for (int i = start; i < rows.length; i++) {
        final r = _allergyFromCsvRow(rows[i]);
        if (r != null) records.add(r);
      }
    }

    if (records.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No valid records found in file'),
          backgroundColor: AppColors.warning,
        ));
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ImportConfirmDialog(
        title: 'Import Allergies',
        filename: file.name,
        count: records.length,
        color: const Color(0xFF7C3AED),
      ),
    );
    if (confirmed != true || !mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(
        title: 'Importing Allergies',
        records: records,
        onCreate: (rec) => _repo.createAllergy(rec),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // ── Toolbar ───────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(child: _SearchField(ctrl: _searchCtrl, hint: 'Search allergies…', onChanged: _onSearch)),
                const SizedBox(width: 8),
                _FilterButton(
                  categories: _allergyCategories
                      .map((e) => (e.$1, e.$2))
                      .toList(),
                  value: _category,
                  onChanged: (v) {
                    setState(() => _category = v);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _AddButton(onPressed: () => _showForm()),
                const SizedBox(width: 8),
                _MoreMenuButton(
                  onExportCsv: _exportCsv,
                  onExportJson: _exportJson,
                  onImport: _importFile,
                ),
              ],
            ),
          ),

          // ── Active category banner ────────────────────────────────────
          if (_category.isNotEmpty)
            _ActiveFilterBanner(
              label: _allergyMeta(_category).$2,
              color: _allergyMeta(_category).$4,
              onClear: () {
                setState(() => _category = '');
                _load();
              },
            ),

          // ── Count summary ─────────────────────────────────────────────
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${_items.length} allerg${_items.length == 1 ? 'y' : 'ies'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? _EmptyState(
                            icon: Icons.warning_amber_rounded,
                            title: 'No allergies found',
                            subtitle: _search.isNotEmpty
                                ? 'Try a different search term'
                                : 'Add the first allergy to get started',
                            onAdd: () => _showForm(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _items.length,
                            itemBuilder: (_, i) => _AllergyCard(
                              item: _items[i],
                              onEdit: () => _showForm(item: _items[i]),
                              onDelete: () => _confirmDelete(_items[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chronic Conditions Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ConditionsTab extends StatefulWidget {
  final ValueChanged<int> onCountChanged;
  const _ConditionsTab({required this.onCountChanged});

  @override
  State<_ConditionsTab> createState() => _ConditionsTabState();
}

class _ConditionsTabState extends State<_ConditionsTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = ClinicalCatalogRepository();
  final _searchCtrl = TextEditingController();

  List<ChronicConditionModel> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _category = '';

  @override
  bool get wantKeepAlive => true;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.getConditions(q: _search, category: _category);
      if (mounted) {
        setState(() => _items = items);
        widget.onCountChanged(items.length);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String v) {
    _search = v;
    _load();
  }

  Future<void> _showForm({ChronicConditionModel? item}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ConditionFormDialog(item: item),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(ChronicConditionModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteDialog(
        title: 'Delete Condition',
        name: item.name,
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteCondition(item.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    try {
      final all = await _repo.getConditions(pageSize: 10000);
      final tag = _dateTag();
      final filename = 'conditions_$tag.csv';
      final content =
          '$_conditionCsvHeader\n${all.map(_conditionToCsvRow).join('\n')}';
      final path = await downloadTextFile(filename, content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(path != null
              ? 'Saved to $path'
              : '${all.length} conditions exported as $filename'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _exportJson() async {
    try {
      final all = await _repo.getConditions(pageSize: 10000);
      final tag = _dateTag();
      final filename = 'conditions_$tag.json';
      final path = await downloadTextFile(filename, _conditionsToJson(all));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(path != null
              ? 'Saved to $path'
              : '${all.length} conditions exported as $filename'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final content = utf8.decode(file.bytes!);
    final ext = (file.extension ?? '').toLowerCase();

    List<Map<String, dynamic>> records = [];
    if (ext == 'json') {
      final parsed = _parseConditionJson(content);
      if (parsed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Invalid JSON — expected condition data'),
            backgroundColor: AppColors.error,
          ));
        }
        return;
      }
      records = parsed;
    } else {
      final rows = _parseCsv(content);
      final start =
          rows.isNotEmpty && rows[0].first.toLowerCase() == 'name' ? 1 : 0;
      for (int i = start; i < rows.length; i++) {
        final r = _conditionFromCsvRow(rows[i]);
        if (r != null) records.add(r);
      }
    }

    if (records.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No valid records found in file'),
          backgroundColor: AppColors.warning,
        ));
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ImportConfirmDialog(
        title: 'Import Conditions',
        filename: file.name,
        count: records.length,
        color: const Color(0xFF0284C7),
      ),
    );
    if (confirmed != true || !mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(
        title: 'Importing Conditions',
        records: records,
        onCreate: (rec) => _repo.createCondition(rec),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // ── Toolbar ───────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(child: _SearchField(ctrl: _searchCtrl, hint: 'Search conditions or ICD code…', onChanged: _onSearch)),
                const SizedBox(width: 8),
                _FilterButton(
                  categories: _conditionCategories
                      .map((e) => (e.$1, e.$2))
                      .toList(),
                  value: _category,
                  onChanged: (v) {
                    setState(() => _category = v);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _AddButton(onPressed: () => _showForm()),
                const SizedBox(width: 8),
                _MoreMenuButton(
                  onExportCsv: _exportCsv,
                  onExportJson: _exportJson,
                  onImport: _importFile,
                ),
              ],
            ),
          ),

          // ── Active category banner ────────────────────────────────────
          if (_category.isNotEmpty)
            _ActiveFilterBanner(
              label: _conditionMeta(_category).$2,
              color: _conditionMeta(_category).$4,
              onClear: () {
                setState(() => _category = '');
                _load();
              },
            ),

          // ── Count summary ─────────────────────────────────────────────
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${_items.length} condition${_items.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? _EmptyState(
                            icon: Icons.monitor_heart_outlined,
                            title: 'No conditions found',
                            subtitle: _search.isNotEmpty
                                ? 'Try a different search term'
                                : 'Add the first condition to get started',
                            onAdd: () => _showForm(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _items.length,
                            itemBuilder: (_, i) => _ConditionCard(
                              item: _items[i],
                              onEdit: () => _showForm(item: _items[i]),
                              onDelete: () => _confirmDelete(_items[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared toolbar widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField(
      {required this.ctrl, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    ctrl.clear();
                    onChanged('');
                  },
                )
              : null,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.background,
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final List<(String, String)> categories;
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterButton(
      {required this.categories, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final active = value.isNotEmpty;
    return PopupMenuButton<String>(
      initialValue: value.isEmpty ? null : value,
      onSelected: onChanged,
      tooltip: 'Filter by category',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: '',
          child: Row(children: [
            Icon(Icons.clear_all, size: 16, color: Color(0xFF6B7280)),
            SizedBox(width: 8),
            Text('All Categories'),
          ]),
        ),
        const PopupMenuDivider(),
        ...categories.map(
          (c) => PopupMenuItem(
            value: c.$1,
            child: Text(c.$2),
          ),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color: active ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(10),
          color: active
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune,
                size: 15,
                color: active ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              'Filter',
              style: TextStyle(
                  fontSize: 13,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add New'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _ActiveFilterBanner extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onClear;

  const _ActiveFilterBanner(
      {required this.label, required this.color, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
      color: color.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 14, color: color),
          const SizedBox(width: 6),
          Text('Filtered: ',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: Row(
              children: [
                Icon(Icons.close, size: 14, color: color),
                const SizedBox(width: 2),
                Text('Clear',
                    style: TextStyle(
                        fontSize: 12, color: color, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty & Error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Entry'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Allergy Card
// ─────────────────────────────────────────────────────────────────────────────

class _AllergyCard extends StatelessWidget {
  final AllergyModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AllergyCard(
      {required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final meta = _allergyMeta(item.category);
    final color = meta.$4;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left accent
              Container(width: 4, color: color),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(meta.$3, size: 18, color: color),
                      ),
                      const SizedBox(width: 12),
                      // Name + symptoms
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(item.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (!item.isActive)
                                  _Badge(
                                      label: 'Inactive',
                                      bg: AppColors.warning.withValues(alpha: 0.15),
                                      fg: AppColors.warning),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Category pill
                            _Badge(
                              label: meta.$2,
                              bg: color.withValues(alpha: 0.09),
                              fg: color,
                            ),
                            if (item.commonSymptoms.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _SymptomsRow(symptoms: item.commonSymptoms),
                            ],
                          ],
                        ),
                      ),
                      // Actions
                      _CardActions(onEdit: onEdit, onDelete: onDelete),
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
// Chronic Condition Card
// ─────────────────────────────────────────────────────────────────────────────

class _ConditionCard extends StatelessWidget {
  final ChronicConditionModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConditionCard(
      {required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final meta = _conditionMeta(item.category);
    final color = meta.$4;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left accent
              Container(width: 4, color: color),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(meta.$3, size: 18, color: color),
                      ),
                      const SizedBox(width: 12),
                      // Name + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(item.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (!item.isActive)
                                  _Badge(
                                      label: 'Inactive',
                                      bg: AppColors.warning.withValues(alpha: 0.15),
                                      fg: AppColors.warning),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _Badge(
                                  label: meta.$2,
                                  bg: color.withValues(alpha: 0.09),
                                  fg: color,
                                ),
                                if (item.icdCode.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  _Badge(
                                    label: 'ICD: ${item.icdCode}',
                                    bg: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                    fg: const Color(0xFF0284C7),
                                    icon: Icons.tag,
                                  ),
                                ],
                              ],
                            ),
                            if (item.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(item.description,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      // Actions
                      _CardActions(onEdit: onEdit, onDelete: onDelete),
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
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final IconData? icon;

  const _Badge(
      {required this.label,
      required this.bg,
      required this.fg,
      this.border,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _SymptomsRow extends StatelessWidget {
  final String symptoms;
  const _SymptomsRow({required this.symptoms});

  @override
  Widget build(BuildContext context) {
    final parts =
        symptoms.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: parts.take(4).map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(s,
              style: TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        );
      }).toList()
        ..addAll(parts.length > 4
            ? [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('+${parts.length - 4} more',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                )
              ]
            : []),
    );
  }
}

class _CardActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CardActions({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.edit_outlined,
                size: 16, color: AppColors.primary),
          ),
        ),
        InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.delete_outline,
                size: 16, color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete confirmation dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final String title;
  final String name;

  const _DeleteDialog({required this.title, required this.name});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.delete_forever_outlined,
                color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
          children: [
            const TextSpan(text: 'Are you sure you want to delete '),
            TextSpan(
                text: '"$name"',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: '? This action cannot be undone.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Allergy Form Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AllergyFormDialog extends StatefulWidget {
  final AllergyModel? item;
  const _AllergyFormDialog({this.item});

  @override
  State<_AllergyFormDialog> createState() => _AllergyFormDialogState();
}

class _AllergyFormDialogState extends State<_AllergyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ClinicalCatalogRepository();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _symptoms;
  late String _category;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _symptoms = TextEditingController(text: item?.commonSymptoms ?? '');
    _category = item?.category ?? _allergyCategories.first.$1;
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _symptoms.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _name.text.trim(),
        'category': _category,
        'description': _description.text.trim(),
        'common_symptoms': _symptoms.text.trim(),
        'is_active': _isActive,
      };
      if (_isEdit) {
        await _repo.updateAllergy(widget.item!.id, payload);
      } else {
        await _repo.createAllergy(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _allergyMeta(_category);
    return _FormDialog(
      isEdit: _isEdit,
      title: _isEdit ? 'Edit Allergy' : 'New Allergy',
      accentColor: meta.$4,
      icon: meta.$3,
      saving: _saving,
      onSave: _save,
      formKey: _formKey,
      fields: [
        _FL(
          label: 'Name *',
          child: TextFormField(
            controller: _name,
            decoration: _inputDec('e.g. Penicillin'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        _FL(
          label: 'Category',
          child: DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: _inputDec(null),
            items: _allergyCategories
                .map((c) => DropdownMenuItem(
                    value: c.$1,
                    child: Row(children: [
                      Icon(c.$3, size: 16, color: c.$4),
                      const SizedBox(width: 8),
                      Text(c.$2),
                    ])))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
        ),
        _FL(
          label: 'Common Symptoms',
          child: TextFormField(
            controller: _symptoms,
            decoration:
                _inputDec('e.g. Rash, hives, anaphylaxis (comma-separated)'),
            maxLines: 2,
          ),
        ),
        _FL(
          label: 'Description',
          child: TextFormField(
            controller: _description,
            decoration: _inputDec('Optional clinical description'),
            maxLines: 3,
          ),
        ),
        _ActiveToggle(
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chronic Condition Form Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ConditionFormDialog extends StatefulWidget {
  final ChronicConditionModel? item;
  const _ConditionFormDialog({this.item});

  @override
  State<_ConditionFormDialog> createState() => _ConditionFormDialogState();
}

class _ConditionFormDialogState extends State<_ConditionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ClinicalCatalogRepository();

  late final TextEditingController _name;
  late final TextEditingController _icdCode;
  late final TextEditingController _description;
  late String _category;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _icdCode = TextEditingController(text: item?.icdCode ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _category = item?.category ?? _conditionCategories.first.$1;
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _icdCode.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _name.text.trim(),
        'category': _category,
        'icd_code': _icdCode.text.trim(),
        'description': _description.text.trim(),
        'is_active': _isActive,
      };
      if (_isEdit) {
        await _repo.updateCondition(widget.item!.id, payload);
      } else {
        await _repo.createCondition(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _conditionMeta(_category);
    return _FormDialog(
      isEdit: _isEdit,
      title: _isEdit ? 'Edit Condition' : 'New Condition',
      accentColor: meta.$4,
      icon: meta.$3,
      saving: _saving,
      onSave: _save,
      formKey: _formKey,
      fields: [
        _FL(
          label: 'Name *',
          child: TextFormField(
            controller: _name,
            decoration: _inputDec('e.g. Type 2 Diabetes Mellitus'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        _FL(
          label: 'Category',
          child: DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: _inputDec(null),
            items: _conditionCategories
                .map((c) => DropdownMenuItem(
                    value: c.$1,
                    child: Row(children: [
                      Icon(c.$3, size: 16, color: c.$4),
                      const SizedBox(width: 8),
                      Text(c.$2),
                    ])))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
        ),
        _FL(
          label: 'ICD-10 Code',
          child: TextFormField(
            controller: _icdCode,
            decoration: _inputDec('e.g. E11'),
            textCapitalization: TextCapitalization.characters,
          ),
        ),
        _FL(
          label: 'Description',
          child: TextFormField(
            controller: _description,
            decoration: _inputDec('Clinical description'),
            maxLines: 3,
          ),
        ),
        _ActiveToggle(
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form dialog shell
// ─────────────────────────────────────────────────────────────────────────────

class _FormDialog extends StatelessWidget {
  final bool isEdit;
  final String title;
  final Color accentColor;
  final IconData icon;
  final bool saving;
  final VoidCallback onSave;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;

  const _FormDialog({
    required this.isEdit,
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.saving,
    required this.onSave,
    required this.formKey,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colored header strip
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                    bottom: BorderSide(
                        color: accentColor.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context, false),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Form fields
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: fields
                        .expand((w) => [w, const SizedBox(height: 14)])
                        .toList()
                      ..removeLast(),
                  ),
                ),
              ),
            ),
            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                    top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: saving ? null : onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(110, 40),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Save Changes' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form field label wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _FL extends StatelessWidget {
  final String label;
  final Widget child;

  const _FL({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _ActiveToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ActiveToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.background,
      ),
      child: SwitchListTile(
        title: const Text('Active',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(
          value ? 'Visible to all users' : 'Hidden from users',
          style: TextStyle(
              fontSize: 11,
              color: value ? const Color(0xFF059669) : AppColors.textSecondary),
        ),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeColor: const Color(0xFF059669),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input decoration helper
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDec(String? hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
    );

// ─────────────────────────────────────────────────────────────────────────────
// More menu button (export / import)
// ─────────────────────────────────────────────────────────────────────────────

class _MoreMenuButton extends StatelessWidget {
  final VoidCallback onExportCsv;
  final VoidCallback onExportJson;
  final VoidCallback onImport;

  const _MoreMenuButton({
    required this.onExportCsv,
    required this.onExportJson,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        switch (v) {
          case 'csv':
            onExportCsv();
          case 'json':
            onExportJson();
          case 'import':
            onImport();
        }
      },
      tooltip: 'Import / Export',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      offset: const Offset(0, 44),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'csv',
          child: Row(children: [
            Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Export as CSV', style: TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'json',
          child: Row(children: [
            Icon(Icons.data_object, size: 16, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Export as JSON', style: TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'import',
          child: Row(children: [
            Icon(Icons.upload_file_outlined, size: 16, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('Import from file', style: TextStyle(fontSize: 13)),
          ]),
        ),
      ],
      child: Builder(
        builder: (ctx) => Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.surface,
          ),
          child: Icon(Icons.more_horiz,
              color: AppColors.textSecondary, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Import confirm dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ImportConfirmDialog extends StatelessWidget {
  final String title;
  final String filename;
  final int count;
  final Color color;

  const _ImportConfirmDialog({
    required this.title,
    required this.filename,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.upload_file, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(filename,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              children: [
                TextSpan(
                    text: '$count ',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: color)),
                const TextSpan(text: 'records found. Import all?'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Records that already exist may return an error and will be skipped.',
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.upload, size: 16),
          label: const Text('Import'),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Import progress dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ImportProgressDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> records;
  final Future<dynamic> Function(Map<String, dynamic>) onCreate;

  const _ImportProgressDialog({
    required this.title,
    required this.records,
    required this.onCreate,
  });

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  int _done = 0;
  int _failed = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (final rec in widget.records) {
      try {
        await widget.onCreate(rec);
      } catch (_) {
        if (mounted) setState(() => _failed++);
      }
      if (mounted) setState(() => _done++);
    }
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.records.length;
    final success = _done - _failed;
    final progress = total > 0 ? _done / total : 0.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          if (!_finished)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
          const SizedBox(width: 10),
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _finished
                ? 'Done! Imported $success of $total records${_failed > 0 ? ' ($_failed failed).' : '.'}'
                : 'Importing $_done of $total…',
            style: TextStyle(
                fontSize: 13,
                color: _finished && _failed == 0
                    ? AppColors.success
                    : AppColors.textPrimary),
          ),
          if (_finished && _failed > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$_failed records could not be imported (duplicate name or invalid data).',
              style:
                  TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: _finished ? () => Navigator.pop(context) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(_finished ? 'Done' : 'Importing…'),
        ),
      ],
    );
  }
}
