import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalAuthStorage {
  static const String _usersFile = 'users.json';
  static const String _sessionsFile = 'sessions.json';
  static const String _resetCodesFile = 'reset_codes.json';

  Future<Directory> _getAuthDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/auth_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Map<String, dynamic>> readUsers() async {
    final dir = await _getAuthDir();
    final file = File('${dir.path}/$_usersFile');
    if (!await file.exists()) { await file.create(); await file.writeAsString('{}'); return {}; }
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return {};
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (_) { return {}; } // ✅ Fixed syntax
  }

  Future<void> writeUsers(Map<String, dynamic> users) async {
    final dir = await _getAuthDir();
    await File('${dir.path}/$_usersFile').writeAsString(jsonEncode(users));
  }

  Future<Map<String, dynamic>> readSessions() async {
    final dir = await _getAuthDir();
    final file = File('${dir.path}/$_sessionsFile');
    if (!await file.exists()) return {};
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return {};
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (_) { return {}; } // ✅ Fixed syntax
  }

  Future<void> writeSessions(Map<String, dynamic> sessions) async {
    final dir = await _getAuthDir();
    await File('${dir.path}/$_sessionsFile').writeAsString(jsonEncode(sessions));
  }

  Future<void> deleteFile(String fileName) async {
    final dir = await _getAuthDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) await file.delete();
  }
}
