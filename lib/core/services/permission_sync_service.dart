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
  // Permission sync state tracking
  static bool _isPermissionSyncInProgress = false;
  static String? _currentSyncToken;
  
  /// HYBRID: Smart permission loading with ONLINE + OFFLINE + HYBRID modes
  static Future<Map<String, dynamic>?> loadPermissionsSmart(String? token) async {
    if (token == null) return null;
    
    _isPermissionSyncInProgress = true;
    _currentSyncToken = token;
    
    try {
      debugPrint('🔍 PermissionSyncService: Starting HYBRID permission loading...');
      
      // STRATEGY 1: Try LOCAL database first (FAST - works OFFLINE)
      final localUser = await AuthService.getCurrentUser(token, waitForFirestore: false);
      if (localUser != null && _hasValidPermissions(localUser)) {
        debugPrint('✅ PermissionSyncService: Permissions loaded from LOCAL database (OFFLINE mode)');
        _cacheUserPermissions(localUser, token);
        return localUser;
      }
      
      // STRATEGY 2: Try Firestore (ONLINE mode)
      try {
        debugPrint('⚡ PermissionSyncService: Local not available, trying Firestore (ONLINE mode)...');
        final firestoreUser = await AuthService.getCurrentUser(token, waitForFirestore: true);
        if (firestoreUser != null && _hasValidPermissions(firestoreUser)) {
          // CACHE to local database for OFFLINE use
          await _cachePermissionsLocally(firestoreUser);
          debugPrint('✅ PermissionSyncService: Permissions loaded from Firestore + CACHED locally (HYBRID mode)');
          _cacheUserPermissions(firestoreUser, token);
          return firestoreUser;
        }
      } catch (e) {
        debugPrint('⚠️ PermissionSyncService: Firestore unavailable: $e');
      }
      
      // STRATEGY 3: Emergency fallback (last resort)
      debugPrint('🚨 PermissionSyncService: Both sources failed, using emergency fallback');
      final emergencyUser = _getEmergencyPermissions(token);
      if (emergencyUser != null) {
        _cacheUserPermissions(emergencyUser, token);
        return emergencyUser;
      }
      
      return null;
    } finally {
      _isPermissionSyncInProgress = false;
      _currentSyncToken = null;
    }
  }
  
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
  
  /// Check if permission sync is currently in progress
  static bool isPermissionSyncInProgress() {
    return _isPermissionSyncInProgress;
  }
  
  /// Check if user has valid permissions structure
 static bool _hasValidPermissions(Map<String, dynamic>? user) {
  if (user == null) return false;
  
  // Try direct permissionsMap first
  var permissionsMap = user['permissionsMap'];
  
  // If not found, try to extract from nested permissions field
  if (permissionsMap == null) {
    final permissions = user['permissions'];
    if (permissions != null) {
      try {
        Map<String, dynamic>? perms;
        if (permissions is String) {
          perms = jsonDecode(permissions) as Map<String, dynamic>?;
        } else if (permissions is Map) {
          perms = permissions as Map<String, dynamic>?;
        }
        
        if (perms != null) {
          if (perms.containsKey('permissionsMap') && perms['permissionsMap'] is Map) {
            permissionsMap = perms['permissionsMap'];
          } else {
            permissionsMap = perms;
          }
        }
      } catch (_) {
        return false;
      }
    }
  }
  
  // Handle string permissionsMap
  if (permissionsMap is String) {
    try {
      permissionsMap = jsonDecode(permissionsMap);
    } catch (_) {
      return false;
    }
  }
  
  return permissionsMap != null && 
         (permissionsMap is Map) && 
         (permissionsMap as Map).isNotEmpty;
}
  
  /// Cache user permissions in global cache
  static void _cacheUserPermissions(Map<String, dynamic> user, String token) {
    final permissionsMap = _extractPermissionsMap(user);
    if (permissionsMap != null && permissionsMap.isNotEmpty) {
      _cachedUser = user;
      _cachedPermissionsMap = permissionsMap;
      _lastUserId = token;
      
      debugPrint('PermissionSyncService: Cached permissions for ${user['email']}');
      debugPrint('PermissionSyncService: Available modules: ${permissionsMap.keys.toList()}');
    }
  }
  
  /// Cache permissions locally for offline use
  static Future<void> _cachePermissionsLocally(Map<String, dynamic> user) async {
    try {
      // This will trigger AuthService's local caching mechanism
      // Cache user data locally for offline use
      final storage = AppStorage();
      final settings = await storage.readSettings();
      settings['cachedUser'] = user;
      await storage.writeSettings(settings);
      debugPrint('PermissionSyncService: Permissions cached locally for offline use');
    } catch (e) {
      debugPrint('PermissionSyncService: Error caching permissions locally: $e');
    }
  }
  
  /// Get emergency permissions for last resort
  static Map<String, dynamic>? _getEmergencyPermissions(String? token) {
    if (token == null) return null;
    
    try {
      final payload = _decodeJWT(token);
      if (payload == null) return null;
      
      final email = payload['email'] as String?;
      if (email == null) return null;
      
      // Emergency: Basic permissions for authenticated user
      final emergencyUser = {
        'id': email.toLowerCase(),
        'email': email,
        'name': payload['name'] ?? email.split('@')[0],
        'role': 'agent', // Safe default
        'permissionsMap': {
          'dashboard': 'view_only',
          'settings': 'view_only',
        },
      };
      
      debugPrint('PermissionSyncService: Emergency permissions created for $email');
      return emergencyUser;
    } catch (e) {
      debugPrint('PermissionSyncService: Error creating emergency permissions: $e');
      return null;
    }
  }
  
  /// Decode JWT token (helper method)
  static Map<String, dynamic>? _decodeJWT(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      // Pad base64 string if needed
      final padding = '=' * ((4 - payload.length % 4) % 4);
      final normalizedPayload = payload + padding;
      
      final decoded = utf8.decode(base64.decode(normalizedPayload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('PermissionSyncService: Error decoding JWT: $e');
      return null;
    }
  }
  
  /// Extract permissionsMap from user object
  /// Extract permissionsMap from user object
  /// Extract permissionsMap from user object
  static Map<String, dynamic>? _extractPermissionsMap(Map<String, dynamic> user) {
    try {
      // debugPrint('PermissionSyncService: Extracting permissionsMap for user ${user['email']}');
      
      var permissionsMapRaw = user['permissionsMap'];
      
      // ✅ FIX: Handle empty permissionsMap by generating from role
      if (permissionsMapRaw != null) {
        if (permissionsMapRaw is Map && (permissionsMapRaw as Map).isEmpty) {
          // debugPrint('PermissionSyncService: permissionsMap is empty, generating from role');
          final permissionsField = user['permissions'];
          if (permissionsField != null) {
            Map<String, dynamic>? decodedPerms;
            if (permissionsField is String) {
              // ✅ FIX: Added explicit cast here
              decodedPerms = jsonDecode(permissionsField) as Map<String, dynamic>?;
            } else if (permissionsField is Map) {
              // ✅ FIX: Added explicit cast here
              decodedPerms = Map<String, dynamic>.from(permissionsField);
            }
            
            if (decodedPerms != null) {
              permissionsMapRaw = _generatePermissionsMapFromRole(decodedPerms, user);
            }
          }
        }
      } 
      // ✅ FIX: If permissionsMap is null, try to generate from permissions field
      else {
        final permissionsField = user['permissions'];
        
        if (permissionsField != null) {
          Map<String, dynamic>? decodedPerms;
          if (permissionsField is String) {
            // ✅ FIX: Added explicit cast here
            decodedPerms = jsonDecode(permissionsField) as Map<String, dynamic>?;
          } else if (permissionsField is Map) {
            // ✅ FIX: Added explicit cast here
            decodedPerms = Map<String, dynamic>.from(permissionsField);
          }
          
          if (decodedPerms != null) {
            permissionsMapRaw = _generatePermissionsMapFromRole(decodedPerms, user);
          }
        }
      }
      
      // ✅ FIX: Parse and return the map safely without undefined 'result' variable
      if (permissionsMapRaw != null) {
        if (permissionsMapRaw is Map) {
          final result = Map<String, dynamic>.from(permissionsMapRaw);
          return result;
        } else if (permissionsMapRaw is String) {
          final decoded = jsonDecode(permissionsMapRaw);
          if (decoded is Map) {
            final result = Map<String, dynamic>.from(decoded);
            return result;
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('PermissionSyncService: Error extracting permissionsMap: $e');
      return null;
    }
  }
  /// Generate permissionsMap from role-based permissions
  static Map<String, dynamic> _generatePermissionsMapFromRole(Map<String, dynamic> permissions, Map<String, dynamic> user) {
    final role = permissions['role']?.toString().toLowerCase();
    final permission = permissions['permission']?.toString().toLowerCase();
    
    debugPrint('PermissionSyncService: Generating permissionsMap for role: $role, permission: $permission');
    
    Map<String, String> permissionsMap = {};
    
    if (role == 'super_admin') {
      // Super Admin gets full access to all modules
      final allModules = [
        'users', 'companies', 'trading', 'inventory', 'rental', 'expenditure', 
        'agent_working', 'reports', 'dashboard', 'settings'
      ];
      for (final module in allModules) {
        permissionsMap[module] = 'full_access';
      }
    } else if (role == 'company_admin') {
      // Company Admin gets full access to users and reports, limited access to others
      permissionsMap['users'] = 'full_access';
      permissionsMap['reports'] = 'full_access';
      permissionsMap['dashboard'] = 'view_add_edit';
      permissionsMap['settings'] = 'view_add_edit';
      
      // For other modules, check if there are explicit permissions in the permissions object
      final modules = ['trading', 'inventory', 'rental', 'expenditure', 'agent_working'];
      for (final module in modules) {
        // Check if user has been assigned this module (would be in permissionsMap)
        if (permissions.containsKey(module)) {
          permissionsMap[module] = 'view_add_edit'; // Company admin gets full access to assigned modules
        } else {
          permissionsMap[module] = 'no_access';
        }
      }
    } else if (role == 'agent') {
      // Agent gets access based on assigned modules
      final modules = ['trading', 'inventory', 'rental', 'expenditure', 'agent_working'];
      for (final module in modules) {
        if (permissions.containsKey(module)) {
          permissionsMap[module] = 'view_add_edit'; // Agents get view_add_edit for assigned modules
        } else {
          permissionsMap[module] = 'no_access';
        }
      }
      permissionsMap['dashboard'] = 'view_only';
      permissionsMap['settings'] = 'view_only';
    } else {
      // Default/unknown role - minimal access
      permissionsMap['dashboard'] = 'view_only';
      permissionsMap['settings'] = 'view_only';
    }
    
    debugPrint('PermissionSyncService: Generated permissionsMap: $permissionsMap');
    return Map<String, dynamic>.from(permissionsMap);
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
