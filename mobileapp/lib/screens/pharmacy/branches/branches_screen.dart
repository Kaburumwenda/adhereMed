import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';
import 'map_picker.dart';

// ─── Providers ──────────────────────────────────────
final _searchProvider = StateProvider<String>((ref) => '');
final _statusFilterProvider = StateProvider<String>((ref) => ''); // '', 'true', 'false'
final _viewModeProvider = StateProvider<String>((ref) => 'list'); // 'list' or 'map'

final _branchesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 200};
  final status = ref.watch(_statusFilterProvider);
  if (status.isNotEmpty) params['is_active'] = status;
  final res = await dio.get('/pharmacy-profile/branches/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final search = ref.watch(_searchProvider).toLowerCase();
  if (search.isEmpty) return items;
  return items.where((b) =>
    '${b['name'] ?? ''}'.toLowerCase().contains(search) ||
    '${b['address'] ?? ''}'.toLowerCase().contains(search) ||
    '${b['phone'] ?? ''}'.toLowerCase().contains(search) ||
    '${b['email'] ?? ''}'.toLowerCase().contains(search)
  ).toList();
});

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});
  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_branchesProvider);
    final cs = Theme.of(context).colorScheme;
    final statusFilter = ref.watch(_statusFilterProvider);
    final viewMode = ref.watch(_viewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branches'),
        actions: [
          // View mode toggle
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _ViewToggle(
                icon: Icons.list_rounded,
                selected: viewMode == 'list',
                onTap: () => ref.read(_viewModeProvider.notifier).state = 'list',
              ),
              _ViewToggle(
                icon: Icons.map_rounded,
                selected: viewMode == 'map',
                onTap: () => ref.read(_viewModeProvider.notifier).state = 'map',
              ),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_branchesProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBranchDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Branch'),
      ),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search branches...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _searchCtrl.clear(); ref.read(_searchProvider.notifier).state = ''; })
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
            ),
            onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
          ),
        ),

        // Status filter chips
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              _StatusChip(label: 'All', selected: statusFilter.isEmpty, onTap: () => ref.read(_statusFilterProvider.notifier).state = ''),
              const SizedBox(width: 6),
              _StatusChip(label: 'Active', selected: statusFilter == 'true', color: const Color(0xFF22C55E), onTap: () => ref.read(_statusFilterProvider.notifier).state = 'true'),
              const SizedBox(width: 6),
              _StatusChip(label: 'Inactive', selected: statusFilter == 'false', color: const Color(0xFFEF4444), onTap: () => ref.read(_statusFilterProvider.notifier).state = 'false'),
            ],
          ),
        ),

        // KPI row
        data.whenOrNull(data: (items) {
          final total = items.length;
          final active = items.where((b) => b['is_active'] == true).length;
          final main = items.where((b) => b['is_main'] == true).length;
          final inactive = total - active;
          return SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              children: [
                _MiniKPI(label: 'Total', value: '$total', color: const Color(0xFF6366F1), icon: Icons.store_rounded),
                _MiniKPI(label: 'Active', value: '$active', color: const Color(0xFF22C55E), icon: Icons.check_circle_rounded),
                _MiniKPI(label: 'Main', value: '$main', color: const Color(0xFF3B82F6), icon: Icons.star_rounded),
                _MiniKPI(label: 'Inactive', value: '$inactive', color: const Color(0xFFEF4444), icon: Icons.block_rounded),
              ],
            ),
          );
        }) ?? const SizedBox.shrink(),

        // Content: List or Map
        Expanded(child: viewMode == 'map'
            ? _BranchesMapView()
            : data.when(
                loading: () => const LoadingShimmer(),
                error: (e, _) => ErrorRetry(message: 'Failed to load branches', onRetry: () => ref.invalidate(_branchesProvider)),
                data: (items) {
                  if (items.isEmpty) return const EmptyState(icon: Icons.store_rounded, title: 'No branches found', subtitle: 'Create your first branch');
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(_branchesProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _BranchCard(branch: items[i], index: i)
                          .animate().fadeIn(delay: (30 * i).clamp(0, 300).ms, duration: 250.ms),
                    ),
                  );
                },
              ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// VIEW MODE TOGGLE BUTTON
// ════════════════════════════════════════════════════
class _ViewToggle extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ViewToggle({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 18, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// MAP VIEW — ALL BRANCHES
// ════════════════════════════════════════════════════
class _BranchesMapView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BranchesMapView> createState() => _BranchesMapViewState();
}

class _BranchesMapViewState extends ConsumerState<_BranchesMapView> {
  GoogleMapController? _mapCtrl;
  int? _selectedBranchId;

  static const _defaultCenter = LatLng(-1.2921, 36.8219); // Nairobi

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers(List items) {
    return items
        .where((b) => b['latitude'] != null && b['longitude'] != null)
        .map<Marker>((b) {
      final lat = double.tryParse('${b['latitude']}') ?? 0;
      final lng = double.tryParse('${b['longitude']}') ?? 0;
      final isMain = b['is_main'] == true;
      final isActive = b['is_active'] == true;
      return Marker(
        markerId: MarkerId('branch_${b['id']}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isMain ? BitmapDescriptor.hueBlue : (isActive ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange),
        ),
        infoWindow: InfoWindow(
          title: '${b['name'] ?? 'Branch'}${isMain ? ' ★ MAIN' : ''}',
          snippet: '${b['address'] ?? ''}${isActive ? '' : ' (Inactive)'}',
          onTap: () => _showBranchDetail(context, ref, b),
        ),
        onTap: () => setState(() => _selectedBranchId = b['id']),
      );
    }).toSet();
  }

  void _fitBounds(List items) {
    final geo = items.where((b) => b['latitude'] != null && b['longitude'] != null).toList();
    if (geo.isEmpty || _mapCtrl == null) return;
    if (geo.length == 1) {
      final lat = double.tryParse('${geo[0]['latitude']}') ?? 0;
      final lng = double.tryParse('${geo[0]['longitude']}') ?? 0;
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15));
      return;
    }
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final b in geo) {
      final lat = double.tryParse('${b['latitude']}') ?? 0;
      final lng = double.tryParse('${b['longitude']}') ?? 0;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      60,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_branchesProvider);
    final cs = Theme.of(context).colorScheme;

    return data.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load branches', onRetry: () => ref.invalidate(_branchesProvider)),
      data: (items) {
        final geo = items.where((b) => b['latitude'] != null && b['longitude'] != null).toList();
        if (geo.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.map_outlined, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No branches with coordinates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Add location to branches to see them on the map', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
          ]));
        }

        return Column(children: [
          // Map
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _defaultCenter, zoom: 6),
                onMapCreated: (c) {
                  _mapCtrl = c;
                  // Delay to let map render before fitting bounds
                  Future.delayed(const Duration(milliseconds: 400), () => _fitBounds(items));
                },
                markers: _buildMarkers(items),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),
            ),
          ),

          // Legend chips — scrollable branch list below map
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: geo.length,
              itemBuilder: (_, i) {
                final b = geo[i];
                final isMain = b['is_main'] == true;
                final isSelected = _selectedBranchId == b['id'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedBranchId = b['id']);
                    final lat = double.tryParse('${b['latitude']}') ?? 0;
                    final lng = double.tryParse('${b['longitude']}') ?? 0;
                    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isMain ? const Color(0xFF3B82F6) : const Color(0xFF6366F1))
                          : (isMain ? const Color(0xFF3B82F6).withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected
                          ? Colors.transparent
                          : (isMain ? const Color(0xFF3B82F6).withValues(alpha: 0.2) : cs.outlineVariant.withValues(alpha: 0.2))),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        isMain ? Icons.star_rounded : Icons.store_rounded,
                        size: 14,
                        color: isSelected ? Colors.white : (isMain ? const Color(0xFF3B82F6) : cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${b['name'] ?? ''}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : cs.onSurface),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════════
// BRANCH CARD
// ════════════════════════════════════════════════════
class _BranchCard extends ConsumerWidget {
  final Map<String, dynamic> branch;
  final int index;
  const _BranchCard({required this.branch, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final name = '${branch['name'] ?? ''}'.trim();
    final address = '${branch['address'] ?? ''}';
    final placeName = '${branch['place_name'] ?? ''}';
    final phone = '${branch['phone'] ?? ''}';
    final email = '${branch['email'] ?? ''}';
    final isMain = branch['is_main'] == true;
    final isActive = branch['is_active'] == true;
    final hasGeo = branch['latitude'] != null && branch['longitude'] != null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isMain ? const Color(0xFF3B82F6).withValues(alpha: 0.25) : cs.outlineVariant.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBranchDetail(context, ref, branch),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Row(children: [
              // Icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: isMain
                      ? [const Color(0xFF3B82F6).withValues(alpha: 0.2), const Color(0xFF3B82F6).withValues(alpha: 0.05)]
                      : [const Color(0xFF6366F1).withValues(alpha: 0.12), const Color(0xFF6366F1).withValues(alpha: 0.03)]),
                ),
                child: Icon(
                  isMain ? Icons.star_rounded : Icons.store_rounded,
                  size: 22,
                  color: isMain ? const Color(0xFF3B82F6) : const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),

              // Name + badges
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name.isNotEmpty ? name : 'Branch #${branch['id']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (isMain) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('MAIN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                    ),
                  ],
                ]),
                if (placeName.isNotEmpty)
                  Text(placeName, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),

              // Status + Menu
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isActive ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 12, color: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                    const SizedBox(width: 3),
                    Text(isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
                  ]),
                ),
              ]),
            ]),

            // Details
            if (address.isNotEmpty || phone.isNotEmpty || email.isNotEmpty || hasGeo) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (address.isNotEmpty) _InfoChip(Icons.location_on_rounded, address, const Color(0xFF6366F1)),
                if (phone.isNotEmpty) _InfoChip(Icons.phone_rounded, phone, const Color(0xFF22C55E)),
                if (email.isNotEmpty) _InfoChip(Icons.email_rounded, email, const Color(0xFF3B82F6)),
                if (hasGeo) _InfoChip(Icons.my_location_rounded, '${branch['latitude']}, ${branch['longitude']}', const Color(0xFF14B8A6)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// BRANCH DETAIL BOTTOM SHEET
// ════════════════════════════════════════════════════
void _showBranchDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> b) {
  final cs = Theme.of(context).colorScheme;
  final name = '${b['name'] ?? ''}'.trim();
  final isMain = b['is_main'] == true;
  final isActive = b['is_active'] == true;
  final hasGeo = b['latitude'] != null && b['longitude'] != null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) => ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMain ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : const Color(0xFF6366F1).withValues(alpha: 0.1),
            ),
            child: Icon(isMain ? Icons.star_rounded : Icons.store_rounded, size: 24, color: isMain ? const Color(0xFF3B82F6) : const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              if (isMain) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]), borderRadius: BorderRadius.circular(5)),
                  child: const Text('MAIN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: isActive ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
              ),
            ]),
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              Navigator.pop(ctx);
              switch (v) {
                case 'edit': _showBranchDialog(context, ref, branch: b);
                case 'main': _setMain(context, ref, b);
                case 'toggle': _toggleActive(context, ref, b);
                case 'delete': _confirmDelete(context, ref, b);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')])),
              if (!isMain) const PopupMenuItem(value: 'main', child: Row(children: [Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)), SizedBox(width: 8), Text('Set as Main')])),
              PopupMenuItem(value: 'toggle', child: Row(children: [
                Icon(isActive ? Icons.block_rounded : Icons.check_circle_rounded, size: 18),
                const SizedBox(width: 8),
                Text(isActive ? 'Deactivate' : 'Activate'),
              ])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))])),
            ],
          ),
        ]),

        const SizedBox(height: 20),

        // Detail rows
        _DetailRow(Icons.location_on_rounded, 'Address', '${b['address'] ?? '—'}'),
        _DetailRow(Icons.place_rounded, 'Place', '${b['place_name'] ?? '—'}'),
        _DetailRow(Icons.phone_rounded, 'Phone', '${b['phone'] ?? '—'}'),
        _DetailRow(Icons.email_rounded, 'Email', '${b['email'] ?? '—'}'),
        if (hasGeo) _DetailRow(Icons.my_location_rounded, 'Coordinates', '${b['latitude']}, ${b['longitude']}'),
        _DetailRow(Icons.calendar_today_rounded, 'Created', _formatDate(b['created_at'])),
        _DetailRow(Icons.update_rounded, 'Updated', _formatDate(b['updated_at'])),

        // Action buttons
        const SizedBox(height: 20),
        Row(children: [
          if ('${b['phone'] ?? ''}'.isNotEmpty)
            Expanded(child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${b['phone']}')),
              icon: const Icon(Icons.phone_rounded, size: 16),
              label: const Text('Call'),
            )),
          if ('${b['phone'] ?? ''}'.isNotEmpty && '${b['email'] ?? ''}'.isNotEmpty) const SizedBox(width: 8),
          if ('${b['email'] ?? ''}'.isNotEmpty)
            Expanded(child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('mailto:${b['email']}')),
              icon: const Icon(Icons.email_rounded, size: 16),
              label: const Text('Email'),
            )),
        ]),
        if (hasGeo) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${b['latitude']},${b['longitude']}')),
            icon: const Icon(Icons.map_rounded, size: 16),
            label: const Text('Open in Maps'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
          ),
        ],
      ]),
    ),
  );
}

String _formatDate(dynamic d) {
  if (d == null) return '—';
  try {
    final dt = DateTime.parse('$d');
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '$d';
  }
}

// ════════════════════════════════════════════════════
// CREATE / EDIT BRANCH DIALOG
// ════════════════════════════════════════════════════
void _showBranchDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? branch}) {
  final isEdit = branch != null;
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController(text: isEdit ? '${branch['name'] ?? ''}' : '');
  final addressCtrl = TextEditingController(text: isEdit ? '${branch['address'] ?? ''}' : '');
  final placeCtrl = TextEditingController(text: isEdit ? '${branch['place_name'] ?? ''}' : '');
  final phoneCtrl = TextEditingController(text: isEdit ? '${branch['phone'] ?? ''}' : '');
  final emailCtrl = TextEditingController(text: isEdit ? '${branch['email'] ?? ''}' : '');
  final latCtrl = TextEditingController(text: isEdit && branch['latitude'] != null ? '${branch['latitude']}' : '');
  final lngCtrl = TextEditingController(text: isEdit && branch['longitude'] != null ? '${branch['longitude']}' : '');

  bool isMain = isEdit ? (branch['is_main'] == true) : false;
  bool isActive = isEdit ? (branch['is_active'] == true) : true;
  bool saving = false;
  bool gpsLoading = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(builder: (ctx, setState) {
      final cs = Theme.of(ctx).colorScheme;

      // Open full-screen map picker
      void openMapPicker() async {
        final result = await Navigator.push<PickedLocation>(
          ctx,
          MaterialPageRoute(builder: (_) => MapPickerPage(
            initialLat: latCtrl.text.isNotEmpty ? double.tryParse(latCtrl.text) : null,
            initialLng: lngCtrl.text.isNotEmpty ? double.tryParse(lngCtrl.text) : null,
          )),
        );
        if (result != null) {
          setState(() {
            latCtrl.text = result.latitude.toStringAsFixed(6);
            lngCtrl.text = result.longitude.toStringAsFixed(6);
            if (result.address.isNotEmpty) addressCtrl.text = result.address;
            if (result.placeName.isNotEmpty) placeCtrl.text = result.placeName;
          });
        }
      }

      // Use GPS for current location
      void useGps() async {
        setState(() => gpsLoading = true);
        try {
          LocationPermission perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
          if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Location permission denied'), behavior: SnackBarBehavior.floating));
            setState(() => gpsLoading = false);
            return;
          }
          final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
          setState(() {
            latCtrl.text = pos.latitude.toStringAsFixed(6);
            lngCtrl.text = pos.longitude.toStringAsFixed(6);
            gpsLoading = false;
          });
          // Reverse geocode to fill address
          try {
            final dio = Dio();
            final res = await dio.get(
              'https://maps.googleapis.com/maps/api/geocode/json',
              queryParameters: {'latlng': '${pos.latitude},${pos.longitude}', 'key': 'AIzaSyAhiNO62geg58-WaLGeq235Lo8gySLvs_I'},
            );
            final results = (res.data['results'] as List?) ?? [];
            if (results.isNotEmpty && ctx.mounted) {
              final first = results[0];
              setState(() {
                addressCtrl.text = first['formatted_address'] ?? '';
              });
              final components = (first['address_components'] as List?) ?? [];
              for (final comp in components) {
                final types = (comp['types'] as List?) ?? [];
                if (types.any((t) => ['locality', 'sublocality', 'neighborhood'].contains(t))) {
                  setState(() => placeCtrl.text = comp['long_name'] ?? '');
                  break;
                }
              }
            }
            dio.close();
          } catch (_) {}
        } catch (e) {
          setState(() => gpsLoading = false);
          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('GPS error: $e'), behavior: SnackBarBehavior.floating));
        }
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Form(
          key: formKey,
          child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(children: [
              Icon(isEdit ? Icons.edit_rounded : Icons.add_business_rounded, size: 22, color: cs.primary),
              const SizedBox(width: 10),
              Text(isEdit ? 'Edit Branch' : 'New Branch', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 20),

            // Name
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Branch Name *', isDense: true, prefixIcon: Icon(Icons.store_rounded, size: 18)),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Address with Places autocomplete + map picker + GPS
            PlacesAutocompleteField(
              controller: addressCtrl,
              onPicked: (loc) {
                setState(() {
                  latCtrl.text = loc.latitude.toStringAsFixed(6);
                  lngCtrl.text = loc.longitude.toStringAsFixed(6);
                  addressCtrl.text = loc.address;
                  if (loc.placeName.isNotEmpty) placeCtrl.text = loc.placeName;
                });
              },
              onPickOnMap: openMapPicker,
              onUseGps: useGps,
            ),
            const SizedBox(height: 14),

            // Place name
            TextFormField(
              controller: placeCtrl,
              decoration: const InputDecoration(labelText: 'Place / City Name', isDense: true, prefixIcon: Icon(Icons.place_rounded, size: 18)),
            ),
            const SizedBox(height: 14),

            // Phone + Email
            Row(children: [
              Expanded(child: TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone', isDense: true, prefixIcon: Icon(Icons.phone_rounded, size: 18)),
                keyboardType: TextInputType.phone,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email', isDense: true, prefixIcon: Icon(Icons.email_rounded, size: 18)),
                keyboardType: TextInputType.emailAddress,
              )),
            ]),
            const SizedBox(height: 14),

            // Coordinates display (auto-filled by places/map/gps)
            Row(children: [
              Icon(Icons.my_location_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Coordinates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              if (gpsLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextFormField(
                controller: latCtrl,
                decoration: const InputDecoration(labelText: 'Latitude', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: lngCtrl,
                decoration: const InputDecoration(labelText: 'Longitude', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              )),
            ]),
            if (latCtrl.text.isNotEmpty && lngCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Text('Location set: ${latCtrl.text}, ${lngCtrl.text}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF22C55E))),
                ]),
              ),
            ],
            const SizedBox(height: 16),

            // Toggles
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                SwitchListTile(
                  title: Row(children: [
                    const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    const Text('Main Branch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
                  subtitle: const Text('Set as headquarters', style: TextStyle(fontSize: 11)),
                  value: isMain,
                  onChanged: (v) => setState(() => isMain = v),
                  dense: true,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.15)),
                SwitchListTile(
                  title: Row(children: [
                    Icon(Icons.power_settings_new_rounded, size: 18, color: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    const Text('Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
                  subtitle: const Text('Branch is operational', style: TextStyle(fontSize: 11)),
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v),
                  dense: true,
                ),
              ]),
            ),

            if (isMain)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_rounded, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Setting this as main will unset any other main branch.', style: TextStyle(fontSize: 11, color: cs.onSurface))),
                  ]),
                ),
              ),

            const SizedBox(height: 24),

            // Submit
            FilledButton.icon(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setState(() => saving = true);
                try {
                  final dio = ref.read(dioProvider);
                  final body = <String, dynamic>{
                    'name': nameCtrl.text,
                    'address': addressCtrl.text,
                    'place_name': placeCtrl.text,
                    'phone': phoneCtrl.text,
                    'email': emailCtrl.text,
                    'is_main': isMain,
                    'is_active': isActive,
                  };
                  if (latCtrl.text.isNotEmpty) {
                    final lv = double.tryParse(latCtrl.text);
                    body['latitude'] = lv != null ? lv.toStringAsFixed(12) : latCtrl.text;
                  }
                  if (lngCtrl.text.isNotEmpty) {
                    final lv = double.tryParse(lngCtrl.text);
                    body['longitude'] = lv != null ? lv.toStringAsFixed(12) : lngCtrl.text;
                  }

                  if (isEdit) {
                    await dio.patch('/pharmacy-profile/branches/${branch['id']}/', data: body);
                  } else {
                    await dio.post('/pharmacy-profile/branches/', data: body);
                  }
                  ref.invalidate(_branchesProvider);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEdit ? 'Branch updated' : 'Branch created'), behavior: SnackBarBehavior.floating));
                  }
                } catch (e) {
                  setState(() => saving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
                }
              },
              icon: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isEdit ? Icons.save_rounded : Icons.add_business_rounded),
              label: Text(isEdit ? 'Save Changes' : 'Create Branch'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ]),
        ),
      );
    }),
  );
}

// ════════════════════════════════════════════════════
// ACTIONS
// ════════════════════════════════════════════════════
void _setMain(BuildContext context, WidgetRef ref, Map<String, dynamic> b) async {
  try {
    await ref.read(dioProvider).patch('/pharmacy-profile/branches/${b['id']}/', data: {'is_main': true});
    ref.invalidate(_branchesProvider);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${b['name']} set as main branch'), behavior: SnackBarBehavior.floating));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
  }
}

void _toggleActive(BuildContext context, WidgetRef ref, Map<String, dynamic> b) async {
  final newVal = !(b['is_active'] == true);
  try {
    await ref.read(dioProvider).patch('/pharmacy-profile/branches/${b['id']}/', data: {'is_active': newVal});
    ref.invalidate(_branchesProvider);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${b['name']} ${newVal ? 'activated' : 'deactivated'}'), behavior: SnackBarBehavior.floating));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
  }
}

void _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> b) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Branch'),
      content: Text('Remove "${b['name']}"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          onPressed: () async {
            Navigator.pop(context);
            try {
              await ref.read(dioProvider).delete('/pharmacy-profile/branches/${b['id']}/');
              ref.invalidate(_branchesProvider);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch deleted'), behavior: SnackBarBehavior.floating));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
            }
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? const Color(0xFF6366F1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? c.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? c : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _MiniKPI extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _MiniKPI({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: color.withValues(alpha: 0.06),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
      ]),
    ]),
  );
}
