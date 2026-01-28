# Implementation Plan - Completion and Fixes

## 1. Merging Video with Audio
- **Problem**: High-resolution YouTube formats (1080p and above) separate video and audio streams. `yt-dlp` requires FFmpeg to merge them. The app was downloading, but without FFmpeg integration, it couldn't merge these streams or was only downloading video/audio separately.
- **Solution**:
    - Updated `YtdlpService` to accept `ffmpegPath`.
    - Updated `YtdlpService.downloadVideo` and `getVideoInfo` to pass `--ffmpeg-location` to the `yt-dlp` process.
    - Updated `SettingsProvider` to synchronize the `ffmpegPath` (managed by `FfmpegService`) to `YtdlpService`.
    - Updated `main.dart` to inject the initial `ffmpegPath` into `YtdlpService`.

## 2. Fixing Download Issues with yt-dlp
- **Status**: The app includes a built-in mechanism to download and update `yt-dlp` from the official GitHub releases.
- **Verification**: 
    - Verified the download URL for Windows is correct.
    - Verified the JSON parsing logic works with current `yt-dlp` output.
    - The merging fix also resolves "download issues" related to 4K/1080p downloads failing or lacking audio.

## 3. App Completion
- **Status**: Verified implementation of all screens (`HomeScreen`, `DownloadsScreen`, `SettingsScreen`) and services.
    - `DownloadsScreen` correctly displays progress and allows managing downloads.
    - `SettingsScreen` allows full configuration of paths, including manual overrides for `yt-dlp` and `ffmpeg`.
    - `AppTheme` and `AppConstants` are correctly defined.

The app is now fully functional with:
- Automatic tool management (downloading `yt-dlp` and `ffmpeg`).
- High-quality video downloading (merging enabled).
- Audio-only extraction.
- Custom path configuration.
