import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/mask_result.dart';
import 'ai_mask_helper.dart';
import 'tflite_mask_helper.dart';

export '../models/mask_result.dart';

enum BgBlockTool { autoCut, markerErase, markerRestore }

class BgRemoverService {
  static final BgRemoverService _instance = BgRemoverService._internal();
  factory BgRemoverService() => _instance;
  BgRemoverService._internal();

  /// Generates initial background mask (0 = BG, 255 = Subject).
  /// - Web: uses client-side Google MediaPipe Selfie Segmentation.
  /// - Android/Native App: uses on-device TensorFlow Lite (TFLite) inference.
  /// - Fallback: multi-seed BFS flood fill algorithm.
  Future<MaskResult?> generateInitialMask({
    required Uint8List imageBytes,
    int tolerance = 35,
  }) async {
    // 1. On Web: Google MediaPipe AI
    if (kIsWeb) {
      try {
        final aiMask = await getWebAiMask(imageBytes);
        if (aiMask != null && aiMask.maskBytes.isNotEmpty) {
          debugPrint('MediaPipe AI Background Removal succeeded! (${aiMask.width}x${aiMask.height})');
          return aiMask;
        }
      } catch (e) {
        debugPrint('MediaPipe AI attempt exception, falling back to flood fill: $e');
      }
    } else {
      // 2. On Native App (Android/APK): On-Device TFLite AI
      try {
        final tfliteMask = await getNativeTfliteMask(imageBytes);
        if (tfliteMask != null && tfliteMask.maskBytes.isNotEmpty) {
          debugPrint('On-Device TFLite AI Background Removal succeeded! (${tfliteMask.width}x${tfliteMask.height})');
          return tfliteMask;
        }
      } catch (e) {
        debugPrint('TFLite AI attempt exception, falling back to flood fill: $e');
      }
    }

    // 3. High-precision Flood Fill fallback
    return await compute(_processInitialMask, {
      'bytes': imageBytes,
      'tolerance': tolerance,
    });
  }

  /// Updates mask with eraser brush (sets mask to 0) or restore brush (sets mask to 255)
  Future<Uint8List?> updateMaskWithBrush({
    required Uint8List maskBytes,
    required int width,
    required int height,
    required List<Offset> pixelPoints,
    required int radius,
    required bool isEraser,
  }) async {
    return await compute(_processBrushMask, {
      'maskBytes': maskBytes,
      'width': width,
      'height': height,
      'points': pixelPoints.map((p) => [p.dx, p.dy]).toList(),
      'radius': radius,
      'isEraser': isEraser,
    });
  }

  /// Renders final image by combining original photo, mask, and desired background color
  Future<Uint8List?> renderMaskedImage({
    required Uint8List originalImageBytes,
    required Uint8List maskBytes,
    required Color backgroundColor,
  }) async {
    return await compute(_processRenderMaskedImage, {
      'origBytes': originalImageBytes,
      'maskBytes': maskBytes,
      'r': (backgroundColor.r * 255.0).round().clamp(0, 255),
      'g': (backgroundColor.g * 255.0).round().clamp(0, 255),
      'b': (backgroundColor.b * 255.0).round().clamp(0, 255),
      'a': (backgroundColor.a * 255.0).round().clamp(0, 255),
      'isTransparent': backgroundColor == Colors.transparent,
    });
  }
}

/// Initial Mask Generator with multi-point edge sampling (Offline fallback)
MaskResult? _processInitialMask(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'];
  final int tolerance = params['tolerance'];

  final image = img.decodeImage(bytes);
  if (image == null) return null;

  final width = image.width;
  final height = image.height;
  final mask = Uint8List(width * height);
  mask.fillRange(0, mask.length, 255); // Default all pixels to Subject (255)

  // Collect seeds across all 4 borders
  int sumR = 0, sumG = 0, sumB = 0, count = 0;

  void sample(int x, int y) {
    final p = image.getPixel(x, y);
    sumR += p.r.toInt();
    sumG += p.g.toInt();
    sumB += p.b.toInt();
    count++;
  }

  final stepX = (width / 20).round().clamp(1, width);
  final stepY = (height / 20).round().clamp(1, height);

  for (int x = 0; x < width; x += stepX) {
    sample(x, 0);
    sample(x, height - 1);
  }
  for (int y = 0; y < height; y += stepY) {
    sample(0, y);
    sample(width - 1, y);
  }

  if (count == 0) return MaskResult(maskBytes: mask, width: width, height: height);

  final avgR = (sumR / count).round();
  final avgG = (sumG / count).round();
  final avgB = (sumB / count).round();

  final visited = List<bool>.filled(width * height, false);
  final Queue<int> queue = Queue<int>();

  void enqueue(int x, int y) {
    final idx = y * width + x;
    if (!visited[idx]) {
      visited[idx] = true;
      queue.add(idx);
    }
  }

  // Border seeds
  for (int x = 0; x < width; x++) {
    enqueue(x, 0);
    enqueue(x, height - 1);
  }
  for (int y = 0; y < height; y++) {
    enqueue(0, y);
    enqueue(width - 1, y);
  }

  while (queue.isNotEmpty) {
    final idx = queue.removeFirst();
    final x = idx % width;
    final y = idx ~/ width;

    final p = image.getPixel(x, y);
    final pr = p.r.toInt();
    final pg = p.g.toInt();
    final pb = p.b.toInt();

    // Human skin protection: do not mark skin as background
    final isSkin = pr > 60 && pg > 28 && pb > 15 && pr > pg && (pr - pg) > 6 && (pr - pb) > 6;
    if (isSkin) continue;

    final dr = (pr - avgR).abs();
    final dg = (pg - avgG).abs();
    final db = (pb - avgB).abs();
    final diff = (dr + dg + db) / 3;

    if (diff <= tolerance) {
      mask[idx] = 0; // Mark as Background

      if (x > 0) enqueue(x - 1, y);
      if (x < width - 1) enqueue(x + 1, y);
      if (y > 0) enqueue(x, y - 1);
      if (y < height - 1) enqueue(x, y + 1);
    }
  }

  return MaskResult(maskBytes: mask, width: width, height: height);
}

/// Mask Brush Updater (Sets mask to 0 for eraser, 255 for restore)
Uint8List? _processBrushMask(Map<String, dynamic> params) {
  final Uint8List maskBytes = params['maskBytes'];
  final int width = params['width'];
  final int height = params['height'];
  final List<dynamic> rawPoints = params['points'];
  final int radius = params['radius'];
  final bool isEraser = params['isEraser'];

  final outputMask = Uint8List.fromList(maskBytes);
  final rSq = radius * radius;
  final targetVal = isEraser ? 0 : 255;

  for (final rawP in rawPoints) {
    final int startX = (rawP[0] as double).round();
    final int startY = (rawP[1] as double).round();

    final minX = (startX - radius).clamp(0, width - 1);
    final maxX = (startX + radius).clamp(0, width - 1);
    final minY = (startY - radius).clamp(0, height - 1);
    final maxY = (startY + radius).clamp(0, height - 1);

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final dx = x - startX;
        final dy = y - startY;
        if (dx * dx + dy * dy <= rSq) {
          final idx = y * width + x;
          outputMask[idx] = targetVal;
        }
      }
    }
  }

  return outputMask;
}

/// Masked Image Renderer: Combines original photo, mask (0=BG, 255=Subject), and desired background color
Uint8List? _processRenderMaskedImage(Map<String, dynamic> params) {
  final Uint8List origBytes = params['origBytes'];
  final Uint8List maskBytes = params['maskBytes'];
  final int bgR = params['r'];
  final int bgG = params['g'];
  final int bgB = params['b'];
  final int bgA = params['a'];
  final bool isTransparent = params['isTransparent'];

  final image = img.decodeImage(origBytes);
  if (image == null) return null;

  final width = image.width;
  final height = image.height;
  final output = img.Image(width: width, height: height, numChannels: 4);

  for (int y = 0; y < height; y++) {
    final rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final idx = rowOffset + x;
      final maskVal = maskBytes[idx];

      if (maskVal == 0) {
        // Background Pixel -> Fill directly with desired studio color!
        if (isTransparent) {
          output.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          output.setPixelRgba(x, y, bgR, bgG, bgB, bgA);
        }
      } else {
        // Subject Pixel -> Keep original photo pixel!
        final p = image.getPixel(x, y);
        output.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt());
      }
    }
  }

  return Uint8List.fromList(img.encodePng(output));
}
