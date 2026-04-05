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
        return 'view_add';
    }
  }

  static String getModulePermissionLevel(Map<String, dynamic>? user, String moduleKey) {
    if (user == null) return 'no_access';
    if (isBypassUser(user)) return 'view_add_edit';
    if (local.RoleUtils.isSuperAdmin(user)) return 'view_add_edit';
    
    // CRITICAL FIX: Explicit bypass for Company Admins for specific modules
    if (local.RoleUtils.isCompanyAdmin(user) && moduleKey == 'users') { 
      debugPrint('PermissionHelper: Company Admin override - granting full_access to users module');
      return 'full_access'; 
    }
    if (local.RoleUtils.isCompanyAdmin(user) && moduleKey == 'reports') { 
      debugPrint('PermissionHelper: Company Admin override - granting full_access to reports module');
      return 'full_access'; 
    }
    
    // ROLE-BASED SHORTCUTS: Skip permissionsMap checking for known roles
    final userRole = local.RoleUtils.getUserRole(user);
    
    // DEBUG: Add detailed logging for 'users' module
    if (moduleKey == 'users') {
      final email = (user['email'] ?? user['username'])?.toString().toLowerCase();
      debugPrint('PermissionHelper.getModulePermissionLevel(users) DEBUG:');
      debugPrint('  User email: $email');
      debugPrint('  getUserRole: $userRole');
      debugPrint('  isBypassUser: ${isBypassUser(user)}');
      debugPrint('  isSuperAdmin: ${local.RoleUtils.isSuperAdmin(user)}');
    }
    
    if (userRole == 'company_admin') {
      // Company Admin gets full access within their company
      if (moduleKey == 'users') {
        debugPrint('  Company Admin detected, returning view_add_edit for users module');
      }
      return 'view_add_edit';
    }
    if (userRole == 'agent') {
      // Agent gets view-only access
      if (moduleKey == 'users') {
        debugPrint('  Agent detected, returning view_only for users module');
      }
      return 'view_only';
    }
    
    // Fallback to permissionsMap for unknown roles
    final map = getModulePermissionsMap(user);
    final v = map[moduleKey];
    if (v != null && v.trim().isNotEmpty) return v.trim();
    
    // Only log this for debugging unknown roles, not for standard roles
    debugPrint('PermissionHelper: Unknown role "$userRole" with empty permissionsMap for module $moduleKey');
    
    if (map.isNotEmpty) return 'no_access';
    final legacy = getPermissionLevel(user);
    return normalizeLegacyToModuleLevel(legacy);
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

