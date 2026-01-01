import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    // TODO: Replace with platform-specific configs once google-services / GoogleService-Info are added.
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD-UMtGdCGTtFhmu7-X84vEF-I1ZsCDLuE',
    authDomain: 'my-tracker-app-b52b7.firebaseapp.com',
    projectId: 'my-tracker-app-b52b7',
    storageBucket: 'my-tracker-app-b52b7.firebasestorage.app',
    messagingSenderId: '250029058350',
    appId: '1:250029058350:web:7302b959c72ce44b2632bf',
  );
}
