# Platform-Specific Service Refactoring Guide

## Overview

This document describes the platform-specific service refactoring that enables the YouTube Downloader app to work seamlessly on both **Windows** and **Android** platforms.

## Architecture

### Platform Detection
- **File**: `lib/core/utils/platform_utils.dart`
- **Purpose**: Centralized platform detection utilities
- **Usage**:
  ```dart
  if (PlatformUtils.isAndroid) {
    // Android-specific code
  } else if (PlatformUtils.isWindows) {
    // Windows-specific code
  }
  ```

## Services

### 1. YtdlpService

#### Windows Implementation (`lib/services/ytdlp_service.dart`)
- **Backend**: yt-dlp executable
- **Features**:
  - Downloads and manages yt-dlp binary
  - Uses Process.run for executing yt-dlp commands
  - Supports cookie authentication via WebView2
  - Full playlist support
  - SponsorBlock integration
  - Download archive support

#### Android Implementation (`lib/services/ytdlp_service_android.dart`)
- **Backend**: youtubedl-android native library (https://github.com/yausername/youtubedl-android)
- **Key Changes**:
  - Uses `YoutubeDL` Java/Kotlin class for all operations
  - Native yt-dlp binary bundled in the library
  - FFmpeg and aria2c included as optional dependencies
  - Communicates via Flutter MethodChannel
  - Downloads managed by native library with progress callbacks
- **Features**:
  - No Python/Chaquopy needed (pure native library)
  - Built-in yt-dlp binary (no separate download)
  - Native progress tracking
  - FFmpeg integration for merging
  - Config file support (config.txt in assets)

**Example Usage (Android)**:
```dart
final ytdlpService = YtdlpServiceAndroid();
await ytdlpService.initialize();

// Get video info
final videoInfo = await ytdlpService.getVideoInfo(url);

// Download video
final task = await ytdlpService.downloadVideo(
  url: url,
  outputPath: outputPath,
  formatId: formatId,
  audioFormatId: audioFormatId,
  onProgress: (progress, speed, eta) {
    print('Progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);
```

---

### 2. FfmpegService

#### Windows Implementation (`lib/services/ffmpeg_service.dart`)
- **Backend**: FFmpeg executable
- **Features**:
  - Downloads and manages FFmpeg binary from GitHub
  - Checks availability and parses version
  - Used by yt-dlp for merging streams
  - Self-update capability

#### Android Implementation (`lib/services/ffmpeg_service_android.dart`)
- **Backend**: ffmpeg_kit_flutter_new
- **Key Changes**:
  - Replaces Process.run with FFmpegKit.execute()
  - Uses FFmpegSession for command execution
  - Built-in progress and statistics callbacks
  - No binary management needed (bundled with app)
- **Features**:
  - Merge video/audio streams
  - Convert between formats
  - Extract audio from video
  - Trim video segments
  - Custom FFmpeg command support

**Example Usage (Android)**:
```dart
final ffmpegService = FfmpegServiceAndroid();
await ffmpegService.initialize();

// Merge video and audio
final success = await ffmpegService.mergeVideoAudio(
  videoPath: videoPath,
  audioPath: audioPath,
  outputPath: outputPath,
  onProgress: (progress) {
    print('Merge progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

// Extract audio
await ffmpegService.extractAudio(
  inputPath: videoPath,
  outputPath: audioPath,
  audioFormat: 'mp3',
);
```

---

### 3. CookieService (Authentication)

#### Windows Implementation (`lib/services/cookie_service.dart`)
- **Backend**: webview_windows (WebView2)
- **Features**:
  - Embeds WebView2 for YouTube login
  - Stores cookies in user data directory
  - Cookie file path for yt-dlp consumption
  - Manual cookie clearing

#### Android Implementation (`lib/services/cookie_service_android.dart`)
- **Backend**: flutter_web_auth_2 + flutter_secure_storage
- **Key Changes**:
  - Replaces webview_windows with flutter_web_auth_2
  - Implements OAuth2 authentication flow
  - Stores tokens in secure storage (not cookies)
  - Token refresh support
  - Export/import cookies for yt-dlp compatibility
- **Features**:
  - OAuth2 authorization code flow
  - Secure token storage
  - Automatic token refresh
  - Login/logout functionality
  - Cookie file export (for compatibility)

**Authentication Flow (Android)**:
1. User taps "Login with YouTube"
2. App opens browser with OAuth2 URL
3. User logs in and grants permissions
4. Browser redirects back to app with authorization code
5. App exchanges code for access/refresh tokens
6. Tokens stored securely using flutter_secure_storage
7. Tokens used for authenticated requests

**Example Usage (Android)**:
```dart
final cookieService = CookieServiceAndroid();
await cookieService.init();

// Login
await cookieService.login(
  onStatus: (status) => print(status),
);

// Check if logged in
final isLoggedIn = await cookieService.isLoggedIn;

// Get auth token
final token = await cookieService.authToken;

// Logout
await cookieService.logout();
```

---

### 4. NotificationService

#### Windows Implementation (`lib/services/notification_service.dart`)
- **Backend**: local_notifier
- **Features**:
  - System tray notifications
  - In-app SnackBar notifications
  - Styled notification cards
  - Tap callbacks

#### Android Implementation (`lib/services/notification_service_android.dart`)
- **Backend**: flutter_local_notifications
- **Key Changes**:
  - Replaces local_notifier with flutter_local_notifications
  - Configures notification channels
  - Handles runtime permission requests (Android 13+)
  - Progress notifications for downloads
- **Features**:
  - Multiple notification channels (downloads, general, errors)
  - Progress bar notifications
  - Configurable importance and priority
  - Sound and vibration control
  - Persistent notifications for ongoing downloads

**Notification Channels (Android)**:
1. **Download Progress** (low importance, no sound)
   - Used for download progress updates
   - Shows progress bar
   - Ongoing notification (not dismissible)

2. **General Notifications** (default importance)
   - Used for general app notifications
   - Success messages
   - Informational messages

3. **Error Notifications** (high importance, sound + vibration)
   - Used for errors and warnings
   - High priority
   - Immediate user attention

**Example Usage (Android)**:
```dart
final notificationService = NotificationServiceAndroid();
await notificationService.init();

// Check permission
final enabled = await notificationService.areNotificationsEnabled();

// Simple notification
await notificationService.show(
  title: 'Download Complete',
  body: 'Video has been downloaded',
  isError: false,
);

// Progress notification
await notificationService.showDownloadProgress(
  title: 'Downloading Video',
  body: '45% complete',
  progress: 0.45,
);

// Cancel progress notification
await notificationService.cancelDownloadProgress();
```

---

### 5. AuthService (NEW - Android Focus)

**File**: `lib/services/auth_service.dart`

**Purpose**: Centralized secure storage for authentication tokens

**Features**:
- Secure token storage using flutter_secure_storage
- Encrypted shared preferences on Android
- Keychain storage on iOS
- Token expiry tracking
- User data storage
- Easy token retrieval

**Storage Security**:
- Android: EncryptedSharedPreferences
- iOS: Keychain with first_unlock_this_device accessibility
- Windows: DPAPI (via flutter_secure_storage_windows)

**Example Usage**:
```dart
final authService = AuthService();

// Store tokens
await authService.storeAuthToken(
  accessToken: 'token123',
  refreshToken: 'refresh123',
  expiry: DateTime.now().add(Duration(hours: 1)),
);

// Get token
final token = await authService.getAuthToken();

// Check expiry
final expired = await authService.isTokenExpired();

// Clear auth data
await authService.clearAuth();
```

---

## Service Factory

**File**: `lib/services/service_factory.dart`

**Purpose**: Unified access to platform-specific services

**Usage**:
```dart
// Get services (automatically selects platform-specific implementation)
final services = Services();

// Platform-specific ytdlp service
final ytdlp = services.ytdlpService;
if (PlatformUtils.isAndroid) {
  // Returns YtdlpServiceAndroid
} else {
  // Returns YtdlpService (Windows)
}

// Initialize all services
await services.initializeAll();
```

**Global Access**:
```dart
import 'package:youtube_downloader/services/service_factory.dart';

// Access services anywhere
final ytdlp = services.ytdlpService;
final ffmpeg = services.ffmpegService;
final cookies = services.cookieService;
final notifications = services.notificationService;
final auth = services.authService;
```

---

## Migration Guide

### From Windows to Android

When code needs to work on both platforms, use the service factory:

**Before** (Windows only):
```dart
final ytdlpService = YtdlpService();
await ytdlpService.initialize();
final info = await ytdlpService.getVideoInfo(url);
```

**After** (Cross-platform):
```dart
import 'package:youtube_downloader/services/service_factory.dart';

final ytdlp = services.ytdlpService;

if (PlatformUtils.isAndroid) {
  await (ytdlp as YtdlpServiceAndroid).initialize();
  final info = await ytdlp.getVideoInfo(url);
} else {
  await (ytdlp as YtdlpService).initialize();
  final info = await ytdlp.getVideoInfo(url);
}
```

**Or simpler** (if APIs are compatible):
```dart
await services.ytdlpService.initialize();
final info = await services.ytdlpService.getVideoInfo(url);
```

---

## Dependencies

### Android-Specific
- `youtube_explode_dart: ^3.0.5` - YouTube API client
- `ffmpeg_kit_flutter_new: ^4.1.0` - FFmpeg for Android
- `flutter_web_auth_2: ^3.0.0` - OAuth authentication
- `flutter_local_notifications: ^17.0.0` - Notifications
- `permission_handler: ^11.0.0` - Runtime permissions
- `flutter_secure_storage: ^9.0.0` - Secure token storage

### Windows-Specific
- `webview_windows: ^0.4.0` - WebView2 for authentication
- `local_notifier: ^0.1.3` - Desktop notifications

### Common
- `shared_preferences: ^2.3.3` - Settings persistence
- `path_provider: ^2.1.5` - Directory paths
- `http: ^1.2.2` - HTTP requests
- `archive: ^4.0.7` - ZIP extraction

---

## Platform-Specific Considerations

### Android
1. **Permissions**: Request notification permission at runtime (Android 13+)
2. **Storage**: Use scoped storage (don't assume file system access)
3. **Background Tasks**: Use work manager for long downloads
4. **Battery**: Optimize network and CPU usage
5. **Security**: Use encrypted storage for tokens

### Windows
1. **File Paths**: Use absolute paths
2. **Executables**: Manage binary downloads
3. **WebView2**: Requires Edge WebView2 runtime
4. **Notifications**: Use local_notifier for system tray
5. **Permissions**: No runtime permission requests needed

---

## Testing

### Android Testing
```bash
flutter run -d <android_device>
```

### Windows Testing
```bash
flutter run -d windows
```

### Check Platform Detection
```dart
print('Platform: ${PlatformUtils.platformName}');
print('Is Android: ${PlatformUtils.isAndroid}');
print('Is Windows: ${PlatformUtils.isWindows}');
```

---

## Future Improvements

1. **iOS Support**: Add platform detection and services for iOS
2. **macOS Support**: Add platform detection and services for macOS
3. **Linux Support**: Add platform detection and services for Linux
4. **Background Downloads**: Implement background download tasks for Android
5. **Push Notifications**: Add Firebase Cloud Messaging for push notifications
6. **Biometric Auth**: Add fingerprint/face ID for secure operations
7. **Cloud Sync**: Sync settings and downloads across devices

---

## Troubleshooting

### Android Issues

**Problem**: Notification permission denied
- **Solution**: User must enable notifications in app settings

**Problem**: YouTube login fails
- **Solution**: Check redirect URI scheme matches in AndroidManifest.xml

**Problem**: FFmpeg commands fail
- **Solution**: Ensure ffmpeg_kit_flutter_new is properly configured in build.gradle

### Windows Issues

**Problem**: yt-dlp not found
- **Solution**: Service will auto-download yt-dlp.exe

**Problem**: WebView2 not available
- **Solution**: Install Microsoft Edge WebView2 Runtime

**Problem**: Notifications not showing
- **Solution**: Check local_notifier setup in main.dart

---

## Contributing

When adding new features:
1. Implement for both Android and Windows
2. Use the service factory for access
3. Test on both platforms
4. Update this documentation

---

## License

This project is licensed under the MIT License.
