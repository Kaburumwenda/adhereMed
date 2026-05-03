import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/department_repository.dart';
import '../models/department_model.dart';
import '../../../core/models/paginated_response.dart';

final departmentRepositoryProvider =
    Provider((ref) => DepartmentRepository());

final departmentListProvider = FutureProvider.family<
    PaginatedResponse<Department>, ({int page, String? search})>(
  (ref, params) => ref
      .read(departmentRepositoryProvider)
      .getList(page: params.page, search: params.search),
);

final departmentDetailProvider = FutureProvider.family<Department, int>(
  (ref, id) => ref.read(departmentRepositoryProvider).getDetail(id),
);
