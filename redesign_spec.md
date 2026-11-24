# AeroTube — Clean Modern Redesign Spec (Android + Windows)

> **Suggestion / Architecture Spec Document.**  
> Stack: Flutter 3 / Material 3, provider, flutter_animate, Manrope font.

---

## 1. What the app already is (the design DNA to KEEP)

*Read from `app_theme.dart`, `app_motion.dart`, `app_navigation_rail.dart`, `mobile_home_screen.dart`, `home_screen.dart`.*

| Principle | Current implementation | Keep? |
| :--- | :--- | :--- |
| **Minimal, content-first** | Pure black / pure white backgrounds, almost no chrome | **Yes** |
| **One accent** | Violet `#8B5CF6` only | **Yes** |
| **Hairline borders, not shadows** | Outline `#FFFFFF` @ 20% dark / `#000` @ 13% light | **Yes** |
| **Single typeface** | Manrope; 800 weight headlines, 300 "Tube" in the logo | **Yes** |
| **Soft rounded geometry** | Radii 12 / 14 / 16 / 18 | **Yes (formalize)** |
| **M3 Expressive motion** | Spring curves, FadeForwards page transitions, reduce-motion respected | **Yes** |
| **Calm empty states** | Centered headline + one input + a few pills | **Yes** |
| **Wordmark** | Aero(800, onSurface) + Tube(300, violet) | **Yes, make it the brand anchor** |

---

## 2. What is weak today (the redesign targets)

1. **Flat hierarchy**: Pure black + black cards + 12% borders means cards, inputs and background all look the same. Depth comes only from borders.
2. **No tokens**: Colors and sizes are hard-coded in widgets (`Color(0xFF9C9CA1)`, `Colors.orange`, `Colors.red`, `fontSize: 11/13/14`, `alpha: 0.58`, etc.). `GlassCard`, `SurfaceCard`, `Container` cards and `Card` all coexist.
3. **Mobile has no persistent navigation**: `MobileShell` is an `IndexedStack`. Downloads and Settings are reached through small top-bar icons, and Search through a FAB. Not discoverable and not thumb-friendly.
4. **Desktop rail is icon-only**: (80 px, `labelType: none`). Four unlabeled glyphs vertically centered, with the account avatar at the bottom. Status banners and the theme toggle float at the top-right.
5. **Status is scattered**: Tool state (yt-dlp / FFmpeg), cookie state and initialization appear as banners, pills and toggles in different places.
6. **Download card is dense**: 160 px thumbnail + title + actions + badge + speed + ETA + progress, all in one row, with a box shadow that clashes with the border-only language.
7. **Hover scale of 1.02 on cards causes visual jitter** and implies layout shift. Hover should be a tonal change, not a scale.
8. **Duplicate widgets per platform**: `url_input_card` vs `mobile_url_input_card`, `video_configuration_widget` vs `mobile_video_configuration_widget`. The two sides drift visually.
9. **Dead-simple text scale**: `ResponsiveLayout.getFontScale` exists but the text theme defines only a few styles.

---

## 3. Redesign concept: "Aero Calm"

Same black / white / violet minimalism, but with layered tonal surfaces, a real token system, persistent navigation on both platforms, and one shared component library used identically on Android and Windows.

> **Three words**: quiet, layered, fast.

---

## 4. Design tokens (create `lib/core/theme/tokens/`)

### 4.1 Color

Keep OLED black for dark. Add tonal steps so layers are visible without borders.

| Token | Dark | Light |
| :--- | :--- | :--- |
| `bg` | `#000000` | `#FFFFFF` |
| `surface1` (cards, nav) | `#0E0E10` | `#F7F7F9` |
| `surface2` (inputs, chips, raised) | `#161619` | `#EFEFF3` |
| `surface3` (hover, pressed, selected row) | `#1F1F24` | `#E6E6EC` |
| `outline` (hairline) | `#FFFFFF` @ 10% | `#000000` @ 8% |
| `outlineStrong` (focus, dividers on hover) | `#FFFFFF` @ 20% | `#000000` @ 16% |
| `onSurface` | `#F5F5F5` | `#111111` |
| `onSurfaceMuted` | `#A1A1A8` | `#6B6B72` |
| `onSurfaceFaint` | `#6E6E75` | `#9A9AA1` |
| `primary` | `#8B5CF6` | `#7C3AED` (slightly deeper for AA contrast on white) |
| `primarySoft` (selected bg) | `primary` @ 16% | `primary` @ 10% |
| `primaryGlow` (focus ring, progress head) | `primary` @ 35% | `primary` @ 25% |
| `success` | `#34D399` | `#059669` |
| `warning` | `#FBBF24` | `#D97706` |
| `danger` | `#F87171` | `#DC2626` |
| `info` | `#60A5FA` | `#2563EB` |

**Rules:**
- Expose as a `ThemeExtension<AeroColors>` so widgets read `context.aero.surface2`. Kills every hard-coded hex.
- Status colors always render as color @ 12% fill + color icon/text + color @ 24% border (same pattern as current compact status banner).
- Optional brand gradient (use only on logo glow, primary progress bar head and onboarding hero): `#8B5CF6` -> `#6366F1`.

---

### 4.2 Typography (Manrope, define the full M3 scale)

| Role | Size / Line | Weight | Tracking | Use |
| :--- | :--- | :--- | :--- | :--- |
| `display` | 40 / 44 | 800 | -1.0 | Desktop hero only |
| `headline` | 28 / 34 | 800 | -0.6 | Screen titles |
| `title` | 20 / 26 | 700 | -0.2 | Section headers, dialogs |
| `titleSm` | 16 / 22 | 700 | 0 | Card titles |
| `body` | 14 / 21 | 500 | 0 | Default text |
| `bodySm` | 13 / 19 | 500 | 0 | Secondary text |
| `label` | 12 / 16 | 600 | +0.2 | Chips, badges, buttons |
| `caption` | 11 / 14 | 500 | +0.3 | Meta (speed, ETA, size) |
| `mono` | 12 / 16 | 500 | 0 | Logs, paths, URLs (system mono) |

**Rules:**
- Use `FontFeature.tabularFigures()` on speed, ETA, percent and size so numbers do not jitter.
- No raw `fontSize:` in widgets.

---

### 4.3 Spacing, radius, size

- **Spacing scale (4-pt)**: 4, 8, 12, 16, 20, 24, 32, 48.
- **Page padding**: Android 20, Windows 32.
- **Radius scale**:
  - `sm`: 10 (chips, badges)
  - `md`: 14 (inputs, buttons, tiles)
  - `lg`: 18 (cards, FAB)
  - `xl`: 24 (sheets, dialogs, hero input)
  - `full`: 999 (pills, progress)
- **Touch targets**: Android min 48 dp. Windows min 36 px height for controls, 40 px for nav items.
- **Elevation**: None. Replace all `BoxShadow` on cards with tonal `surface1` plus hairline. Only floating overlays (mini-player, menus, dialogs) get one soft shadow `0 8 24 black@40%` (dark) or `black@12%` (light).

---

### 4.4 Iconography

- Use rounded Material Symbols consistently (`*_rounded`).
- Outlined when inactive, filled when active.
- Size 20 in dense rows, 24 in nav, 28 in empty states.
- Never mix `Icons.x_outlined` with `Icons.x_rounded` in the same surface.

---

### 4.5 Motion (extend existing AppMotion, do not replace it)

Keep `fast` (150 ms), `short` (200 ms), `medium` (350 ms), `long` (500 ms) and the three springs. Add intent tokens:
- **press**: scale 0.97, fast, `snappySpring` on release.
- **hover (desktop)**: tonal change `surface1` -> `surface3` over 120 ms. No scale.
- **enter**: fade + 8 px slide-up, medium, decelerate, stagger 40 ms, max 6 items.
- **selectionMorph**: nav indicator slides between items with `spatialSpring`.
- **completion**: one-shot `bounceSpring` check-mark pop, nothing else celebrates.
- Always route through `appMotionDuration()` so reduce-motion works.

---

## 5. Shared component library (one set, both platforms)

Put in `lib/ui/components/`. Each takes density (compact for Windows, comfortable for Android) instead of being duplicated.

| Component | Replaces | Spec |
| :--- | :--- | :--- |
| `AeroScaffold` | per-screen Scaffold/SafeArea | Chooses bottom bar (Android) vs rail (Windows) vs top-bar slots; owns page padding and max-width |
| `AeroCard` | GlassCard, SurfaceCard, Container cards | `surface1`, hairline outline, radius `lg`, optional hover (tonal) and selected (`primarySoft` + `primary` hairline) |
| `AeroTextField` | UrlInputCard, MobileUrlInputCard field | 56 dp (Android) / 48 px (Windows), radius `xl`, `surface2` fill, focus = primary hairline + 3 px `primaryGlow` ring |
| `UrlComposer` | both URL cards | Field + inline Paste + Fetch; state machine: idle, valid, loading (inline progress line along bottom edge), error (inline, below) |
| `AeroButton` (primary, tonal, ghost, danger) | Elevated/Filled/Outlined mixes | Height 48 / 40; primary uses solid violet, tonal uses `surface2`, ghost uses text only |
| `AeroChip` / `FormatChip` | Choice/Filter chips | Radius `sm`; selected = `primarySoft` + `primary` text |
| `StatusPill` | banners, pills, cookie row | success/warning/danger/info/neutral + optional dot or spinner; tap opens details sheet |
| `AeroProgress` | LinearProgressIndicator | 4 px track, 999 radius, primary fill with faint glow at head; indeterminate = shimmer |
| `ThumbnailTile` | thumbnail code duplicated in cards | 16:9, radius `md`, duration chip bottom-right, skeleton shimmer while loading |
| `SectionHeader` | ad-hoc Text | label style, uppercase, `onSurfaceMuted`, 24 px top margin |
| `SettingsRow` | ListTile | Icon in a 36 px `surface2` rounded square, title, subtitle, trailing control or chevron |
| `AeroSheet` / `AeroDialog` | AlertDialog / bottom sheets | Radius `xl`, drag handle on Android sheets, Windows uses centered 480 px dialog, same content widget |
| `EmptyState` | hand-built centers | Icon in 72 px tonal circle, title, one-line `bodySm`, one primary action |
| `AeroSnack` | SnackBar variants | Floating, radius `md`, leading status icon, max 1 action |

---

## 6. Navigation and shell

### 6.1 Android (phone)
- **Bottom navigation bar, 4 destinations**: Home, Search, Library (with badge for active count), Settings.
  - Height 64 + safe area, `surface1` background, hairline top border, pill indicator (`primarySoft`) behind active icon, label always visible at 11 sp.
- Remove Search FAB and top-bar Files/Settings icons (redundant).
- Top bar on Home: wordmark on left, single `StatusPill` (tools / cookies) + avatar on right.
- Back from non-Home tab returns to Home, then exits (keep current `PopScope` behavior).
- **Mini download tray**: persistent 56 dp bar above bottom nav showing top active download, thin progress line and pause/cancel. Replaces current floating overlay position conflict. Tap expands to Library tab.

### 6.2 Android (tablet / foldable, width >= 600)
- `NavigationRail` (labels visible) instead of bottom bar.
- Breakpoints: compact < 600, medium 600-1023, expanded >= 1024.

### 6.3 Windows
- **Left sidebar**: 232 px expanded / 72 px collapsed (user toggle, remembered). Not icon-only.
  - Top: wordmark (collapsed = "A" glyph).
  - Middle: Home, Search, Library (badge), Settings (40 px tall, 12 px radius, `primarySoft` fill + 3 px violet bar at left for active).
  - Bottom: account row (avatar + "Guest" or channel name + cookie status dot), then theme toggle.
- **Top strip** (48 px, transparent): window drag area, breadcrumb or page title on left, global `StatusPill` cluster on right. Removes floating top-right stack.
- **Keyboard**:
  - `Ctrl+V`: focus composer and paste
  - `Ctrl+1..4`: switch tabs
  - `Ctrl+,`: open Settings
  - `Esc`: clear / cancel
  - `Enter`: fetch
  - Show shortcuts in tooltips.
- Min window: 960 x 640. Content max width 1100, centered.

---

## 7. Screen-by-screen

### 7.1 Home

#### Android (idle)
```
[AeroTube]                         [pill][avatar]
 
 
          Download anything,
          cleanly.                       (headline 28, 800)
   Paste a link. Pick a format.          (bodySm, muted)
 
 [ Paste a video URL…        ⎘  → ]      (UrlComposer, 56dp, radius xl)
 
 Recent                                   (SectionHeader)
 [thumb] Title…        1080p MP4  ✓      (3 most recent, tap = re-open)
 [thumb] Title…        MP3       ✓
 
 ─ cookie/sign-in status row (StatusPill, tappable) ─
[Home][Search][Library•2][Settings]
```
- Composer sits upper-middle (~35% from top), above keyboard.
- Clipboard suggestion chip under composer only after tap Paste (H27 privacy rule: never auto-read clipboard).
- `StatusPill`: "Signed in · cookies on" (success), "Cookies on · not signed in" (warning), "Cookies off" (neutral).

#### Windows (idle)
- Two-column layout at >= 1100 px:
  - **Left (flex 3)**: hero headline (`display 40`), subtitle, composer (max 720), three feature pills (Fast fetch, Quality control, Playlist ready).
  - **Right (flex 2)**: Recent + Active panel in `AeroCard`: top 5 history items and active downloads with live progress.
- Below 1100 px: single column.

---

### 7.2 Result / Configuration (video found)

Unify `mobile_result_screen` and `video_configuration_widget` into one `VideoConfigPanel`.

#### Android: full screen, collapsing header
- `ThumbnailTile` 16:9 full-bleed with title, channel and duration overlaid on bottom gradient scrim.
- Segmented control: Video | Audio (`spatialSpring` indicator).
- Quality: horizontally scrolling `FormatChip` row (2160p, 1440p, 1080p, ...) with estimated size under label.
- Collapsible "More options" (container, subtitles, SponsorBlock, trim): `SettingsRow`s.
- Sticky bottom action bar: "Download · 142 MB" (primary, full width) + destination folder ghost button.

#### Windows: two-pane
- Left 40%: thumbnail, title, metadata.
- Right 60%: Video/Audio segmented control, quality grid (3 columns of chips), options accordion.
- Action bar pinned bottom-right: Download, Add to queue, Cancel.

#### Playlist
- Table-style list with checkbox, thumb 96 px, title, duration, per-row quality override.
- Top bar: Select all / none, count, total size estimate.
- Android: sticky "Download 12 selected" bar.

#### States
- Loading: skeleton thumbnail + chips (no bare spinner).
- Error: inline `EmptyState` with Try again and New URL.
- Auth required: restyled auth dialog.

---

### 7.3 Search
- Search field pinned top (`AeroTextField`).
- Results: 2-line rows (Android) or 2-3 column grid of `ThumbnailTile` cards (Windows).
- Each result: tap to open config panel, trailing quick-action "download best" icon.
- Skeleton loader matching new radii. Recent searches as chips when field is empty.

---

### 7.4 Library (Downloads)
- Segmented tabs: `Active | History` with counts.
- **Active card**:
  ```
  [thumb 96x54] Title (1-2 lines)               [⏸][✕]
                1080p MP4 · 4.2 MB/s · 00:41 left
                ███████████░░░░░░░░  62%
  ```
- State colors: downloading = violet, merging = info shimmer, paused = warning, failed = danger + reason + Retry.
- **History**: grouped by date (Today, Yesterday, This week, Earlier) with `SectionHeader`.
  - Row = thumb, title, size, format, date, overflow menu (Open, Share, Show in folder, Delete).
  - Windows: right-click context menu and multi-select checkboxes.
- Search and filter chips (Video, Audio, Failed).
- Empty states: "No active downloads" and "Nothing here yet".
- Remove card `BoxShadow`; use `surface1` + hairline.

---

### 7.5 Settings
- Single scroll column, max 720 px on Windows (or master-detail at >= 1100 px).
- Groups with `SectionHeader`: Account, Downloads, Appearance, Tools, Notifications & Background, Advanced, About.
- Search field at top of Settings.
- Destructive actions (Log out, Clear history): danger ghost buttons confirming in `AeroDialog`.

---

### 7.6 Onboarding (Android)
- 3 pages max, full-bleed black, icon in violet glow circle, headline + one line, dots indicator, Skip top-right.
- Last page requests notification and storage permissions with plain-language reasons.

---

### 7.7 Dialogs, sheets, overlays
- Share `AeroDialog` (radius `xl`, title style, max 2 actions, primary on right).
- Update dialog: version chip, 3 bullet changelog, Update now / Later, progress inline.
- `FloatingProgressOverlay` -> mini download tray docked above bottom nav (Android) or bottom of content (Windows).
- Error details dialog: human sentence summary, expandable technical details in mono, Copy & Report bug.

---

## 8. Accessibility and quality bar
- Contrast >= 4.5:1 for body text, >= 3:1 for icons/borders.
- Visible keyboard focus ring on every Windows interactive element (2 px primary + `primaryGlow`).
- Semantics labels on icon-only buttons, live-region download completion announcements.
- Support text scale up to 1.3 without clipping (`Flexible` and `maxLines`, no fixed heights).
- Respect OS reduce-motion and `enableAnimations`.
- Test matrix: Android (360x800, 412x915, 800x1280 tablet), Windows (960x640, 1280x720, 1920x1080), dark and light, text scale 1.0 and 1.3.

---

## 9. Implementation plan

| Phase | Scope | Files mainly touched | Risk |
| :---: | :--- | :--- | :---: |
| **0** | Safety net: golden / screenshot baselines of every screen in both themes | `test/` | Low |
| **1** | Tokens: `AeroColors` ThemeExtension, typography scale, spacing and radius constants. Rewire `AppTheme`. | `core/theme/*` | Low |
| **2** | Component library (section 5), with debug gallery screen | `ui/components/*` | Low |
| **3** | Shell and navigation: Android bottom bar & mini tray, Windows sidebar & top strip | `app.dart`, `mobile_home_layout.dart`, `app_navigation_rail.dart` | Medium |
| **4** | Home (both) | `home_screen.dart`, `mobile_home_screen.dart`, URL cards | Medium |
| **5** | Config panel and playlist (merge duplicates) | `video_configuration_widget.dart`, `mobile_video_configuration_widget.dart`, `mobile_result_screen.dart`, `playlist_screen.dart` | High |
| **6** | Library | `downloads_screen.dart`, `download_item_card.dart`, tabs | Medium |
| **7** | Search and Settings | `search_screen.dart`, `settings_screen.dart` | High |
| **8** | Dialogs, onboarding, polish, accessibility pass | various | Low |

---

### Hard constraints:
1. Presentation only. Do not touch providers, services, models, or Kotlin code.
2. Keep every existing callback, provider call, and guard (e.g., H21, H22, H23, H27, C7, C8).
3. Do not delete existing comments or docstrings unrelated to the change.
4. No new packages unless listed. Reuse `flutter_animate`, `provider`, `cached_network_image`.
5. No hard-coded colors, font sizes or radii. Use tokens.
6. Run `flutter analyze` and `flutter test`, and build both windows and apk --debug before reporting done (ask user if ambiguous).

---

## 10. Copy-paste prompts for other models

### Master Prompt Template
```
You are redesigning the Flutter app in "E:\youtube downloader" (AeroTube, Android + Windows).
Read redesign_spec.md fully, then implement ONLY Phase <PHASE>.
Keep the existing design DNA: OLED black / white, single violet accent (#8B5CF6),
Manrope, hairline borders, rounded geometry, M3 Expressive spring motion.
Rules:
- UI layer only (lib/ui, lib/core/theme, lib/app.dart). Do not edit providers, services, models, Kotlin.
- Preserve all callbacks, provider usage, guards and existing comments.
- Use design tokens (AeroColors, AeroText, AeroSpace, AeroRadius). No hard-coded colors/sizes.
- Both platforms must use the same components; differences only via density and layout.
- Respect appMotionDuration() for every animation.
- Finish with: flutter analyze, flutter test, and a short list of changed files + screenshots notes.
Do not start other phases.
```

- **Phase 1 Add-on**:
  > Create `lib/core/theme/tokens/{colors,typography,spacing,radius}.dart`. Implement `AeroColors extends ThemeExtension<AeroColors>` with the exact values in section 4.1 and `context.aero` extension. Build a full `TextTheme` from section 4.2 on Manrope, using `copyWith` on the existing styles so the fontFamily is not dropped (see the comment in `app_theme.dart`). Keep `AppTheme.darkTheme` and `lightTheme` entry points unchanged.

- **Phase 2 Add-on**:
  > Implement the 14 components in section 5 under `lib/ui/components/`, each with density and dark/light support, plus a `ComponentGalleryScreen` reachable only in debug (Settings > Advanced). Deprecate `GlassCard` and `SurfaceCard` by forwarding to `AeroCard`; do not delete them yet.

- **Phase 3 Add-on**:
  > Implement section 6. Android: bottom NavigationBar with a pill indicator and badge, remove the search FAB and top-bar icons, convert FloatingProgressOverlay to the mini tray. Windows: 232/72 px collapsible sidebar with labels, 48 px top strip, move theme toggle and status banners into it, add keyboard shortcuts. Keep PopScope behavior.

- **Phases 4–8**:
  > Use the matching sub-section of section 7 verbatim as the requirements.

---

## 11. Quick wins (incremental path)
1. Add labels to the Windows rail (`NavigationRailLabelType.all`) and widen to ~200 px.
2. Add a bottom `NavigationBar` on Android and delete the FAB.
3. Drop card `BoxShadow` and the 1.02 hover scale. Use tonal hover instead.
4. Introduce `surface1/2/3` (3 constants) and replace pure-black cards.
5. Merge all status banners and pills into one `StatusPill`.
6. Make progress bars 4 px with tabular-figure numbers.
