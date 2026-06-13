import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';

/// Utility class for role-based operations and permissions
class RoleUtils {
  /// Check if user is a Super Admin
  static bool isSuperAdmin(Map<String, dynamic>? user) {
    if (user == null) return false;
    final roleStr = (user['role'] ?? '').toString().toLowerCase().trim();
    return roleStr == 'super admin' || roleStr == 'superadmin' || roleStr == 'super_admin';
  }

  /// Check if user is an Agent
 static bool isAgent(Map<String, dynamic>? user) {
  if (user == null) return false;
  
  // Direct check first
  final directRole = (user['role'] ?? '').toString().toLowerCase().trim();
  if (directRole == 'agent') return true;
  
  // Fallback to getUserRole()
  final roleStr = getUserRole(user).toLowerCase().trim();
  return roleStr == 'agent';
}

  /// Check if user is a Company Admin
  static bool isCompanyAdmin(Map<String, dynamic>? user) {
    if (user == null) return false;
    final roleStr = getUserRole(user).toLowerCase().trim();
    return roleStr == 'company admin' || 
         roleStr == 'companyadmin' || 
         roleStr == 'company_admin';
           }

  /// Check if user is a regular User
  static bool isUser(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = (user['role'] ?? '').toString().toLowerCase();
    return role == 'user';
  }

  // Cache to prevent infinite loop
  static final Map<String, String> _roleCache = {};
  
  /// Get user role as string
 /// Get user role as string - FIXED VERSION
static String getUserRole(Map<String, dynamic>? user) {
  if (user == null) return '';
  
  final userId = user['id']?.toString() ?? user['email']?.toString() ?? '';
  
  // ✅ PRIORITY 1: Direct role field (always check fresh, don't trust cache first)
  final directRole = (user['role'] ?? '').toString().trim();
  if (directRole.isNotEmpty && directRole.toLowerCase() != 'null') {
    if (userId.isNotEmpty) _roleCache[userId] = directRole;
    return directRole;
  }
  
  // ✅ PRIORITY 2: Extract from permissions JSON (handle both string & map)
  final permissionsRaw = user['permissions'];
  if (permissionsRaw != null) {
    Map<String, dynamic>? permissions;
    
    if (permissionsRaw is String) {
      try {
        permissions = jsonDecode(permissionsRaw) as Map<String, dynamic>?;
      } catch (e) {
        debugPrint('RoleUtils: JSON decode failed: $e');
        return '';
      }
    } else if (permissionsRaw is Map<String, dynamic>) {
      permissions = permissionsRaw;
    }
    
    if (permissions != null) {
      // ✅ Handle nested structure: { permissions: { permissionsMap: { role: "..." } } }
      if (permissions.containsKey('permissionsMap') && permissions['permissionsMap'] is Map) {
        permissions = permissions['permissionsMap'] as Map<String, dynamic>;
      }
      
      final roleFromPerms = (permissions['role'] ?? '').toString().trim();
      if (roleFromPerms.isNotEmpty && roleFromPerms.toLowerCase() != 'null') {
        if (userId.isNotEmpty) _roleCache[userId] = roleFromPerms;
        return roleFromPerms;
      }
    }
  }
  
  // ✅ PRIORITY 3: Fallback to cache ONLY if no fresh data
  if (userId.isNotEmpty && _roleCache.containsKey(userId)) {
    final cached = _roleCache[userId]!;
    if (cached.isNotEmpty) return cached;
  }
  
  return ''; // Final fallback
}

  // Cache to prevent infinite loop
  static final Map<String, String?> _companyIdCache = {};
  
  /// Clear caches - useful for testing or user changes
  static void clearCaches() {
    _roleCache.clear();
    _companyIdCache.clear();
    debugPrint('RoleUtils: Caches cleared');
  }
  
  /// Get user's company ID
  static String? getUserCompanyId(Map<String, dynamic>? user) {
    if (user == null) return null;
    
    // Create cache key from user ID
    final userId = user['id']?.toString() ?? user['email']?.toString() ?? '';
    if (userId.isNotEmpty && _companyIdCache.containsKey(userId)) {
      return _companyIdCache[userId];
    }
    
    // First check direct company_id fields
    final directCompanyId = user['company_id']?.toString() ?? user['companyId']?.toString();
    if (directCompanyId != null && directCompanyId.isNotEmpty) {
      if (userId.isNotEmpty) _companyIdCache[userId] = directCompanyId;
      return directCompanyId;
    }
    
    // Check if permissions contain nested permissionsMap with company info
    final permissionsRaw = user['permissions'];
    if (permissionsRaw != null) {
      Map<String, dynamic>? permissions;
      
      if (permissionsRaw is String) {
        try {
          permissions = jsonDecode(permissionsRaw) as Map<String, dynamic>?;
        } catch (e) {
          debugPrint('RoleUtils.getUserCompanyId: Failed to decode permissions JSON: $e');
        }
      } else if (permissionsRaw is Map<String, dynamic>) {
        permissions = permissionsRaw;
      }
      
      if (permissions != null) {
        // Handle double-nested permissionsMap
        if (permissions.containsKey('permissionsMap') && permissions['permissionsMap'] is Map<String, dynamic>) {
          permissions = permissions['permissionsMap'] as Map<String, dynamic>;
        }
        
        final companyIdFromPermissions = permissions['company_id']?.toString() ?? permissions['companyId']?.toString();
        if (companyIdFromPermissions != null && companyIdFromPermissions.isNotEmpty) {
          if (userId.isNotEmpty) _companyIdCache[userId] = companyIdFromPermissions;
          return companyIdFromPermissions;
        }
      }
    }
    
    final nullCompanyId = null;
    if (userId.isNotEmpty) _companyIdCache[userId] = nullCompanyId;
    return nullCompanyId;
  }

  /// Check if user has specific permission
 static bool hasPermission(Map<String, dynamic>? user, String permission) {
  if (user == null) return false;
  
  // Super admins have all permissions
  if (isSuperAdmin(user)) return true;
  
  final permissionsRaw = user['permissions'];
  Map<String, dynamic>? permissions;
  
  // Handle JSON string permissions
  if (permissionsRaw is String) {
    try {
      permissions = jsonDecode(permissionsRaw) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('RoleUtils: Failed to decode permissions JSON: $e');
      permissions = null;
    }
  } else if (permissionsRaw is Map<String, dynamic>) {
    permissions = permissionsRaw;
  }
  
  if (permissions != null) {
    // Handle nested permissionsMap
    if (permissions.containsKey('permissionsMap') && permissions['permissionsMap'] is Map<String, dynamic>) {
      permissions = permissions['permissionsMap'] as Map<String, dynamic>;
      debugPrint('RoleUtils.hasPermission: Extracted nested permissionsMap');
    }
    
    // ✅ FIX: Check for string-based permission levels
    final permValue = permissions[permission]?.toString().toLowerCase().trim();
    
    if (permValue != null && permValue.isNotEmpty) {
      // Deny if explicitly no_access or false-like
      if (permValue == 'no_access' || permValue == 'false' || permValue == '0') {
        return false;
      }
      // Allow any other non-empty string value (view_only, view_add, full_access, etc.)
      return true;
    }
    
    // Fallback: check for boolean true (legacy support)
    if (permissions[permission] == true) return true;
  }
  
  // Fallback to role-based permissions (existing switch statement)
  final role = getUserRole(user).toLowerCase();
  switch (permission) {
    case 'view_users':
    case 'create_users':
    case 'edit_users':
    case 'delete_users':
      return isSuperAdmin(user) || isCompanyAdmin(user);
    // ... baqi cases ...
    default:
      return false;
  }
}

  /// Create permissions map for Super Admin
  static Map<String, bool> createSuperAdminPermissions() {
    return {
      'view_users': true,
      'create_users': true,
      'edit_users': true,
      'delete_users': true,
      'view_companies': true,
      'create_companies': true,
      'edit_companies': true,
      'delete_companies': true,
      'view_trading': true,
      'create_trading': true,
      'edit_trading': true,
      'delete_trading': true,
      'view_inventory': true,
      'create_inventory': true,
      'edit_inventory': true,
      'delete_inventory': true,
      'view_rentals': true,
      'create_rentals': true,
      'edit_rentals': true,
      'delete_rentals': true,
      'view_expenditure': true,
      'create_expenditure': true,
      'edit_expenditure': true,
      'delete_expenditure': true,
      'view_reports': true,
    };
  }

  /// Create permissions map for Company Admin
  static Map<String, bool> createCompanyAdminPermissions() {
    return {
      'view_users': true,
      'create_users': true,
      'edit_users': true,
      'delete_users': false, // Company admins can't delete users
      'view_companies': false, // Can't view other companies
      'create_companies': false,
      'edit_companies': false,
      'delete_companies': false,
      'view_trading': true,
      'create_trading': true,
      'edit_trading': true,
      'delete_trading': true,
      'view_inventory': true,
      'create_inventory': true,
      'edit_inventory': true,
      'delete_inventory': true,
      'view_rentals': true,
      'create_rentals': true,
      'edit_rentals': true,
      'delete_rentals': true,
      'view_expenditure': true,
      'create_expenditure': true,
      'edit_expenditure': true,
      'delete_expenditure': true,
      'view_reports': true,
    };
  }

  /// Create permissions map for Agent
  static Map<String, bool> createAgentPermissions() {
    return {
      'view_users': false,
      'create_users': false,
      'edit_users': false,
      'delete_users': false,
      'view_companies': false,
      'create_companies': false,
      'edit_companies': false,
      'delete_companies': false,
      'view_trading': true,
      'create_trading': true,
      'edit_trading': false, // Can only edit their own
      'delete_trading': false, // Can only delete their own
      'view_inventory': true,
      'create_inventory': true,
      'edit_inventory': false, // Can only edit their own
      'delete_inventory': false, // Can only delete their own
      'view_rentals': true,
      'create_rentals': true,
      'edit_rentals': false, // Can only edit their own
      'delete_rentals': false, // Can only delete their own
      'view_expenditure': true,
      'create_expenditure': true,
      'edit_expenditure': false, // Can only edit their own
      'delete_expenditure': false, // Can only delete their own
      'view_reports': true,
    };
  }

  /// Create permissions map for regular User
  static Map<String, bool> createUserPermissions() {
    return {
      'view_users': false,
      'create_users': false,
      'edit_users': false,
      'delete_users': false,
      'view_companies': false,
      'create_companies': false,
      'edit_companies': false,
      'delete_companies': false,
      'view_trading': false,
      'create_trading': false,
      'edit_trading': false,
      'delete_trading': false,
      'view_inventory': false,
      'create_inventory': false,
      'edit_inventory': false,
      'delete_inventory': false,
      'view_rentals': false,
      'create_rentals': false,
      'edit_rentals': false,
      'delete_rentals': false,
      'view_expenditure': false,
      'create_expenditure': false,
      'edit_expenditure': false,
      'delete_expenditure': false,
      'view_reports': false,
    };
  }
}
