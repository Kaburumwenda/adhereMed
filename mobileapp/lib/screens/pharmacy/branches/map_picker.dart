import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

const _kGoogleApiKey = 'AIzaSyAhiNO62geg58-WaLGeq235Lo8gySLvs_I';

/// Result returned by the map picker
class PickedLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String placeName;
  const PickedLocation({required this.latitude, required this.longitude, required this.address, required this.placeName});
}

/// Full-screen map picker with Places search + GPS + tap-to-pick
class MapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerPage({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? _mapCtrl;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // State
  LatLng? _selectedPos;
  String _address = '';
  String _placeName = '';
  bool _loading = false;
  bool _gpsLoading = false;

  // Places autocomplete
  List<Map<String, dynamic>> _predictions = [];
  bool _showPredictions = false;

  final _dio = Dio();

  // Default: Nairobi
  static const _defaultLat = -1.2921;
  static const _defaultLng = 36.8219;

  LatLng get _initialPos => LatLng(
    widget.initialLat ?? _defaultLat,
    widget.initialLng ?? _defaultLng,
  );

  Set<Marker> get _markers => _selectedPos == null
      ? {}
      : {
          Marker(
            markerId: const MarkerId('picked'),
            position: _selectedPos!,
            draggable: true,
            onDragEnd: _onMarkerDrag,
          ),
        };

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedPos = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode(_selectedPos!);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _mapCtrl?.dispose();
    _dio.close();
    super.dispose();
  }

  // ── Places Autocomplete ────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() { _predictions = []; _showPredictions = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetchPredictions(query));
  }

  Future<void> _fetchPredictions(String query) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {'input': query, 'key': _kGoogleApiKey, 'types': 'geocode|establishment'},
      );
      if (!mounted) return;
      final preds = (res.data['predictions'] as List?) ?? [];
      setState(() {
        _predictions = preds.cast<Map<String, dynamic>>();
        _showPredictions = preds.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _onPredictionSelected(Map<String, dynamic> pred) async {
    setState(() { _showPredictions = false; _loading = true; });
    _searchCtrl.text = pred['description'] ?? '';
    FocusScope.of(context).unfocus();

    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': pred['place_id'],
          'fields': 'formatted_address,geometry,name',
          'key': _kGoogleApiKey,
        },
      );
      final result = res.data['result'];
      if (result != null && mounted) {
        final loc = result['geometry']?['location'];
        if (loc != null) {
          final pos = LatLng(loc['lat'].toDouble(), loc['lng'].toDouble());
          setState(() {
            _selectedPos = pos;
            _address = result['formatted_address'] ?? '';
            _placeName = result['name'] ?? '';
            _loading = false;
          });
          _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Reverse Geocode ────────────────────────────
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'latlng': '${pos.latitude},${pos.longitude}', 'key': _kGoogleApiKey},
      );
      if (!mounted) return;
      final results = (res.data['results'] as List?) ?? [];
      if (results.isNotEmpty) {
        final first = results[0];
        final addr = first['formatted_address'] ?? '';
        // Extract place name from address components
        String place = '';
        final components = (first['address_components'] as List?) ?? [];
        for (final comp in components) {
          final types = (comp['types'] as List?) ?? [];
          if (types.any((t) => ['point_of_interest', 'establishment', 'premise', 'neighborhood', 'sublocality', 'locality'].contains(t))) {
            place = comp['long_name'] ?? '';
            break;
          }
        }
        setState(() { _address = addr; _placeName = place; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Map Tap / Marker Drag ──────────────────────
  void _onMapTap(LatLng pos) {
    setState(() => _selectedPos = pos);
    _reverseGeocode(pos);
  }

  void _onMarkerDrag(LatLng pos) {
    setState(() => _selectedPos = pos);
    _reverseGeocode(pos);
  }

  // ── GPS Location ───────────────────────────────
  Future<void> _useGps() async {
    setState(() => _gpsLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied'), behavior: SnackBarBehavior.floating));
        }
        setState(() => _gpsLoading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() { _selectedPos = ll; _gpsLoading = false; });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 16));
      _reverseGeocode(ll);
    } catch (e) {
      if (mounted) {
        setState(() => _gpsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS error: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  // ── Confirm ────────────────────────────────────
  void _confirm() {
    if (_selectedPos == null) return;
    Navigator.pop(context, PickedLocation(
      latitude: double.parse(_selectedPos!.latitude.toStringAsFixed(6)),
      longitude: double.parse(_selectedPos!.longitude.toStringAsFixed(6)),
      address: _address,
      placeName: _placeName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          if (_gpsLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              onPressed: _useGps,
              icon: const Icon(Icons.my_location_rounded),
              tooltip: 'Use GPS',
            ),
        ],
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search for a place...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _predictions = []; _showPredictions = false; });
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        // Predictions overlay
        if (_showPredictions)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _predictions.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 48, color: cs.outlineVariant.withValues(alpha: 0.15)),
              itemBuilder: (_, i) {
                final p = _predictions[i];
                final main = (p['structured_formatting']?['main_text'] ?? p['description'] ?? '') as String;
                final secondary = (p['structured_formatting']?['secondary_text'] ?? '') as String;
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.location_on_rounded, size: 20, color: cs.primary),
                  title: Text(main, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: secondary.isNotEmpty ? Text(secondary, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                  onTap: () => _onPredictionSelected(p),
                );
              },
            ),
          ),

        // Map
        Expanded(
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _initialPos, zoom: widget.initialLat != null ? 16 : 12),
              onMapCreated: (c) => _mapCtrl = c,
              onTap: _onMapTap,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            if (_loading)
              Positioned(
                top: 12, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text('Getting address...', style: TextStyle(fontSize: 12, color: cs.onSurface)),
                    ]),
                  ),
                ),
              ),

            // Crosshair hint when no marker
            if (_selectedPos == null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.touch_app_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Tap on map to pick location', style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
          ]),
        ),

        // Bottom info + confirm
        if (_selectedPos != null)
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Coordinate chips
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.my_location_rounded, size: 12, color: Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    Text('${_selectedPos!.latitude.toStringAsFixed(6)}, ${_selectedPos!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                  ]),
                ),
                if (_placeName.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                      child: Text(_placeName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF22C55E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ]),
              if (_address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_address, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Text('Drag the pin or tap anywhere to refine', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Use this location'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// PLACES AUTOCOMPLETE FIELD — Reusable widget for form
// ════════════════════════════════════════════════════
class PlacesAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final void Function(PickedLocation location) onPicked;
  final VoidCallback? onPickOnMap;
  final VoidCallback? onUseGps;
  const PlacesAutocompleteField({
    super.key,
    required this.controller,
    required this.onPicked,
    this.onPickOnMap,
    this.onUseGps,
  });

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  Timer? _debounce;
  List<Map<String, dynamic>> _predictions = [];
  bool _showPredictions = false;
  bool _loading = false;
  final _dio = Dio();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _debounce?.cancel();
    _dio.close();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.length < 3) {
      _removeOverlay();
      setState(() { _predictions = []; _showPredictions = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetchPredictions(q));
  }

  Future<void> _fetchPredictions(String q) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {'input': q, 'key': _kGoogleApiKey, 'types': 'geocode|establishment'},
      );
      if (!mounted) return;
      final preds = (res.data['predictions'] as List?) ?? [];
      setState(() {
        _predictions = preds.cast<Map<String, dynamic>>();
        _showPredictions = preds.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _onPredictionSelected(Map<String, dynamic> pred) async {
    setState(() { _showPredictions = false; _loading = true; });
    widget.controller.text = pred['description'] ?? '';
    FocusScope.of(context).unfocus();

    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': pred['place_id'],
          'fields': 'formatted_address,geometry,name',
          'key': _kGoogleApiKey,
        },
      );
      final result = res.data['result'];
      if (result != null && mounted) {
        final loc = result['geometry']?['location'];
        if (loc != null) {
          widget.onPicked(PickedLocation(
            latitude: loc['lat'].toDouble(),
            longitude: loc['lng'].toDouble(),
            address: result['formatted_address'] ?? '',
            placeName: result['name'] ?? '',
          ));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: 'Address / Search Places',
          isDense: true,
          prefixIcon: _loading
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : const Icon(Icons.location_on_rounded, size: 18),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.onPickOnMap != null)
              IconButton(
                icon: const Icon(Icons.map_rounded, size: 20),
                tooltip: 'Pick on map',
                onPressed: widget.onPickOnMap,
                visualDensity: VisualDensity.compact,
              ),
            if (widget.onUseGps != null)
              IconButton(
                icon: const Icon(Icons.gps_fixed_rounded, size: 20),
                tooltip: 'Use GPS',
                onPressed: widget.onUseGps,
                visualDensity: VisualDensity.compact,
              ),
          ]),
        ),
        maxLines: 2,
        minLines: 1,
        onChanged: _onSearchChanged,
      ),

      // Predictions dropdown
      if (_showPredictions && _predictions.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _predictions.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 44, color: cs.outlineVariant.withValues(alpha: 0.15)),
            itemBuilder: (_, i) {
              final p = _predictions[i];
              final main = (p['structured_formatting']?['main_text'] ?? p['description'] ?? '') as String;
              final secondary = (p['structured_formatting']?['secondary_text'] ?? '') as String;
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(Icons.location_on_rounded, size: 18, color: cs.primary),
                title: Text(main, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: secondary.isNotEmpty ? Text(secondary, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                onTap: () => _onPredictionSelected(p),
              );
            },
          ),
        ),
    ]);
  }
}
