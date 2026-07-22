import 'package:flutter/material.dart';
import 'hc_common.dart';

/// Care-note category metadata — mirrors the web categoryOptions.
class NoteCategory {
  final String value, label;
  final IconData icon;
  final Color color;
  const NoteCategory(this.value, this.label, this.icon, this.color);
}

const List<NoteCategory> noteCategories = [
  NoteCategory('diet', 'Diet', Icons.restaurant_rounded, hcGreen),
  NoteCategory('activity', 'Activity', Icons.directions_run_rounded, hcBlue),
  NoteCategory('observation', 'Observation', Icons.visibility_rounded, hcTeal),
  NoteCategory('vitals', 'Vitals', Icons.monitor_heart_rounded, hcRose),
  NoteCategory('incident', 'Incident', Icons.report_rounded, hcRed),
  NoteCategory('medication', 'Medication', Icons.medication_rounded, hcPurple),
];

NoteCategory noteCategoryMeta(String? value) {
  if (value == null) return const NoteCategory('', 'Note', Icons.note_alt_rounded, hcSlate);
  return noteCategories.firstWhere(
    (c) => c.value == value,
    orElse: () => NoteCategory(value, value, Icons.note_alt_rounded, hcSlate),
  );
}

/// Strip HTML/markdown to a single-line preview (mirrors web contentPreview).
String noteContentPreview(dynamic content, {int max = 160}) {
  if (content == null) return '';
  var s = content.toString();
  s = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
  s = s.replaceAll(RegExp(r'[`*_~>#\[\]()]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length > max) s = '${s.substring(0, max)}…';
  return s;
}

String formatFileSize(num? bytes) {
  if (bytes == null) return '';
  final units = ['B', 'KB', 'MB', 'GB'];
  var n = bytes.toDouble();
  var i = 0;
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024;
    i++;
  }
  return '${n.toStringAsFixed(n < 10 && i > 0 ? 1 : 0)} ${units[i]}';
}
