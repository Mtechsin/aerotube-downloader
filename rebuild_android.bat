@echo off
echo ===================================
echo Flutter Clean Rebuild for Android
echo ===================================
echo.

echo Step 1: Stopping any running Flutter processes...
taskkill /F /IM flutter.exe 2>nul
timeout /t 2 /nobreak >nul

echo.
echo Step 2: Cleaning Flutter build...
call flutter clean

echo.
echo Step 3: Getting dependencies...
call flutter pub get

echo.
echo Step 4: Running Flutter analyzer...
call flutter analyze lib/services/ytdlp_service_android.dart lib/main.dart

echo.
echo Step 5: Building APK for Android...
echo (This will take a minute...)
call flutter build apk --debug

echo.
echo ===================================
echo Build Complete!
echo ===================================
echo.
echo Now install the APK on your device/emulator:
echo   flutter install
echo.
echo Or run directly:
echo   flutter run
echo.
pause
