import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/lab_repository.dart';
import '../models/lab_order_model.dart';
import '../../../core/models/paginated_response.dart';

final labRepositoryProvider = Provider((ref) => LabRepository());

final labOrderListProvider = FutureProvider.family<
    PaginatedResponse<LabOrder>,
    ({int page, String? search, String? status, String? priority})>(
  (ref, params) => ref.read(labRepositoryProvider).getOrders(
        page: params.page,
        search: params.search,
        status: params.status,
        priority: params.priority,
      ),
);

final labOrderDetailProvider = FutureProvider.family<LabOrder, int>(
  (ref, id) => ref.read(labRepositoryProvider).getOrder(id),
);

final labCatalogProvider = FutureProvider<List<LabTestCatalog>>(
  (ref) => ref.read(labRepositoryProvider).getAllCatalogTests(),
);
