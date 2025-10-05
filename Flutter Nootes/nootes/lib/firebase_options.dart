// Minimal Firebase options for web only, based on your provided config.
// For mobile/desktop, configure via FlutterFire CLI or add platform options.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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
        return linux;
      case TargetPlatform.fuchsia:
        // Not supported
        break;
    }
    throw UnsupportedError(
      'Firebase no está configurado para $defaultTargetPlatform.\n'
      'Usa "flutterfire configure" para generar opciones por plataforma.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5J4Bqc32E6qUATwQYLdGX8TYL8FcKzrI',
    appId: '1:479471329501:web:8e420233a1edab3ba43b34',
    messagingSenderId: '479471329501',
    projectId: 'smartnotes-d0bdd',
    authDomain: 'smartnotes-d0bdd.firebaseapp.com',
    storageBucket: 'smartnotes-d0bdd.firebasestorage.app',
    measurementId: 'G-2J1E4W47J8',
  );

  // Placeholder options for other platforms.
  // Reemplázalos con el archivo generado por: flutterfire configure
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_ANDROID_SENDER_ID',
    projectId: 'smartnotes-d0bdd',
    storageBucket: 'smartnotes-d0bdd.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_IOS_SENDER_ID',
    projectId: 'smartnotes-d0bdd',
    storageBucket: 'smartnotes-d0bdd.appspot.com',
    iosClientId: 'REPLACE_WITH_IOS_CLIENT_ID',
    iosBundleId: 'REPLACE_WITH_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_MACOS_API_KEY',
    appId: 'REPLACE_WITH_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MACOS_SENDER_ID',
    projectId: 'smartnotes-d0bdd',
    storageBucket: 'smartnotes-d0bdd.appspot.com',
    iosBundleId: 'REPLACE_WITH_MACOS_BUNDLE_ID',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WINDOWS_API_KEY',
    appId: 'REPLACE_WITH_WINDOWS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_WINDOWS_SENDER_ID',
    projectId: 'smartnotes-d0bdd',
    storageBucket: 'smartnotes-d0bdd.appspot.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_LINUX_API_KEY',
    appId: 'REPLACE_WITH_LINUX_APP_ID',
    messagingSenderId: 'REPLACE_WITH_LINUX_SENDER_ID',
    projectId: 'smartnotes-d0bdd',
    storageBucket: 'smartnotes-d0bdd.appspot.com',
  );
}
