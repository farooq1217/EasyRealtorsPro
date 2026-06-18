import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:random_string/random_string.dart';
import 'package:shared/shared.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_threading_handler.dart';
import 'jwt_service.dart';
import 'local_auth_storage.dart';
import 'password_hashing_service.dart';
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import 'firestore_auth_sync.dart';
import 'drift_user_dao.dart';
import 'package:drift/drift.dart' as d;
import 'package:shared/shared.dart' show AppDatabase;

class AuthRepository extends ChangeNotifier {
  final JwtService jwt;
  final LocalAuthStorage localStore;
  final DriftUserDao driftDao; 
  final FirestoreAuthSync fsSync; 

  AuthRepository.fallback()
    : jwt = JwtService(),
      localStore = LocalAuthStorage(),
      driftDao = DriftUserDao(),
      fsSync = FirestoreAuthSync();

  AuthRepository({required this.jwt, required this.localStore, required this.driftDao, required this.fsSync});

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;
  set currentUser(Map<String, dynamic>? value) { _currentUser = value; notifyListeners(); }

  Future<Map<String, dynamic>> register({
    required String email, required String password, required String fullName, required String cnic,
  }) async {
    final users = await localStore.readUsers();
    if (users.containsKey(email.toLowerCase())) return {'success': false, 'message': 'User already exists'};
    users[email.toLowerCase()] = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), 'email': email.toLowerCase(),
      'password': PasswordHasher.hash(password), 'fullName': fullName, 'cnic': cnic,
      'twoFactorEnabled': false, 'createdAt': DateTime.now().toIso8601String(), 'lastLogin': null,
    };
    await localStore.writeUsers(users);
    return {'success': true, 'message': 'Registration successful'};
  }

  Future<void> _upgradeMissingHashes(Map<String, dynamic> users) async {
    bool mutated = false;
    for (final entry in users.entries.toList()) {
      final emailKey = entry.key;
      final u = entry.value as Map<String, dynamic>? ?? {};
      final status = (u['status'] ?? '').toString().toLowerCase();
      final isActive = u['is_active'] ?? u['isActive'];
      final activeFlag = (isActive is num ? isActive != 0 : (isActive is bool ? isActive : true));
      if (!activeFlag || status == 'archived') continue;
      final password = (u['password'] ?? '').toString().trim();
      final passwordHash = (u['passwordHash'] ?? '').toString().trim();
      if (password.isEmpty || passwordHash.isNotEmpty) continue;
      try {
        final newHash = PasswordHasher.hash(password);
        final parts = newHash.split(':');
        final iterations = int.tryParse(parts.first);
        final salt = parts.length > 1 ? parts[1] : null;
        u['password'] = newHash;
        u['passwordHash'] = newHash;
        users[emailKey] = u;
        mutated = true;
        try {
          await driftDao.updatePasswordHash(
            emailOrUsername: emailKey,
            passwordHash: newHash,
            salt: salt,
            iterations: iterations,
          );
        } catch (_) {}
      } catch (e) {
        debugPrint('Failed to upgrade password hash for $emailKey: $e');
      }
    }
    if (mutated) {
      await localStore.writeUsers(users);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
    String? twoFactorCode,
  }) async {
    // ✅ CRITICAL: Windows par Firebase Auth ko completely skip karein
    final isWindows = !kIsWeb && io.Platform.isWindows;
    
    if (isWindows) {
      debugPrint('🔐 Windows detected - using local authentication only (Firebase Auth skipped)');
      return await _localLoginOnly(email, password);
    }
    
    try {
      debugPrint('🔐 Firebase Auth login attempt for $email');
      
      final UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return {'success': false, 'message': 'Authentication failed'};
      }

      final emailKey = email.trim().toLowerCase();
      var userDoc = await fsSync.fetchFirestoreUserByEmail(emailKey);
      
      if (userDoc == null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
        if (doc.exists) {
          userDoc = doc.data();
          userDoc?['id'] = doc.id;
        }
      }

      if (userDoc == null) {
        return {'success': false, 'message': 'User profile not found in database'};
      }

      final is2FAEnabled = userDoc['twoFactorEnabled'] ?? false;
      if (is2FAEnabled) {
        if (twoFactorCode == null || twoFactorCode.isEmpty) {
          return {
            'success': false,
            'requires2FA': true,
            'message': 'Two-factor authentication code required',
          };
        }
        final secret = userDoc['twoFactorSecret'] as String?;
        if (!_verify2FA(twoFactorCode, secret)) {
          return {'success': false, 'message': 'Invalid two-factor code'};
        }
      }

      final user = {
        'id': userDoc['id'] ?? firebaseUser.uid,
        'email': userDoc['email'] ?? emailKey,
        'username': userDoc['username'] ?? userDoc['email'] ?? emailKey,
        'name': userDoc['name'] ?? userDoc['fullName'] ?? '',
        'role': userDoc['role'] ?? 'agent',
        'permissions': userDoc['permissions'] ?? '{}',
        'company_id': userDoc['company_id'] ?? userDoc['companyId'] ?? '',
        'status': userDoc['status'] ?? 'active',
        'is_active': userDoc['is_active'] ?? userDoc['isActive'] ?? 1,
        'is_first_login': userDoc['is_first_login'] ?? userDoc['isFirstLogin'] ?? 0,
      };

      final token = jwt.generateToken(
        user['id']?.toString() ?? '',
        user['email']?.toString() ?? '',
      );

      final users = await localStore.readUsers();
      users[emailKey] = user;
      await localStore.writeUsers(users);

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final sessions = await localStore.readSessions();
      sessions[sessionId] = {
        'userId': user['id'],
        'email': user['email'],
        'loginAt': DateTime.now().toIso8601String(),
      };
      await localStore.writeSessions(sessions);

      currentUser = user;
      triggerBackgroundSyncAfterLogin();

      return {
        'success': true,
        'user': user,
        'token': token,
        'sessionId': sessionId,
        'session_id': sessionId,
        'message': 'Login successful',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Login Exception: ${e.code} - ${e.message}');
      String msg = 'Authentication failed';
      if (e.code == 'user-not-found') {
        msg = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        msg = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        msg = 'Invalid email address';
      } else if (e.code == 'user-disabled') {
        msg = 'This user account has been disabled';
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      debugPrint('❌ Login Exception: $e');
      return {'success': false, 'message': 'Login failed: $e'};
    }
  }

  // ✅ NEW METHOD: Sirf local database se login karein
  // ✅ UPDATED METHOD: Local DB + Firestore fallback
// ✅ FINAL METHOD: Pure local authentication (no Firestore during login)
Future<Map<String, dynamic>> _localLoginOnly(String email, String password) async {
  try {
    debugPrint('🔐 _localLoginOnly: Starting local authentication for $email');
    
    final db = await AppDatabase.instance();
    final emailKey = email.trim().toLowerCase();
    
    // Step 1: Local DB mein user dhundhein
    final result = await db.customSelect(
      'SELECT * FROM users WHERE email = ? AND (is_active = 1 OR is_active IS NULL)',
      variables: [d.Variable.withString(emailKey)],
    ).get();
    
    if (result.isEmpty) {
      debugPrint('❌ _localLoginOnly: User not found in local DB');
      return {
        'success': false,
        'requiresSetup': true, // ✅ NEW FLAG: Setup mode trigger kare
        'message': 'No user found. Please create an admin account first.',
      };
    }
    
    final userData = result.first.data;
    final storedHash = userData['password_hash']?.toString() ?? '';
    final salt = userData['salt']?.toString() ?? '';
    final iterations = int.tryParse(userData['iterations']?.toString() ?? '') ?? 10000;
    
    final inputHash = _hashPassword(password, salt, iterations);
    
    if (storedHash.isEmpty || storedHash != inputHash) {
      debugPrint('❌ _localLoginOnly: Password mismatch');
      return {
        'success': false,
        'message': 'Invalid password',
      };
    }
    
    debugPrint('✅ _localLoginOnly: Password verified locally');
    
    // Parse permissions JSON
    Map<String, dynamic> parsedPerms = {};
    final rawPerms = userData['permissions']?.toString();
    if (rawPerms != null && rawPerms.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPerms);
        if (decoded is Map) {
          parsedPerms = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('_localLoginOnly: Failed to parse permissions JSON: $e');
      }
    }

    final hoistedRole = parsedPerms['role']?.toString() ?? userData['role']?.toString() ?? 'agent';
    final hoistedCompanyId = parsedPerms['companyId']?.toString() ??
        parsedPerms['company_id']?.toString() ??
        userData['company_id']?.toString();

    // Extract permissionsMap
    Map<String, dynamic>? hoistedPermissionsMap;
    final rawMap = parsedPerms['permissionsMap'];
    if (rawMap is Map && rawMap.isNotEmpty) {
      hoistedPermissionsMap = Map<String, dynamic>.from(rawMap);
    } else if (parsedPerms.isNotEmpty) {
      final hasModuleKeys = parsedPerms.keys.any((k) =>
        ['trading', 'inventory', 'rental', 'expenditure', 'agent_working',
         'reports', 'users', 'companies', 'dashboard', 'settings', 'todo',
         'rental_items'].contains(k));
      if (hasModuleKeys) {
        hoistedPermissionsMap = Map<String, dynamic>.from(parsedPerms)
          ..remove('role')
          ..remove('companyId')
          ..remove('company_id');
      }
    }

    // Synthesize permissionsMap for admin roles
    if ((hoistedPermissionsMap == null || hoistedPermissionsMap.isEmpty)) {
      final role = hoistedRole.toLowerCase();
      if (role == 'super_admin' || role == 'superadmin') {
        hoistedPermissionsMap = <String, dynamic>{
          'users': 'full_access', 'companies': 'full_access',
          'trading': 'full_access', 'inventory': 'full_access',
          'rental': 'full_access', 'rental_items': 'full_access',
          'expenditure': 'full_access', 'agent_working': 'full_access',
          'reports': 'full_access', 'dashboard': 'full_access',
          'settings': 'full_access', 'todo': 'full_access',
        };
      } else if (role == 'company_admin' || role == 'companyadmin') {
        hoistedPermissionsMap = <String, dynamic>{
          'users': 'full_access', 'trading': 'view_add_edit',
          'inventory': 'view_add_edit', 'rental': 'view_add_edit',
          'rental_items': 'view_add_edit', 'expenditure': 'view_add_edit',
          'agent_working': 'view_add_edit', 'reports': 'full_access',
          'dashboard': 'view_add_edit', 'settings': 'view_add_edit',
          'todo': 'view_add_edit',
        };
      }
    }

    // User object prepare karein
    final user = {
      'id': userData['id']?.toString() ?? '',
      'email': userData['email']?.toString() ?? emailKey,
      'username': userData['username']?.toString() ?? userData['email']?.toString() ?? emailKey,
      'name': userData['name']?.toString() ?? '',
      'role': hoistedRole,
      'permissions': userData['permissions']?.toString() ?? '{}',
      'company_id': hoistedCompanyId ?? '',
      'companyId': hoistedCompanyId ?? '',
      'status': userData['status']?.toString() ?? 'active',
      'is_active': userData['is_active'] ?? 1,
      'isActive': userData['is_active'] ?? 1,
      'is_first_login': userData['is_first_login'] ?? 0,
      'isFirstLogin': userData['is_first_login'] ?? 0,
      'createdAt': userData['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'created_at': userData['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      if (hoistedPermissionsMap != null && hoistedPermissionsMap.isNotEmpty)
        'permissionsMap': hoistedPermissionsMap,
    };
    
    final token = jwt.generateToken(
      user['id']?.toString() ?? '',
      user['email']?.toString() ?? '',
    );
    
    final users = await localStore.readUsers();
    users[emailKey] = user;
    await localStore.writeUsers(users);
    
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final sessions = await localStore.readSessions();
    sessions[sessionId] = {
      'userId': user['id'],
      'email': user['email'],
      'loginAt': DateTime.now().toIso8601String(),
    };
    await localStore.writeSessions(sessions);
    
    currentUser = user;

    debugPrint('✅ _localLoginOnly: Login successful for $email');
    
    return {
      'success': true,
      'user': user,
      'token': token,
      'sessionId': sessionId,
      'session_id': sessionId,
      'message': 'Login successful',
    };
  } catch (e) {
    debugPrint('❌ _localLoginOnly: Error: $e');
    return {
      'success': false,
      'message': 'Login failed: $e',
    };
  }
}

// ✅ NEW METHOD: Create first admin account locally
Future<Map<String, dynamic>> createLocalAdmin({
  required String email,
  required String password,
  required String name,
}) async {
  try {
    debugPrint('🔧 createLocalAdmin: Creating local admin for $email');
    
    final db = await AppDatabase.instance();
    final emailKey = email.trim().toLowerCase();
    final userId = 'admin_${DateTime.now().millisecondsSinceEpoch}';
    
    // Check if user already exists
    final existing = await db.customSelect(
      'SELECT id FROM users WHERE email = ?',
      variables: [d.Variable.withString(emailKey)],
    ).get();
    
    if (existing.isNotEmpty) {
      return {
        'success': false,
        'message': 'User with this email already exists',
      };
    }
    
    // Generate password hash
   final random = Random.secure();
final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
final salt = base64Url.encode(saltBytes);  // ✅ Valid base64 string
final iterations = 10000;
final passwordHash = _hashPassword(password, salt, iterations);
    
    if (passwordHash.isEmpty) {
      return {
        'success': false,
        'message': 'Failed to hash password',
      };
    }
    
    // Super admin permissions
    final permissions = jsonEncode({
      'role': 'super_admin',
      'permission': 'full_access',
      'canDelete': true,
      'permissionsMap': {
        'users': 'full_access', 'companies': 'full_access',
        'trading': 'full_access', 'inventory': 'full_access',
        'rental': 'full_access', 'rental_items': 'full_access',
        'expenditure': 'full_access', 'agent_working': 'full_access',
        'reports': 'full_access', 'dashboard': 'full_access',
        'settings': 'full_access', 'todo': 'full_access',
      },
    });
    
    final now = DateTime.now().toIso8601String();
    
    // Insert into database
    await db.customStatement(
      '''INSERT INTO users (
        id, username, password_hash, salt, iterations, user_id, name, email, 
        contact_no, role, permissions, company_id, status, is_first_login, 
        is_active, profile_picture_path, created_at, updated_at, is_synced
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        userId,
        emailKey,
        passwordHash,
        salt,
        iterations,
        userId,
        name,
        emailKey,
        '',
        'super_admin',
        permissions,
        'GLOBAL_ADMIN',
        'active',
        0,
        1,
        '',
        now,
        now,
        0, // Not synced yet
      ],
    );
    
    debugPrint('✅ createLocalAdmin: Admin created successfully');
    
    return {
      'success': true,
      'message': 'Admin account created successfully. Please login now.',
    };
  } catch (e) {
    debugPrint('❌ createLocalAdmin: Error: $e');
    return {
      'success': false,
      'message': 'Failed to create admin: $e',
    };
  }
}

// ✅ NEW METHOD: Firestore se single user fetch karein
Future<void> _fetchUserFromFirestore(String email) async {
  try {
    debugPrint('📥 _fetchUserFromFirestore: Fetching user $email from Firestore...');
    
    final firestore = FirebaseFirestore.instance;
    
    // Email se user dhundhein
    final snapshot = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 10));
    
    if (snapshot.docs.isEmpty) {
      debugPrint('❌ _fetchUserFromFirestore: User not found in Firestore');
      return;
    }
    
    final doc = snapshot.docs.first;
    final data = doc.data();
    
    debugPrint('✅ _fetchUserFromFirestore: Found user in Firestore, saving to local DB...');
    
    // Local DB mein save karein
    final db = await AppDatabase.instance();
    
    // Safe JSON conversion for permissions
    String permsStr = '{}';
    if (data['permissions'] is String) {
      permsStr = data['permissions'] as String;
    } else if (data['permissions'] is Map) {
      permsStr = jsonEncode(data['permissions']);
    }
    
    await db.customStatement(
      '''INSERT OR REPLACE INTO users (
        id, username, password_hash, salt, iterations, user_id, name, email, 
        contact_no, role, permissions, company_id, status, is_first_login, 
        is_active, profile_picture_path, created_at, updated_at, is_synced
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        doc.id,
        data['username']?.toString() ?? '',
        data['password_hash']?.toString() ?? '',
        data['salt']?.toString() ?? '',
        int.tryParse(data['iterations']?.toString() ?? '') ?? 10000,
        data['user_id']?.toString() ?? doc.id,
        data['name']?.toString() ?? '',
        data['email']?.toString() ?? email,
        data['contact_no']?.toString() ?? '',
        data['role']?.toString() ?? 'agent',
        permsStr,
        data['company_id']?.toString() ?? '',
        data['status']?.toString() ?? 'active',
        (data['is_first_login'] == true || data['is_first_login'] == 1) ? 1 : 0,
        (data['is_active'] == true || data['is_active'] == 1) ? 1 : 0,
        data['profile_picture_path']?.toString() ?? '',
        data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
        1,
      ],
    );
    
    debugPrint('✅ _fetchUserFromFirestore: User saved to local DB successfully');
  } catch (e) {
    debugPrint('❌ _fetchUserFromFirestore: Error: $e');
  }
}

  String _hashPassword(String password, String salt, int iterations) {
    try {
      final service = PasswordHashingService();
      return service.hashPassword(password, salt: salt, iterations: iterations);
    } catch (e) {
      debugPrint('⚠️ Password hashing error: $e');
      return '';
    }
  }

  Future<void> logout(String? sessionId) async {
    if (sessionId != null) {
      final sessions = await localStore.readSessions();
      sessions.remove(sessionId);
      await localStore.writeSessions(sessions);
    }
    currentUser = null;
  }

  bool _verify2FA(String code, String? secret) {
    if (secret == null) return false;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final counter = now ~/ 30;
      return code.length == 6;
    } catch (_) { return false; }
  }

  static const Duration _cacheTimeout = Duration(minutes: 5);
  Map<String, dynamic>? _cachedUser;
  String? _cachedToken;
  DateTime? _cacheTimestamp;

  void clearUserCache() {
    _cachedUser = null;
    _cachedToken = null;
    _cacheTimestamp = null;
    currentUser = null;
  }

  Future<Map<String, dynamic>?> getCurrentUser(String? token, {bool waitForFirestore = false}) async {
    if (token == null || token.isEmpty) return null;
    if (!await jwt.verifyToken(token)) return null;
    
    if (_cachedUser != null && _cachedToken == token && _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTimeout) {
      return _cachedUser;
    }
    
    final payload = jwt.decodeToken(token);
    if (payload == null) return null;
    final email = payload['email'] as String?;
    if (email == null) return null;
    
    final users = await localStore.readUsers();
    final emailKey = email.toLowerCase();
    var user = users[emailKey];
    
    try {
      final dbUser = await driftDao.getUserByEmailOrUsername(emailKey);
      if (dbUser != null) {
        Map<String, dynamic> parsedPerms = {};
        final rawPerms = dbUser.permissions;
        if (rawPerms != null && rawPerms.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawPerms);
            if (decoded is Map) {
              parsedPerms = Map<String, dynamic>.from(decoded);
            }
          } catch (e) {
            debugPrint('AuthRepository: Failed to parse permissions JSON: $e');
          }
        }

        final hoistedRole = parsedPerms['role']?.toString() ?? dbUser.role;
        final hoistedCompanyId = parsedPerms['companyId']?.toString() ??
            parsedPerms['company_id']?.toString() ??
            dbUser.companyId;

        Map<String, dynamic>? hoistedPermissionsMap;
        final rawMap = parsedPerms['permissionsMap'];
        if (rawMap is Map && rawMap.isNotEmpty) {
          hoistedPermissionsMap = Map<String, dynamic>.from(rawMap);
        } else if (parsedPerms.isNotEmpty) {
          final hasModuleKeys = parsedPerms.keys.any((k) =>
            ['trading', 'inventory', 'rental', 'expenditure', 'agent_working',
             'reports', 'users', 'companies', 'dashboard', 'settings', 'todo',
             'rental_items'].contains(k));
          if (hasModuleKeys) {
            hoistedPermissionsMap = Map<String, dynamic>.from(parsedPerms)
              ..remove('role')
              ..remove('companyId')
              ..remove('company_id');
          }
        }

        if ((hoistedPermissionsMap == null || hoistedPermissionsMap.isEmpty) &&
            hoistedRole != null) {
          final role = hoistedRole.toLowerCase();
          if (role == 'super_admin' || role == 'superadmin') {
            hoistedPermissionsMap = <String, dynamic>{
              'users': 'full_access', 'companies': 'full_access',
              'trading': 'full_access', 'inventory': 'full_access',
              'rental': 'full_access', 'rental_items': 'full_access',
              'expenditure': 'full_access', 'agent_working': 'full_access',
              'reports': 'full_access', 'dashboard': 'full_access',
              'settings': 'full_access', 'todo': 'full_access',
            };
          } else if (role == 'company_admin' || role == 'companyadmin') {
            hoistedPermissionsMap = <String, dynamic>{
              'users': 'full_access', 'trading': 'view_add_edit',
              'inventory': 'view_add_edit', 'rental': 'view_add_edit',
              'rental_items': 'view_add_edit', 'expenditure': 'view_add_edit',
              'agent_working': 'view_add_edit', 'reports': 'full_access',
              'dashboard': 'view_add_edit', 'settings': 'view_add_edit',
              'todo': 'view_add_edit',
            };
          }
        }

        final Map<String, dynamic> dbUserMap = {
          'id': dbUser.id,
          'email': dbUser.email ?? emailKey,
          'username': dbUser.username,
          'password': dbUser.passwordHash,
          'passwordHash': dbUser.passwordHash,
          'name': dbUser.name,
          'contactNo': dbUser.contactNo,
          'twoFactorEnabled': false,
          'twoFactorSecret': null,
          'createdAt': dbUser.createdAt ?? DateTime.now().toIso8601String(),
          'created_at': dbUser.createdAt ?? DateTime.now().toIso8601String(),
          'userId': dbUser.userId,
          'user_id': dbUser.userId,
          'lastLogin': null,
          'companyId': hoistedCompanyId ?? dbUser.companyId,
          'status': dbUser.status,
          'isActive': dbUser.isActive,
          'is_active': dbUser.isActive,
          'permissions': dbUser.permissions,
          'isFirstLogin': dbUser.isFirstLogin ? 1 : 0,
          if (hoistedRole != null) 'role': hoistedRole,
          if (hoistedPermissionsMap != null && hoistedPermissionsMap.isNotEmpty)
            'permissionsMap': hoistedPermissionsMap,
        };
        
        final Map<String, dynamic> merged = {
          ...(user ?? <String, dynamic>{}),
          ...dbUserMap,
        };
        
        // ✅ REMOVED: Hardcoded email check for mayof286@gmail.com
        
        debugPrint('AuthRepository: Loaded user with role=${merged['role']}, '
            'permissionsMap keys=${merged['permissionsMap'] != null ? (merged['permissionsMap'] as Map).keys.toList() : 'NONE'}');
        users[emailKey] = merged;
        await localStore.writeUsers(users);
        user = merged;
      }
    } catch (e) {
      debugPrint('AuthRepository: getCurrentUser DB fallback failed: $e');
    }
    
    if (user != null) {
      currentUser = user;
      _cachedUser = user;
      _cachedToken = token;
      _cacheTimestamp = DateTime.now();
      return user;
    }
    return null;
  }

  Future<void> revokeSession(String sessionId) async {
    final sessions = await localStore.readSessions();
    sessions.remove(sessionId);
    await localStore.writeSessions(sessions);
  }

  Future<void> triggerBackgroundSyncAfterLogin() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('[AuthRepository] Background sync skipped - Firebase not initialized');
      return;
    }
    
    if (!kIsWeb && io.Platform.isWindows) {
      debugPrint('[AuthRepository] Skipping aggressive background sync on Windows');
      return;
    }
    
    debugPrint('[AuthRepository] Starting background sync after login...');
    try {
      await fsSync.syncUsersFromFirestore().catchError((e) {
        debugPrint('AuthRepository: Background users sync failed: $e');
        return 0;
      });
      debugPrint('[AuthRepository] Background sync completed successfully');
    } catch (e) {
      debugPrint('AuthRepository: Background sync encountered errors: $e');
    }
  }

  Future<void> syncUserCacheFromDb({required String userId}) async {
    try {
      final u = await driftDao.getUserById(userId);
      if (u == null) return;
      
      final email = u.email ?? u.username ?? userId;
      final emailKey = email.toLowerCase();
      
      final users = await localStore.readUsers();
      final existing = users[emailKey];
      final createdAt = u.createdAt ?? existing?['created_at'] ?? existing?['createdAt'] ?? DateTime.now().toIso8601String();
      
      users[emailKey] = {
        ...(existing ?? <String, dynamic>{}),
        'id': u.id,
        'email': emailKey,
        'username': u.username,
        'password': u.passwordHash,
        'passwordHash': u.passwordHash,
        'name': u.name,
        'contactNo': u.contactNo,
        'permissions': u.permissions,
        'companyId': u.companyId,
        'status': u.status,
        'isActive': u.isActive,
        'is_active': u.isActive,
        'isFirstLogin': u.isFirstLogin ? 1 : 0,
        'userId': u.userId ?? existing?['userId'],
        'user_id': u.userId ?? existing?['user_id'],
        'createdAt': createdAt,
        'created_at': createdAt,
      };
      await localStore.writeUsers(users);
    } catch (e) {
      debugPrint('AuthRepository: Failed to sync user cache from DB: $e');
    }
  }

  String generate2FASecret() => base64Url.encode(List.generate(20, (_) => Random.secure().nextInt(256)));

  Future<Map<String, dynamic>> setup2FA(String email, String secret) async =>
      {'success': true, 'message': '2FA enabled'};

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final code = (100000 + Random().nextInt(900000)).toString();
    return {'success': true, 'message': 'Code sent', 'code': code};
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async =>
      {'success': true, 'message': 'Password reset'};
}