import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class JwtService {
  final String _secret;

  JwtService() : _secret = dotenv.env['JWT_SECRET'] ?? 'your-secret-key-change-in-production';

  Future<void> initialize() async {}

  String generateToken(String userId, String email, {bool rememberMe = false}) {
    final now = DateTime.now();
    final expiry = rememberMe ? now.add(const Duration(days: 7)) : now.add(const Duration(hours: 24));
    final payload = {
      'userId': userId, 'email': email,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
    };
    final header = base64Url.encode(utf8.encode(jsonEncode({'typ': 'JWT', 'alg': 'HS256'})));
    final payloadEncoded = base64Url.encode(utf8.encode(jsonEncode(payload)));
    final signature = _hmacSha256('$header.$payloadEncoded', _secret);
    return '$header.$payloadEncoded.$signature';
  }

  bool verifyToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final signature = _hmacSha256('${parts[0]}.${parts[1]}', _secret);
      if (parts[2] != signature) return false;
      final payloadJson = jsonDecode(utf8.decode(base64Url.decode(parts[1])));
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 < (payloadJson['exp'] as int);
    } catch (_) { return false; } // ✅ Fixed syntax
  }

  Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final decodedMap = jsonDecode(utf8.decode(base64Url.decode(parts[1])));
      if (decodedMap is Map) {
        return Map<String, dynamic>.from(decodedMap);
      }
      return null;
    } catch (_) { return null; } // ✅ Fixed syntax
  }

  String _hmacSha256(String data, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    return base64Url.encode(Hmac(sha256, key).convert(bytes).bytes);
  }
}
