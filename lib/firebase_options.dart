import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'your_web_api_key',
    appId: 'your_web_app_id',
    messagingSenderId: 'your_sender_id',
    projectId: 'your_project_id',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'your_android_api_key',
    appId: 'your_android_app_id',
    messagingSenderId: 'your_sender_id',
    projectId: 'your_project_id',
    storageBucket: 'your_project_id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'your_ios_api_key',
    appId: 'your_ios_app_id',
    messagingSenderId: 'your_sender_id',
    projectId: 'your_project_id',
    storageBucket: 'your_project_id.appspot.com',
    iosClientId: 'your_ios_client_id',
    iosBundleId: 'your_ios_bundle_id',
  );
}