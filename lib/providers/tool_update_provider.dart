import 'package:flutter/material.dart';
import '../services/ytdlp_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/logging_service.dart';

export '../services/ytdlp_service.dart' show YtdlpUpdateInfo;
export '../services/ffmpeg_service.dart' show FfmpegUpdateInfo;

enum ToolUpdateStatus {
  idle,
  checking,
  updateAvailable,
  downloading,
  installing,
  upToDate,
  error,
}

enum ToolType { ytdlp, ffmpeg }

class ToolUpdateState {
  final ToolType tool;
  final ToolUpdateStatus status;
  final String? currentVersion;
  final String? latestVersion;
  final double progress;
  final String? statusMessage;
  final String? errorMessage;
  final bool isAvailable;

  ToolUpdateState({
    required this.tool,
    this.status = ToolUpdateStatus.idle,
    this.currentVersion,
    this.latestVersion,
    this.progress = 0.0,
    this.statusMessage,
    this.errorMessage,
    this.isAvailable = false,
  });

  ToolUpdateState copyWith({
    ToolUpdateStatus? status,
    String? currentVersion,
    String? latestVersion,
    double? progress,
    String? statusMessage,
    String? errorMessage,
    bool? isAvailable,
  }) {
    return ToolUpdateState(
      tool: tool,
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  bool get hasUpdate => status == ToolUpdateStatus.updateAvailable;
  bool get isBusy =>
      status == ToolUpdateStatus.checking ||
      status == ToolUpdateStatus.downloading ||
      status == ToolUpdateStatus.installing;
}

class ToolUpdateProvider extends ChangeNotifier {
  final YtdlpService _ytdlpService;
  final FfmpegService _ffmpegService;
  final LoggingService _logger = LoggingService();

  ToolUpdateState _ytdlpState;
  ToolUpdateState _ffmpegState;
  bool _autoCheckEnabled = true;

  ToolUpdateProvider({
    required YtdlpService ytdlpService,
    required FfmpegService ffmpegService,
  }) : _ytdlpService = ytdlpService,
       _ffmpegService = ffmpegService,
       _ytdlpState = ToolUpdateState(tool: ToolType.ytdlp),
       _ffmpegState = ToolUpdateState(tool: ToolType.ffmpeg);

  // Getters
  ToolUpdateState get ytdlpState => _ytdlpState;
  ToolUpdateState get ffmpegState => _ffmpegState;
  bool get autoCheckEnabled => _autoCheckEnabled;

  bool get hasAnyUpdates => _ytdlpState.hasUpdate || _ffmpegState.hasUpdate;
  bool get isAnyBusy => _ytdlpState.isBusy || _ffmpegState.isBusy;

  /// Initialize and check tool availability
  Future<void> init() async {
    _logger.info(
      'Initializing ToolUpdateProvider',
      component: 'ToolUpdateProvider',
    );

    // Check initial availability
    await _checkAvailability();

    // Auto-check for updates if enabled
    if (_autoCheckEnabled) {
      await checkAllForUpdates();
    }
  }

  /// Check availability of both tools
  Future<void> _checkAvailability() async {
    // Check yt-dlp
    final ytdlpAvailable = await _ytdlpService.isAvailable();
    final ytdlpVersion = await _ytdlpService.getVersion();

    _ytdlpState = _ytdlpState.copyWith(
      isAvailable: ytdlpAvailable,
      currentVersion: ytdlpVersion,
    );

    // Check FFmpeg
    await _ffmpegService.initialize();
    final ffmpegVersion = await _ffmpegService.getVersion();

    _ffmpegState = _ffmpegState.copyWith(
      isAvailable: _ffmpegService.isAvailable,
      currentVersion: ffmpegVersion,
    );

    notifyListeners();
  }

  /// Check both tools for updates
  Future<void> checkAllForUpdates() async {
    _logger.info(
      'Checking all tools for updates',
      component: 'ToolUpdateProvider',
    );
    await Future.wait([checkYtdlpForUpdate(), checkFfmpegForUpdate()]);
  }

  /// Check yt-dlp for updates
  Future<void> checkYtdlpForUpdate() async {
    if (_ytdlpState.isBusy) return;

    _ytdlpState = _ytdlpState.copyWith(
      status: ToolUpdateStatus.checking,
      statusMessage: 'Checking for updates...',
      errorMessage: null,
    );
    notifyListeners();

    try {
      final updateInfo = await _ytdlpService.checkForUpdateWithProgress();

      if (updateInfo != null) {
        _ytdlpState = _ytdlpState.copyWith(
          status: ToolUpdateStatus.updateAvailable,
          currentVersion: updateInfo.currentVersion,
          latestVersion: updateInfo.latestVersion,
          statusMessage: 'Update available: ${updateInfo.latestVersion}',
        );
        _logger.info(
          'yt-dlp update available: ${updateInfo.currentVersion} -> ${updateInfo.latestVersion}',
          component: 'ToolUpdateProvider',
        );
      } else {
        // Preserve the current version even when no update is available
        final currentVersion = _ytdlpState.currentVersion ?? (await _ytdlpService.getVersion());
        _ytdlpState = _ytdlpState.copyWith(
          status: ToolUpdateStatus.upToDate,
          currentVersion: currentVersion,
          statusMessage: currentVersion != null ? 'Up to date (v$currentVersion)' : 'Up to date',
        );
      }
    } catch (e) {
      _ytdlpState = _ytdlpState.copyWith(
        status: ToolUpdateStatus.error,
        errorMessage: 'Failed to check: $e',
      );
      _logger.error(
        'Failed to check yt-dlp updates',
        component: 'ToolUpdateProvider',
        error: e,
      );
    }

    notifyListeners();
  }

  /// Check FFmpeg for updates
  Future<void> checkFfmpegForUpdate() async {
    if (_ffmpegState.isBusy) return;

    _ffmpegState = _ffmpegState.copyWith(
      status: ToolUpdateStatus.checking,
      statusMessage: 'Checking for updates...',
      errorMessage: null,
    );
    notifyListeners();

    try {
      final updateInfo = await _ffmpegService.checkForUpdate();

      if (updateInfo != null && updateInfo.latestVersion != null) {
        // Check if we actually have an update available
        final hasUpdate = updateInfo.currentVersion != updateInfo.latestVersion;
        
        _ffmpegState = _ffmpegState.copyWith(
          status: hasUpdate ? ToolUpdateStatus.updateAvailable : ToolUpdateStatus.upToDate,
          currentVersion: updateInfo.currentVersion,
          latestVersion: updateInfo.latestVersion,
          statusMessage: hasUpdate 
              ? 'Update available: ${updateInfo.latestVersion}'
              : 'Up to date (v${updateInfo.currentVersion})',
        );
      } else {
        _ffmpegState = _ffmpegState.copyWith(
          status: ToolUpdateStatus.upToDate,
          statusMessage: 'Up to date',
        );
      }
    } catch (e) {
      _ffmpegState = _ffmpegState.copyWith(
        status: ToolUpdateStatus.error,
        errorMessage: 'Failed to check: $e',
      );
      _logger.error(
        'Failed to check FFmpeg updates',
        component: 'ToolUpdateProvider',
        error: e,
      );
    }

    notifyListeners();
  }

  /// Update yt-dlp to latest version
  Future<bool> updateYtdlp() async {
    if (_ytdlpState.status != ToolUpdateStatus.updateAvailable) return false;

    _ytdlpState = _ytdlpState.copyWith(
      status: ToolUpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Downloading update...',
    );
    notifyListeners();

    final success = await _ytdlpService.downloadAndInstallUpdate(
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
      onProgress: (progress) {
        _ytdlpState = _ytdlpState.copyWith(progress: progress);
        notifyListeners();
      },
      onStatus: (status) {
        _ytdlpState = _ytdlpState.copyWith(statusMessage: status);
        notifyListeners();
      },
    );

    if (success) {
      _ytdlpState = _ytdlpState.copyWith(
        status: ToolUpdateStatus.upToDate,
        currentVersion: _ytdlpState.latestVersion,
        progress: 1.0,
        statusMessage: 'Update complete!',
      );
      _logger.showUserLog(
        'yt-dlp updated to version ${_ytdlpState.latestVersion}',
      );
    } else {
      _ytdlpState = _ytdlpState.copyWith(
        status: ToolUpdateStatus.error,
        errorMessage: 'Update failed',
      );
    }

    notifyListeners();
    return success;
  }

  /// Update FFmpeg to latest version
  Future<bool> updateFfmpeg() async {
    if (_ffmpegState.status != ToolUpdateStatus.updateAvailable) return false;

    _ffmpegState = _ffmpegState.copyWith(
      status: ToolUpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Downloading FFmpeg update...',
    );
    notifyListeners();

    final success = await _ffmpegService.update();

    if (success) {
      await _checkAvailability();
      _ffmpegState = _ffmpegState.copyWith(
        status: ToolUpdateStatus.upToDate,
        currentVersion: _ffmpegState.latestVersion,
        progress: 1.0,
        statusMessage: 'Update complete!',
      );
      _logger.showUserLog('FFmpeg updated to version ${_ffmpegState.latestVersion}');
    } else {
      _ffmpegState = _ffmpegState.copyWith(
        status: ToolUpdateStatus.error,
        errorMessage: 'Update failed',
      );
    }

    notifyListeners();
    return success;
  }

  /// Install FFmpeg
  Future<bool> installFfmpeg() async {
    if (_ffmpegState.isBusy) return false;

    _ffmpegState = _ffmpegState.copyWith(
      status: ToolUpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Downloading FFmpeg...',
    );
    notifyListeners();

    final success = await _ffmpegService.downloadAndInstall(
      onProgress: (progress) {
        _ffmpegState = _ffmpegState.copyWith(progress: progress);
        notifyListeners();
      },
      onStatus: (status) {
        _ffmpegState = _ffmpegState.copyWith(statusMessage: status);
        notifyListeners();
      },
    );

    if (success) {
      await _checkAvailability();
      _ffmpegState = _ffmpegState.copyWith(
        status: ToolUpdateStatus.upToDate,
        progress: 1.0,
        statusMessage: 'Installation complete!',
      );
      _logger.showUserLog('FFmpeg installed successfully');
    } else {
      _ffmpegState = _ffmpegState.copyWith(
        status: ToolUpdateStatus.error,
        errorMessage: 'Installation failed',
      );
    }

    notifyListeners();
    return success;
  }

  /// Install yt-dlp
  Future<bool> installYtdlp() async {
    if (_ytdlpState.isBusy) return false;

    _ytdlpState = _ytdlpState.copyWith(
      status: ToolUpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Downloading yt-dlp...',
    );
    notifyListeners();

    try {
      // Force initialization to trigger download/setup
      await _ytdlpService.initialize(force: true);
      
      // Refresh status
      await checkYtdlpForUpdate();
      
      // Check if it's now available
      final isAvailable = await _ytdlpService.isAvailable();
      
      if (isAvailable) {
        _ytdlpState = _ytdlpState.copyWith(
          status: ToolUpdateStatus.upToDate,
          progress: 1.0,
          statusMessage: 'Installation complete!',
          isAvailable: true,
          currentVersion: await _ytdlpService.getVersion(),
        );
        _logger.showUserLog('yt-dlp installed successfully');
        return true;
      } else {
        throw Exception('Installation verification failed');
      }
    } catch (e) {
      _ytdlpState = _ytdlpState.copyWith(
        status: ToolUpdateStatus.error,
        errorMessage: 'Installation failed: $e',
      );
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Refresh tool availability (call after manual path changes)
  Future<void> refreshAvailability() async {
    await _checkAvailability();
  }

  /// Set auto-check preference
  void setAutoCheckEnabled(bool value) {
    _autoCheckEnabled = value;
    notifyListeners();
  }

  /// Reset state for a tool
  void resetState(ToolType tool) {
    if (tool == ToolType.ytdlp) {
      _ytdlpState = ToolUpdateState(tool: ToolType.ytdlp);
    } else {
      _ffmpegState = ToolUpdateState(tool: ToolType.ffmpeg);
    }
    notifyListeners();
  }
}
