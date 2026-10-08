import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveAndDownloadFile({
  required String fileName,
  required List<int> bytes,
}) async {
  Directory baseDir;
  try {
    baseDir = await getApplicationDocumentsDirectory();
  } catch (_) {
    baseDir = Directory.current;
  }
  final pagelabDir = Directory('${baseDir.path}/PageLab');
  if (!await pagelabDir.exists()) {
    await pagelabDir.create(recursive: true);
  }
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final cleanName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
  final filePath = '${pagelabDir.path}/${timestamp}_$cleanName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  return filePath;
}

Future<void> openDownloadedFile(String filePath, {List<int>? bytes, String? fileName}) async {
  try {
    await OpenFilex.open(filePath);
  } catch (e) {
    debugPrint('Error opening file: $e');
  }
}

Future<void> shareDownloadedFile(String filePath, {String? text, List<int>? bytes, String? fileName}) async {
  try {
    final xFile = XFile(filePath);
    await SharePlus.instance.share(ShareParams(files: [xFile], text: text));
  } catch (e) {
    debugPrint('Error sharing file: $e');
  }
}

Future<void> deleteDownloadedFile(String filePath) async {
  try {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    debugPrint('Error deleting file: $e');
  }
}

void downloadApkDirect() {}

