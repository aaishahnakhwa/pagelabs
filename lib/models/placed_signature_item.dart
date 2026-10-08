import 'dart:typed_data';

class PlacedSignatureItem {
  final String id;
  final int pageIndex;
  double normX; // 0.0 - 1.0 (relative to page width)
  double normY; // 0.0 - 1.0 (relative to page height)
  double normWidth; // 0.0 - 1.0
  double normHeight; // 0.0 - 1.0
  final Uint8List imageBytes;
  final String label;

  PlacedSignatureItem({
    required this.id,
    required this.pageIndex,
    required this.normX,
    required this.normY,
    required this.normWidth,
    required this.normHeight,
    required this.imageBytes,
    this.label = 'Signature',
  });
}
