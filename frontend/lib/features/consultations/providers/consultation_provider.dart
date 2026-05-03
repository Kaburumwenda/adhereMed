import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/consultation_repository.dart';
import '../models/consultation_model.dart';
import '../../../core/models/paginated_response.dart';

final consultationRepositoryProvider =
    Provider((ref) => ConsultationRepository());

final consultationListProvider = FutureProvider.family<
    PaginatedResponse<Consultation>, ({int page, String? search})>(
  (ref, params) => ref
      .read(consultationRepositoryProvider)
      .getList(page: params.page, search: params.search),
);

final consultationDetailProvider = FutureProvider.family<Consultation, int>(
  (ref, id) => ref.read(consultationRepositoryProvider).getDetail(id),
);
