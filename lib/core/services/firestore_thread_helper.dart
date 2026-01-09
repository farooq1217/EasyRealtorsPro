import 'package:flutter/foundation.dart';

/// Helper class to ensure Firestore operations run on the platform thread
/// for Windows compatibility
class FirestoreThreadHelper {
  /// Execute a function on the platform thread
  /// In Flutter, async operations already run on appropriate threads,
  /// so this is mainly a compatibility wrapper
  static void executeOnPlatformThread(Future<void> Function() callback) {
    // For Windows compatibility, we ensure the operation runs asynchronously
    // Flutter's async/await already handles thread management properly
    callback().catchError((error) {
      debugPrint('FirestoreThreadHelper error: $error');
    });
  }
}
