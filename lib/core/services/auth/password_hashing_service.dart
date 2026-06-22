import 'dart:convert';
import 'dart:math';
import 'package:shared/shared.dart' show PasswordHasher;
import 'package:flutter/foundation.dart';

class PasswordHashingService {
  /// Hashes a password using PBKDF2 from the shared package.
  String hashPassword(String password, {String? salt, int iterations = PasswordHasher.defaultIterations}) {
    try {
      final actualSalt = salt ?? generateSalt();
      return PasswordHasher.hash(password, salt: actualSalt, iterations: iterations);
    } catch (e) {
      debugPrint('❌ PasswordHashingService: Error hashing password: $e');
      rethrow;
    }
  }

  /// Verifies a password against a stored PBKDF2 hash.
  bool verifyPassword(String password, String storedHash) {
    try {
      if (!_isValidHashFormat(storedHash)) {
        debugPrint('⚠️ PasswordHashingService: Invalid hash format detected');
        return false;
      }
      
      return PasswordHasher.verify(password, storedHash);
    } on FormatException catch (e) {
      debugPrint('⚠️ PasswordHashingService: FormatException during password verification: $e');
      return false;
    } catch (e) {
      debugPrint('❌ PasswordHashingService: Unexpected error during password verification: $e');
      return false;
    }
  }

  /// Generates a random secure salt (Base64 encoded).
  String generateSalt([int length = 16]) {
    try {
      return PasswordHasher.generateSalt(length);
    } catch (e) {
      debugPrint('⚠️ PasswordHashingService: Error generating salt, using fallback: $e');
      return _generateBase64Salt(length);
    }
  }

  /// Validates if hash format is correct (iterations:salt:hash)
  bool _isValidHashFormat(String hash) {
    try {
      final parts = hash.split(':');
      if (parts.length != 3) {
        return false;
      }
      
      final iterations = int.tryParse(parts[0]);
      if (iterations == null || iterations <= 0) {
        return false;
      }
      
      final salt = parts[1];
      final hashValue = parts[2];
      
      if (salt.isEmpty || hashValue.isEmpty) {
        return false;
      }
      
      // Validate Base64 length (must be multiple of 4)
      if (salt.length % 4 != 0 || hashValue.length % 4 != 0) {
        debugPrint('⚠️ PasswordHashingService: Base64 length validation failed');
        debugPrint('⚠️ Salt length: ${salt.length}, Hash length: ${hashValue.length}');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('⚠️ PasswordHashingService: Error validating hash format: $e');
      return false;
    }
  }

  /// Checks if a stored hash needs to be rehashed
  bool needsRehash(String storedHash) {
    return !_isValidHashFormat(storedHash);
  }

  /// Fallback: Generate proper Base64 salt
  String _generateBase64Salt(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }
}