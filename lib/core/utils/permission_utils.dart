import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'platform_utils.dart';

/// Universal permission handling for cross-platform compatibility
class PermissionUtils {
  /// Request camera permission
  static Future<PermissionStatus> requestCameraPermission() async {
    if (kIsWeb) {
      // Web permissions are handled by browser API
      return await _requestWebPermission('camera');
    }
    
    if (!PlatformUtils.supportsCamera) {
      return PermissionStatus.denied;
    }
    
    try {
      final status = await Permission.camera.request();
      return status;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to request camera permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request storage permission
  static Future<PermissionStatus> requestStoragePermission() async {
    if (kIsWeb) {
      // Web doesn't need storage permission for file operations
      return PermissionStatus.granted;
    }
    
    if (!PlatformUtils.supportsFileSystem) {
      return PermissionStatus.denied;
    }
    
    try {
      PermissionStatus status;
      
      if (io.Platform.isAndroid) {
        // Android 13+ uses media permissions instead of storage
        status = await Permission.photos.request();
        if (status.isGranted) {
          return status;
        }
        // Fallback to storage permission
        status = await Permission.storage.request();
      } else if (io.Platform.isIOS) {
        // iOS uses photos permission
        status = await Permission.photos.request();
      } else {
        // Desktop platforms don't typically need storage permission
        status = PermissionStatus.granted;
      }
      
      return status;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to request storage permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request notification permission
  static Future<PermissionStatus> requestNotificationPermission() async {
    if (kIsWeb) {
      return await _requestWebPermission('notifications');
    }
    
    if (!PlatformUtils.supportsNotifications) {
      return PermissionStatus.denied;
    }
    
    try {
      final status = await Permission.notification.request();
      return status;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to request notification permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request microphone permission
  static Future<PermissionStatus> requestMicrophonePermission() async {
    if (kIsWeb) {
      return await _requestWebPermission('microphone');
    }
    
    try {
      final status = await Permission.microphone.request();
      return status;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to request microphone permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check camera permission status
  static Future<PermissionStatus> checkCameraPermission() async {
    if (kIsWeb) {
      return await _checkWebPermission('camera');
    }
    
    if (!PlatformUtils.supportsCamera) {
      return PermissionStatus.denied;
    }
    
    try {
      final status = await Permission.camera.status;
      return status;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to check camera permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check storage permission status
  static Future<PermissionStatus> checkStoragePermission() async {
    if (kIsWeb) {
      return PermissionStatus.granted; // Web doesn't need storage permission
    }
    
    if (!PlatformUtils.supportsFileSystem) {
      return PermissionStatus.denied;
    }
    
    try {
      PermissionStatus status;
      
      if (io.Platform.isAndroid) {
        status = await Permission.photos.status;
        if (status.isGranted) {
          return status;
        }
        status = await Permission.storage.status;
      } else if (io.Platform.isIOS) {
        status = await Permission.photos.status;
      } else {
        status = PermissionStatus.granted; // Desktop
      }
      
      return status;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to check storage permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check notification permission status
  static Future<PermissionStatus> checkNotificationPermission() async {
    if (kIsWeb) {
      return await _checkWebPermission('notifications');
    }
    
    if (!PlatformUtils.supportsNotifications) {
      return PermissionStatus.denied;
    }
    
    try {
      final status = await Permission.notification.status;
      return status;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to check notification permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    if (kIsWeb) {
      // Web doesn't have app settings
      return;
    }
    
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('PermissionUtils: Failed to open app settings: $e');
    }
  }

  /// Request multiple permissions at once
  static Future<Map<Permission, PermissionStatus>> requestMultiplePermissions(
    List<Permission> permissions,
  ) async {
    if (kIsWeb) {
      // Handle web permissions separately
      final results = <Permission, PermissionStatus>{};
      for (final permission in permissions) {
        PermissionStatus status;
        switch (permission) {
          case Permission.camera:
            status = await requestCameraPermission();
            break;
          case Permission.notification:
            status = await requestNotificationPermission();
            break;
          case Permission.microphone:
            status = await requestMicrophonePermission();
            break;
          default:
            status = PermissionStatus.granted; // Web grants most permissions by default
        }
        results[permission] = status;
      }
      return results;
    }
    
    try {
      final results = await permissions.request();
      return results;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to request multiple permissions: $e');
      return {};
    }
  }

  /// Check if all required permissions are granted
  static Future<bool> areAllPermissionsGranted(List<Permission> permissions) async {
    for (final permission in permissions) {
      final status = await _checkSinglePermission(permission);
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
  }

  /// Check single permission status
  static Future<PermissionStatus> _checkSinglePermission(Permission permission) async {
    try {
      final status = await permission.status;
      return status;
    } catch (e) {
      debugPrint('PermissionUtils: Failed to check permission ${permission.toString()}: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request web permission using browser API
  static Future<PermissionStatus> _requestWebPermission(String permissionType) async {
    // Web permissions are handled by browser APIs
    // This is a simplified implementation
    try {
      switch (permissionType) {
        case 'camera':
        case 'microphone':
          // These would use navigator.mediaDevices.getUserMedia()
          return PermissionStatus.granted; // Simplified for now
        case 'notifications':
          // This would use Notification.requestPermission()
          return PermissionStatus.granted; // Simplified for now
        default:
          return PermissionStatus.granted;
      }
    } catch (e) {
      debugPrint('PermissionUtils: Failed to request web permission $permissionType: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check web permission status
  static Future<PermissionStatus> _checkWebPermission(String permissionType) async {
    // Web permissions are checked by browser APIs
    // This is a simplified implementation
    try {
      switch (permissionType) {
        case 'camera':
        case 'microphone':
          return PermissionStatus.granted; // Simplified for now
        case 'notifications':
          return PermissionStatus.granted; // Simplified for now
      }
      return PermissionStatus.granted; // Default for other permissions
    } catch (e) {
      debugPrint('PermissionUtils: Failed to check web permission $permissionType: $e');
      return PermissionStatus.denied;
    }
  }

  /// Get permission status description
  static String getPermissionStatusDescription(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }

  /// Check if permission can be requested again
  static bool canRequestPermission(PermissionStatus status) {
    return status.isDenied || status.isLimited;
  }

  /// Check if user should be directed to settings
  static bool shouldOpenSettings(PermissionStatus status) {
    return status.isPermanentlyDenied || status.isRestricted;
  }
}
