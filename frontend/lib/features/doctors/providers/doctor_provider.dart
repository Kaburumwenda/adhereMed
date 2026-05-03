import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/doctor_repository.dart';
import '../models/doctor_model.dart';
import '../../../core/models/paginated_response.dart';

final doctorRepositoryProvider = Provider((ref) => DoctorRepository());

final doctorDirectoryProvider = FutureProvider.family<
    PaginatedResponse<DoctorProfile>, ({int page, String? search})>(
  (ref, params) => ref
      .read(doctorRepositoryProvider)
      .getDirectory(page: params.page, search: params.search),
);

final doctorDetailProvider = FutureProvider.family<DoctorProfile, int>(
  (ref, id) => ref.read(doctorRepositoryProvider).getDoctor(id),
);
