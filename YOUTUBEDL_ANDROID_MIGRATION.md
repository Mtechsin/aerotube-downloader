# youtubedl-android Migration Summary

## Overview
This document summarizes the migration from Chaquopy/Python-based yt-dlp implementation to the native youtubedl-android library (https://github.com/yausername/youtubedl-android).

## What Changed

### 1. Android Native Code

#### build.gradle.kts
- **Removed**: Chaquopy plugin (`com.chaquo.python`)
- **Added**: youtubedl-android dependencies:
  - `io.github.junkfood02.youtubedl-android:library:0.18.1`
  - `io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1`
  - `io.github.junkfood02.youtubedl-android:aria2c:0.18.1`
- **Updated**: ABI filters to include `x86` architecture

#### settings.gradle.kts
- **Removed**: Chaquopy plugin declaration

#### AndroidManifest.xml
- **Added**: `android:extractNativeLibs="true"` (required for youtubedl-android)
- **Updated**: Application name to use `.YtDlpApplication`

#### New Files
- **YtDlpApplication.kt**: Application class that initializes YoutubeDL, FFmpeg, and Aria2c instances
- **MainActivity.kt**: Completely rewritten to use youtubedl-android Java API instead of Python/Chaquopy
  - Methods: `getVersion()`, `getVideoInfo()`, `getPlaylistInfo()`, `downloadVideo()`, `cancelDownload()`, `updateYoutubeDL()`
  - Uses MethodChannel `com.aerotube.youtube_downloader/ytdlp_android`
- **config.txt**: Default yt-dlp configuration file in `android/app/src/main/assets/`
  - Contains: `--no-mtime`, output template, format selector

#### Removed Files
- **python/yt_dlp_runner.py**: Python script no longer needed

### 2. Flutter/Dart Code

#### New Files
- **native_ytdlp_android.dart**: MethodChannel bridge to native youtubedl-android library
  - Methods: `getVersion()`, `getVideoInfo()`, `getPlaylistInfo()`, `downloadVideo()`, `cancelDownload()`, `updateYoutubeDL()`

#### Modified Files
- **ytdlp_service_android.dart**: 
  - Rewritten to use `NativeYtdlpAndroid` instead of `NativeYtdlpPython`
  - Download method now returns `processId` (String?) instead of `Process`
  - Removed Python-specific comments and references
  
- **mobile_download_provider.dart**:
  - Updated to work with process IDs instead of Process objects
  - New method `_trackDownloadById()` handles progress tracking via process ID
  - Removed Process stream handling code
  
- **ffmpeg_service_android.dart**:
  - Removed ffmpeg_kit_flutter_new imports
  - Simplified to indicate FFmpeg is bundled with youtubedl-android
  - All FFmpeg operations now handled internally by yt-dlp
  
- **main.dart**:
  - No Python-specific initialization needed
  - YtDlpApplication handles library initialization
  
- **pubspec.yaml**:
  - **Removed**: `ffmpeg_kit_flutter_new` dependency
  - FFmpeg now provided by youtubedl-android library

#### Deleted Files
- **native_ytdlp_python.dart**: No longer needed (replaced by native_ytdlp_android.dart)

### 3. Documentation

- **PLATFORM_SERVICES_GUIDE.md**: Updated to reflect youtubedl-android architecture instead of youtube_explode_dart

## Architecture Changes

### Before (Chaquopy/Python)
```
Flutter → MethodChannel → MainActivity.kt → Chaquopy → Python (yt_dlp_runner.py) → yt-dlp
```

### After (youtubedl-android)
```
Flutter → MethodChannel → MainActivity.kt → youtubedl-android library → yt-dlp (native)
```

## Key Features

### What's Included
1. **yt-dlp binary**: Bundled in the library, no separate download needed
2. **FFmpeg**: Included for audio extraction, format conversion, etc.
3. **Aria2c**: Optional external downloader for faster downloads
4. **Config file support**: Default options in `config.txt`
5. **Progress tracking**: Built-in progress callbacks
6. **Process management**: Start/stop downloads with process IDs
7. **Update support**: Update yt-dlp binary from within the app

### What's Removed
1. **Python runtime**: No longer needed (saves ~50MB)
2. **Chaquopy plugin**: Replaced by native library
3. **Python scripts**: All logic moved to Kotlin/Java
4. **ffmpeg_kit_flutter_new**: FFmpeg provided by youtubedl-android

## Configuration

### Default config.txt
Located at: `android/app/src/main/assets/config.txt`

```
--no-mtime
-o /sdcard/Download/youtubedl-android/%(title)s.%(ext)s
-f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
```

You can customize this file or create additional config files for different use cases.

## Build Configuration

### ABI Splits
The app now supports 4 architectures:
- `armeabi-v7a` (32-bit ARM)
- `arm64-v8a` (64-bit ARM)
- `x86` (32-bit x86)
- `x86_64` (64-bit x86)

Universal APK includes all architectures.

### Manifest Requirements
- `android:extractNativeLibs="true"` is **required**
- `android:requestLegacyExternalStorage="true"` for Android 10 compatibility
- Application name set to `.YtDlpApplication` for library initialization

## API Reference

### YtdlpServiceAndroid

#### Initialization
```dart
final service = YtdlpServiceAndroid();
await service.initialize();
```

#### Get Video Info
```dart
final info = await service.getVideoInfo(url);
```

#### Download Video
```dart
final processId = await service.downloadVideo(
  url: url,
  outputPath: '/sdcard/Download/youtubedl-android',
  formatId: 'best',
);
```

#### Cancel Download
```dart
await service.cancelDownload(processId);
```

#### Update yt-dlp
```dart
await service.update();
```

## Migration Notes

### For Developers
1. All Python code has been replaced with Kotlin/Java
2. Downloads now use process IDs instead of Process objects
3. FFmpeg operations are handled internally by yt-dlp
4. No manual FFmpeg binary management needed

### For Users
1. App size may be slightly larger due to bundled binaries
2. Downloads should be faster with aria2c support
3. No Python installation or setup required
4. Better compatibility across Android versions

## Testing Checklist

- [x] Flutter dependencies updated (`flutter pub get`)
- [x] Code analysis passes (`flutter analyze` - no errors)
- [ ] Android build succeeds (`flutter build apk`)
- [ ] Video info fetching works
- [ ] Playlist info fetching works
- [ ] Video download works
- [ ] Audio-only download works
- [ ] Progress tracking works
- [ ] Download cancellation works
- [ ] yt-dlp update works
- [ ] Cookies authentication works
- [ ] FFmpeg features work (format conversion, etc.)

## Known Limitations

1. **Direct FFmpeg commands**: Not exposed in the new implementation (handled by yt-dlp internally)
2. **Progress tracking**: Simulated in Flutter layer (native callbacks available but not fully integrated)
3. **Config file**: Currently static (could be made dynamic in future)

## Future Improvements

1. Implement proper progress callbacks from native to Flutter
2. Make config.txt dynamic (user-configurable)
3. Add download queue management
4. Implement batch download from clipboard
5. Add download speed tracking
6. Support for custom yt-dlp arguments

## References

- youtubedl-android: https://github.com/yausername/youtubedl-android
- Seal (example app): https://github.com/JunkFood02/Seal
- dvd (example app): https://github.com/yausername/dvd
- yt-dlp: https://github.com/yt-dlp/yt-dlp

## Version Information

- youtubedl-android version: 0.18.1
- Migration date: April 5, 2026
- Previous implementation: Chaquopy + Python yt-dlp
- New implementation: Native youtubedl-android library
