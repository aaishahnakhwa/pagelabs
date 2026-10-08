import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize Firebase with options for pagelabs-utility
  Future<void> init() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _initialized = true;
        return;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      debugPrint('Firebase initialized successfully for pagelabs-utility.');
    } catch (e) {
      debugPrint('Firebase initialization note/warning: $e');
      // App can still run offline or locally
    }
  }

  /// Firestore reference
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Firebase Storage reference
  FirebaseStorage get storage => FirebaseStorage.instance;

  /// Save processed file metadata to Firestore
  Future<void> logProcessedFile({
    required String fileName,
    required String toolName,
    required int fileSizeBytes,
    String? fileUrl,
  }) async {
    if (!_initialized) return;
    try {
      await firestore.collection('processed_files').add({
        'fileName': fileName,
        'toolName': toolName,
        'fileSize': fileSizeBytes,
        'fileUrl': fileUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging file to Firestore: $e');
    }
  }
}
