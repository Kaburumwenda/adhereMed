import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import 'document_viewer.dart';
import 'hc_common.dart';

// ── Provider ──
final _pcDocsProvider =
    FutureProvider.autoDispose.family<List, int>((ref, id) async {
  return hcFetchAll(ref, '/homecare/patient-documents/',
      params: {'patient': id, 'page_size': 500});
});

// ── Catalogs (mirror web docCategories / docAccessLevels) ──
class _DocCategory {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _DocCategory(this.value, this.label, this.icon, this.color);
}

const _docCategories = [
  _DocCategory('insurance_card', 'Insurance Cards',
      Icons.card_membership_rounded, hcTeal),
  _DocCategory('id_document', 'ID Documents', Icons.badge_rounded, hcAmber),
  _DocCategory('lab_report', 'Lab Reports', Icons.science_rounded, hcBlue),
  _DocCategory('imaging', 'Imaging / Radiology', Icons.image_rounded, hcPurple),
  _DocCategory(
      'clinical_note', 'Clinical Notes', Icons.note_alt_rounded, hcIndigo),
  _DocCategory(
      'prescription', 'Prescriptions', Icons.medication_rounded, hcRose),
  _DocCategory('consent', 'Consents', Icons.handshake_rounded, hcGreen),
  _DocCategory('care_plan', 'Care Plans', Icons.article_rounded, Color(0xFF0891B2)),
  _DocCategory('other', 'Other', Icons.folder_rounded, hcSlate),
];

class _DocAccess {
  final String value;
  final String label;
  final Color color;
  const _DocAccess(this.value, this.label, this.color);
}

const _docAccessLevels = [
  _DocAccess('care_team', 'Care Team', hcGreen),
  _DocAccess('doctor_only', 'Doctor Only', hcAmber),
  _DocAccess('nurse_only', 'Nurse Only', hcBlue),
  _DocAccess('restricted', 'Restricted', hcRed),
];

_DocCategory _catOf(String? v) =>
    _docCategories.firstWhere((c) => c.value == v,
        orElse: () => _docCategories.last);
_DocAccess? _accessOf(String? v) {
  if (v == null) return null;
  for (final a in _docAccessLevels) {
    if (a.value == v) return a;
  }
  return null;
}

String _formatSize(dynamic bytes) {
  final b = int.tryParse('${bytes ?? 0}') ?? 0;
  if (b <= 0) return '—';
  if (b < 1024) return '$b B';
  if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1048576).toStringAsFixed(1)} MB';
}

int _daysUntil(String? d) {
  if (d == null || d.isEmpty) return 1 << 30;
  final dt = DateTime.tryParse(d);
  if (dt == null) return 1 << 30;
  return dt.difference(DateTime.now()).inDays;
}

String _extOf(Map d) {
  final ft = d['file_type']?.toString() ?? '';
  if (ft.isNotEmpty) return ft.toLowerCase();
  final url = (d['file_url'] ?? d['file'] ?? '').toString();
  final dot = url.lastIndexOf('.');
  return dot >= 0 ? url.substring(dot + 1).toLowerCase() : '';
}

/// Patient documents tab — list, view, and upload documents for a homecare
/// patient. Mirrors the web "/homecare/patient-care/:id" Documents tab.
class HomecareDocsTab extends ConsumerStatefulWidget {
  final int patientId;
  const HomecareDocsTab({super.key, required this.patientId});

  @override
  ConsumerState<HomecareDocsTab> createState() => _HomecareDocsTabState();
}

class _HomecareDocsTabState extends ConsumerState<HomecareDocsTab> {
  String _search = '';
  String _categoryFilter = ''; // '' = all
  String? _accessFilter;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map> _applyFilters(List<Map> rows) {
    final q = _search.toLowerCase();
    rows.sort((a, b) =>
        (b['uploaded_at']?.toString() ?? '').compareTo(a['uploaded_at'] ?? ''));
    return rows.where((d) {
      if (_categoryFilter.isNotEmpty && d['category'] != _categoryFilter) {
        return false;
      }
      if (_accessFilter != null && d['access_level'] != _accessFilter) {
        return false;
      }
      if (q.isNotEmpty &&
          !'${d['name'] ?? ''} ${d['description'] ?? ''}'
              .toLowerCase()
              .contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(_pcDocsProvider(widget.patientId));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'pd-doc-${widget.patientId}',
        backgroundColor: hcTeal,
        foregroundColor: Colors.white,
        onPressed: () => _openUpload(context, ref),
        icon: const Icon(Icons.upload_file_rounded, size: 20),
        label: const Text('Upload'),
      ),
      body: HcAsyncBody(
        value: docs,
        onRefresh: () async =>
            ref.refresh(_pcDocsProvider(widget.patientId).future),
        builder: (list) {
          final all = list.cast<Map>();
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(
                child: _buildKpis(context, all),
              ),
              SliverToBoxAdapter(
                child: _buildCategoryChips(context, all),
              ),
              SliverToBoxAdapter(child: _buildFilters(context, all)),
              if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmpty(context),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final filtered = _applyFilters(all);
                        if (i >= filtered.length) return null;
                        return _DocCard(
                          doc: filtered[i],
                          onView: () => _openViewer(ctx, filtered[i]),
                          onDownload: () => _download(ctx, filtered[i]),
                          onDetails: () => _openDetails(ctx, filtered[i]),
                          onEdit: () => _openEdit(ctx, ref, filtered[i]),
                          onDelete: () => _confirmDelete(ctx, ref, filtered[i]),
                        );
                      },
                      childCount: _applyFilters(all).length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hcTeal.withValues(alpha: 0.10), hcBlue.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hcTeal.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.file_copy_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Document Management',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                'Insurance cards, lab reports, imaging, prescriptions, consents & more',
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── KPI row ──
  Widget _buildKpis(BuildContext context, List<Map> all) {
    final restricted = all
        .where((d) =>
            d['access_level'] == 'restricted' ||
            d['access_level'] == 'doctor_only')
        .length;
    final expiring = all
        .where((d) =>
            d['expiry_date'] != null &&
            _daysUntil(d['expiry_date'].toString()) >= 0 &&
            _daysUntil(d['expiry_date'].toString()) <= 30)
        .length;
    final storageBytes =
        all.fold<int>(0, (s, d) => s + (int.tryParse('${d['file_size']}') ?? 0));
    final storageMb = (storageBytes / 1048576).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(child: _kpiTile(context, '${all.length}', 'Total', hcTeal,
              Icons.file_copy_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _kpiTile(context, '$restricted', 'Restricted', hcRed,
              Icons.shield_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _kpiTile(context, '$expiring', 'Expiring', hcAmber,
              Icons.schedule_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _kpiTile(
              context, storageMb, 'Storage (MB)', hcPurple, Icons.storage_rounded)),
        ],
      ),
    );
  }

  Widget _kpiTile(BuildContext context, String value, String label, Color color,
      IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ── Category chips ──
  Widget _buildCategoryChips(BuildContext context, List<Map> all) {
    int countFor(String cat) => all.where((d) => d['category'] == cat).length;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _catChip(context, '', 'All', Icons.file_copy_rounded, hcTeal,
              all.length),
          const SizedBox(width: 8),
          for (final c in _docCategories) ...[
            _catChip(context, c.value, c.label, c.icon, c.color, countFor(c.value)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _catChip(BuildContext context, String value, String label,
      IconData icon, Color color, int count) {
    final selected = _categoryFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _categoryFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? color : Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filters row ──
  Widget _buildFilters(BuildContext context, List<Map> all) {
    final filtered = _applyFilters(all);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search documents…',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String?>(
            value: _accessFilter,
            hint: const Text('Access', style: TextStyle(fontSize: 12)),
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All access')),
              for (final a in _docAccessLevels)
                DropdownMenuItem<String?>(
                    value: a.value, child: Text(a.label)),
            ],
            onChanged: (v) => setState(() => _accessFilter = v),
          ),
          const SizedBox(width: 8),
          Text('${filtered.length}/${all.length}',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No documents uploaded.',
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap Upload to add one.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ── Actions ──
  void _download(BuildContext context, Map d) {
    final url = (d['file_url'] ?? d['file'] ?? '').toString();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('File not available.')));
      return;
    }
    var u = url;
    if (u.startsWith('/')) u = kApiBase.replaceAll('/api', '') + u;
    launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  }

  void _openViewer(BuildContext context, Map d) {
    final url = (d['file_url'] ?? d['file'] ?? '').toString();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('File not available.')));
      return;
    }
    var u = url;
    if (u.startsWith('/')) u = kApiBase.replaceAll('/api', '') + u;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HomecareDocumentViewer(
        url: u,
        name: d['name']?.toString() ?? 'Document',
        fileType: d['file_type']?.toString(),
        fileSize: d['file_size'] is int
            ? d['file_size'] as int
            : int.tryParse('${d['file_size']}'),
      ),
    ));
  }

  void _openDetails(BuildContext context, Map d) {
    showDialog(
      context: context,
      builder: (ctx) => _DocDetailDialog(
        doc: d,
        onView: () {
          Navigator.pop(ctx);
          _openViewer(context, d);
        },
        onEdit: () {
          Navigator.pop(ctx);
          _openEdit(context, ref, d);
        },
        onDownload: () => _download(context, d),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Map d) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(
        name: d['name']?.toString() ?? 'this document',
        onConfirm: () async {
          Navigator.pop(ctx);
          try {
            await ref.read(dioProvider)
                .delete('/homecare/patient-documents/${d['id']}/');
            ref.invalidate(_pcDocsProvider(widget.patientId));
            if (mounted) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Document deleted.')));
            }
          } catch (_) {
            if (mounted) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Failed to delete.')));
            }
          }
        },
      ),
    );
  }

  // ── Upload sheet ──
  void _openUpload(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    _DocFormSheet.show(
        context: context,
        ref: ref,
        patientId: widget.patientId,
        title: 'Upload document',
        onSubmit: (form, picked, isImage) async {
          if (picked == null) throw Exception('No file selected');
          final dio = ref.read(dioProvider);
          final data = <String, dynamic>{
            'name': form.name,
            'category': form.category,
            'access_level': form.accessLevel,
            'patient': widget.patientId,
            if (form.expiryDate != null) 'expiry_date': form.expiryDate,
            if (form.description != null) 'description': form.description,
          };
          data['file'] = await MultipartFile.fromFile(picked.path,
              filename: picked.name);
          await dio.post('/homecare/patient-documents/',
              data: FormData.fromMap(data));
          ref.invalidate(_pcDocsProvider(widget.patientId));
        },
      ).then((ok) {
        if (ok == true && mounted) {
          messenger
              .showSnackBar(const SnackBar(content: Text('Document uploaded.')));
        }
      });
  }

  // ── Edit sheet ──
  void _openEdit(BuildContext context, WidgetRef ref, Map d) {
    final messenger = ScaffoldMessenger.of(context);
    _DocFormSheet.show(
      context: context,
      ref: ref,
      patientId: widget.patientId,
      title: 'Edit document',
      initial: _DocForm(
        name: d['name']?.toString() ?? '',
        category: d['category']?.toString() ?? 'other',
        accessLevel: d['access_level']?.toString() ?? 'care_team',
        expiryDate: d['expiry_date']?.toString(),
        description: d['description']?.toString(),
      ),
      currentFileType: d['file_type']?.toString(),
      currentFileSize: d['file_size'],
      onSubmit: (form, picked, isImage) async {
        final dio = ref.read(dioProvider);
        final data = <String, dynamic>{
          'name': form.name,
          'category': form.category,
          'access_level': form.accessLevel,
          if (form.expiryDate != null) 'expiry_date': form.expiryDate,
          if (form.description != null) 'description': form.description,
        };
        if (picked != null) {
          data['file'] = await MultipartFile.fromFile(picked.path,
              filename: picked.name);
        }
        await dio.patch('/homecare/patient-documents/${d['id']}/',
            data: FormData.fromMap(data));
        ref.invalidate(_pcDocsProvider(widget.patientId));
      },
    ).then((ok) {
      if (ok == true && mounted) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Document updated.')));
      }
    });
  }
}

// ═════════════════════════════════════════════════════════════════
//  Document card
// ═════════════════════════════════════════════════════════════════
class _DocCard extends StatelessWidget {
  final Map doc;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DocCard({
    required this.doc,
    required this.onView,
    required this.onDownload,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = doc['name']?.toString() ?? '—';
    final cat = _catOf(doc['category']?.toString());
    final access = _accessOf(doc['access_level']?.toString());
    final ext = _extOf(doc).toUpperCase();
    final size = _formatSize(doc['file_size']);
    final expiry = doc['expiry_date']?.toString();
    final days = _daysUntil(expiry);
    final expired = expiry != null && days < 0;
    final expiringSoon = expiry != null && days >= 0 && days <= 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, color: cat.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text('$ext · $size',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        HcStatusChip(label: cat.label, color: cat.color),
                        if (access != null)
                          HcStatusChip(
                              label: access.label,
                              color: access.color,
                              icon: Icons.shield_rounded),
                        if (expired)
                          HcStatusChip(
                              label: 'Expired',
                              color: hcRed,
                              icon: Icons.error_outline_rounded)
                        else if (expiringSoon)
                          HcStatusChip(
                              label: 'Expires in ${days}d',
                              color: hcAmber,
                              icon: Icons.schedule_rounded),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('Uploaded ${hcDate(doc['uploaded_at'])}',
                            style: TextStyle(
                                fontSize: 10.5, color: cs.onSurfaceVariant)),
                        if (expiry != null && !expired) ...[
                          const Text(' · ',
                              style: TextStyle(fontSize: 10.5)),
                          Text('Expires ${hcDate(expiry)}',
                              style: TextStyle(
                                  fontSize: 10.5, color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'view', child: ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('View'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
                  const PopupMenuItem(value: 'download', child: ListTile(
                    leading: Icon(Icons.download_rounded),
                    title: Text('Download'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
                  const PopupMenuItem(value: 'details', child: ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('Details'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
                  const PopupMenuItem(value: 'edit', child: ListTile(
                    leading: Icon(Icons.edit_rounded),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: hcRed),
                    title: Text('Delete', style: TextStyle(color: hcRed)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'view':
                      onView();
                      break;
                    case 'download':
                      onDownload();
                      break;
                    case 'details':
                      onDetails();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Document detail dialog
// ═════════════════════════════════════════════════════════════════
class _DocDetailDialog extends StatelessWidget {
  final Map doc;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  const _DocDetailDialog({
    required this.doc,
    required this.onView,
    required this.onEdit,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cat = _catOf(doc['category']?.toString());
    final access = _accessOf(doc['access_level']?.toString());
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.file_copy_rounded, color: hcTeal, size: 22),
        const SizedBox(width: 8),
        const Text('Document Details',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(context, 'Name', doc['name']?.toString()),
            _row(context, 'Category', cat.label),
            _row(context, 'Access', access?.label ?? '—'),
            _row(context, 'Size', _formatSize(doc['file_size'])),
            _row(context, 'Uploaded', hcDate(doc['uploaded_at'])),
            _row(context, 'Expires',
                doc['expiry_date'] != null ? hcDate(doc['expiry_date']) : '—'),
            if ((doc['description'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(doc['description'].toString(),
                        style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit'),
        ),
        TextButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Download'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: hcTeal),
          onPressed: onView,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View'),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String? value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text((value == null || value.isEmpty) ? '—' : value,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Delete confirm dialog
// ═════════════════════════════════════════════════════════════════
class _DeleteConfirmDialog extends StatefulWidget {
  final String name;
  final Future<void> Function() onConfirm;
  const _DeleteConfirmDialog({required this.name, required this.onConfirm});

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete document?'),
      content: Text.rich(TextSpan(children: [
        const TextSpan(text: 'This permanently removes '),
        TextSpan(text: widget.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        const TextSpan(text: '.'),
      ])),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: hcRed),
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.onConfirm();
                  if (mounted) setState(() => _saving = false);
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Delete'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Upload / Edit form bottom sheet
// ═════════════════════════════════════════════════════════════════
class _DocForm {
  String name;
  String category;
  String accessLevel;
  String? expiryDate;
  String? description;
  _DocForm({
    required this.name,
    required this.category,
    required this.accessLevel,
    this.expiryDate,
    this.description,
  });
}

class _DocFormSheet extends StatefulWidget {
  final WidgetRef ref;
  final int patientId;
  final String title;
  final _DocForm? initial;
  final String? currentFileType;
  final dynamic currentFileSize;
  final Future<void> Function(
      _DocForm form, XFile? picked, bool isImage) onSubmit;
  const _DocFormSheet({
    required this.ref,
    required this.patientId,
    required this.title,
    this.initial,
    this.currentFileType,
    this.currentFileSize,
    required this.onSubmit,
  });

  static Future<bool?> show({
    required BuildContext context,
    required WidgetRef ref,
    required int patientId,
    required String title,
    _DocForm? initial,
    String? currentFileType,
    dynamic currentFileSize,
    required Future<void> Function(_DocForm, XFile?, bool) onSubmit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DocFormSheet(
        ref: ref,
        patientId: patientId,
        title: title,
        initial: initial,
        currentFileType: currentFileType,
        currentFileSize: currentFileSize,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<_DocFormSheet> createState() => _DocFormSheetState();
}

class _DocFormSheetState extends State<_DocFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  late String _accessLevel;
  String? _expiryDate;
  XFile? _picked;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameCtrl = TextEditingController(text: i?.name ?? '');
    _descCtrl = TextEditingController(text: i?.description ?? '');
    _category = i?.category ?? 'other';
    _accessLevel = i?.accessLevel ?? 'care_team';
    _expiryDate = i?.expiryDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      initialDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _expiryDate =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: hcTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.upload_file_rounded,
                    color: hcTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Text(widget.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Document name *',
                  prefixIcon: Icon(Icons.label_rounded)),
            ),
            const SizedBox(height: 12),
            Text('Category',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _docCategories)
                  ChoiceChip(
                    selected: _category == c.value,
                    avatar: Icon(c.icon, size: 14, color: c.color),
                    label: Text(c.label, style: const TextStyle(fontSize: 11.5)),
                    selectedColor: c.color.withValues(alpha: 0.18),
                    onSelected: (_) => setSheet(() => _category = c.value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accessLevel,
              decoration: const InputDecoration(
                labelText: 'Access level',
                prefixIcon: Icon(Icons.shield_rounded),
              ),
              items: [
                for (final a in _docAccessLevels)
                  DropdownMenuItem(value: a.value, child: Text(a.label)),
              ],
              onChanged: (v) => setSheet(() => _accessLevel = v ?? _accessLevel),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expiry date (optional)',
                  prefixIcon: Icon(Icons.event_rounded),
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
                child: Text(_expiryDate ?? ''),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.note_rounded),
              ),
            ),
            const SizedBox(height: 14),
            if (widget.initial != null &&
                widget.currentFileType != null &&
                _picked == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.attach_file_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                      'Current: ${widget.currentFileType} · ${_formatSize(widget.currentFileSize)}',
                      style:
                          TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                ]),
              ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final f = await ImagePicker().pickImage(
                        source: ImageSource.camera, imageQuality: 85);
                    if (f != null) setSheet(() => _picked = f);
                  },
                  icon: const Icon(Icons.photo_camera_rounded, size: 17),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final f = await ImagePicker().pickImage(
                        source: ImageSource.gallery, imageQuality: 85);
                    if (f != null) setSheet(() => _picked = f);
                  },
                  icon: const Icon(Icons.photo_library_rounded, size: 17),
                  label: const Text('Gallery'),
                ),
              ),
            ]),
            if (_picked != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: hcTeal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_picked!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: hcTeal)),
                  ),
                ]),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: hcTeal),
                onPressed: _saving
                    ? null
                    : () async {
                        if (_nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Document name is required.')));
                          return;
                        }
                        if (widget.initial == null && _picked == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Please select a file to upload.')));
                          return;
                        }
                        setSheet(() => _saving = true);
                        try {
                          final form = _DocForm(
                            name: _nameCtrl.text.trim(),
                            category: _category,
                            accessLevel: _accessLevel,
                            expiryDate: _expiryDate,
                            description: _descCtrl.text.trim().isEmpty
                                ? null
                                : _descCtrl.text.trim(),
                          );
                          await widget.onSubmit(form, _picked, true);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setSheet(() => _saving = false);
                          if (ctx.mounted) {
                            String msg = 'Failed to save.';
                            try {
                              final err = (e as dynamic).response?.data;
                              if (err is Map) {
                                msg = err['detail']?.toString() ??
                                    err.entries
                                        .map((en) =>
                                            '${en.key}: ${en.value is List ? (en.value as List).join(', ') : en.value}')
                                        .join('\n');
                              }
                            } catch (_) {}
                            ScaffoldMessenger.of(ctx)
                                .showSnackBar(SnackBar(content: Text(msg)));
                          }
                        }
                      },
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(widget.initial == null ? 'Upload' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
