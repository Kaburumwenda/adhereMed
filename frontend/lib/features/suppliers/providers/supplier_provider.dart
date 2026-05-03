import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/supplier_repository.dart';
import '../models/supplier_model.dart';
import '../../../core/models/paginated_response.dart';

final supplierRepositoryProvider = Provider((ref) => SupplierRepository());

final supplierListProvider = FutureProvider.family<
    PaginatedResponse<Supplier>, ({int page, String? search})>(
  (ref, params) => ref
      .read(supplierRepositoryProvider)
      .getSuppliers(page: params.page, search: params.search),
);

final supplierDetailProvider = FutureProvider.family<Supplier, int>(
  (ref, id) => ref.read(supplierRepositoryProvider).getSupplier(id),
);
