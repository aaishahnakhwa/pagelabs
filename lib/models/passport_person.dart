import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'passport_preset.dart';

class PassportPersonItem {
  final String id;
  String name;
  Uint8List sourceBytes;
  img.Image? decodedSource;
  Uint8List? cutoutBytes;
  Uint8List? processedBytes;
  
  // Independent configuration per person
  PassportPreset preset;
  bool removeBackground;
  bool autoEnhance;
  int copies;
  bool isProcessing;

  // Alignment & framing
  double panX;
  double panY;
  double zoom;

  PassportPersonItem({
    required this.id,
    required this.name,
    required this.sourceBytes,
    this.decodedSource,
    this.cutoutBytes,
    this.processedBytes,
    PassportPreset? preset,
    this.removeBackground = true,
    this.autoEnhance = true,
    this.copies = 4,
    this.isProcessing = false,
    this.panX = 0.0,
    this.panY = 0.0,
    this.zoom = 1.0,
  }) : preset = preset ?? PassportPreset.presets[0];

  void resetAlignment() {
    panX = 0.0;
    panY = 0.0;
    zoom = 1.0;
  }
}
