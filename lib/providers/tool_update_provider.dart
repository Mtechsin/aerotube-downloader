import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ffmpeg/ffmpeg_tool_service.dart';
import '../services/ytdlp/ytdlp_tool_service.dart';
import '../services/core/logging_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/platform_utils.dart';
import '../core/utils/version_utils.dart';
import 'platform_settings_provider.dart';

export '../services/ytdlp/ytdlp_tool_service.dart' show YtdlpUpdateInfo;
export '../services/ffmpeg/ffmpeg_tool_service.dart' show FfmpegUpdateInfo;

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
  final YtdlpToolService _ytdlpService;
  final FfmpegToolService _ffmpegService;
  final PlatformSettingsProvider _settingsProvider;
  final LoggingService _logger = LoggingService();

  ToolUpdateState _ytdlpState;
  ToolUpdateState _ffmpegState;

  bool _ytdlpCancelToken = false;
  bool _ffmpegCancelToken = false;

  // Throttling: track last notifyListeners call time per tool
  DateTime _lastYtdlpNotify = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFfmpegNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _progressThrottleMs = 100; // max 10 UI updates/sec

  // Debounce: prevent hammering GitHub API (VPN shared IP 104.28.x.x)
  DateTime? _lastYtdlpCheck;
  DateTime? _lastFfmpegCheck;
  static const _debounceWindow = Duration(seconds: 60);
  DateTime? _lastCheckAll;

  bool _isDisposed = false;

  ToolUpdateProvider({
    required YtdlpToolService ytdlpService,
    required FfmpegToolService ffmpegService,
    required PlatformSettingsProvider settingsProvider,
  }) : _ytdlpService = ytdlpService,
       _ffmpegService = ffmpegService,
       _settingsProvider = settingsProvider,
       _ytdlpState = ToolUpdateState(tool: ToolType.ytdlp),
       _ffmpegState = ToolUpdateState(tool: ToolType.ffmpeg);

  // Getters
  ToolUpdateState get ytdlpState => _ytdlpState;
  ToolUpdateState get ffmpegState => _ffmpegState;
  bool get autoCheckEnabled => _settingsProvider.autoCheckUpdates;

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

  /// Async version that doesn't block - called on app start
  Future<void> _checkAvailabilityAsync() async {
    // Run availability check in background
    await _checkAvailability();

    // Auto-install yt-dlp on first launch or if missing (Android & Desktop)
    if (!_ytdlpState.isAvailable) {
      _logger.info(
        'yt-dlp is not available, auto-installing in background',
        component: 'ToolUpdateProvider',
      );
      await installYtdlp();
    }

    // Auto-check for updates if enabled - defer to after app is interactive.
    // 3s is enough for the first frame; force so we always see the newest.
    if (autoCheckEnabled) {
      Future.delayed(const Duration(seconds: 3), () {
        unawaited(
          checkAllForUpdates(force: true).catchError((Object e, StackTrace st) {
            _logger.warning(
              'Auto check for updates failed: $e',
              component: 'ToolUpdateProvider',
            );
          }),
        );
      });
    }
  }



  /// Check availability of both tools - now runs async without blocking
  Future<void> _checkAvailability() async {
    // Ensure the path to the managed binary has been resolved before probing.
    // initialize() is a no-op when already done, so this is cheap after boot.
    await _ytdlpService.initialize();

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

    // Always notify – UI needs to know "not found" state too (conditional was hiding errors)
    notifyListeners();
  }

  /// Check both tools for updates (staggered to avoid hammering GitHub API)
  Future<void> checkAllForUpdates({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastCheckAll != null &&
        now.difference(_lastCheckAll!) < _debounceWindow) {
      _logger.debug(
        'checkAllForUpdates debounced (called too soon)',
        component: 'ToolUpdateProvider',
      );
      return;
    }
    _lastCheckAll = now;
    _logger.info(
      'Checking all tools for updates',
      component: 'ToolUpdateProvider',
    );
    // Staggered: ytdlp first, then 500ms delay, then ffmpeg
    // Prevents Future.wait hammering same GitHub API rate limit
    await checkYtdlpForUpdate(force: force);
    await Future.delayed(const Duration(milliseconds: 500));
    await checkFfmpegForUpdate(force: force);
  }

  /// Check yt-dlp for updates
  Future<void> checkYtdlpForUpdate({bool force = false}) async {
    if (_ytdlpState.isBusy) return;

    // Debounce: if called within 60s of last successful check, skip network
    if (!force &&
        _lastYtdlpCheck != null &&
        DateTime.now().difference(_lastYtdlpCheck!) < _debounceWindow) {
      if (_ytdlpState.latestVersion != null ||
          _ytdlpState.currentVersion != null) {
        _logger.debug(
          'checkYtdlpForUpdate debounced (cached state preserved)',
          component: 'ToolUpdateProvider',
        );
        return;
      }
    }

    _ytdlpState = _ytdlpState.copyWith(
      status: ToolUpdateStatus.checking,
      statusMessage: 'Checking for updates...',
      errorMessage: null,
    );
    notifyListeners();

    try {
      final updateInfo = await _ytdlpService.checkForUpdateWithProgress();
      _lastYtdlpCheck = DateTime.now();

      if (updateInfo != null) {
        // yt-dlp is available - check if update is needed
        final hasUpdate = VersionUtils.isNewerVersion(
          updateInfo.currentVersion,
          updateInfo.latestVersion,
        );

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
          if (autoCheckEnabled) {
            _logger.info(
              'Auto-applying yt-dlp update in background...',
              component: 'ToolUpdateProvider',
            );
            Future.microtask(() => updateYtdlp());
          }
        }
      } else {
        // yt-dlp is not available
        _ytdlpState = _ytdlpState.copyWith(
          status: ToolUpdateStatus.error,
          isAvailable: false,
          errorMessage: 'yt-dlp not found',
          statusMessage: 'Not found',
        );
        if (autoCheckEnabled) {
          Future.microtask(() => installYtdlp());
        }
      }
    } catch (e) {
      final msg = e.toString();
      final isRateLimit = msg.toLowerCase().contains('rate limit') ||
          msg.contains('403') ||
          msg.contains('429');
      if (isRateLimit) {
        // Preserve last known version state, don't show generic error
        final hasKnownVersion = _ytdlpState.currentVersion != null ||
            _ytdlpState.latestVersion != null;
        _ytdlpState = _ytdlpState.copyWith(
          status: hasKnownVersion
              ? ToolUpdateStatus.upToDate
              : ToolUpdateStatus.idle,
          statusMessage: hasKnownVersion
              ? 'Up to date (rate limited – tap check again later)'
              : 'Rate limited – tap check again in a few minutes',
          errorMessage:
              'GitHub API rate limit – try again in a few minutes. You can still tap Install/Update to fetch latest binary directly.',
        );
        _logger.warning(
          'Rate limited checking yt-dlp updates (preserving cached state): $e',
          component: 'ToolUpdateProvider',
        );
      } else {
        _ytdlpState = _ytdlpState.copyWith(
          status: ToolUpdateStatus.error,
          errorMessage: 'Failed to check: $e',
          statusMessage: 'Check failed',
        );
        _logger.error(
          'Failed to check yt-dlp updates',
          component: 'ToolUpdateProvider',
          error: e,
        );
      }
    }

    notifyListeners();
  }

  /// Check FFmpeg for updates
  Future<void> checkFfmpegForUpdate({bool force = false}) async {
    if (_ffmpegState.isBusy) return;

    if (!force &&
        _lastFfmpegCheck != null &&
        DateTime.now().difference(_lastFfmpegCheck!) < _debounceWindow) {
      if (_ffmpegState.latestVersion != null ||
          _ffmpegState.currentVersion != null) {
        _logger.debug(
          'checkFfmpegForUpdate debounced',
          component: 'ToolUpdateProvider',
        );
        return;
      }
    }

    _ffmpegState = _ffmpegState.copyWith(
      status: ToolUpdateStatus.checking,
      statusMessage: 'Checking for updates...',
      errorMessage: null,
    );
    notifyListeners();

    try {
      final updateInfo = await _ffmpegService.checkForUpdate();
      _lastFfmpegCheck = DateTime.now();

      if (updateInfo != null && updateInfo.latestVersion != null) {
        // Check if we actually have an update available
        final hasUpdate = VersionUtils.isNewerVersion(
          updateInfo.currentVersion,
          updateInfo.latestVersion,
        );

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
      final msg = e.toString().toLowerCase();
      final isRateLimit = msg.contains('rate limit') ||
          msg.contains('403') ||
          msg.contains('429');
      if (isRateLimit) {
        final hasKnown = _ffmpegState.currentVersion != null ||
            _ffmpegState.latestVersion != null;
        _ffmpegState = _ffmpegState.copyWith(
          status: hasKnown ? ToolUpdateStatus.upToDate : ToolUpdateStatus.idle,
          statusMessage: hasKnown
              ? 'Up to date (rate limited – retry later)'
              : 'Rate limited – tap check again',
          errorMessage:
              'GitHub API rate limit – try again in a few minutes.',
        );
        _logger.warning(
          'Rate limited checking FFmpeg updates: $e',
          component: 'ToolUpdateProvider',
        );
      } else {
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
    }

    notifyListeners();
  }

  /// Update yt-dlp to latest version
  Future<bool> updateYtdlp() async {
    _logger.info(
      'updateYtdlp called, current status: ${_ytdlpState.status}',
      component: 'ToolUpdateProvider',
    );

    if (_ytdlpState.isBusy) {
      _logger.warning(
        'updateYtdlp: tool is already busy, skipping',
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
      final downloadUrl = AppConstants.ytdlpAndroidDownloadUrl;

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
      final downloadUrl = AppConstants.ytdlpWindowsDownloadUrl;

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
      await _settingsProvider.checkToolsAvailability();
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
      await _settingsProvider.checkToolsAvailability();
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
        final downloadUrl = AppConstants.ytdlpAndroidDownloadUrl;

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
        const downloadUrl = AppConstants.ytdlpWindowsDownloadUrl;

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

      // Refresh status (force to bypass debounce after fresh install)
      await checkYtdlpForUpdate(force: true);

      // Check if it's now available
      final isAvailable = await _ytdlpService.isAvailable();

      if (isAvailable) {
        await _settingsProvider.checkToolsAvailability();
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
  Future<void> setAutoCheckEnabled(bool value) async {
    await _settingsProvider.setAutoCheckUpdates(value);
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
