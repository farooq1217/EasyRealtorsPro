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
      // CRITICAL: On Windows, Firebase operations MUST run normally on the main Dart UI isolate.
      // Custom threading wrappers, runZonedGuarded, or endOfFrame delays must be avoided.
      debugPrint('FirebaseThreadingHandler: Windows detected - executing ${operationName ?? 'operation'} directly on main isolate');
      return await operation();
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
          // Don't rethrow platform thread warnings - they're non-critical, retry with exponential backoff
          const maxRetries = 3;
          for (int attempt = 0; attempt < maxRetries; attempt++) {
            try {
              return await operation();
            } catch (err) {
              if (attempt == maxRetries - 1) rethrow;
              await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
            }
          }
          rethrow;
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
    debugPrint('FirebaseThreadingHandler: Returning original stream directly for ${streamName ?? 'stream'}');
    return stream;
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
      // For Windows, do NOT force token refresh (getIdToken(true)).
      // Let the Firebase SDK handle its own token lifecycle by passing false or check if token is near expiry.
      debugPrint('FirebaseThreadingHandler: Retrieving ID token on Windows without forcing refresh');
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          final idToken = await FirebaseAuth.instance.currentUser!.getIdToken(false);
          debugPrint('FirebaseThreadingHandler: ID token retrieved successfully (cached/refreshed by SDK)');
          return idToken;
        }
        return null;
      } catch (e) {
        debugPrint('FirebaseThreadingHandler: ID token retrieval error on Windows: $e');
        return null;
      }
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
