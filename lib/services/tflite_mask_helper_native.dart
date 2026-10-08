import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/mask_result.dart';

class NativeTfliteSegmentation {
  static Interpreter? _interpreter;
  static bool _hasTriedLoad = false;

  /// Loads bundled TFLite model from assets (e.g. assets/models/selfie_segmenter.tflite)
  static Future<Interpreter?> _getInterpreter() async {
    if (_interpreter != null) return _interpreter;
    if (_hasTriedLoad) return null;
    _hasTriedLoad = true;

    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/selfie_segmenter.tflite',
        options: options,
      );
      debugPrint('Loaded TFLite segmentation model successfully.');
      return _interpreter;
    } catch (e) {
      debugPrint('TFLite model asset not found or not initialized yet: $e');
      return null;
    }
  }

  static Future<MaskResult?> runInference(Uint8List imageBytes) async {
    try {
      final interpreter = await _getInterpreter();
      if (interpreter == null) return null;

      final original = img.decodeImage(imageBytes);
      if (original == null) return null;

      final inputTensor = interpreter.getInputTensor(0);
      final inputShape = inputTensor.shape; // e.g., [1, 256, 256, 3]
      final inputHeight = inputShape.length > 1 ? inputShape[1] : 256;
      final inputWidth = inputShape.length > 2 ? inputShape[2] : 256;

      final resized = img.copyResize(original, width: inputWidth, height: inputHeight);

      // Input buffer float32
      final input = List.generate(
        1,
        (_) => List.generate(
          inputHeight,
          (y) => List.generate(
            inputWidth,
            (x) {
              final p = resized.getPixel(x, y);
              return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
            },
          ),
        ),
      );

      final outputTensor = interpreter.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final outputHeight = outputShape.length > 1 ? outputShape[1] : 256;
      final outputWidth = outputShape.length > 2 ? outputShape[2] : 256;
      final channels = outputShape.length > 3 ? outputShape[3] : 1;

      final output = List.generate(
        1,
        (_) => List.generate(
          outputHeight,
          (_) => List.generate(outputWidth, (_) => List.filled(channels, 0.0)),
        ),
      );

      interpreter.run(input, output);

      final maskImg = img.Image(width: outputWidth, height: outputHeight, numChannels: 1);
      for (int y = 0; y < outputHeight; y++) {
        for (int x = 0; x < outputWidth; x++) {
          final val = output[0][y][x][0];
          final maskVal = (val > 0.5) ? 255 : 0;
          maskImg.setPixelRgba(x, y, maskVal, maskVal, maskVal, 255);
        }
      }

      final finalMask = img.copyResize(maskImg, width: original.width, height: original.height);
      final resultBytes = Uint8List(original.width * original.height);
      for (int y = 0; y < original.height; y++) {
        for (int x = 0; x < original.width; x++) {
          resultBytes[y * original.width + x] = finalMask.getPixel(x, y).r.toInt();
        }
      }

      return MaskResult(
        maskBytes: resultBytes,
        width: original.width,
        height: original.height,
      );
    } catch (e) {
      debugPrint('TFLite native inference error: $e');
      return null;
    }
  }
}

Future<MaskResult?> getNativeTfliteMask(Uint8List imageBytes) async {
  return await NativeTfliteSegmentation.runInference(imageBytes);
}
