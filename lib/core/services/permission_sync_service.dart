import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import '../role_utils.dart' as local;
import 'app_storage.dart';
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';

/// Service to handle permission synchronization and refresh
/// OPTIMIZED: Singleton with global permissions cache and minimal logging
class PermissionSyncService {
  // Singleton instance
  static final PermissionSyncService _instance = PermissionSyncService._internal();
  factory PermissionSyncService() => _instance;
  PermissionSyncService._internal();
  
  // Global permissions cache
  static Map<String, dynamic>? _cachedPermissionsMap;
  static Map<String, dynamic>? _cachedUser;
  static String? _lastUserId;
  static bool _hasLoggedInitialization = false;
  
  // Getters for global cache access
  static Map<String, dynamic>? get cachedPermissionsMap => _cachedPermissionsMap;
  static Map<String, dynamic>? get cachedUser => _cachedUser;
  static bool get hasCachedPermissions => _cachedPermissionsMap != null && _cachedPermissionsMap!.isNotEmpty;
  /// Initialize permissions cache with immediate local data injection
  /// OPTIMIZED: No timeouts, immediate cache population from local database
  static Future<void> initializePermissionsCache(String? token) async {
    if (token == null) return;
    
    // Check if already cached for this user
    if (_cachedUser != null && _lastUserId == token) {
      if (!_hasLoggedInitialization) {
        debugPrint('PermissionSyncService: Permissions already cached for user');
        _hasLoggedInitialization = true;
      }
      return;
    }
    
    // Get user data immediately from local database (no Firestore wait)
    final user = await AuthService.getCurrentUser(token, waitForFirestore: false);
    
    if (user != null) {
      // Extract and cache permissionsMap immediately
      final permissionsMap = _extractPermissionsMap(user);
      
      if (permissionsMap != null && permissionsMap.isNotEmpty) {
        _cachedUser = user;
        _cachedPermissionsMap = permissionsMap;
        _lastUserId = token;
        
        if (!_hasLoggedInitialization) {
          debugPrint('PermissionSyncService: Permissions cached successfully for ${user['email']}');
          debugPrint('PermissionSyncService: Available modules: ${permissionsMap.keys.toList()}');
          _hasLoggedInitialization = true;
        }
      } else {
        if (!_hasLoggedInitialization) {
          debugPrint('PermissionSyncService: No permissions found for user ${user['email']}');
          _hasLoggedInitialization = true;
        }
      }
    }
  }
  
  /// Extract permissionsMap from user object
  static Map<String, dynamic>? _extractPermissionsMap(Map<String, dynamic> user) {
    try {
      // Check permissionsMap field first
      var permissionsMapRaw = user['permissionsMap'];
      
      if (permissionsMapRaw == null) {
        // Check inside permissions field
        final permissionsField = user['permissions'];
        if (permissionsField != null) {
          Map<String, dynamic>? permissions;
          if (permissionsField is String) {
            permissions = jsonDecode(permissionsField) as Map<String, dynamic>?;
          } else if (permissionsField is Map<String, dynamic>) {
            permissions = permissionsField;
          }
          
          if (permissions != null) {
            permissionsMapRaw = permissions['permissionsMap'];
          }
        }
      }
      
      if (permissionsMapRaw != null) {
        if (permissionsMapRaw is Map) {
          return Map<String, dynamic>.from(permissionsMapRaw);
        } else if (permissionsMapRaw is String) {
          final decoded = jsonDecode(permissionsMapRaw);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (e) {
      debugPrint('PermissionSyncService: Error extracting permissionsMap: $e');
    }
    
    return null;
  }
  
  /// Force permission refresh and update cache
  static Future<Map<String, dynamic>?> refreshUserPermissions(String? token) async {
    if (token == null) return null;

    // Clear cache to force fresh data fetch
    _clearCache();
    AuthService.clearUserCache();
    
    // Re-initialize cache with fresh data
    await initializePermissionsCache(token);
    
    return _cachedUser;
  }

  /// Check if user permissions are fully loaded and valid
  /// OPTIMIZED: Uses global cache first, minimal logging
  static bool arePermissionsFullyLoaded(Map<String, dynamic>? user) {
    // First check global cache
    if (_cachedPermissionsMap != null && _cachedPermissionsMap!.isNotEmpty) {
      return true;
    }
    
    // Fallback to user object check
    if (user == null) {
      return false;
    }
    
    final permissionsMap = _extractPermissionsMap(user);
    return permissionsMap != null && permissionsMap.isNotEmpty;
  }

  /// Get permissions immediately without timeout
  /// OPTIMIZED: Returns cached permissions or loads them instantly from local database
  static Future<Map<String, dynamic>?> getPermissionsInstantly(String? token) async {
    if (token == null) return null;

    // Return cached permissions if available
    if (_cachedPermissionsMap != null && _cachedPermissionsMap!.isNotEmpty && _lastUserId == token) {
      return _cachedUser;
    }
    
    // Initialize cache immediately from local database
    await initializePermissionsCache(token);
    
    return _cachedUser;
  }

  /// Clear global permissions cache
  static void _clearCache() {
    _cachedPermissionsMap = null;
    _cachedUser = null;
    _lastUserId = null;
    _hasLoggedInitialization = false;
  }
  
  /// Enhanced logout that clears all permission-related caches
  static Future<void> clearAllPermissionCaches() async {
    debugPrint('PermissionSyncService: Clearing all permission caches...');
    
    // Clear global cache
    _clearCache();
    
    // Clear AuthService cache
    AuthService.clearUserCache();
    
    // Clear any additional permission-related storage
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      settings.remove('currentUserRole');
      settings.remove('currentUserCompanyId');
      settings.remove('cachedRole');
      settings.remove('cachedCompanyId');
      settings.remove('cachedPermissionsMap');
      await storage.writeSettings(settings);
    } catch (e) {
      debugPrint('PermissionSyncService: Error clearing permission settings: $e');
    }
    
    debugPrint('PermissionSyncService: All permission caches cleared');
  }

  /// Comprehensive logout that clears all caches and handles Firebase cleanup
  static Future<void> performLogout(String? sessionId) async {
    debugPrint('PermissionSyncService: Performing comprehensive logout...');
    
    // Step 1: Clear all permission caches first
    await clearAllPermissionCaches();
    
    // Step 2: Revoke session if provided
    if (sessionId != null) {
      try {
        await AuthService.revokeSession(sessionId);
        debugPrint('PermissionSyncService: Session revoked');
      } catch (e) {
        debugPrint('PermissionSyncService: Error revoking session: $e');
      }
    }
    
    // Step 3: Clear app storage settings
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      settings.remove('currentSessionId');
      settings.remove('authToken');
      settings.remove('currentUserRole');
      settings.remove('currentUserCompanyId');
      settings.remove('cachedRole');
      settings.remove('cachedCompanyId');
      settings.remove('cachedPermissionsMap');
      await storage.writeSettings(settings);
      debugPrint('PermissionSyncService: App storage cleared');
    } catch (e) {
      debugPrint('PermissionSyncService: Error clearing app storage: $e');
    }
    
    // Step 4: Clear user cache files
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final usersFile = io.File('${appDir.path}${io.Platform.pathSeparator}users.json');
      if (await usersFile.exists()) {
        await usersFile.delete();
        debugPrint('PermissionSyncService: Users file deleted');
      }
      final sessionsFile = io.File('${appDir.path}${io.Platform.pathSeparator}sessions.json');
      if (await sessionsFile.exists()) {
        await sessionsFile.delete();
        debugPrint('PermissionSyncService: Sessions file deleted');
      }
    } catch (e) {
      debugPrint('PermissionSyncService: Error clearing cache files: $e');
    }
    
    // Step 5: Firebase cleanup (non-Windows only)
    if (!kIsWeb && !io.Platform.isWindows && Firebase.apps.isNotEmpty) {
      try {
        await fb.FirebaseAuth.instance.signOut();
        debugPrint('PermissionSyncService: Firebase sign-out completed');
      } catch (e) {
        debugPrint('PermissionSyncService: Firebase sign-out error: $e');
      }
      
      try {
        await FirebaseFirestore.instance.terminate();
        debugPrint('PermissionSyncService: Firestore terminated');
      } catch (e) {
        debugPrint('PermissionSyncService: Firestore terminate error: $e');
      }
    }
    
    debugPrint('PermissionSyncService: Comprehensive logout completed');
  }
}
