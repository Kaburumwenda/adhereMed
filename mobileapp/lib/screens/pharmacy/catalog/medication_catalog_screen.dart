import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ── data ──
final _medicationsProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/medications/', queryParameters: {'page_size': 1000});
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

// ── constants ──
const _categories = [
  'analgesic', 'antibiotic', 'antifungal', 'antiviral', 'antiparasitic',
  'antimalarial', 'antihypertensive', 'antidiabetic', 'antihistamine',
  'antacid', 'cardiovascular', 'respiratory', 'cns', 'hormone',
  'vitamin', 'vaccine', 'dermatological', 'ophthalmic', 'oncology',
  'immunosuppressant', 'nsaid', 'other',
];

const _dosageForms = [
  'tablet', 'capsule', 'syrup', 'injection', 'cream', 'ointment',
  'drops', 'inhaler', 'suppository', 'suspension', 'powder', 'gel',
  'patch', 'lozenge', 'spray', 'solution', 'other',
];

String _pretty(String s) => s.replaceAll('_', ' ').replaceFirst(s[0], s[0].toUpperCase());

class MedicationCatalogScreen extends ConsumerStatefulWidget {
  const MedicationCatalogScreen({super.key});
  @override
  ConsumerState<MedicationCatalogScreen> createState() => _MedicationCatalogScreenState();
}

class _MedicationCatalogScreenState extends ConsumerState<MedicationCatalogScreen> {
  String _search = '';
  String? _catFilter;
  String? _formFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final medsAsync = ref.watch(_medicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Catalog'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: () => ref.invalidate(_medicationsProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(context, cs),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Medication'),
      ),
      body: medsAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load medications', onRetry: () => ref.invalidate(_medicationsProvider)),
        data: (meds) {
          // KPI
          final total = meds.length;
          final active = meds.where((m) => m['is_active'] == true).length;
          final rx = meds.where((m) => m['requires_prescription'] == true).length;
          final otc = total - rx;

          // filter
          final filtered = meds.where((m) {
            if (_search.isNotEmpty) {
              final q = _search.toLowerCase();
              final name = (m['generic_name'] ?? '').toString().toLowerCase();
              final abbr = (m['abbreviation'] ?? '').toString().toLowerCase();
              final strength = (m['strength'] ?? '').toString().toLowerCase();
              final sub = (m['subcategory'] ?? '').toString().toLowerCase();
              final brands = ((m['brand_names'] as List?) ?? []).join(' ').toLowerCase();
              if (!name.contains(q) && !abbr.contains(q) && !strength.contains(q) && !sub.contains(q) && !brands.contains(q)) return false;
            }
            if (_catFilter != null && m['category'] != _catFilter) return false;
            if (_formFilter != null && m['dosage_form'] != _formFilter) return false;
            return true;
          }).toList();

          return Column(children: [
            // ── KPI strip ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(height: 52, child: ListView(scrollDirection: Axis.horizontal, children: [
                _KpiTile('Total', '$total', Icons.medication_rounded, cs.primary, cs),
                _KpiTile('Active', '$active', Icons.check_circle_rounded, const Color(0xFF22C55E), cs),
                _KpiTile('Rx Only', '$rx', Icons.receipt_long_rounded, const Color(0xFFEF4444), cs),
                _KpiTile('OTC', '$otc', Icons.storefront_rounded, const Color(0xFF3B82F6), cs),
              ])),
            ),

            // ── Search ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search name, brand, abbreviation...', hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20), isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),

            // ── Filters ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
                _DropdownChip(
                  label: _catFilter != null ? _pretty(_catFilter!) : 'Category',
                  selected: _catFilter != null, cs: cs,
                  items: _categories,
                  onSelected: (v) => setState(() => _catFilter = v),
                  onClear: () => setState(() => _catFilter = null),
                ),
                const SizedBox(width: 6),
                _DropdownChip(
                  label: _formFilter != null ? _pretty(_formFilter!) : 'Dosage Form',
                  selected: _formFilter != null, cs: cs,
                  items: _dosageForms,
                  onSelected: (v) => setState(() => _formFilter = v),
                  onClear: () => setState(() => _formFilter = null),
                ),
                const SizedBox(width: 8),
                Center(child: Text('${filtered.length} shown', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
              ])),
            ),

            // ── List ──
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(icon: Icons.medication_rounded, title: 'No medications found')
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(_medicationsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _MedCard(
                          med: filtered[i], cs: cs,
                          onEdit: () => _showFormDialog(context, cs, existing: filtered[i]),
                          onDelete: () => _deleteMed(filtered[i]['id']),
                        ),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _deleteMed(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete medication'),
      content: const Text('This will permanently remove this medication from the catalog.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/medications/$id/');
      ref.invalidate(_medicationsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  void _showFormDialog(BuildContext ctx, ColorScheme cs, {Map? existing}) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MedFormSheet(existing: existing, cs: cs, onSaved: () { ref.invalidate(_medicationsProvider); Navigator.pop(ctx); }),
    );
  }
}

// ══════════════════════════════════════════
// KPI Tile
// ══════════════════════════════════════════
class _KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;
  const _KpiTile(this.label, this.value, this.icon, this.color, this.cs);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: color), const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
        Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════
// Dropdown filter chip
// ══════════════════════════════════════════
class _DropdownChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme cs;
  final List<String> items;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;
  const _DropdownChip({required this.label, required this.selected, required this.cs, required this.items, required this.onSelected, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => DraggableScrollableSheet(
            expand: false, initialChildSize: 0.5, maxChildSize: 0.8, minChildSize: 0.3,
            builder: (_, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              ...items.map((item) => ListTile(
                dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                title: Text(_pretty(item), style: const TextStyle(fontSize: 13)),
                onTap: () => Navigator.pop(context, item),
              )),
            ]),
          ),
        );
        if (result != null) onSelected(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? cs.primary : cs.onSurfaceVariant)),
          const SizedBox(width: 4),
          if (selected) GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 14, color: cs.primary))
          else Icon(Icons.expand_more_rounded, size: 14, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// Medication Card
// ══════════════════════════════════════════
class _MedCard extends StatelessWidget {
  final Map med;
  final ColorScheme cs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MedCard({required this.med, required this.cs, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isRx = med['requires_prescription'] == true;
    final isActive = med['is_active'] == true;
    final brands = ((med['brand_names'] as List?) ?? []).take(3).join(', ');
    final category = (med['category'] ?? '').toString();
    final form = (med['dosage_form'] ?? '').toString();

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.medication_rounded, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(med['generic_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (brands.isNotEmpty) Text(brands, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            // Rx / OTC badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isRx ? const Color(0xFFEF4444) : const Color(0xFF22C55E)).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(isRx ? 'Rx' : 'OTC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isRx ? const Color(0xFFEF4444) : const Color(0xFF22C55E))),
            ),
            const SizedBox(width: 4),
            if (!isActive) Icon(Icons.pause_circle_rounded, size: 16, color: cs.onSurfaceVariant),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 16, color: cs.onSurfaceVariant),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit', style: TextStyle(fontSize: 13))])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red))])),
              ],
              onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); },
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (category.isNotEmpty) _chip(_pretty(category), const Color(0xFF0D9488), cs),
            if (form.isNotEmpty) _chip(_pretty(form), const Color(0xFF6366F1), cs),
            if ((med['strength'] ?? '').toString().isNotEmpty) _chip(med['strength'], cs.onSurfaceVariant, cs),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color color, ColorScheme cs) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
  );
}

// ══════════════════════════════════════════
// Create/Edit Form Sheet
// ══════════════════════════════════════════
class _MedFormSheet extends ConsumerStatefulWidget {
  final Map? existing;
  final ColorScheme cs;
  final VoidCallback onSaved;
  const _MedFormSheet({this.existing, required this.cs, required this.onSaved});
  @override
  ConsumerState<_MedFormSheet> createState() => _MedFormSheetState();
}

class _MedFormSheetState extends ConsumerState<_MedFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _genericName;
  late final TextEditingController _abbreviation;
  late final TextEditingController _subcategory;
  late final TextEditingController _strength;
  late final TextEditingController _unit;
  late final TextEditingController _controlledClass;
  late final TextEditingController _description;
  late final TextEditingController _sideEffects;
  late final TextEditingController _contraindications;
  late final TextEditingController _brandInput;

  String? _category;
  String? _dosageForm;
  bool _requiresPrescription = true;
  bool _isActive = true;
  List<String> _brandNames = [];
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _genericName = TextEditingController(text: e?['generic_name'] ?? '');
    _abbreviation = TextEditingController(text: e?['abbreviation'] ?? '');
    _subcategory = TextEditingController(text: e?['subcategory'] ?? '');
    _strength = TextEditingController(text: e?['strength'] ?? '');
    _unit = TextEditingController(text: e?['unit'] ?? '');
    _controlledClass = TextEditingController(text: e?['controlled_substance_class'] ?? '');
    _description = TextEditingController(text: e?['description'] ?? '');
    _sideEffects = TextEditingController(text: e?['side_effects'] ?? '');
    _contraindications = TextEditingController(text: e?['contraindications'] ?? '');
    _brandInput = TextEditingController();
    _category = e?['category'];
    _dosageForm = e?['dosage_form'];
    _requiresPrescription = e?['requires_prescription'] ?? true;
    _isActive = e?['is_active'] ?? true;
    _brandNames = List<String>.from(e?['brand_names'] ?? []);
  }

  @override
  void dispose() {
    _genericName.dispose(); _abbreviation.dispose(); _subcategory.dispose();
    _strength.dispose(); _unit.dispose(); _controlledClass.dispose();
    _description.dispose(); _sideEffects.dispose(); _contraindications.dispose();
    _brandInput.dispose();
    super.dispose();
  }

  void _addBrand() {
    final v = _brandInput.text.trim();
    if (v.isNotEmpty && !_brandNames.contains(v)) {
      setState(() => _brandNames.add(v));
      _brandInput.clear();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final data = {
        'generic_name': _genericName.text.trim(),
        'abbreviation': _abbreviation.text.trim(),
        'category': _category,
        'subcategory': _subcategory.text.trim(),
        'dosage_form': _dosageForm,
        'strength': _strength.text.trim(),
        'unit': _unit.text.trim(),
        'controlled_substance_class': _controlledClass.text.trim(),
        'brand_names': _brandNames,
        'description': _description.text.trim(),
        'side_effects': _sideEffects.text.trim(),
        'contraindications': _contraindications.text.trim(),
        'requires_prescription': _requiresPrescription,
        'is_active': _isActive,
      };
      if (_isEdit) {
        await dio.put('/medications/${widget.existing!['id']}/', data: data);
      } else {
        await dio.post('/medications/', data: data);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.92, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, ctrl) => Form(
        key: _formKey,
        child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
          // Handle
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Row(children: [
            Text(_isEdit ? 'Edit Medication' : 'New Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.onSurface)),
            const Spacer(),
            TextButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)) : Icon(Icons.check_rounded, size: 18, color: cs.primary),
              label: Text(_isEdit ? 'Update' : 'Create', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
            ),
          ]),
          const SizedBox(height: 16),

          // Generic name
          TextFormField(
            controller: _genericName,
            decoration: _dec('Generic Name *', Icons.medication_rounded),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 12),

          // Abbreviation
          TextFormField(controller: _abbreviation, decoration: _dec('Abbreviation', Icons.short_text_rounded).copyWith(hintText: 'PCM, AMOX, RHZE…', hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5)))),
          const SizedBox(height: 12),

          // Category + Dosage form
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: _dec('Category *', Icons.category_rounded),
              isExpanded: true,
              validator: (v) => v == null ? 'Required' : null,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(_pretty(c), style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _category = v),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _dosageForm,
              decoration: _dec('Dosage Form *', Icons.medical_services_rounded),
              isExpanded: true,
              validator: (v) => v == null ? 'Required' : null,
              items: _dosageForms.map((f) => DropdownMenuItem(value: f, child: Text(_pretty(f), style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _dosageForm = v),
            )),
          ]),
          const SizedBox(height: 12),

          // Subcategory
          TextFormField(controller: _subcategory, decoration: _dec('Subcategory', Icons.label_rounded)),
          const SizedBox(height: 12),

          // Strength + Unit
          Row(children: [
            Expanded(child: TextFormField(controller: _strength, decoration: _dec('Strength', Icons.science_rounded).copyWith(hintText: '500mg, 10mg/5ml', hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5))))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _unit, decoration: _dec('Unit', Icons.straighten_rounded).copyWith(hintText: 'tab, ml, vial', hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5))))),
          ]),
          const SizedBox(height: 12),

          // Controlled substance class
          TextFormField(controller: _controlledClass, decoration: _dec('Controlled Substance Class', Icons.gavel_rounded).copyWith(hintText: 'e.g. Schedule II', hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5)))),
          const SizedBox(height: 12),

          // Brand names
          Text('Brand Names', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(
              controller: _brandInput,
              decoration: InputDecoration(
                hintText: 'Add brand and press +', hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (_) => _addBrand(),
            )),
            const SizedBox(width: 8),
            IconButton(onPressed: _addBrand, icon: Icon(Icons.add_circle_rounded, color: cs.primary)),
          ]),
          if (_brandNames.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 6, runSpacing: 4, children: _brandNames.map((b) => Chip(
              label: Text(b, style: const TextStyle(fontSize: 11)),
              deleteIcon: const Icon(Icons.close_rounded, size: 14),
              onDeleted: () => setState(() => _brandNames.remove(b)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList()),
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(controller: _description, maxLines: 2, decoration: _dec('Description', Icons.description_rounded)),
          const SizedBox(height: 12),
          TextFormField(controller: _sideEffects, maxLines: 2, decoration: _dec('Side Effects', Icons.report_problem_rounded)),
          const SizedBox(height: 12),
          TextFormField(controller: _contraindications, maxLines: 2, decoration: _dec('Contraindications', Icons.block_rounded)),
          const SizedBox(height: 16),

          // Switches
          SwitchListTile(
            title: const Text('Requires Prescription', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(_requiresPrescription ? 'Rx only — prescription needed' : 'OTC — over the counter', style: const TextStyle(fontSize: 11)),
            value: _requiresPrescription, onChanged: (v) => setState(() => _requiresPrescription = v),
            activeThumbColor: const Color(0xFFEF4444),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4), dense: true,
          ),
          SwitchListTile(
            title: const Text('Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(_isActive ? 'Available for use' : 'Hidden / disabled', style: const TextStyle(fontSize: 11)),
            value: _isActive, onChanged: (v) => setState(() => _isActive = v),
            activeThumbColor: const Color(0xFF22C55E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4), dense: true,
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded),
            label: Text(_isEdit ? 'Update Medication' : 'Create Medication'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(fontSize: 13),
    prefixIcon: Icon(icon, size: 20), isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.cs.outlineVariant.withValues(alpha: 0.5))),
  );
}
