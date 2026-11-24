# Windows UI redesign

The `before` folder contains screenshots captured from the original running Windows application. The `after` folder contains headless Flutter renders of the redesigned Windows UI. These renders use the actual screen widgets with isolated sample data, so they can be regenerated without bringing an application window to the foreground or changing your account, history, or preferences.

## Main screens

| Screen | Dark | Light |
| --- | --- | --- |
| Home | [Preview](after/home-dark-1280.png) | [Preview](after/home-light-1280.png) |
| Search | [Preview](after/search-dark-1280.png) | [Preview](after/search-light-1280.png) |
| Downloads | [Preview](after/library-dark-1280.png) | [Preview](after/library-light-1280.png) |
| Settings | [Preview](after/settings-dark-1280.png) | [Preview](after/settings-light-1280.png) |
| Video options | [Preview](after/video-options-dark-1280.png) | [Preview](after/video-options-light-1280.png) |
| Playlist | [Preview](after/playlist-dark-1280.png) | [Preview](after/playlist-light-1280.png) |

Each screen also has a 960 × 640 render and a compact 640 × 720 render with text scaled to 130%. All 36 renders check for Flutter layout exceptions.

## What changed

- Shared dark slate and light surface colors, consistent type, and readable primary button text.
- Sidebar navigation remains available in small Windows windows, with keyboard focus and compact icons.
- Home uses one centered workspace with a prominent Choose format action, a visible save folder, and recent activity underneath.
- The header has one quiet readiness indicator; activity uses readable dates, explicit completion labels, and a View library action.
- Search has an explicit submit button, recent searches, and a simple empty state.
- Downloads has compact tabs, a labeled folder action, clearer progress rows, and grouped history actions.
- Video options adapt between two panes and a scrollable compact layout with a pinned download action.
- Playlist selection uses quieter selected rows, clearer batch controls, and a pinned batch-download action.
- Settings separates account sign-in from cookie readiness, improves section spacing, and shares dialog styling.
- Tools appear first in Settings. Android update actions use icon buttons with labels for assistive technology.
- App icons use rounded Material Symbols, with filled navigation icons for the selected destination.
- Component motion uses linear curves. Android result routes use predictive back transitions.
- Rounded inputs no longer contain a second rectangular fill. Duplicate desktop download-progress overlays are removed.

## Verification

The verification logs are saved in `../ui-test-results.txt`, `../ui-render-results.txt`, and `../windows-debug-build.txt`. The Windows executable is at `../../build/windows/x64/runner/Debug/youtube_downloader.exe`.

To regenerate the screenshots without opening a window:

```powershell
flutter test test/ui/desktop_design_test.dart --dart-define=WRITE_UI_SCREENSHOTS=true
```

These checks validate presentation and existing automated behavior. They do not perform a real network download or authenticate a YouTube account.

Android Search and Settings previews are also generated at 320 and 360 pixels wide with text enlarged to 150%. The latest UI checks are recorded in `../material-ui-test-results.txt` and `../material-ui-analysis.txt`. The system back gesture still needs verification on an Android device.
