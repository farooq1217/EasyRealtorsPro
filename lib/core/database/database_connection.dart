import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:drift/drift.dart';
import 'package:shared/shared.dart' show AppDatabase;
import 'database_stub.dart' as db_stub;
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'package:path_provider/path_provider.dart';

/// Universal database connection class for cross-platform Drift/SQLite support
/// 
/// This class handles database initialization across:
/// - Mobile (Android/iOS): Uses SQLite with native FFI
/// - Desktop (Windows/macOS/Linux): Uses SQLite with native FFI  
/// - Web: Uses WebDatabase with IndexedDB persistence
/// 
/// Uses the abstracted database layer for platform-specific implementations
class DatabaseConnection {
  static DatabaseConnection? _instance;
  static AppDatabase? _database;
  
  /// Singleton instance
  static DatabaseConnection get instance {
    _instance ??= DatabaseConnection._internal();
    return _instance!;
  }
  
  DatabaseConnection._internal();
  
  /// Initialize database connection for the current platform
  Future<AppDatabase> initialize() async {
    if (_database != null) {
      return _database!;
    }
    
    // Use the abstracted database connection
    await db_stub.DatabaseConnection.initialize();
    _database = db_stub.DatabaseConnection.getInstance();
    return _database!;
  }
  
  /// Get the initialized database instance
  AppDatabase get database {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }
  
  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      await db_stub.DatabaseConnection.close();
      debugPrint('DatabaseConnection: Database closed');
    }
  }
  
  /// Reset database (delete and recreate)
  Future<void> reset() async {
    await close();
    
    if (!kIsWeb) {
      try {
        final databaseDirectory = await _getDatabaseDirectory();
        final databaseFile = io.File('${databaseDirectory.path}/easyrealtorspro.sqlite');
        
        if (await databaseFile.exists()) {
          await databaseFile.delete();
          debugPrint('DatabaseConnection: Database file deleted');
        }
      } catch (e) {
        debugPrint('DatabaseConnection: Failed to delete database file: $e');
      }
    } else {
      debugPrint('DatabaseConnection: Web database reset (cleared from IndexedDB)');
    }
    
    // Reinitialize
    await initialize();
  }
  
  /// Check if database exists
  Future<bool> exists() async {
    if (kIsWeb) {
      // Web database exists in IndexedDB
      return _database != null;
    } else {
      try {
        final databaseDirectory = await _getDatabaseDirectory();
        final databaseFile = io.File('${databaseDirectory.path}/easyrealtorspro.sqlite');
        return await databaseFile.exists();
      } catch (e) {
        debugPrint('DatabaseConnection: Failed to check database existence: $e');
        return false;
      }
    }
  }
  
  /// Get database file path (null for web)
  Future<String?> getDatabasePath() async {
    if (kIsWeb) {
      return null; // Web doesn't have file paths
    }
    
    try {
      final databaseDirectory = await _getDatabaseDirectory();
      return '${databaseDirectory.path}/easyrealtorspro.sqlite';
    } catch (e) {
      debugPrint('DatabaseConnection: Failed to get database path: $e');
      return null;
    }
  }
  
  /// Get database size in bytes (null for web)
  Future<int?> getDatabaseSize() async {
    if (kIsWeb) {
      return null; // Web database size not directly accessible
    }
    
    try {
      final databasePath = await getDatabasePath();
      if (databasePath == null) return null;
      
      final databaseFile = io.File(databasePath);
      if (!await databaseFile.exists()) return 0;
      
      return await databaseFile.length();
    } catch (e) {
      debugPrint('DatabaseConnection: Failed to get database size: $e');
      return null;
    }
  }
  
  /// Create database backup
  Future<bool> createBackup(String backupPath) async {
    if (kIsWeb) {
      debugPrint('DatabaseConnection: Backup not supported on web');
      return false;
    }
    
    try {
      final databasePath = await getDatabasePath();
      if (databasePath == null) return false;
      
      final databaseFile = io.File(databasePath);
      if (!await databaseFile.exists()) return false;
      
      final backupFile = io.File(backupPath);
      await databaseFile.copy(backupPath);
      
      debugPrint('DatabaseConnection: Backup created at $backupPath');
      return true;
    } catch (e) {
      debugPrint('DatabaseConnection: Failed to create backup: $e');
      return false;
    }
  }
  
  /// Restore database from backup
  Future<bool> restoreFromBackup(String backupPath) async {
    if (kIsWeb) {
      debugPrint('DatabaseConnection: Restore not supported on web');
      return false;
    }
    
    try {
      final backupFile = io.File(backupPath);
      if (!await backupFile.exists()) return false;
      
      final databasePath = await getDatabasePath();
      if (databasePath == null) return false;
      
      await close(); // Close database before restore
      await backupFile.copy(databasePath);
      
      debugPrint('DatabaseConnection: Database restored from $backupPath');
      return true;
    } catch (e) {
      debugPrint('DatabaseConnection: Failed to restore from backup: $e');
      return false;
    }
  }
  
  /// Get platform-appropriate database directory (only for native platforms)
  Future<io.Directory> _getDatabaseDirectory() async {
    try {
      if (io.Platform.isAndroid || io.Platform.isIOS) {
        // Mobile: Use ApplicationDocumentsDirectory
        final directory = await getApplicationDocumentsDirectory();
        return io.Directory('${directory.path}/databases');
      } else {
        // Desktop (Windows/macOS/Linux): Use ApplicationSupportDirectory
        final directory = await getApplicationSupportDirectory();
        return io.Directory('${directory.path}/databases');
      }
    } catch (e) {
      debugPrint('DatabaseConnection: Failed to get database directory: $e');
      // Fallback to temporary directory
      final tempDir = await getTemporaryDirectory();
      return io.Directory('${tempDir.path}/databases');
    }
  }
}


/// Extension to add WebDatabase support for web builds
extension WebDatabaseExtension on DatabaseConnection {
  /// Check if running on web platform
  bool get isWeb => kIsWeb;
  
  /// Get web database type information
  String get webDatabaseType {
    if (!kIsWeb) return 'Not a web platform';
    return 'IndexedDB (WebDatabase)';
  }
}
