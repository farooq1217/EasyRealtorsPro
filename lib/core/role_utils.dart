import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/services/auth_service.dart';

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
  static String getUserRole(Map<String, dynamic>? user) {
    if (user == null) return '';
    
    // Create cache key from user ID
    final userId = user['id']?.toString() ?? user['email']?.toString() ?? '';
    
    // First check direct role field (before cache to prevent cache corruption)
    final directRole = (user['role'] ?? '').toString().trim();
    
    // If we have a direct role, use it and update cache
    if (directRole.isNotEmpty) {
      // Check if cached value differs from current role
      if (userId.isNotEmpty && _roleCache.containsKey(userId)) {
        final cachedRole = _roleCache[userId]!;
        if (cachedRole != directRole) {
          debugPrint('RoleUtils.getUserRole: Role changed from "$cachedRole" to "$directRole", updating cache');
        }
      }
      if (userId.isNotEmpty) _roleCache[userId] = directRole;
      return directRole;
    }
    
    // Only use cache if no direct role available
    if (userId.isNotEmpty && _roleCache.containsKey(userId)) {
      return _roleCache[userId]!;
    }
    
    // If no direct role, check permissions JSON for role
    final permissionsRaw = user['permissions'];
    if (permissionsRaw != null) {
      Map<String, dynamic>? permissions;
      
      // Handle JSON string permissions from database
      if (permissionsRaw is String) {
        try {
          permissions = jsonDecode(permissionsRaw) as Map<String, dynamic>?;
        } catch (e) {
          debugPrint('RoleUtils.getUserRole: Failed to decode permissions JSON: $e');
          return '';
        }
      } else if (permissionsRaw is Map<String, dynamic>) {
        permissions = permissionsRaw;
      }
      
      if (permissions != null) {
        // CRITICAL FIX: Handle double-nested permissionsMap
        // If permissions contains a nested permissionsMap, extract it
        if (permissions.containsKey('permissionsMap') && permissions['permissionsMap'] is Map<String, dynamic>) {
          permissions = permissions['permissionsMap'] as Map<String, dynamic>;
          debugPrint('RoleUtils.getUserRole: Extracted nested permissionsMap');
        }
        
        // Check for role in the (possibly extracted) permissions map
        final roleFromPermissions = (permissions['role'] ?? '').toString().trim();
        if (roleFromPermissions.isNotEmpty) {
          if (userId.isNotEmpty) _roleCache[userId] = roleFromPermissions;
          return roleFromPermissions;
        }
      }
    }
    
    final emptyRole = '';
    if (userId.isNotEmpty) _roleCache[userId] = emptyRole;
    return emptyRole;
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
    
    // Check permissions map if it exists
    final permissionsRaw = user['permissions'];
    Map<String, dynamic>? permissions;
    
    // CRITICAL FIX: Handle JSON string permissions from database
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
      // CRITICAL FIX: Handle double-nested permissionsMap
      // If permissions contains a nested permissionsMap, extract it
      if (permissions.containsKey('permissionsMap') && permissions['permissionsMap'] is Map<String, dynamic>) {
        permissions = permissions['permissionsMap'] as Map<String, dynamic>;
        debugPrint('RoleUtils.hasPermission: Extracted nested permissionsMap for permission check');
      }
      
      return permissions[permission] == true;
    }
    
    // Fallback to role-based permissions
    final role = getUserRole(user).toLowerCase();
    switch (permission) {
      case 'view_users':
      case 'create_users':
      case 'edit_users':
      case 'delete_users':
        return isSuperAdmin(user) || isCompanyAdmin(user);
      case 'view_companies':
      case 'create_companies':
      case 'edit_companies':
      case 'delete_companies':
        return isSuperAdmin(user);
      case 'view_trading':
      case 'create_trading':
      case 'edit_trading':
      case 'delete_trading':
        return isSuperAdmin(user) || isCompanyAdmin(user) || isAgent(user);
      case 'view_inventory':
      case 'create_inventory':
      case 'edit_inventory':
      case 'delete_inventory':
        return isSuperAdmin(user) || isCompanyAdmin(user) || isAgent(user);
      case 'view_rentals':
      case 'create_rentals':
      case 'edit_rentals':
      case 'delete_rentals':
        return isSuperAdmin(user) || isCompanyAdmin(user) || isAgent(user);
      case 'view_expenditure':
      case 'create_expenditure':
      case 'edit_expenditure':
      case 'delete_expenditure':
        return isSuperAdmin(user) || isCompanyAdmin(user) || isAgent(user);
      case 'view_reports':
        return isSuperAdmin(user) || isCompanyAdmin(user) || isAgent(user);
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
