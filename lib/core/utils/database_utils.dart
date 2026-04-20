import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'platform_utils.dart';

/// Universal database configuration for cross-platform compatibility
class DatabaseUtils {
  /// Creates platform-specific database executor
  static Future<QueryExecutor> createExecutor() async {
    if (kIsWeb) {
      return _createWebExecutor();
    } else {
      return _createMobileDesktopExecutor();
    }
  }

  /// Creates web-compatible database executor
  static QueryExecutor _createWebExecutor() {
    // For web, use in-memory database for now
    // TODO: Implement proper IndexedDB persistence when needed
    return DatabaseConnection(NativeDatabase.memory());
  }

  /// Creates mobile/desktop database executor
  static Future<QueryExecutor> _createMobileDesktopExecutor() async {
    try {
      final dbPath = await PlatformUtils.getDatabasePath();
      final dbDir = io.Directory(dbPath);
      
      // Create database directory if it doesn't exist
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
      
      final dbFile = io.File(p.join(dbPath, 'easyrealtorspro.sqlite'));
      
      // Use native SQLite for mobile/desktop
      return NativeDatabase(dbFile, logStatements: true);
    } catch (e) {
      // Fallback to in-memory database if file system fails
      debugPrint('DatabaseUtils: Failed to create file database, using in-memory: $e');
      return DatabaseConnection(NativeDatabase.memory());
    }
  }

  /// Gets database file path for backup/restore operations
  static Future<String?> getDatabaseFilePath() async {
    if (kIsWeb) {
      // Web doesn't have direct file system access
      return null;
    }
    
    try {
      final dbPath = await PlatformUtils.getDatabasePath();
      return p.join(dbPath, 'easyrealtorspro.sqlite');
    } catch (e) {
      debugPrint('DatabaseUtils: Failed to get database file path: $e');
      return null;
    }
  }

  /// Creates database backup
  static Future<bool> createBackup(String backupPath) async {
    if (kIsWeb) {
      // Web backup handled differently (export to IndexedDB or download)
      return false;
    }
    
    try {
      final dbFilePath = await getDatabaseFilePath();
      if (dbFilePath == null) return false;
      
      final dbFile = io.File(dbFilePath);
      if (!await dbFile.exists()) return false;
      
      final backupFile = io.File(backupPath);
      await dbFile.copy(backupPath);
      return true;
    } catch (e) {
      debugPrint('DatabaseUtils: Backup failed: $e');
      return false;
    }
  }

  /// Restores database from backup
  static Future<bool> restoreFromBackup(String backupPath) async {
    if (kIsWeb) {
      // Web restore handled differently
      return false;
    }
    
    try {
      final backupFile = io.File(backupPath);
      if (!await backupFile.exists()) return false;
      
      final dbFilePath = await getDatabaseFilePath();
      if (dbFilePath == null) return false;
      
      final dbFile = io.File(dbFilePath);
      await backupFile.copy(dbFilePath);
      return true;
    } catch (e) {
      debugPrint('DatabaseUtils: Restore failed: $e');
      return false;
    }
  }

  /// Checks if database exists
  static Future<bool> databaseExists() async {
    if (kIsWeb) {
      // Web database always exists (in-memory or IndexedDB)
      return true;
    }
    
    try {
      final dbFilePath = await getDatabaseFilePath();
      if (dbFilePath == null) return false;
      
      final dbFile = io.File(dbFilePath);
      return await dbFile.exists();
    } catch (e) {
      debugPrint('DatabaseUtils: Failed to check database existence: $e');
      return false;
    }
  }

  /// Deletes database
  static Future<bool> deleteDatabase() async {
    if (kIsWeb) {
      // Web database deletion handled by drift_web
      return true;
    }
    
    try {
      final dbFilePath = await getDatabaseFilePath();
      if (dbFilePath == null) return false;
      
      final dbFile = io.File(dbFilePath);
      if (await dbFile.exists()) {
        await dbFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('DatabaseUtils: Failed to delete database: $e');
      return false;
    }
  }

  /// Gets database size in bytes
  static Future<int?> getDatabaseSize() async {
    if (kIsWeb) {
      // Web database size not directly accessible
      return null;
    }
    
    try {
      final dbFilePath = await getDatabaseFilePath();
      if (dbFilePath == null) return null;
      
      final dbFile = io.File(dbFilePath);
      if (await dbFile.exists()) {
        return await dbFile.length();
      }
      return 0;
    } catch (e) {
      debugPrint('DatabaseUtils: Failed to get database size: $e');
      return null;
    }
  }
}
