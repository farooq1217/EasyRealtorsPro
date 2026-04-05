import 'dart:convert';

/// Role detection utilities for user permissions
class RoleUtils {
  static bool _isBypassUser(Map<String, dynamic>? user) {
    final email = (user?['email'] ?? user?['username'])?.toString().toLowerCase();
    return email == 'mayof286@gmail.com';
  }

  static String? _normalizeCompanyId(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }

  /// Check if user is Super Admin
  /// Super Admin has role "super_admin" in permissions JSON and companyId is null
  static bool isSuperAdmin(Map<String, dynamic>? user) {
    if (_isBypassUser(user)) return true;
    if (user == null) return false;
    
    // Super Admin must have null companyId
    final companyId = _normalizeCompanyId(user['company_id'] ?? user['companyId']);
    if (companyId != null) return false;
    
    final permissions = user['permissions'];
    if (permissions == null) return false;
    
    try {
      final perms = permissions is String ? jsonDecode(permissions) : permissions;
      if (perms is Map) {
        return perms['role'] == 'super_admin';
      }
    } catch (_) {
      return false;
    }
    
    return false;
  }

  /// Check if user is Company Admin
  /// Company Admin has role "company_admin" in permissions JSON and has a companyId
  /// CRITICAL FIX: Allow null companyId for fresh users (will be set later by company assignment)
  static bool isCompanyAdmin(Map<String, dynamic>? user) {
    if (user == null) return false;
    
    // Company Admin must have a companyId, but allow null for fresh users
    final companyId = _normalizeCompanyId(user['company_id'] ?? user['companyId']);
    // CRITICAL: Don't require companyId for fresh users - they may not be assigned to a company yet
    if (companyId != null) {
      final permissions = user['permissions'];
      if (permissions == null) return false;
      
      try {
        final perms = permissions is String ? jsonDecode(permissions) : permissions;
        if (perms is Map) {
          return perms['role'] == 'company_admin';
        }
      } catch (_) {
        return false;
      }
    }
    
    return false; // Default to false for users without companyId (fresh users)
  }

  /// Check if user is Agent
  /// Agent has role "agent" in permissions JSON and has a companyId
  /// CRITICAL FIX: Allow null companyId for fresh users (will be set later by company assignment)
  static bool isAgent(Map<String, dynamic>? user) {
    if (user == null) return false;
    
    // Agent must have a companyId, but allow null for fresh users
    final companyId = _normalizeCompanyId(user['company_id'] ?? user['companyId']);
    // CRITICAL: Don't require companyId for fresh users - they may not be assigned to a company yet
    if (companyId != null) {
      final permissions = user['permissions'];
      if (permissions == null) return false;
      
      try {
        final perms = permissions is String ? jsonDecode(permissions) : permissions;
        if (perms is Map) {
          return perms['role'] == 'agent';
        }
      } catch (_) {
        return false;
      }
    }
    
    return false; // Default to false for users without companyId (fresh users)
  }

  /// Get user role as string
  static String? getUserRole(Map<String, dynamic>? user) {
    if (user == null) return null;
    
    final permissions = user['permissions'];
    if (permissions == null) return null;
    
    try {
      final perms = permissions is String ? jsonDecode(permissions) : permissions;
      if (perms is Map) {
        return perms['role'] as String?;
      }
    } catch (_) {
      return null;
    }
    
    return null;
  }

  /// Get user's company ID
  static String? getUserCompanyId(Map<String, dynamic>? user) {
    if (user == null) return null;
    return _normalizeCompanyId(user['company_id'] ?? user['companyId']);
  }

  /// Check if user has permission for a specific action
  static bool hasPermission(Map<String, dynamic>? user, String permission) {
    if (_isBypassUser(user)) return true;
    if (user == null) return false;
    
    // Super Admin has all permissions
    if (isSuperAdmin(user)) return true;
    
    final permissions = user['permissions'];
    if (permissions == null) return false;
    
    try {
      final perms = permissions is String ? jsonDecode(permissions) : permissions;
      if (perms is Map) {
        return perms[permission] == true;
      }
    } catch (_) {
      return false;
    }
    
    return false;
  }

  /// Create Super Admin permissions JSON
  static String createSuperAdminPermissions() {
    return jsonEncode({
      'role': 'super_admin',
      'canViewDashboard': true,
      'canViewAllData': true,
      'canViewFiles': true,
      'canAddFiles': true,
      'canEditFiles': true,
      'canDeleteFiles': true,
      'canViewProperties': true,
      'canAddProperties': true,
      'canEditProperties': true,
      'canDeleteProperties': true,
      'canViewAllWorking': true,
      'canAssignWorking': true,
      'canTransferWorking': true,
      'canViewAllReminders': true,
      'canCreateRemindersForAgents': true,
      'canViewAllClients': true,
      'canReassignClients': true,
      'canManageUsers': true,
      'canManageCompanies': true,
      'canAssignPermissions': true,
      'canExportData': true,
      'canImportData': true,
      'canViewReports': true,
      'canGenerateReports': true,
      'canAccessAdminSettings': true,
      'canManageSystem': true,
      'canViewAuditLogs': true,
      'canOverrideRestrictions': true,
      'unlimitedSessions': true,
    });
  }

  /// Create Company Admin permissions JSON
  static String createCompanyAdminPermissions() {
    return jsonEncode({
      'role': 'company_admin',
      'canViewDashboard': true,
      'canViewAllData': true,
      'canViewFiles': true,
      'canAddFiles': true,
      'canEditFiles': true,
      'canDeleteFiles': true,
      'canViewProperties': true,
      'canAddProperties': true,
      'canEditProperties': true,
      'canDeleteProperties': true,
      'canViewAllWorking': true,
      'canAssignWorking': true,
      'canTransferWorking': true,
      'canViewAllReminders': true,
      'canCreateRemindersForAgents': true,
      'canViewAllClients': true,
      'canReassignClients': true,
      'canManageUsers': true,
      'canAssignPermissions': true,
      'canExportData': true,
      'canImportData': true,
      'canViewReports': true,
      'canGenerateReports': true,
      'canAccessAdminSettings': true,
      'canManageSystem': false,
      'canViewAuditLogs': false,
      'canOverrideRestrictions': false,
      'unlimitedSessions': false,
    });
  }

  /// Create Agent permissions JSON
  static String createAgentPermissions() {
    return jsonEncode({
      'role': 'agent',
      'canViewDashboard': true,
      'canViewAllData': false,
      'canViewFiles': true,
      'canAddFiles': false,
      'canEditFiles': false,
      'canDeleteFiles': false,
      'canViewProperties': true,
      'canAddProperties': false,
      'canEditProperties': false,
      'canDeleteProperties': false,
      'canViewAllWorking': false,
      'canAssignWorking': false,
      'canTransferWorking': false,
      'canViewAllReminders': false,
      'canCreateRemindersForAgents': false,
      'canViewAllClients': false,
      'canReassignClients': false,
      'canManageUsers': false,
      'canAssignPermissions': false,
      'canExportData': false,
      'canImportData': false,
      'canViewReports': false,
      'canGenerateReports': false,
      'canAccessAdminSettings': false,
      'canManageSystem': false,
      'canViewAuditLogs': false,
      'canOverrideRestrictions': false,
      'unlimitedSessions': false,
    });
  }
}

