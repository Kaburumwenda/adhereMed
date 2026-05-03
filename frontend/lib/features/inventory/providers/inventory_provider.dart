import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/inventory_repository.dart';
import '../models/stock_model.dart';
import '../../../core/models/paginated_response.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository());

final inventoryListProvider = FutureProvider.family<
    PaginatedResponse<MedicationStock>, ({int page, String? search})>(
  (ref, params) => ref
      .read(inventoryRepositoryProvider)
      .getStocks(page: params.page, search: params.search),
);

final inventoryDetailProvider = FutureProvider.family<MedicationStock, int>(
  (ref, id) => ref.read(inventoryRepositoryProvider).getStock(id),
);

final lowStockProvider = FutureProvider.family<
    PaginatedResponse<MedicationStock>, ({int page, String? search})>(
  (ref, params) => ref
      .read(inventoryRepositoryProvider)
      .getLowStock(page: params.page, search: params.search),
);

final categoryListProvider = FutureProvider<List<Category>>(
  (ref) => ref.read(inventoryRepositoryProvider).getCategories(),
);

final unitListProvider = FutureProvider<List<Unit>>(
  (ref) => ref.read(inventoryRepositoryProvider).getUnits(),
);
