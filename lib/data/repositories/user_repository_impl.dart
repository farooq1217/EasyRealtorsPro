import 'dart:async';
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import '../../domain/models/user_model.dart';
import '../../domain/repositories/user_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_database_helper.dart';
import '../../firestore_sync_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/permission_helper.dart';
import '../../core/app_utils.dart';
import 'package:shared/shared.dart';

class UserRepositoryImpl implements UserRepository {
  final AppDatabase db;
  final SyncDatabaseHelper _syncHelper = SyncDatabaseHelper();
  final FirestoreSyncService _firestoreSync = FirestoreSyncService();
  
  // SQLite-only flag - disables all Firestore operations
  static const bool _sqliteOnlyMode = true;

  UserRepositoryImpl(this.db);

  // Helper method to disable Firestore operations in SQLite-only mode
  bool _isFirestoreOperationAllowed() {
    return !_sqliteOnlyMode;
  }

  // Helper method to execute Firestore operations only if allowed
  Future<void> _executeFirestoreOperation(Future<void> Function() operation) async {
    if (_isFirestoreOperationAllowed()) {
      try {
        await operation();
      } catch (e) {
        debugPrint('Firestore operation failed (non-critical in SQLite-only mode): $e');
      }
    } else {
      debugPrint('Firestore operation skipped in SQLite-only mode');
    }
  }

  @override
  Future<List<UserModel>> getUsers(String? companyId) async {
    try {
      final isSuperAdmin = await _isSuperAdmin();
      final effectiveCompanyId = isSuperAdmin ? null : companyId;
      
      String query;
      List<d.Variable> variables = [];
      
      if (isSuperAdmin) {
        query = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE (is_active = 1 OR is_active IS NULL) 
          ORDER BY updated_at DESC
        ''';
      } else {
        query = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE company_id = ? AND (is_active = 1 OR is_active IS NULL) 
          ORDER BY updated_at DESC
        ''';
        variables = [d.Variable.withString(effectiveCompanyId ?? '')];
      }
      
      final result = await db.customSelect(query, variables: variables).get();
      return result.map((r) => UserModel.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    try {
      final result = await db.customSelect(
        '''
        SELECT id, username, user_id, name, email, contact_no, permissions, 
               company_id, status, is_active, is_synced, created_at, updated_at,
               password_hash, salt, iterations, is_first_login, profile_picture_path
        FROM users 
        WHERE id = ? AND (is_active = 1 OR is_active IS NULL)
        ''',
        variables: [d.Variable.withString(id)],
      ).get();
      
      if (result.isEmpty) return null;
      return UserModel.fromMap(result.first.data);
    } catch (e) {
      throw Exception('Failed to fetch user by ID: $e');
    }
  }

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final result = await db.customSelect(
        '''
        SELECT id, username, user_id, name, email, contact_no, permissions, 
               company_id, status, is_active, is_synced, created_at, updated_at,
               password_hash, salt, iterations, is_first_login, profile_picture_path
        FROM users 
        WHERE email = ? AND (is_active = 1 OR is_active IS NULL)
        ''',
        variables: [d.Variable.withString(email)],
      ).get();
      
      if (result.isEmpty) return null;
      return UserModel.fromMap(result.first.data);
    } catch (e) {
      throw Exception('Failed to fetch user by email: $e');
    }
  }

  @override
  Future<void> addUser(UserModel user) async {
    try {
      final now = DateTime.now().toIso8601String();
      final userWithTimestamp = user.copyWith(
        id: user.id.isEmpty ? const Uuid().v4() : user.id,
        createdAt: user.createdAt ?? now,
        updatedAt: now,
      );
      
      await db.customStatement(
        '''
        INSERT OR REPLACE INTO users (
          id, username, user_id, name, email, contact_no, permissions, 
          company_id, status, is_active, is_synced, created_at, updated_at,
          password_hash, salt, iterations, is_first_login, profile_picture_path
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          userWithTimestamp.id,
          userWithTimestamp.username,
          userWithTimestamp.userId,
          userWithTimestamp.name,
          userWithTimestamp.email,
          userWithTimestamp.contactNo,
          userWithTimestamp.permissions != null ? UserModel.encodePermissions(userWithTimestamp.permissions!) : null,
          userWithTimestamp.companyId,
          userWithTimestamp.status,
          userWithTimestamp.isActive ? 1 : 0,
          userWithTimestamp.isSynced ? 1 : 0,
          userWithTimestamp.createdAt,
          userWithTimestamp.updatedAt,
          userWithTimestamp.passwordHash,
          userWithTimestamp.salt,
          userWithTimestamp.iterations,
          userWithTimestamp.isFirstLogin == true ? 1 : 0,
          userWithTimestamp.profilePicturePath,
        ],
      );
      
      // Mark as unsynced for Firestore sync
      if (!_sqliteOnlyMode) {
        await markUserAsUnsynced(userWithTimestamp.id);
      }
    } catch (e) {
      throw Exception('Failed to add user: $e');
    }
  }

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      final now = DateTime.now().toIso8601String();
      final updatedUser = user.copyWith(updatedAt: now);
      
      await db.customStatement(
        '''
        UPDATE users SET 
          username = ?, user_id = ?, name = ?, email = ?, contact_no = ?, 
          permissions = ?, company_id = ?, status = ?, is_active = ?, 
          is_synced = ?, updated_at = ?, password_hash = ?, salt = ?, 
          iterations = ?, is_first_login = ?, profile_picture_path = ?
        WHERE id = ?
        ''',
        [
          updatedUser.username,
          updatedUser.userId,
          updatedUser.name,
          updatedUser.email,
          updatedUser.contactNo,
          updatedUser.permissions != null ? UserModel.encodePermissions(updatedUser.permissions!) : null,
          updatedUser.companyId,
          updatedUser.status,
          updatedUser.isActive ? 1 : 0,
          updatedUser.isSynced ? 1 : 0,
          updatedUser.updatedAt,
          updatedUser.passwordHash,
          updatedUser.salt,
          updatedUser.iterations,
          updatedUser.isFirstLogin == true ? 1 : 0,
          updatedUser.profilePicturePath,
          updatedUser.id,
        ],
      );
      
      // Mark as unsynced for Firestore sync
      if (!_sqliteOnlyMode) {
        await markUserAsUnsynced(updatedUser.id);
      }
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE users SET status = ?, is_active = 0, updated_at = ? WHERE id = ?',
        ['archived', now, id],
      );
      
      // Mark as unsynced for Firestore sync
      if (!_sqliteOnlyMode) {
        await markUserAsUnsynced(id);
      }
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  @override
  Stream<List<UserModel>> watchUsers(String? companyId) {
    // For now, return a one-time stream. In a full implementation, 
    // this would use Drift's watch() method for real-time updates
    return getUsers(companyId).asStream();
  }

  @override
  Stream<UserModel?> watchUserById(String id) {
    return getUserById(id).asStream();
  }

  @override
  Future<bool> validateUser(String email, String password) async {
    try {
      final user = await getUserByEmail(email);
      if (user == null) return false;
      
      // For simplicity, just check if user exists and is active
      // In a real implementation, you'd verify the password hash
      return user.isActive;
    } catch (e) {
      debugPrint('Error validating user: $e');
      return false;
    }
  }

  @override
  Future<void> updatePassword(String userId, String newPassword) async {
    try {
      // In a real implementation, you'd hash the password here
      // For now, just mark as updated
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE users SET updated_at = ? WHERE id = ?',
        [now, userId],
      );
      
      if (!_sqliteOnlyMode) {
        await markUserAsUnsynced(userId);
      }
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  @override
  Future<bool> isFirstLogin(String userId) async {
    try {
      final user = await getUserById(userId);
      return user?.isFirstLogin ?? true;
    } catch (e) {
      return true;
    }
  }

  @override
  Future<void> markFirstLoginComplete(String userId) async {
    try {
      await db.customStatement(
        'UPDATE users SET is_first_login = 0 WHERE id = ?',
        [userId],
      );
      
      if (!_sqliteOnlyMode) {
        await markUserAsUnsynced(userId);
      }
    } catch (e) {
      throw Exception('Failed to mark first login complete: $e');
    }
  }

  @override
  Future<String> generateUniqueUserId(String companyId) async {
    final year = DateTime.now().year;
    final prefix = 'USR${year}';
    
    // Get existing user IDs for this company
    final result = await db.customSelect(
      'SELECT user_id FROM users WHERE company_id = ? AND user_id IS NOT NULL',
      variables: [d.Variable.withString(companyId)],
    ).get();
    
    final existingIds = result.map((r) => r.data['user_id'].toString()).toList();
    final usedNumbers = <int>{};
    
    for (final id in existingIds) {
      final match = RegExp(r'USR\d{4}(\d+)').firstMatch(id);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '');
        if (number != null) {
          usedNumbers.add(number);
        }
      }
    }
    
    // Find the next available number
    int nextNumber = 1;
    while (usedNumbers.contains(nextNumber)) {
      nextNumber++;
    }
    
    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }

  @override
  Future<void> backfillUserIds(String companyId) async {
    final year = DateTime.now().year;
    
    // Get users without user_id
    final result = await db.customSelect(
      'SELECT id FROM users WHERE company_id = ? AND (user_id IS NULL OR user_id = "")',
      variables: [d.Variable.withString(companyId)],
    ).get();
    
    for (final row in result) {
      final userId = row.data['id'].toString();
      final newUserId = await generateUniqueUserId(companyId);
      final now = DateTime.now().toIso8601String();
      
      await db.customStatement(
        'UPDATE users SET user_id = ?, updated_at = ? WHERE id = ?',
        [newUserId, now, userId],
      );
    }
  }

  @override
  Future<bool> isUserIdUnique(String companyId, String userId, {String? excludeUserId}) async {
    String query = 'SELECT COUNT(*) as c FROM users WHERE company_id = ? AND user_id = ?';
    List<d.Variable> variables = [
      d.Variable.withString(companyId),
      d.Variable.withString(userId),
    ];
    
    if (excludeUserId != null) {
      query += ' AND id != ?';
      variables.add(d.Variable.withString(excludeUserId));
    }
    
    final result = await db.customSelect(query, variables: variables).get();
    final count = int.tryParse(result.first.data['c'].toString() ?? '0') ?? 0;
    return count == 0;
  }

  @override
  Future<List<UserModel>> getUsersByCompany(String companyId) async {
    return getUsers(companyId);
  }

  @override
  Future<int> getActiveUserCount(String companyId) async {
    try {
      final result = await db.customSelect(
        "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL) AND (is_active = 1 OR is_active IS NULL)",
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      return int.tryParse(result.first.data['cnt'].toString() ?? '0') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<bool> canAddMoreUsers(String companyId) async {
    try {
      // Get company's user limit
      final limitResult = await db.customSelect(
        'SELECT max_user_limit, subscription_tier FROM companies WHERE id = ? LIMIT 1',
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      if (limitResult.isEmpty) return false;
      
      final limitRaw = limitResult.first.data['max_user_limit'];
      final tier = limitResult.first.data['subscription_tier']?.toString();
      
      int? limit = limitRaw is int ? limitRaw : int.tryParse(limitRaw?.toString() ?? '');
      limit ??= _getUserLimitForTier(tier);
      
      // Get current user count
      final countResult = await db.customSelect(
        "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL) AND (is_active = 1 OR is_active IS NULL)",
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      final count = int.tryParse(countResult.first.data['cnt'].toString() ?? '0') ?? 0;
      
      return count < limit;
    } catch (e) {
      return false;
    }
  }

  int _getUserLimitForTier(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'starter':
        return 5;
      case 'professional':
        return 20;
      case 'enterprise':
        return 100;
      default:
        return 5;
    }
  }

  @override
  Future<void> updateProfilePicture(String userId, String imagePath) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE users SET profile_picture_path = ?, updated_at = ? WHERE id = ?',
        [imagePath, now, userId],
      );
      
      if (!_sqliteOnlyMode) {
        await markUserAsUnsynced(userId);
      }
    } catch (e) {
      throw Exception('Failed to update profile picture: $e');
    }
  }

  @override
  Future<void> updatePermissions(String userId, Map<String, dynamic> permissions) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE users SET permissions = ?, updated_at = ? WHERE id = ?',
        [UserModel.encodePermissions(permissions), now, userId],
      );
      
      if (!_sqliteOnlyMode) {
        await markUserAsUnsynced(userId);
      }
    } catch (e) {
      throw Exception('Failed to update permissions: $e');
    }
  }

  @override
  Future<List<UserModel>> searchUsers(String? companyId, String query) async {
    try {
      final isSuperAdmin = await _isSuperAdmin();
      final effectiveCompanyId = isSuperAdmin ? null : companyId;
      
      String sqlQuery;
      List<d.Variable> variables = [];
      
      if (isSuperAdmin) {
        sqlQuery = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE (is_active = 1 OR is_active IS NULL) 
          AND (LOWER(name) LIKE LOWER(?) OR LOWER(email) LIKE LOWER(?) OR LOWER(username) LIKE LOWER(?))
          ORDER BY updated_at DESC
        ''';
        variables = [
          d.Variable.withString('%$query%'),
          d.Variable.withString('%$query%'),
          d.Variable.withString('%$query%'),
        ];
      } else {
        sqlQuery = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE company_id = ? AND (is_active = 1 OR is_active IS NULL) 
          AND (LOWER(name) LIKE LOWER(?) OR LOWER(email) LIKE LOWER(?) OR LOWER(username) LIKE LOWER(?))
          ORDER BY updated_at DESC
        ''';
        variables = [
          d.Variable.withString(effectiveCompanyId ?? ''),
          d.Variable.withString('%$query%'),
          d.Variable.withString('%$query%'),
          d.Variable.withString('%$query%'),
        ];
      }
      
      final result = await db.customSelect(sqlQuery, variables: variables).get();
      return result.map((r) => UserModel.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  @override
  Stream<List<UserModel>> watchSearchUsers(String? companyId, String query) {
    return searchUsers(companyId, query).asStream();
  }

  @override
  Future<void> ensureUserTableColumns() async {
    try {
      // Ensure all required columns exist
      final columns = [
        'ALTER TABLE users ADD COLUMN is_active INTEGER DEFAULT 1',
        'ALTER TABLE users ADD COLUMN is_synced INTEGER DEFAULT 1',
        'ALTER TABLE users ADD COLUMN profile_picture_path TEXT',
        'ALTER TABLE users ADD COLUMN is_first_login INTEGER DEFAULT 1',
      ];
      
      for (final column in columns) {
        try {
          await db.customStatement(column);
        } catch (e) {
          // Column might already exist, ignore error
        }
      }
      
      // Update null values
      await db.customStatement('UPDATE users SET is_active = 1 WHERE is_active IS NULL');
      await db.customStatement('UPDATE users SET is_synced = 1 WHERE is_synced IS NULL');
      await db.customStatement('UPDATE users SET is_first_login = 1 WHERE is_first_login IS NULL');
    } catch (e) {
      throw Exception('Failed to ensure user table columns: $e');
    }
  }

  @override
  Future<void> syncUsersFromFirestore() async {
    if (!_isFirestoreOperationAllowed()) return;
    
    await _executeFirestoreOperation(() async {
      // Implementation for syncing from Firestore would go here
      // For now, this is a no-op in SQLite-only mode
      debugPrint('Firestore sync skipped in SQLite-only mode');
    });
  }

  @override
  Future<void> markUserAsUnsynced(String userId) async {
    await _syncHelper.markAsUnsynced('users', userId);
  }

  @override
  Future<void> markUserAsSynced(String userId) async {
    await _syncHelper.markAsSynced('users', userId);
  }

  @override
  Future<Map<String, dynamic>> getUserStatistics(String? companyId) async {
    try {
      final isSuperAdmin = await _isSuperAdmin();
      final effectiveCompanyId = isSuperAdmin ? null : companyId;
      
      String query;
      List<d.Variable> variables = [];
      
      if (isSuperAdmin) {
        query = '''
          SELECT 
            COUNT(*) as total_users,
            COUNT(CASE WHEN status = 'active' OR status IS NULL THEN 1 END) as active_users,
            COUNT(CASE WHEN status = 'inactive' THEN 1 END) as inactive_users,
            COUNT(CASE WHEN status = 'archived' THEN 1 END) as archived_users
          FROM users 
          WHERE (is_active = 1 OR is_active IS NULL)
        ''';
      } else {
        query = '''
          SELECT 
            COUNT(*) as total_users,
            COUNT(CASE WHEN status = 'active' OR status IS NULL THEN 1 END) as active_users,
            COUNT(CASE WHEN status = 'inactive' THEN 1 END) as inactive_users,
            COUNT(CASE WHEN status = 'archived' THEN 1 END) as archived_users
          FROM users 
          WHERE company_id = ? AND (is_active = 1 OR is_active IS NULL)
        ''';
        variables = [d.Variable.withString(effectiveCompanyId ?? '')];
      }
      
      final result = await db.customSelect(query, variables: variables).get();
      final data = result.first.data;
      
      return {
        'total_users': int.tryParse(data['total_users'].toString() ?? '0') ?? 0,
        'active_users': int.tryParse(data['active_users'].toString() ?? '0') ?? 0,
        'inactive_users': int.tryParse(data['inactive_users'].toString() ?? '0') ?? 0,
        'archived_users': int.tryParse(data['archived_users'].toString() ?? '0') ?? 0,
      };
    } catch (e) {
      return {
        'total_users': 0,
        'active_users': 0,
        'inactive_users': 0,
        'archived_users': 0,
      };
    }
  }

  // Helper methods
  Future<bool> _isSuperAdmin() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        final authService = AuthService();
        final user = await authService.getCurrentUser(authToken);
        return RoleUtils.isSuperAdmin(user);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final users = await getUsers(null);
      return users.firstWhere(
        (user) => user.username.toLowerCase() == username.toLowerCase(),
        orElse: () => UserModel.empty(),
      );
    } catch (e) {
      debugPrint('Error getting user by username: $e');
      return null;
    }
  }
}
