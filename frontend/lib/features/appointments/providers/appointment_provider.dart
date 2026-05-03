import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/appointment_repository.dart';
import '../models/appointment_model.dart';
import '../../../core/models/paginated_response.dart';

final appointmentRepositoryProvider =
    Provider((ref) => AppointmentRepository());

final appointmentListProvider = FutureProvider.family<
    PaginatedResponse<Appointment>, ({int page, String? search})>(
  (ref, params) => ref
      .read(appointmentRepositoryProvider)
      .getList(page: params.page, search: params.search),
);

final appointmentDetailProvider = FutureProvider.family<Appointment, int>(
  (ref, id) => ref.read(appointmentRepositoryProvider).getDetail(id),
);
