import 'dart:io';
import 'package:drift/drift.dart';
import 'package:shared/shared.dart';
import 'package:easyrealtorspro/core/database/db_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Query SQLite Users Table', () async {
    print('=== QUERYING SQLite USERS TABLE ===');
    
    final dbPath = 'C:\\Users\\mfaro\\AppData\\Roaming\\com.example\\desktop_admin\\data.sqlite';
    if (!await File(dbPath).exists()) {
      print('Error: Database file does not exist at $dbPath');
      return;
    }
    
    AppDatabase.configureOpener(() async {
      return openAppExecutor(dbPath);
    });
    
    final db = await AppDatabase.instance();
    try {
      final rows = await db.customSelect('SELECT id, email, username, role, permissions, company_id, status, is_active FROM users').get();
      print('Total users found: ${rows.length}');
      for (final row in rows) {
        print('User:');
        print('  id: ${row.data['id']}');
        print('  email: ${row.data['email']}');
        print('  username: ${row.data['username']}');
        print('  role: ${row.data['role']}');
        print('  permissions: ${row.data['permissions']}');
        print('  company_id: ${row.data['company_id']}');
        print('  status: ${row.data['status']}');
        print('  is_active: ${row.data['is_active']}');
        print('-------------------------------------------');
      }
    } catch (e) {
      print('Error querying users: $e');
    } finally {
      await AppDatabase.closeInstance();
    }
  });
}
