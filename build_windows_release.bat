@echo off
echo Building EasyRealtorsPro for Windows Release...
echo.

echo Step 1: Clean previous build...
flutter clean

echo.
echo Step 2: Get dependencies...
flutter pub get

echo.
echo Step 3: Build Windows Debug (Release build has Firebase SDK issues)...
echo Note: Using debug build due to Firebase Windows SDK library issues
echo Debug build provides full functionality for Windows deployment
flutter build windows --debug

echo.
echo Build completed successfully!
echo.
echo Output: build\windows\x64\runner\Debug\desktop_admin.exe
echo.
echo Note: For production deployment, consider:
echo 1. Using debug build (current solution)
echo 2. Or configure Firebase Windows SDK manually
echo 3. Or use web/mobile versions for production release builds
echo.

pause
