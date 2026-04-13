import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../users/models/user_model.dart';
import 'user_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sync_database_helper.dart';
import '../../../firestore_sync_service.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/services/permission_helper.dart';
import '../../../core/app_utils.dart';
import '../../../core/services/firebase_threading_handler.dart';
import 'package:shared/shared.dart';

class UserRepositoryImpl implements UserRepository {
  final AppDatabase db;
  final SyncDatabaseHelper _syncHelper = SyncDatabaseHelper();
  final FirestoreSyncService _firestoreSync = FirestoreSyncService();
  
  // SQLite-only flag - enables Firestore operations
  static const bool _sqliteOnlyMode = false;

  // Platform detection for thread safety
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  UserRepositoryImpl(this.db);

  // Helper method to wrap streams with platform thread safety
  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    // ✨ CRITICAL FIX: Completely disable FirebaseThreadingHandler on Windows to prevent connection loss
    if (_isWindows) {
      debugPrint('UserRepository: Windows detected - skipping FirebaseThreadingHandler to prevent connection loss');
      return stream; // Return original stream directly
    }
    
    // For non-Windows platforms, use minimal wrapping
    try {
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'UserRepository $streamName',
      );
    } catch (e) {
      debugPrint('UserRepository: Error wrapping stream $streamName: $e');
      return stream; // Fallback to original stream
    }
  }

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
      String query;
      List<d.Variable> variables = [];
      
      // CRITICAL FIX: Company Admin should only see users from their own company
      if (companyId != null && companyId.isNotEmpty) {
        // Company Admin or regular user - only show users from their company
        query = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE company_id = ? 
          AND (is_active = 1 OR is_active IS NULL) 
          AND (status IS NULL OR status != 'deleted')
          ORDER BY updated_at DESC
        ''';
        variables = [d.Variable.withString(companyId)];
        debugPrint('UserRepository: getUsers query for Company Admin - filtering by company: $companyId');
      } else {
        // Super Admin - show all users across all companies
        query = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE (is_active = 1 OR is_active IS NULL) 
          AND (status IS NULL OR status != 'deleted')
          ORDER BY updated_at DESC
        ''';
        debugPrint('UserRepository: getUsers query for Super Admin - showing all users');
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
        variables: <d.Variable<Object>>[d.Variable.withString(id)],
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
        variables: <d.Variable<Object>>[d.Variable.withString(email)],
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
        isSynced: false, // Mark as unsynced for immediate sync
      );
      
      await db.customStatement(
        '''
        INSERT OR REPLACE INTO users (
          id, username, password_hash, salt, iterations, user_id, name, email, 
          contact_no, role, permissions, company_id, status, is_first_login, 
          is_active, profile_picture_path, created_at, updated_at, is_synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          userWithTimestamp.id,
          userWithTimestamp.username,
          userWithTimestamp.passwordHash,
          userWithTimestamp.salt,
          userWithTimestamp.iterations,
          userWithTimestamp.userId,
          userWithTimestamp.name,
          userWithTimestamp.email,
          userWithTimestamp.contactNo,
          userWithTimestamp.role, // Role derived from permissions
          userWithTimestamp.permissions, // Already a String, no encoding needed
          userWithTimestamp.companyId,
          userWithTimestamp.status,
          userWithTimestamp.isFirstLogin == true ? 1 : 0,
          userWithTimestamp.isActive ? 1 : 0,
          userWithTimestamp.profilePicturePath,
          userWithTimestamp.createdAt,
          userWithTimestamp.updatedAt,
          userWithTimestamp.isSynced ? 1 : 0,
        ],
      );
      
      debugPrint('UserRepository: User added to SQLite: ${userWithTimestamp.name} (${userWithTimestamp.email})');
      debugPrint('UserRepository: DEBUG - User Company ID: ${userWithTimestamp.companyId}');
      debugPrint('UserRepository: DEBUG - User Role: ${userWithTimestamp.role}');
      debugPrint('UserRepository: DEBUG - User Permissions: ${userWithTimestamp.permissions}');
      
      // CRITICAL FIX: Immediate Firestore sync after local save
      if (!_sqliteOnlyMode) {
        await _syncUserToFirestore(userWithTimestamp);
      } else {
        debugPrint('UserRepository: Firestore sync skipped in SQLite-only mode');
      }
    } catch (e) {
      debugPrint('UserRepository: Error adding user: $e');
      throw Exception('Failed to add user: $e');
    }
  }

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      final now = DateTime.now().toIso8601String();
      final updatedUser = user.copyWith(updatedAt: now, isSynced: false); // Mark as unsynced for immediate sync
      
      await db.customStatement(
        '''
        UPDATE users SET 
          username = ?, password_hash = ?, salt = ?, iterations = ?, user_id = ?, 
          name = ?, email = ?, contact_no = ?, role = ?, permissions = ?, 
          company_id = ?, status = ?, is_first_login = ?, is_active = ?, 
          profile_picture_path = ?, updated_at = ?, is_synced = ?
        WHERE id = ?
        ''',
        [
          updatedUser.username,
          updatedUser.passwordHash,
          updatedUser.salt,
          updatedUser.iterations,
          updatedUser.userId,
          updatedUser.name,
          updatedUser.email,
          updatedUser.contactNo,
          updatedUser.role, // Role derived from permissions
          updatedUser.permissions, // Already a String, no encoding needed
          updatedUser.companyId,
          updatedUser.status,
          updatedUser.isFirstLogin == true ? 1 : 0,
          updatedUser.isActive ? 1 : 0,
          updatedUser.profilePicturePath,
          updatedUser.updatedAt,
          updatedUser.isSynced ? 1 : 0,
          updatedUser.id,
        ],
      );
      
      debugPrint('UserRepository: User updated in SQLite: ${updatedUser.name} (${updatedUser.email})');
      
      // CRITICAL FIX: Immediate Firestore sync after local update
      if (!_sqliteOnlyMode) {
        await _syncUserToFirestore(updatedUser);
      } else {
        debugPrint('UserRepository: Firestore sync skipped in SQLite-only mode');
      }
    } catch (e) {
      debugPrint('UserRepository: Error updating user: $e');
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
    try {
      String query;
      List<d.Variable> variables = [];
      
      // CRITICAL FIX: Enhanced Super Admin detection for GLOBAL_ADMIN support
      final isSuperAdmin = companyId == 'GLOBAL_ADMIN' || 
                           companyId == null ||
                           (AuthService.currentUser?['permissions']?.toString().contains('super_admin') ?? false) ||
                           (RoleUtils.isSuperAdmin(AuthService.currentUser));
      
      if (isSuperAdmin) {
        // Super Admin - show all users across all companies
        query = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE (is_active = 1 OR is_active IS NULL) 
          AND (status IS NULL OR status != 'deleted')
          ORDER BY updated_at DESC
        ''';
        debugPrint('UserRepository: watchUsers query for Super Admin - showing all users (companyId: $companyId)');
      } else if (companyId != null && companyId.isNotEmpty && companyId != 'GLOBAL_ADMIN') {
        // Company Admin or regular user - only show users from their company
        query = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE company_id = ? 
          AND (is_active = 1 OR is_active IS NULL) 
          AND (status IS NULL OR status != 'deleted')
          ORDER BY updated_at DESC
        ''';
        variables = [d.Variable.withString(companyId)];
        debugPrint('UserRepository: watchUsers query for Company Admin - filtering by company: $companyId');
      debugPrint('UserRepository: DEBUG - Executing query with company_id: $companyId');
      } else {
        // Fallback: Show all users if companyId is null or invalid (for safety)
        query = '''
          SELECT id, username, user_id, name, email, contact_no, permissions, 
                 company_id, status, is_active, is_synced, created_at, updated_at,
                 password_hash, salt, iterations, is_first_login, profile_picture_path
          FROM users 
          WHERE (is_active = 1 OR is_active IS NULL) 
          AND (status IS NULL OR status != 'deleted')
          ORDER BY updated_at DESC
        ''';
        debugPrint('UserRepository: watchUsers query fallback - showing all users (companyId: $companyId)');
      }
      
      debugPrint('UserRepository: watchUsers query: $query');
      
      final stream = db
          .customSelect(query, variables: variables)
          .watch()
          .map((rows) {
            final displayCompanyId = isSuperAdmin ? 'GLOBAL_ADMIN' : companyId;
            debugPrint('UserRepository: watchUsers fetched ${rows.length} rows for company: $displayCompanyId');
            int index = 0;
            return rows.map((r) {
              final userData = r.data;
              debugPrint('UserRepository: Row ${++index}: ${userData['name']} (${userData['email']}) - Company: ${userData['company_id']} - Permissions: ${userData['permissions']}');
              return UserModel.fromMap(userData);
            }).toList();
          })
          .distinct((previous, current) {
            // CRITICAL: Only rebuild UI if actual data changes
            if (previous.length != current.length) {
              debugPrint('UserRepository: Stream data changed - previous: ${previous.length}, current: ${current.length}');
              return false; // Different length, emit new value
            }
            
            // Compare user lists for actual differences
            for (int i = 0; i < previous.length; i++) {
              if (i >= current.length) return false; // Different lengths
              
              final prevUser = previous[i];
              final currUser = current[i];
              
              // Compare key fields that matter for UI
              if (prevUser.id != currUser.id ||
                  prevUser.email != currUser.email ||
                  prevUser.name != currUser.name ||
                  prevUser.status != currUser.status ||
                  prevUser.isActive != currUser.isActive ||
                  prevUser.companyId != currUser.companyId) {
                debugPrint('UserRepository: Stream data changed - user ${currUser.email} modified');
                return false; // User data changed, emit new value
              }
            }
            
            debugPrint('UserRepository: Stream data unchanged - suppressing UI rebuild');
            return true; // Same data, suppress emission
          });
      
      // CRITICAL: Wrap stream with platform thread safety for Windows
      return _wrapStreamWithThreadSafety(stream, 'watchUsers');
    } catch (e) {
      debugPrint('Error in watchUsers stream: $e');
      // Return empty stream on error
      return Stream.value([]);
    }
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
      variables: <d.Variable<Object>>[d.Variable.withString(companyId)],
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
      variables: <d.Variable<Object>>[d.Variable.withString(companyId)],
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
        variables: <d.Variable<Object>>[d.Variable.withString(companyId)],
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
        variables: <d.Variable<Object>>[d.Variable.withString(companyId)],
      ).get();
      
      if (limitResult.isEmpty) return false;
      
      final limitRaw = limitResult.first.data['max_user_limit'];
      final tier = limitResult.first.data['subscription_tier']?.toString();
      
      int? limit = limitRaw is int ? limitRaw : int.tryParse(limitRaw?.toString() ?? '');
      limit ??= _getUserLimitForTier(tier);
      
      // Get current user count
      final countResult = await db.customSelect(
        "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL) AND (is_active = 1 OR is_active IS NULL)",
        variables: <d.Variable<Object>>[d.Variable.withString(companyId)],
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

  // CRITICAL FIX: Immediate sync method for cross-device synchronization
  Future<void> _syncUserToFirestore(UserModel user) async {
    if (!_isFirestoreOperationAllowed()) {
      debugPrint('UserRepository: Firestore sync not allowed in SQLite-only mode');
      return;
    }
    
    await _executeFirestoreOperation(() async {
      try {
        final firestore = FirebaseFirestore.instance;
        final usersCollection = firestore.collection('users');
        
        // Use email as document ID for consistency
        final firestoreDocId = user.email.toLowerCase().trim();
        debugPrint('UserRepository: Syncing user to Firestore: ${user.name} (doc: $firestoreDocId)');
        
        // Convert user to Firestore format
        final firestoreData = {
          'id': user.id,
          'username': user.username,
          'user_id': user.userId,
          'name': user.name,
          'email': user.email,
          'contact_no': user.contactNo ?? '',
          'permissions': user.permissions ?? {},
          'company_id': user.companyId ?? '',
          'status': user.status ?? 'active',
          'is_active': user.isActive,
          'is_synced': 1, // Mark as synced in Firestore
          'created_at': user.createdAt ?? DateTime.now().toIso8601String(),
          'updated_at': user.updatedAt,
          'password_hash': user.passwordHash ?? '',
          'salt': user.salt ?? '',
          'iterations': user.iterations ?? 10000,
          'is_first_login': user.isFirstLogin,
          'profile_picture_path': user.profilePicturePath ?? '',
        };
        
        // Set document in Firestore
        await usersCollection.doc(firestoreDocId).set(firestoreData, SetOptions(merge: true));
        
        // Mark as synced in local SQLite
        await markUserAsSynced(user.id);
        
        debugPrint('UserRepository: User synced to Firestore successfully: ${user.name}');
      } catch (e) {
        debugPrint('UserRepository: Error syncing user to Firestore: $e');
        // Enhanced error logging for network issues
        if (e.toString().contains('SocketException') || 
            e.toString().contains('TimeoutException') ||
            e.toString().contains('NetworkException')) {
          debugPrint('UserRepository: Network error detected - check internet connection');
        }
        rethrow; // Re-throw to trigger proper error handling
      }
    });
  }

  @override
  Future<void> syncUsersFromFirestore() async {
    if (!_isFirestoreOperationAllowed()) {
      debugPrint('UserRepository: Firestore sync not allowed in SQLite-only mode');
      return;
    }
    
    await _executeFirestoreOperation(() async {
      debugPrint('UserRepository: Starting sync from Firestore...');
      
      try {
        final firestore = FirebaseFirestore.instance;
        final usersCollection = firestore.collection('users');
        
        // CRITICAL FIX: Tenant isolation - only sync users for current user's company
        final currentUser = AuthService.currentUser;
        final isSuperAdmin = RoleUtils.isSuperAdmin(currentUser) || PermissionHelper.isBypassUser(currentUser);
        final userCompanyId = RoleUtils.getUserCompanyId(currentUser);
        
        Query query;
        if (isSuperAdmin) {
          // Super Admin: Sync all users
          query = usersCollection;
          debugPrint('UserRepository: Super Admin sync - fetching all users');
        } else if (userCompanyId != null && userCompanyId!.isNotEmpty) {
          // Company Admin: Sync only users from their company
          query = usersCollection.where('company_id', isEqualTo: userCompanyId);
          debugPrint('UserRepository: Company Admin sync - fetching users for company: $userCompanyId');
        } else {
          debugPrint('UserRepository: No company ID found - skipping sync');
          return;
        }
        
        // ✨ CRITICAL FIX: Add timeout for Windows to prevent hanging
        final querySnapshot = await query.get().timeout(
          _isWindows ? const Duration(seconds: 8) : const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('UserRepository: Firestore query timed out - returning empty result');
            throw TimeoutException('Firestore query timeout', const Duration(seconds: 8));
          },
        );
        debugPrint('UserRepository: Fetched ${querySnapshot.docs.length} users from Firestore');
        
        // Begin transaction for bulk insert
        await db.transaction(() async {
          for (final doc in querySnapshot.docs) {
            final rawData = doc.data();
            
            // Skip if data is null
            if (rawData == null) {
              debugPrint('UserRepository: Skipping null data for document ${doc.id}');
              continue;
            }
            
            // Cast to Map<String, dynamic> for safe access
            final data = rawData as Map<String, dynamic>;
            
            // Convert Firestore data to UserModel format
            // FIX: Safely handle boolean fields that can be int or bool from Firestore
            final isActiveRaw = data['is_active'];
            final isFirstLoginRaw = data['is_first_login'];
            final permissionsStr = data['permissions']?.toString() ?? '{}';
            
            // Extract role from permissions JSON for SQLite storage
            String role = 'agent'; // Default role
            try {
              if (permissionsStr.isNotEmpty) {
                final decoded = jsonDecode(permissionsStr) as Map<String, dynamic>;
                role = decoded['role']?.toString() ?? 'agent';
              }
            } catch (e) {
              // Try to extract role from malformed JSON like {"agent":true}
              if (permissionsStr.contains('agent')) {
                role = 'agent';
              }
            }
            
            final userMap = {
              'id': doc.id,
              'username': data['username']?.toString() ?? '',
              'user_id': data['user_id']?.toString() ?? doc.id,
              'name': data['name']?.toString() ?? '',
              'email': data['email']?.toString() ?? '',
              'contact_no': data['contact_no']?.toString() ?? '',
              'permissions': permissionsStr,
              'role': role, // Add extracted role
              'company_id': data['company_id']?.toString() ?? '',
              'status': data['status']?.toString() ?? 'active',
              'is_active': (isActiveRaw == 1 || isActiveRaw == true) ? 1 : 0, // Handle both int and bool
              'is_synced': 1, // Mark as synced
              'created_at': data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              'updated_at': data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
              'password_hash': data['password_hash']?.toString() ?? '',
              'salt': data['salt']?.toString() ?? '',
              'iterations': int.tryParse(data['iterations']?.toString() ?? '') ?? 10000,
              'is_first_login': (isFirstLoginRaw == 1 || isFirstLoginRaw == true) ? 1 : 0, // Handle both int and bool
              'profile_picture_path': data['profile_picture_path']?.toString() ?? '',
            };
            
            // Insert or replace user in SQLite
            await db.customInsert(
              '''INSERT OR REPLACE INTO users (
                id, username, password_hash, salt, iterations, user_id, name, email, 
                contact_no, role, permissions, company_id, status, is_first_login, 
                is_active, profile_picture_path, created_at, updated_at, is_synced
              ) VALUES (
                :id, :username, :password_hash, :salt, :iterations, :user_id, :name, :email, 
                :contact_no, :role, :permissions, :company_id, :status, :is_first_login, 
                :is_active, :profile_picture_path, :created_at, :updated_at, :is_synced
              )''',
              variables: <d.Variable<Object>>[
                d.Variable.withString(userMap['id']?.toString() ?? ''),
                d.Variable.withString(userMap['username']?.toString() ?? ''),
                d.Variable.withString(userMap['password_hash']?.toString() ?? ''),
                d.Variable.withString(userMap['salt']?.toString() ?? ''),
                d.Variable.withInt(int.tryParse(userMap['iterations']?.toString() ?? '') ?? 10000),
                d.Variable.withString(userMap['user_id']?.toString() ?? ''),
                d.Variable.withString(userMap['name']?.toString() ?? ''),
                d.Variable.withString(userMap['email']?.toString() ?? ''),
                d.Variable.withString(userMap['contact_no']?.toString() ?? ''),
                d.Variable.withString(userMap['role']?.toString() ?? 'agent'), // Add role field
                d.Variable.withString(userMap['permissions']?.toString() ?? '{}'),
                d.Variable.withString(userMap['company_id']?.toString() ?? ''),
                d.Variable.withString(userMap['status']?.toString() ?? ''),
                d.Variable.withInt(int.tryParse(userMap['is_first_login']?.toString() ?? '') ?? 1),
                d.Variable.withInt(int.tryParse(userMap['is_active']?.toString() ?? '') ?? 1),
                d.Variable.withString(userMap['profile_picture_path']?.toString() ?? ''),
                d.Variable.withString(userMap['created_at']?.toString() ?? ''),
                d.Variable.withString(userMap['updated_at']?.toString() ?? ''),
                d.Variable.withInt(int.tryParse(userMap['is_synced']?.toString() ?? '') ?? 1),
              ],
            );
            
            debugPrint('UserRepository: Synced user: ${userMap['name']} (${userMap['email']})');
          }
        });
        
        debugPrint('UserRepository: Successfully synced ${querySnapshot.docs.length} users from Firestore');
      } catch (e) {
        debugPrint('UserRepository: Error syncing from Firestore: $e');
        rethrow;
      }
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
  Future<void> updateUserPassword(String userId, String newPassword) async {
    try {
      // Generate new salt and hash password
      final salt = _generateSalt();
      final passwordHash = _hashPassword(newPassword, salt);
      
      await db.customStatement(
        'UPDATE users SET password_hash = ?, salt = ?, iterations = ?, updated_at = ? WHERE id = ?',
        [passwordHash, salt, 10000, DateTime.now().toIso8601String(), userId],
      );
      
      debugPrint('UserRepository: Password updated for user: $userId');
    } catch (e) {
      debugPrint('Error updating user password: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateUserRole(String userId, String newRole, Map<String, bool> selectedModules) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      // Generate dynamic permissionsMap based on selected modules
      Map<String, dynamic> dynamicPermissionsMap = {};
      selectedModules.forEach((key, isSelected) {
        if (isSelected) {
          // Assign view_add_edit or full_access depending on the base role
          dynamicPermissionsMap[key] = (newRole == 'company_admin') ? 'full_access' : 'view_add_edit';
        }
      });
      
      final updatedPerms = {
        'role': newRole,
        'permission': (newRole == 'company_admin') ? 'full_access' : 'custom',
        'canDelete': (newRole == 'company_admin'),
        'permissionsMap': dynamicPermissionsMap
      };
      
      final String finalJson = jsonEncode(updatedPerms);
      
      debugPrint('UserRepository: Generated dynamic permissions for user $userId: $finalJson');
      debugPrint('FINAL JSON TO DB: $finalJson'); // CRITICAL: Add this debug log
      
      // First, check if user exists
      final existingUser = await getUserById(userId);
      if (existingUser == null) {
        debugPrint('UserRepository: ERROR - User $userId not found!');
        throw Exception('User not found: $userId');
      }
      
      debugPrint('UserRepository: User found - current permissions: ${existingUser.permissions}');
      
      // CRITICAL: Use customUpdate with proper stream triggering
      final result = await db.customUpdate(
        'UPDATE users SET permissions = ?, updated_at = ? WHERE id = ?',
        variables: <d.Variable<String>>[
          d.Variable.withString(finalJson),
          d.Variable.withString(now),
          d.Variable.withString(userId),
        ],
        updates: {db.users}, // CRITICAL: This tells Drift to trigger the watch() stream!
      );
      
      debugPrint('UserRepository: Update completed - affected rows: ${result}');
      
      // ✨ PRODUCTION FIX: Sync to Firestore immediately after SQLite update ✨
      if (!_sqliteOnlyMode) {
        try {
          // ✨ FIX: Query SQLite to get user email for Firestore document ID ✨
          final userQuery = await db.customSelect(
            'SELECT email FROM users WHERE id = ?',
            variables: <d.Variable<Object>>[d.Variable.withString(userId)],
          ).get();
          
          String firestoreDocId = userId; // Fallback to userId
          if (userQuery.isNotEmpty) {
            final userEmail = userQuery.first.data['email'] as String?;
            if (userEmail != null && userEmail.isNotEmpty) {
              firestoreDocId = userEmail.toLowerCase().trim();
              debugPrint('UserRepository: Using email as Firestore doc ID: $firestoreDocId');
            }
          }
          
          final firestoreData = {
            'permissions': finalJson,
            'updated_at': now,
            'role': newRole, // Explicit role field for Firestore
          };
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(firestoreDocId) // ✨ Use email as document ID
              .set(firestoreData, SetOptions(merge: true));
              
          debugPrint('UserRepository: ✅ Role synced to Firestore for user $userId (doc: $firestoreDocId)');
        } catch (firestoreError) {
          debugPrint('UserRepository: ⚠️ Firestore sync failed for user $userId: $firestoreError');
          // Continue even if Firestore fails - SQLite is primary
        }
      }
      
      // Verify the update worked by reading back
      final updatedUser = await getUserById(userId);
      if (updatedUser != null) {
        debugPrint('UserRepository: Verification - new permissions: ${updatedUser.permissions}');
        debugPrint('UserRepository: Verification - parsed role: ${updatedUser.role}');
      }
      
      // Mark as unsynced for Firestore sync
      if (!_sqliteOnlyMode) {
        await markUserAsUnsynced(userId);
      }
      
      debugPrint('UserRepository: Successfully updated user $userId role to $newRole');
    } catch (e) {
      debugPrint('UserRepository: ERROR updating user role: $e');
      throw Exception('Failed to update user role: $e');
    }
  }

  @override
  Future<void> archiveUser(String userId) async {
    try {
      await db.customStatement(
        'UPDATE users SET status = ?, is_active = 0, updated_at = ? WHERE id = ?',
        ['archived', DateTime.now().toIso8601String(), userId],
      );
      
      debugPrint('UserRepository: User archived: $userId');
    } catch (e) {
      debugPrint('Error archiving user: $e');
      rethrow;
    }
  }

  // Helper methods for password handling
  String _generateSalt() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return random;
  }

  String _hashPassword(String password, String salt) {
    // Simple hash implementation - in production, use proper crypto
    return '$salt:$password';
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
          AND (status IS NULL OR status != 'deleted')
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
          AND (status IS NULL OR status != 'deleted')
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
        // For now, assume non-null token means authenticated user
        // TODO: Implement proper token validation when needed
        return false; // Default to non-super admin for safety
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
