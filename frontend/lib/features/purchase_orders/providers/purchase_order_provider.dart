import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/purchase_order_repository.dart';
import '../models/purchase_order_model.dart';
import '../../../core/models/paginated_response.dart';

final purchaseOrderRepositoryProvider =
    Provider((ref) => PurchaseOrderRepository());

final purchaseOrderListProvider = FutureProvider.family<
    PaginatedResponse<PurchaseOrder>, ({int page, String? search})>(
  (ref, params) => ref
      .read(purchaseOrderRepositoryProvider)
      .getPurchaseOrders(page: params.page, search: params.search),
);

final purchaseOrderDetailProvider =
    FutureProvider.family<PurchaseOrder, int>(
  (ref, id) => ref.read(purchaseOrderRepositoryProvider).getPurchaseOrder(id),
);
