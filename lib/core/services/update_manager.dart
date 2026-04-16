import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import '../utils/connectivity_utils.dart';

class UpdateManager {
  static const Duration _remoteConfigTimeout = Duration(minutes: 1);
  static const Duration _downloadTimeout = Duration(minutes: 10);
  
  // Step 1: Check for Update via Firebase Remote Config
  Future<void> checkForUpdate() async {
    try {
      // Check internet connectivity first
      final hasInternet = await ConnectivityUtils.hasInternetConnection();
      if (!hasInternet) {
        debugPrint("UpdateManager: No internet connection - skipping update check");
        return;
      }

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: _remoteConfigTimeout,
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();

      String latestVersion = remoteConfig.getString('latest_version') ?? '';
      String updateUrl = remoteConfig.getString('update_url') ?? '';

      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      debugPrint("UpdateManager: Current version: $currentVersion");
      debugPrint("UpdateManager: Latest version: $latestVersion");

      if (latestVersion.isNotEmpty && latestVersion != currentVersion && updateUrl.isNotEmpty) {
        debugPrint("UpdateManager: New update available: $latestVersion. Downloading...");
        await _downloadAndApplyUpdate(updateUrl);
      } else {
        debugPrint("UpdateManager: App is up to date or no update URL configured.");
      }
    } catch (e) {
      // Silent failure during startup - don't crash the app
      debugPrint("UpdateManager: Update check failed silently: $e");
    }
  }

  // Step 2 & 3: Download and Extract ZIP
  Future<void> _downloadAndApplyUpdate(String url) async {
    try {
      // Check internet before download
      final hasInternet = await ConnectivityUtils.hasInternetConnection();
      if (!hasInternet) {
        debugPrint("UpdateManager: No internet connection - cannot download update");
        return;
      }

      Directory tempDir = await getTemporaryDirectory();
      String zipPath = '${tempDir.path}\\update.zip';
      String extractPath = '${tempDir.path}\\EasyRealtorsPro_Update';

      debugPrint("UpdateManager: Downloading update from: $url");
      debugPrint("UpdateManager: Downloading to: $zipPath");
      
      // Download with timeout
      Dio dio = Dio();
      await dio.download(
        url, 
        zipPath,
        options: Options(
          receiveTimeout: _downloadTimeout,
          sendTimeout: _downloadTimeout,
        ),
      );
      debugPrint("UpdateManager: Download completed");

      // Clean up previous extraction if exists
      if (await Directory(extractPath).exists()) {
        await Directory(extractPath).delete(recursive: true);
      }
      
      // Create extraction directory
      await Directory(extractPath).create(recursive: true);

      // Extract
      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      debugPrint("UpdateManager: Extracting files to: $extractPath");

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final filePath = '$extractPath\\$filename';
          
          // Create directory if it doesn't exist
          final fileDir = File(filePath).parent;
          if (!await fileDir.exists()) {
            await fileDir.create(recursive: true);
          }
          
          await File(filePath).writeAsBytes(data);
        } else {
          await Directory('$extractPath\\$filename').create(recursive: true);
        }
      }

      debugPrint("UpdateManager: Extraction completed");

      // Step 4: Run the Batch script
      await _runUpdaterScript(extractPath);

    } catch (e) {
      debugPrint("UpdateManager: Update failed: $e");
    }
  }

  // Step 4: Create and execute the Batch Script
  Future<void> _runUpdaterScript(String extractedFolderPath) async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      String batFilePath = '${tempDir.path}\\updater.bat';
      
      // Use unified connectivity utility for null-safe path retrieval
      String localAppData = ConnectivityUtils.getLocalAppDataPath();
      if (localAppData.isEmpty) {
        debugPrint("UpdateManager: LOCALAPPDATA environment variable not found");
        return;
      }
      
      String appInstallPath = '$localAppData\\EasyRealtorsPro';

      debugPrint("UpdateManager: Creating updater script at: $batFilePath");
      debugPrint("UpdateManager: App install path: $appInstallPath");
      debugPrint("UpdateManager: Extracted path: $extractedFolderPath");

      String scriptContent = '''
@echo off
echo Starting EasyRealtorsPro Update...
timeout /t 3 /nobreak > NUL
echo Updating application files...
xcopy /s /y /q "$extractedFolderPath\\*" "$appInstallPath\\"
echo Update completed. Restarting application...
start "" "$appInstallPath\\easy_realtors_pro.exe"
echo Cleaning up temporary files...
del "%~f0"
echo Update process finished.
''';

      File batFile = File(batFilePath);
      await batFile.writeAsString(scriptContent);
      debugPrint("UpdateManager: Updater script created");

      // Run script in background
      await Process.start(batFilePath, [], mode: ProcessStartMode.detached);
      debugPrint("UpdateManager: Updater script started in detached mode");

      // Force close app to release file locks
      debugPrint("UpdateManager: Closing app for update...");
      exit(0); 
    } catch (e) {
      debugPrint("UpdateManager: Error running updater script: $e");
    }
  }

  /// Check if update is available without downloading
  Future<bool> isUpdateAvailable() async {
    try {
      // Check internet connectivity first
      final hasInternet = await ConnectivityUtils.hasInternetConnection();
      if (!hasInternet) {
        debugPrint("UpdateManager: No internet connection - cannot check for updates");
        return false;
      }

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: _remoteConfigTimeout,
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();

      String latestVersion = remoteConfig.getString('latest_version') ?? '';
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      return latestVersion.isNotEmpty && latestVersion != currentVersion;
    } catch (e) {
      debugPrint("UpdateManager: Error checking update availability: $e");
      return false;
    }
  }

  /// Get latest version from Remote Config
  Future<String> getLatestVersion() async {
    try {
      // Check internet connectivity first
      final hasInternet = await ConnectivityUtils.hasInternetConnection();
      if (!hasInternet) {
        debugPrint("UpdateManager: No internet connection - cannot get latest version");
        return '';
      }

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: _remoteConfigTimeout,
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();

      return remoteConfig.getString('latest_version') ?? '';
    } catch (e) {
      debugPrint("UpdateManager: Error getting latest version: $e");
      return '';
    }
  }
}
