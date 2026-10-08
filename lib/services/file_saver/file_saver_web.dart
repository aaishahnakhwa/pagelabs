// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<String> saveAndDownloadFile({
  required String fileName,
  required List<int> bytes,
}) async {
  try {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final isPng = fileName.toLowerCase().endsWith('.png');
    final mimeType = isPdf ? 'application/pdf' : (isPng ? 'image/png' : 'image/jpeg');
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    Future.delayed(const Duration(seconds: 30), () {
      html.Url.revokeObjectUrl(url);
    });
    return 'downloaded://$fileName';
  } catch (e) {
    debugPrint('Error downloading file on Web: $e');
    return 'error://$fileName';
  }
}

Future<void> openDownloadedFile(String filePath, {List<int>? bytes, String? fileName}) async {
  if (bytes != null && bytes.isNotEmpty) {
    try {
      final name = fileName ?? 'file';
      final isPdf = name.toLowerCase().endsWith('.pdf');
      final isPng = name.toLowerCase().endsWith('.png');
      final mimeType = isPdf ? 'application/pdf' : (isPng ? 'image/png' : 'image/jpeg');
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      Future.delayed(const Duration(minutes: 5), () {
        html.Url.revokeObjectUrl(url);
      });
      return;
    } catch (e) {
      debugPrint('Error opening file in browser tab: $e');
    }
  }
}

Future<void> shareDownloadedFile(String filePath, {String? text, List<int>? bytes, String? fileName}) async {
  if (bytes != null && bytes.isNotEmpty) {
    final name = fileName ?? 'downloaded_file';
    await saveAndDownloadFile(fileName: name, bytes: bytes);
  }
}

Future<void> deleteDownloadedFile(String filePath) async {
  // No local file on web to delete from filesystem
}

void downloadApkDirect() {
  try {
    final anchor = html.AnchorElement(href: 'pagelab.apk')
      ..setAttribute('download', 'pagelab.apk')
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  } catch (e) {
    debugPrint('Error triggering APK download: $e');
  }
}

