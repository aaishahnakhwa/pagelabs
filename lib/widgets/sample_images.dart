import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SampleImagesHelper {
  /// Generates a scenic mountain landscape image (similar to the mockup)
  static Uint8List getLandscapeSample() {
    const width = 1200;
    const height = 800;
    final image = img.Image(width: width, height: height);

    // Render sky gradient (deep blue to warm horizon)
    for (int y = 0; y < height; y++) {
      final t = y / height;
      final r = (30 + 190 * t).round().clamp(0, 255);
      final g = (110 + 120 * t).round().clamp(0, 255);
      final b = (200 - 30 * t).round().clamp(0, 255);
      for (int x = 0; x < width; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Render warm sun
    const sunCenterX = 300;
    const sunCenterY = 220;
    const sunRadius = 70;
    for (int y = sunCenterY - sunRadius; y <= sunCenterY + sunRadius; y++) {
      for (int x = sunCenterX - sunRadius; x <= sunCenterX + sunRadius; x++) {
        final dist = sqrt(pow(x - sunCenterX, 2) + pow(y - sunCenterY, 2));
        if (dist <= sunRadius) {
          final factor = (1.0 - (dist / sunRadius)).clamp(0.0, 1.0);
          final p = image.getPixel(x, y);
          final nr = (p.r + (255 - p.r) * factor).round().clamp(0, 255);
          final ng = (p.g + (230 - p.g) * factor).round().clamp(0, 255);
          final nb = (p.b + (140 - p.b) * factor).round().clamp(0, 255);
          image.setPixelRgb(x, y, nr, ng, nb);
        }
      }
    }

    // Draw back mountain ridges (slate blue/purple)
    for (int x = 0; x < width; x++) {
      final ridgeY = 360 +
          (80 * sin(x * 0.008) + 40 * sin(x * 0.02) + 20 * cos(x * 0.05)).round();
      for (int y = ridgeY; y < height; y++) {
        final factor = ((y - ridgeY) / (height - ridgeY)).clamp(0.0, 1.0);
        final r = (70 + 30 * factor).round();
        final g = (90 + 40 * factor).round();
        final b = (120 + 30 * factor).round();
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Draw foreground mountain ridges & evergreen pine hills (sage green/forest)
    for (int x = 0; x < width; x++) {
      final ridge2Y = 480 +
          (60 * sin((x + 200) * 0.009) + 30 * cos(x * 0.025)).round();
      for (int y = ridge2Y; y < height; y++) {
        final factor = ((y - ridge2Y) / (height - ridge2Y)).clamp(0.0, 1.0);
        final r = (45 + 20 * factor).round();
        final g = (85 + 25 * factor).round();
        final b = (65 + 15 * factor).round();
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Foreground lake reflection
    const waterLevel = 620;
    for (int y = waterLevel; y < height; y++) {
      final t = (y - waterLevel) / (height - waterLevel);
      for (int x = 0; x < width; x++) {
        final ripple = (sin(y * 0.3 + x * 0.05) * 8).round();
        final r = (40 + ripple).clamp(20, 100);
        final g = (90 + (t * 30).round() + ripple).clamp(50, 150);
        final b = (130 + (t * 20).round()).clamp(80, 180);
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  /// Generates a portrait photo sample for Passport Photo and HD enhancer
  static Uint8List getPortraitSample() {
    const width = 800;
    const height = 1000;
    final image = img.Image(width: width, height: height);

    // Warm studio backdrop
    for (int y = 0; y < height; y++) {
      final t = y / height;
      final r = (235 - 30 * t).round().clamp(0, 255);
      final g = (238 - 25 * t).round().clamp(0, 255);
      final b = (242 - 20 * t).round().clamp(0, 255);
      for (int x = 0; x < width; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Shoulders / dark navy suit
    const cx = 400;
    for (int y = 560; y < height; y++) {
      final span = 150 + (y - 560) * 1.6;
      for (int x = (cx - span).round(); x <= (cx + span).round(); x++) {
        if (x >= 0 && x < width) {
          // Navy suit texture
          final r = 35 + ((x + y) % 5);
          final g = 42 + ((x * y) % 4);
          final b = 60 + ((x - y) % 6);
          image.setPixelRgb(x, y, r, g, b);
        }
      }
    }

    // Collar / white shirt
    for (int y = 520; y < 620; y++) {
      final span = 60 - ((y - 520) * 0.4);
      for (int x = (cx - span).round(); x <= (cx + span).round(); x++) {
        if (x >= 0 && x < width) {
          image.setPixelRgb(x, y, 245, 247, 250);
        }
      }
    }

    // Neck
    for (int y = 440; y < 540; y++) {
      for (int x = cx - 55; x <= cx + 55; x++) {
        if (x >= 0 && x < width) {
          image.setPixelRgb(x, y, 225, 175, 145);
        }
      }
    }

    // Face oval
    const faceCy = 360;
    const radiusX = 130;
    const radiusY = 160;
    for (int y = faceCy - radiusY; y <= faceCy + radiusY; y++) {
      for (int x = cx - radiusX; x <= cx + radiusX; x++) {
        final nx = (x - cx) / radiusX;
        final ny = (y - faceCy) / radiusY;
        if (nx * nx + ny * ny <= 1.0) {
          // Soft skin tone shading
          final lightFactor = 1.0 - (nx * 0.15) - (ny * 0.1);
          final r = (238 * lightFactor).round().clamp(160, 255);
          final g = (195 * lightFactor).round().clamp(140, 240);
          final b = (168 * lightFactor).round().clamp(120, 215);
          image.setPixelRgb(x, y, r, g, b);
        }
      }
    }

    // Hair
    for (int y = faceCy - radiusY - 30; y < faceCy - 10; y++) {
      for (int x = cx - radiusX - 20; x <= cx + radiusX + 20; x++) {
        final nx = (x - cx) / (radiusX + 15);
        final ny = (y - (faceCy - 20)) / (radiusY + 15);
        if (nx * nx + ny * ny <= 1.0 && y < faceCy - 40) {
          image.setPixelRgb(x, y, 40, 32, 28);
        }
      }
    }

    // Eyes
    for (int offset in [-45, 45]) {
      final eyeX = cx + offset;
      const eyeY = 345;
      for (int dy = -6; dy <= 6; dy++) {
        for (int dx = -14; dx <= 14; dx++) {
          final dist = sqrt(dx * dx + (dy * dy * 4));
          if (dist < 12) {
            image.setPixelRgb(eyeX + dx, eyeY + dy, 250, 250, 250);
          }
        }
      }
      // Pupil
      for (int dy = -5; dy <= 5; dy++) {
        for (int dx = -5; dx <= 5; dx++) {
          if (dx * dx + dy * dy <= 20) {
            image.setPixelRgb(eyeX + dx, eyeY + dy, 45, 30, 20);
          }
        }
      }
      // Eyebrows
      for (int dx = -20; dx <= 20; dx++) {
        for (int dy = -3; dy <= 2; dy++) {
          image.setPixelRgb(eyeX + dx, eyeY - 20 + dy, 55, 40, 30);
        }
      }
    }

    // Nose
    for (int y = 350; y <= 400; y++) {
      final span = (y - 350) * 0.2;
      for (int x = (cx - span).round(); x <= (cx + span).round(); x++) {
        image.setPixelRgb(x, y, 220, 175, 145);
      }
    }

    // Smile / lips
    for (int y = 430; y <= 444; y++) {
      final span = 35 - ((y - 437).abs() * 3);
      for (int x = (cx - span).round(); x <= (cx + span).round(); x++) {
        image.setPixelRgb(x, y, 200, 110, 110);
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  /// Generates a multi-page sample PDF document for testing PDF tools & compression
  static Future<Uint8List> getSamplePdfDocument() async {
    final pdf = pw.Document();

    for (int i = 1; i <= 3; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PageLab Sample Report',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.Text('Page $i of 3', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.deepOrange400),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Section $i: High Resolution Document Processing',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'PageLab offers enterprise-grade document and image utilities running 100% offline. '
                  'Your data never leaves your device. Test image to PDF conversion, multi-page extraction, '
                  'smart compression, and passport photo generation.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 2),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  height: 180,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange200),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Sample Chart / Figure #$i',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange800),
                    ),
                  ),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Confidential - PageLab Utility Suite', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                    pw.Text('Date: October 2026', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                  ],
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
