import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/prescription_repository.dart';
import '../models/prescription_model.dart';
import '../../../core/models/paginated_response.dart';

final prescriptionRepositoryProvider =
    Provider((ref) => PrescriptionRepository());

final prescriptionListProvider = FutureProvider.family<
    PaginatedResponse<Prescription>, ({int page, String? search})>(
  (ref, params) => ref
      .read(prescriptionRepositoryProvider)
      .getList(page: params.page, search: params.search),
);

final prescriptionDetailProvider = FutureProvider.family<Prescription, int>(
  (ref, id) => ref.read(prescriptionRepositoryProvider).getDetail(id),
);
