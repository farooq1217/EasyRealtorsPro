import 'dart:convert';
import 'package:shared/shared.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Utility to create Super Admin account
/// This should be run manually by the developer/system administrator
/// Super Admin accounts cannot be created through the UI by Company Admins
/// 
/// Usage:
/// ```dart
/// final result = await SuperAdminCreator.createSuperAdmin(
///   email: 'admin@example.com',
///   password: 'SecurePassword123!',
///   name: 'Super Admin',
/// );
/// print(result['message']);
/// ```
class SuperAdminCreator {
  static const String _usersFile = 'users.json';

  static Future<io.Directory> _getAppDir() async {
    if (kIsWeb) {
      throw UnsupportedError('SuperAdminCreator not supported on web');
    }
    final dir = await getApplicationSupportDirectory();
    final app = io.Directory('${dir.path}${io.Platform.pathSeparator}desktop_admin');
    if (!await app.exists()) await app.create(recursive: true);
    return app;
  }

  static Future<Map<String, dynamic>> _readUsers() async {
    if (kIsWeb) return {};
    try {
      final file = io.File('${(await _getAppDir()).path}${io.Platform.pathSeparator}$_usersFile');
      if (!await file.exists()) return {};
      final text = await file.readAsString();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeUsers(Map<String, dynamic> users) async {
    if (kIsWeb) return;
    final file = io.File('${(await _getAppDir()).path}${io.Platform.pathSeparator}$_usersFile');
    await file.writeAsString(jsonEncode(users));
  }

  /// Create a Super Admin account
  /// 
  /// [email] - Email address for the Super Admin (must be unique)
  /// [password] - Password for the Super Admin
  /// [name] - Optional name for the Super Admin (defaults to 'Super Admin')
  /// [contactNo] - Optional contact number
  /// 
  /// Returns a map with 'success' (bool) and 'message' (String)
  static Future<Map<String, dynamic>> createSuperAdmin({
    required String email,
    required String password,
    String? name,
    String? contactNo,
  }) async {
    try {
      // Check if user already exists
      final users = await _readUsers();
      if (users.containsKey(email.toLowerCase())) {
        return {
          'success': false,
          'message': 'User with this email already exists',
        };
      }

      // Hash password
      final hashedPassword = PasswordHasher.hash(password);

      // Create Super Admin user
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final nowIso = DateTime.now().toIso8601String();
      final year = DateTime.now().year;
      final superAdminUser = {
        'id': userId,
        'email': email.toLowerCase(),
        'password': hashedPassword,
        'fullName': name ?? 'Super Admin',
        'name': name ?? 'Super Admin',
        'contactNo': contactNo,
        'permissions': RoleUtils.createSuperAdminPermissions(),
        'companyId': null, // Super Admin has no company
        'status': 'active',
        'twoFactorEnabled': false,
        'twoFactorSecret': null,
        'createdAt': nowIso,
        'created_at': nowIso,
        'userId': 'USR-$year-000',
        'user_id': 'USR-$year-000',
        'lastLogin': null,
      };

      users[email.toLowerCase()] = superAdminUser;
      await _writeUsers(users);

      return {
        'success': true,
        'message': 'Super Admin created successfully',
        'userId': userId,
        'email': email.toLowerCase(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating Super Admin: $e',
      };
    }
  }

  /// Verify if a user is Super Admin
  static Future<bool> verifySuperAdmin(String email) async {
    try {
      final users = await _readUsers();
      final user = users[email.toLowerCase()] as Map<String, dynamic>?;
      if (user == null) return false;
      
      return RoleUtils.isSuperAdmin(user);
    } catch (_) {
      return false;
    }
  }
}

