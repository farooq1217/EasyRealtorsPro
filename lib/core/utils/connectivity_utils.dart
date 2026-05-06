import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Unified connectivity utility to avoid redundancy across services
class ConnectivityUtils {
  static const String _pingUrl = 'https://www.google.com';
  static const Duration _timeout = Duration(seconds: 10); // Increased from 5 to 10 seconds
  
  // Debounce and caching mechanism
  static DateTime? _lastCheckTime;
  static bool? _lastCheckResult;
  static const Duration _cacheValidity = Duration(seconds: 30); // Cache for 30 seconds
  static const Duration _debounceDelay = Duration(milliseconds: 500); // Prevent rapid checks
  
  /// Check if internet connectivity is available with debounce and caching
  /// Returns false on any error to ensure graceful degradation
  static Future<bool> hasInternetConnection({bool forceRefresh = false}) async {
    final now = DateTime.now();
    
    // Check cache first (unless force refresh)
    if (!forceRefresh && 
        _lastCheckTime != null && 
        _lastCheckResult != null && 
        now.difference(_lastCheckTime!) < _cacheValidity) {
      debugPrint('ConnectivityUtils: Using cached result: $_lastCheckResult');
      return _lastCheckResult!;
    }
    
    // Debounce rapid successive calls
    if (_lastCheckTime != null && now.difference(_lastCheckTime!) < _debounceDelay) {
      debugPrint('ConnectivityUtils: Debouncing rapid check, returning cached result');
      return _lastCheckResult ?? false;
    }
    
    _lastCheckTime = now;
    
    try {
      debugPrint('ConnectivityUtils: Checking internet connection...');
      final response = await http.head(
        Uri.parse(_pingUrl),
      ).timeout(_timeout);
      
      final isConnected = response.statusCode >= 200 && response.statusCode < 300;
      _lastCheckResult = isConnected;
      
      debugPrint('ConnectivityUtils: Connection check result: $isConnected');
      return isConnected;
    } catch (e) {
      debugPrint('ConnectivityUtils: Internet check failed: $e');
      _lastCheckResult = false;
      return false;
    }
  }
  
  /// Quick check without network call (uses cache only)
  static bool getQuickConnectionStatus() {
    if (_lastCheckTime == null || _lastCheckResult == null) return false;
    
    final now = DateTime.now();
    if (now.difference(_lastCheckTime!) > _cacheValidity) {
      return false; // Cache expired
    }
    
    return _lastCheckResult!;
  }
  
  /// Clear connection cache (useful after network changes)
  static void clearCache() {
    _lastCheckTime = null;
    _lastCheckResult = null;
    debugPrint('ConnectivityUtils: Cache cleared');
  }
  
  /// Get Windows LocalAppData path with null safety
  /// Returns empty string if not available (should never happen on Windows)
  static String getLocalAppDataPath() {
    return Platform.environment['LOCALAPPDATA'] ?? '';
  }
  
  /// Windows-specific connectivity check with enhanced error handling
  static Future<bool> hasInternetConnectionWindows({bool forceRefresh = false}) async {
    if (!Platform.isWindows) {
      return hasInternetConnection(forceRefresh: forceRefresh);
    }
    
    // Windows-specific: Additional timeout and retry logic
    try {
      return await hasInternetConnection(forceRefresh: forceRefresh)
          .timeout(const Duration(seconds: 15)); // Additional timeout for Windows
    } catch (e) {
      debugPrint('ConnectivityUtils: Windows connection check failed: $e');
      return false;
    }
  }
}
