import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/pos_repository.dart';
import '../models/pos_transaction_model.dart';
import '../../../core/models/paginated_response.dart';

final posRepositoryProvider = Provider((ref) => POSRepository());

final posTransactionListProvider = FutureProvider.family<
    PaginatedResponse<POSTransaction>, ({int page, String? search})>(
  (ref, params) => ref
      .read(posRepositoryProvider)
      .getTransactions(page: params.page, search: params.search),
);

final posTransactionDetailProvider =
    FutureProvider.family<POSTransaction, int>(
  (ref, id) => ref.read(posRepositoryProvider).getTransaction(id),
);

final todayTransactionsProvider = FutureProvider<List<POSTransaction>>(
  (ref) => ref.read(posRepositoryProvider).getTodayTransactions(),
);
