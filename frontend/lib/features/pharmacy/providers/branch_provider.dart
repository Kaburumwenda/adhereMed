import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repository/branch_repository.dart';
import '../models/branch_model.dart';

final branchRepositoryProvider = Provider((ref) => BranchRepository());

/// All active branches for this tenant.
final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  return ref.watch(branchRepositoryProvider).getBranches(isActive: true);
});

const _kActiveBranchId = 'active_branch_id';

/// Notifier that persists the selected branch to SharedPreferences.
class ActiveBranchNotifier extends StateNotifier<Branch?> {
  ActiveBranchNotifier() : super(null);

  void setFromList(List<Branch> branches, int? savedId) {
    if (state != null) return; // already set
    if (savedId != null) {
      final found = branches.where((b) => b.id == savedId);
      if (found.isNotEmpty) {
        state = found.first;
        return;
      }
    }
    // Default to main branch or first
    if (branches.isNotEmpty) {
      state = branches.firstWhere((b) => b.isMain, orElse: () => branches.first);
    }
  }

  Future<void> select(Branch branch) async {
    state = branch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kActiveBranchId, branch.id);
  }

  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveBranchId);
  }
}

final activeBranchProvider = StateNotifierProvider<ActiveBranchNotifier, Branch?>(
  (ref) => ActiveBranchNotifier(),
);

/// Initialiser — call once in AppProviderScope or on login.
/// Reads saved branch id from prefs and seeds the active branch from loaded list.
final branchInitProvider = FutureProvider<void>((ref) async {
  final branches = await ref.watch(branchesProvider.future);
  final prefs = await SharedPreferences.getInstance();
  final savedId = prefs.getInt(_kActiveBranchId);
  ref.read(activeBranchProvider.notifier).setFromList(branches, savedId);
});
