import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PickedDoc {
  final String name;
  final Uint8List bytes;
  const PickedDoc({required this.name, required this.bytes});
}

class FilePickerHelper {
  static Future<Uint8List?> pickSingleImage() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (files.isNotEmpty) {
      return _readBytes(files.first);
    }
    return null;
  }

  static Future<PickedDoc?> pickSingleImageWithDetails() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (files.isNotEmpty) {
      final bytes = await _readBytes(files.first);
      if (bytes != null) {
        return PickedDoc(name: files.first.name, bytes: bytes);
      }
    }
    return null;
  }

  static Future<List<Uint8List>> pickMultipleImages() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );
    final List<Uint8List> results = [];
    for (final file in files) {
      final bytes = await _readBytes(file);
      if (bytes != null) results.add(bytes);
    }
    return results;
  }

  static Future<PickedDoc?> pickSinglePdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isNotEmpty) {
      final bytes = await _readBytes(files.first);
      if (bytes != null) {
        return PickedDoc(name: files.first.name, bytes: bytes);
      }
    }
    return null;
  }

  static Future<List<PickedDoc>> pickMultiplePdfs() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final List<PickedDoc> results = [];
    for (final file in files) {
      final bytes = await _readBytes(file);
      if (bytes != null) {
        results.add(PickedDoc(name: file.name, bytes: bytes));
      }
    }
    return results;
  }

  static Future<PickedDoc?> pickSingleDocumentOrImageWithDetails() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isNotEmpty) {
      final bytes = await _readBytes(files.first);
      if (bytes != null) {
        return PickedDoc(name: files.first.name, bytes: bytes);
      }
    }
    return null;
  }

  static Future<Uint8List?> _readBytes(PlatformFile file) async {
    try {
      return await file.readAsBytes();
    } catch (_) {
      try {
        final p = file.path;
        if (p != null) {
          final f = File(p);
          if (await f.exists()) {
            return await f.readAsBytes();
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
