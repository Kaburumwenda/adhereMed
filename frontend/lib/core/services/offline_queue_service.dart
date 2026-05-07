import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _kQueueKey = 'pos_offline_queue';

/// A single pending POS transaction that could not be submitted while offline.
class PendingPOSSale {
  final String localId;
  final Map<String, dynamic> payload; // the data sent to createTransaction()
  final String createdAt; // ISO-8601 local timestamp
  final double totalAmount;
  final String? customerName;
  SyncStatus status;

  PendingPOSSale({
    required this.localId,
    required this.payload,
    required this.createdAt,
    required this.totalAmount,
    this.customerName,
    this.status = SyncStatus.pending,
  });

  factory PendingPOSSale.fromJson(Map<String, dynamic> json) => PendingPOSSale(
        localId: json['local_id'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: json['created_at'] as String,
        totalAmount: (json['total_amount'] as num).toDouble(),
        customerName: json['customer_name'] as String?,
        status: SyncStatus.pending, // always start pending on restore
      );

  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'payload': payload,
        'created_at': createdAt,
        'total_amount': totalAmount,
        'customer_name': customerName,
      };
}

enum SyncStatus { pending, syncing, failed }

/// Persists and manages pending POS transactions for offline use.
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  List<PendingPOSSale> _queue = [];

  List<PendingPOSSale> get queue => List.unmodifiable(_queue);

  int get pendingCount =>
      _queue.where((s) => s.status != SyncStatus.syncing).length;

  /// Load persisted queue from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kQueueKey) ?? [];
    _queue = raw.map((e) {
      try {
        return PendingPOSSale.fromJson(
            jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<PendingPOSSale>().toList();
  }

  /// Enqueue a new pending sale and persist it.
  Future<PendingPOSSale> enqueue({
    required Map<String, dynamic> payload,
    required double totalAmount,
    String? customerName,
  }) async {
    final sale = PendingPOSSale(
      localId: 'offline_${DateTime.now().millisecondsSinceEpoch}',
      payload: payload,
      createdAt: DateTime.now().toIso8601String(),
      totalAmount: totalAmount,
      customerName: customerName,
    );
    _queue.add(sale);
    await _persist();
    return sale;
  }

  /// Remove a successfully synced sale and persist the updated queue.
  Future<void> remove(String localId) async {
    _queue.removeWhere((s) => s.localId == localId);
    await _persist();
  }

  /// Mark a sale as failed (reverts from syncing).
  void markFailed(String localId) {
    final idx = _queue.indexWhere((s) => s.localId == localId);
    if (idx >= 0) _queue[idx].status = SyncStatus.failed;
  }

  /// Attempt to sync all pending sales using the provided upload function.
  /// Returns the number of successfully synced sales.
  Future<int> syncAll(
      Future<void> Function(PendingPOSSale sale) upload) async {
    int synced = 0;
    final toSync = _queue
        .where((s) => s.status != SyncStatus.syncing)
        .toList();

    for (final sale in toSync) {
      sale.status = SyncStatus.syncing;
      try {
        await upload(sale);
        await remove(sale.localId);
        synced++;
      } catch (_) {
        markFailed(sale.localId);
      }
    }
    return synced;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kQueueKey,
      _queue.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }
}
