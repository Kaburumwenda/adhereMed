import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/dispensing_repository.dart';
import '../models/dispensing_model.dart';
import '../../../core/models/paginated_response.dart';

final dispensingRepositoryProvider =
    Provider((ref) => DispensingRepository());

final dispensingListProvider = FutureProvider.family<
    PaginatedResponse<DispensingRecord>, ({int page, String? search})>(
  (ref, params) => ref
      .read(dispensingRepositoryProvider)
      .getRecords(page: params.page, search: params.search),
);

final dispensingDetailProvider =
    FutureProvider.family<DispensingRecord, int>(
  (ref, id) => ref.read(dispensingRepositoryProvider).getRecord(id),
);
