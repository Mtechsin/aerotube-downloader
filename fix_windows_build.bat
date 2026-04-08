@echo off
echo ===================================
echo Fix NuGet for Windows Build
echo ===================================
echo.

echo Step 1: Checking if nuget.exe is already in PATH...
where nuget >nul 2>&1
if %errorlevel% equ 0 (
    echo NuGet is already installed and available in PATH.
    echo Location:
    where nuget
    echo.
    echo You're all set! Try running flutter run again.
    pause
    exit /b 0
)

echo NuGet not found in PATH.
echo.

echo Step 2: Downloading nuget.exe...
set NUGET_PATH=%~dp0nuget.exe

if not exist "%NUGET_PATH%" (
    echo Downloading from https://dist.nuget.org/win-x86-commandline/latest/nuget.exe ...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile '%NUGET_PATH%'"
    
    if not exist "%NUGET_PATH%" (
        echo ERROR: Failed to download nuget.exe
        echo Please download it manually from:
        echo https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
        echo Place it in: %NUGET_PATH%
        pause
        exit /b 1
    )
) else (
    echo NuGet.exe already exists at: %NUGET_PATH%
)

echo.
echo Step 3: Adding project root to system PATH...
echo This will add the project directory to your system PATH permanently.
echo.
echo NOTE: You may need to run this script as Administrator.
echo If you don't want to modify system PATH, you can:
echo   1. Copy nuget.exe to C:\Windows\System32\ 
echo   2. Or manually add this directory to PATH
echo.

set PROJECT_DIR=%~dp0
set PROJECT_DIR_NO_QUOTE=%PROJECT_DIR:~0,-1%

echo Adding to PATH: %PROJECT_DIR_NO_QUOTE%
setx PATH "%PROJECT_DIR_NO_QUOTE%;%PATH%" /M
if %errorlevel% equ 0 (
    echo.
    echo SUCCESS! NuGet.exe is now accessible.
    echo.
    echo IMPORTANT: You need to restart your terminal/IDE for PATH changes to take effect.
    echo After restarting, run: flutter clean ^&^& flutter run
) else (
    echo.
    echo WARNING: Could not add to system PATH (may need Administrator rights).
    echo.
    echo ALTERNATIVE: Copy nuget.exe to a directory already in your PATH:
    echo   copy "%NUGET_PATH%" "C:\Windows\System32\"
    echo.
    echo Or run this script as Administrator.
)

echo.
echo ===================================
echo Setup Complete!
echo ===================================
echo.
echo Next steps:
echo 1. Close this terminal and open a new one
echo 2. Verify nuget is available: where nuget
echo 3. Clean and rebuild: flutter clean ^&^& flutter run
echo.
pause
