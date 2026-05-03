import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/ward_repository.dart';
import '../models/ward_model.dart';
import '../../../core/models/paginated_response.dart';

final wardRepositoryProvider = Provider((ref) => WardRepository());

final wardListProvider = FutureProvider.family<
    PaginatedResponse<Ward>,
    ({int page, String? search, String? type})>(
  (ref, params) => ref.read(wardRepositoryProvider).getWards(
        page: params.page,
        search: params.search,
        type: params.type,
      ),
);

final wardDetailProvider = FutureProvider.family<Ward, int>(
  (ref, id) => ref.read(wardRepositoryProvider).getWard(id),
);

final admissionListProvider = FutureProvider.family<
    PaginatedResponse<Admission>,
    ({int page, String? search, String? status})>(
  (ref, params) => ref.read(wardRepositoryProvider).getAdmissions(
        page: params.page,
        search: params.search,
        status: params.status,
      ),
);
