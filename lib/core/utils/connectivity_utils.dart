import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Unified connectivity utility to avoid redundancy across services
class ConnectivityUtils {
  static const String _pingUrl = 'https://www.google.com';
  static const Duration _timeout = Duration(seconds: 5);
  
  /// Check if internet connectivity is available
  /// Returns false on any error to ensure graceful degradation
  static Future<bool> hasInternetConnection() async {
    try {
      final response = await http.head(
        Uri.parse(_pingUrl),
      ).timeout(_timeout);
      
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ConnectivityUtils: Internet check failed: $e');
      return false;
    }
  }
  
  /// Get Windows LocalAppData path with null safety
  /// Returns empty string if not available (should never happen on Windows)
  static String getLocalAppDataPath() {
    return Platform.environment['LOCALAPPDATA'] ?? '';
  }
}
