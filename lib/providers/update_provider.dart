import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/platform_utils.dart';
import '../core/utils/error_helper.dart';
import '../services/core/logging_service.dart';
import '../services/core/settings_service.dart';
import '../services/core/update_service.dart';
export '../services/core/update_service.dart' show UpdateInfo;

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  upToDate,
  error,

  /// APK downloaded but system "Install unknown apps" toggle is off.
  /// UI should prompt to open Settings instead of showing a generic error.
  needsInstallPermission,
}

class UpdateProvider extends ChangeNotifier {
  final UpdateService _updateService;
  final SettingsService? _settingsService;

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _updateInfo;
  String? _errorMessage;
  double _downloadProgress = 0.0;
  String? _downloadedFilePath;
  bool _autoCheckEnabled = true;
  bool _cancelDownload = false;
  DateTime? _lastChecked;
  static DateTime? _staticLastChecked;
  static const String _prefLastCheckedKey = 'last_app_update_check';
  bool _isDisposed = false;

  UpdateProvider({
    UpdateService? updateService,
    SettingsService? settingsService,
  }) : _updateService = updateService ?? UpdateService(),
       _settingsService = settingsService {
    if (_settingsService != null) {
      _autoCheckEnabled = _settingsService.autoCheckUpdates;
    }
  }

  // Getters
  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  String? get downloadedFilePath => _downloadedFilePath;
  bool get autoCheckEnabled =>
      _settingsService?.autoCheckUpdates ?? _autoCheckEnabled;
  DateTime? get lastChecked => _lastChecked;
  bool get hasUpdate =>
      _status == UpdateStatus.available ||
      _status == UpdateStatus.downloading ||
      _status == UpdateStatus.readyToInstall ||
      _status == UpdateStatus.needsInstallPermission;
  bool get isChecking => _status == UpdateStatus.checking;
  bool get isDownloading => _status == UpdateStatus.downloading;
  bool get needsInstallPermission =>
      _status == UpdateStatus.needsInstallPermission;

  /// Check for updates. Pass [force] = true for manual checks so the
  /// cache/throttle is bypassed and GitHub is always queried.
  Future<bool> checkForUpdates({String? currentVersion, bool force = false}) async {
    try {
      _status = UpdateStatus.checking;
      _errorMessage = null;
      notifyListeners();

      final version =
          currentVersion ?? await _updateService.getCurrentVersion();
      final update = await _updateService.checkForUpdate(version, force: force);

      _lastChecked = DateTime.now();
      _staticLastChecked = _lastChecked;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _prefLastCheckedKey,
          _lastChecked!.millisecondsSinceEpoch,
        );
      } catch (_) {}

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
    } catch (e, stackTrace) {
      LoggingService().error(
        'Failed to check for updates: $e',
        component: 'UpdateProvider',
        error: e,
        stackTrace: stackTrace,
      );
      _status = UpdateStatus.error;
      _errorMessage = ErrorHelper.clean(e.toString());
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
      _cancelDownload = false;
      notifyListeners();

      final filePath = await _updateService.downloadUpdate(
        _updateInfo!.downloadUrl,
        (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
        isCancelled: () => _cancelDownload,
      );

      _downloadedFilePath = filePath;
      _status = UpdateStatus.readyToInstall;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      final wasCancelled = _cancelDownload;
      LoggingService().error(
        'Failed to download update: $e',
        component: 'UpdateProvider',
        error: e,
        stackTrace: stackTrace,
      );
      if (wasCancelled) {
        _status = UpdateStatus.available;
        _downloadProgress = 0.0;
      } else {
        _status = UpdateStatus.error;
        _errorMessage = ErrorHelper.clean(e.toString());
      }
      notifyListeners();
      return false;
    }
  }

  /// Cancel an in-flight download. Returns to the "available" state.
  void cancelDownload() {
    if (_status != UpdateStatus.downloading) return;
    _cancelDownload = true;
  }

  /// Install the downloaded update
  Future<void> installUpdate() async {
    if (_downloadedFilePath == null) return;

    try {
      if (PlatformUtils.isAndroid) {
        // Pre-flight: route to Settings when "Install unknown apps" is off
        // instead of firing an intent the system will silently drop.
        final allowed = await _updateService.canRequestPackageInstalls();
        if (!allowed) {
          _status = UpdateStatus.needsInstallPermission;
          _errorMessage =
              'Enable "Install unknown apps" for AeroTube in system settings, then tap Install again.';
          notifyListeners();
          return;
        }
        // Trigger Android system APK installer — no exit() needed.
        // The user confirms installation via the system prompt.
        await _updateService.launchAndroidInstaller(_downloadedFilePath!);
      } else {
        // Windows: launch the installer then close the app.
        await _updateService.launchInstaller(_downloadedFilePath!);
        exit(0);
      }
    } catch (e, stackTrace) {
      if (UpdateService.isInstallPermissionError(e)) {
        _status = UpdateStatus.needsInstallPermission;
        _errorMessage =
            'Enable "Install unknown apps" for AeroTube in system settings, then tap Install again.';
        notifyListeners();
        return;
      }
      LoggingService().error(
        'Failed to install update: $e',
        component: 'UpdateProvider',
        error: e,
        stackTrace: stackTrace,
      );
      _status = UpdateStatus.error;
      _errorMessage = ErrorHelper.clean(e.toString());
      notifyListeners();
    }
  }

  /// Opens the system "Install unknown apps" page for this app.
  /// Returns true when the toggle is granted after returning.
  Future<bool> openInstallSettings() async {
    try {
      // Fire the settings intent; the native side resolves with the
      // post-return toggle state on most devices.
      final granted = await _updateService.requestInstallPermission();
      if (granted && _status == UpdateStatus.needsInstallPermission) {
        _status = UpdateStatus.readyToInstall;
        _errorMessage = null;
        notifyListeners();
      }
      return granted;
    } catch (_) {
      await _updateService.openInstallSettings();
      return false;
    }
  }

  /// Re-checks the toggle (call when returning from Settings).
  /// Moves back to readyToInstall when granted.
  Future<bool> refreshInstallPermission() async {
    try {
      final granted = await _updateService.canRequestPackageInstalls();
      if (granted && _status == UpdateStatus.needsInstallPermission) {
        _status = UpdateStatus.readyToInstall;
        _errorMessage = null;
        notifyListeners();
      }
      return granted;
    } catch (_) {
      return false;
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
  Future<void> setAutoCheckEnabled(bool value) async {
    _autoCheckEnabled = value;
    if (_settingsService != null) {
      await _settingsService.setAutoCheckUpdates(value);
    }
    notifyListeners();
  }

  /// Check for updates on startup (if auto-check is enabled).
  /// Checks every 6 hours so users pick up new releases promptly.
  Future<void> checkOnStartup() async {
    if (!autoCheckEnabled) return;

    const throttle = Duration(hours: 6);

    // Only check once per throttle window – instance memory
    if (_lastChecked != null) {
      final difference = DateTime.now().difference(_lastChecked!);
      if (difference < throttle) return;
    }
    // Static cross-instance throttle (survives provider recreation, rapid restarts in same process)
    if (_staticLastChecked != null) {
      final difference = DateTime.now().difference(_staticLastChecked!);
      if (difference < throttle) return;
    }
    // Persistent throttle (survives app restarts, protects shared VPN IP)
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_prefLastCheckedKey);
      if (stored != null) {
        final storedTime = DateTime.fromMillisecondsSinceEpoch(stored);
        if (DateTime.now().difference(storedTime) < throttle) {
          _lastChecked = storedTime;
          _staticLastChecked = storedTime;
          return;
        }
      }
    } catch (_) {}

    // Throttle expired — force a fresh network check so we always see
    // the newest release rather than a 60-minute cached answer.
    await checkForUpdates(force: true);
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
