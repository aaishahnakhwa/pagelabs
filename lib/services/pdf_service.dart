import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import '../models/passport_preset.dart';
import '../models/placed_signature_item.dart';

enum PageMarginSetting { none, small, medium, large }
enum PdfCompressionLevel { low, medium, high }

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

  /// Converts multiple image bytes to a single PDF document
  Future<Uint8List> createPdfFromImages({
    required List<Uint8List> images,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    bool isLandscape = false,
    PageMarginSetting marginSetting = PageMarginSetting.none,
    int jpegQuality = 85,
    bool fitToImage = false,
  }) async {
    final pdf = pw.Document();

    double marginValue = 0.0;
    switch (marginSetting) {
      case PageMarginSetting.none:
        marginValue = 0.0;
        break;
      case PageMarginSetting.small:
        marginValue = 15.0;
        break;
      case PageMarginSetting.medium:
        marginValue = 30.0;
        break;
      case PageMarginSetting.large:
        marginValue = 50.0;
        break;
    }

    final targetFormat = isLandscape ? pageFormat.landscape : pageFormat.portrait;

    for (final imageBytes in images) {
      // Yield slightly to event loop to keep UI thread responsive
      await Future.delayed(const Duration(milliseconds: 10));

      // Optimize image if needed
      Uint8List processedBytes = imageBytes;
      if (jpegQuality < 100) {
        final decoded = img.decodeImage(imageBytes);
        if (decoded != null) {
          processedBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: jpegQuality));
        }
      }

      final image = pw.MemoryImage(processedBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: targetFormat,
          margin: pw.EdgeInsets.all(marginValue),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: marginValue == 0 && !fitToImage ? pw.BoxFit.cover : pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 10));
    return pdf.save();
  }

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

  /// Compresses a PDF by rasterizing and recompressing pages with balanced JPEG compression
  Future<Uint8List> compressPdf({
    required Uint8List pdfBytes,
    required PdfCompressionLevel level,
    void Function(double progress, String status)? onProgress,
  }) async {
    int targetQuality;
    double targetDpi;

    switch (level) {
      case PdfCompressionLevel.low:
        targetQuality = 80;
        targetDpi = 200.0;
        break;
      case PdfCompressionLevel.medium:
        targetQuality = 60;
        targetDpi = 130.0;
        break;
      case PdfCompressionLevel.high:
        targetQuality = 40;
        targetDpi = 90.0;
        break;
    }

    final compressedDoc = pw.Document();

    try {
      final rasterPages = Printing.raster(pdfBytes, dpi: targetDpi);
      int pageCount = 0;
      await for (final page in rasterPages) {
        pageCount++;
        if (onProgress != null) {
          onProgress(0.20 + (pageCount * 0.15).clamp(0.0, 0.65), 'Compressing page $pageCount...');
        }
        await Future.delayed(const Duration(milliseconds: 15));

        final pngBytes = await page.toPng();
        final decoded = img.decodeImage(pngBytes);
        if (decoded != null) {
          final compressedBytes = Uint8List.fromList(
            img.encodeJpg(decoded, quality: targetQuality),
          );
          final pwImage = pw.MemoryImage(compressedBytes);
          compressedDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
              margin: pw.EdgeInsets.zero,
              build: (pw.Context ctx) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(pwImage, fit: pw.BoxFit.cover),
              ),
            ),
          );
        }
      }

      if (onProgress != null) {
        onProgress(0.88, 'Finalizing compressed document...');
      }
      await Future.delayed(const Duration(milliseconds: 15));

      return await compressedDoc.save();
    } catch (e) {
      debugPrint('Error in PDF compression: $e');
      // If rasterizing fails, return original
      return pdfBytes;
    }
  }

  /// Extracts pages of a PDF as PNG / JPG image bytes
  Future<List<Uint8List>> pdfToImages({
    required Uint8List pdfBytes,
    List<int>? pageNumbers, // 1-indexed
    double dpi = 150.0,
    bool isJpg = true,
  }) async {
    final List<Uint8List> outputImages = [];

    final rasterPages = Printing.raster(
      pdfBytes,
      pages: pageNumbers?.map((p) => p - 1).toList(),
      dpi: dpi,
    );

    await for (final page in rasterPages) {
      final pngBytes = await page.toPng();
      if (isJpg) {
        final decoded = img.decodeImage(pngBytes);
        if (decoded != null) {
          outputImages.add(Uint8List.fromList(img.encodeJpg(decoded, quality: 92)));
        } else {
          outputImages.add(pngBytes);
        }
      } else {
        outputImages.add(pngBytes);
      }
    }

    return outputImages;
  }

  /// Generates a signed PDF document with placed signatures/stamps overlaid on pages
  Future<Uint8List> createSignedPdf({
    required List<Uint8List> pageImages,
    required List<PlacedSignatureItem> items,
    void Function(double progress, String status)? onProgress,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < pageImages.length; i++) {
      if (onProgress != null) {
        final pct = 0.20 + (0.65 * (i / pageImages.length));
        onProgress(pct, 'Compositing page ${i + 1} of ${pageImages.length}...');
      }
      await Future.delayed(const Duration(milliseconds: 20));

      final pageImg = pageImages[i];
      final decoded = img.decodeImage(pageImg);
      if (decoded == null) continue;

      final pageWidth = decoded.width.toDouble();
      final pageHeight = decoded.height.toDouble();
      final pageFormat = PdfPageFormat(pageWidth, pageHeight);

      final bgImage = pw.MemoryImage(pageImg);
      final pageItems = items.where((item) => item.pageIndex == i).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Image(bgImage, fit: pw.BoxFit.fill),
                ),
                for (final item in pageItems)
                  pw.Positioned(
                    left: item.normX * pageWidth,
                    top: item.normY * pageHeight,
                    child: pw.SizedBox(
                      width: item.normWidth * pageWidth,
                      height: item.normHeight * pageHeight,
                      child: pw.Image(
                        pw.MemoryImage(item.imageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    if (onProgress != null) {
      onProgress(0.90, 'Finalizing signed document...');
    }
    await Future.delayed(const Duration(milliseconds: 20));

    return await pdf.save();
  }
}
