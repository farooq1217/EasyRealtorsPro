import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
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
      if (localUser != null) {
        final enriched = _ensurePermissionsMap(localUser);
        if (_hasValidPermissions(enriched)) {
          debugPrint('✅ PermissionSyncService: Permissions loaded from LOCAL database (OFFLINE mode)');
          _cacheUserPermissions(enriched, token);
          return enriched;
        }
      }
      
      // STRATEGY 2: Try Firestore (ONLINE mode)
      try {
        debugPrint('⚡ PermissionSyncService: Local not available, trying Firestore (ONLINE mode)...');
        final firestoreUser = await AuthService.getCurrentUser(token, waitForFirestore: true);
        if (firestoreUser != null) {
          final enriched = _ensurePermissionsMap(firestoreUser);
          if (_hasValidPermissions(enriched)) {
            // CACHE to local database for OFFLINE use
            await _cachePermissionsLocally(enriched);
            debugPrint('✅ PermissionSyncService: Permissions loaded from Firestore + CACHED locally (HYBRID mode)');
            _cacheUserPermissions(enriched, token);
            return enriched;
          }
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
  
  /// Ensure user map has a top-level `permissionsMap` key.
  /// Handles all nested/flat/role-based structures found in offline SQLite data.
  static Map<String, dynamic> _ensurePermissionsMap(Map<String, dynamic> user) {
    // Already has a valid top-level permissionsMap? Return as-is.
    final existing = user['permissionsMap'];
    if (existing is Map && existing.isNotEmpty) return user;
    
    // Try to extract from permissions field
    final extracted = _extractPermissionsMap(user);
    if (extracted != null && extracted.isNotEmpty) {
      final result = Map<String, dynamic>.from(user);
      result['permissionsMap'] = extracted;
      // Also hoist role/companyId if available inside permissions
      if (result['role'] == null) {
        try {
          final perms = user['permissions'];
          Map<String, dynamic>? parsed;
          if (perms is String) {
            final raw = jsonDecode(perms);
            if (raw is Map) parsed = Map<String, dynamic>.from(raw);
          } else if (perms is Map) {
            parsed = Map<String, dynamic>.from(perms);
          }
          if (parsed?['role'] != null) result['role'] = parsed!['role'];
        } catch (_) {}
      }
      return result;
    }
    
    // Synthesize from role if nothing else works
    var role = user['role']?.toString().toLowerCase();
    if (role == null && user['permissions'] != null) {
      try {
        final perms = user['permissions'];
        Map<String, dynamic>? parsed;
        if (perms is String) {
          final raw = jsonDecode(perms);
          if (raw is Map) parsed = Map<String, dynamic>.from(raw);
        } else if (perms is Map) {
          parsed = Map<String, dynamic>.from(perms);
        }
        if (parsed?['role'] != null) {
          role = parsed!['role']?.toString().toLowerCase();
        }
      } catch (_) {}
    }

    if (role != null) {
      Map<String, dynamic>? synthesized;
      if (role == 'super_admin' || role == 'superadmin') {
        synthesized = <String, dynamic>{
          'users': 'full_access', 'companies': 'full_access',
          'trading': 'full_access', 'inventory': 'full_access',
          'rental': 'full_access', 'rental_items': 'full_access',
          'expenditure': 'full_access', 'agent_working': 'full_access',
          'reports': 'full_access', 'dashboard': 'full_access',
          'settings': 'full_access', 'todo': 'full_access',
        };
      } else if (role == 'company_admin' || role == 'companyadmin') {
        synthesized = <String, dynamic>{
          'users': 'full_access', 'trading': 'view_add_edit',
          'inventory': 'view_add_edit', 'rental': 'view_add_edit',
          'rental_items': 'view_add_edit', 'expenditure': 'view_add_edit',
          'agent_working': 'view_add_edit', 'reports': 'full_access',
          'dashboard': 'view_add_edit', 'settings': 'view_add_edit',
          'todo': 'view_add_edit',
        };
      } else if (role == 'agent') {
        synthesized = <String, dynamic>{
          'trading': 'view_add_edit', 'inventory': 'view_add_edit',
          'rental': 'view_add_edit', 'rental_items': 'view_add_edit',
          'expenditure': 'view_add_edit', 'agent_working': 'view_add_edit',
          'dashboard': 'view_only', 'settings': 'view_only',
          'todo': 'view_add_edit',
        };
      }
      if (synthesized != null) {
        debugPrint('PermissionSyncService: Synthesized permissionsMap from role=$role');
        final result = Map<String, dynamic>.from(user);
        result['permissionsMap'] = synthesized;
        if (result['role'] == null) {
          result['role'] = role;
        }
        return result;
      }
    }
    
    return user; // Return unchanged — _hasValidPermissions will handle the null case
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
    final rawUser = await AuthService.getCurrentUser(token, waitForFirestore: false);
    
    if (rawUser != null) {
      // ✅ Ensure top-level permissionsMap (handles nested/flat/role-based structures)
      final user = _ensurePermissionsMap(rawUser);
      
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
          final decoded = jsonDecode(permissions);
          if (decoded is Map) {
            perms = Map<String, dynamic>.from(decoded);
          }
        } else if (permissions is Map) {
          perms = Map<String, dynamic>.from(permissions);
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
      final Map<String, dynamic> emergencyUser = {
        'id': email.toLowerCase(),
        'email': email,
        'name': payload['name'] ?? email.split('@')[0],
        'role': 'agent', // Safe default
        'permissionsMap': <String, dynamic>{
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
      
      final decoded = utf8.decode(base64Url.decode(normalizedPayload));
      final decodedMap = jsonDecode(decoded);
      if (decodedMap is Map) {
        return Map<String, dynamic>.from(decodedMap);
      }
      return null;
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
    // Step 1: Try direct permissionsMap (top-level)
    var raw = user['permissionsMap'];
    
    // Step 2: If not found, try nested inside 'permissions' field
    if (raw == null && user['permissions'] != null) {
      final perms = user['permissions'];
      if (perms is String) {
        raw = jsonDecode(perms);
      } else if (perms is Map) {
        raw = perms;
      }
      
      // Handle nested permissionsMap inside permissions
      if (raw is Map && raw.containsKey('permissionsMap')) {
        raw = raw['permissionsMap'];
      }
    }
    
    // Step 3: Handle string → Map conversion
    if (raw is String) {
      raw = jsonDecode(raw);
    }
    
    // Step 4: Return clean Map or null
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    } else if (raw is Map) {
      return Map<String, dynamic>.from(raw.cast<String, dynamic>());
    }
    
    return null;
  } catch (e) {
    debugPrint('❌ PermissionSyncService: _extractPermissionsMap error: $e');
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
    if (user == null) {
      return false;
    }

    // First check global cache, ensuring it matches the queried user
    if (_cachedPermissionsMap != null && _cachedPermissionsMap!.isNotEmpty && _cachedUser != null) {
      final cachedEmail = _cachedUser!['email']?.toString().toLowerCase();
      final userEmail = user['email']?.toString().toLowerCase();
      final cachedId = _cachedUser!['id']?.toString();
      final userId = user['id']?.toString();
      
      if ((cachedEmail != null && cachedEmail == userEmail) || (cachedId != null && cachedId == userId)) {
        return true;
      }
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
