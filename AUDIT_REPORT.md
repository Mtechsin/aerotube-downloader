# AeroTube Audit Report — Bugs, Edge Cases, Performance, UX

Scope: full `lib/` (services, providers, UI). Method: static code audit + Jev (TypeSafe) fact-check of the highest-confidence findings.

- Jev-verified findings: **11 / 11 kept** (confidence 0.91–1.00). Results: `tool/jev_factcheck_results.json`, `tool/jev_factcheck_results_batch2.json`.
- Raw explorer counts: core services 50 · UI/UX 50. This report deduplicates and prioritizes.

**Severity key:** Critical = crash / data loss / feature dead · High = wrong result, stuck UI, or trust break · Medium = degraded UX / edge case · Low = polish.

---

## Executive summary

The biggest themes, in fix order:

1. **Desktop download queue races** — the same download can start twice; cancel during pre-flight leaves a zombie yt-dlp process.
2. **Timeout budget mismatch** — providers give up at 90s while the Windows service allows 6 minutes for playlists and 120s for video info. Large playlists always fail; the yt-dlp process is not cancelled.
3. **Title-only output template** — same-title videos are silently marked "already downloaded" pointing at the wrong file; `--merge-output-format` is never applied because the code reads the extension from an output *template*.
4. **Auth/cookie surfaces are inconsistent or dead** — Google OAuth client id is a placeholder; tokens are never wired into yt-dlp; cookie source priority can be silently overridden.
5. **Minimize pauses all downloads** — `AppLifecycleState.hidden` fires on Windows minimize and triggers graceful shutdown.
6. **UX trust breaks** — "Download started" toast fires before enqueue; duplicate URL tap is a silent no-op; cancel/history delete have no confirmation; mobile History hides cancelled items.

---

## Critical

### C1. Desktop provider can start the same download twice
**File:** `lib/providers/download_provider.dart:534–557, 560–659`  
`_processQueue()` only counts `downloading*` items. `_startDownloadInternal` awaits disk-space pre-flight *before* flipping status to `downloadingVideo`. A second `_processQueue()` (from another enqueue/pause/completion) picks the same still-`queued` item → two yt-dlp processes; the second overwrites `_activeProcesses[id]` and the first is leaked forever.  
**Fix:** Mark items "starting" (or use `_currentlyProcessingIds` like mobile) synchronously before the first `await`.

### C2. Cancel/pause during pre-flight → orphan yt-dlp process
**File:** `lib/providers/download_provider.dart:560–648, 893–928`  
After `await _getAvailableDiskSpace(...)` the code never re-checks item status before spawning yt-dlp. User cancels a queued item → it moves to history as cancelled, but the process still starts, `indexWhere` returns −1, exit handling is skipped, and the download runs to completion untracked.  
**Fix:** Re-validate status/id membership after every await and bail before spawning (mobile already does this at `mobile_download_provider.dart:896–902`).

### C3. Provider 90s timeout vs service 6-min playlist budget — large playlists always fail
**Files:** `lib/providers/playlist_provider.dart:113–119` · `lib/providers/video_provider.dart:746–752` · `lib/services/ytdlp/ytdlp_service_windows.dart:1176–1181`  
Providers throw at 90s; the Windows service is allowed 6 minutes. Any playlist over 90s errors. The provider timeout does **not** call `cancelFetch()`, so yt-dlp keeps running as a zombie while its result is discarded. Same class of mismatch for video info (90s vs 120s service budget).  
**Fix:** Provider timeout ≥ service budget; call `cancelFetch()` on timeout.

### C4. Google OAuth client id is a placeholder — login is dead
**Files:** `lib/services/core/auth_service.dart:21–24` · `lib/services/cookie/cookie_service_android.dart:24–27`  
```dart
static const String _clientId =
    'YOUR_CLIENT_ID.apps.googleusercontent.com'; // TODO: Replace with your actual Google OAuth client ID
```
Used directly in authorize URL and token exchange. Also `AuthService` tokens are **never** converted into cookies/`--cookies-from-browser` state — even a working login would not affect downloads. Android redirect scheme (`com.youtube.downloader:/oauth2callback`) does not match the app id used elsewhere (`com.aerotube.youtube_downloader`).  
**Fix:** Inject real client ids via `--dart-define`, align redirect scheme, and either wire tokens into yt-dlp or remove the dead flow.  
**Jev:** KEEP · support=1.00

### C5. Title-only output template → silent wrong-file "completion"
**Files:** `lib/providers/download_provider.dart:619` · `lib/services/ytdlp/ytdlp_service_windows.dart:1318, 1530–1532`  
`-o dir\%(title)s.%(ext)s`. Two videos with the same title (or a re-download while the first file exists) hit yt-dlp's "has already been downloaded" skip; the new item is marked completed pointing at the *old* file. Concurrent downloads into the same folder also race `findDownloadedFile`'s newest-mtime heuristic (Android prefers native filepath; Windows has no such path).  
**Fix:** Include `%(id)s` in the template; parse yt-dlp's `--print after_move:filepath`; stop treating "already been downloaded" as success without identity check.

### C6. Minimizing the window pauses every download
**File:** `lib/providers/download_provider.dart:185–191`  
```dart
if (state == AppLifecycleState.detached ||
    state == AppLifecycleState.hidden) {
  _initiateGracefulShutdown();
}
```
On Windows, `hidden` fires when the window is minimized/occluded — not only on exit. All running downloads are killed and marked paused.  
**Fix:** Shut down only on `detached` (never on `hidden` for desktop).

### C7. Forced null unwrap can crash
**Files:** `lib/ui/screens/home_screen.dart:60–61` · `mobile_home_screen.dart:55–56`  
`ErrorHelper.parse(_videoProvider!.errorMessage!)` while `hasError` is true. If error state is set without a message, red screen.  
**Fix:** Early-return when `errorMessage` is null.

### C8. Mobile back button cannot exit the app on Home tab
**File:** `lib/ui/screens/mobile_home_layout.dart:27–34`  
`PopScope(canPop: false)` swallows back when `currentIndex == 0`. Users cannot leave the app with back.  
**Fix:** Allow pop / `SystemNavigator.pop` when already on tab 0.

### C9. Update dialog "Checking" is an unescapable trap
**Files:** `lib/ui/widgets/update_dialog.dart:73–107` · shown with `barrierDismissible: false` from `app.dart:79–83`  
No Cancel/Close while status is `checking`. Slow/hung GitHub check soft-locks the app.  
**Fix:** Cancel button on checking state; allow dismiss after timeout.

---

## High

### H1. `searchVideosRaw` / `update()` use `Process.run().timeout()` — zombie yt-dlp
**File:** `lib/services/ytdlp/ytdlp_service_windows.dart:1278–1283, 255–257`  
Same class of bug the file itself documents for `_runWithTimeoutTracked`. Dart throws; the native process keeps running.  
**Fix:** `Process.start` + `exitCode.timeout` + `kill()`.

### H2. Android `cancelFetch` only bumps a generation counter
**File:** `lib/services/ytdlp/ytdlp_service_android.dart:54–58`  
Native extraction keeps running after cancel; rapid cancel/retry stacks native jobs.  
**Fix:** Expose native cancel keyed by request id.

### H3. `--merge-output-format` is dead code for dual-stream downloads
**File:** `lib/services/ytdlp/ytdlp_service_windows.dart:1354–1363`  
`p.extension(outputPath)` is called on the template `dir\%(title)s.%(ext)s` → extension is `.%(ext)s` → never matches `['mp4','mkv','ogg','webm','flv']`. Container is never forced.  
**Fix:** Pass the concrete container from settings, not from the template path.  
**Jev:** KEEP · support=1.00

### H4. `activeCookieSource` returns `'browser'` when nothing is configured
**File:** `lib/services/ytdlp/ytdlp_service_windows.dart:124–128`  
`null != 'none'` is true in Dart → returns `'browser'` when `_cookiePath` and `_cookieBrowser` are both null.  
**Fix:** Null-check before comparing.  
**Jev:** KEEP · support=0.93

### H5. Cookie browser choice is undone on next launch
**File:** `lib/providers/platform_settings_provider.dart:438–445` vs `210–216`  
`setCookieBrowser` nulls the service `cookiePath` but never clears persisted `settings.cookiePath`. On init the file wins (priority file > browser).  
**Fix:** Persist `cookiePath = null` when a browser is selected (and vice versa).

### H6. WebView login silently wipes cookie file/browser settings
**File:** `lib/providers/platform_settings_provider.dart:260–279`  
Any non-empty `webview_cookies` dir forces Edge-profile cookies and clears the user's explicit cookie config with no notice.  
**Fix:** Require a real login signal before overriding.

### H7. Hardcoded Chrome 120 UA + Edge cookies-from-browser
**File:** `lib/services/cookie/cookie_service.dart:91–95`  
UA/cookies-from-browser mismatch is a known bot-detection trigger.  
**Fix:** Read the real UA from the WebView session, or omit `--user-agent` when using browser cookies.

### H8. Unbounded static video-info cache on Android
**File:** `lib/services/ytdlp/ytdlp_service_android.dart:70–72, 429–437`  
Full format ladders retained for process lifetime; expired entries never evicted. Windows caps at 30.  
**Fix:** Mirror Windows LRU + purge expired on write.

### H9. Explode preview can land after yt-dlp error → contradictory UI
**File:** `lib/providers/video_provider.dart:331, 424–495`  
Provider can hold both `_errorMessage` and a preview `VideoInfo`.  
**Fix:** Bail preview when `_errorMessage != null` for the same gen.

### H10. `clear()` does not cancel in-flight fetch — state repopulates
**File:** `lib/providers/video_provider.dart:800–820`  
No `_fetchGen++` / `cancelFetch()`. Running fetch completes and repopulates after clear.  
**Fix:** Bump gen + cancel in `clear()`.

### H11. HEAD size probing resets the user's format selection
**File:** `lib/providers/video_provider.dart:629–691`  
Background probe finishing after the user picked 4K yanks selection back to defaults via `_processFormats()`.  
**Fix:** Preserve current selection by height/formatId across probe-driven re-processing.

### H12. Desktop `_startDownloadInternal` catch path can throw while handling failure
**File:** `lib/providers/download_provider.dart:980–988`  
`_downloadsBox.get(k)!` during history trim throws on corrupted entries → finished/failed download never recorded.  
**Fix:** Per-key try/catch during trim (same as `_loadHistory`).

### H13. `_saveActiveDownloads` is clear-then-put — crash loses all active state
**File:** `lib/providers/download_provider.dart:1062–1068`  
Not atomic. Crash between clear and put drops every in-flight item.  
**Fix:** Diff-and-put, or temp box then swap.

### H14. Deep-link playlist heuristic misroutes `watch?v=…&list=…`
**Files:** `lib/services/deep_link_handler.dart:40–42` · `lib/ui/screens/home_screen.dart:670–678` · `lib/core/utils/url_validator.dart:74–78`  
Any URL containing `list=` opens the playlist flow. Desktop home does this unconditionally; mobile correctly requires `!url.contains('v=')`. Inconsistent.  
**Fix:** Treat as playlist only for `/playlist` paths or when `v=` is absent.  
**Jev:** KEEP · support=1.00

### H15. Deep-link same-URL forever-dedup
**File:** `lib/services/deep_link_handler.dart:36–39`  
Sharing the same link twice in one session does nothing (no fetch, no feedback).  
**Fix:** Time-window dedup (2–3s).

### H16. `isBrokenExtractorError` matches bare `outdated` / `signature`
**File:** `lib/core/utils/error_helper.dart:73–86, 270–287`  
Any stderr containing "outdated" or "signature" (TLS certificate signature failure, a title containing "signature") triggers "Extractor Update Required" and can auto-download yt-dlp.  
**Fix:** Match yt-dlp-specific phrasing only.  
**Jev:** KEEP · support=0.98

### H17. Mobile History hides cancelled downloads
**Files:** `lib/ui/screens/downloads_screen.dart:624–631` · `lib/providers/mobile_download_provider.dart:171–189`  
`_MobileHistoryDownloadsView` selects only `completedDownloads + failedDownloads`. Cancelled is terminal, persisted, and has a dedicated `clearCancelled()` — but never rendered. Desktop History shows them.  
**Fix:** Include cancelled (or add a third filter).  
**Jev:** KEEP · support=1.00

### H18. "Download started" SnackBar fires before enqueue succeeds
**File:** `lib/ui/screens/home_screen.dart:716–776`  
`startDownload(...)` is not awaited; toast + `videoProvider.clear()` run immediately. Enqueue failure → user saw success and lost the fetched video.  
**Fix:** Await, handle errors, only then toast + clear.

### H19. Silent no-op on duplicate URL tap
**File:** `lib/providers/download_provider.dart:383–397`  
Logging-only return. Button press appears broken.  
**Fix:** SnackBar "Already in queue".  
**Jev:** KEEP · support=1.00

### H20. Destructive actions without confirmation
- Clear Finished — `downloads_screen.dart:191–200` (no confirm; mobile also wipes failed+cancelled)
- Delete history item — `downloads_screen.dart:638–639`
- Cookie Logout — `settings_screen.dart:1201–1206`
- Clear logs — `logs_viewer.dart:63–69`

### H21. Fixed 136px download card clips title + error + progress
**File:** `lib/ui/widgets/download_item_card.dart:69–72, 197–209`  
Hard-coded height; failed items with 2-line titles lose the error line.  
**Fix:** Intrinsic height, `mainAxisSize: min`.  
**Jev:** KEEP · support=0.91

### H22. Double-tap Fetch pushes two result screens / starts two fetches
**Files:** `mobile_home_screen.dart:288–307` · `home_screen.dart:662–682` · `search_screen.dart:327–341`  
**Fix:** `isNavigating` guard / disable while loading.

### H23. Auth dialog re-opens after dismiss
**File:** `lib/ui/screens/home_screen.dart:51–91`  
`_isShowingAuthDialog` only prevents stacking. After dismiss, any later notify while `hasError` re-opens the dialog.  
**Fix:** Track last-shown error identity.  
**Jev:** KEEP · support=1.00

### H24. Playlist controls / thumbnail overflow on narrow windows
**Files:** `playlist_screen.dart:418–489` · `playlist_video_card.dart:59–61` (fixed 180px thumb)  
**Fix:** `Wrap`/`Flexible` + `AspectRatio`.

### H25. Desktop download-button progress fill uses wrong width basis
**File:** `video_configuration_widget.dart:1092–1104`  
`MediaQuery.size.width * 0.65 * progress` ≠ actual button width.  
**Fix:** `FractionallySizedBox` / `LayoutBuilder`.

### H26. `AnimatedButton` looks active when `onPressed` is null
**File:** `animated_button.dart:28–55`  
No disabled visual; still scales on press. No Semantics.  
**Fix:** Ignore pointer + opacity when disabled; wrap in `Semantics`.

### H27. Mobile URL card reads clipboard on every focus
**File:** `mobile_url_input_card.dart:56–73, 143–146`  
Android 13+ clipboard toast every focus; privacy surprise.  
**Fix:** Read only on explicit Paste tap.

### H28. "Open folder" failures are silent on desktop history
**Files:** `history_downloads_tab.dart:77–80` · `download_item_card.dart:35–54`  
Result ignored / only logged.  
**Fix:** SnackBar on failure.

### H29. Playlist cancel surfaces as a hard error
**File:** `ytdlp_service_windows.dart:1174–1205`  
`cancelFetch()` kills the process; exit ≠ 0 → "Failed to fetch playlist info".  
**Fix:** Dedicated Cancelled exception the providers swallow.

### H30. Disk-space pre-flight hard-fails on heuristic sizes
**Files:** `download_provider.dart:563–597` · `mobile_download_provider.dart:859–874`  
Bitrate-table estimates (e.g. 14 Mbps for 4K) can exceed real free space + 100 MiB buffer and hard-fail a download that would have fit.  
**Fix:** Hard-fail only on exact/approx sizes; treat heuristics as warnings.

---

## Medium (selected)

| # | Issue | Location |
|---|---|---|
| M1 | `looksLikePlaylist` / desktop home treats any `list=` as playlist | `url_validator.dart:74–78` · `home_screen.dart:670–678` |
| M2 | Desktop `_throttledNotify` is leading-edge only — last progress tick can drop | `download_provider.dart:75–83` (**Jev KEEP 1.00**) |
| M3 | `findDownloadedFile` id branch never matches (filename is title, not composite id) | `downloaded_file_finder.dart:36–39` (**Jev KEEP 0.94**) |
| M4 | Windows `.webm` destination treated as video (Opus audio is also `.webm`) | `ytdlp_service_windows.dart:1507–1527` |
| M5 | `NotificationService.show('Fetch Complete')` on every metadata fetch — spam | `ytdlp_service_windows.dart:897` |
| M6 | `getVideoInfo` retries without cookies on *any* error when cookies are on | `ytdlp_service_windows.dart:780` |
| M7 | FFmpeg update checks gyan.dev tag but installs BtbN binary | `ffmpeg_service_windows.dart:173–218` |
| M8 | Tool-update debounce timestamp only set on success → API hammering on failure | `tool_update_provider.dart:241–243` |
| M9 | Mobile: no stall watchdog if EventChannel dies — downloads stuck forever | `mobile_download_provider.dart:568–587` |
| M10 | History corruption-recovery silently switches to `_recovered` box | `download_provider.dart:116–136` |
| M11 | `_processFormats` cache path hard-codes 1080p, ignores preferred quality | `video_provider.dart:501–517` |
| M12 | Clear Finished: mobile wipes completed+failed+cancelled; desktop only completed | `downloads_screen.dart:192–199` |
| M13 | Desktop loading state is a blank gap (`SizedBox.shrink`) | `video_configuration_widget.dart:158–161` |
| M14 | Same error shown twice on desktop home (capsule + full-page state) | `home_screen.dart:138–161` |
| M15 | Mobile playlist batch ignores user format/quality choices | `mobile_result_screen.dart:354–368` |
| M16 | Search has no cancel; load-more errors invisible | `search_screen.dart:132–244` |
| M17 | YouTube login "Done" returns success without verifying login | `youtube_login_screen.dart:359–378` |
| M18 | Onboarding can swipe past the permission page | `onboarding_screen.dart:154–165` |
| M19 | Undersized touch targets (`BoxConstraints()` collapse hit area) | `downloads_screen.dart:878–899` |
| M20 | Low-contrast `Colors.grey[400]` labels in light theme | `downloads_screen.dart:433–439` |
| M21 | Floating log overlay covers app chrome; unbounded log stack | `floating_progress_overlay.dart:16–46` |
| M22 | `UpdateProvider.downloadUpdate` notifies every chunk (no throttle) | `update_provider.dart:126–131` |
| M23 | Windows asset picker may grab wrong-arch installer | `update_service.dart:260–272` |
| M24 | `cmd /c start "" path` breaks on `&` / quotes | `file_action_service.dart:90` |
| M25 | `VideoInfo.fromJson` may set url to a direct CDN stream URL | `video_info.dart:260` |
| M26 | `getDefaultOutputPath` can produce a relative path | `platform_settings_provider.dart:123–127` |
| M27 | Cookie toggle row is whole-row GestureDetector + tiny Switch | `mobile_home_screen.dart:394–448` |
| M28 | `PlaylistProvider.isAllSelected` breaks with duplicate video IDs | `playlist_provider.dart:49–50` |

---

## Low (notable)

- Theme toggle only on desktop Home (`home_screen.dart:684–714`)
- `GradientBackground` is a flat color (`gradient_background.dart:15–18`)
- User-log close button 18px, no hit target (`floating_progress_overlay.dart:105–112`)
- Raw `substring` title truncation can split surrogate pairs (`floating_progress_overlay.dart:418`)
- `CompletionPop.recent` 5s wall-clock window (`motion_effects.dart:27–37`)
- Desktop "New URL" on error does not clear provider error (`home_screen.dart:594–598`)
- Curl single-download progress parsing dead (`\r` vs `\n`) (`download_helper.dart:230–243`)
- Mixed `SystemEncoding` vs `utf8` stdout decode (`download_provider.dart:662`)
- `YtdlpService.update()` fallback always uses Windows binary URL (`ytdlp_service_windows.dart:273–278`)
- Windows DownloadProvider hardcodes `\\` and `explorer` (`download_provider.dart:619, 787`)
- Hardcoded greys instead of theme tokens (`downloads_screen.dart:242, 297`)
- Fake progress in unused `MobileInitializationOverlay` (`mobile_home_screen.dart:517–678`)
- No Semantics on custom chips (resolution/mode/quality) — screen-reader unusable

---

## Jev fact-check ledger

| Finding | Action | Support | Conf |
|---|---|---|---|
| activeCookieSource null → `'browser'` | keep | supported | 0.93 |
| `--merge-output-format` dead (template path) | keep | supported | 1.00 |
| `looksLikePlaylist` false positives | keep | supported | 1.00 |
| `outdated`/`signature` overmatch | keep | supported | 0.98 |
| Desktop leading-edge throttle drops last tick | keep | supported | 1.00 |
| file finder id-branch never matches | keep | supported | 0.94 |
| Silent duplicate-URL no-op | keep | supported | 1.00 |
| OAuth placeholder client id | keep | supported | 1.00 |
| Mobile History hides cancelled | keep | supported | 1.00 |
| Fixed 136px card clipping | keep | supported | 0.91 |
| Auth dialog re-surface after dismiss | keep | supported | 1.00 |

Scripts: `tool/jev_factcheck_audit.py`, `tool/jev_factcheck_batch2.py`.

---

## Recommended fix order

1. **Queue correctness (C1, C2, C6)** — in-flight guard + status re-check + stop shutting down on `hidden`.
2. **Timeouts + zombies (C3, H1)** — align budgets, always kill on timeout.
3. **Output identity (C5, H3, M3)** — `%(id)s` in template, print final filepath, fix merge-format.
4. **Auth honesty (C4, H5, H6, H7)** — real client ids or remove dead OAuth; persist cookie source symmetrically; stop UA mismatch.
5. **UX trust (H18, H19, H17, H20, H23, C7, C8, C9)** — await before success toast, feedback on duplicate, confirm destructive actions, fix back button / update-dialog traps.
6. **Layout & a11y (H21, H24, H25, H26, M19, M20)** — intrinsic heights, flexible playlist chrome, disabled button state, 48px targets, theme tokens.
