import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../models/history_item.dart';
import 'file_saver/file_saver.dart' as saver;

class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static final Map<String, Uint8List> _bytesCache = {};

  List<HistoryItem> _history = [];
  List<HistoryItem> get history => List.unmodifiable(_history);

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('pagelab_history') ?? [];
    _history = jsonList
        .map((item) {
          try {
            return HistoryItem.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<HistoryItem>()
        .toList();
    _history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _isInitialized = true;
    notifyListeners();
  }

  Uint8List? getFileBytes(HistoryItem item) {
    if (_bytesCache.containsKey(item.id)) {
      return _bytesCache[item.id];
    }
    if (item.fileBase64 != null && item.fileBase64!.isNotEmpty) {
      try {
        final decoded = base64Decode(item.fileBase64!);
        _bytesCache[item.id] = decoded;
        return decoded;
      } catch (_) {}
    }
    return null;
  }

  Uint8List? getThumbnailBytes(HistoryItem item) {
    if (item.thumbnailBase64 != null && item.thumbnailBase64!.isNotEmpty) {
      try {
        return base64Decode(item.thumbnailBase64!);
      } catch (_) {}
    }
    return getFileBytes(item);
  }

  static String? _generateThumbnail(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final maxDim = 160;
      final resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxDim : null,
        height: decoded.height > decoded.width ? maxDim : null,
      );
      final jpg = img.encodeJpg(resized, quality: 72);
      return base64Encode(jpg);
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
      return null;
    }
  }

  Future<HistoryItem> saveFile({
    required String fileName,
    required List<int> bytes,
    required String type,
    required String subtitle,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = timestamp.toString();

    // Cache bytes in session memory
    final uint8 = Uint8List.fromList(bytes);
    _bytesCache[id] = uint8;

    // Normalize type
    final lowerName = fileName.toLowerCase();
    final lowerType = type.toLowerCase();
    final isPdf = lowerType.contains('pdf') || lowerName.endsWith('.pdf');
    final normalizedType = isPdf ? 'pdf' : 'image';

    // Generate thumbnail & fileBase64
    String? thumbB64;
    String? fileB64;

    if (!isPdf) {
      thumbB64 = _generateThumbnail(uint8);
    }

    // Persist full base64 if <= 2MB
    if (bytes.length <= 2 * 1024 * 1024) {
      try {
        fileB64 = base64Encode(bytes);
      } catch (_) {}
    }

    // Save locally or trigger Web browser file download
    final filePath = await saver.saveAndDownloadFile(
      fileName: fileName,
      bytes: bytes,
    );

    final item = HistoryItem(
      id: id,
      title: fileName,
      type: normalizedType,
      filePath: filePath,
      fileSizeBytes: bytes.length,
      createdAt: DateTime.now(),
      subtitle: subtitle,
      thumbnailBase64: thumbB64,
      fileBase64: fileB64,
    );

    _history.insert(0, item);
    await _saveHistoryToPrefs();
    notifyListeners();
    return item;
  }

  Future<void> deleteHistoryItem(HistoryItem item) async {
    _bytesCache.remove(item.id);
    await saver.deleteDownloadedFile(item.filePath);
    _history.removeWhere((element) => element.id == item.id);
    await _saveHistoryToPrefs();
    notifyListeners();
  }

  Future<void> deleteMultipleItems(List<HistoryItem> items) async {
    for (final item in items) {
      _bytesCache.remove(item.id);
      await saver.deleteDownloadedFile(item.filePath);
    }
    final idsToRemove = items.map((e) => e.id).toSet();
    _history.removeWhere((element) => idsToRemove.contains(element.id));
    await _saveHistoryToPrefs();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _bytesCache.clear();
    _history.clear();
    await _saveHistoryToPrefs();
    notifyListeners();
  }

  Future<void> _saveHistoryToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _history.map((e) => e.toJson()).toList();
      await prefs.setStringList('pagelab_history', jsonList);
    } catch (e) {
      debugPrint('Warning: LocalStorage save failed ($e). Stripping large base64...');
      try {
        final lightHistory = _history.map((e) {
          if (e.fileBase64 != null) {
            return HistoryItem(
              id: e.id,
              title: e.title,
              type: e.type,
              filePath: e.filePath,
              fileSizeBytes: e.fileSizeBytes,
              createdAt: e.createdAt,
              subtitle: e.subtitle,
              thumbnailBase64: e.thumbnailBase64,
              fileBase64: null,
            );
          }
          return e;
        }).toList();
        final prefs = await SharedPreferences.getInstance();
        final jsonList = lightHistory.map((e) => e.toJson()).toList();
        await prefs.setStringList('pagelab_history', jsonList);
      } catch (err) {
        debugPrint('Failed to save fallback history: $err');
      }
    }
  }

  Future<void> shareFile(String filePath, {String? text, List<int>? bytes, String? fileName, HistoryItem? item}) async {
    List<int>? fileBytes = bytes;
    String? name = fileName;
    if (fileBytes == null && item != null) {
      fileBytes = getFileBytes(item);
      name ??= item.title;
    }
    await saver.shareDownloadedFile(filePath, text: text, bytes: fileBytes, fileName: name);
  }

  Future<void> openFile(String filePath, {List<int>? bytes, String? fileName, HistoryItem? item}) async {
    List<int>? fileBytes = bytes;
    String? name = fileName;
    if (fileBytes == null && item != null) {
      fileBytes = getFileBytes(item);
      name ??= item.title;
    }
    await saver.openDownloadedFile(filePath, bytes: fileBytes, fileName: name);
  }
}
