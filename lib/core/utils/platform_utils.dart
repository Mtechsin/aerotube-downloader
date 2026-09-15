import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform detection utility
class PlatformUtils {
  @visibleForTesting
  static bool? isAndroidOverride;
  @visibleForTesting
  static bool? isWindowsOverride;

  static bool get isAndroid => isAndroidOverride ?? Platform.isAndroid;
  static bool get isWindows => isWindowsOverride ?? Platform.isWindows;
  static bool get isIOS => Platform.isIOS;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  
  /// Returns the current platform name
  static String get platformName {
    if (isAndroid) return 'Android';
    if (isWindows) return 'Windows';
    if (isIOS) return 'iOS';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }
  
  /// Check if running on a mobile platform
  static bool get isMobile => isAndroid || isIOS;
  
  /// Check if running on a desktop platform
  static bool get isDesktop => isWindows || isMacOS || isLinux;
}
