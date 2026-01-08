import 'package:googleapis/drive/v3.dart' as gdrive;
import 'drive_client.dart';

class DriveRetentionService {
  final DriveService drive;
  DriveRetentionService(this.drive);

  /// Enforce: keep files <= 90 days and <= 100 latest per module
  /// Applies to export_* per module and bootstrap_* groups.
  Future<List<gdrive.File>> enforceRetention(String folderId) async {
    final files = await drive.listFiles(folderId: folderId);
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 90));

    // Partition groups: modules by export_ prefix, and bootstrap groups
    final Map<String, List<gdrive.File>> groups = {};

    for (final f in files) {
      final name = f.name ?? '';
      String group;
      if (name.startsWith('export_')) {
        final module = DriveService.parseModuleFromExportName(name) ?? 'unknown';
        group = 'export:$module';
      } else if (name.startsWith('bootstrap_users_snapshot_')) {
        group = 'bootstrap:snapshot';
      } else if (name.startsWith('bootstrap_users_delta_')) {
        group = 'bootstrap:delta';
      } else if (name.startsWith('bootstrap_users_')) {
        group = 'bootstrap:init';
      } else {
        // ignore other files
        continue;
      }
      groups.putIfAbsent(group, () => []).add(f);
    }

    final toDelete = <gdrive.File>[];

    for (final entry in groups.entries) {
      final groupName = entry.key;
      final list = entry.value;

      // Sort by createdTime ascending
      list.sort((a, b) {
        final at = a.createdTime ?? a.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdTime ?? b.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return at.compareTo(bt);
      });

      // Age-based deletion
      for (final f in list) {
        final t = f.createdTime ?? f.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (t.isBefore(cutoff)) toDelete.add(f);
      }

      // Count-based: keep latest 100 per module/group
      final survivors = list.where((f) => !toDelete.contains(f)).toList();
      if (survivors.length > 100) {
        final extra = survivors.length - 100;
        toDelete.addAll(survivors.take(extra));
      }
    }

    // Delete flagged
    for (final f in toDelete) {
      await drive.deleteFile(fileId: f.id!);
    }

    return toDelete;
  }
}
