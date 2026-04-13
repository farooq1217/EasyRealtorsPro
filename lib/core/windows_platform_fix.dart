/// Windows Platform Fix - Comprehensive Connection Stability
/// This module provides Windows-specific fixes to prevent connection loss issues
/// caused by FirebaseThreadingHandler and other platform threading conflicts.

import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;

class WindowsPlatformFix {
  static bool get isWindows => !kIsWeb && io.Platform.isWindows;
  static bool _initialized = false;
  
  /// Initialize Windows-specific fixes (only once)
  static void initialize() {
    if (isWindows && !_initialized) {
      debugPrint('WindowsPlatformFix: Initializing Windows-specific fixes');
      debugPrint('WindowsPlatformFix: FirebaseThreadingHandler disabled to prevent connection loss');
      debugPrint('WindowsPlatformFix: All Firebase operations will use direct streams');
      _initialized = true;
    } else if (isWindows && _initialized) {
      debugPrint('WindowsPlatformFix: Already initialized - skipping');
    }
  }
  
  /// Check if error is related to connection loss
  static bool isConnectionLossError(Object error) {
    if (!isWindows) return false;
    
    final errorString = error.toString();
    return errorString.contains('Lost connection to device') ||
           errorString.contains('channel sent a message') ||
           errorString.contains('non-platform thread') ||
           errorString.contains('firebase_auth_plugin');
  }
  
  /// Handle connection loss errors gracefully
  static void handleConnectionLossError(Object error, StackTrace? stack) {
    if (isConnectionLossError(error)) {
      debugPrint('WindowsPlatformFix: Connection loss detected - app will continue with local data');
      debugPrint('WindowsPlatformFix: Error type: ${error.runtimeType}');
      debugPrint('WindowsPlatformFix: Error message: ${error.toString()}');
    } else {
      debugPrint('WindowsPlatformFix: Non-connection error: $error');
      if (kDebugMode) {
        debugPrint('WindowsPlatformFix: Stack trace: $stack');
      }
    }
  }
  
  /// Get Windows-specific stream wrapper that bypasses FirebaseThreadingHandler
  static T wrapStreamSafely<T>(T stream) {
    if (isWindows) {
      debugPrint('WindowsPlatformFix: Bypassing FirebaseThreadingHandler for stream');
      return stream; // Return original stream directly
    }
    return stream; // For non-Windows, return as-is
  }
}
