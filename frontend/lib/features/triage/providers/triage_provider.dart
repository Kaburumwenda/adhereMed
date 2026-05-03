import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/triage_repository.dart';
import '../models/triage_model.dart';
import '../../../core/models/paginated_response.dart';

final triageRepositoryProvider = Provider((ref) => TriageRepository());

final triageListProvider = FutureProvider.family<
    PaginatedResponse<TriageRecord>, ({int page, String? search})>(
  (ref, params) => ref
      .read(triageRepositoryProvider)
      .getList(page: params.page, search: params.search),
);

final triageDetailProvider = FutureProvider.family<TriageRecord, int>(
  (ref, id) => ref.read(triageRepositoryProvider).getDetail(id),
);
