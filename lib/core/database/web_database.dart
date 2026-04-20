import 'package:drift/drift.dart';
import 'package:drift/web.dart' as drift;
import 'package:shared/shared.dart' show AppDatabase;

/// Web database implementation using drift_web with IndexedDB
/// Provides persistent storage that survives page refreshes
class WebDatabaseImpl {
  static AppDatabase? _instance;
  static bool _initialized = false;

  /// Initialize web database
  static Future<void> initialize() async {
    if (_initialized) return;
    
    // Web initialization if needed
    _initialized = true;
  }

  /// Create and return web database connection using IndexedDB
  static QueryExecutor createDatabase() {
    return LazyDatabase(() async {
      // Initialize if needed
      await initialize();
      
      // Use WebDatabase with IndexedDB for persistence
      return drift.WebDatabase('easyrealtorspro_web');
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
