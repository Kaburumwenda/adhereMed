import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';

class _StaffMember {
  final int id;
  final String userName;
  final String userEmail;
  final String userRole;
  final String specializationName;
  final String? licenseNumber;
  final String? qualification;
  final int yearsOfExperience;
  final bool isAvailable;

  _StaffMember({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.specializationName,
    this.licenseNumber,
    this.qualification,
    required this.yearsOfExperience,
    required this.isAvailable,
  });

  factory _StaffMember.fromJson(Map<String, dynamic> json) => _StaffMember(
        id: json['id'] as int,
        userName: json['user_name'] as String? ?? 'Unknown',
        userEmail: json['user_email'] as String? ?? '',
        userRole: json['user_role'] as String? ?? '',
        specializationName: json['specialization_name'] as String? ?? '',
        licenseNumber: json['license_number'] as String?,
        qualification: json['qualification'] as String?,
        yearsOfExperience: json['years_of_experience'] as int? ?? 0,
        isAvailable: json['is_available'] as bool? ?? true,
      );

  String get roleLabel {
    switch (userRole) {
      case 'pharmacist':
        return 'Pharmacist';
      case 'pharmacy_tech':
        return 'Pharmacy Tech';
      case 'cashier':
        return 'Cashier';
      default:
        return userRole;
    }
  }
}

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final Dio _dio = ApiClient.instance;
  List<_StaffMember> _staff = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{};
      if (_search.isNotEmpty) params['search'] = _search;
      final response = await _dio.get('/staff/', queryParameters: params);
      final results = response.data['results'] as List<dynamic>? ??
          (response.data is List ? response.data as List : []);
      setState(() {
        _staff = results
            .map((e) => _StaffMember.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteStaff(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: const Text(
            'Are you sure you want to remove this staff member? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dio.delete('/staff/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Staff member removed'),
              backgroundColor: AppColors.success),
        );
        _loadStaff();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to remove: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Staff',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final result = await context.push<bool>('/staff/new');
                  if (result == true) _loadStaff();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Staff'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SearchField(
            hintText: 'Search staff...',
            onChanged: (v) {
              _search = v;
              _loadStaff();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: LoadingWidget())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _staff.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.badge_outlined,
                            title: 'No staff members',
                            subtitle: 'Add pharmacy staff to get started',
                            actionLabel: 'Add Staff',
                            onAction: () async {
                              final result =
                                  await context.push<bool>('/staff/new');
                              if (result == true) _loadStaff();
                            },
                          )
                        : Card(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Specialization')),
                                  DataColumn(label: Text('Qualification')),
                                  DataColumn(label: Text('License')),
                                  DataColumn(
                                      label: Text('Experience'),
                                      numeric: true),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _staff.map((s) {
                                  return DataRow(cells: [
                                    DataCell(
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(s.userName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500)),
                                          Text(s.userEmail,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(s.roleLabel,
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    )),
                                    DataCell(Text(
                                        s.specializationName.isNotEmpty
                                            ? s.specializationName
                                            : '-')),
                                    DataCell(Text(s.qualification ?? '-')),
                                    DataCell(Text(s.licenseNumber ?? '-')),
                                    DataCell(
                                        Text('${s.yearsOfExperience} yrs')),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (s.isAvailable
                                                ? AppColors.success
                                                : AppColors.textSecondary)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        s.isAvailable
                                            ? 'Available'
                                            : 'Unavailable',
                                        style: TextStyle(
                                          color: s.isAvailable
                                              ? AppColors.success
                                              : AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 20),
                                          tooltip: 'Edit',
                                          onPressed: () async {
                                            final result =
                                                await context.push<bool>(
                                                    '/staff/${s.id}/edit');
                                            if (result == true) _loadStaff();
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              size: 20,
                                              color: AppColors.error),
                                          tooltip: 'Remove',
                                          onPressed: () => _deleteStaff(s.id),
                                        ),
                                      ],
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
