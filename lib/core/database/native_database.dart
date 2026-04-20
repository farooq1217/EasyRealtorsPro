import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared/shared.dart' show AppDatabase;

/// Native database implementation for Windows/Desktop platforms
/// Uses sqlite3 with native FFI for optimal performance
class NativeDatabase {
  static AppDatabase? _instance;
  static bool _initialized = false;

  /// Initialize native database with sqlite3
  static Future<void> initialize() async {
    if (_initialized) return;
    
    // Platform-specific initialization if needed
    // Note: sqlite3_flutter_libs not available, using basic initialization
    _initialized = true;
  }

  /// Create and return native database connection
  static QueryExecutor createDatabase() {
    return LazyDatabase(() async {
      // Initialize if needed
      await initialize();
      
      // Get application documents directory
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'easyrealtorspro.db'));
      
      // Use drift's NativeDatabase constructor
      return drift.NativeDatabase(file);
    });
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
