import 'dart:async';

Future<String> saveAndDownloadFile({
  required String fileName,
  required List<int> bytes,
}) async {
  throw UnsupportedError('Cannot save file without web or io implementation.');
}

Future<void> openDownloadedFile(String filePath, {List<int>? bytes, String? fileName}) async {
  throw UnsupportedError('Cannot open file without web or io implementation.');
}

Future<void> shareDownloadedFile(String filePath, {String? text, List<int>? bytes, String? fileName}) async {
  throw UnsupportedError('Cannot share file without web or io implementation.');
}

Future<void> deleteDownloadedFile(String filePath) async {
  // Stub
}

void downloadApkDirect() {}

