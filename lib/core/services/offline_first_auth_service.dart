import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as d;
import 'package:shared/shared.dart';
import 'firebase_threading_handler.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';

/// Offline-First Authentication Service
/// 
/// This service implements a strict offline-first architecture:
/// 1. First-time login requires internet and Firebase Auth
/// 2. Subsequent logins are completely offline using secure local storage
/// 3. Password changes work offline and sync when internet is available
/// 4. All data operations are local-first with background Firebase sync
class OfflineFirstAuthService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    wOptions: WindowsOptions(
      // Use secure credential manager - FIXED: Removed insecurePath argument
    ),
  );

  static const String _authStateKey = 'auth_state';
  static const String _userCredentialsKey = 'user_credentials';
  static const String _pendingPasswordChangeKey = 'pending_password_change';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const Duration _connectivityCheckInterval = Duration(seconds: 15);
  static const String _pingUrl = 'https://www.google.com';

  static bool _isInitialized = false;
  static bool _isOnline = false;
  static Timer? _connectivityCheckTimer;
  static StreamSubscription<fb.User?>? _authSubscription;

  // Authentication state streams
  static final StreamController<AuthState> _authStateController = 
      StreamController<AuthState>.broadcast();
  static Stream<AuthState> get authStateStream => _authStateController.stream;

  // User data stream for real-time updates
  static final StreamController<Map<String, dynamic>?> _userController = 
      StreamController<Map<String, dynamic>?>.broadcast();
  static Stream<Map<String, dynamic>?> get userStream => _userController.stream;

  static Map<String, dynamic>? _currentUser;
  static AuthState _currentAuthState = AuthState.uninitialized;

  /// Initialize the offline-first auth service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('OfflineFirstAuthService: Initializing...');
    
    try {
      // Initialize Windows FFI if needed
      await _initializeWindowsFfi();
      
      // Check for existing authentication state
      final hasStoredAuth = await _hasStoredAuthentication();
      
      if (hasStoredAuth) {
        // Try to authenticate locally first
        final localAuthSuccess = await _authenticateLocally();
        if (localAuthSuccess) {
          _currentAuthState = AuthState.authenticated;
          _emitAuthState();
          
          // Start connectivity check for background sync
          _startConnectivityCheck();
          
          debugPrint('OfflineFirstAuthService: Initialized with local authentication');
        } else {
          _currentAuthState = AuthState.unauthenticated;
          _emitAuthState();
          debugPrint('OfflineFirstAuthService: Local authentication failed');
        }
      } else {
        _currentAuthState = AuthState.unauthenticated;
        _emitAuthState();
        debugPrint('OfflineFirstAuthService: No stored authentication found');
      }

      // Listen to Firebase auth changes for first-time setup
      _listenToFirebaseAuth();
      
      _isInitialized = true;
      debugPrint('OfflineFirstAuthService: Initialization complete');
      
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Initialization error: $e');
      _currentAuthState = AuthState.unauthenticated;
      _emitAuthState();
    }
  }

  /// First-time login with Firebase (requires internet)
  static Future<AuthResult> signInWithFirebase({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      debugPrint('OfflineFirstAuthService: Attempting Firebase sign-in for $email');
      
      // Ensure Firebase is initialized
      if (fb.FirebaseAuth.instance.currentUser == null) {
        // Try to access Firebase Auth to check if Firebase is initialized
        try {
          await fb.FirebaseAuth.instance.authStateChanges().first;
        } catch (e) {
          throw AuthException('Firebase not initialized. Internet connection required.');
        }
      }

      // Authenticate with Firebase
      final credential = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (credential.user == null) {
        throw AuthException('Firebase authentication failed');
      }

      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user?.uid ?? '')
          .get();

      if (!userDoc.exists) {
        throw AuthException('User data not found in Firestore');
      }

      final userData = userDoc.data()!;
      userData['id'] = credential.user!.uid;
      userData['email'] = credential.user!.email;

      // Store authentication state securely
      await _storeAuthenticationState(
        userId: credential.user?.uid ?? '',
        email: email,
        password: password,
        userData: userData,
        rememberMe: rememberMe,
      );

      // Sync user data to local database
      await _syncUserToLocalDb(userData);

      // Update current user
      _currentUser = userData;
      _currentAuthState = AuthState.authenticated;
      _emitAuthState();
      _emitUserUpdate();

      // Start connectivity check for background sync
      _startConnectivityCheck();

      debugPrint('OfflineFirstAuthService: Firebase sign-in successful');
      return AuthResult.success(userData);

    } on fb.FirebaseAuthException catch (e) {
      debugPrint('OfflineFirstAuthService: Firebase auth error: ${e.code} - ${e.message}');
      return AuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Sign-in error: $e');
      return AuthResult.failure('Authentication failed: ${e.toString()}');
    }
  }

  /// Retrieve stored authentication data
  static Future<Map<String, dynamic>?> _getStoredAuthentication() async {
    try {
      final authData = await _secureStorage.read(key: _authStateKey);
      if (authData == null) return null;
      
      return jsonDecode(authData);
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error reading stored auth: $e');
      return null;
    }
  }

  /// Store authentication data
  static Future<void> _storeAuthentication(Map<String, dynamic> authData) async {
    try {
      await _secureStorage.write(key: _authStateKey, value: jsonEncode(authData));
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error storing auth: $e');
    }
  }

  /// Local authentication (offline) with Firebase Auth fallback
  static Future<AuthResult> authenticateLocally({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('OfflineFirstAuthService: Attempting local authentication for $email');

      // Retrieve stored credentials
      final storedAuth = await _getStoredAuthentication();
      if (storedAuth == null) {
        return AuthResult.failure('No stored authentication found. First-time login requires internet.');
      }

      // Verify email matches
      if (storedAuth['email'] != email.toLowerCase()) {
        return AuthResult.failure('Invalid email or password');
      }

      // Verify password using stored hash
      final storedPasswordHash = storedAuth['passwordHash'] as String?;
      final salt = storedAuth['salt'] as String?;
      final iterations = storedAuth['iterations'] as int?;

      if (storedPasswordHash == null || salt == null || iterations == null) {
        return AuthResult.failure('Invalid stored credentials');
      }

      final inputHash = _hashPassword(password, salt, iterations);
      bool passwordValid = inputHash == storedPasswordHash;

      // NEW: Firebase Auth fallback if local password verification fails
      if (!passwordValid) {
        debugPrint('OfflineFirstAuthService: Local password verification failed, attempting Firebase Auth fallback...');
        
        try {
          // Check if Firebase is initialized and we have internet
          if (Firebase.apps.isEmpty) {
            debugPrint('OfflineFirstAuthService: Firebase not initialized for fallback');
            return AuthResult.failure('Invalid email or password');
          }

          // Check internet connectivity
          final hasInternet = await _checkInternetConnectivity();
          if (!hasInternet) {
            debugPrint('OfflineFirstAuthService: No internet connection for Firebase Auth fallback');
            return AuthResult.failure('Invalid email or password');
          }

          // CRITICAL: Use Firebase Authentication as source of truth
          debugPrint('OfflineFirstAuthService: Attempting Firebase Auth sign-in...');
          final userCredential = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email.toLowerCase(),
            password: password,
          );

          if (userCredential.user != null) {
            debugPrint('OfflineFirstAuthService: Firebase Auth successful - password verified');
            
            // Generate NEW PBKDF2 hash from the verified password
            final newSalt = _generateSalt();
            const newIterations = 10000;
            final newPasswordHash = _hashPassword(password, newSalt, newIterations);
            
            debugPrint('OfflineFirstAuthService: Generated new PBKDF2 hash for local storage');

            // Update local SQLite with new hash
            await _updateStoredPassword(
              newPasswordHash: newPasswordHash,
              salt: newSalt,
              iterations: newIterations,
            );

            // Update local database with new hash
            await _updatePasswordInLocalDb(newPasswordHash, newSalt, newIterations);

            // Update Firestore document with new hash (so it's not empty anymore)
            await _updatePasswordInFirestore(
              userId: storedAuth['userId'],
              passwordHash: newPasswordHash,
              salt: newSalt,
              iterations: newIterations,
            );

            // Get updated user data
            final userData = await _getUserFromLocalDb(storedAuth['userId']);
            if (userData != null) {
              // Update current user
              _currentUser = userData;
              _currentAuthState = AuthState.authenticated;
              _emitAuthState();
              _emitUserUpdate();

              // Start connectivity check for background sync
              _startConnectivityCheck();

              debugPrint('OfflineFirstAuthService: Firebase Auth fallback authentication successful');
              return AuthResult.success(userData);
            }
          }
          
          debugPrint('OfflineFirstAuthService: Firebase Auth returned null user');
          return AuthResult.failure('Invalid email or password');
          
        } catch (e) {
          debugPrint('OfflineFirstAuthService: Firebase Auth fallback error: $e');
          return AuthResult.failure('Invalid email or password');
        }
      }

      // Get user data from local database (original flow for successful local auth)
      final userData = await _getUserFromLocalDb(storedAuth['userId']);
      if (userData == null) {
        return AuthResult.failure('User data not found locally');
      }

      // Update current user
      _currentUser = userData;
      _currentAuthState = AuthState.authenticated;
      _emitAuthState();
      _emitUserUpdate();

      // Start connectivity check for background sync
      _startConnectivityCheck();

      debugPrint('OfflineFirstAuthService: Local authentication successful');
      return AuthResult.success(userData);

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Local authentication error: $e');
      return AuthResult.failure('Local authentication failed: ${e.toString()}');
    }
  }

  /// Change password (works offline)
  static Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('No authenticated user');
      }

      debugPrint('OfflineFirstAuthService: Changing password for user ${_currentUser!['email']}');

      // Verify current password
      final authResult = await authenticateLocally(
        email: _currentUser!['email'],
        password: currentPassword,
      );

      if (!authResult.success) {
        return AuthResult.failure('Current password is incorrect');
      }

      // Generate new password hash
      final salt = _generateSalt();
      const iterations = 10000;
      final newPasswordHash = _hashPassword(newPassword, salt, iterations);

      // Update local storage immediately
      await _updateStoredPassword(
        newPasswordHash: newPasswordHash,
        salt: salt,
        iterations: iterations,
      );

      // Update local database
      await _updatePasswordInLocalDb(newPasswordHash, salt, iterations);

      // Store pending password change for background sync
      await _storePendingPasswordChange(newPassword);

      // Update current user data
      _currentUser!['passwordHash'] = newPasswordHash;
      _currentUser!['salt'] = salt;
      _currentUser!['iterations'] = iterations;
      _emitUserUpdate();

      debugPrint('OfflineFirstAuthService: Password changed successfully (offline)');
      return AuthResult.success(_currentUser!);

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Password change error: $e');
      return AuthResult.failure('Password change failed: ${e.toString()}');
    }
  }

  /// Sign out (clears local authentication)
  static Future<void> signOut() async {
    try {
      debugPrint('OfflineFirstAuthService: Signing out');

      // Clear Firebase auth if available
      if (fb.FirebaseAuth.instance.currentUser != null) {
        await fb.FirebaseAuth.instance.signOut();
      }

      // Clear local storage
      await _clearAuthenticationState();

      // Clear current user
      _currentUser = null;
      _currentAuthState = AuthState.unauthenticated;
      _emitAuthState();
      _emitUserUpdate();

      // Stop connectivity check
      _connectivityCheckTimer?.cancel();

      debugPrint('OfflineFirstAuthService: Sign out complete');

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Sign out error: $e');
    }
  }

  /// Get current authenticated user
  static Map<String, dynamic>? get currentUser => _currentUser;

  /// Get current authentication state
  static AuthState get currentAuthState => _currentAuthState;

  /// Check if user is authenticated
  static bool get isAuthenticated => _currentAuthState == AuthState.authenticated;

  /// Dispose the service
  static Future<void> dispose() async {
    _connectivityCheckTimer?.cancel();
    await _authSubscription?.cancel();
    await _authStateController.close();
    await _userController.close();
    _isInitialized = false;
  }

  // Private methods

  static Future<void> _initializeWindowsFfi() async {
    try {
      if (Platform.isWindows) {
        // Initialize SQLite FFI for Windows
        sqfliteFfiInit();
        debugPrint('OfflineFirstAuthService: Windows FFI initialized');
      }
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Windows FFI initialization error: $e');
    }
  }

  static Future<bool> _hasStoredAuthentication() async {
    try {
      final authState = await _secureStorage.read(key: _authStateKey);
      return authState != null;
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error checking stored auth: $e');
      return false;
    }
  }

  static Future<bool> _authenticateLocally() async {
    try {
      final storedAuth = await _getStoredAuthentication();
      if (storedAuth == null) return false;

      final userData = await _getUserFromLocalDb(storedAuth['userId']);
      if (userData == null) return false;

      _currentUser = userData;
      return true;

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Local auth error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getStoredAuthentication() async {
    try {
      final authStateJson = await _secureStorage.read(key: _authStateKey);
      if (authStateJson == null) return null;

      return jsonDecode(authStateJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error retrieving stored auth: $e');
      return null;
    }
  }

  static Future<void> _storeAuthenticationState({
    required String userId,
    required String email,
    required String password,
    required Map<String, dynamic> userData,
    required bool rememberMe,
  }) async {
    try {
      // Generate password hash
      final salt = _generateSalt();
      const iterations = 10000;
      final passwordHash = _hashPassword(password, salt, iterations);

      final authState = {
        'userId': userId,
        'email': email.toLowerCase(),
        'passwordHash': passwordHash,
        'salt': salt,
        'iterations': iterations,
        'rememberMe': rememberMe,
        'createdAt': DateTime.now().toIso8601String(),
        'lastAccess': DateTime.now().toIso8601String(),
      };

      // Store authentication state
      await _secureStorage.write(
        key: _authStateKey,
        value: jsonEncode(authState),
      );

      debugPrint('OfflineFirstAuthService: Authentication state stored securely');

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error storing auth state: $e');
      rethrow;
    }
  }

  static Future<void> _updateStoredPassword({
    required String newPasswordHash,
    required String salt,
    required int iterations,
  }) async {
    try {
      final storedAuth = await _getStoredAuthentication();
      if (storedAuth == null) throw Exception('No stored authentication found');

      storedAuth['passwordHash'] = newPasswordHash;
      storedAuth['salt'] = salt;
      storedAuth['iterations'] = iterations;
      storedAuth['lastAccess'] = DateTime.now().toIso8601String();

      await _secureStorage.write(
        key: _authStateKey,
        value: jsonEncode(storedAuth),
      );

      debugPrint('OfflineFirstAuthService: Stored password updated');

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error updating stored password: $e');
      rethrow;
    }
  }

  static Future<void> _clearAuthenticationState() async {
    try {
      await _secureStorage.delete(key: _authStateKey);
      await _secureStorage.delete(key: _userCredentialsKey);
      await _secureStorage.delete(key: _pendingPasswordChangeKey);
      await _secureStorage.delete(key: _lastSyncKey);
      
      debugPrint('OfflineFirstAuthService: Authentication state cleared');
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error clearing auth state: $e');
    }
  }

  static Future<bool> _checkInternetConnectivity() async {
    try {
      final response = await http.head(
        Uri.parse('https://www.google.com'),
      ).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Internet connectivity check failed: $e');
      return false;
    }
  }

  static Future<void> _updatePasswordInFirestore({
    required String userId,
    required String passwordHash,
    required String salt,
    required int iterations,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('OfflineFirstAuthService: Firebase not initialized, skipping Firestore update');
        return;
      }

      final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      await userDoc.set({
        'password_hash': passwordHash,
        'salt': salt,
        'iterations': iterations,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      debugPrint('OfflineFirstAuthService: Successfully updated password hash in Firestore');
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error updating password in Firestore: $e');
      // Don't rethrow - local auth should still work even if Firestore update fails
    }
  }

  static Future<Map<String, dynamic>?> _fetchUserFromFirestore(String email) async {
    try {
      debugPrint('OfflineFirstAuthService: Fetching user from Firestore for $email');
      
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        debugPrint('OfflineFirstAuthService: Firebase not initialized, cannot fetch from Firestore');
        return null;
      }
      
      // Query Firestore for user by email
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final userData = doc.data();
        userData['id'] = doc.id; // Ensure ID is included
        debugPrint('OfflineFirstAuthService: Successfully fetched user from Firestore');
        return userData;
      }
      
      debugPrint('OfflineFirstAuthService: User not found in Firestore');
      return null;
    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error fetching user from Firestore: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getUserFromLocalDb(String userId) async {
    try {
      final db = await AppDatabase.instance();
      final result = await db.customSelect(
        'SELECT * FROM users WHERE id = ?',
        variables: [_convertToVariable(userId)],
      ).get();

      if (result.isEmpty) return null;

      final userData = result.first.data;
      return Map<String, dynamic>.from(userData);

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error getting user from local DB: $e');
      return null;
    }
  }

  static Future<void> _syncUserToLocalDb(Map<String, dynamic> userData) async {
    try {
      final db = await AppDatabase.instance();
      
      await db.customStatement('''
        INSERT OR REPLACE INTO users (
          id, username, email, password_hash, salt, iterations,
          name, contact_no, permissions, company_id, status, is_active,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        userData['id'],
        userData['username'] ?? userData['email'],
        userData['email'],
        userData['passwordHash'] ?? '',
        userData['salt'] ?? '',
        userData['iterations'] ?? 10000,
        userData['name'] ?? '',
        userData['contact_no'] ?? '',
        userData['permissions'] != null ? jsonEncode(userData['permissions']) : null,
        userData['company_id'] ?? '',
        userData['status'] ?? 'active',
        userData['is_active'] ?? 1,
        userData['created_at'] ?? DateTime.now().toIso8601String(),
        userData['updated_at'] ?? DateTime.now().toIso8601String(),
      ]);

      debugPrint('OfflineFirstAuthService: User synced to local database');

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error syncing user to local DB: $e');
    }
  }

  static Future<void> _updatePasswordInLocalDb(
    String passwordHash,
    String salt,
    int iterations,
  ) async {
    try {
      final db = await AppDatabase.instance();
      
      await db.customStatement('''
        UPDATE users SET 
          password_hash = ?, 
          salt = ?, 
          iterations = ?, 
          updated_at = ?
        WHERE id = ?
      ''', [
        passwordHash,
        salt,
        iterations,
        DateTime.now().toIso8601String(),
        _currentUser!['id'],
      ]);

      debugPrint('OfflineFirstAuthService: Password updated in local database');

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error updating password in local DB: $e');
    }
  }

  static Future<void> _storePendingPasswordChange(String newPassword) async {
    try {
      final pendingChange = {
        'userId': _currentUser!['id'],
        'newPassword': newPassword,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _secureStorage.write(
        key: _pendingPasswordChangeKey,
        value: jsonEncode(pendingChange),
      );

      debugPrint('OfflineFirstAuthService: Pending password change stored');

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error storing pending password change: $e');
    }
  }

  static void _startConnectivityCheck() {
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = Timer.periodic(_connectivityCheckInterval, (_) async {
      await _checkConnectivity();
    });
    debugPrint('OfflineFirstAuthService: Started periodic connectivity check');
  }

  static Future<void> _checkConnectivity() async {
    try {
      final previousState = _isOnline;
      
      // Windows-safe HTTP ping check
      final response = await http.head(
        Uri.parse(_pingUrl),
      ).timeout(
        const Duration(seconds: 5),
      );
      
      _isOnline = response.statusCode >= 200 && response.statusCode < 300;
      
      if (previousState != _isOnline) {
        debugPrint('OfflineFirstAuthService: Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
        
        if (_isOnline) {
          debugPrint('OfflineFirstAuthService: Internet connectivity detected, checking for pending sync');
          _syncPendingChanges();
        }
      }
    } catch (e) {
      if (_isOnline) {
        debugPrint('OfflineFirstAuthService: Connectivity check failed: $e');
        _isOnline = false;
      }
    }
  }

  static Future<void> _syncPendingChanges() async {
    try {
      // Check for pending password change
      final pendingChangeJson = await _secureStorage.read(key: _pendingPasswordChangeKey);
      if (pendingChangeJson != null) {
        final pendingChange = jsonDecode(pendingChangeJson) as Map<String, dynamic>;
        await _syncPasswordChangeToFirebase(pendingChange);
      }

      // Update last sync timestamp
      await _secureStorage.write(
        key: _lastSyncKey,
        value: DateTime.now().toIso8601String(),
      );

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error syncing pending changes: $e');
    }
  }

  static Future<void> _syncPasswordChangeToFirebase(Map<String, dynamic> pendingChange) async {
    try {
      if (fb.FirebaseAuth.instance.currentUser == null) {
        debugPrint('OfflineFirstAuthService: No Firebase user, skipping password sync');
        return;
      }

      final newPassword = pendingChange['newPassword'] as String;
      
      // Update password in Firebase
      await fb.FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
      
      // Clear pending change
      await _secureStorage.delete(key: _pendingPasswordChangeKey);
      
      debugPrint('OfflineFirstAuthService: Password synced to Firebase successfully');

    } catch (e) {
      debugPrint('OfflineFirstAuthService: Error syncing password to Firebase: $e');
    }
  }

  static void _listenToFirebaseAuth() {
    _authSubscription = fb.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && _currentAuthState == AuthState.authenticated) {
        debugPrint('OfflineFirstAuthService: Firebase auth state updated, syncing user data');
        _syncPendingChanges();
      }
    });
  }

  static void _emitAuthState() {
    if (!_authStateController.isClosed) {
      _authStateController.add(_currentAuthState);
    }
  }

  static void _emitUserUpdate() {
    if (!_userController.isClosed) {
      _userController.add(_currentUser);
    }
  }

  static String _generateSalt() {
    final bytes = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64.encode(bytes);
  }

  static String _hashPassword(String password, String salt, int iterations) {
    final bytes = utf8.encode(password);
    final saltBytes = base64.decode(salt);
    
    var digest = Uint8List.fromList(bytes);
    for (int i = 0; i < iterations; i++) {
      final hmac = Hmac(sha256, saltBytes);
      digest = Uint8List.fromList(hmac.convert(digest).bytes);
    }
    
    return base64.encode(digest);
  }

  static String _mapFirebaseAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Invalid password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'User account disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Check your internet connection';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  static d.Variable _convertToVariable(dynamic value) {
    // Helper function to create Variables with proper constructor
    return d.Variable(value);
  }
}

// Enums and classes

enum AuthState {
  uninitialized,
  authenticated,
  unauthenticated,
}

class AuthResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? userData;

  AuthResult.success(this.userData) : success = true, error = null;
  AuthResult.failure(this.error) : success = false, userData = null;

  @override
  String toString() {
    return success ? 'AuthResult.success' : 'AuthResult.failure: $error';
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => 'AuthException: $message';
}
