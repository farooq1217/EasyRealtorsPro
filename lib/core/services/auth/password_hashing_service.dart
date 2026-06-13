import 'package:shared/shared.dart' show PasswordHasher;

class PasswordHashingService {
  /// Hashes a password using PBKDF2 from the shared package.
  String hashPassword(String password, {String? salt, int iterations = PasswordHasher.defaultIterations}) {
    return PasswordHasher.hash(password, salt: salt, iterations: iterations);
  }

  /// Verifies a password against a stored PBKDF2 hash.
  bool verifyPassword(String password, String storedHash) {
    return PasswordHasher.verify(password, storedHash);
  }

  /// Generates a random secure salt.
  String generateSalt([int length = 16]) {
    return PasswordHasher.generateSalt(length);
  }
}
