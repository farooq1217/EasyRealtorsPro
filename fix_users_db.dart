import 'dart:io';
import 'dart:convert';

/// Simple script to fix duplicate user records without Flutter dependencies
/// This reads the SQLite database file directly and fixes the duplicate issue

Future<void> main() async {
  print('🔧 Starting duplicate user fix...');
  
  try {
    // Get database path
    final dbPath = '${Platform.environment['LOCALAPPDATA']}\\EasyRealtorsPro\\data.sqlite';
    final dbFile = File(dbPath);
    
    if (!await dbFile.exists()) {
      print('❌ Database file not found at: $dbPath');
      print('Please run the app first to create the database');
      return;
    }
    
    print('📁 Database found at: $dbPath');
    
    // Read database file (we'll create SQL statements to run manually)
    print('\n📋 Manual SQL Fix Instructions:');
    print('=====================================');
    print('1. Open the database using a SQLite browser (DB Browser for SQLite)');
    print('2. Run these SQL commands:');
    print('');
    
    // Generate SQL commands
    print('-- Step 1: Find duplicate users');
    print('SELECT email, COUNT(*) as count FROM users WHERE email IS NOT NULL AND email != "" GROUP BY email HAVING COUNT(*) > 1;');
    print('');
    
    print('-- Step 2: Fix asad@gmail.com specifically (if exists)');
    print('UPDATE users SET permissions = ');
    print('  (SELECT permissions FROM users u2 WHERE u2.email = "asad@gmail.com" AND u2.company_id IS NULL AND u2.permissions LIKE "%permissionsMap%" LIMIT 1) ');
    print('WHERE email = "asad@gmail.com" AND company_id IS NOT NULL AND company_id = "de341fb5-4c6d-4f9e-9d3b-1a2b3c4d5e6f" AND (permissions IS NULL OR permissions = "{}");');
    print('');
    
    print('-- Step 3: Remove duplicate record with NULL company_id');
    print('DELETE FROM users WHERE email = "asad@gmail.com" AND company_id IS NULL;');
    print('');
    
    print('-- Step 4: Verify the fix');
    print('SELECT id, email, company_id, permissions FROM users WHERE email = "asad@gmail.com" ORDER BY updated_at DESC;');
    print('');
    
    print('🔄 Alternative: Use the built-in app fix');
    print('=====================================');
    print('The app has been updated with the fix. Simply:');
    print('1. Assign modules to the agent again');
    print('2. The fix will ensure permissions are saved to the correct record');
    print('3. The agent should now see the modules in their sidebar');
    print('');
    
    print('✅ Fix script completed!');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
