import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/passport_preset.dart';

class MultiPersonPhoto {
  final Uint8List photoBytes;
  final int copies;
  final String? name;
  final PassportPreset? preset;

  MultiPersonPhoto({
    required this.photoBytes,
    this.copies = 4,
    this.name,
    this.preset,
  });
}

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  /// Creates a printable A4 / 4x6" passport photo grid sheet with crop marks
  Future<Uint8List> createPassportPrintSheet({
    required Uint8List photoBytes,
    required PassportPreset preset,
    int copies = 8,
    bool isA4 = true,
  }) async {
    return createMultiPersonPassportPrintSheet(
      persons: [
        MultiPersonPhoto(photoBytes: photoBytes, copies: copies),
      ],
      preset: preset,
      isA4: isA4,
    );
  }

  /// Creates a printable passport photo sheet supporting multiple people with configurable copies each
  Future<Uint8List> createMultiPersonPassportPrintSheet({
    required List<MultiPersonPhoto> persons,
    required PassportPreset preset,
    bool isA4 = true,
  }) async {
    final pdf = pw.Document();

    const mmToPoints = 72.0 / 25.4;
    final sheetFormat = isA4 ? PdfPageFormat.a4 : const PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch);

    // Pre-create MemoryImages
    final List<pw.Widget> photoWidgets = [];
    for (final person in persons) {
      final activePreset = person.preset ?? preset;
      final pWidthPts = activePreset.widthMm * mmToPoints;
      final pHeightPts = activePreset.heightMm * mmToPoints;

      final imgWidget = pw.MemoryImage(person.photoBytes);
      for (int i = 0; i < person.copies; i++) {
        photoWidgets.add(
          pw.Container(
            width: pWidthPts,
            height: pHeightPts,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Image(imgWidget, fit: pw.BoxFit.cover),
          ),
        );
      }
    }

    // If no photos, return empty
    if (photoWidgets.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: sheetFormat,
          build: (context) => pw.Center(child: pw.Text('No photos selected')),
        ),
      );
      return pdf.save();
    }

    final int maxPhotosPerPage = isA4 ? 20 : 6;
    final int totalPages = (photoWidgets.length / maxPhotosPerPage).ceil();

    for (int pIndex = 0; pIndex < totalPages; pIndex++) {
      final startIndex = pIndex * maxPhotosPerPage;
      final endIndex = (startIndex + maxPhotosPerPage < photoWidgets.length)
          ? startIndex + maxPhotosPerPage
          : photoWidgets.length;
      final pageChunk = photoWidgets.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: sheetFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Header(
                  level: 1,
                  text: persons.length == 1
                      ? 'PageLab - ${preset.country} Passport Photos (${preset.widthMm.toInt()} x ${preset.heightMm.toInt()} mm)${totalPages > 1 ? " - Page ${pIndex + 1}/$totalPages" : ""}'
                      : 'PageLab - Combined Passport Photo Print Sheet (${persons.length} People, ${photoWidgets.length} Total Photos)${totalPages > 1 ? " - Page ${pIndex + 1}/$totalPages" : ""}',
                  textStyle: pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Wrap(
                  spacing: 10,
                  runSpacing: 14,
                  alignment: pw.WrapAlignment.center,
                  children: pageChunk,
                ),
                pw.Spacer(),
                pw.Text(
                  'Cut along grey borders. Print at 100% scale (Do not scale or fit to page) for exact dimensions.',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }
}
