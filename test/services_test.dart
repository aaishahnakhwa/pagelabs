import 'package:flutter_test/flutter_test.dart';
import 'package:pagelab/services/image_service.dart';
import 'package:pagelab/services/pdf_service.dart';
import 'package:pagelab/models/passport_preset.dart';
import 'package:pagelab/widgets/sample_images.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SampleImagesHelper Tests', () {
    test('Landscape sample is valid and decodable', () {
      final bytes = SampleImagesHelper.getLandscapeSample();
      expect(bytes, isNotEmpty);
      final decoded = ImageService().decode(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(1200));
      expect(decoded.height, equals(800));
    });

    test('Portrait sample is valid and decodable', () {
      final bytes = SampleImagesHelper.getPortraitSample();
      expect(bytes, isNotEmpty);
      final decoded = ImageService().decode(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(800));
      expect(decoded.height, equals(1000));
    });

    test('Sample PDF document generates valid bytes', () async {
      final pdfBytes = await SampleImagesHelper.getSamplePdfDocument();
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });

  group('ImageService Operations', () {
    late img.Image testImage;

    setUp(() {
      final bytes = SampleImagesHelper.getLandscapeSample();
      testImage = ImageService().decode(bytes)!;
    });

    test('cropImage crops to target dimensions correctly', () {
      final cropped = ImageService().cropImage(
        src: testImage,
        x: 100,
        y: 100,
        width: 400,
        height: 300,
      );
      expect(cropped.width, equals(400));
      expect(cropped.height, equals(300));
    });

    test('resizeImage resizes with custom dimensions', () {
      final resized = ImageService().resizeImage(
        src: testImage,
        width: 600,
        height: 400,
        maintainAspect: false,
      );
      expect(resized.width, equals(600));
      expect(resized.height, equals(400));
    });

    test('resizeByPercentage scales proportionally', () {
      final scaled = ImageService().resizeByPercentage(
        src: testImage,
        percentage: 0.5,
      );
      expect(scaled.width, equals(600));
      expect(scaled.height, equals(400));
    });

    test('rotateImage rotates 90 degrees', () {
      final rotated = ImageService().rotateImage(testImage, 90);
      expect(rotated.width, equals(testImage.height));
      expect(rotated.height, equals(testImage.width));
    });

    test('flipImage flips horizontally and vertically', () {
      final flippedH = ImageService().flipImage(testImage, horizontal: true);
      expect(flippedH.width, equals(testImage.width));
      expect(flippedH.height, equals(testImage.height));
    });

    test('enhanceImage executes Standard, HD and Ultra HD levels', () {
      final standard = ImageService().enhanceImage(testImage, EnhancementLevel.standard);
      expect(standard, isNotNull);

      final hd = ImageService().enhanceImage(testImage, EnhancementLevel.hd);
      expect(hd, isNotNull);

      final ultraHd = ImageService().enhanceImage(testImage, EnhancementLevel.ultraHd);
      expect(ultraHd, isNotNull);
    });

    test('processPassportPhoto crops to exact country aspect ratio', () {
      final portraitBytes = SampleImagesHelper.getPortraitSample();
      final portrait = ImageService().decode(portraitBytes)!;

      final indiaPreset = PassportPreset.presets.firstWhere((p) => p.country == 'India');
      final passportPhoto = ImageService().processPassportPhoto(
        src: portrait,
        targetAspectRatio: indiaPreset.aspectRatio,
        autoEnhance: true,
      );

      final currentAspect = passportPhoto.width / passportPhoto.height;
      expect((currentAspect - indiaPreset.aspectRatio).abs(), lessThan(0.02));
    });

    test('removeBackground removes backdrop and produces clean output', () {
      final portraitBytes = SampleImagesHelper.getPortraitSample();
      final portrait = ImageService().decode(portraitBytes)!;

      // 1. Transparent PNG background removal
      final noBg = ImageService().removeBackground(
        src: portrait,
        tolerance: 40.0,
        targetBgColor: 0x00000000,
      );
      expect(noBg.width, equals(portrait.width));
      expect(noBg.height, equals(portrait.height));
      expect(noBg.hasAlpha, isTrue);

      // Top corner should have zero alpha (transparent background)
      final cornerPixel = noBg.getPixel(2, 2);
      expect(cornerPixel.a, equals(0));

      // Center face region should be opaque
      final facePixel = noBg.getPixel(400, 360);
      expect(facePixel.a, equals(255));

      // 2. White background replacement
      final whiteBg = ImageService().removeBackground(
        src: portrait,
        tolerance: 40.0,
        targetBgColor: 0xFFFFFFFF,
      );
      final whiteCorner = whiteBg.getPixel(2, 2);
      expect(whiteCorner.r, equals(255));
      expect(whiteCorner.g, equals(255));
      expect(whiteCorner.b, equals(255));
    });

    test('encode outputs JPG, PNG and WebP bytes', () {
      final jpgBytes = ImageService().encode(testImage, format: ImageOutputFormat.jpg);
      expect(jpgBytes, isNotEmpty);

      final pngBytes = ImageService().encode(testImage, format: ImageOutputFormat.png);
      expect(pngBytes, isNotEmpty);
    });
  });

  group('PdfService Operations', () {
    test('createPdfFromImages creates a valid multi-page PDF', () async {
      final img1 = SampleImagesHelper.getLandscapeSample();
      final img2 = SampleImagesHelper.getPortraitSample();

      final pdfBytes = await PdfService().createPdfFromImages(
        images: [img1, img2],
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(2000));
    });

    test('createPassportPrintSheet creates print-ready multi-copy A4 sheet', () async {
      final portraitBytes = SampleImagesHelper.getPortraitSample();
      final preset = PassportPreset.presets.first;

      final sheetPdf = await PdfService().createPassportPrintSheet(
        photoBytes: portraitBytes,
        preset: preset,
        copies: 8,
        isA4: true,
      );

      expect(sheetPdf, isNotEmpty);
      expect(sheetPdf.length, greaterThan(2000));
    });
  });
}
