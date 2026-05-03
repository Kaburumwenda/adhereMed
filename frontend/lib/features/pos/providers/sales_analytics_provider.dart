import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/sales_analytics_repository.dart';

final salesAnalyticsRepositoryProvider = Provider((ref) => SalesAnalyticsRepository());

final salesAnalyticsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String period, int? branchId})>(
  (ref, params) => ref
      .read(salesAnalyticsRepositoryProvider)
      .getSalesAnalytics(period: params.period, branchId: params.branchId),
);
