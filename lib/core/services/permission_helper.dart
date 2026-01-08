import 'dart:convert';
import 'package:shared/shared.dart';

/// Global permission helper for checking user permissions
/// Based on permission levels: 'view_only', 'view_add', 'full_access', 'no_access'
class PermissionHelper {
  /// Get permission level from user object
  /// Returns: 'view_only', 'view_add', 'full_access', 'no_access', or null
  static String? getPermissionLevel(Map<String, dynamic>? user) {
    if (user == null) return null;
    
    // Super Admin always has full access
    if (RoleUtils.isSuperAdmin(user)) return 'full_access';
    
    final permissions = user['permissions'];
    // Legacy installs may not have permissions persisted for non-super users.
    // Default Agents/Company Admins to view_add (can view + add) so modules are visible.
    if (permissions == null) {
      if (RoleUtils.isAgent(user) || RoleUtils.isCompanyAdmin(user)) return 'view_add';
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
    final raw = perms['permissionsMap'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }
    return const {};
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
    if (RoleUtils.isSuperAdmin(user)) return 'view_add_edit';
    final map = getModulePermissionsMap(user);
    final v = map[moduleKey];
    if (v != null && v.trim().isNotEmpty) return v.trim();
    if (map.isNotEmpty) return 'no_access';
    final legacy = getPermissionLevel(user);
    return normalizeLegacyToModuleLevel(legacy);
  }

  static bool canViewModule(Map<String, dynamic>? user, String moduleKey) {
    final level = getModulePermissionLevel(user, moduleKey);
    return level != 'no_access';
  }

  static bool canAddModule(Map<String, dynamic>? user, String moduleKey) {
    if (user == null) return false;
    if (RoleUtils.isSuperAdmin(user) || RoleUtils.isCompanyAdmin(user)) {
      return canViewModule(user, moduleKey);
    }
    final level = getModulePermissionLevel(user, moduleKey);
    return level == 'view_add' || level == 'view_add_edit';
  }

  static bool canEditModule(Map<String, dynamic>? user, String moduleKey) {
    if (user == null) return false;
    if (RoleUtils.isSuperAdmin(user) || RoleUtils.isCompanyAdmin(user)) {
      return canViewModule(user, moduleKey);
    }
    final level = getModulePermissionLevel(user, moduleKey);
    return level == 'view_add_edit';
  }

  static bool canDeleteModule(Map<String, dynamic>? user, String moduleKey) {
    if (user == null) return false;
    if (RoleUtils.isSuperAdmin(user) || RoleUtils.isCompanyAdmin(user)) {
      return canViewModule(user, moduleKey);
    }
    return false;
  }
  
  /// Check if user can view (any permission except 'no_access')
  static bool canView(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (RoleUtils.isSuperAdmin(user)) return true;
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
    if (RoleUtils.isSuperAdmin(user) || RoleUtils.isCompanyAdmin(user)) return true;
    final level = getPermissionLevel(user);
    return level == 'view_add' || level == 'full_access';
  }
  
  /// Check if user can edit data
  static bool canEdit(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (RoleUtils.isSuperAdmin(user) || RoleUtils.isCompanyAdmin(user)) return true;
    final level = getPermissionLevel(user);
    return level == 'full_access';
  }
  
  /// Check if user can delete data
  static bool canDelete(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (RoleUtils.isSuperAdmin(user) || RoleUtils.isCompanyAdmin(user)) return true;
    return false;
  }
  
  /// Generic permission check based on action type
  /// ActionType: 'view', 'add', 'edit', 'delete'
  static bool hasPermission(Map<String, dynamic>? user, String actionType) {
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

