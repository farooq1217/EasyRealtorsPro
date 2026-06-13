// Extension methods to expose Drift customStatement and customSelect on AppDatabase
import 'package:drift/drift.dart';
import 'package:shared/src/db/schema.dart';

extension AppDatabaseExtensions on AppDatabase {

  /// Executes a custom SQL statement.
  Future<void> customStatement(String sql, [List<dynamic>? args]) async {
    // Use the exposed executor from AppDatabase to run custom statements.
    await (this as DatabaseConnectionUser).customStatement(sql, args);
  }

  /// Performs a custom SELECT query and returns rows.
  Future<List<QueryRow>> customSelect(String sql, {List<Variable>? variables}) async {
    return await (this as DatabaseConnectionUser).customSelect(sql, variables: variables ?? []).get();
  }
}
