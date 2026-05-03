import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/customer_repository.dart';
import '../../../core/models/paginated_response.dart';

final customerRepositoryProvider = Provider((ref) => CustomerRepository());

final customerListProvider = FutureProvider.family<
    PaginatedResponse<Customer>, ({int page, String? search})>(
  (ref, params) => ref
      .read(customerRepositoryProvider)
      .getCustomers(page: params.page, search: params.search),
);

final customerDetailProvider = FutureProvider.family<Customer, int>(
  (ref, id) => ref.read(customerRepositoryProvider).getCustomer(id),
);
