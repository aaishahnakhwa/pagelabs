import 'dart:typed_data';

class MaskResult {
  final Uint8List maskBytes; // 0 = Background, 255 = Subject
  final int width;
  final int height;

  MaskResult({
    required this.maskBytes,
    required this.width,
    required this.height,
  });
}
