import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_repository.dart';
import 'jwt_service.dart';
import 'local_auth_storage.dart';

class AuthService extends ChangeNotifier {
  final AuthRepository _repository;
  final JwtService _jwt;
  final LocalAuthStorage _localStore;
  
  static AuthService? _instance;
  static AuthService get instance {
  if (_instance == null) {
    // Fallback: Create a minimal instance for static method calls
    // This should ONLY happen during early app startup
    debugPrint('AuthService: Creating fallback instance for static call');
    _instance = AuthService._fallback();
  }
  return _instance!;
}

// ✅ Private fallback constructor for early static calls
AuthService._fallback()
    : _repository = AuthRepository.fallback(),
      _jwt = JwtService(),
      _localStore = LocalAuthStorage() {
  _instance = this;
}

  // ✅ PUBLIC CONSTRUCTOR FOR PROVIDER
  AuthService({
    required AuthRepository repository,
    required JwtService jwt,
    required LocalAuthStorage localStore,
  })  : _repository = repository,
        _jwt = jwt,
        _localStore = localStore {
    _instance = this;
  }

  // 🔹 STATIC API (100% BACKWARD COMPATIBLE)
  static final ValueNotifier<Map<String, dynamic>?> currentUserNotifier = ValueNotifier(null);
  static Map<String, dynamic>? get currentUser => currentUserNotifier.value;
  static set currentUser(Map<String, dynamic>? value) {
    currentUserNotifier.value = value;
    _instance?.notifyListeners();
  }

  static final StreamController<Map<String, dynamic>?> _userStreamController = StreamController.broadcast();
  static Stream<Map<String, dynamic>?> get currentUserStream => _userStreamController.stream;

  // === DELEGATE TO INJECTED SERVICES ===
  
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String cnic,
  }) {
    if (_instance == null) {
      debugPrint('AuthService: Instance not ready, deferring register...');
      return Future.value({'success': false, 'message': 'AuthService initializing. Please wait.'});
    }
    return instance._repository.register(
      email: email, password: password, fullName: fullName, cnic: cnic,
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
    String? twoFactorCode,
  }) async {
    // At the VERY START of login():
    debugPrint('🔐 AuthService.login() CALLED for: $email');

    if (_instance == null) {
      debugPrint('AuthService: Instance not ready, deferring login...');
      return {'success': false, 'message': 'AuthService initializing. Please wait.'};
    }
    final res = await instance._repository.login(
      email: email, password: password, rememberMe: rememberMe, twoFactorCode: twoFactorCode,
    );
    
    if (res['success'] == true) {
      final u = res['user'] as Map<String, dynamic>? ?? {};
      debugPrint('✅ Password verified for: $email');
      debugPrint('👤 User object keys: ${u.keys.toList()}');
      debugPrint('🔑 User role: ${u['role']}');
      debugPrint('📦 User modules: ${u['modules']}');
      
      currentUser = u;
      if (!_userStreamController.isClosed) _userStreamController.add(currentUser);
      
      final token = res['token'] as String?;
      if (token != null) {
        final tokenPart = token.length >= 20 ? '${token.substring(0, 20)}...' : token;
        debugPrint('🎫 JWT token generated: $tokenPart');
      } else {
        debugPrint('🎫 JWT token generated: null');
      }
    } else {
      debugPrint('❌ Password verification FAILED for: $email');
    }

    // Before returning success:
    debugPrint('🚀 About to return login success for: $email');
    debugPrint('📊 AuthService.currentUser set: ${AuthService.currentUser != null}');
    debugPrint('📡 currentUserNotifier value: ${AuthService.currentUserNotifier.value?['email']}');

    return res;
  }

  static Future<void> logout(String? sessionId) async {
    if (_instance == null) return;
    await instance._repository.logout(sessionId);
    currentUser = null;
    clearUserCache();
  }

  static Future<bool> verifyToken(String? token) async {
    if (token == null || token.isEmpty) return false;
    if (_instance == null) return false;
    return instance._jwt.verifyToken(token);
  }

  static String generate2FASecret() {
    if (_instance == null) return '';
    return instance._repository.generate2FASecret();
  }

  static Future<Map<String, dynamic>> setup2FA(String email, String secret) {
    if (_instance == null) return Future.value({'success': false, 'message': 'AuthService initializing.'});
    return instance._repository.setup2FA(email, secret);
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) {
    if (_instance == null) return Future.value({'success': false, 'message': 'AuthService initializing.'});
    return instance._repository.requestPasswordReset(email);
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) {
    if (_instance == null) return Future.value({'success': false, 'message': 'AuthService initializing.'});
    return instance._repository.resetPassword(email, code, newPassword);
  }

  static Future<Map<String, dynamic>?> getCurrentUser(String? token, {bool waitForFirestore = false}) async {
    if (_instance == null) return null;
    final user = await instance._repository.getCurrentUser(token, waitForFirestore: waitForFirestore);
    if (user != null) {
      currentUser = user;
      if (!_userStreamController.isClosed) _userStreamController.add(user);
    }
    return user;
  }

  static void clearUserCache() {
    if (_instance == null) return;
    instance._repository.clearUserCache();
    currentUser = null;
  }

  static Future<void> revokeSession(String sessionId) {
    if (_instance == null) return Future.value();
    return instance._repository.revokeSession(sessionId);
  }

  static Future<void> triggerBackgroundSyncAfterLogin() {
    if (_instance == null) return Future.value();
    return instance._repository.triggerBackgroundSyncAfterLogin();
  }

  static Future<void> syncUserCacheFromDb({required dynamic db, required String userId}) {
    if (_instance == null) return Future.value();
    return instance._repository.syncUserCacheFromDb(userId: userId);
  }

  @override
  void dispose() {
    _userStreamController.close();
    super.dispose();
  }
}
