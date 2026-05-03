import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../models/medication_model.dart';
import '../repositories/medication_repository.dart';

class MedicationCatalogScreen extends ConsumerStatefulWidget {
  const MedicationCatalogScreen({super.key});

  @override
  ConsumerState<MedicationCatalogScreen> createState() =>
      _MedicationCatalogScreenState();
}

class _MedicationCatalogScreenState
    extends ConsumerState<MedicationCatalogScreen> {
  final _repo = MedicationRepository();
  final _searchCtrl = TextEditingController();

  PaginatedResponse<Medication>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String? _categoryFilter;
  String? _formFilter;

  // Medication categories from backend
  static const _categories = [
    ('analgesic', 'Analgesic'),
    ('antibiotic', 'Antibiotic'),
    ('antifungal', 'Antifungal'),
    ('antiviral', 'Antiviral'),
    ('antimalarial', 'Antimalarial'),
    ('antihypertensive', 'Antihypertensive'),
    ('antidiabetic', 'Antidiabetic'),
    ('antihistamine', 'Antihistamine'),
    ('antacid', 'Antacid / GI'),
    ('cardiovascular', 'Cardiovascular'),
    ('respiratory', 'Respiratory'),
    ('cns', 'CNS'),
    ('vitamin', 'Vitamin / Supplement'),
    ('vaccine', 'Vaccine'),
    ('nsaid', 'NSAID'),
    ('other', 'Other'),
  ];

  static const _dosageForms = [
    ('tablet', 'Tablet'),
    ('capsule', 'Capsule'),
    ('syrup', 'Syrup'),
    ('injection', 'Injection'),
    ('cream', 'Cream'),
    ('ointment', 'Ointment'),
    ('drops', 'Drops'),
    ('inhaler', 'Inhaler'),
    ('suspension', 'Suspension'),
    ('solution', 'Solution'),
    ('powder', 'Powder'),
    ('spray', 'Spray'),
    ('gel', 'Gel'),
    ('patch', 'Patch'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getMedications(
        page: _page,
        search: _search.isEmpty ? null : _search,
        category: _categoryFilter,
        dosageForm: _formFilter,
      );
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearch(String v) {
    setState(() {
      _search = v;
      _page = 1;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Medication Catalog',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showMedicationForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Medication'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search + filters row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, brand...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: _onSearch,
                  onChanged: (v) {
                    if (v.isEmpty) _onSearch('');
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: _categoryFilter,
                hint: const Text('Category'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('All Categories')),
                  ..._categories.map((c) => DropdownMenuItem<String?>(
                        value: c.$1,
                        child: Text(c.$2),
                      )),
                ],
                onChanged: (v) {
                  setState(() {
                    _categoryFilter = v;
                    _page = 1;
                  });
                  _loadData();
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: _formFilter,
                hint: const Text('Form'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('All Forms')),
                  ..._dosageForms.map((f) => DropdownMenuItem<String?>(
                        value: f.$1,
                        child: Text(f.$2),
                      )),
                ],
                onChanged: (v) {
                  setState(() {
                    _formFilter = v;
                    _page = 1;
                  });
                  _loadData();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Results count
          if (_data != null && !_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_data!.count} medication${_data!.count == 1 ? '' : 's'} found',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: LoadingWidget())
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.medication_outlined,
                            title: 'No Medications Found',
                            subtitle: 'Try adjusting your search or filters.',
                          )
                        : _buildGrid(),
          ),

          // Pagination
          if (_data != null && (_data!.previous != null || _data!.next != null))
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 1200
          ? 4
          : constraints.maxWidth > 800
              ? 3
              : constraints.maxWidth > 500
                  ? 2
                  : 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
        ),
        itemCount: _data!.results.length,
        itemBuilder: (context, i) =>
            _MedicationCard(medication: _data!.results[i], onTap: () {
          _showMedicationDetail(context, _data!.results[i]);
        }),
      );
    });
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _data!.previous != null
                ? () {
                    setState(() => _page--);
                    _loadData();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page $_page',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          IconButton(
            onPressed: _data!.next != null
                ? () {
                    setState(() => _page++);
                    _loadData();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _showMedicationDetail(BuildContext context, Medication med) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(med.genericName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 4),
                if (med.brandNames.isNotEmpty)
                  Text(
                    'Also known as: ${med.brandNames.join(', ')}',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                const SizedBox(height: 16),
                _DetailRow('Category',
                    med.category.replaceAll('_', ' ').toUpperCase()),
                _DetailRow('Dosage Form',
                    med.dosageForm.replaceAll('_', ' ')),
                if (med.strength?.isNotEmpty == true)
                  _DetailRow('Strength', med.strength!),
                _DetailRow('Requires Rx',
                    med.requiresPrescription ? 'Yes' : 'No'),
                if (med.controlledSubstanceClass?.isNotEmpty == true)
                  _DetailRow('Controlled Class',
                      med.controlledSubstanceClass!),
                if (med.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  const Text('Description',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(med.description!,
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
                if (med.sideEffects?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text('Side Effects',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(med.sideEffects!,
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
                if (med.contraindications?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text('Contraindications',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(med.contraindications!,
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMedicationForm(BuildContext context, [Medication? existing]) {
    showDialog(
      context: context,
      builder: (ctx) => _MedicationFormDialog(
        existing: existing,
        repo: _repo,
        onSaved: () {
          Navigator.of(ctx).pop();
          _loadData();
        },
      ),
    );
  }
}

// ─── Medication Card ─────────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onTap;
  const _MedicationCard({required this.medication, required this.onTap});

  Color _catColor(String cat) {
    const map = {
      'antibiotic': Color(0xFF22C55E),
      'analgesic': Color(0xFFF59E0B),
      'antihypertensive': Color(0xFF3B82F6),
      'antidiabetic': Color(0xFF8B5CF6),
      'antimalarial': Color(0xFF0D9488),
      'vitamin': Color(0xFF10B981),
      'vaccine': Color(0xFF6366F1),
      'nsaid': Color(0xFFEF4444),
    };
    return map[cat] ?? AppColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _catColor(medication.category);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    medication.category.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
                const Spacer(),
                if (medication.requiresPrescription)
                  Tooltip(
                    message: 'Requires Prescription',
                    child: Icon(Icons.local_pharmacy_outlined,
                        size: 16, color: AppColors.warning),
                  ),
              ]),
              const SizedBox(height: 10),
              Text(
                medication.genericName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  medication.dosageForm.replaceAll('_', ' '),
                  if (medication.strength?.isNotEmpty == true)
                    medication.strength!,
                ].join(' · '),
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              if (medication.brandNames.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  medication.brandNames.take(2).join(', '),
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Detail Row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text('$label:',
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
}

// ─── Medication Form Dialog ───────────────────────────────────────────────────

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
  bool _requiresPrescription = true;
  bool _saving = false;
  String? _error;

  static const _categories = [
    ('analgesic', 'Analgesic / Pain Reliever'),
    ('antibiotic', 'Antibiotic'),
    ('antifungal', 'Antifungal'),
    ('antiviral', 'Antiviral'),
    ('antimalarial', 'Antimalarial'),
    ('antihypertensive', 'Antihypertensive'),
    ('antidiabetic', 'Antidiabetic'),
    ('antihistamine', 'Antihistamine'),
    ('antacid', 'Antacid / GI'),
    ('cardiovascular', 'Cardiovascular'),
    ('respiratory', 'Respiratory'),
    ('cns', 'Central Nervous System'),
    ('vitamin', 'Vitamin / Supplement'),
    ('vaccine', 'Vaccine'),
    ('nsaid', 'NSAID'),
    ('other', 'Other'),
  ];

  static const _forms = [
    ('tablet', 'Tablet'),
    ('capsule', 'Capsule'),
    ('syrup', 'Syrup'),
    ('injection', 'Injection'),
    ('cream', 'Cream'),
    ('ointment', 'Ointment'),
    ('drops', 'Drops'),
    ('inhaler', 'Inhaler'),
    ('suspension', 'Suspension'),
    ('solution', 'Solution'),
    ('powder', 'Powder'),
    ('spray', 'Spray'),
    ('gel', 'Gel'),
    ('patch', 'Patch'),
    ('other', 'Other'),
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
      _requiresPrescription = m.requiresPrescription;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _strengthCtrl.dispose();
    _descCtrl.dispose();
    _sideEffectsCtrl.dispose();
    _contraindicationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = {
        'generic_name': _nameCtrl.text.trim(),
        'strength': _strengthCtrl.text.trim(),
        'category': _category,
        'dosage_form': _form,
        'requires_prescription': _requiresPrescription,
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
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null
                      ? 'Add Medication'
                      : 'Edit Medication',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Generic Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder()),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c.$1, child: Text(c.$2)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _form,
                      decoration: const InputDecoration(
                          labelText: 'Dosage Form *',
                          border: OutlineInputBorder()),
                      items: _forms
                          .map((f) => DropdownMenuItem(
                              value: f.$1, child: Text(f.$2)))
                          .toList(),
                      onChanged: (v) => setState(() => _form = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _strengthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Strength (e.g. 500mg, 250mg/5ml)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Requires Prescription'),
                  value: _requiresPrescription,
                  onChanged: (v) =>
                      setState(() => _requiresPrescription = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sideEffectsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Side Effects',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contraindicationsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Contraindications',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
