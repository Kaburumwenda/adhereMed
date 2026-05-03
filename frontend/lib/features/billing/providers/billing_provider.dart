import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/billing_repository.dart';
import '../models/invoice_model.dart';
import '../../../core/models/paginated_response.dart';

final billingRepositoryProvider = Provider((ref) => BillingRepository());

final invoiceListProvider = FutureProvider.family<
    PaginatedResponse<Invoice>, ({int page, String? search})>(
  (ref, params) => ref
      .read(billingRepositoryProvider)
      .getList(page: params.page, search: params.search),
);

final invoiceDetailProvider = FutureProvider.family<Invoice, int>(
  (ref, id) => ref.read(billingRepositoryProvider).getDetail(id),
);
