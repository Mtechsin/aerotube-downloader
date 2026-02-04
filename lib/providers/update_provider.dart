import 'dart:io';
import 'package:flutter/material.dart';
import '../services/update_service.dart';
export '../services/update_service.dart' show UpdateInfo;

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  upToDate,
  error,
}

class UpdateProvider extends ChangeNotifier {
  final UpdateService _updateService = UpdateService();

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _updateInfo;
  String? _errorMessage;
  double _downloadProgress = 0.0;
  String? _downloadedFilePath;
  bool _autoCheckEnabled = true;
  DateTime? _lastChecked;

  // Getters
  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  String? get downloadedFilePath => _downloadedFilePath;
  bool get autoCheckEnabled => _autoCheckEnabled;
  DateTime? get lastChecked => _lastChecked;
  bool get hasUpdate =>
      _status == UpdateStatus.available ||
      _status == UpdateStatus.downloading ||
      _status == UpdateStatus.readyToInstall;
  bool get isChecking => _status == UpdateStatus.checking;
  bool get isDownloading => _status == UpdateStatus.downloading;

  /// Check for updates
  Future<bool> checkForUpdates({String? currentVersion}) async {
    try {
      _status = UpdateStatus.checking;
      _errorMessage = null;
      notifyListeners();

      final version =
          currentVersion ?? await _updateService.getCurrentVersion();
      final update = await _updateService.checkForUpdate(version);

      _lastChecked = DateTime.now();

      if (update != null) {
        _updateInfo = update;
        _status = UpdateStatus.available;
        notifyListeners();
        return true;
      } else {
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Download the update
  Future<bool> downloadUpdate() async {
    if (_updateInfo == null) return false;

    try {
      _status = UpdateStatus.downloading;
      _downloadProgress = 0.0;
      notifyListeners();

      final filePath = await _updateService.downloadUpdate(
        _updateInfo!.downloadUrl,
        (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      _downloadedFilePath = filePath;
      _status = UpdateStatus.readyToInstall;
      notifyListeners();
      return true;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Install the downloaded update
  Future<void> installUpdate() async {
    if (_downloadedFilePath == null) return;

    try {
      await _updateService.launchInstaller(_downloadedFilePath!);
      // Exit the app after launching installer
      exit(0);
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Skip this update
  void skipUpdate() {
    _status = UpdateStatus.idle;
    _updateInfo = null;
    notifyListeners();
  }

  /// Reset to idle state
  void reset() {
    _status = UpdateStatus.idle;
    _errorMessage = null;
    _downloadProgress = 0.0;
    notifyListeners();
  }

  /// Set auto-check preference
  void setAutoCheckEnabled(bool value) {
    _autoCheckEnabled = value;
    notifyListeners();
  }

  /// Check for updates on startup (if auto-check is enabled)
  Future<void> checkOnStartup() async {
    if (!_autoCheckEnabled) return;

    // Only check once per day
    if (_lastChecked != null) {
      final difference = DateTime.now().difference(_lastChecked!);
      if (difference.inHours < 24) return;
    }

    await checkForUpdates();
  }
}
