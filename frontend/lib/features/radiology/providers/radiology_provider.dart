import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/radiology_repository.dart';
import '../models/radiology_model.dart';
import '../../../core/models/paginated_response.dart';

final radiologyRepositoryProvider = Provider((ref) => RadiologyRepository());

final radiologyOrderListProvider = FutureProvider.family<
    PaginatedResponse<RadiologyOrder>,
    ({int page, String? search, String? status, String? imagingType})>(
  (ref, params) => ref.read(radiologyRepositoryProvider).getOrders(
        page: params.page,
        search: params.search,
        status: params.status,
        imagingType: params.imagingType,
      ),
);

final radiologyOrderDetailProvider = FutureProvider.family<RadiologyOrder, int>(
  (ref, id) => ref.read(radiologyRepositoryProvider).getOrder(id),
);
