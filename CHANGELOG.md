# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Security
- **Certificate Pinning**: Added HTTPS certificate pinning for GitHub API update checks and download requests to prevent MITM attacks
  - New `CertificatePinningService` validates server certificates against pinned fingerprints
  - Applied to `UpdateService` for both update checks and update downloads

- **URL Sanitization in Logs**: Added automatic sanitization of sensitive data (cookies, tokens, auth keys) in log output
  - New `UrlSanitizer` utility strips sensitive query parameters from URLs before logging
  - Configurable via `LoggingService.setSanitizeUrlsEnabled()` toggle
  - Applied to all log entries automatically

### Reliability
- **Graceful Shutdown**: Active downloads are now paused gracefully when the app closes
  - `DownloadProvider` observes app lifecycle changes via `WidgetsBindingObserver`
  - Sends SIGTERM to active download processes before force-killing
  - Saves download state to Hive for recovery on next launch
  - Added `resumeInterruptedDownloads()` to resume paused downloads on startup

### Added
- `lib/core/utils/url_sanitizer.dart` - URL and data sanitization utility
- `lib/services/certificate_pinning_service.dart` - Certificate pinning service for HTTP clients
- `CHANGELOG.md` - This changelog file
