import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/exchange_repository.dart';
import '../models/exchange_model.dart';
import '../../../core/models/paginated_response.dart';

final exchangeRepositoryProvider = Provider((ref) => ExchangeRepository());

final exchangeListProvider = FutureProvider.family<
    PaginatedResponse<PrescriptionExchange>, ({int page, String? search})>(
  (ref, params) => ref
      .read(exchangeRepositoryProvider)
      .getExchanges(page: params.page, search: params.search),
);

final exchangeDetailProvider =
    FutureProvider.family<PrescriptionExchange, int>(
  (ref, id) => ref.read(exchangeRepositoryProvider).getExchange(id),
);

final quotesProvider = FutureProvider.family<List<PharmacyQuote>, int>(
  (ref, exchangeId) =>
      ref.read(exchangeRepositoryProvider).getQuotes(exchangeId),
);
