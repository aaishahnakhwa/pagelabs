import 'dart:convert';

class HistoryItem {
  final String id;
  final String title;
  final String type; // 'image' or 'pdf'
  final String filePath;
  final int fileSizeBytes;
  final DateTime createdAt;
  final String subtitle;
  final String? thumbnailBase64;
  final String? fileBase64;

  HistoryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.filePath,
    required this.fileSizeBytes,
    required this.createdAt,
    required this.subtitle,
    this.thumbnailBase64,
    this.fileBase64,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'subtitle': subtitle,
      if (thumbnailBase64 != null) 'thumbnailBase64': thumbnailBase64,
      if (fileBase64 != null) 'fileBase64': fileBase64,
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] ?? 'image',
      filePath: map['filePath'] ?? '',
      fileSizeBytes: map['fileSizeBytes'] ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      subtitle: map['subtitle'] ?? '',
      thumbnailBase64: map['thumbnailBase64'],
      fileBase64: map['fileBase64'],
    );
  }

  String toJson() => json.encode(toMap());

  factory HistoryItem.fromJson(String source) =>
      HistoryItem.fromMap(json.decode(source));
}
