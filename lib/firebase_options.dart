// Generated or configured for project: pagelabs-utility
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyYOUR_API_KEY_HERE',
    appId: '1:100000000000:web:pagelabs-utility',
    messagingSenderId: '100000000000',
    projectId: 'pagelabs-utility',
    authDomain: 'pagelabs-utility.web.app',
    storageBucket: 'pagelabs-utility.appspot.com',
    databaseURL: 'https://pagelabs-utility-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyYOUR_API_KEY_HERE',
    appId: '1:100000000000:android:pagelabs-utility',
    messagingSenderId: '100000000000',
    projectId: 'pagelabs-utility',
    storageBucket: 'pagelabs-utility.appspot.com',
    databaseURL: 'https://pagelabs-utility-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyYOUR_API_KEY_HERE',
    appId: '1:100000000000:ios:pagelabs-utility',
    messagingSenderId: '100000000000',
    projectId: 'pagelabs-utility',
    storageBucket: 'pagelabs-utility.appspot.com',
    iosBundleId: 'com.example.pagelab',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyYOUR_API_KEY_HERE',
    appId: '1:100000000000:ios:pagelabs-utility',
    messagingSenderId: '100000000000',
    projectId: 'pagelabs-utility',
    storageBucket: 'pagelabs-utility.appspot.com',
    iosBundleId: 'com.example.pagelab',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyYOUR_API_KEY_HERE',
    appId: '1:100000000000:web:pagelabs-utility',
    messagingSenderId: '100000000000',
    projectId: 'pagelabs-utility',
    authDomain: 'pagelabs-utility.web.app',
    storageBucket: 'pagelabs-utility.appspot.com',
  );
}
