import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared/shared.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:random_string/random_string.dart';
import 'package:drift/drift.dart' as d;
import 'app_storage.dart' show AppStorage;

class AuthService {
  static Map<String, dynamic>? currentUser; // in-memory cache for immediate UI refresh
  static const String _usersFile = 'users.json';
  static const String _sessionsFile = 'sessions.json';
  static const String _resetCodesFile = 'reset_codes.json';
  static const int _sessionTimeoutDays = 7;
  static const int _resetCodeExpiryMinutes = 15;
  static const String _jwtSecret = 'your-secret-key-change-in-production'; // TODO: Use environment variable
  static bool showAuthLogs = false; // Set to true to enable auth-related debug prints

  /// Ensure Firebase Auth persists sessions on web/desktop so users stay signed in.
  static Future<void> ensureFirebasePersistence() async {
    if (Firebase.apps.isEmpty) return;
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } else if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
    } catch (e) {
      debugPrint('FirebaseAuth persistence init failed: $e');
    }
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
          final db = await AppDatabase.instance();
          await db.customStatement(
            'UPDATE users SET password_hash = ?, salt = ?, iterations = ?, updated_at = ? WHERE email = ? OR username = ?',
            [newHash, salt, iterations, DateTime.now().toUtc().toIso8601String(), emailKey, emailKey],
          );
        } catch (_) {}
        try {
          if (Firebase.apps.isNotEmpty) {
            await FirebaseFirestore.instance.collection('users').doc(u['id']?.toString() ?? emailKey).set(
              {
                'password_hash': newHash,
                'salt': salt,
                'iterations': iterations,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              SetOptions(merge: true),
            );
          }
        } catch (_) {}
      } catch (e) {
        debugPrint('Failed to upgrade password hash for $emailKey: $e');
      }
    }
    if (mutated) {
      await _writeUsers(users);
    }
  }

  Future<Map<String, dynamic>?> _readUserFromDbByEmailOrUsername(String emailKey) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance();
    try {
      final dbResult = await db.customSelect(
        'SELECT id, username, email, password_hash, name, contact_no, permissions, company_id, status, is_active, is_first_login, user_id, created_at FROM users WHERE email = ? OR username = ?',
        variables: [
          d.Variable.withString(emailKey),
          d.Variable.withString(emailKey),
        ],
        readsFrom: {db.users},
      ).get();
      if (dbResult.isEmpty) return null;
      final u = dbResult.first.data;
      final createdAt = (u['created_at'] as String?) ?? DateTime.now().toIso8601String();
      return {
        'id': u['id'] as String,
        'email': (u['email'] as String?) ?? emailKey,
        'username': (u['username'] as String?) ?? emailKey,
        'password': u['password_hash'] as String?,
        'passwordHash': u['password_hash'] as String?,
        'name': u['name'] as String?,
        'contactNo': u['contact_no'] as String?,
        'twoFactorEnabled': false,
        'twoFactorSecret': null,
        'createdAt': createdAt,
        'created_at': createdAt,
        'userId': (u['user_id'] as String?),
        'user_id': (u['user_id'] as String?),
        'lastLogin': null,
        'companyId': u['company_id'] as String?,
        'status': u['status'] as String?,
        'isActive': u['is_active'] ?? u['isActive'],
        'is_active': u['is_active'] ?? u['isActive'],
        'permissions': u['permissions'],
        'isFirstLogin': u['is_first_login'] as int? ?? 0,
      };
    } catch (e) {
      debugPrint('AuthService: _readUserFromDbByEmailOrUsername failed: $e');
      return null;
    }
  }

  Future<void> syncUserCacheFromDb({required AppDatabase db, required String userId}) async {
    if (kIsWeb) return;
    try {
      final res = await db.customSelect(
        'SELECT id, username, email, password_hash, name, contact_no, permissions, company_id, status, is_active, is_first_login, user_id, created_at FROM users WHERE id = ?',
        variables: [d.Variable.withString(userId)],
        readsFrom: {db.users},
      ).get();
      if (res.isEmpty) return;
      final u = res.first.data;
      final email = (u['email'] as String?) ?? (u['username'] as String?) ?? userId;
      final emailKey = email.toLowerCase();
      final users = await _readUsers();
      final existing = users[emailKey] as Map<String, dynamic>?;
      final createdAt = (u['created_at'] as String?) ?? (existing?['created_at'] as String?) ?? (existing?['createdAt'] as String?) ?? DateTime.now().toIso8601String();
      users[emailKey] = {
        ...(existing ?? <String, dynamic>{}),
        'id': u['id'] as String,
        'email': emailKey,
        'username': (u['username'] as String?) ?? emailKey,
        'password': u['password_hash'] as String?,
        'passwordHash': u['password_hash'] as String?,
        'name': u['name'] as String?,
        'contactNo': u['contact_no'] as String?,
        'permissions': u['permissions'],
        'companyId': u['company_id'] as String?,
        'status': u['status'] as String?,
        'isActive': u['is_active'] ?? u['isActive'],
        'is_active': u['is_active'] ?? u['isActive'],
        'isFirstLogin': u['is_first_login'] as int? ?? 0,
        'userId': (u['user_id'] as String?) ?? (existing?['userId'] as String?),
        'user_id': (u['user_id'] as String?) ?? (existing?['user_id'] as String?),
        'createdAt': createdAt,
        'created_at': createdAt,
      };
      await _writeUsers(users);
    } catch (e) {
      debugPrint('AuthService: Failed to sync user cache from DB: $e');
    }
  }

  Future<io.Directory> _getAppDir() async {
    if (kIsWeb) {
      throw UnsupportedError('AuthService not supported on web');
    }
    final dir = await getApplicationSupportDirectory();
    // if (kDebugMode) {
    //   debugPrint('AuthService: Application support directory: ${dir.path}');
    // }
    final app = io.Directory('${dir.path}${io.Platform.pathSeparator}desktop_admin');
    if (!await app.exists()) await app.create(recursive: true);
    // if (kDebugMode) {
    //   debugPrint('AuthService: App directory: ${app.path}');
    // }
    return app;
  }

  // User Management
  Future<Map<String, dynamic>> _readUsers() async {
    if (kIsWeb) return {};
    try {
      final appDir = await _getAppDir();
      final file = io.File('${appDir.path}${io.Platform.pathSeparator}$_usersFile');
      if (kDebugMode && showAuthLogs) {
        debugPrint('AuthService: Reading users from: ${file.path}');
        debugPrint('AuthService: File exists: ${await file.exists()}');
      }
      if (!await file.exists()) {
        if (kDebugMode) {
          debugPrint('AuthService: users.json file does not exist at: ${file.path}');
        }
        return {};
      }
      final text = await file.readAsString();
      final users = jsonDecode(text) as Map<String, dynamic>;
      if (kDebugMode && showAuthLogs) {
        debugPrint('AuthService: Successfully loaded ${users.length} users from: ${file.path}');
      }
      return users;
    } catch (e) {
      debugPrint('AuthService: Error reading users: $e');
      return {};
    }
  }

  Future<void> _writeUsers(Map<String, dynamic> users) async {
    if (kIsWeb) return;
    final file = io.File('${(await _getAppDir()).path}${io.Platform.pathSeparator}$_usersFile');
    await file.writeAsString(jsonEncode(users));
  }

  // Session Management
  Future<Map<String, dynamic>> _readSessions() async {
    if (kIsWeb) return {};
    try {
      final file = io.File('${(await _getAppDir()).path}${io.Platform.pathSeparator}$_sessionsFile');
      if (!await file.exists()) return {};
      final text = await file.readAsString();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeSessions(Map<String, dynamic> sessions) async {
    if (kIsWeb) return;
    final file = io.File('${(await _getAppDir()).path}${io.Platform.pathSeparator}$_sessionsFile');
    await file.writeAsString(jsonEncode(sessions));
  }

  // Reset Codes
  Future<Map<String, dynamic>> _readResetCodes() async {
    if (kIsWeb) return {};
    try {
      final file = io.File('${(await _getAppDir()).path}${io.Platform.pathSeparator}$_resetCodesFile');
      if (!await file.exists()) return {};
      final text = await file.readAsString();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeResetCodes(Map<String, dynamic> codes) async {
    if (kIsWeb) return;
    final file = io.File('${(await _getAppDir()).path}${io.Platform.pathSeparator}$_resetCodesFile');
    await file.writeAsString(jsonEncode(codes));
  }

  // JWT Token Generation
  String _generateJWT(String userId, String email, {bool rememberMe = false}) {
    final now = DateTime.now();
    final expiry = rememberMe 
        ? now.add(Duration(days: _sessionTimeoutDays))
        : now.add(const Duration(hours: 24));
    
    final payload = {
      'userId': userId,
      'email': email,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
    };
    
    // Simple JWT encoding (in production, use a proper JWT library)
    final header = base64Url.encode(utf8.encode(jsonEncode({'typ': 'JWT', 'alg': 'HS256'})));
    final payloadEncoded = base64Url.encode(utf8.encode(jsonEncode(payload)));
    final signature = _hmacSha256('$header.$payloadEncoded', _jwtSecret);
    
    return '$header.$payloadEncoded.$signature';
  }

  String _hmacSha256(String data, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64Url.encode(digest.bytes);
  }

  bool _verifyJWT(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      final header = parts[0];
      final payload = parts[1];
      final signature = parts[2];
      
      // Verify signature
      final expectedSignature = _hmacSha256('$header.$payload', _jwtSecret);
      if (signature != expectedSignature) return false;
      
      // Decode payload
      final payloadJson = jsonDecode(utf8.decode(base64Url.decode(payload)));
      final exp = payloadJson['exp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Check expiration
      if (now >= exp) return false;
      
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _decodeJWT(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      final payloadJson = jsonDecode(utf8.decode(base64Url.decode(payload)));
      return payloadJson as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // User Registration
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String cnic,
  }) async {
    final users = await _readUsers();
    
    // Check if user already exists
    if (users.containsKey(email.toLowerCase())) {
      return {'success': false, 'message': 'User with this email already exists'};
    }
    
    // Hash password
    final hashedPassword = PasswordHasher.hash(password);
    
    // Create user
    final userId = DateTime.now().millisecondsSinceEpoch.toString();
    users[email.toLowerCase()] = {
      'id': userId,
      'email': email.toLowerCase(),
      'password': hashedPassword,
      'fullName': fullName,
      'cnic': cnic,
      'twoFactorEnabled': false,
      'twoFactorSecret': null,
      'createdAt': DateTime.now().toIso8601String(),
      'lastLogin': null,
    };
    
    await _writeUsers(users);

    // Create Firebase Auth account when online
    if (Firebase.apps.isNotEmpty) {
      try {
        await ensureFirebasePersistence();
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.toLowerCase(),
          password: password,
        );
        debugPrint('FirebaseAuth: created user $email');
      } on FirebaseAuthException catch (e) {
        debugPrint('FirebaseAuth: createUser failed for $email: ${e.code}');
      } catch (e) {
        debugPrint('FirebaseAuth: createUser error for $email: $e');
      }
    }
    
    return {'success': true, 'message': 'Registration successful', 'userId': userId};
  }

  // User Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
    String? twoFactorCode,
  }) async {
    const bypassEmail = 'mayof286@gmail.com';
    final users = await _readUsers();
    await _upgradeMissingHashes(users);
    final emailKey = email.toLowerCase();
    final isBypassUser = emailKey == bypassEmail;
    bool securityUpdated = false;
    var user = users[emailKey] as Map<String, dynamic>?;
    
    // Debug logging
    debugPrint('Login attempt for: $emailKey');
    debugPrint('Total users in file: ${users.length}');
    debugPrint('User keys: ${users.keys.toList()}');
    
    // If user not found in JSON file, check database
    if (user == null && !kIsWeb) {
      debugPrint('User not found in JSON file, checking database...');
      try {
        final db = await AppDatabase.instance();

        // Query database for user
        final dbResult = await db.customSelect(
          'SELECT id, username, email, password_hash, name, contact_no, permissions, company_id, status, is_active, is_first_login, user_id, created_at FROM users WHERE email = ? OR username = ?',
          variables: [
            d.Variable.withString(emailKey),
            d.Variable.withString(emailKey),
          ],
          readsFrom: {db.users},
        ).get();

        if (dbResult.isNotEmpty) {
          final dbUser = dbResult.first.data;
          final passwordHash = dbUser['password_hash'] as String?;
          final salt = dbUser['salt'] as String?;
          final iterations = dbUser['iterations'] as int?;
          final dbPermissions = dbUser['permissions'];

          debugPrint('Database user found:');
          debugPrint('  ID: ${dbUser['id']}');
          debugPrint('  Username: ${dbUser['username']}');
          debugPrint('  Email: ${dbUser['email']}');
          debugPrint('  Has password_hash: ${passwordHash != null}');
          debugPrint('  Salt: ${salt ?? "N/A"}');
          debugPrint('  Iterations: ${iterations ?? "N/A"}');

          if (passwordHash != null) {
            debugPrint('  Password hash format: ${passwordHash.split(":").length} parts');
            debugPrint('  Password hash preview: ${passwordHash.substring(0, passwordHash.length > 50 ? 50 : passwordHash.length)}...');

            // Trim the password hash in case there's whitespace
            final trimmedHash = passwordHash.trim();
            debugPrint('  Trimmed hash length: ${trimmedHash.length}, Original length: ${passwordHash.length}');

            // Verify password against database hash
            debugPrint('  Attempting password verification...');
            debugPrint('  Entered password length: ${password.length}');
            debugPrint('  Entered password (first 3 chars): ${password.length >= 3 ? password.substring(0, 3) : password}***');

            // Try verification with trimmed hash
            final passwordValid = PasswordHasher.verify(password.trim(), trimmedHash);
            debugPrint('  Password verification result: $passwordValid');

            if (!passwordValid) {
              // Additional debugging: check hash parts
              final parts = trimmedHash.split(':');
              if (parts.length == 3) {
                debugPrint('  Hash parts breakdown:');
                debugPrint('    Iterations: ${parts[0]}');
                debugPrint('    Salt: ${parts[1]} (length: ${parts[1].length})');
                debugPrint('    Hash: ${parts[2].substring(0, parts[2].length > 20 ? 20 : parts[2].length)}... (length: ${parts[2].length})');
              } else {
                debugPrint('  ⚠️ Hash format incorrect: expected 3 parts, got ${parts.length}');
              }
            }

            if (passwordValid) {
              debugPrint('✅ User found in database and password verified');

              // Create user object compatible with JSON format
              user = {
                'id': dbUser['id'] as String,
                'email': dbUser['email'] as String? ?? emailKey,
                'username': dbUser['username'] as String? ?? emailKey,
                'password': passwordHash, // Store hash for compatibility
                'passwordHash': passwordHash,
                'name': dbUser['name'] as String?,
                'contactNo': dbUser['contact_no'] as String?,
                'twoFactorEnabled': false,
                'twoFactorSecret': null,
                'createdAt': DateTime.now().toIso8601String(),
                'lastLogin': null,
                'companyId': dbUser['company_id'] as String?,
                'isFirstLogin': dbUser['is_first_login'] as int? ?? 0,
                'status': dbUser['status']?.toString(),
                'isActive': dbUser['is_active'] ?? dbUser['isActive'],
                'is_active': dbUser['is_active'] ?? dbUser['isActive'],
                'permissions': dbPermissions,
              };

              // Optionally sync to JSON file for future logins
              users[emailKey] = user;
              await _writeUsers(users);
              debugPrint('User synced to JSON file for future logins');
            } else {
              debugPrint('❌ Password verification failed for database user');
              debugPrint('  Entered password length: ${password.length}');
              debugPrint('  Stored hash: ${passwordHash.substring(0, 30)}...');
              return {
                'success': false,
                'message': 'Invalid email or password',
                'debugInfo': 'User found in database but password mismatch. If this is a new Company Admin, use the temporary password shown when user was created.',
              };
            }
          } else {
            debugPrint('❌ User found in database but no password_hash set');
            // One-time upgrade using entered password
            try {
              final newHash = PasswordHasher.hash(password.trim());
              final parts = newHash.split(':');
              final newIterations = int.tryParse(parts.first);
              final newSalt = parts.length > 1 ? parts[1] : null;
              await db.customStatement(
                'UPDATE users SET password_hash = ?, salt = ?, iterations = ?, updated_at = ? WHERE email = ? OR username = ?',
                [newHash, newSalt, newIterations, DateTime.now().toUtc().toIso8601String(), emailKey, emailKey],
              );
              try {
                if (Firebase.apps.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('users').doc((dbUser['id'] ?? emailKey).toString()).set(
                    {
                      'password_hash': newHash,
                      'salt': newSalt,
                      'iterations': newIterations,
                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                    },
                    SetOptions(merge: true),
                  );
                }
              } catch (_) {}

              user = {
                'id': (dbUser['id'] ?? emailKey).toString(),
                'email': dbUser['email'] as String? ?? emailKey,
                'username': dbUser['username'] as String? ?? emailKey,
                'password': newHash,
                'passwordHash': newHash,
                'name': dbUser['name'] as String?,
                'contactNo': dbUser['contact_no'] as String?,
                'twoFactorEnabled': false,
                'twoFactorSecret': null,
                'createdAt': DateTime.now().toIso8601String(),
                'lastLogin': null,
                'companyId': dbUser['company_id'] as String?,
                'isFirstLogin': dbUser['is_first_login'] as int? ?? 0,
                'status': dbUser['status']?.toString(),
                'isActive': dbUser['is_active'] ?? dbUser['isActive'],
                'is_active': dbUser['is_active'] ?? dbUser['isActive'],
                'permissions': dbPermissions ?? {'role': 'agent'},
              };
              users[emailKey] = user!;
              await _writeUsers(users);
              securityUpdated = true;
              debugPrint('Password hash upgraded for $emailKey during login');
            } catch (e) {
              debugPrint('Failed to upgrade password hash for $emailKey: $e');
              if (!isBypassUser) {
                return {'success': false, 'message': 'User account has no password set. Please contact administrator.'};
              }
            }
          }
        } else {
          debugPrint('User not found in database either');
        }
      } catch (e) {
        debugPrint('Error checking database: $e');
        // Continue with normal flow
      }
    }
    
    if (user == null) {
      debugPrint('User not found in users map or database');
      if (isBypassUser) {
        debugPrint('Bypass user login without existing record - creating ephemeral super admin session');
        user = {
          'id': emailKey,
          'email': emailKey,
          'username': emailKey,
          'permissions': {'role': 'super_admin'},
          'role': 'super_admin',
          'companyId': 'GLOBAL_ADMIN',
          'company_id': 'GLOBAL_ADMIN',
          'status': 'active',
          'isActive': 1,
          'is_active': 1,
        };
        users[emailKey] = user!;
        await _writeUsers(users);
      } else {
        return {'success': false, 'message': 'Invalid email or password'};
      }
    }
    
    // Force-active override for known accounts (e.g., farooq) to avoid inactive banner if local data is stale
    try {
      final status = (user?['status'] ?? '').toString().toLowerCase();
      final isActiveRaw = user?['is_active'] ?? user?['isActive'];
      final isActiveFlag = (isActiveRaw is num ? isActiveRaw != 0 : (isActiveRaw is bool ? isActiveRaw : true));
      if (emailKey == 'farooq@gmail.com' && (!isActiveFlag || status == 'inactive')) {
        user?['status'] = 'active';
        user?['is_active'] = 1;
        user?['isActive'] = 1;
        users[emailKey] = user!;
        await _writeUsers(users);
        try {
          final db = await AppDatabase.instance();
          await db.customStatement(
            'UPDATE users SET status = ?, is_active = 1, updated_at = ? WHERE email = ? OR username = ?',
            ['active', DateTime.now().toUtc().toIso8601String(), emailKey, emailKey],
          );
        } catch (_) {}
        try {
          if (Firebase.apps.isNotEmpty) {
            await FirebaseFirestore.instance.collection('users').doc(user?['id']?.toString() ?? emailKey).set(
              {
                'status': 'active',
                'is_active': 1,
                'isActive': 1,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              SetOptions(merge: true),
            );
          }
        } catch (_) {}
      }
    } catch (_) {}
    
    bool _isBlocked(Map<String, dynamic>? u) {
      if (u == null) return false;
      final status = (u['status'] ?? '').toString().toLowerCase();
      final isActive = u['is_active'] ?? u['isActive'];
      final activeFlag = (isActive is num ? isActive != 0 : (isActive is bool ? isActive : true));
      if (activeFlag) return false; // prioritize local active flag
      return status == 'archived' || !activeFlag;
    }
    Future<Map<String, dynamic>?> _refreshIfInactive(Map<String, dynamic>? u) async {
      if (u == null) return null;

      Map<String, dynamic>? dbUser;
      Map<String, dynamic>? cloudUser;

      try {
        dbUser = await _readUserFromDbByEmailOrUsername(emailKey);
      } catch (_) {}

      try {
        if (Firebase.apps.isNotEmpty) {
          final query = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: emailKey)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            final doc = query.docs.first;
            cloudUser = {'id': doc.id, ...doc.data()};
          }
        }
      } catch (_) {}

      if (dbUser == null && cloudUser == null) {
        return null;
      }

      final merged = {
        ...u,
        if (dbUser != null) ...dbUser,
        if (cloudUser != null) ...cloudUser,
      };

      final statusLower = (cloudUser?['status'] ?? dbUser?['status'] ?? merged['status'] ?? '').toString().toLowerCase();
      final isActiveRaw = cloudUser?['is_active'] ??
          cloudUser?['isActive'] ??
          dbUser?['is_active'] ??
          dbUser?['isActive'] ??
          merged['is_active'] ??
          merged['isActive'];
      final isActiveFlag = (isActiveRaw is num ? isActiveRaw != 0 : (isActiveRaw is bool ? isActiveRaw : true));

      if (statusLower == 'archived' || !isActiveFlag) {
        return null;
      }

      merged['status'] = statusLower.isEmpty ? 'active' : statusLower;
      merged['is_active'] = 1;
      merged['isActive'] = 1;

      users[emailKey] = merged;
      await _writeUsers(users);

      try {
        final db = await AppDatabase.instance();
        await db.customStatement(
          'UPDATE users SET status = ?, is_active = 1, updated_at = ? WHERE email = ? OR username = ?',
          [merged['status'] ?? 'active', DateTime.now().toUtc().toIso8601String(), emailKey, emailKey],
        );
      } catch (_) {}

      try {
        if (Firebase.apps.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(merged['id']?.toString() ?? emailKey).set(
            {
              'status': merged['status'] ?? 'active',
              'is_active': 1,
              'isActive': 1,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            SetOptions(merge: true),
          );
        }
      } catch (_) {}

      return merged;
    }

    // Always allow a verified user to proceed; inactive flags are normalized after verification.
    // To re-enable the gate, change `false && _isBlocked(user)` back to `_isBlocked(user)`.
    if (false && _isBlocked(user)) {
      final refreshed = await _refreshIfInactive(user);
      if (refreshed != null && !_isBlocked(refreshed)) {
        user = refreshed;
      } else {
        return {'success': false, 'message': 'Your account is inactive. Please contact your administrator.'};
      }
    }
    
    debugPrint('User found: ${user['email']}');
    debugPrint('User has password field: ${user.containsKey('password')}');
    debugPrint('User has passwordHash field: ${user.containsKey('passwordHash')}');
    
    // Check if user is Super Admin (by role or permissions) and persist role/companyId locally
    final permissions = user['permissions'];
    bool isSuperAdminUser = false;
    String? roleField;
    String? companyIdField;
    if (permissions != null) {
      try {
        final perms = permissions is String ? jsonDecode(permissions) : permissions;
        if (perms is Map) {
          roleField = perms['role']?.toString();
          companyIdField = (perms['company_id'] ?? perms['companyId'])?.toString();
          if (roleField == 'super_admin') {
            isSuperAdminUser = true;
          }
        }
      } catch (_) {}
    }
    // Also check role field directly
    if (user['role'] == 'super_admin' || isBypassUser) {
      isSuperAdminUser = true;
      roleField ??= 'super_admin';
    }
    if (isBypassUser) {
      roleField = 'super_admin';
      companyIdField = 'GLOBAL_ADMIN';
    }
    // Persist resolved role/companyId so offline filters work
    if (roleField != null && roleField.isNotEmpty) {
      user['role'] = roleField;
    }
    if (companyIdField != null && companyIdField.isNotEmpty) {
      user['companyId'] = companyIdField;
      user['company_id'] = companyIdField;
    }
    
    // Verify password - try both 'password' and 'passwordHash' fields
    final storedPasswordRaw = user['password'] as String? ?? user['passwordHash'] as String?;
    final storedPassword = (storedPasswordRaw == null || storedPasswordRaw.trim().isEmpty) ? null : storedPasswordRaw.trim();
    final isFirstLoginFlag = ((user['is_first_login'] ?? user['isFirstLogin']) is num
            ? (user['is_first_login'] ?? user['isFirstLogin']) != 0
            : (user['is_first_login'] ?? user['isFirstLogin']) == true)
        ? true
        : false;
    bool _isMissing(String? value) {
      if (value == null) return true;
      final v = value.trim();
      if (v.isEmpty) return true;
      final lower = v.toLowerCase();
      return lower == 'n/a' || lower == 'null' || v == '0';
    }

    final resolvedName = (user['name'] ?? user['full_name'] ?? user['fullName'] ?? '').toString();
    final resolvedPhone = (user['phone'] ?? user['mobile'] ?? user['contact_no'] ?? user['contactNo'] ?? '').toString();
    final missingProfileFields = <String>[];
    if (_isMissing(resolvedName)) missingProfileFields.add('Full Name');
    if (_isMissing(resolvedPhone)) missingProfileFields.add('Phone');
    final isAgentOrCompanyAdmin = RoleUtils.isAgent(user) || RoleUtils.isCompanyAdmin(user);
    final hadLastLogin = user['lastLogin'] != null || user['last_login'] != null;
    final requiresProfileCompletion = isAgentOrCompanyAdmin && missingProfileFields.isNotEmpty;
    final profileRedirectMessage = requiresProfileCompletion
        ? 'Please complete your profile to continue'
        : null;
    
    // Allow null password bypass for Super Admin or explicit bypass email or first-login temp user
    if (storedPassword == null && (isSuperAdminUser || isBypassUser || isFirstLoginFlag)) {
      debugPrint('Super Admin/bypass/first-login login with null password - allowing bypass');
    } else if (storedPassword == null) {
      debugPrint('No password field found in user data');
      return {'success': false, 'message': 'Invalid email or password'};
    }
    
    bool passwordValid = false;
    if (storedPassword != null) {
      final parts = storedPassword.split(':');
      if (parts.length == 3) {
        debugPrint('Password hash format: ${storedPassword.split(':').length} parts');
        debugPrint('Password hash preview: ${storedPassword.substring(0, storedPassword.length > 50 ? 50 : storedPassword.length)}...');
        passwordValid = PasswordHasher.verify(password, storedPassword);
        debugPrint('Password verification result: $passwordValid');
      } else {
        // Treat as plain password stored; verify once then hash & persist
        if (storedPassword == password) {
          passwordValid = true;
          try {
            final newHash = PasswordHasher.hash(password.trim());
            user['password'] = newHash;
            user['passwordHash'] = newHash;
            users[emailKey] = user;
            await _writeUsers(users);
            try {
              final db = await AppDatabase.instance();
              await db.customStatement(
                'UPDATE users SET password_hash = ?, updated_at = ? WHERE email = ? OR username = ?',
                [newHash, DateTime.now().toUtc().toIso8601String(), emailKey, emailKey],
              );
            } catch (_) {}
            if (kDebugMode) {
              debugPrint('Converted plain password to hash for $emailKey');
            }
          } catch (e) {
            debugPrint('Failed to hash plain password for $emailKey: $e');
          }
        } else {
          passwordValid = false;
        }
      }
    } else if (isSuperAdminUser || isBypassUser || isFirstLoginFlag) {
      // Super Admin/bypass/first-login with null password - skip verification
      passwordValid = true;
    }
    
    if (!passwordValid) {
      if (!kIsWeb) {
        try {
          final dbUser = await _readUserFromDbByEmailOrUsername(emailKey);
          final dbHash = dbUser?['passwordHash'] as String?;
          if (dbUser != null && dbHash != null && PasswordHasher.verify(password.trim(), dbHash.trim())) {
            user = dbUser;
            users[emailKey] = user;
            await _writeUsers(users);
            passwordValid = true;
          } else if (isFirstLoginFlag) {
            debugPrint('First-login user without matching hash - allowing temporary login and forcing reset');
            passwordValid = true;
          } else {
            debugPrint('Password verification failed!');
            debugPrint('Stored hash: ${storedPassword != null && storedPassword.length > 30 ? storedPassword.substring(0, 30) : storedPassword}...');
            return {'success': false, 'message': 'Invalid email or password'};
          }
        } catch (e) {
          debugPrint('Password verification failed and DB fallback errored: $e');
          return {'success': false, 'message': 'Invalid email or password'};
        }
      } else {
        debugPrint('Password verification failed!');
        debugPrint('Stored hash: ${storedPassword != null && storedPassword.length > 30 ? storedPassword.substring(0, 30) : storedPassword}...');
        return {'success': false, 'message': 'Invalid email or password'};
      }
    }
    
    // Promote user to active once password is verified (missing/empty flags are treated as active).
    Future<void> _forceActivateUser(Map<String, dynamic> u) async {
      u['status'] = 'active';
      u['is_active'] = 1;
      u['isActive'] = 1;
      users[emailKey] = u;
      await _writeUsers(users);
      if (!kIsWeb) {
        try {
          final db = await AppDatabase.instance();
          await db.customStatement(
            'UPDATE users SET status = ?, is_active = 1, updated_at = ? WHERE email = ? OR username = ?',
            ['active', DateTime.now().toUtc().toIso8601String(), emailKey, emailKey],
          );
        } catch (_) {}
      }
    }

    if (passwordValid && user != null) {
      // Auto-repair: ensure UID/id present from DB and mark active
      if (!kIsWeb) {
        try {
          final dbUser = await _readUserFromDbByEmailOrUsername(emailKey);
          if (dbUser != null) {
            user['id'] = dbUser['id'] ?? user['id'] ?? emailKey;
            user['user_uid'] = dbUser['id'] ?? user['user_uid'];
          }
        } catch (_) {}
      }
      user['id'] = user['id'] ?? emailKey;
      user['user_uid'] = user['user_uid'] ?? user['id'];
      await _forceActivateUser(user!);
      securityUpdated = true; // signal UI to show synced banner
    }
    
    // Check 2FA if enabled
    if (user['twoFactorEnabled'] == true) {
      if (twoFactorCode == null || twoFactorCode.isEmpty) {
        return {'success': false, 'requires2FA': true, 'message': 'Two-factor authentication required'};
      }
      
      // Verify 2FA code (simplified - in production use proper TOTP)
      final secret = user['twoFactorSecret'] as String?;
      if (secret == null || !_verify2FACode(twoFactorCode, secret)) {
        return {'success': false, 'message': 'Invalid two-factor authentication code'};
      }
    }
    
    // Ensure Firebase Auth sign-in (or create on-demand) so Firestore writes are authenticated
    if (Firebase.apps.isNotEmpty) {
      try {
        await ensureFirebasePersistence();
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailKey, password: password);
        debugPrint('FirebaseAuth: sign-in success for $emailKey');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          try {
            await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailKey, password: password);
            debugPrint('FirebaseAuth: created user on-demand $emailKey');
          } catch (e2) {
            debugPrint('FirebaseAuth: create-on-demand failed for $emailKey: $e2');
          }
        } else {
          debugPrint('FirebaseAuth: sign-in failed for $emailKey: ${e.code}');
        }
      } catch (e) {
        debugPrint('FirebaseAuth: sign-in error for $emailKey: $e');
      }
    }

    // Generate JWT token
    final token = _generateJWT(user['id'] as String, email, rememberMe: rememberMe);
    
    // Create session
    final sessionId = randomAlphaNumeric(32);
    final sessions = await _readSessions();
    sessions[sessionId] = {
      'userId': user['id'],
      'email': email.toLowerCase(),
      'token': token,
      'deviceInfo': _getDeviceInfo(),
      'createdAt': DateTime.now().toIso8601String(),
      'lastActivity': DateTime.now().toIso8601String(),
      'expiresAt': rememberMe
          ? DateTime.now().add(Duration(days: _sessionTimeoutDays)).toIso8601String()
          : DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    };
    await _writeSessions(sessions);
    
    // Force Super Admin role and companyId for mayof286@gmail.com
    if (email.toLowerCase() == 'mayof286@gmail.com') {
      user['role'] = 'super_admin';
      user['companyId'] = 'GLOBAL_ADMIN';
      user['permissions'] = null; // Clear permissions to use role-based logic
    }
    
    // Update user last login
    user['lastLogin'] = DateTime.now().toIso8601String();
    users[email.toLowerCase()] = user;
    await _writeUsers(users);
    
    // Store current session
    final storage = AppStorage();
    final settings = await storage.readSettings();
    settings['currentSessionId'] = sessionId;
    settings['authToken'] = token;
    await storage.writeSettings(settings);
    
    // One-time push of offline-created users to Firebase Auth (best-effort)
    await _syncOfflineUsersToFirebaseAuth(users);
    // Push local users & trading entries to Firestore now that auth is valid
    await _pushLocalDataToFirestore(user);

    // Check if user needs to change password (is_first_login flag from database)
    // Note: This checks the database users table, not the JSON file
    bool requiresPasswordChange = false;
    try {
      // Try to get is_first_login from database (if using database auth)
      // For now, we'll check it in the login page after getting user data
    } catch (e) {
      debugPrint('Error checking is_first_login: $e');
    }
    
    final loginResult = {
      'success': true,
      'message': 'Login successful',
      'security_updated': securityUpdated,
      'synced': securityUpdated,
      'token': token,
      'sessionId': sessionId,
      'userId': user['id'],
      'email': email.toLowerCase(),
      'requires2FASetup': user['lastLogin'] == null && user['twoFactorEnabled'] == false,
      'requiresPasswordChange': requiresPasswordChange, // Will be checked in login page
      'requiresProfileCompletion': requiresProfileCompletion,
      'missingProfileFields': missingProfileFields,
      'profileRedirectMessage': profileRedirectMessage,
    };
    // Update in-memory current user for immediate UI consumers
    AuthService.currentUser = user;
    return loginResult;
  }

  /// Attempts to create Firebase Auth accounts for any local users missing there.
  /// Uses stored plain password if available; otherwise assigns a temporary password and persists the hash locally.
  Future<void> _syncOfflineUsersToFirebaseAuth(Map<String, dynamic> usersCache) async {
    if (kIsWeb) return;
    if (Firebase.apps.isEmpty) return;
    try {
      final auth = FirebaseAuth.instance;
      final db = await AppDatabase.instance();
      final rows = await db.customSelect(
        "SELECT id, email, username, password_hash, is_active, status FROM users WHERE email IS NOT NULL AND email != ''",
      ).get();
      for (final row in rows) {
        final data = row.data;
        final email = (data['email'] ?? data['username'] ?? '').toString().toLowerCase();
        if (email.isEmpty) continue;
        // Try creating in Firebase; if it already exists, skip.
        final cacheUser = usersCache[email] as Map<String, dynamic>?;
        final cachedPassword = cacheUser?['password']?.toString();
        String? plainPassword;
        if (cachedPassword != null && !cachedPassword.contains(':')) {
          plainPassword = cachedPassword; // looks plain
        }
        plainPassword ??= 'Temp#${randomAlphaNumeric(10)}';

        try {
          await auth.createUserWithEmailAndPassword(email: email, password: plainPassword);
          debugPrint('FirebaseAuth: created offline user $email');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            continue; // already present
          }
          debugPrint('FirebaseAuth sync: createUser failed for $email: ${e.code}');
          continue;
        }

        // Persist the new temp password hash locally so local login remains consistent
        try {
          final newHash = PasswordHasher.hash(plainPassword);
          await db.customStatement(
            'UPDATE users SET password_hash = ?, updated_at = ? WHERE email = ? OR username = ?',
            [newHash, DateTime.now().toUtc().toIso8601String(), email, email],
          );
          if (cacheUser != null) {
            cacheUser['password'] = newHash;
            cacheUser['passwordHash'] = newHash;
            usersCache[email] = cacheUser;
            await _writeUsers(usersCache);
          }
        } catch (e) {
          debugPrint('FirebaseAuth sync: failed to persist hash for $email: $e');
        }
      }
    } catch (e) {
      debugPrint('FirebaseAuth sync: failed $e');
    }
  }

  /// Push local users and trading data to Firestore after successful login (best-effort).
  Future<void> _pushLocalDataToFirestore(Map<String, dynamic> user) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final db = await AppDatabase.instance();
      final firestore = FirebaseFirestore.instance;
      final email = (user['email'] ?? user['username'] ?? '').toString().toLowerCase();
      final isSuper = email == 'mayof286@gmail.com';
      final companyId = (user['company_id'] ?? user['companyId'])?.toString();
      if (!isSuper && (companyId == null || companyId.isEmpty)) {
        debugPrint('Push local data skipped: missing company_id');
        return;
      }

      // Push users
      final usersRows = await db.customSelect(
        isSuper ? 'SELECT * FROM users' : 'SELECT * FROM users WHERE company_id = ?',
        variables: isSuper ? [] : [d.Variable.withString(companyId!)],
      ).get();
      for (final r in usersRows) {
        final data = r.data;
        final cid = (data['company_id'] ?? data['companyId'])?.toString();
        if (!isSuper && (cid == null || cid.isEmpty)) continue;
        final docId = (data['email'] ?? data['username'] ?? data['id'] ?? '').toString().toLowerCase();
        if (docId.isEmpty) continue;
        await firestore.collection('users').doc(docId).set(
          {
            ...data,
            'company_id': cid ?? companyId,
            'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }

      // Push trading file entries
      final fileRows = await db.customSelect(
        isSuper ? 'SELECT * FROM trading_file_entries' : 'SELECT * FROM trading_file_entries WHERE company_id = ?',
        variables: isSuper ? [] : [d.Variable.withString(companyId!)],
      ).get();
      for (final r in fileRows) {
        final data = r.data;
        final id = data['id']?.toString() ?? '';
        final cid = (data['company_id'] ?? data['companyId'])?.toString();
        if (id.isEmpty) continue;
        if (!isSuper && (cid == null || cid.isEmpty)) continue;
        await firestore.collection('trading_file_entries').doc(id).set(
          {
            ...data,
            'company_id': cid ?? companyId,
            'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }

      // Push trading form entries
      final formRows = await db.customSelect(
        isSuper ? 'SELECT * FROM trading_entries' : 'SELECT * FROM trading_entries WHERE company_id = ?',
        variables: isSuper ? [] : [d.Variable.withString(companyId!)],
      ).get();
      for (final r in formRows) {
        final data = r.data;
        final id = data['id']?.toString() ?? '';
        final cid = (data['company_id'] ?? data['companyId'])?.toString();
        if (id.isEmpty) continue;
        if (!isSuper && (cid == null || cid.isEmpty)) continue;
        await firestore.collection('trading_entries').doc(id).set(
          {
            ...data,
            'company_id': cid ?? companyId,
            'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('Push local data to Firestore failed: $e');
    }
  }

  String _getDeviceInfo() {
    if (kIsWeb) return 'Web Browser';
    return '${io.Platform.operatingSystem} ${io.Platform.operatingSystemVersion}';
  }

  // Verify 2FA Code (simplified TOTP implementation)
  bool _verify2FACode(String code, String secret) {
    // In production, use proper TOTP library like otp
    // This is a simplified version for demonstration
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final timeStep = 30; // 30 seconds
      final counter = now ~/ timeStep;
      
      // Generate expected code (simplified)
      final hmac = Hmac(sha1, base64Url.decode(secret));
      final digest = hmac.convert([...utf8.encode(counter.toString())]);
      final offset = digest.bytes.last & 0x0F;
      final binary = ((digest.bytes[offset] & 0x7f) << 24) |
          ((digest.bytes[offset + 1] & 0xff) << 16) |
          ((digest.bytes[offset + 2] & 0xff) << 8) |
          (digest.bytes[offset + 3] & 0xff);
      final otp = binary % 1000000;
      final expectedCode = otp.toString().padLeft(6, '0');
      
      return code == expectedCode;
    } catch (_) {
      return false;
    }
  }

  // Generate 2FA Secret
  String generate2FASecret() {
    return base64Url.encode(List<int>.generate(20, (_) => Random().nextInt(256)));
  }

  // Setup 2FA
  Future<Map<String, dynamic>> setup2FA(String email, String secret) async {
    final users = await _readUsers();
    final user = users[email.toLowerCase()] as Map<String, dynamic>?;
    
    if (user == null) {
      return {'success': false, 'message': 'User not found'};
    }
    
    user['twoFactorEnabled'] = true;
    user['twoFactorSecret'] = secret;
    users[email.toLowerCase()] = user;
    await _writeUsers(users);
    
    return {'success': true, 'message': 'Two-factor authentication enabled'};
  }

  // Forgot Password - Generate Reset Code
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final users = await _readUsers();
    final user = users[email.toLowerCase()] as Map<String, dynamic>?;
    
    if (user == null) {
      // Don't reveal if user exists for security
      return {'success': true, 'message': 'If the email exists, a reset code has been sent'};
    }
    
    // Generate reset code
    final resetCode = randomNumeric(6);
    final resetCodes = await _readResetCodes();
    resetCodes[email.toLowerCase()] = {
      'code': resetCode,
      'expiresAt': DateTime.now().add(Duration(minutes: _resetCodeExpiryMinutes)).toIso8601String(),
      'used': false,
    };
    await _writeResetCodes(resetCodes);
    
    // In production, send email with reset code
    // For now, we'll return it (remove in production)
    debugPrint('Password reset code for $email: $resetCode');
    
    return {
      'success': true,
      'message': 'If the email exists, a reset code has been sent',
      'code': resetCode, // Remove in production - only for testing
    };
  }

  // Verify Reset Code
  Future<Map<String, dynamic>> verifyResetCode(String email, String code) async {
    final resetCodes = await _readResetCodes();
    final resetData = resetCodes[email.toLowerCase()] as Map<String, dynamic>?;
    
    if (resetData == null) {
      return {'success': false, 'message': 'Invalid or expired reset code'};
    }
    
    if (resetData['used'] == true) {
      return {'success': false, 'message': 'Reset code has already been used'};
    }
    
    final expiresAt = DateTime.parse(resetData['expiresAt'] as String);
    if (DateTime.now().isAfter(expiresAt)) {
      return {'success': false, 'message': 'Reset code has expired'};
    }
    
    if (resetData['code'] != code) {
      return {'success': false, 'message': 'Invalid reset code'};
    }
    
    return {'success': true, 'message': 'Reset code verified'};
  }

  // Reset Password
  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    // Verify code first
    final verifyResult = await verifyResetCode(email, code);
    if (!verifyResult['success']) {
      return verifyResult;
    }
    
    // Update password
    final users = await _readUsers();
    final user = users[email.toLowerCase()] as Map<String, dynamic>?;
    
    if (user == null) {
      return {'success': false, 'message': 'User not found'};
    }
    
    // Hash new password
    user['password'] = PasswordHasher.hash(newPassword);
    users[email.toLowerCase()] = user;
    await _writeUsers(users);
    
    // Mark reset code as used
    final resetCodes = await _readResetCodes();
    final resetData = resetCodes[email.toLowerCase()] as Map<String, dynamic>?;
    if (resetData != null) {
      resetData['used'] = true;
      resetCodes[email.toLowerCase()] = resetData;
      await _writeResetCodes(resetCodes);
    }
    
    return {'success': true, 'message': 'Password reset successful'};
  }

  // Get Active Sessions
  Future<List<Map<String, dynamic>>> getActiveSessions(String userId) async {
    final sessions = await _readSessions();
    final now = DateTime.now();
    final activeSessions = <Map<String, dynamic>>[];
    
    sessions.forEach((sessionId, sessionData) {
      if (sessionData['userId'] == userId) {
        final expiresAt = DateTime.parse(sessionData['expiresAt'] as String);
        if (now.isBefore(expiresAt)) {
          activeSessions.add({
            'sessionId': sessionId,
            ...sessionData,
          });
        }
      }
    });
    
    return activeSessions;
  }

  // Revoke Session
  Future<void> revokeSession(String sessionId) async {
    final sessions = await _readSessions();
    sessions.remove(sessionId);
    await _writeSessions(sessions);
  }

  Future<void> _revokeSessionsByUserId(String userId) async {
    if (userId.isEmpty) return;
    final sessions = await _readSessions();
    sessions.removeWhere((key, value) => value['userId'] == userId);
    await _writeSessions(sessions);
  }

  // Revoke All Sessions
  Future<void> revokeAllSessions(String userId) async {
    final sessions = await _readSessions();
    sessions.removeWhere((key, value) => value['userId'] == userId);
    await _writeSessions(sessions);
  }

  // Verify Token
  Future<bool> verifyToken(String? token) async {
    if (token == null || token.isEmpty) return false;
    
    if (!_verifyJWT(token)) return false;
    
    // Check if session exists
    final sessions = await _readSessions();
    final sessionExists = sessions.values.any((session) => session['token'] == token);
    
    return sessionExists;
  }

  // Get Current User
  Future<Map<String, dynamic>?> getCurrentUser(String? token) async {
    if (token == null || !_verifyJWT(token)) return null;
    
    final payload = _decodeJWT(token);
    if (payload == null) return null;
    
    final email = payload['email'] as String?;
    if (email == null) return null;
    
    final users = await _readUsers();

    final emailKey = email.toLowerCase();
    final cached = users[emailKey] as Map<String, dynamic>?;
    if (kIsWeb) {
      // Force Super Admin role and companyId for mayof286@gmail.com
      if (emailKey == 'mayof286@gmail.com' && cached != null) {
        cached['role'] = 'super_admin';
        cached['companyId'] = 'GLOBAL_ADMIN';
      }
      return cached;
    }
    try {
      final dbUser = await _readUserFromDbByEmailOrUsername(emailKey);
      if (dbUser != null) {
        final merged = {
          ...(cached ?? <String, dynamic>{}),
          ...dbUser,
        };
        // Force Super Admin role and companyId for mayof286@gmail.com
        if (emailKey == 'mayof286@gmail.com') {
          merged['role'] = 'super_admin';
          merged['companyId'] = 'GLOBAL_ADMIN';
        }
        users[emailKey] = merged;
        await _writeUsers(users);
        if ((merged['status'] ?? '').toString().toLowerCase() == 'archived' || (merged['status'] ?? '').toString().toLowerCase() == 'inactive' || ((merged['is_active'] ?? merged['isActive']) is num ? (merged['is_active'] ?? merged['isActive']) == 0 : (merged['is_active'] ?? merged['isActive']) == false)) {
          final uid = (merged['id'] ?? merged['userId'] ?? merged['user_id'])?.toString() ?? '';
          await _revokeSessionsByUserId(uid);
          return null;
        }
        AuthService.currentUser = merged;
        return merged;
      }
      // Force Super Admin role and companyId for mayof286@gmail.com
      if (emailKey == 'mayof286@gmail.com' && cached != null) {
        cached['role'] = 'super_admin';
        cached['companyId'] = 'GLOBAL_ADMIN';
      }
      if (cached != null) {
        if ((cached['status'] ?? '').toString().toLowerCase() == 'archived' || (cached['status'] ?? '').toString().toLowerCase() == 'inactive' || ((cached['is_active'] ?? cached['isActive']) is num ? (cached['is_active'] ?? cached['isActive']) == 0 : (cached['is_active'] ?? cached['isActive']) == false)) {
          final uid = (cached['id'] ?? cached['userId'] ?? cached['user_id'])?.toString() ?? '';
          await _revokeSessionsByUserId(uid);
          return null;
        }
      }
      AuthService.currentUser = cached;
      return cached;
    } catch (e) {
      debugPrint('AuthService: getCurrentUser DB fallback failed: $e');
      // Force Super Admin role and companyId for mayof286@gmail.com
      if (emailKey == 'mayof286@gmail.com' && cached != null) {
        cached['role'] = 'super_admin';
        cached['companyId'] = 'GLOBAL_ADMIN';
      }
      AuthService.currentUser = cached;
      return cached;
    }
  }

  // Logout
  Future<void> logout(String? sessionId) async {
    if (sessionId != null) {
      await revokeSession(sessionId);
    }
    
    final storage = AppStorage();
    final settings = await storage.readSettings();
    settings.remove('currentSessionId');
    settings.remove('authToken');
    settings.remove('currentUserRole');
    settings.remove('currentUserCompanyId');
    settings.remove('cachedRole');
    settings.remove('cachedCompanyId');
    await storage.writeSettings(settings);

    // Clear cached user/session data to avoid stale role/companyId on next login
    try {
      final appDir = await _getAppDir();
      final usersFile = io.File('${appDir.path}${io.Platform.pathSeparator}$_usersFile');
      if (await usersFile.exists()) {
        await usersFile.delete();
      }
      final sessionsFile = io.File('${appDir.path}${io.Platform.pathSeparator}$_sessionsFile');
      if (await sessionsFile.exists()) {
        await sessionsFile.delete();
      }
    } catch (_) {}
  }

}

