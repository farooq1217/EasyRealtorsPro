import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const int defaultIterations = 100000;
  static const int keyLength = 32;

  static String generateSalt([int length = 16]) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static List<int> _pbkdf2(String password, List<int> salt, int iterations, int length) {
    var hmac = Hmac(sha256, utf8.encode(password));
    var blocks = (length / hmac.convert([]).bytes.length).ceil();
    var output = <int>[];
    for (var block = 1; block <= blocks; block++) {
      var u = hmac.convert([...salt, ..._int32be(block)]).bytes;
      var t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.addAll(t);
    }
    return output.sublist(0, length);
  }

  static List<int> _int32be(int i) => [
        (i >> 24) & 0xff,
        (i >> 16) & 0xff,
        (i >> 8) & 0xff,
        i & 0xff,
      ];

  static String hash(String password, {String? salt, int iterations = defaultIterations}) {
    final s = salt ?? generateSalt();
    final key = _pbkdf2(password, base64Url.decode(s), iterations, keyLength);
    return '$iterations:$s:${base64UrlEncode(key)}';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 3) return false;
    final iters = int.tryParse(parts[0]);
    if (iters == null) return false;
    final salt = parts[1];
    final expected = parts[2];
    final key = _pbkdf2(password, base64Url.decode(salt), iters, keyLength);
    final actual = base64UrlEncode(key);
    return constantTimeEquals(utf8.encode(actual), utf8.encode(expected));
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    for (var i = 0; i < a.length && i < b.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
