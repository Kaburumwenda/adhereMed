import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/lab_exchange_repository.dart';
import '../models/lab_exchange_model.dart';
import '../../../core/models/paginated_response.dart';

final labExchangeRepositoryProvider =
    Provider((ref) => LabExchangeRepository());

final labExchangeListProvider = FutureProvider.family<
    PaginatedResponse<LabOrderExchange>,
    ({int page, String? search, String? status, String? priority})>(
  (ref, params) => ref.read(labExchangeRepositoryProvider).getLabExchanges(
        page: params.page,
        search: params.search,
        status: params.status,
        priority: params.priority,
      ),
);

final labExchangeDetailProvider =
    FutureProvider.family<LabOrderExchange, int>(
  (ref, id) => ref.read(labExchangeRepositoryProvider).getLabExchange(id),
);

final labDashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.read(labExchangeRepositoryProvider).getDashboardStats(),
);
