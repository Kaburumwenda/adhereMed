import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/prescription_model.dart';

/// Fetches raw image bytes from a network URL (profile pics / signatures).
/// Returns null silently on any error.
Future<Uint8List?> fetchNetworkImageBytes(String url) async {
  try {
    final dio = Dio();
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.statusCode == 200 && response.data != null) {
      return Uint8List.fromList(response.data!);
    }
  } catch (_) {}
  return null;
}

/// Builds a styled prescription PDF and returns it as [Uint8List].
///
/// [leftLogoBytes] — doctor's profile photo (for independent doctors) or
/// the hospital logo. Pass `null` to fall back to `hos_default.png`.
///
/// [leftName] / [leftEmail] / [leftLocation] — clinic or doctor details shown
/// under the left logo. All are optional and omitted when empty.
///
/// The AdhereMed logo (`logo.png`) is always shown on the right with fixed
/// contact info (AdhereMed · info@adheremed.com · Kenya).
Future<Uint8List> buildPrescriptionPdf({
  required Prescription prescription,
  Uint8List? leftLogoBytes,
  String? leftName,
  String? leftEmail,
  String? leftLocation,
}) async {
  // ── Load asset images ────────────────────────────────────────────────────
  final adhereData = await rootBundle.load('assets/images/logo.png');
  final adhereBytes = adhereData.buffer.asUint8List();

  final defaultLogoData =
      await rootBundle.load('assets/images/hos_default.png');
  final defaultLogoBytes = defaultLogoData.buffer.asUint8List();

  final leftBytes = leftLogoBytes ?? defaultLogoBytes;

  // ── Fetch doctor signature if available ───────────────────────────────────
  Uint8List? signatureBytes;
  final sigUrl = prescription.doctorSignatureUrl;
  if (sigUrl != null && sigUrl.isNotEmpty) {
    signatureBytes = await fetchNetworkImageBytes(sigUrl);
  }

  // ── Color palette ─────────────────────────────────────────────────────────
  final cPrimary = PdfColor(26 / 255, 86 / 255, 219 / 255);
  final cLightBlue = PdfColor(235 / 255, 245 / 255, 1.0);
  final cTextDark = PdfColor(17 / 255, 24 / 255, 39 / 255);
  final cTextGrey = PdfColor(107 / 255, 114 / 255, 128 / 255);
  final cBorder = PdfColor(229 / 255, 231 / 255, 235 / 255);
  final cNoteYellow = PdfColor(254 / 255, 249 / 255, 195 / 255);
  final cNoteYellowBorder = PdfColor(252 / 255, 211 / 255, 77 / 255);

  // ── Local helper builders ─────────────────────────────────────────────────
  pw.Widget sectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(width: 3, height: 16, color: cPrimary),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: cPrimary,
          ),
        ),
      ],
    );
  }

  pw.Widget labelValue(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 9, color: cTextGrey)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: cTextDark,
            )),
      ],
    );
  }

  // ── Prepare data strings ──────────────────────────────────────────────────
  final p = prescription;
  final dateStr = p.createdAt != null
      ? DateFormat('dd MMM yyyy')
          .format(DateTime.tryParse(p.createdAt!) ?? DateTime.now())
      : DateFormat('dd MMM yyyy').format(DateTime.now());

  final leftImage = pw.MemoryImage(leftBytes);
  final rightImage = pw.MemoryImage(adhereBytes);
  final sigImage =
      signatureBytes != null ? pw.MemoryImage(signatureBytes) : null;

  // ── Build document ────────────────────────────────────────────────────────
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.ltr,
        margin: const pw.EdgeInsets.fromLTRB(32, 24, 32, 28),
      ),
      // ── Page header ───────────────────────────────────────────────────
      header: (_) => pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // ── Left: hospital / doctor logo + info ──────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.ClipRRect(
                    verticalRadius: 8,
                    horizontalRadius: 8,
                    child: pw.Image(leftImage,
                        width: 60, height: 60, fit: pw.BoxFit.contain),
                  ),
                  if ((leftName?.isNotEmpty == true) ||
                      (leftEmail?.isNotEmpty == true) ||
                      (leftLocation?.isNotEmpty == true)) ...
                    [
                      pw.SizedBox(width: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (leftName?.isNotEmpty == true)
                            pw.Text(
                              leftName!,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: cTextDark,
                              ),
                            ),
                          if (leftEmail?.isNotEmpty == true) ...
                            [
                              pw.SizedBox(height: 2),
                              pw.Text(
                                leftEmail!,
                                style: pw.TextStyle(
                                    fontSize: 8.5, color: cTextGrey),
                              ),
                            ],
                          if (leftLocation?.isNotEmpty == true) ...
                            [
                              pw.SizedBox(height: 2),
                              pw.Text(
                                leftLocation!,
                                style: pw.TextStyle(
                                    fontSize: 8.5, color: cTextGrey),
                              ),
                            ],
                        ],
                      ),
                    ],
                ],
              ),
              // ── Centre: title ─────────────────────────────────────────
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PRESCRIPTION',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: cPrimary,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'AdhereMed Healthcare Platform',
                    style: pw.TextStyle(fontSize: 9, color: cTextGrey),
                  ),
                ],
              ),
              // ── Right: AdhereMed logo + fixed info ────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'AdhereMed',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: cTextDark,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'info@adheremed.com',
                        style:
                            pw.TextStyle(fontSize: 8.5, color: cTextGrey),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Kenya',
                        style:
                            pw.TextStyle(fontSize: 8.5, color: cTextGrey),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 8),
                  pw.ClipRRect(
                    verticalRadius: 8,
                    horizontalRadius: 8,
                    child: pw.Image(rightImage,
                        width: 60, height: 60, fit: pw.BoxFit.contain),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: cBorder, thickness: 1.5),
          pw.SizedBox(height: 6),
        ],
      ),
      // ── Page footer ───────────────────────────────────────────────────
      footer: (pw.Context ctx) => pw.Column(
        children: [
          pw.Divider(color: cBorder),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by AdhereMed · '
                '${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 8, color: cTextGrey),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: cTextGrey),
              ),
            ],
          ),
        ],
      ),
      // ── Body ──────────────────────────────────────────────────────────
      build: (_) => [
        // Rx reference bar
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: pw.BoxDecoration(
            color: cLightBlue,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              labelValue('Prescription #', '${p.id}'),
              pw.SizedBox(width: 32),
              labelValue('Date', dateStr),
              pw.SizedBox(width: 32),
              labelValue(
                  'Status',
                  p.status.substring(0, 1).toUpperCase() +
                      p.status.substring(1)),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // ── Patient info ─────────────────────────────────────────────────
        sectionTitle('Patient Information'),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: cBorder),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Contact row ────────────────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: labelValue('Name', p.patientName ?? '—')),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                      child: labelValue(
                          'National ID',
                          (p.patientNationalId?.isNotEmpty == true)
                              ? p.patientNationalId!
                              : '—')),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                      child: labelValue(
                          'Phone',
                          (p.patientPhone?.isNotEmpty == true)
                              ? p.patientPhone!
                              : '—')),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                      child: labelValue(
                          'Email',
                          (p.patientEmail?.isNotEmpty == true)
                              ? p.patientEmail!
                              : '—')),
                ],
              ),
              // ── Medical info ────────────────────────────────────────────
              pw.SizedBox(height: 10),
              pw.Divider(color: cBorder, thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Allergies
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Allergies',
                            style:
                                pw.TextStyle(fontSize: 9, color: cTextGrey)),
                        pw.SizedBox(height: 4),
                        if (p.patientAllergies.isEmpty)
                          pw.Text('None',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  color: cTextGrey,
                                  fontStyle: pw.FontStyle.italic))
                        else
                          pw.Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: p.patientAllergies
                                .map((a) => pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: pw.BoxDecoration(
                                        color: PdfColor(
                                            254 / 255, 226 / 255, 226 / 255),
                                        borderRadius:
                                            pw.BorderRadius.circular(4),
                                        border: pw.Border.all(
                                            color: PdfColor(
                                                252 / 255,
                                                165 / 255,
                                                165 / 255)),
                                      ),
                                      child: pw.Text(a,
                                          style: pw.TextStyle(
                                              fontSize: 9,
                                              color: PdfColor(
                                                  185 / 255,
                                                  28 / 255,
                                                  28 / 255),
                                              fontWeight:
                                                  pw.FontWeight.bold)),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Chronic conditions
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Chronic Conditions',
                            style:
                                pw.TextStyle(fontSize: 9, color: cTextGrey)),
                        pw.SizedBox(height: 4),
                        if (p.patientChronicConditions.isEmpty)
                          pw.Text('None',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  color: cTextGrey,
                                  fontStyle: pw.FontStyle.italic))
                        else
                          pw.Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: p.patientChronicConditions
                                .map((c) => pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: pw.BoxDecoration(
                                        color: PdfColor(
                                            254 / 255, 243 / 255, 199 / 255),
                                        borderRadius:
                                            pw.BorderRadius.circular(4),
                                        border: pw.Border.all(
                                            color: PdfColor(
                                                253 / 255,
                                                211 / 255,
                                                77 / 255)),
                                      ),
                                      child: pw.Text(c,
                                          style: pw.TextStyle(
                                              fontSize: 9,
                                              color: PdfColor(
                                                  146 / 255,
                                                  64 / 255,
                                                  14 / 255),
                                              fontWeight:
                                                  pw.FontWeight.bold)),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // ── Insurance row ────────────────────────────────────────────
              if ((p.patientInsuranceProvider?.isNotEmpty == true) ||
                  (p.patientInsuranceNumber?.isNotEmpty == true)) ...[
                pw.SizedBox(height: 10),
                pw.Divider(color: cBorder, thickness: 0.5),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Expanded(
                        child: labelValue(
                            'Insurance Provider',
                            (p.patientInsuranceProvider?.isNotEmpty == true)
                                ? p.patientInsuranceProvider!
                                : '—')),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                        child: labelValue(
                            'Policy Number',
                            (p.patientInsuranceNumber?.isNotEmpty == true)
                                ? p.patientInsuranceNumber!
                                : '—')),
                    pw.Expanded(child: pw.SizedBox()),
                    pw.Expanded(child: pw.SizedBox()),
                  ],
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // ── Doctor info ───────────────────────────────────────────────────
        sectionTitle('Prescribing Doctor'),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: cBorder),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                  child: labelValue('Name', p.doctorName ?? '—')),
              pw.SizedBox(width: 16),
              pw.Expanded(
                  child: labelValue(
                      'License No.',
                      (p.doctorLicenseNumber?.isNotEmpty == true)
                          ? p.doctorLicenseNumber!
                          : '—')),
              pw.SizedBox(width: 16),
              pw.Expanded(
                  child: labelValue(
                      'Practice Type',
                      (p.doctorPracticeType?.isNotEmpty == true)
                          ? p.doctorPracticeType!
                          : '—')),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // ── Medications ───────────────────────────────────────────────────
        sectionTitle('Prescribed Medications (${p.items.length})'),
        pw.SizedBox(height: 10),
        ...p.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: cBorder),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Medication header row
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: cLightBlue,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(8),
                      topRight: pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 22,
                        height: 22,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: cPrimary,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '${idx + 1}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        item.medicationName,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: cTextDark,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        '— ${item.dosage}',
                        style: pw.TextStyle(
                            fontSize: 12, color: cTextGrey),
                      ),
                    ],
                  ),
                ),
                // Medication detail grid
                pw.Padding(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Wrap(
                    spacing: 32,
                    runSpacing: 10,
                    children: [
                      labelValue('Dosage', item.dosage),
                      labelValue('Frequency', item.frequency),
                      labelValue('Duration', item.duration),
                      labelValue('Quantity', '${item.quantity}'),
                      if (item.refills > 0)
                        labelValue('Refills', '${item.refills}'),
                      if (item.schedule?.isNotEmpty == true)
                        labelValue('Schedule', item.schedule!),
                      if (item.instructions?.isNotEmpty == true)
                        labelValue('Instructions', item.instructions!),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        // ── Clinical notes ────────────────────────────────────────────────
        if ((p.notes ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 6),
          sectionTitle('Clinical Notes'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: cNoteYellow,
              border: pw.Border.all(color: cNoteYellowBorder),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              p.notes!,
              style: pw.TextStyle(
                  fontSize: 12, color: cTextDark, lineSpacing: 4),
            ),
          ),
          pw.SizedBox(height: 10),
        ],

        // ── Signature block ───────────────────────────────────────────────
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (sigImage != null)
                  pw.Container(
                    width: 180,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: cBorder),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child:
                        pw.Image(sigImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 52),
                pw.Container(
                  width: 180,
                  child: pw.Divider(color: cTextDark, thickness: 0.5),
                ),
                pw.Text(
                  p.doctorName ?? 'Doctor',
                  style: pw.TextStyle(fontSize: 10, color: cTextGrey),
                ),
                if (p.doctorLicenseNumber?.isNotEmpty == true)
                  pw.Text(
                    'License: ${p.doctorLicenseNumber}',
                    style: pw.TextStyle(fontSize: 9, color: cTextGrey),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}
