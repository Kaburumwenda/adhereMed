import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import 'auth_provider.dart';

const _kBranchKey = 'adheremed_branch_id';

/// Roles that get soft-assigned to nearby branches (can switch within 1km).
const _softAssignRoles = {'cashier', 'pharmacist', 'pharmacy_tech'};

/// Roles that can freely switch between any branch.
const _adminRoles = {'super_admin', 'tenant_admin'};

/// Haversine distance in km between two lat/lon pairs.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _toRad(double v) => v * pi / 180;

/// Location permission status for soft-assign roles.
enum LocationStatus {
  unknown,   // not yet checked
  granted,   // permission granted & location obtained
  denied,    // user denied permission
  disabled,  // location services turned off on device
}

class BranchState {
  final List<Map<String, dynamic>> branches;
  final int? currentBranchId;
  final bool loading;
  final double? userLat;
  final double? userLon;
  final int? userBranchId; // assigned via staff_profile
  final String? autoAssignedBranchName;
  final LocationStatus locationStatus;

  const BranchState({
    this.branches = const [],
    this.currentBranchId,
    this.loading = false,
    this.userLat,
    this.userLon,
    this.userBranchId,
    this.autoAssignedBranchName,
    this.locationStatus = LocationStatus.unknown,
  });

  /// Whether location is not available (denied or services off).
  bool get locationBlocked => locationStatus == LocationStatus.denied || locationStatus == LocationStatus.disabled;

  /// Whether the branch selector should be locked (no location + soft-assign role).
  /// When locked, user can only use their assigned branch.
  bool get branchLocked => locationBlocked && userBranchId != null;

  Map<String, dynamic>? get currentBranch =>
      branches.where((b) => b['id'] == currentBranchId).firstOrNull;

  List<Map<String, dynamic>> get activeBranches =>
      branches.where((b) => b['is_active'] == true).toList();

  /// For soft-assign roles: branches within 1km + assigned branch.
  /// For admins: all active branches.
  List<Map<String, dynamic>> allowedBranches(String role) {
    final active = activeBranches;
    if (_adminRoles.contains(role)) return active;

    // Soft-assign roles get geo-filtered list
    if (userLat == null || userLon == null) {
      // No geo — only show assigned branch
      if (userBranchId != null) {
        return active.where((b) => b['id'] == userBranchId).toList();
      }
      return active;
    }

    final nearby = active.where((b) {
      if (b['id'] == userBranchId) return true; // always include assigned
      final lat = _parseDouble(b['latitude']);
      final lon = _parseDouble(b['longitude']);
      if (lat == null || lon == null) return false;
      return _haversineKm(userLat!, userLon!, lat, lon) <= 1.0;
    }).toList();

    if (nearby.isNotEmpty) return nearby;
    // Fallback: assigned branch or all
    if (userBranchId != null) {
      return active.where((b) => b['id'] == userBranchId).toList();
    }
    return active;
  }

  BranchState copyWith({
    List<Map<String, dynamic>>? branches,
    int? currentBranchId,
    bool? loading,
    double? userLat,
    double? userLon,
    int? userBranchId,
    String? autoAssignedBranchName,
    LocationStatus? locationStatus,
    bool clearBranchId = false,
    bool clearAutoAssigned = false,
  }) {
    return BranchState(
      branches: branches ?? this.branches,
      currentBranchId: clearBranchId ? null : (currentBranchId ?? this.currentBranchId),
      loading: loading ?? this.loading,
      userLat: userLat ?? this.userLat,
      userLon: userLon ?? this.userLon,
      userBranchId: userBranchId ?? this.userBranchId,
      autoAssignedBranchName: clearAutoAssigned ? null : (autoAssignedBranchName ?? this.autoAssignedBranchName),
      locationStatus: locationStatus ?? this.locationStatus,
    );
  }
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class BranchNotifier extends StateNotifier<BranchState> {
  final Ref _ref;

  BranchNotifier(this._ref) : super(const BranchState());

  /// Load branches from API and restore persisted selection.
  Future<void> load() async {
    if (state.branches.isNotEmpty) return;
    state = state.copyWith(loading: true);
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get('/pharmacy-profile/branches/', queryParameters: {'page_size': 200});
      final data = res.data;
      final list = data is List ? data : (data?['results'] as List?) ?? [];
      final branches = List<Map<String, dynamic>>.from(list);

      // Restore persisted branch
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_kBranchKey);
      int? branchId;
      if (saved != null && branches.any((b) => b['id'] == saved)) {
        branchId = saved;
      }

      // Get user's assigned branch from auth
      final auth = _ref.read(authProvider);
      final userBranchId = auth.user?.branchId;

      state = state.copyWith(
        branches: branches,
        currentBranchId: branchId,
        userBranchId: userBranchId,
        loading: false,
      );
    } catch (e) {
      debugPrint('[BranchProvider] load() error: $e');
      state = state.copyWith(loading: false);
    }
  }

  /// Select a branch (validates for soft-assign roles).
  Future<void> select(int? branchId) async {
    final role = _ref.read(authProvider).user?.role ?? '';

    // Soft-assign roles can only select from allowed branches
    if (_softAssignRoles.contains(role) && branchId != null) {
      final allowed = state.allowedBranches(role);
      if (allowed.isNotEmpty && !allowed.any((b) => b['id'] == branchId)) return;
    }

    state = state.copyWith(currentBranchId: branchId, clearBranchId: branchId == null);

    final prefs = await SharedPreferences.getInstance();
    if (branchId != null) {
      await prefs.setInt(_kBranchKey, branchId);
    } else {
      await prefs.remove(_kBranchKey);
    }
  }

  /// Auto-assign the nearest branch using geolocation.
  Future<void> autoAssignNearest() async {
    final role = _ref.read(authProvider).user?.role ?? '';
    if (_adminRoles.contains(role)) {
      state = state.copyWith(locationStatus: LocationStatus.granted);
      return;
    }

    // If already has a persisted branch, just capture location for filtering
    if (state.currentBranchId != null) {
      await _captureLocation();
      return;
    }

    // If branches haven't loaded yet, try loading them
    if (state.branches.isEmpty) {
      await load();
    }

    final active = state.activeBranches;
    if (active.isEmpty) {
      debugPrint('[BranchProvider] No active branches found');
      return;
    }

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(locationStatus: LocationStatus.disabled);
        _fallbackAssign(active);
        return;
      }

      // Check/request location permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        state = state.copyWith(locationStatus: LocationStatus.denied);
        _fallbackAssign(active);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));

      state = state.copyWith(userLat: pos.latitude, userLon: pos.longitude, locationStatus: LocationStatus.granted);

      // Find nearest branch
      Map<String, dynamic>? nearest;
      double minDist = double.infinity;
      for (final b in active) {
        final lat = _parseDouble(b['latitude']);
        final lon = _parseDouble(b['longitude']);
        if (lat == null || lon == null) continue;
        final d = _haversineKm(pos.latitude, pos.longitude, lat, lon);
        if (d < minDist) {
          minDist = d;
          nearest = b;
        }
      }

      if (nearest != null) {
        final id = nearest['id'] as int;
        state = state.copyWith(
          currentBranchId: id,
          autoAssignedBranchName: nearest['name']?.toString(),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kBranchKey, id);
      } else {
        _fallbackAssign(active);
      }
    } catch (_) {
      if (state.locationStatus == LocationStatus.unknown) {
        state = state.copyWith(locationStatus: LocationStatus.denied);
      }
      _fallbackAssign(active);
    }
  }

  /// Capture user location silently (for allowedBranches filtering).
  Future<void> _captureLocation() async {
    if (state.userLat != null) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(locationStatus: LocationStatus.disabled);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        state = state.copyWith(locationStatus: LocationStatus.denied);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));
      state = state.copyWith(userLat: pos.latitude, userLon: pos.longitude, locationStatus: LocationStatus.granted);
    } catch (_) {
      state = state.copyWith(locationStatus: LocationStatus.denied);
    }
  }

  /// Re-check location permission (e.g. after user enables in settings).
  Future<void> recheckLocation() async {
    // Reset location state to re-attempt
    state = BranchState(
      branches: state.branches,
      currentBranchId: state.currentBranchId,
      loading: false,
      userLat: null,
      userLon: null,
      userBranchId: state.userBranchId,
      locationStatus: LocationStatus.unknown,
    );
    final role = _ref.read(authProvider).user?.role ?? '';
    if (_adminRoles.contains(role)) {
      state = state.copyWith(locationStatus: LocationStatus.granted);
      return;
    }
    // Re-run the full auto-assign flow
    // Clear currentBranchId so autoAssignNearest doesn't shortcut
    state = BranchState(
      branches: state.branches,
      currentBranchId: null,
      loading: false,
      userBranchId: state.userBranchId,
      locationStatus: LocationStatus.unknown,
    );
    await autoAssignNearest();
  }

  void _fallbackAssign(List<Map<String, dynamic>> active) {
    // Use assigned branch, or main branch, or first active
    final auth = _ref.read(authProvider);
    final assignedId = auth.user?.branchId;
    Map<String, dynamic>? target;
    if (assignedId != null) {
      target = active.where((b) => b['id'] == assignedId).firstOrNull;
    }
    target ??= active.where((b) => b['is_main'] == true).firstOrNull;
    target ??= active.first;

    final id = target['id'] as int;
    state = state.copyWith(
      currentBranchId: id,
      autoAssignedBranchName: target['name']?.toString(),
    );
    SharedPreferences.getInstance().then((p) => p.setInt(_kBranchKey, id));
  }

  /// Clear branch state (on logout).
  Future<void> clear() async {
    state = const BranchState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBranchKey);
  }
}

final branchProvider = StateNotifierProvider<BranchNotifier, BranchState>((ref) {
  return BranchNotifier(ref);
});
