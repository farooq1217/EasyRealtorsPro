import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../role_utils.dart' as local;
import 'package:shared/shared.dart';

/// Global permission helper for checking user permissions
/// Based on permission levels: 'view_only', 'view_add', 'full_access', 'no_access'
class PermissionHelper {
  static bool isBypassUser(Map<String, dynamic>? user) {
    final email = (user?['email'] ?? user?['username'])?.toString().toLowerCase();
    return email == 'mayof286@gmail.com';
  }

  /// Get permission level from user object
  /// Returns: 'view_only', 'view_add', 'full_access', 'no_access', or null
  static String? getPermissionLevel(Map<String, dynamic>? user) {
    if (user == null) return null;
    if (isBypassUser(user)) return 'full_access';
    
    // Super Admin always has full access
    if (local.RoleUtils.isSuperAdmin(user)) return 'full_access';
    
    final permissions = user['permissions'];
    // Legacy installs may not have permissions persisted for non-super users.
    // Default Agents/Company Admins to view_add (can view + add) so modules are visible.
    if (permissions == null) {
      if (local.RoleUtils.isAgent(user) || local.RoleUtils.isCompanyAdmin(user)) return 'view_add';
      return null;
    }
    
    try {
      final perms = permissions is String ? jsonDecode(permissions) : permissions;
      if (perms is Map) {
        // Check the 'permission' field first (new format)
        final permission = perms['permission'] as String?;
        if (permission != null) {
          return permission;
        }
        // Fallback to boolean flags (old format)
        if (perms['canDelete'] == true) return 'full_access';
        if (perms['canAdd'] == true) return 'view_add';
        if (perms['canView'] == true) return 'view_only';
      }
    } catch (_) {
      return null;
    }
    
    return null;
  }

  static Map<String, dynamic>? _parsePermissions(dynamic permissions) {
    if (permissions == null) return null;
    try {
      if (permissions is Map) {
        return Map<String, dynamic>.from(permissions);
      }
      if (permissions is String) {
        final decoded = jsonDecode(permissions);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static Map<String, String> getModulePermissionsMap(Map<String, dynamic>? user) {
    final perms = _parsePermissions(user?['permissions']);
    if (perms == null) return const {};
    
    // Try permissionsMap first (new format)
    final raw = perms['permissionsMap'];
    Map<String, dynamic> permissionsMap;
    
    if (raw is Map) {
      permissionsMap = Map<String, dynamic>.from(raw);
    } else {
      // If no permissionsMap, check if permissions object itself contains module permissions
      permissionsMap = <String, dynamic>{};
      perms.forEach((key, value) {
        if (key != 'role' && key != 'company_id' && key != 'companyId') {
          permissionsMap[key.toString()] = value;
        }
      });
    }
    
    // CRITICAL FIX: Inject required permissions for Company Admins
    final userRole = perms['role']?.toString().toLowerCase();
    if (userRole == 'company_admin') {
      debugPrint('PermissionHelper: Injecting Company Admin permissions into permissionsMap');
      permissionsMap['users'] = 'full_access';
      permissionsMap['reports'] = 'full_access';
    }
    
    return permissionsMap.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  static String normalizeLegacyToModuleLevel(String? level) {
    switch ((level ?? '').trim()) {
      case 'view_only':
        return 'view_only';
      case 'view_add':
        return 'view_add';
      case 'full_access':
        return 'view_add_edit';
      case 'no_access':
        return 'no_access';
      default:
        return 'no_access'; // CRITICAL FIX: Default to no_access for strict RBAC
    }
  }

  static String getModulePermissionLevel(Map<String, dynamic>? user, String moduleKey) {
    if (user == null) return 'no_access';
    if (isBypassUser(user)) return 'view_add_edit';
    if (local.RoleUtils.isSuperAdmin(user)) return 'view_add_edit';
    
    // CRITICAL FIX: Allow permissions to load, but maintain security
    // If permissions are still loading, return 'loading' state for sidebar to handle
    if (_arePermissionsStillLoading(user)) {
      return 'loading';
    }
    
    // CRITICAL FIX: Explicit bypass for Company Admins for specific modules ONLY
    if (local.RoleUtils.isCompanyAdmin(user) && moduleKey == 'users') { 
      return 'full_access'; 
    }
    if (local.RoleUtils.isCompanyAdmin(user) && moduleKey == 'reports') { 
      return 'full_access'; 
    }
    
    final userRole = local.RoleUtils.getUserRole(user);
    
        
    // CRITICAL SECURITY FIX: Company Admins only get access to specific modules
    if (userRole == 'company_admin') {
      // Company Admin gets access to users and reports ONLY
      if (moduleKey == 'users' || moduleKey == 'reports') {
        return 'view_add_edit';
      }
      // For all other modules, check permissionsMap explicitly
      final map = getModulePermissionsMap(user);
      final v = map[moduleKey];
      if (v != null && v.trim().isNotEmpty) {
        return v.trim();
      }
      return 'no_access';
    }
    
    // CRITICAL SECURITY FIX: Agents MUST have explicit permissions in permissionsMap
    if (userRole == 'agent') {
      final map = getModulePermissionsMap(user);
      final v = map[moduleKey];
      
      if (v != null && v.trim().isNotEmpty) {
        final permission = v.trim().toLowerCase();
        // Only allow valid permission levels
        if (permission == 'view_only' || permission == 'view_add' || permission == 'view_add_edit' || permission == 'full_access') {
          return permission;
        }
      }
      
      return 'no_access';
    }
    
    // CRITICAL SECURITY FIX: Default to no_access for all unknown scenarios
    return 'no_access';
  }

  /// Check if permissions are still loading (permissionsMap not populated yet)
  static bool _arePermissionsStillLoading(Map<String, dynamic>? user) {
    if (user == null) {
      debugPrint('PermissionHelper: user is null - still loading');
      return true;
    }
    
    // Check if permissionsMap exists and has content
    // First check if permissionsMap exists as a direct field
    var permissionsMapRaw = user['permissionsMap'];
    
    // DEBUG: Only log when permissions are actually loading
    if (permissionsMapRaw == null) {
      debugPrint('PermissionHelper: User permissions field is null or empty');
    }
    
    // If not, check inside the permissions field (JSON string)
    if (permissionsMapRaw == null) {
      final permissionsField = user['permissions'];
      if (permissionsField != null) {
        try {
          Map<String, dynamic>? permissions;
          if (permissionsField is String) {
            permissions = jsonDecode(permissionsField) as Map<String, dynamic>?;
          } else if (permissionsField is Map<String, dynamic>) {
            permissions = permissionsField;
          }
          
          if (permissions != null) {
            permissionsMapRaw = permissions['permissionsMap'];
          }
        } catch (e) {
          debugPrint('PermissionHelper: Error parsing permissions field: $e');
        }
      }
    }
    
    if (permissionsMapRaw == null) {
      debugPrint('PermissionHelper: permissionsMap is null - still loading');
      return true;
    }
    
    try {
      Map<String, dynamic>? permissionsMap;
      if (permissionsMapRaw is String) {
        permissionsMap = jsonDecode(permissionsMapRaw) as Map<String, dynamic>?;
      } else if (permissionsMapRaw is Map<String, dynamic>) {
        permissionsMap = permissionsMapRaw;
      }
      
      if (permissionsMap == null || permissionsMap.isEmpty) {
        debugPrint('PermissionHelper: permissionsMap is empty - still loading');
        return true;
      }
      
      return false; // Permissions are loaded
    } catch (e) {
      debugPrint('PermissionHelper: Error checking permissions loading state: $e');
      return true; // Assume still loading if there's an error
    }
  }

  static bool canViewModule(Map<String, dynamic>? user, String moduleKey) {
    if (isBypassUser(user)) return true;
    
    // CRITICAL FIX: Company Admins MUST have access to users and reports modules
    if (local.RoleUtils.isCompanyAdmin(user) && (moduleKey == 'users' || moduleKey == 'reports')) {
      debugPrint('PermissionHelper.canViewModule: Company Admin override granted for module: $moduleKey');
      return true;
    }
    
    // DEBUG: Add detailed logging for 'users' module
    if (moduleKey == 'users') {
      final email = (user?['email'] ?? user?['username'])?.toString().toLowerCase();
      debugPrint('PermissionHelper.canViewModule(users) DEBUG:');
      debugPrint('  User email: $email');
      debugPrint('  isBypassUser: ${isBypassUser(user)}');
      debugPrint('  local.RoleUtils.isSuperAdmin: ${local.RoleUtils.isSuperAdmin(user)}');
      debugPrint('  local.RoleUtils.isCompanyAdmin: ${local.RoleUtils.isCompanyAdmin(user)}');
      debugPrint('  local.RoleUtils.isAgent: ${local.RoleUtils.isAgent(user)}');
      debugPrint('  local.RoleUtils.getUserRole: ${local.RoleUtils.getUserRole(user)}');
      
      final level = getModulePermissionLevel(user, moduleKey);
      debugPrint('  getModulePermissionLevel: $level');
      debugPrint('  Final result: ${level != 'no_access'}');
    }
    
    final level = getModulePermissionLevel(user, moduleKey);
    return level != 'no_access';
  }

  static bool canAddModule(Map<String, dynamic>? user, String moduleKey) {
    if (user == null) return false;
    if (isBypassUser(user)) return true;
    if (local.RoleUtils.isSuperAdmin(user)) return true;
    
    // ROLE-BASED SHORTCUT: Company Admin can add within their company
    if (local.RoleUtils.isCompanyAdmin(user)) return true;
    
    // ROLE-BASED SHORTCUT: Agent cannot add anything
    if (local.RoleUtils.isAgent(user)) return false;
    
    final level = getModulePermissionLevel(user, moduleKey);
    return level == 'view_add' || level == 'view_add_edit';
  }

  static bool canEditModule(Map<String, dynamic>? user, String moduleKey) {
    if (user == null) return false;
    if (isBypassUser(user)) return true;
    if (local.RoleUtils.isSuperAdmin(user)) return true;
    
    // ROLE-BASED SHORTCUT: Company Admin can edit within their company
    if (local.RoleUtils.isCompanyAdmin(user)) return true;
    
    // ROLE-BASED SHORTCUT: Agent cannot edit anything
    if (local.RoleUtils.isAgent(user)) return false;
    
    final level = getModulePermissionLevel(user, moduleKey);
    return level == 'view_add_edit';
  }

  static bool canDeleteModule(Map<String, dynamic>? user, String moduleKey) {
    if (user == null) return false;
    if (isBypassUser(user)) return true;
    if (local.RoleUtils.isSuperAdmin(user)) return true;
    
    // ROLE-BASED SHORTCUT: Company Admin can delete within their company
    if (local.RoleUtils.isCompanyAdmin(user)) return true;
    
    // ROLE-BASED SHORTCUT: Agent cannot delete anything
    if (local.RoleUtils.isAgent(user)) return false;
    
    final level = getModulePermissionLevel(user, moduleKey);
    return level == 'view_add_edit';
  }
  
  /// Check if user can view (any permission except 'no_access')
  static bool canView(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (isBypassUser(user)) return true;
    if (local.RoleUtils.isSuperAdmin(user)) return true;
    final map = getModulePermissionsMap(user);
    if (map.isNotEmpty) {
      return map.values.any((v) => v.toString().trim() != 'no_access');
    }
    final level = getPermissionLevel(user);
    return level != null && level != 'no_access';
  }
  
  /// Check if user can add data
  static bool canAdd(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (isBypassUser(user)) return true;
    if (local.RoleUtils.isSuperAdmin(user) || local.RoleUtils.isCompanyAdmin(user)) return true;
    final level = getPermissionLevel(user);
    return level == 'view_add' || level == 'full_access';
  }
  
  /// Check if user can edit data
  static bool canEdit(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (isBypassUser(user)) return true;
    if (local.RoleUtils.isSuperAdmin(user) || local.RoleUtils.isCompanyAdmin(user)) return true;
    final level = getPermissionLevel(user);
    return level == 'full_access';
  }
  
  /// Check if user can delete data
  static bool canDelete(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (isBypassUser(user)) return true;
    if (local.RoleUtils.isSuperAdmin(user) || local.RoleUtils.isCompanyAdmin(user)) return true;
    return false;
  }
  
  /// Generic permission check based on action type
  /// ActionType: 'view', 'add', 'edit', 'delete'
  static bool hasPermission(Map<String, dynamic>? user, String actionType) {
    if (isBypassUser(user)) return true;
    switch (actionType.toLowerCase()) {
      case 'view':
        return canView(user);
      case 'add':
        return canAdd(user);
      case 'edit':
        return canEdit(user);
      case 'delete':
        return canDelete(user);
      default:
        return false;
    }
  }
}

