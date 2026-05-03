import 'package:flutter/material.dart';

import '../theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final Color? overrideColor;

  const StatusBadge({
    super.key,
    required this.status,
    this.overrideColor,
  });

  Color get _color {
    if (overrideColor != null) return overrideColor!;
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'paid':
        return AppColors.success;
      case 'pending':
      case 'in_progress':
      case 'in progress':
      case 'processing':
        return AppColors.warning;
      case 'cancelled':
      case 'rejected':
      case 'failed':
      case 'overdue':
        return AppColors.error;
      case 'completed':
      case 'discharged':
      case 'dispensed':
        return AppColors.primary;
      case 'inactive':
      case 'draft':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
