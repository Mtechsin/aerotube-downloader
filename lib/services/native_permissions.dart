import 'package:flutter/services.dart';

class NativePermissions {
  static const MethodChannel _channel = MethodChannel(
    'com.aerotube.youtube_downloader/permissions',
  );

  static Future<bool> setExecutable(String path) async {
    try {
      final result = await _channel.invokeMethod<bool>('setExecutable', {
        'path': path,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkExecutable(String path) async {
    try {
      final result = await _channel.invokeMethod<bool>('checkExecutable', {
        'path': path,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
