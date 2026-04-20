// Stub implementation for non-web platforms
// This file provides empty implementations when running on mobile/desktop

import 'package:drift/drift.dart';

/// Stub WebDatabase class for non-web platforms
/// This will never be used on non-web platforms due to kIsWeb checks
class WebDatabase {
  final String name;
  
  WebDatabase(this.name);
  
  // This should never be called on non-web platforms
  QueryExecutor get executor {
    throw UnsupportedError('WebDatabase is only available on web platforms');
  }
}

/// Stub implementation for non-web platforms
QueryExecutor connectToWebDatabase(String name) {
  throw UnsupportedError('WebDatabase is only available on web platforms');
}
