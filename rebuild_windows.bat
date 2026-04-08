@echo off
setlocal enabledelayedexpansion

echo ===================================
echo Rebuild Windows with NuGet Fix
echo ===================================
echo.

:: Set NUGET variable explicitly for this session
set NUGET_PATH=%~dp0nuget.exe
echo Using NuGet from: %NUGET_PATH%
echo.

:: Clean previous build
echo Step 1: Cleaning previous build...
call flutter clean
echo.

:: Get dependencies
echo Step 2: Getting dependencies...
call flutter pub get
echo.

:: Build Windows with explicit NUGET path
echo Step 3: Building Windows application...
echo (This may take a few minutes...)
call flutter build windows --debug

if %errorlevel% equ 0 (
    echo.
    echo ===================================
    echo BUILD SUCCESS!
    echo ===================================
    echo.
    echo You can now run the app with: flutter run -d windows
) else (
    echo.
    echo ===================================
    echo BUILD FAILED
    echo ===================================
    echo.
    echo The build failed. Try these steps:
    echo 1. Open a NEW terminal (to pick up PATH changes)
    echo 2. Run: flutter clean ^&^& flutter build windows --debug
    echo.
    echo Or manually add nuget.exe to C:\Windows\System32\ 
    echo (requires Administrator privileges)
)

echo.
pause
