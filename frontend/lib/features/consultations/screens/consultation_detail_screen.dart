import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/status_badge.dart';
import '../models/consultation_model.dart';
import '../repository/consultation_repository.dart';

class ConsultationDetailScreen extends ConsumerStatefulWidget {
  final String consultationId;

  const ConsultationDetailScreen({super.key, required this.consultationId});

  @override
  ConsumerState<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState
    extends ConsumerState<ConsultationDetailScreen> {
  final _repo = ConsultationRepository();
  Consultation? _consultation;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await _repo.getDetail(int.parse(widget.consultationId));
      setState(() {
        _consultation = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final c = _consultation!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Consultation #${c.id}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              StatusBadge(status: c.status),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/consultations/${widget.consultationId}/edit'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _infoCard(c)),
                        const SizedBox(width: 16),
                        Expanded(child: _soapCard(c)),
                      ],
                    )
                  : Column(
                      children: [
                        _infoCard(c),
                        const SizedBox(height: 16),
                        _soapCard(c),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),

          // Related sections
          _sectionCard(
            'Prescriptions',
            Icons.medication_outlined,
            c.prescriptions,
            (item) => 'Prescription #${item['id']} - ${item['status'] ?? 'N/A'}',
          ),
          const SizedBox(height: 16),
          _sectionCard(
            'Lab Orders',
            Icons.science_outlined,
            c.labOrders,
            (item) => 'Lab Order #${item['id']} - ${item['status'] ?? 'N/A'}',
          ),
          const SizedBox(height: 16),
          _sectionCard(
            'Radiology Orders',
            Icons.image_outlined,
            c.radiologyOrders,
            (item) =>
                'Radiology Order #${item['id']} - ${item['status'] ?? 'N/A'}',
          ),
        ],
      ),
    );
  }

  Widget _infoCard(Consultation c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consultation Info',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Divider(height: 24),
            _row('Patient', c.patientName ?? 'ID: ${c.patientId}'),
            _row('Doctor', c.doctorName ?? 'ID: ${c.doctorId}'),
            _row('Appointment', c.appointmentId != null ? '#${c.appointmentId}' : '-'),
            _row('Date', c.createdAt?.split('T').first ?? '-'),
            _row('Status', c.status.replaceAll('_', ' ').toUpperCase()),
          ],
        ),
      ),
    );
  }

  Widget _soapCard(Consultation c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clinical Notes',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Divider(height: 24),
            _soapSection('Chief Complaint', c.chiefComplaint),
            _soapSection('History of Present Illness', c.historyOfPresentIllness),
            _soapSection('Examination', c.examination),
            _soapSection('Diagnosis', c.diagnosis),
            _soapSection('Treatment Plan', c.treatmentPlan),
            _soapSection('Notes', c.notes),
          ],
        ),
      ),
    );
  }

  Widget _soapSection(String title, String? content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            content?.isNotEmpty == true ? content! : 'Not recorded',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    String title,
    IconData icon,
    List<dynamic>? items,
    String Function(dynamic) labelBuilder,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
            const Divider(height: 24),
            if (items == null || items.isEmpty)
              Text('No records',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))
            else
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      labelBuilder(item),
                      style: const TextStyle(fontSize: 13),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
