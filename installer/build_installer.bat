@echo off
REM EasyRealtorsPro Production Installer Build Script
REM This script builds the production installer using Inno Setup

echo ========================================
echo EasyRealtorsPro Installer Build Script
echo ========================================
echo.

REM Check if Inno Setup is installed
if not exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    if not exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
        echo ERROR: Inno Setup 6 is not installed or not found.
        echo Please install Inno Setup 6 from https://jrsoftware.org/isinfo.php
        pause
        exit /b 1
    )
)

REM Set Inno Setup path
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else (
    set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
)

echo Found Inno Setup at: %ISCC_PATH%
echo.

REM Check if Flutter build exists
if not exist "..\build\windows\x64\runner\Release\easyrealtorspro.exe" (
    echo ERROR: Flutter build not found.
    echo Please run the following commands first:
    echo   flutter clean
    echo   flutter pub get
    echo   flutter build windows --release
    echo.
    pause
    exit /b 1
)

echo Flutter build found. Continuing with installer creation...
echo.

REM Create output directory
if not exist "installer_output" mkdir installer_output

REM Build the installer
echo Building EasyRealtorsPro production installer...
echo.

"%ISCC_PATH%" "easyrealtorspro_production.iss"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo SUCCESS: Installer built successfully!
    echo ========================================
    echo.
    echo Installer location: installer_output\EasyRealtorsPro_Setup_1.0.0_Production.exe
    echo.
    echo To test the installer:
    echo   1. Run the installer on a clean Windows machine
    echo   2. Verify all components install correctly
    echo   3. Test application launch and functionality
    echo.
    echo To distribute the installer:
    echo   1. Upload the installer file to your distribution platform
    echo   2. Update download links on your website
    echo   3. Notify customers of the new release
    echo.
) else (
    echo.
    echo ========================================
    echo ERROR: Installer build failed!
    echo ========================================
    echo.
    echo Please check the error messages above and fix any issues.
    echo Common issues:
    echo   - Missing files in Flutter build directory
    echo   - Incorrect paths in the .iss script
    echo   - Permission issues
    echo.
)

pause
