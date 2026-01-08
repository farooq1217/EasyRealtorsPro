import 'dart:convert';
import 'package:googleapis_auth/googleapis_auth.dart';

class CredentialsCodec {
  static Map<String, dynamic> toJson(AccessCredentials c) => {
        'accessToken': {
          'type': c.accessToken.type,
          'data': c.accessToken.data,
          'expiry': c.accessToken.expiry.toIso8601String(),
        },
        'refreshToken': c.refreshToken,
        'idToken': c.idToken,
        'scopes': c.scopes,
      };

  static AccessCredentials fromJson(Map<String, dynamic> j) {
    final at = j['accessToken'] as Map<String, dynamic>;
    return AccessCredentials(
      AccessToken(
        at['type'] as String,
        at['data'] as String,
        DateTime.parse(at['expiry'] as String),
      ),
      j['refreshToken'] as String?,
      (j['scopes'] as List).cast<String>(),
      idToken: j['idToken'] as String?,
    );
  }

  static String encode(AccessCredentials c) => jsonEncode(toJson(c));
  static AccessCredentials decode(String s) => fromJson(jsonDecode(s) as Map<String, dynamic>);
}
