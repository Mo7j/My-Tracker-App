import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;

      case TargetPlatform.android:
        return android;

      default:
        throw UnsupportedError(
          'FirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Web Firebase configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD-UMtGdCGTtFhmu7-X84vEF-I1ZsCDLuE',
    authDomain: 'my-tracker-app-b52b7.firebaseapp.com',
    projectId: 'my-tracker-app-b52b7',
    storageBucket: 'my-tracker-app-b52b7.firebasestorage.app',
    messagingSenderId: '250029058350',
    appId: '1:250029058350:web:7302b959c72ce44b2632bf',
  );

  /// ✅ iOS Firebase configuration (REAL – from Firebase Console)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD-UMtGdCGTtFhmu7-X84vEF-I1ZsCDLuE',
    projectId: 'my-tracker-app-b52b7',
    storageBucket: 'my-tracker-app-b52b7.firebasestorage.app',
    messagingSenderId: '250029058350',
    appId: '1:250029058350:ios:d92d0b68ebe5c9002632bf',
    iosBundleId: 'com.example.myTrackerApp',
  );

  /// Android (optional – safe placeholder)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-UMtGdCGTtFhmu7-X84vEF-I1ZsCDLuE',
    projectId: 'my-tracker-app-b52b7',
    storageBucket: 'my-tracker-app-b52b7.firebasestorage.app',
    messagingSenderId: '250029058350',
    appId: '1:250029058350:android:PLACEHOLDER',
  );
}
