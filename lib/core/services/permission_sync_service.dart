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
/// CRITICAL: Ensures permissions are properly loaded and cached
class PermissionSyncService {
  /// Force permission refresh and ensure permissionsMap is fully loaded
  /// CRITICAL: This ensures that when a user logs in, their fresh permissions are loaded
  /// from local database (which already has permissionsMap) before UI navigation occurs
  static Future<Map<String, dynamic>?> refreshUserPermissions(String? token) async {
    if (token == null) return null;

    debugPrint('PermissionSyncService: Force refreshing user permissions...');
    
    // Clear cache to force fresh data fetch
    AuthService.clearUserCache();
    
    // Get current user from local data (which already has permissionsMap)
    final freshUser = await AuthService.getCurrentUser(token, waitForFirestore: false);
    
    if (freshUser != null) {
      debugPrint('PermissionSyncService: Permission refresh completed for ${freshUser['email']}');
      debugPrint('PermissionSyncService: User role: ${local.RoleUtils.getUserRole(freshUser)}');
      debugPrint('PermissionSyncService: Permissions: ${freshUser['permissions']}');
      debugPrint('PermissionSyncService: PermissionsMap: ${freshUser['permissionsMap']}');
      
      // The user update will be emitted automatically by getCurrentUser
    } else {
      debugPrint('PermissionSyncService: Permission refresh failed - no user data returned');
    }
    
    return freshUser;
  }

  /// Check if user permissions are fully loaded and valid
  /// Returns true if permissionsMap exists and has valid data
  static bool arePermissionsFullyLoaded(Map<String, dynamic>? user) {
    if (user == null) {
      debugPrint('PermissionSyncService: User is null - permissions not loaded');
      return false;
    }
    
    // Check if permissionsMap exists and has content
    final permissionsMapRaw = user['permissionsMap'];
    if (permissionsMapRaw == null) {
      debugPrint('PermissionSyncService: permissionsMap is null - permissions not loaded');
      return false;
    }
    
    try {
      Map<String, dynamic>? permissionsMap;
      if (permissionsMapRaw is String) {
        permissionsMap = jsonDecode(permissionsMapRaw) as Map<String, dynamic>?;
      } else if (permissionsMapRaw is Map<String, dynamic>) {
        permissionsMap = permissionsMapRaw;
      }
      
      if (permissionsMap == null || permissionsMap.isEmpty) {
        debugPrint('PermissionSyncService: Permissions not fully loaded - empty permissionsMap');
        return false;
      }
      
      debugPrint('PermissionSyncService: Permissions fully loaded with ${permissionsMap.length} module permissions');
      debugPrint('PermissionSyncService: Available modules: ${permissionsMap.keys.toList()}');
      return true;
    } catch (e) {
      debugPrint('PermissionSyncService: Error checking permissions loaded: $e');
      return false;
    }
  }

  /// Wait for permissions to be fully loaded with timeout
  /// Returns user data when permissions are available, or null on timeout
  static Future<Map<String, dynamic>?> waitForPermissionsLoad(
    String? token, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (token == null) return null;

    debugPrint('PermissionSyncService: Checking if permissions are already loaded...');
    
    // OPTIMIZATION: Check if permissions are already loaded before starting timeout loop
    final currentUser = await AuthService.getCurrentUser(token);
    if (currentUser != null && arePermissionsFullyLoaded(currentUser)) {
      debugPrint('PermissionSyncService: Permissions already loaded, skipping timeout');
      return currentUser;
    }
    
    debugPrint('PermissionSyncService: Permissions not loaded, waiting...');
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      final user = await AuthService.getCurrentUser(token);
      if (user != null && arePermissionsFullyLoaded(user)) {
        debugPrint('PermissionSyncService: Permissions loaded successfully in ${stopwatch.elapsedMilliseconds}ms');
        return user;
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    debugPrint('PermissionSyncService: Timeout waiting for permissions after ${stopwatch.elapsedMilliseconds}ms');
    return null;
  }

  /// Enhanced logout that clears all permission-related caches
  static Future<void> clearAllPermissionCaches() async {
    debugPrint('PermissionSyncService: Clearing all permission caches...');
    
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
      debugPrint('PermissionSyncService: Cleared permission-related settings');
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
