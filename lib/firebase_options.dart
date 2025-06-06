// File generated by FlutterFire CLI.
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
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCo5-xWO8ffCGSLEAhj3GBZkPkQZxeVNtE',
    appId: '1:1018101191873:web:89089f7145bdb266e73040',
    messagingSenderId: '1018101191873',
    projectId: 'ocp-maps-41572',
    authDomain: 'ocp-maps-41572.firebaseapp.com',
    storageBucket: 'ocp-maps-41572.firebasestorage.app',
    measurementId: 'G-3Q5255T36V',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAz6AJWSbj326BlRvPwZ67ZyWWNBO2UC-E',
    appId: '1:1018101191873:android:65c2f87e1b6f3db0e73040',
    messagingSenderId: '1018101191873',
    projectId: 'ocp-maps-41572',
    storageBucket: 'ocp-maps-41572.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCCaKq2vjLL2TgJTk4Nz0lzbhCPXhhLDN8',
    appId: '1:1018101191873:ios:6836757c51e1ddf7e73040',
    messagingSenderId: '1018101191873',
    projectId: 'ocp-maps-41572',
    storageBucket: 'ocp-maps-41572.firebasestorage.app',
    iosBundleId: 'com.example.ocpMaps',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCCaKq2vjLL2TgJTk4Nz0lzbhCPXhhLDN8',
    appId: '1:1018101191873:ios:6836757c51e1ddf7e73040',
    messagingSenderId: '1018101191873',
    projectId: 'ocp-maps-41572',
    storageBucket: 'ocp-maps-41572.firebasestorage.app',
    iosBundleId: 'com.example.ocpMaps',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCo5-xWO8ffCGSLEAhj3GBZkPkQZxeVNtE',
    appId: '1:1018101191873:web:07762338560626ebe73040',
    messagingSenderId: '1018101191873',
    projectId: 'ocp-maps-41572',
    authDomain: 'ocp-maps-41572.firebaseapp.com',
    storageBucket: 'ocp-maps-41572.firebasestorage.app',
    measurementId: 'G-0MVD60E55M',
  );
}
