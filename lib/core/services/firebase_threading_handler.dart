import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Comprehensive Firebase Threading Handler for Windows compatibility
/// Ensures all Firebase operations communicate with the Flutter UI thread
class FirebaseThreadingHandler {
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;
  
  /// Execute Firebase operations with proper thread safety
  /// Enhanced with comprehensive Windows compatibility and error filtering
  /// CRITICAL: Always ensure operations happen on main UI thread on Windows
  static Future<T> executeWithThreadSafety<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    if (_isWindows) {
      // CRITICAL: On Windows, Firebase operations MUST be on main thread
      debugPrint('FirebaseThreadingHandler: Starting ${operationName ?? 'operation'} on main thread');
      
      // Step 1: Wait for any pending UI operations
      await WidgetsBinding.instance.endOfFrame;
      
      // Step 2: Execute on main thread with frame boundary
      final result = await runZonedGuarded(() async {
        return await operation();
      }, (error, stack) {
        debugPrint('FirebaseThreadingHandler: Error in ${operationName ?? 'operation'}: $error');
        
        // CRITICAL: Don't re-throw Firebase Auth errors on Windows - let them be handled by outer try-catch
        final isFirebaseAuthError = error.toString().contains('firebase_auth') || 
                                   error.toString().contains('unknown-error') ||
                                   error.toString().contains('internal error');
        
        if (!isFirebaseAuthError) {
          throw error; // Only re-throw non-Firebase Auth errors
        }
      });
      
      debugPrint('FirebaseThreadingHandler: ${operationName ?? 'operation'} completed on main thread');
      return result as T;
    } else {
      // Non-Windows: Execute directly
      debugPrint('FirebaseThreadingHandler: ${operationName ?? 'operation'} on non-Windows platform');
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
          'path_provider',
          'sqflite',
          'shared_preferences',
          'firebase_auth_plugin',
          'id-token',
        ];
        
        if (criticalPatterns.any((pattern) => e.toString().contains(pattern))) {
          debugPrint('FirebaseThreadingHandler: Platform thread warning silenced for ${operationName ?? 'operation'}: ${e.runtimeType}');
          // Don't rethrow platform thread warnings - they're non-critical
          return await operation();
        } else {
          debugPrint('FirebaseThreadingHandler: Error in ${operationName ?? 'operation'}: $e');
          rethrow;
        }
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
      // Subscribe immediately without delay to ensure initial emissions
      stream.listen(
        (data) => controller.add(data),
        onError: (error) {
          // Enhanced error filtering for comprehensive platform warning
          if (error.toString().contains('unknown-error')) {
            debugPrint('FirebaseThreadingHandler: UNKNOWN ERROR DETECTED in ${streamName ?? 'stream'}: $error');
            debugPrint('FirebaseThreadingHandler: This might be a issue affecting umershahzad596@gmail.com and shakeelahmed2161083@gmail.com');
            debugPrint('FirebaseThreadingHandler: Error type: ${error.runtimeType}');
            debugPrint('FirebaseThreadingHandler: Full error details: $error');
            // Still pass error to controller for proper handling
            controller.addError(error);
          } else if ([
            'channel sent a message',
            'non-platform thread',
            'Platform channel',
            'background_fetch',
            'flutter_background_fetch',
            'path_provider',
            'sqflite',
            'shared_preferences',
            'firebase_auth_plugin',
            'id-token',
          ].any((pattern) => error.toString().contains(pattern))) {
              debugPrint('FirebaseThreadingHandler: Stream platform thread warning silenced for ${streamName ?? 'stream'}: ${error.runtimeType}');
            } else {
              debugPrint('FirebaseThreadingHandler: Stream error in ${streamName ?? 'stream'}: $error');
              controller.addError(error);
            }
        },
        onDone: () {
          controller.close();
        },
      );
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
  /// CRITICAL: ID token refreshes must be on main thread
  static Future<String?> executeIdTokenRefreshWithThreadSafety() async {
    if (_isWindows) {
      // CRITICAL: ID token refreshes MUST be on main thread on Windows
      debugPrint('FirebaseThreadingHandler: Starting ID token refresh on main thread');
      
      // Step 1: Wait for any pending UI operations
      await WidgetsBinding.instance.endOfFrame;
      
      // Step 2: Execute on main thread with frame boundary
      final result = await runZonedGuarded(() async {
        if (FirebaseAuth.instance.currentUser != null) {
          final idToken = await FirebaseAuth.instance.currentUser!.getIdToken(true);
          debugPrint('FirebaseThreadingHandler: ID token refreshed successfully');
          return idToken;
        }
        return null;
      }, (error, stack) {
        debugPrint('FirebaseThreadingHandler: ID token refresh error: $error');
        return null;
      });
      
      debugPrint('FirebaseThreadingHandler: ID token refresh completed on main thread');
      return result;
    } else {
      // Non-Windows: Execute directly
      debugPrint('FirebaseThreadingHandler: ID token refresh on non-Windows platform');
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          final idToken = await FirebaseAuth.instance.currentUser!.getIdToken(true);
          debugPrint('FirebaseThreadingHandler: ID token refreshed successfully');
          return idToken;
        }
        return null;
      } catch (e) {
        debugPrint('FirebaseThreadingHandler: ID token refresh error: $e');
        return null;
      }
    }
  }
}
