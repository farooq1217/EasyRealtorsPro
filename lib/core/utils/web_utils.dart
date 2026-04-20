import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Web-specific utilities for cross-platform compatibility
class WebUtils {
  /// Checks if running in web environment
  static bool get isWeb => kIsWeb;

  /// Creates web-specific database connection (simplified)
  static DatabaseConnection createWebDatabase(String name) {
    // For web, return a delayed connection that will be configured elsewhere
    return DatabaseConnection.delayed(Future(() async {
      // This will be implemented with proper web database setup
      throw UnimplementedError('Web database setup to be implemented');
    }));
  }

  /// Converts file to base64 for web storage
  static String fileToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  /// Converts base64 to file bytes
  static Uint8List base64ToFile(String base64) {
    return base64Decode(base64);
  }

  /// Generates download URL for web
  static String generateDownloadUrl(Uint8List bytes, String fileName) {
    final base64 = fileToBase64(bytes);
    return 'data:application/octet-stream;base64,$base64';
  }

  /// Triggers file download in browser (placeholder)
  static void downloadFile(Uint8List bytes, String fileName) {
    if (!kIsWeb) return;
    
    debugPrint('WebUtils: File download feature not implemented yet');
  }

  /// Stores data in browser's local storage (placeholder)
  static Future<void> setLocalStorage(String key, String value) async {
    if (!kIsWeb) return;
    
    debugPrint('WebUtils: Local storage feature not implemented yet');
  }

  /// Retrieves data from browser's local storage (placeholder)
  static String? getLocalStorage(String key) {
    if (!kIsWeb) return null;
    
    debugPrint('WebUtils: Local storage feature not implemented yet');
    return null;
  }

  /// Removes data from browser's local storage (placeholder)
  static Future<void> removeLocalStorage(String key) async {
    if (!kIsWeb) return;
    
    debugPrint('WebUtils: Local storage feature not implemented yet');
  }

  /// Stores data in browser's session storage (placeholder)
  static Future<void> setSessionStorage(String key, String value) async {
    if (!kIsWeb) return;
    
    debugPrint('WebUtils: Session storage feature not implemented yet');
  }

  /// Retrieves data from browser's session storage (placeholder)
  static String? getSessionStorage(String key) {
    if (!kIsWeb) return null;
    
    debugPrint('WebUtils: Session storage feature not implemented yet');
    return null;
  }

  /// Uploads file to Firebase Storage for web
  static Future<String?> uploadToFirebaseStorage(
    Uint8List bytes,
    String path, {
    Map<String, String>? metadata,
  }) async {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child(path);
      
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: metadata?['contentType'] ?? 'application/octet-stream',
          customMetadata: metadata,
        ),
      );
      
      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('WebUtils: Failed to upload to Firebase Storage: $e');
      return null;
    }
  }

  /// Downloads file from Firebase Storage for web
  static Future<Uint8List?> downloadFromFirebaseStorage(String path) async {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child(path);
      return await ref.getData();
    } catch (e) {
      debugPrint('WebUtils: Failed to download from Firebase Storage: $e');
      return null;
    }
  }

  /// Checks if browser supports IndexedDB (placeholder)
  static bool get supportsIndexedDB {
    if (!kIsWeb) return false;
    debugPrint('WebUtils: IndexedDB detection not implemented yet');
    return true; // Assume modern browsers support it
  }

  /// Checks if browser supports File API (placeholder)
  static bool get supportsFileAPI {
    if (!kIsWeb) return false;
    debugPrint('WebUtils: File API detection not implemented yet');
    return true; // Assume modern browsers support it
  }

  /// Checks if browser supports Web Workers (placeholder)
  static bool get supportsWebWorkers {
    if (!kIsWeb) return false;
    debugPrint('WebUtils: Web Workers detection not implemented yet');
    return true; // Assume modern browsers support it
  }

  /// Gets browser information (placeholder)
  static Map<String, String> getBrowserInfo() {
    if (!kIsWeb) return {};
    
    debugPrint('WebUtils: Browser info detection not implemented yet');
    return {
      'userAgent': 'Unknown',
      'platform': 'Unknown',
      'language': 'Unknown',
      'cookieEnabled': 'Unknown',
      'onLine': 'Unknown',
    };
  }

  /// Shows browser notification (placeholder)
  static Future<void> showNotification(
    String title,
    String body, {
    String? icon,
  }) async {
    if (!kIsWeb) return;
    debugPrint('WebUtils: Notification feature not implemented yet');
  }

  /// Copies text to clipboard (placeholder)
  static Future<void> copyToClipboard(String text) async {
    if (!kIsWeb) return;
    debugPrint('WebUtils: Clipboard feature not implemented yet');
  }

  /// Reads text from clipboard (placeholder)
  static Future<String?> readFromClipboard() async {
    if (!kIsWeb) return null;
    debugPrint('WebUtils: Clipboard feature not implemented yet');
    return null;
  }

  /// Opens URL in new tab (placeholder)
  static void openUrl(String url) {
    if (!kIsWeb) return;
    debugPrint('WebUtils: URL opening feature not implemented yet');
  }

  /// Reloads the page (placeholder)
  static void reloadPage() {
    if (!kIsWeb) return;
    debugPrint('WebUtils: Page reload feature not implemented yet');
  }

  /// Gets current URL (placeholder)
  static String? getCurrentUrl() {
    if (!kIsWeb) return null;
    debugPrint('WebUtils: URL getter not implemented yet');
    return null;
  }

  /// Checks if app is running in PWA mode (placeholder)
  static bool get isPWA {
    if (!kIsWeb) return false;
    debugPrint('WebUtils: PWA detection not implemented yet');
    return false;
  }

  /// Gets screen size (placeholder)
  static Map<String, int> getScreenSize() {
    if (!kIsWeb) return {};
    debugPrint('WebUtils: Screen size detection not implemented yet');
    return {};
  }

  /// Gets viewport size (placeholder)
  static Map<String, int> getViewportSize() {
    if (!kIsWeb) return {};
    debugPrint('WebUtils: Viewport size detection not implemented yet');
    return {};
  }
}
