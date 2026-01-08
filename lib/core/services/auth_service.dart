import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared/shared.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:random_string/random_string.dart';
import 'package:drift/drift.dart' as d;
import 'app_storage.dart' show AppStorage;

class AuthService {
  static const String _usersFile = 'users.json';
  static const String _sessionsFile = 'sessions.json';
  static const String _resetCodesFile = 'reset_codes.json';
  static const int _sessionTimeoutDays = 7;
  static const int _resetCodeExpiryMinutes = 15;
  static const String _jwtSecret = 'your-secret-key-change-in-production'; // TODO: Use environment variable
  static bool showAuthLogs = false; // Set to true to enable auth-related debug prints

  Future<Map<String, dynamic>?> _readUserFromDbByEmailOrUsername(String emailKey) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance();
    try {
      final dbResult = await db.customSelect(
        'SELECT id, username, email, password_hash, name, contact_no, permissions, company_id, status, is_first_login, user_id, created_at FROM users WHERE email = ? OR username = ?',
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
        'SELECT id, username, email, password_hash, name, contact_no, permissions, company_id, status, is_first_login, user_id, created_at FROM users WHERE id = ?',
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
    
    return {'success': true, 'message': 'Registration successful', 'userId': userId};
  }

  // User Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
    String? twoFactorCode,
  }) async {
    final users = await _readUsers();
    final emailKey = email.toLowerCase();
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
          'SELECT id, username, email, password_hash, name, contact_no, permissions, company_id, status, is_first_login, user_id, created_at FROM users WHERE email = ? OR username = ?',
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
            return {'success': false, 'message': 'User account has no password set. Please contact administrator.'};
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
      return {'success': false, 'message': 'Invalid email or password'};
    }
    
    debugPrint('User found: ${user['email']}');
    debugPrint('User has password field: ${user.containsKey('password')}');
    debugPrint('User has passwordHash field: ${user.containsKey('passwordHash')}');
    
    // Check if user is Super Admin (by role or permissions)
    final permissions = user['permissions'];
    bool isSuperAdminUser = false;
    if (permissions != null) {
      try {
        final perms = permissions is String ? jsonDecode(permissions) : permissions;
        if (perms is Map && perms['role'] == 'super_admin') {
          isSuperAdminUser = true;
        }
      } catch (_) {}
    }
    // Also check role field directly
    if (user['role'] == 'super_admin' || emailKey == 'mayof286@gmail.com') {
      isSuperAdminUser = true;
    }
    
    // Verify password - try both 'password' and 'passwordHash' fields
    final storedPassword = user['password'] as String? ?? user['passwordHash'] as String?;
    
    // Allow null password bypass for Super Admin only
    if (storedPassword == null) {
      if (isSuperAdminUser) {
        debugPrint('Super Admin login with null password - allowing bypass');
        // Continue to session creation without password verification
      } else {
        debugPrint('No password field found in user data');
        return {'success': false, 'message': 'Invalid email or password'};
      }
    }
    
    bool passwordValid = false;
    if (storedPassword != null) {
      debugPrint('Password hash format: ${storedPassword.split(':').length} parts');
      debugPrint('Password hash preview: ${storedPassword.substring(0, storedPassword.length > 50 ? 50 : storedPassword.length)}...');
      passwordValid = PasswordHasher.verify(password, storedPassword);
      debugPrint('Password verification result: $passwordValid');
    } else if (isSuperAdminUser) {
      // Super Admin with null password - skip verification
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
    
    // Check if user needs to change password (is_first_login flag from database)
    // Note: This checks the database users table, not the JSON file
    bool requiresPasswordChange = false;
    try {
      // Try to get is_first_login from database (if using database auth)
      // For now, we'll check it in the login page after getting user data
    } catch (e) {
      debugPrint('Error checking is_first_login: $e');
    }
    
    return {
      'success': true,
      'message': 'Login successful',
      'token': token,
      'sessionId': sessionId,
      'userId': user['id'],
      'email': email.toLowerCase(),
      'requires2FASetup': user['lastLogin'] == null && user['twoFactorEnabled'] == false,
      'requiresPasswordChange': requiresPasswordChange, // Will be checked in login page
    };
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
        return merged;
      }
      // Force Super Admin role and companyId for mayof286@gmail.com
      if (emailKey == 'mayof286@gmail.com' && cached != null) {
        cached['role'] = 'super_admin';
        cached['companyId'] = 'GLOBAL_ADMIN';
      }
      return cached;
    } catch (e) {
      debugPrint('AuthService: getCurrentUser DB fallback failed: $e');
      // Force Super Admin role and companyId for mayof286@gmail.com
      if (emailKey == 'mayof286@gmail.com' && cached != null) {
        cached['role'] = 'super_admin';
        cached['companyId'] = 'GLOBAL_ADMIN';
      }
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
    await storage.writeSettings(settings);
  }
}

