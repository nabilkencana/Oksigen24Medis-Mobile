// File generated or curated manually from google-services.json and GoogleService-Info.plist configuration.
// ignore_for_file: type=lint
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
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAA9rhzrtjJgwDJmeTccfDhcAlGcvAeEBQ',
    appId: '1:905545093547:android:c2219d6713fadfec5842ee',
    messagingSenderId: '905545093547',
    projectId: 'oksigen24medis-db0ec',
    storageBucket: 'oksigen24medis-db0ec.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAS-im3L4JJXjdd6UjHcogjwqFwKjVQ7IA',
    appId: '1:905545093547:ios:54a827aa642fda445842ee',
    messagingSenderId: '905545093547',
    projectId: 'oksigen24medis-db0ec',
    storageBucket: 'oksigen24medis-db0ec.firebasestorage.app',
    iosBundleId: 'com.example.oksigen24medisMobile2',
  );
}
