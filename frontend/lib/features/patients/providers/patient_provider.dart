import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/patient_repository.dart';
import '../models/patient_model.dart';
import '../../../core/models/paginated_response.dart';

final patientRepositoryProvider = Provider((ref) => PatientRepository());

final patientListProvider = FutureProvider.family<
    PaginatedResponse<Patient>, ({int page, String? search})>(
  (ref, params) => ref
      .read(patientRepositoryProvider)
      .getPatients(page: params.page, search: params.search),
);

final patientDetailProvider = FutureProvider.family<Patient, int>(
  (ref, id) => ref.read(patientRepositoryProvider).getPatient(id),
);
