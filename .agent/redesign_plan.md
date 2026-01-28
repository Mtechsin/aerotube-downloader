# Implementation Plan - Settings Redesign & Global Theme

## Status: Completed

### 1. Global Theme Update (`lib/core/theme/app_theme.dart`)
- **Status**: Completed
- **Objective**: Establish a comprehensive `ThemeData` as the source of truth.
- **Changes**:
    - **Colors**: Set background to `0xFF0F0F0F` (Dark), Surface to `0xFF1E1E1E`, Primary to Vibrant Purple (`0xFF8B5CF6`).
    - **Typography**: Defined global text styles using `GoogleFonts.inter`.
    - **Components**:
        - `NavigationRailTheme`: Styled for dark mode with purple accents.
        - `CardTheme`: zero elevation, rounded corners (16px), dark surface color. Fixed `CardThemeData` type error.
        - `FilledButtonTheme`: Purple background, Stadium (pill) shape.
        - `InputDecorationTheme`: Filled, fully rounded borders, subtle styling.
        - `SwitchTheme` & `SliderTheme`: Purple accents.

### 2. Home Screen Redesign (`lib/ui/screens/home_screen.dart`)
- **Status**: Completed
- **Objective**: Implement "Floating Command Capsule" and "Empty State".
- **Changes**:
    - **Layout**: Removed `SliverAppBar`. Used `Stack` to position the floating capsule.
    - **Command Capsule**: Custom stadium-shaped container with glassmorphic touch, housing input and fetch button.
    - **Empty State**: Hero icon ("Ready to Download") with quick action chips ("Up to 4K", "Audio Only") in the center.

### 3. Settings Screen Redesign (`lib/ui/screens/settings_screen.dart`)
- **Status**: Completed
- **Changes**:
    - **Structure**: `CustomScrollView` with `SliverAppBar`.
    - **Styling**: Removed manual color/shape overrides. Now relies on `AppTheme` for consistency.
    - **Sections**:
        - **Tools Management**: Standardized ListTiles, "Check Update" button uses theme.
        - **Download Preferences**: Added Dropdowns, File Picker, and a **Two-Part Slider** layout for "Concurrent Downloads".
        - **Appearance**: Implemented `SegmentedButton` for Theme Mode.
        - **Authentication**: Refined layout for Cookie management.
        - **Advanced**: standard SwitchTiles.
    - **Code Quality**: Cleaned up duplicated methods and unused imports.

### 3. Verification
- partial `flutter analyze` run shows reduction in errors/warnings related to the changes.
- The UI should now automatically reflect the "Dark Mode + Purple Accent" aesthetic defined in the prompt.
