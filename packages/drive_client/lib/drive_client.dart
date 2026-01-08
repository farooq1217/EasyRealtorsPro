import 'dart:async';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class DriveService {
  final ClientId clientId;
  final List<String> scopes;
  AutoRefreshingAuthClient? _client;
  final http.Client Function()? _httpFactory;

  DriveService(this.clientId, {this.scopes = const [gdrive.DriveApi.driveFileScope], http.Client Function()? httpFactory})
      : _httpFactory = httpFactory;

  Future<void> signIn(AccessCredentials? stored) async {
    if (stored != null) {
      final base = _httpFactory?.call() ?? http.Client();
      _client = authenticatedClient(base, stored) as AutoRefreshingAuthClient;
      return;
    }
    throw StateError('Interactive sign-in not implemented here');
  }

  /// Interactive sign-in using user consent. Provide a callback to open the auth URL to the user.
  Future<AccessCredentials> signInInteractive(void Function(Uri authUrl) openUrl) async {
    final base = _httpFactory?.call() ?? http.Client();
    final creds = await obtainAccessCredentialsViaUserConsent(
      clientId,
      scopes,
      base,
      (String url) => openUrl(Uri.parse(url)),
    );
    _client = authenticatedClient(base, creds) as AutoRefreshingAuthClient;
    return creds;
  }

  AccessCredentials? get credentials => _client?.credentials;

  Future<List<gdrive.File>> listFiles({required String folderId, String? q, int pageSize = 100}) async {
    final api = gdrive.DriveApi(_client!);
    final query = [
      "'$folderId' in parents",
      "trashed = false",
      if (q != null) q,
    ].join(' and ');
    final result = await api.files.list(q: query, spaces: 'drive', pageSize: pageSize, $fields: 'files(id,name,createdTime,modifiedTime,mimeType,size)');
    return result.files ?? <gdrive.File>[];
  }

  Future<gdrive.File> uploadFile({required String folderId, required String name, required List<int> bytes, String mimeType = 'text/csv'}) async {
    final api = gdrive.DriveApi(_client!);
    final file = gdrive.File()
      ..name = name
      ..parents = [folderId]
      ..mimeType = mimeType;
    final media = gdrive.Media(Stream.value(bytes), bytes.length, contentType: mimeType);
    return await api.files.create(file, uploadMedia: media, $fields: 'id,name');
  }

  Future<List<int>> downloadFile({required String fileId}) async {
    final api = gdrive.DriveApi(_client!);
    final media = await api.files.get(fileId, downloadOptions: gdrive.DownloadOptions.fullMedia) as gdrive.Media;
    final bytes = await media.stream.fold<List<int>>(<int>[], (p, e) { p.addAll(e); return p; });
    return bytes;
  }

  Future<void> deleteFile({required String fileId}) async {
    final api = gdrive.DriveApi(_client!);
    await api.files.delete(fileId);
  }

  static String? parseModuleFromExportName(String? name) {
    // export_<module>_<YYYYMMDD_HHMMSS>_<exportId>.csv
    if (name == null) return null;
    if (!name.startsWith('export_')) return null;
    final parts = name.split('_');
    if (parts.length < 4) return null;
    return parts[1];
  }

  Future<List<gdrive.File>> listFolders({String? nameContains, int pageSize = 100}) async {
    final api = gdrive.DriveApi(_client!);
    final queryParts = [
      "mimeType = 'application/vnd.google-apps.folder'",
      "trashed = false",
      if (nameContains != null) "name contains '${nameContains.replaceAll("'", "\\'")}'",
    ];
    final result = await api.files.list(q: queryParts.join(' and '), spaces: 'drive', pageSize: pageSize, $fields: 'files(id,name)');
    return result.files ?? <gdrive.File>[];
  }

  Future<gdrive.File> createFolder({required String name, String? parentId}) async {
    final api = gdrive.DriveApi(_client!);
    final file = gdrive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = parentId == null ? null : [parentId];
    return await api.files.create(file, $fields: 'id,name');
  }

  Future<gdrive.File?> getFile(String id) async {
    final api = gdrive.DriveApi(_client!);
    try {
      return await api.files.get(id, $fields: 'id,name,mimeType,trashed,createdTime,modifiedTime') as gdrive.File;
    } catch (_) {
      return null;
    }
  }
}

