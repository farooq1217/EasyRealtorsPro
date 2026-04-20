import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:path_provider/path_provider.dart';

/// Universal platform utility for cross-platform compatibility
class PlatformUtils {
  /// Returns platform-specific database directory
  static Future<String> getDatabasePath() async {
    if (kIsWeb) {
      // For web, we'll use in-memory database with drift_web
      // This is handled by the database configuration, not path_provider
      return 'in_memory_web_database';
    }
    
    try {
      if (io.Platform.isAndroid || io.Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        return '${directory.path}/databases';
      } else {
        // Windows, macOS, Linux
        final directory = await getApplicationSupportDirectory();
        return '${directory.path}/databases';
      }
    } catch (e) {
      // Fallback to support directory if documents directory fails
      final directory = await getApplicationSupportDirectory();
      return '${directory.path}/databases';
    }
  }

  /// Returns platform-specific image storage directory
  static Future<String> getImageStoragePath() async {
    if (kIsWeb) {
      // Web uses Firebase Storage or IndexedDB, not local file paths
      return 'web_storage';
    }
    
    try {
      if (io.Platform.isAndroid || io.Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        return '${directory.path}/images';
      } else {
        // Windows, macOS, Linux
        final directory = await getApplicationSupportDirectory();
        return '${directory.path}/images';
      }
    } catch (e) {
      final directory = await getApplicationSupportDirectory();
      return '${directory.path}/images';
    }
  }

  /// Returns platform-specific temporary directory
  static Future<String> getTempPath() async {
    if (kIsWeb) {
      // Web uses browser's temporary storage
      return 'web_temp';
    }
    
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  /// Checks if current platform supports file system access
  static bool get supportsFileSystem => !kIsWeb;

  /// Checks if current platform supports camera
  static bool get supportsCamera {
    if (kIsWeb) return true; // Web camera support through browser
    return io.Platform.isAndroid || io.Platform.isIOS;
  }

  /// Checks if current platform supports gallery access
  static bool get supportsGallery {
    if (kIsWeb) return true; // Web file picker support
    return true; // All mobile/desktop platforms support gallery
  }

  /// Checks if current platform supports window management
  static bool get supportsWindowManager => !kIsWeb && (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux);

  /// Checks if current platform supports system tray
  static bool get supportsSystemTray => !kIsWeb && (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux);

  /// Checks if current platform supports notifications
  static bool get supportsNotifications {
    if (kIsWeb) return true; // Web notifications through browser API
    return true; // All platforms support notifications
  }

  /// Returns platform-specific file picker implementation
  static bool get usesFileSelector => !kIsWeb && (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux);

  /// Returns platform-specific image picker implementation
  static bool get usesImagePicker => true; // image_picker works on all platforms

  /// Checks if platform requires special permissions handling
  static bool get requiresPermissions => !kIsWeb;

  /// Returns platform name for debugging
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (io.Platform.isAndroid) return 'Android';
    if (io.Platform.isIOS) return 'iOS';
    if (io.Platform.isWindows) return 'Windows';
    if (io.Platform.isMacOS) return 'macOS';
    if (io.Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Checks if platform is mobile
  static bool get isMobile => !kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS);

  /// Checks if platform is desktop
  static bool get isDesktop => !kIsWeb && (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux);

  /// Checks if platform is touch-enabled
  static bool get isTouchEnabled => isMobile || kIsWeb;

  /// Returns platform-specific visual density
  static bool get useCompactUI => isDesktop;

  /// Returns platform-specific font scaling
  static double get fontScale {
    if (isMobile) return 1.0;
    if (isDesktop) return 0.9;
    return 1.0; // Web default
  }
}
