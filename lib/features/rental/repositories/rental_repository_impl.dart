import 'dart:async';
import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:firebase_core/firebase_core.dart';
import 'package:shared/shared.dart' show AppDatabase;
import '../../../core/services/firebase_threading_handler.dart';
import 'rental_repository.dart';

/// Implementation of RentalRepository using Drift/SQLite
class RentalRepositoryImpl implements RentalRepository {
  late final AppDatabase _database;

  // SQLite-only flag - disables all Firestore operations
  static const bool _sqliteOnlyMode = false;

  // Platform detection for thread safety
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  RentalRepositoryImpl([AppDatabase? database]) {
    _database = database ?? AppDatabase.instanceIfInitialized!;
  }

  // Helper method to wrap streams with platform thread safety
  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    if (_isWindows) {
      debugPrint('RentalRepository: Wrapping $streamName with Windows thread safety');
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'RentalRepository $streamName',
      );
    }
    return stream;
  }

  // Helper method to disable Firestore operations in SQLite-only mode
  bool _isFirestoreOperationAllowed() {
    return !_sqliteOnlyMode && Firebase.apps.isNotEmpty;
  }

  // Helper method to execute Firestore operations only if allowed
  Future<void> _executeFirestoreOperation(Future<void> Function() operation) async {
    if (_isFirestoreOperationAllowed()) {
      try {
        await operation();
      } catch (e) {
        debugPrint('Firestore operation failed (non-critical in SQLite-only mode): $e');
      }
    } else {
      debugPrint('Firestore operation skipped in SQLite-only mode');
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRentalItems({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
  }) {
    final stream = _database
        .customSelect(
          _buildQuery(
            companyId: companyId,
            createdBy: createdBy,
            searchQuery: searchQuery,
            statusFilter: statusFilter,
          ),
          variables: _buildQueryVariables(
            companyId: companyId,
            createdBy: createdBy,
            searchQuery: searchQuery,
            statusFilter: statusFilter,
          ),
          readsFrom: {_database.rentalItems},
        )
        .watch()
        .map((rows) => rows
            .map((row) => Map<String, dynamic>.from(row.data))
            .toList());
    
    // CRITICAL: Wrap stream with platform thread safety for Windows
    return _wrapStreamWithThreadSafety(stream, 'watchRentalItems');
  }

  @override
  Future<List<Map<String, dynamic>>> getRentalItems({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
  }) async {
    final result = await _database.customSelect(
      _buildQuery(
        companyId: companyId,
        createdBy: createdBy,
        searchQuery: searchQuery,
        statusFilter: statusFilter,
      ),
      variables: _buildQueryVariables(
        companyId: companyId,
        createdBy: createdBy,
        searchQuery: searchQuery,
        statusFilter: statusFilter,
      ),
      readsFrom: {_database.rentalItems},
    ).get();

    return result.map((row) => Map<String, dynamic>.from(row.data)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getRentalItemById(String id) async {
    final result = await _database.customSelect(
      'SELECT * FROM rental_items WHERE id = ? AND is_active = 1',
      variables: <d.Variable<Object>>[d.Variable.withString(id)],
      readsFrom: {_database.rentalItems},
    ).get();

    if (result.isEmpty) return null;
    return Map<String, dynamic>.from(result.first.data);
  }

  @override
  Future<String> addRentalItem(Map<String, dynamic> item) async {
    try {
      final id = item['id']?.toString() ?? _generateId();
      final now = DateTime.now().toIso8601String();

      await _database.customStatement(
        '''INSERT INTO rental_items 
           (id, created_by, name, location, owner_name, contact_no, cnic, 
            price, security, sale_status, remarks, company_id, is_active, updated_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          item['created_by'],
          item['name'],
          item['location'],
          item['owner_name'],
          item['contact_no'],
          item['cnic'],
          item['price'],
          item['security'],
          item['sale_status'],
          item['remarks'],
          item['company_id'],
          item['is_active'] ?? 1,
          now,
        ],
      );
      
      // Mark as unsynced for Firestore sync
      if (_isFirestoreOperationAllowed()) {
        await markRentalItemAsUnsynced(id);
      }
      
      return id;
    } catch (e) {
      debugPrint('Error adding rental item: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateRentalItem(Map<String, dynamic> item) async {
    final now = DateTime.now().toIso8601String();

    await _database.customStatement(
      '''UPDATE rental_items SET 
         created_by = ?, name = ?, location = ?, owner_name = ?, 
         contact_no = ?, cnic = ?, price = ?, security = ?, 
         sale_status = ?, remarks = ?, company_id = ?, 
         is_active = ?, updated_at = ? 
         WHERE id = ?''',
      [
        item['created_by'],
        item['name'],
        item['location'],
        item['owner_name'],
        item['contact_no'],
        item['cnic'],
        item['price'],
        item['security'],
        item['sale_status'],
        item['remarks'],
        item['company_id'],
        item['is_active'] ?? 1,
        now,
        item['id'],
      ],
    );

    if (_isFirestoreOperationAllowed()) {
      await markRentalItemAsUnsynced(item['id']);
    }
  }

  @override
  Future<void> updateRentalStatus(String id, RentalStatus status) async {
    final now = DateTime.now().toIso8601String();

    await _database.customStatement(
      'UPDATE rental_items SET sale_status = ?, updated_at = ? WHERE id = ?',
      [status.displayName, now, id],
    );

    if (_isFirestoreOperationAllowed()) {
      await markRentalItemAsUnsynced(id);
    }
  }

  @override
  Future<void> deleteRentalItem(String id) async {
    final now = DateTime.now().toIso8601String();

    await _database.customStatement(
      'UPDATE rental_items SET is_active = 0, updated_at = ? WHERE id = ?',
      [now, id],
    );

    if (_isFirestoreOperationAllowed()) {
      await markRentalItemAsUnsynced(id);
    }
  }

  @override
  Future<Map<RentalStatus, int>> getRentalStats(String? companyId) async {
    final result = await _database.customSelect(
      companyId != null
          ? 'SELECT sale_status, COUNT(*) as count FROM rental_items WHERE company_id = ? AND is_active = 1 GROUP BY sale_status'
          : 'SELECT sale_status, COUNT(*) as count FROM rental_items WHERE is_active = 1 GROUP BY sale_status',
      variables: companyId != null ? [d.Variable.withString(companyId)] : [],
      readsFrom: {_database.rentalItems},
    ).get();

    final stats = <RentalStatus, int>{};
    for (final row in result) {
      final status = RentalStatus.fromString(row.data['sale_status']?.toString());
      final count = int.tryParse(row.data['count']?.toString() ?? '0') ?? 0;
      stats[status] = count;
    }

    // Ensure all statuses are present in the map
    for (final status in RentalStatus.values) {
      stats[status] = stats[status] ?? 0;
    }

    return stats;
  }

  @override
  Future<List<Map<String, dynamic>>> searchRentalItems(String query, {
    String? companyId,
    String? createdBy,
    RentalStatus? statusFilter,
  }) {
    return getRentalItems(
      companyId: companyId,
      createdBy: createdBy,
      searchQuery: query,
      statusFilter: statusFilter,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getRentalItemsPaginated({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
    int page = 1,
    int limit = 20,
  }) async {
    final offset = (page - 1) * limit;
    final query = _buildQuery(
      companyId: companyId,
      createdBy: createdBy,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
      limit: limit,
      offset: offset,
    );

    final result = await _database.customSelect(
      query,
      variables: _buildQueryVariables(
        companyId: companyId,
        createdBy: createdBy,
        searchQuery: searchQuery,
        statusFilter: statusFilter,
      ),
      readsFrom: {_database.rentalItems},
    ).get();

    return result.map((row) => Map<String, dynamic>.from(row.data)).toList();
  }

  @override
  Future<bool> hasMoreRentalItems({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
    int currentPage = 1,
    int limit = 20,
  }) async {
    final offset = currentPage * limit;
    final query = _buildQuery(
      companyId: companyId,
      createdBy: createdBy,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
      limit: 1, // Only check if there's at least one more record
      offset: offset,
    );

    final result = await _database.customSelect(
      query,
      variables: _buildQueryVariables(
        companyId: companyId,
        createdBy: createdBy,
        searchQuery: searchQuery,
        statusFilter: statusFilter,
      ),
      readsFrom: {_database.rentalItems},
    ).get();

    return result.isNotEmpty;
  }

  /// Build SQL query with optional filters and pagination
  String _buildQuery({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
    int? limit,
    int? offset,
  }) {
    final clauses = <String>['is_active = 1'];
    
    if (companyId != null) {
      clauses.add('company_id = ?');
    }
    
    if (createdBy != null) {
      clauses.add('created_by = ?');
    }
    
    if (statusFilter != null) {
      clauses.add('sale_status = ?');
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      clauses.add('(name LIKE ? OR location LIKE ? OR owner_name LIKE ? OR remarks LIKE ? OR contact_no LIKE ?)');
    }

    final whereClause = 'WHERE ${clauses.join(' AND ')}';
    var query = '''
      SELECT id, created_by, name, price, remarks, location, owner_name, 
             contact_no, cnic, security, sale_status, company_id, updated_at 
      FROM rental_items 
      $whereClause 
      ORDER BY updated_at DESC
    ''';

    if (limit != null) {
      query += ' LIMIT $limit';
      if (offset != null) {
        query += ' OFFSET $offset';
      }
    }

    return query;
  }

  /// Build query variables list
  List<d.Variable<Object>> _buildQueryVariables({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
  }) {
    final variables = <d.Variable<Object>>[];
    
    if (companyId != null) {
      variables.add(d.Variable.withString(companyId));
    }
    
    if (createdBy != null) {
      variables.add(d.Variable.withString(createdBy));
    }
    
    if (statusFilter != null) {
      variables.add(d.Variable.withString(statusFilter.displayName));
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchPattern = '%$searchQuery%';
      variables.add(d.Variable.withString(searchPattern)); // name LIKE
      variables.add(d.Variable.withString(searchPattern)); // location LIKE
      variables.add(d.Variable.withString(searchPattern)); // owner_name LIKE
      variables.add(d.Variable.withString(searchPattern)); // remarks LIKE
      variables.add(d.Variable.withString(searchPattern)); // contact_no LIKE
    }

    return variables;
  }

  /// Generate unique ID for new rental items
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> markRentalItemAsUnsynced(String id) async {
    await _database.customStatement('''
      UPDATE rental_items SET is_synced = 0, updated_at = ? 
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), id]);
  }

  Future<void> markRentalItemAsSynced(String id) async {
    await _database.customStatement('''
      UPDATE rental_items SET is_synced = 1, updated_at = ? 
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), id]);
  }
}
