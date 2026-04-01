import 'dart:async';
import 'package:drift/drift.dart' as d;
import 'package:shared/shared.dart';
import '../../core/services/network_sync_manager.dart' show SyncOperation, SyncOperationType;

/// Simplified Offline-First Repository
/// 
/// This repository implements a basic offline-first data flow
/// without complex sync operations for now.
abstract class OfflineFirstRepositorySimple {
  final AppDatabase _database;
  
  OfflineFirstRepositorySimple(this._database);
  
  /// Create a record locally and queue for sync
  Future<T> create<T>({
    required String tableName,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    // Add metadata
    final enrichedData = Map<String, dynamic>.from(data);
    enrichedData['id'] = _generateId();
    enrichedData['created_at'] = DateTime.now().toIso8601String();
    enrichedData['updated_at'] = DateTime.now().toIso8601String();
    enrichedData['is_synced'] = 0; // Mark as not synced
    
    // Insert into local database
    await _insertIntoDatabase(tableName, enrichedData);
    
    // Get created record
    final createdRecord = await getById<T>(
      tableName: tableName,
      recordId: enrichedData['id'],
      fromMap: fromMap,
    );
    
    return createdRecord ?? fromMap({});
  }
  
  /// Update a record locally and queue for sync
  Future<void> update({
    required String tableName,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    final updateData = Map<String, dynamic>.from(data);
    updateData['updated_at'] = DateTime.now().toIso8601String();
    updateData['is_synced'] = 0; // Mark as not synced
    
    await _updateInDatabase(tableName, recordId, updateData);
  }
  
  /// Delete a record locally and queue for sync
  Future<void> delete({
    required String tableName,
    required String recordId,
  }) async {
    await _softDeleteInDatabase(tableName, recordId);
  }
  
  /// Get a record by ID
  Future<T?> getById<T>({
    required String tableName,
    required String recordId,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    final result = await _database.customSelect(
      'SELECT * FROM $tableName WHERE id = ? AND is_active = 1',
      variables: [_convertToVariable(recordId)],
    ).get();
    
    return result.isNotEmpty ? fromMap(result.first.data) : null;
  }
  
  /// Watch all records for real-time updates
  Stream<List<T>> watchAll<T>({
    required String tableName,
    required T Function(Map<String, dynamic>) fromMap,
    String orderBy = 'created_at DESC',
  }) {
    return _database
        .customSelect('SELECT * FROM $tableName WHERE is_active = 1 ORDER BY $orderBy')
        .watch()
        .map((rows) => rows.map((row) => fromMap(row.data)).toList());
  }
  
  /// Get all records
  Future<List<T>> getAll<T>({
    required String tableName,
    required T Function(Map<String, dynamic>) fromMap,
    String orderBy = 'created_at DESC',
  }) async {
    final result = await _database.customSelect(
      'SELECT * FROM $tableName WHERE is_active = 1 ORDER BY $orderBy',
    ).get();
    
    return result.map((row) => fromMap(row.data)).toList();
  }
  
  // Private helper methods
  
  Future<void> _insertIntoDatabase(String tableName, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    final values = data.values.toList();
    
    await _database.customStatement(
      'INSERT INTO $tableName ($columns) VALUES ($placeholders)',
      values.map((v) => _convertToVariable(v)).toList(),
    );
  }
  
  Future<void> _updateInDatabase(String tableName, String recordId, Map<String, dynamic> data) async {
    final setClause = data.keys.map((key) => '$key = ?').join(', ');
    final values = [...data.values, recordId];
    
    await _database.customStatement(
      'UPDATE $tableName SET $setClause WHERE id = ?',
      [...data.values.map((v) => _convertToVariable(v)).toList(), _convertToVariable(recordId)],
    );
  }
  
  Future<void> _softDeleteInDatabase(String tableName, String recordId) async {
    await _database.customStatement(
      'UPDATE $tableName SET is_active = 0, updated_at = ? WHERE id = ?',
      [_convertToVariable(DateTime.now().toIso8601String()), _convertToVariable(recordId)],
    );
  }
  
  d.Variable _convertToVariable(dynamic value) {
    // Helper function to create Variables with proper constructor
    return d.Variable(value);
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           _randomString(8);
  }
  
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecond;
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random % chars.length)),
    );
  }
}

/// User Repository Implementation
class UserRepositorySimple extends OfflineFirstRepositorySimple {
  UserRepositorySimple(AppDatabase database) : super(database);
  
  Future<Map<String, dynamic>?> createUser(Map<String, dynamic> userData) async {
    return await create(
      tableName: 'users',
      data: userData,
      fromMap: (data) => data,
    );
  }
  
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    return await getById(
      tableName: 'users',
      recordId: userId,
      fromMap: (data) => data,
    );
  }
  
  Stream<List<Map<String, dynamic>>> watchAllUsers() {
    return watchAll(
      tableName: 'users',
      fromMap: (data) => data,
    );
  }
}

/// Trading Entry Repository Implementation
class TradingRepositorySimple extends OfflineFirstRepositorySimple {
  TradingRepositorySimple(AppDatabase database) : super(database);
  
  Future<Map<String, dynamic>?> createEntry(Map<String, dynamic> entryData) async {
    return await create(
      tableName: 'trading_entries',
      data: entryData,
      fromMap: (data) => data,
    );
  }
  
  Future<void> updateEntry(String entryId, Map<String, dynamic> updateData) async {
    await update(
      tableName: 'trading_entries',
      recordId: entryId,
      data: updateData,
    );
  }
  
  Future<void> deleteEntry(String entryId) async {
    await delete(
      tableName: 'trading_entries',
      recordId: entryId,
    );
  }
  
  Stream<List<Map<String, dynamic>>> watchAllEntries() {
    return watchAll(
      tableName: 'trading_entries',
      fromMap: (data) => data,
    );
  }
}
