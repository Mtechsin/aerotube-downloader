import 'package:flutter/material.dart';

import '../services/ffmpeg_service.dart';
import '../services/ffmpeg_service_android.dart';
import '../services/logging_service.dart';
import '../core/utils/platform_utils.dart';

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
  final dynamic _ytdlpService; // Can be YtdlpService or YtdlpServiceAndroid
  final dynamic _ffmpegService; // Can be FfmpegService or FfmpegServiceAndroid
  final LoggingService _logger = LoggingService();

  ToolUpdateState _ytdlpState;
  ToolUpdateState _ffmpegState;
  bool _autoCheckEnabled = true;

  bool _ytdlpCancelToken = false;
  bool _ffmpegCancelToken = false;

  // Throttling: track last notifyListeners call time per tool
  DateTime _lastYtdlpNotify = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFfmpegNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _progressThrottleMs = 100; // max 10 UI updates/sec

  ToolUpdateProvider({
    required dynamic ytdlpService,
    required dynamic ffmpegService,
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
  /// Now lazy-loads update checks to avoid blocking cold boot
  Future<void> init() async {
    _logger.info(
      'Initializing ToolUpdateProvider',
      component: 'ToolUpdateProvider',
    );

    // Don't block - just schedule background work
    _checkAvailabilityAsync();
  }

  /// Async version that doesn't block - called on first user interaction
  Future<void> _checkAvailabilityAsync() async {
    // Run availability check in background
    await _checkAvailability();

    // Auto-check for updates if enabled - defer to after app is interactive
    if (_autoCheckEnabled) {
      Future.delayed(const Duration(seconds: 10), () {
        checkAllForUpdates();
      });
    }
  }

  /// Check availability of both tools - now runs async without blocking
  Future<void> _checkAvailability() async {
    // Check yt-dlp
    final ytdlpAvailable = await _ytdlpService.isAvailable();
    final ytdlpVersion = await _ytdlpService.getVersion();

    _ytdlpState = _ytdlpState.copyWith(
      isAvailable: ytdlpAvailable,
      currentVersion: ytdlpVersion,
    );

    // Check FFmpeg
    if (_ffmpegService is FfmpegServiceAndroid) {
      await (_ffmpegService).initialize();
      final ffmpegVersion = (_ffmpegService).version;

      _ffmpegState = _ffmpegState.copyWith(
        isAvailable: (_ffmpegService).isAvailable,
        currentVersion: ffmpegVersion,
      );
    } else {
      await (_ffmpegService as FfmpegService).initialize();
      final ffmpegVersion = await (_ffmpegService).getVersion();

      _ffmpegState = _ffmpegState.copyWith(
        isAvailable: (_ffmpegService).isAvailable,
        currentVersion: ffmpegVersion,
      );
    }

    // Notify listeners only if needed - don't block cold boot
    if (ytdlpAvailable || _ffmpegState.isAvailable) {
      notifyListeners();
    }
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
        // yt-dlp is available - check if update is needed
        final hasUpdate = updateInfo.currentVersion != updateInfo.latestVersion;

        _ytdlpState = _ytdlpState.copyWith(
          status: hasUpdate
              ? ToolUpdateStatus.updateAvailable
              : ToolUpdateStatus.upToDate,
          currentVersion: updateInfo.currentVersion,
          latestVersion: updateInfo.latestVersion,
          statusMessage: hasUpdate
              ? 'Update available: ${updateInfo.latestVersion}'
              : 'Up to date (v${updateInfo.currentVersion})',
          isAvailable: true,
        );

        if (hasUpdate) {
          _logger.info(
            'yt-dlp update available: ${updateInfo.currentVersion} -> ${updateInfo.latestVersion}',
            component: 'ToolUpdateProvider',
          );
        }
      } else {
        // yt-dlp is not available
        _ytdlpState = _ytdlpState.copyWith(
          status: ToolUpdateStatus.error,
          isAvailable: false,
          errorMessage: 'yt-dlp not found',
          statusMessage: 'Not found',
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
  /// On Android, FFmpeg is bundled - always return upToDate
  Future<void> checkFfmpegForUpdate() async {
    if (_ffmpegState.isBusy) return;

    // On Android, FFmpeg is bundled with the library, no updates needed
    if (_ffmpegService is FfmpegServiceAndroid) {
      _ffmpegState = _ffmpegState.copyWith(
        status: ToolUpdateStatus.upToDate,
        statusMessage: 'Bundled with app',
        isAvailable: true,
      );
      notifyListeners();
      return;
    }

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
          status: hasUpdate
              ? ToolUpdateStatus.updateAvailable
              : ToolUpdateStatus.upToDate,
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
    _logger.info(
      'updateYtdlp called, current status: ${_ytdlpState.status}',
      component: 'ToolUpdateProvider',
    );

    if (_ytdlpState.status != ToolUpdateStatus.updateAvailable) {
      _logger.warning(
        'updateYtdlp: status is not updateAvailable, status: ${_ytdlpState.status}',
        component: 'ToolUpdateProvider',
      );
      return false;
    }

    _ytdlpCancelToken = false;
    _ytdlpState = _ytdlpState.copyWith(
      status: ToolUpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Downloading update...',
    );
    notifyListeners();

    String? lastStatusMessage;
    final bool success;
    if (PlatformUtils.isAndroid) {
      final downloadUrl =
          'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';

      _logger.info(
        'Calling downloadAndInstallUpdate for Android',
        component: 'ToolUpdateProvider',
      );

      success = await _ytdlpService.downloadAndInstallUpdate(
        downloadUrl,
        onProgress: (progress) {
          final now = DateTime.now();
          if (now.difference(_lastYtdlpNotify).inMilliseconds >=
              _progressThrottleMs) {
            _lastYtdlpNotify = now;
            _ytdlpState = _ytdlpState.copyWith(progress: progress);
            notifyListeners();
          }
        },
        onStatus: (status) {
          lastStatusMessage = status;
          _lastYtdlpNotify = DateTime.now();
          _ytdlpState = _ytdlpState.copyWith(statusMessage: status);
          notifyListeners();
        },
        isCancelled: () => _ytdlpCancelToken,
      );

      _logger.info(
        'downloadAndInstallUpdate returned: $success',
        component: 'ToolUpdateProvider',
      );

      if (success) {
        _ytdlpState = _ytdlpState.copyWith(
          progress: 1.0,
          currentVersion: await _ytdlpService.getVersion(),
          latestVersion: await _ytdlpService.getLatestVersion(),
          isAvailable: true,
        );
      }
    } else {
      final downloadUrl =
          'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';

      success = await _ytdlpService.downloadAndInstallUpdate(
        downloadUrl,
        onProgress: (progress) {
          final now = DateTime.now();
          if (now.difference(_lastYtdlpNotify).inMilliseconds >=
              _progressThrottleMs) {
            _lastYtdlpNotify = now;
            _ytdlpState = _ytdlpState.copyWith(progress: progress);
            notifyListeners();
          }
        },
        onStatus: (status) {
          lastStatusMessage = status;
          _lastYtdlpNotify = DateTime.now();
          _ytdlpState = _ytdlpState.copyWith(statusMessage: status);
          notifyListeners();
        },
        isCancelled: () => _ytdlpCancelToken,
      );
    }

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
      if (_ytdlpCancelToken) {
        _ytdlpState = _ytdlpState.copyWith(
          status: ToolUpdateStatus.idle,
          statusMessage: 'Cancelled',
        );
      } else {
        final message = lastStatusMessage ?? 'Update failed';
        _ytdlpState = _ytdlpState.copyWith(
          status: ToolUpdateStatus.error,
          statusMessage: message,
          errorMessage: message,
        );
        _logger.showUserLog(message, isError: true);
      }
    }

    notifyListeners();
    return success;
  }

  /// Update FFmpeg to latest version
  Future<bool> updateFfmpeg() async {
    if (_ffmpegState.status != ToolUpdateStatus.updateAvailable) return false;

    _ffmpegCancelToken = false;
    _ffmpegState = _ffmpegState.copyWith(
      status: ToolUpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Downloading FFmpeg update...',
    );
    notifyListeners();

    final success = await _ffmpegService.update(
      onProgress: (progress) {
        final now = DateTime.now();
        if (now.difference(_lastFfmpegNotify).inMilliseconds >=
            _progressThrottleMs) {
          _lastFfmpegNotify = now;
          _ffmpegState = _ffmpegState.copyWith(progress: progress);
          notifyListeners();
        }
      },
      onStatus: (status) {
        _lastFfmpegNotify = DateTime.now();
        _ffmpegState = _ffmpegState.copyWith(statusMessage: status);
        notifyListeners();
      },
      isCancelled: () => _ffmpegCancelToken,
    );

    if (success) {
      await _checkAvailability();
      _ffmpegState = _ffmpegState.copyWith(
        status: ToolUpdateStatus.upToDate,
        currentVersion: _ffmpegState.latestVersion,
        progress: 1.0,
        statusMessage: 'Update complete!',
      );
      _logger.showUserLog(
        'FFmpeg updated to version ${_ffmpegState.latestVersion}',
      );
    } else {
      if (_ffmpegCancelToken) {
        _ffmpegState = _ffmpegState.copyWith(
          status: ToolUpdateStatus.idle,
          statusMessage: 'Cancelled',
        );
      } else {
        _ffmpegState = _ffmpegState.copyWith(
          status: ToolUpdateStatus.error,
          errorMessage: 'Update failed',
        );
      }
    }

    notifyListeners();
    return success;
  }

  /// Install FFmpeg
  Future<bool> installFfmpeg() async {
    if (_ffmpegState.isBusy) return false;

    _ffmpegCancelToken = false;
    _ffmpegState = _ffmpegState.copyWith(
      status: ToolUpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Downloading FFmpeg...',
    );
    notifyListeners();

    final success = await _ffmpegService.downloadAndInstall(
      onProgress: (progress) {
        final now = DateTime.now();
        if (now.difference(_lastFfmpegNotify).inMilliseconds >=
            _progressThrottleMs) {
          _lastFfmpegNotify = now;
          _ffmpegState = _ffmpegState.copyWith(progress: progress);
          notifyListeners();
        }
      },
      onStatus: (status) {
        _lastFfmpegNotify = DateTime.now();
        _ffmpegState = _ffmpegState.copyWith(statusMessage: status);
        notifyListeners();
      },
      isCancelled: () => _ffmpegCancelToken,
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
      if (_ffmpegCancelToken) {
        _ffmpegState = _ffmpegState.copyWith(
          status: ToolUpdateStatus.idle,
          statusMessage: 'Cancelled',
        );
      } else {
        _ffmpegState = _ffmpegState.copyWith(
          status: ToolUpdateStatus.error,
          errorMessage: 'Installation failed',
        );
      }
    }

    notifyListeners();
    return success;
  }

  /// Install yt-dlp
  Future<bool> installYtdlp() async {
    if (_ytdlpState.isBusy) return false;

    _ytdlpCancelToken = false;
    _ytdlpState = _ytdlpState.copyWith(
      status: ToolUpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Downloading yt-dlp...',
    );
    notifyListeners();

    try {
      String? lastStatusMessage;
      final bool installSucceeded;

      if (PlatformUtils.isAndroid) {
        final downloadUrl =
            'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';

        installSucceeded = await _ytdlpService.downloadAndInstallUpdate(
          downloadUrl,
          onProgress: (progress) {
            final now = DateTime.now();
            if (now.difference(_lastYtdlpNotify).inMilliseconds >=
                _progressThrottleMs) {
              _lastYtdlpNotify = now;
              _ytdlpState = _ytdlpState.copyWith(progress: progress);
              notifyListeners();
            }
          },
          onStatus: (status) {
            lastStatusMessage = status;
            _lastYtdlpNotify = DateTime.now();
            _ytdlpState = _ytdlpState.copyWith(statusMessage: status);
            notifyListeners();
          },
          isCancelled: () => _ytdlpCancelToken,
        );
      } else {
        const downloadUrl =
            'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';

        installSucceeded = await _ytdlpService.downloadAndInstallUpdate(
          downloadUrl,
          onProgress: (progress) {
            final now = DateTime.now();
            if (now.difference(_lastYtdlpNotify).inMilliseconds >=
                _progressThrottleMs) {
              _lastYtdlpNotify = now;
              _ytdlpState = _ytdlpState.copyWith(progress: progress);
              notifyListeners();
            }
          },
          onStatus: (status) {
            lastStatusMessage = status;
            _lastYtdlpNotify = DateTime.now();
            _ytdlpState = _ytdlpState.copyWith(statusMessage: status);
            notifyListeners();
          },
          isCancelled: () => _ytdlpCancelToken,
        );
      }

      if (!installSucceeded) {
        if (_ytdlpCancelToken) {
          _ytdlpState = _ytdlpState.copyWith(
            status: ToolUpdateStatus.idle,
            statusMessage: 'Cancelled',
          );
        } else {
          final message = lastStatusMessage ?? 'Installation failed';
          _ytdlpState = _ytdlpState.copyWith(
            status: ToolUpdateStatus.error,
            statusMessage: message,
            errorMessage: message,
          );
          _logger.showUserLog(message, isError: true);
        }
        return false;
      }

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

  /// Cancel ongoing operations
  void cancelYtdlpUpdate() {
    _ytdlpCancelToken = true;
    _ytdlpState = _ytdlpState.copyWith(
      status: ToolUpdateStatus.idle,
      statusMessage: 'Cancelled',
    );
    notifyListeners();
  }

  void cancelFfmpegUpdate() {
    _ffmpegCancelToken = true;
    _ffmpegState = _ffmpegState.copyWith(
      status: ToolUpdateStatus.idle,
      statusMessage: 'Cancelled',
    );
    notifyListeners();
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
