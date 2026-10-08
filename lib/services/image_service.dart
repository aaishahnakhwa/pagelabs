import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum ImageOutputFormat { jpg, png, webp }

enum EnhancementLevel { standard, hd, ultraHd }

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  /// Decodes raw image bytes into an img.Image
  img.Image? decode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (e) {
      debugPrint('Error decoding image: $e');
      return null;
    }
  }

  /// Encodes an img.Image into target format bytes
  Uint8List encode(img.Image image, {
    ImageOutputFormat format = ImageOutputFormat.jpg,
    int quality = 90,
  }) {
    switch (format) {
      case ImageOutputFormat.jpg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ImageOutputFormat.png:
        return Uint8List.fromList(img.encodePng(image));
      case ImageOutputFormat.webp:
        try {
          // Fallback to jpg/png if webp encoder isn't available or fails
          return Uint8List.fromList(img.encodeJpg(image, quality: quality));
        } catch (_) {
          return Uint8List.fromList(img.encodeJpg(image, quality: quality));
        }
    }
  }

  /// Compresses image to fit under target size in Kilobytes (e.g. 20 KB, 50 KB, 100 KB)
  /// Uses binary search on JPEG/WebP quality stepping and progressive scaling if necessary.
  Uint8List compressToTargetSize(
    img.Image src, {
    required int targetKb,
    ImageOutputFormat format = ImageOutputFormat.jpg,
  }) {
    final int targetBytes = targetKb * 1024;
    img.Image working = img.Image.from(src);

    int minQuality = 5;
    int maxQuality = 95;
    Uint8List? bestBytes;

    for (int iter = 0; iter < 7; iter++) {
      final midQuality = ((minQuality + maxQuality) / 2).round();
      final bytes = encode(working, format: format, quality: midQuality);
      if (bytes.length <= targetBytes) {
        bestBytes = bytes;
        minQuality = midQuality + 1;
      } else {
        maxQuality = midQuality - 1;
      }
    }

    if (bestBytes != null && bestBytes.length <= targetBytes) {
      return bestBytes;
    }

    // If still over target, downscale resolution progressively
    while (working.width > 120 && working.height > 120) {
      working = img.copyResize(
        working,
        width: (working.width * 0.85).round(),
        height: (working.height * 0.85).round(),
        interpolation: img.Interpolation.linear,
      );
      final bytes = encode(working, format: format, quality: 60);
      if (bytes.length <= targetBytes) {
        return bytes;
      }
    }

    return encode(working, format: format, quality: 25);
  }

  /// Crops an image with bounding coordinates
  img.Image cropImage({
    required img.Image src,
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    final clampedX = x.clamp(0, src.width - 1);
    final clampedY = y.clamp(0, src.height - 1);
    final clampedW = width.clamp(1, src.width - clampedX);
    final clampedH = height.clamp(1, src.height - clampedY);

    return img.copyCrop(
      src,
      x: clampedX,
      y: clampedY,
      width: clampedW,
      height: clampedH,
    );
  }

  /// Resizes image with custom width and height
  img.Image resizeImage({
    required img.Image src,
    required int width,
    required int height,
    bool maintainAspect = true,
  }) {
    if (maintainAspect) {
      final double aspect = src.width / src.height;
      if (width / height > aspect) {
        return img.copyResize(src, height: height, interpolation: img.Interpolation.cubic);
      } else {
        return img.copyResize(src, width: width, interpolation: img.Interpolation.cubic);
      }
    } else {
      return img.copyResize(
        src,
        width: width,
        height: height,
        interpolation: img.Interpolation.cubic,
      );
    }
  }

  /// Resizes image by a percentage (e.g. 50% = 0.5)
  img.Image resizeByPercentage({
    required img.Image src,
    required double percentage,
  }) {
    final newW = (src.width * percentage).round().clamp(10, 10000);
    final newH = (src.height * percentage).round().clamp(10, 10000);
    return img.copyResize(
      src,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Rotates image in multiples of 90 degrees
  img.Image rotateImage(img.Image src, num angle) {
    return img.copyRotate(src, angle: angle);
  }

  /// Flips image horizontally or vertically
  img.Image flipImage(img.Image src, {required bool horizontal}) {
    if (horizontal) {
      return img.flipHorizontal(src);
    } else {
      return img.flipVertical(src);
    }
  }

  /// HD Quality Enhancement with multi-level processing
  img.Image enhanceImage(img.Image src, EnhancementLevel level) {
    img.Image working = img.Image.from(src);

    switch (level) {
      case EnhancementLevel.standard:
        // Mild contrast and subtle clarity
        working = img.adjustColor(
          working,
          contrast: 1.08,
          saturation: 1.05,
          brightness: 1.02,
        );
        break;

      case EnhancementLevel.hd:
        // Noticeable sharpness boost and tone curve balancing
        working = img.adjustColor(
          working,
          contrast: 1.16,
          saturation: 1.10,
          brightness: 1.04,
        );
        // Unsharp mask approximation using convolution
        working = _sharpen(working, amount: 0.7);
        break;

      case EnhancementLevel.ultraHd:
        // Upscale if under 2000px, deep sharpening and vibrant clarity
        if (working.width < 1800) {
          working = img.copyResize(
            working,
            width: (working.width * 1.5).round(),
            interpolation: img.Interpolation.cubic,
          );
        }
        working = img.adjustColor(
          working,
          contrast: 1.22,
          saturation: 1.15,
          brightness: 1.05,
        );
        working = _sharpen(working, amount: 1.2);
        break;
    }

    return working;
  }

  img.Image _sharpen(img.Image src, {required double amount}) {
    // 3x3 sharpening kernel
    final center = 1.0 + (4.0 * amount);
    final edge = -amount;
    final kernel = [
      0.0, edge, 0.0,
      edge, center, edge,
      0.0, edge, 0.0,
    ];
    return img.convolution(src, filter: kernel, div: 1.0);
  }

  /// Passport photo preparation:
  /// Crops to desired aspect ratio, applies optional auto-enhancement and background removal/replacement
  img.Image processPassportPhoto({
    required img.Image src,
    required double targetAspectRatio,
    required bool autoEnhance,
    int? backgroundColorHex, // e.g. 0xFFFFFFFF for white, 0x00000000 for transparent
    bool removeBackground = false,
    double bgTolerance = 42.0,
    int bgFeather = 2,
    bool isFastPreview = false,
    double panX = 0.0,
    double panY = 0.0,
    double zoom = 1.0,
  }) {
    // 1. Center crop to target aspect ratio (width / height) with pan & zoom support
    final double srcAspect = src.width / src.height;
    double baseCropW;
    double baseCropH;
    double baseCenterX;
    double baseCenterY;

    if (srcAspect > targetAspectRatio) {
      // Source is wider than target -> trim sides
      baseCropH = src.height.toDouble();
      baseCropW = src.height * targetAspectRatio;
      baseCenterX = src.width / 2.0;
      baseCenterY = src.height / 2.0;
    } else {
      // Source is taller than target -> trim top/bottom with bias towards top (face is centered)
      baseCropW = src.width.toDouble();
      baseCropH = src.width / targetAspectRatio;
      baseCenterX = src.width / 2.0;
      // Keep slightly closer to top for face framing (0.35 bias)
      baseCenterY = (src.height - baseCropH) * 0.35 + (baseCropH / 2.0);
    }

    final double clampedZoom = zoom.clamp(1.0, 4.0);
    final double cropW = baseCropW / clampedZoom;
    final double cropH = baseCropH / clampedZoom;

    // Pan offset is normalized relative to base crop size
    // Positive panX in UI moves image right -> crop window moves left on source image
    // Positive panY in UI moves image down -> crop window moves up on source image
    final double centerX = baseCenterX - (panX * baseCropW);
    final double centerY = baseCenterY - (panY * baseCropH);

    final int maxCropW = cropW.round().clamp(1, src.width);
    final int maxCropH = cropH.round().clamp(1, src.height);

    final int cropX = (centerX - maxCropW / 2.0).round().clamp(0, src.width - maxCropW);
    final int cropY = (centerY - maxCropH / 2.0).round().clamp(0, src.height - maxCropH);

    img.Image result = cropImage(
      src: src,
      x: cropX,
      y: cropY,
      width: maxCropW,
      height: maxCropH,
    );

    // Standardize resolution: 360 px for instant non-blocking UI preview, 600 px for print-ready save
    final targetW = isFastPreview ? 360 : 600;
    final targetH = (targetW / targetAspectRatio).round();
    result = img.copyResize(
      result,
      width: targetW,
      height: targetH,
      interpolation: isFastPreview ? img.Interpolation.linear : img.Interpolation.cubic,
    );

    // 2. Background removal / replacement if requested
    if (removeBackground || backgroundColorHex != null) {
      result = this.removeBackground(
        src: result,
        tolerance: bgTolerance,
        targetBgColor: backgroundColorHex,
        feather: bgFeather,
      );
    }

    // 3. Auto enhance (document clarity, contrast, skin tone balance)
    if (autoEnhance) {
      result = img.adjustColor(
        result,
        contrast: 1.12,
        brightness: 1.04,
        saturation: 1.06,
      );
      result = _sharpen(result, amount: 0.4);
    }

    return result;
  }

  /// High-performance offline portrait background removal & replacement
  /// Identifies background regions connected to the outer boundary using zero-allocation BFS,
  /// protects face/skin tones, applies edge-only contour feathering, and composites with target color or transparency.
  img.Image removeBackground({
    required img.Image src,
    double tolerance = 42.0,
    int? targetBgColor, // null or 0x00000000 for transparent PNG, or 0xFFFFFFFF, 0xFFD0E8F2, etc.
    int feather = 2,
  }) {
    final w = src.width;
    final h = src.height;

    // 1. Collect background color seeds from top border and upper corners
    int sampleR = 0, sampleG = 0, sampleB = 0, sampleCount = 0;

    // Top border sampling
    final stepX = math.max(1, (w / 30).round());
    final sampleY = math.min(8, (h * 0.03).round());
    for (int x = 0; x < w; x += stepX) {
      final p1 = src.getPixel(x, 1);
      final p2 = src.getPixel(x, sampleY);
      sampleR += p1.r.toInt() + p2.r.toInt();
      sampleG += p1.g.toInt() + p2.g.toInt();
      sampleB += p1.b.toInt() + p2.b.toInt();
      sampleCount += 2;
    }

    // Upper sides
    final stepY = math.max(1, (h / 25).round());
    final sideYLimit = (h * 0.35).round();
    for (int y = 5; y < sideYLimit; y += stepY) {
      final pL = src.getPixel(1, y);
      final pR = src.getPixel(w - 2, y);
      sampleR += pL.r.toInt() + pR.r.toInt();
      sampleG += pL.g.toInt() + pR.g.toInt();
      sampleB += pL.b.toInt() + pR.b.toInt();
      sampleCount += 2;
    }

    if (sampleCount == 0) return src;
    final avgR = sampleR / sampleCount;
    final avgG = sampleG / sampleCount;
    final avgB = sampleB / sampleCount;

    // 2. Zero-allocation BFS flood-fill from boundary pixels
    final mask = Uint8List(w * h);
    mask.fillRange(0, mask.length, 255); // 255 = subject, 0 = background

    final queue = Int32List(w * h);
    int head = 0;
    int tail = 0;

    void enqueue(int x, int y) {
      final idx = y * w + x;
      if (mask[idx] == 0) return;
      mask[idx] = 0;
      queue[tail++] = idx;
    }

    // Initialize boundary seeds
    for (int x = 0; x < w; x++) {
      enqueue(x, 0);
    }
    final sideLimit = (h * 0.45).round();
    for (int y = 1; y < sideLimit; y++) {
      enqueue(0, y);
      enqueue(w - 1, y);
    }

    final tolSq = tolerance * tolerance;

    while (head < tail) {
      final currIdx = queue[head++];
      final cx = currIdx % w;
      final cy = currIdx ~/ w;
      final cp = src.getPixel(cx, cy);
      final cr = cp.r.toInt();
      final cg = cp.g.toInt();
      final cb = cp.b.toInt();

      void visitNeighbor(int nx, int ny) {
        final nIdx = ny * w + nx;
        if (mask[nIdx] == 0) return;

        final np = src.getPixel(nx, ny);
        final nr = np.r.toInt();
        final ng = np.g.toInt();
        final nb = np.b.toInt();

        // 1. Skin Protection: NEVER remove human skin tone (face, chin, neck, chest) as background!
        final isSkin = nr > 60 && ng > 28 && nb > 15 && nr > ng && (nr - ng) > 6 && (nr - nb) > 6;
        if (isSkin) return;

        // 2. Allow top background text / patterns (top 25% of image) to be erased
        final isTopBackground = ny < h * 0.25;

        // Color distance to average seed
        final dr = nr - avgR;
        final dg = ng - avgG;
        final db = nb - avgB;
        final dSeedSq = dr * dr + dg * dg + db * db;

        // Local step distance from current pixel
        final ldr = nr - cr;
        final ldg = ng - cg;
        final ldb = nb - cb;
        final dLocalSq = ldr * ldr + ldg * ldg + ldb * ldb;

        if (!isTopBackground && dLocalSq > 45 * 45) return;

        if (dSeedSq <= tolSq || isTopBackground || (dLocalSq <= 24 * 24 && dSeedSq <= tolSq * 1.85)) {
          mask[nIdx] = 0;
          queue[tail++] = nIdx;
        }
      }

      if (cx > 0) visitNeighbor(cx - 1, cy);
      if (cx < w - 1) visitNeighbor(cx + 1, cy);
      if (cy > 0) visitNeighbor(cx, cy - 1);
      if (cy < h - 1) visitNeighbor(cx, cy + 1);
    }

    // 3. Fast Edge-Only Contour Feathering
    final alphaMap = Float32List(w * h);
    final fRadius = feather.clamp(0, 4);

    if (fRadius == 0) {
      for (int i = 0; i < mask.length; i++) {
        alphaMap[i] = mask[i] == 0 ? 0.0 : 1.0;
      }
    } else {
      final windowSize = (2 * fRadius + 1) * (2 * fRadius + 1);
      for (int y = 0; y < h; y++) {
        final rowOffset = y * w;
        for (int x = 0; x < w; x++) {
          final idx = rowOffset + x;
          final m = mask[idx];

          // Check if pixel is on the contour border (has differing neighbor)
          bool isBorder = false;
          if (x > 0 && mask[idx - 1] != m) {
            isBorder = true;
          } else if (x < w - 1 && mask[idx + 1] != m) {
            isBorder = true;
          } else if (y > 0 && mask[idx - w] != m) {
            isBorder = true;
          } else if (y < h - 1 && mask[idx + w] != m) {
            isBorder = true;
          }

          if (!isBorder) {
            alphaMap[idx] = m == 0 ? 0.0 : 1.0;
            continue;
          }

          int sum = 0;
          for (int dy = -fRadius; dy <= fRadius; dy++) {
            final wy = (y + dy).clamp(0, h - 1);
            final wOffset = wy * w;
            for (int dx = -fRadius; dx <= fRadius; dx++) {
              final wx = (x + dx).clamp(0, w - 1);
              sum += mask[wOffset + wx];
            }
          }
          alphaMap[idx] = (sum / (255.0 * windowSize)).clamp(0.0, 1.0);
        }
      }
    }

    // 4. Composite output image
    final isTransparent = targetBgColor == null || targetBgColor == 0x00000000;
    final bgR = !isTransparent ? ((targetBgColor >> 16) & 0xFF) : 0;
    final bgG = !isTransparent ? ((targetBgColor >> 8) & 0xFF) : 0;
    final bgB = !isTransparent ? (targetBgColor & 0xFF) : 0;

    final output = img.Image(width: w, height: h, numChannels: 4);

    for (int y = 0; y < h; y++) {
      final rowOffset = y * w;
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        final a = alphaMap[rowOffset + x];

        if (isTransparent) {
          final outA = (a * 255).round().clamp(0, 255);
          output.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), outA);
        } else {
          final outR = (a * p.r + (1 - a) * bgR).round().clamp(0, 255);
          final outG = (a * p.g + (1 - a) * bgG).round().clamp(0, 255);
          final outB = (a * p.b + (1 - a) * bgB).round().clamp(0, 255);
          output.setPixelRgba(x, y, outR, outG, outB, 255);
        }
      }
    }

    return output;
  }
}
