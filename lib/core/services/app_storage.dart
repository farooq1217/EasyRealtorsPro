import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:drive_client/credentials.dart' show CredentialsCodec;
import 'package:googleapis_auth/googleapis_auth.dart' show AccessCredentials;
import 'package:path_provider/path_provider.dart';

class AppStorage {
  static const _credsFile = 'oauth_tokens.json';
  static const _folderFile = 'drive_folder_id.txt';
  static const _exportFile = 'export_state.json';
  static const _settingsFile = 'settings.json';

  Future<io.Directory> _appDir() async {
    if (kIsWeb) {
      throw UnsupportedError('AppStorage not supported on web');
    }
    final dir = await getApplicationSupportDirectory();
    final app = io.Directory('${dir.path}${io.Platform.pathSeparator}desktop_admin');
    if (!await app.exists()) await app.create(recursive: true);
    return app;
  }

  Future<io.Directory> appDir() => _appDir();

  Future<Map<String, dynamic>> _readExportState() async {
    if (kIsWeb) return {};
    final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_exportFile');
    if (!await file.exists()) return {};
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeExportState(Map<String, dynamic> s) async {
    if (kIsWeb) return;
    final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_exportFile');
    await file.writeAsString(jsonEncode(s));
  }

  Future<String?> readLastExportTs(String module) async {
    final s = await _readExportState();
    final rawLast = s['last'];
    if (rawLast is Map) {
      final m = Map<String, dynamic>.from(rawLast);
      return m[module] as String?;
    }
    return null;
  }

  Future<void> writeLastExportTs(String module, String ts) async {
    final s = await _readExportState();
    final rawLast = s['last'];
    final Map<String, dynamic> m = rawLast is Map ? Map<String, dynamic>.from(rawLast) : {};
    m[module] = ts;
    s['last'] = m;
    await _writeExportState(s);
  }

  Future<int> nextExportId(String module) async {
    final s = await _readExportState();
    final rawSeq = s['seq'];
    final Map<String, dynamic> m = rawSeq is Map ? Map<String, dynamic>.from(rawSeq) : {};
    final v = ((m[module] as int?) ?? 0) + 1;
    m[module] = v;
    s['seq'] = m;
    await _writeExportState(s);
    return v;
  }

  Future<int?> readNavIndex() async {
    final s = await _readExportState();
    final v = s['navIndex'];
    if (v is int) return v;
    return null;
  }

  Future<void> writeNavIndex(int index) async {
    final s = await _readExportState();
    s['navIndex'] = index;
    await _writeExportState(s);
  }

  Future<AccessCredentials?> readCredentials() async {
    if (kIsWeb) return null;
    try {
      final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_credsFile');
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      return CredentialsCodec.decode(text);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCredentials(AccessCredentials creds) async {
    if (kIsWeb) return;
    final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_credsFile');
    await file.writeAsString(CredentialsCodec.encode(creds));
  }

  Future<void> deleteCredentials() async {
    if (kIsWeb) return;
    final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_credsFile');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> readFolderId() async {
    if (kIsWeb) return null;
    try {
      final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_folderFile');
      if (!await file.exists()) return null;
      return (await file.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeFolderId(String id) async {
    if (kIsWeb) return;
    final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_folderFile');
    await file.writeAsString(id);
  }

  Future<void> deleteFolderId() async {
    if (kIsWeb) return;
    final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_folderFile');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Map<String, dynamic>> readSettings() async {
    if (kIsWeb) return {};
    try {
      final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_settingsFile');
      if (!await file.exists()) return {};
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> writeSettings(Map<String, dynamic> s) async {
    if (kIsWeb) return;
    final file = io.File('${(await _appDir()).path}${io.Platform.pathSeparator}$_settingsFile');
    await file.writeAsString(jsonEncode(s));
  }
}

