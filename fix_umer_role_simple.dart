import 'dart:io';
import 'dart:convert';

void main() async {
  print('Fixing Umer Shahzad role from agent to company_admin...');
  
  // Create company admin permissions JSON
  final companyAdminPermissions = {
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
  };
  
  final permissionsJson = jsonEncode(companyAdminPermissions);
  print('Company Admin permissions JSON created: ${permissionsJson.substring(0, 100)}...');
  
  print('✅ Role fix script completed. Please run the SQL command manually:');
  print('');
  print('SQL Command:');
  print("UPDATE users SET permissions = '${permissionsJson.replaceAll("'", "''")}', updated_at = '${DateTime.now().toUtc().toIso8601String()}' WHERE email = 'umershahzad596@gmail.com';");
  print('');
  print('Or use the flutter app with the debug logging to verify the role change.');
}
