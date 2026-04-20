/// Database abstraction barrel file
/// Automatically selects the appropriate database implementation based on platform
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift/drift.dart';
import 'package:shared/shared.dart' show AppDatabase;

// Import both implementations
import 'native_database.dart';
import 'web_database.dart';

/// Abstract database interface that works on all platforms
abstract class DatabaseConnection {
  static AppDatabase? _instance;
  static bool _initialized = false;

  /// Initialize the appropriate database for the current platform
  static Future<void> initialize() async {
    if (_initialized) return;

    // Platform-specific initialization will be handled by the imported implementation
    _initialized = true;
  }

  /// Create and return the appropriate database connection
  static QueryExecutor createDatabase() {
    // Use runtime platform check to select the appropriate implementation
    if (kIsWeb) {
      return WebDatabaseImpl.createDatabase();
    } else {
      return NativeDatabase.createDatabase();
    }
  }

  /// Get singleton database instance
  static AppDatabase getInstance() {
    if (_instance == null) {
      _instance = AppDatabase(createDatabase());
    }
    return _instance!;
  }

  /// Close database connection
  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
