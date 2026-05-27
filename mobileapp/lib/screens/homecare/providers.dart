import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';

// ─── Dashboard ───────────────────────────────────────────
final homecareDashboardProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/dashboard/summary/');
  return res.data as Map<String, dynamic>;
});

// ─── My Day (caregiver view) ─────────────────────────────
final homecareMyDayProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/caregivers/me/my-day/');
  return res.data as Map<String, dynamic>;
});

// ─── Patients ────────────────────────────────────────────
final homecarePatientSearchProvider = StateProvider<String>((ref) => '');

final homecarePatientsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final search = ref.watch(homecarePatientSearchProvider);
  final params = <String, dynamic>{};
  if (search.isNotEmpty) params['search'] = search;
  final res = await dio.get('/homecare/patients/', queryParameters: params);
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

final homecarePatientDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/patients/$id/');
  return res.data as Map<String, dynamic>;
});

final homecareEnrollmentCaregiversProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/caregivers/', queryParameters: {'page_size': 200});
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

final homecareDoctorDirectoryProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/doctors/directory/', queryParameters: {'page_size': 200});
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

// ─── Caregivers ──────────────────────────────────────────
final homecareCaregiverSearchProvider = StateProvider<String>((ref) => '');

final homecareCaregiversProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final search = ref.watch(homecareCaregiverSearchProvider);
  final params = <String, dynamic>{'page_size': 500};
  if (search.isNotEmpty) params['search'] = search;
  final res = await dio.get('/homecare/caregivers/', queryParameters: params);
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

final homecareCaregiverDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/caregivers/$id/');
  return res.data as Map<String, dynamic>;
});

final homecareCaregiverOverviewProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final responses = await Future.wait([
    dio.get('/homecare/caregivers/$id/'),
    dio.get('/homecare/schedules/', queryParameters: {'caregiver': id, 'page_size': 100}),
    dio.get('/homecare/caregivers/$id/assigned-patients/'),
  ]);

  final visitData = responses[1].data;
  final visits = visitData is List ? visitData : (visitData['results'] as List?) ?? [];
  final patientData = responses[2].data;
  final patients = patientData is List ? patientData : (patientData['results'] as List?) ?? [];

  return {
    'caregiver': responses[0].data as Map<String, dynamic>,
    'visits': visits,
    'patients': patients,
  };
});

// ─── Schedules / Visits ──────────────────────────────────
final homecareScheduleStatusFilter = StateProvider<String>((ref) => '');

final homecareSchedulesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final statusFilter = ref.watch(homecareScheduleStatusFilter);
  final params = <String, dynamic>{};
  if (statusFilter.isNotEmpty) params['status'] = statusFilter;
  final res = await dio.get('/homecare/schedules/', queryParameters: params);
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

// ─── Escalations ─────────────────────────────────────────
final homecareEscalationStatusFilter = StateProvider<String>((ref) => 'open');

final homecareEscalationsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final statusFilter = ref.watch(homecareEscalationStatusFilter);
  final params = <String, dynamic>{};
  if (statusFilter.isNotEmpty) params['status'] = statusFilter;
  final res = await dio.get('/homecare/escalations/', queryParameters: params);
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

// ─── Doses ───────────────────────────────────────────────
final homecareDosesProvider =
    FutureProvider.autoDispose.family<List, Map<String, dynamic>>((ref, params) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/doses/', queryParameters: params);
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

// ─── Treatment Plans ─────────────────────────────────────
final homecareTreatmentPlansProvider =
    FutureProvider.autoDispose.family<List, int>((ref, patientId) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/treatment-plans/', queryParameters: {'patient': patientId});
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});

// ─── Medication Schedules ────────────────────────────────
final homecareMedSchedulesProvider =
    FutureProvider.autoDispose.family<List, int>((ref, patientId) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/medication-schedules/', queryParameters: {'patient': patientId});
  final data = res.data;
  if (data is List) return data;
  return (data['results'] as List?) ?? [];
});
