import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralised feature-detection for the platforms Planom runs on.
///
/// The app started life on iOS/iPadOS, so a handful of plugins it depends on
/// are mobile-only (badge, biometrics, photo picker, orientation lock). On
/// macOS / Linux / Windows we either guard those calls out, swap in a desktop
/// equivalent, or accept that the feature is simply unavailable on that
/// platform. Keeping the predicates in one place makes "where does this not
/// work?" answerable from a single file.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool get _isWeb => kIsWeb;
  static bool get isIOS => !_isWeb && Platform.isIOS;
  static bool get isAndroid => !_isWeb && Platform.isAndroid;
  static bool get isMacOS => !_isWeb && Platform.isMacOS;
  static bool get isLinux => !_isWeb && Platform.isLinux;
  static bool get isWindows => !_isWeb && Platform.isWindows;

  /// True on iOS + Android. Used as the gate for the "mobile" feature set —
  /// app icon badges, screen-orientation lock, the system photo gallery.
  static bool get isMobile => isIOS || isAndroid;

  /// True on macOS + Linux + Windows — Planom switches to the iPad sidebar
  /// layout regardless of window width on these platforms, since they always
  /// have room for it.
  static bool get isDesktop => isMacOS || isLinux || isWindows;

  /// Whether `sqflite` can talk to SQLite natively here. Mobile + macOS yes;
  /// Linux and Windows need `sqflite_common_ffi` installed as the factory.
  static bool get sqfliteNeedsFfi => isLinux || isWindows;

  /// Whether the app icon badge can be set. `flutter_app_badger` is iOS/Android
  /// only — calling it elsewhere silently no-ops at best, crashes at worst.
  static bool get supportsAppBadge => isMobile;

  /// Whether `SystemChrome.setPreferredOrientations` has any effect. On desktop
  /// the call is a documented no-op but still costs a platform-channel round
  /// trip; we just skip it.
  static bool get supportsOrientationLock => isMobile;

  /// Whether `image_picker` can pop the system photo gallery. Desktop and web
  /// fall back to `file_picker` with image filetype filters.
  static bool get supportsImagePicker => isMobile;

  /// Whether `local_auth` can prompt for Face ID / Touch ID / Windows Hello.
  /// macOS and Linux have no `local_auth` implementation, so PIN/password is
  /// the only lock option there.
  static bool get supportsBiometricAuth => isIOS || isAndroid || isWindows;

  /// Whether `flutter_local_notifications` has a working implementation. We
  /// have init wiring for iOS + macOS today; Android/Linux/Windows would each
  /// need their own InitializationSettings entry before scheduling.
  static bool get supportsLocalNotifications => isIOS || isMacOS;

  /// Whether Apple's EventKit framework is available — the native device
  /// calendar integration (`app.planom/eventkit` MethodChannel + Swift bridge).
  /// iOS and macOS only; every other platform has no calendar store to read.
  static bool get supportsEventKit => isIOS || isMacOS;
}
