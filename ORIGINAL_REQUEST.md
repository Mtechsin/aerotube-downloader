# Original User Request

## 2026-09-12T09:53:21Z

Resolve the 4 core Android download pipeline flaws in AeroTube: migrate downloads to user-accessible public storage, enable direct "Open" and "Share" actions via FileProvider, implement persistence and session recovery across app kills/OEM battery termination, and connect live progress reporting to the foreground service notification.

Working directory: `e:\youtube downloader`
Integrity mode: development

## Requirements

### R1. User-Accessible Public Storage
Migrate Android downloads out of the hidden app-specific `Android/data/...` directory into public, user-visible directories (such as public `Downloads/AeroTube` or `Movies/AeroTube` via MediaStore/SAF or public scoped storage) so that downloads remain visible in Gallery/media apps and are preserved when the app is uninstalled.

### R2. Open & Share Actions for Completed Downloads
Implement "Open with" and "Share" functionality on finished download cards using the native `FileProvider` (`getContentUri` / `ACTION_VIEW` / `ACTION_SEND`) or standard platform plugins (`open_filex` / `share_plus`), and replace the mobile folder action which is currently a no-op empty closure (`() {}`).

### R3. Download Session Persistence & Process Kill Recovery
Persist active and queued downloads to local storage (e.g. Hive active downloads box, mirroring desktop resilience) so that if the application or foreground service is killed by Android or aggressive OEM battery managers, pending/in-progress downloads can be recovered and resumed/restarted on next launch. Add OEM autostart guidance or settings access where appropriate.

### R4. Real-Time Foreground Service Progress Notification
Wire the active download progress stream from download execution to the Android foreground service notification so that it reflects true percentage, speed, and state rather than remaining permanently static or indeterminate at 0%. Ensure notifications clear or transition cleanly upon completion or cancellation.

## Acceptance Criteria

### Storage & Accessibility
- [ ] Finished downloads are saved in public storage and visible in standard file managers and gallery apps.
- [ ] Uninstalling and reinstalling the app does not erase previously downloaded files.

### User Interaction
- [ ] Tapping "Open" on a completed download launches the appropriate media player via system intent.
- [ ] Tapping "Share" opens the Android system share sheet with a valid `content://` URI.
- [ ] The action button on mobile download cards is functional and no longer a no-op closure.

### Resilience & Recovery
- [ ] Killing the app process while downloads are active leaves persistent records that allow resuming or retrying upon restart.
- [ ] Battery optimization and background execution guidance alerts users on aggressive OEM devices (MIUI, HyperOS, ColorOS).

### Notification Accuracy
- [ ] The ongoing notification displays accurate real-time percentage progress and download state during execution.
- [ ] Upon download completion or cancellation, the notification updates or clears cleanly without orphan notifications.

## Verification Plan

### Automated Checks
- Run `flutter analyze` to ensure clean static analysis without lints or compilation errors across Dart code.
- Run `flutter test` to verify existing and new unit/provider tests pass.

### Code & Architecture Verification
- Verify `getExternalDownloadDir` / storage resolver targets public storage rather than `getExternalFilesDir`.
- Verify `getContentUri` and intent launchers are wired to card UI actions.
- Verify `MobileDownloadProvider` initializes and synchronizes with a persistent active downloads box.
- Verify progress events update the foreground notification builder with actual percentages.
