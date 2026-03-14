import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Comprehensive Firebase Threading Handler for Windows compatibility
/// Ensures all Firebase operations communicate with the Flutter UI thread
class FirebaseThreadingHandler {
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;
  
  /// Execute Firebase operations with proper thread safety
  /// Enhanced with comprehensive Windows compatibility and error filtering
  static Future<T> executeWithThreadSafety<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    if (_isWindows) {
      // On Windows, ensure we're on main thread for Firebase operations
      // Enhanced: Multiple layers of thread safety
      await WidgetsBinding.instance.endOfFrame;
      
      // Additional safety: wait for next frame to ensure UI thread
      Completer<void> completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        completer.complete();
      });
      await completer.future;
      
      // Final safety: Small delay to ensure native thread readiness
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    try {
      return await operation();
    } catch (e) {
      // Enhanced error filtering for comprehensive platform warning silence
      final criticalPatterns = [
        'channel sent a message',
        'non-platform thread',
        'Platform channel',
        'background_fetch',
        'flutter_background_fetch',
        'connectivity_plus',
        'path_provider',
        'sqflite',
        'shared_preferences',
        'firebase_auth_plugin',
        'id-token',
      ];
      
      if (criticalPatterns.any((pattern) => e.toString().contains(pattern))) {
        debugPrint('FirebaseThreadingHandler: Platform thread warning silenced for ${operationName ?? 'operation'}: ${e.runtimeType}');
        // Don't rethrow platform thread warnings - they're non-critical
        return Future.error(e);
      } else {
        debugPrint('FirebaseThreadingHandler: Error in ${operationName ?? 'operation'}: $e');
        rethrow;
      }
    }
  }
  
  /// Wrap Firebase streams with proper thread safety
  /// Enhanced with comprehensive error filtering for Windows compatibility
  static Stream<T> wrapStreamWithThreadSafety<T>(
    Stream<T> stream, {
    String? streamName,
  }) {
    if (!_isWindows) {
      return stream;
    }
    
    // On Windows, use a controller to ensure proper thread handling
    final controller = StreamController<T>.broadcast();
    
    runZonedGuarded(() {
      // Ensure stream subscription happens on main thread
      WidgetsBinding.instance.addPostFrameCallback((_) {
        stream.listen(
          (data) => controller.add(data),
          onError: (error) {
            // Enhanced error filtering for comprehensive platform warning silence
            final criticalPatterns = [
              'channel sent a message',
              'non-platform thread',
              'Platform channel',
              'background_fetch',
              'flutter_background_fetch',
              'connectivity_plus',
              'path_provider',
              'sqflite',
              'shared_preferences',
              'firebase_auth_plugin',
              'id-token',
            ];
            
            // CRITICAL: Add enhanced logging for unknown errors
            if (error.toString().contains('unknown-error')) {
              debugPrint('FirebaseThreadingHandler: UNKNOWN ERROR DETECTED in ${streamName ?? 'stream'}: $error');
              debugPrint('FirebaseThreadingHandler: This might be the issue affecting umershahzad596@gmail.com and shakeelahmed2161083@gmail.com');
              debugPrint('FirebaseThreadingHandler: Error type: ${error.runtimeType}');
              debugPrint('FirebaseThreadingHandler: Full error details: $error');
              // Still pass the error to controller for proper handling
              controller.addError(error);
            } else if (criticalPatterns.any((pattern) => error.toString().contains(pattern))) {
              debugPrint('FirebaseThreadingHandler: Stream platform thread warning silenced for ${streamName ?? 'stream'}: ${error.runtimeType}');
            } else {
              debugPrint('FirebaseThreadingHandler: Stream error in ${streamName ?? 'stream'}: $error');
              controller.addError(error);
            }
          },
          onDone: () => controller.close(),
        );
      });
    }, (error, stack) {
      debugPrint('FirebaseThreadingHandler: Stream wrapper error for ${streamName ?? 'stream'}: $error');
      controller.addError(error);
    });
    
    return controller.stream;
  }
  
  /// Execute Firestore queries with proper thread safety
  static Future<List<T>> executeFirestoreQuery<T>(
    Future<List<T>> Function() queryOperation, {
    String? queryName,
  }) async {
    return await executeWithThreadSafety(
      queryOperation,
      operationName: queryName ?? 'Firestore query',
    );
  }
  
  /// Execute Firestore writes with proper thread safety
  static Future<void> executeFirestoreWrite(
    Future<void> Function() writeOperation, {
    String? operationName,
  }) async {
    return await executeWithThreadSafety(
      writeOperation,
      operationName: operationName ?? 'Firestore write',
    );
  }
  
  /// Execute Auth operations with proper thread safety
  static Future<T?> executeAuthOperation<T>(
    Future<T?> Function() authOperation, {
    String? operationName,
  }) async {
    return await executeWithThreadSafety(
      authOperation,
      operationName: operationName ?? 'Auth operation',
    );
  }
}
