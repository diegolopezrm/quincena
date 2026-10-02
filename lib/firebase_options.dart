// The Firebase project the app talks to: quincena-dlsoft.
//
// Written from `firebase apps:sdkconfig` for the three registered apps.
// These values identify the apps; they are not secrets. What keeps others
// from using them is App Check, set up in lib/ai/cloud.dart.
//
// ignore_for_file: lines_longer_than_80_chars
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

abstract final class DefaultFirebaseOptions {
  /// The options for this platform, or null where Quincena has no Firebase
  /// app: Windows and Linux.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS || TargetPlatform.macOS => apple,
      _ => null,
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA37Xm4Yf_gLGxQiYN9HguG-RW6jlOzsU4',
    appId: '1:480223146144:web:81581fcfe4319b832b59c5',
    messagingSenderId: '480223146144',
    projectId: 'quincena-dlsoft',
    authDomain: 'quincena-dlsoft.firebaseapp.com',
    storageBucket: 'quincena-dlsoft.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCk4nftBO0eFUoFLhaKi1BOubm-nyx5KE',
    appId: '1:480223146144:android:aafd6a4e3b4b8fd42b59c5',
    messagingSenderId: '480223146144',
    projectId: 'quincena-dlsoft',
    storageBucket: 'quincena-dlsoft.firebasestorage.app',
  );

  /// One app for iOS and macOS, which share the bundle ID.
  static const FirebaseOptions apple = FirebaseOptions(
    apiKey: 'AIzaSyCaCNKNmfeethSZzJfSiyF5QOxOWAoB2Ps',
    appId: '1:480223146144:ios:946a584cdeb43cb62b59c5',
    messagingSenderId: '480223146144',
    projectId: 'quincena-dlsoft',
    storageBucket: 'quincena-dlsoft.firebasestorage.app',
    iosBundleId: 'dev.dlsoft.quincena',
  );
}
