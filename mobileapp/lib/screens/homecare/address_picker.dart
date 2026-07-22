import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:http/http.dart' as http;
import 'hc_common.dart';

/// Google Maps API key (set in env or here)
const kGoogleMapsApiKey = 'AIzaSyAhiNO62geg58-WaLGeq235Lo8gySLvs_I';

/// Result from address picker
class AddressPickResult {
  final String address;
  final double? lat;
  final double? lng;
  AddressPickResult({required this.address, this.lat, this.lng});
}

/// Address picker that supports:
/// 1. Google Places autocomplete search
/// 2. Open Google Maps to pick a point
/// 3. Use current GPS location
class HcAddressPicker extends StatefulWidget {
  final String? initialAddress;
  final ValueChanged<AddressPickResult> onPicked;

  const HcAddressPicker({
    super.key,
    this.initialAddress,
    required this.onPicked,
  });

  @override
  State<HcAddressPicker> createState() => _HcAddressPickerState();
}

class _HcAddressPickerState extends State<HcAddressPicker> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  List<Prediction> _predictions = [];
  bool _loading = false;
  bool _showDropdown = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _ctrl.text = widget.initialAddress!;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _buildPlacesUrl(String input) {
    return 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$kGoogleMapsApiKey&components=country:ke';
  }

  String _buildDetailsUrl(String placeId) {
    return 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=formatted_address,geometry&key=$kGoogleMapsApiKey';
  }

  Future<void> _searchPlaces(String input) async {
    if (input.trim().length < 3) {
      setState(() { _predictions = []; _showDropdown = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(_buildPlacesUrl(input)));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          final preds = (data['predictions'] as List)
              .map((p) => Prediction.fromJson(p))
              .toList();
          setState(() { _predictions = preds; _showDropdown = preds.isNotEmpty; });
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _selectPrediction(Prediction p) async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(_buildDetailsUrl(p.placeId!)));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final addr = result['formatted_address'] ?? p.description ?? '';
          final loc = result['geometry']?['location'];
          if (loc != null) {
            _lat = loc['lat'].toDouble();
            _lng = loc['lng'].toDouble();
          }
          _ctrl.text = addr;
          widget.onPicked(AddressPickResult(address: addr, lat: _lat, lng: _lng));
        }
      }
    } catch (_) {}
    setState(() { _loading = false; _showDropdown = false; _predictions = []; });
    _focusNode.unfocus();
  }

  Future<void> _pickFromMap() async {
    // Open Google Maps app with a draggable pin, then the user comes back
    // and enters coordinates manually — or we use google_maps_flutter.
    // For simplicity, show a dialog asking for coordinates or open Google Maps URL.
    final latCtrl = TextEditingController(text: _lat?.toStringAsFixed(6) ?? '');
    final lngCtrl = TextEditingController(text: _lng?.toStringAsFixed(6) ?? '');
    final addrCtrl = TextEditingController(text: _ctrl.text);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: hcTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.map_rounded, color: hcTeal, size: 20)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Pick from map', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address / description', isDense: true)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: latCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Latitude', isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: lngCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Longitude', isDense: true))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx, {
                'address': addrCtrl.text.trim(),
                'lat': double.tryParse(latCtrl.text),
                'lng': double.tryParse(lngCtrl.text),
              });
            },
            icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Apply'),
            style: FilledButton.styleFrom(backgroundColor: hcTeal),
          ),
        ],
      ),
    );

    if (result != null) {
      final lat = result['lat'] as double?;
      final lng = result['lng'] as double?;
      setState(() { _lat = lat; _lng = lng; _ctrl.text = result['address'] ?? ''; });
      widget.onPicked(AddressPickResult(
        address: result['address'] ?? '',
        lat: lat,
        lng: lng,
      ));
    }
  }

  Future<void> _pickFromGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      
      // Reverse geocode using Google Maps API
      setState(() => _loading = true);
      try {
        final res = await http.get(Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$kGoogleMapsApiKey'));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final addr = data['results'][0]['formatted_address'];
            setState(() { _ctrl.text = addr; _lat = pos.latitude; _lng = pos.longitude; });
            widget.onPicked(AddressPickResult(address: addr, lat: pos.latitude, lng: pos.longitude));
          }
        }
      } catch (_) {
        setState(() { _ctrl.text = '${pos.latitude}, ${pos.longitude}'; _lat = pos.latitude; _lng = pos.longitude; });
        widget.onPicked(AddressPickResult(address: '${pos.latitude}, ${pos.longitude}', lat: pos.latitude, lng: pos.longitude));
      }
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get location')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // Address text field with action buttons
      Row(children: [
        Expanded(child: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Home address',
            prefixIcon: const Icon(Icons.home_rounded),
            suffixIcon: _loading
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : _ctrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _ctrl.clear(); setState(() { _lat = null; _lng = null; _predictions = []; _showDropdown = false; }); widget.onPicked(AddressPickResult(address: '')); })
                    : null,
            helperText: 'Search, pick on map, or use GPS',
            helperMaxLines: 2,
          ),
          onChanged: (v) {
            if (v.trim().length >= 3) _searchPlaces(v);
            else setState(() { _predictions = []; _showDropdown = false; });
          },
          onTap: () {
            if (_ctrl.text.trim().length >= 3 && _predictions.isNotEmpty) {
              setState(() => _showDropdown = true);
            }
          },
        )),
      ]),
      const SizedBox(height: 6),

      // Action buttons row
      Row(children: [
        _ActionChip(icon: Icons.search_rounded, label: 'Search', color: hcTeal, onTap: () => _focusNode.requestFocus()),
        const SizedBox(width: 8),
        _ActionChip(icon: Icons.map_rounded, label: 'Map', color: hcBlue, onTap: _pickFromMap),
        const SizedBox(width: 8),
        _ActionChip(icon: Icons.gps_fixed_rounded, label: 'GPS', color: hcGreen, onTap: _pickFromGps),
      ]),

      // Lat/lng hint
      if (_lat != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Row(children: [
            Icon(Icons.gps_fixed_rounded, size: 12, color: hcTeal),
            const SizedBox(width: 4),
            Text('${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}', style: const TextStyle(fontSize: 11, color: hcTeal)),
          ]),
        ),

      // Places dropdown results (inline)
      if (_showDropdown && _predictions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _predictions.length,
            itemBuilder: (_, i) {
              final p = _predictions[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.location_on_rounded, size: 18, color: hcTeal),
                title: Text(p.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                onTap: () => _selectPrediction(p),
              );
            },
          ),
        ),
    ]);
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ])),
      ),
    );
  }
}
