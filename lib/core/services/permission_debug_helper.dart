import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart' show AppDatabase;
import '../services/auth_service.dart';
import '../services/permission_sync_service.dart';

/// Helper class for debugging permission issues on client systems
class PermissionDebugHelper {
  static bool _hasLogged = false;
  
  /// Comprehensive permission system diagnostic
  static Future<void> diagnosePermissionSystem(String? token) async {
    if (_hasLogged) return; // Log once per session
    _hasLogged = true;
    
    debugPrint('=== PERMISSION SYSTEM DIAGNOSTIC ===');
    debugPrint('Token available: ${token != null && token.isNotEmpty}');
    
    try {
      // 1. Check database connectivity
      final db = AppDatabase.instanceIfInitialized;
      debugPrint('Database initialized: ${db != null}');
      
      if (db != null) {
        try {
          final testQuery = await db.customSelect('SELECT COUNT(*) as count FROM users').getSingle();
          debugPrint('Database connectivity: OK (${testQuery.data['count']} users found)');
        } catch (e) {
          debugPrint('Database connectivity ERROR: $e');
        }
      }
      
      // 2. Check current user state
      final currentUser = AuthService.currentUser;
      debugPrint('Current user: ${currentUser != null ? currentUser['email'] : 'null'}');
      if (currentUser != null) {
        debugPrint('User role: ${currentUser['role']}');
        debugPrint('User companyId: ${currentUser['companyId']}');
        debugPrint('PermissionsMap present: ${currentUser['permissionsMap'] != null}');
      }
      
      // 3. Check permission sync service state
      debugPrint('PermissionSyncService.hasCachedPermissions: ${PermissionSyncService.hasCachedPermissions}');
      if (PermissionSyncService.hasCachedPermissions) {
        final cached = PermissionSyncService.cachedPermissionsMap;
        debugPrint('Cached permissions count: ${cached?.length}');
        if (cached != null) {
          cached.forEach((key, value) {
            debugPrint('  - $key: $value');
          });
        }
      }
      
      // 4. Test permission loading
      if (token != null) {
        try {
          final testUser = await PermissionSyncService.getPermissionsInstantly(token);
          debugPrint('Permission loading test: ${testUser != null ? 'SUCCESS' : 'FAILED'}');
          if (testUser != null) {
            final isLoaded = PermissionSyncService.arePermissionsFullyLoaded(testUser);
            debugPrint('Permissions fully loaded: $isLoaded');
          }
        } catch (e) {
          debugPrint('Permission loading test ERROR: $e');
        }
      }
      
    } catch (e) {
      debugPrint('Diagnostic ERROR: $e');
    }
    
    debugPrint('=== END DIAGNOSTIC ===');
  }
  
  /// Log permission state changes for debugging
  static void logPermissionStateChange(String event, Map<String, dynamic>? user) {
    if (!kDebugMode) return; // Only log in debug mode
    
    debugPrint('PERMISSION_STATE_CHANGE: $event');
    if (user != null) {
      debugPrint('  User: ${user['email']}');
      debugPrint('  Role: ${user['role']}');
      debugPrint('  PermissionsMap: ${user['permissionsMap'] != null ? 'PRESENT' : 'MISSING'}');
    }
  }
  
  /// Check for common permission issues
  static Future<String> checkCommonIssues() async {
    final issues = <String>[];
    
    try {
      // Check database
      final db = AppDatabase.instanceIfInitialized;
      if (db == null) {
        issues.add('Database not initialized');
      }
      
      // Check current user
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        issues.add('No current user');
      } else {
        if (currentUser['permissionsMap'] == null) {
          issues.add('No permissionsMap in current user');
        }
      }
      
      // Check permission sync service
      if (!PermissionSyncService.hasCachedPermissions) {
        issues.add('No cached permissions');
      }
      
    } catch (e) {
      issues.add('Error during check: $e');
    }
    
    return issues.isEmpty ? 'No issues detected' : issues.join(', ');
  }
}
