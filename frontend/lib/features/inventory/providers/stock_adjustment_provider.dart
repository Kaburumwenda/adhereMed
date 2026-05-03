import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/inventory_repository.dart';
import '../repository/stock_adjustment_repository.dart';
import '../../../core/models/paginated_response.dart';

final stockAdjustmentRepositoryProvider = Provider((ref) => StockAdjustmentRepository());

final stockAdjustmentListProvider = FutureProvider.family<
    PaginatedResponse<StockAdjustment>, ({int page, String? search})>(
  (ref, params) => ref
      .read(stockAdjustmentRepositoryProvider)
      .getAdjustments(page: params.page, search: params.search),
);

final inventoryAnalyticsProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => InventoryRepository().getAnalytics(),
);
