import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/delivery_repository.dart';
import '../../../core/models/paginated_response.dart';

final deliveryRepositoryProvider = Provider((ref) => DeliveryRepository());

final deliveryListProvider = FutureProvider.family<
    PaginatedResponse<Delivery>, ({int page, String? search, String? status})>(
  (ref, params) => ref
      .read(deliveryRepositoryProvider)
      .getDeliveries(page: params.page, search: params.search, status: params.status),
);
