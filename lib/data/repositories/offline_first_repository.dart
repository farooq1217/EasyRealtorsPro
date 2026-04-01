import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as d;
import 'package:shared/shared.dart';
import '../../core/services/network_sync_manager.dart';

// Import models from network_sync_manager to avoid duplicates
import '../../core/services/network_sync_manager.dart' show SyncOperation, SyncResult, SyncStatus, SyncStats;

/// Offline-First Repository Base Class
/// 
/// This repository implements a strict offline-first data flow:
/// 1. All reads and writes happen against local SQLite database first
/// 2. Changes are queued for background sync to Firebase
/// 3. Real-time updates are provided through local database streams
/// 4. Network sync happens automatically when connectivity is available
abstract class OfflineFirstRepository {
  final AppDatabase _database;
  final NetworkSyncManager _syncManager;
  
  OfflineFirstRepository(this._database) : _syncManager = NetworkSyncManager.instance;

  /// Get database instance
  AppDatabase get database => _database;

  /// Create a record (offline-first)
  Future<T> create<T>({
    required String tableName,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    try {
      debugPrint('OfflineFirstRepository: Creating record in $tableName');

      // Add metadata
      final enrichedData = Map<String, dynamic>.from(data);
      enrichedData['id'] = enrichedData['id'] ?? _generateId();
      enrichedData['created_at'] = DateTime.now().toIso8601String();
      enrichedData['updated_at'] = DateTime.now().toIso8601String();
      enrichedData['is_synced'] = 0; // Mark as not synced
      enrichedData['is_active'] = 1;

      // Insert into local database
      await _insertIntoDatabase(tableName, enrichedData);

      // Queue for sync
      await _syncManager.queueOperation(SyncOperation(
        tableName: tableName,
        recordId: enrichedData['id'],
        type: SyncOperationType.create,
        data: enrichedData,
      ));

      // Return created record
      return fromMap(enrichedData);

    } catch (e) {
      debugPrint('OfflineFirstRepository: Error creating record: $e');
      rethrow;
    }
  }

  /// Update a record (offline-first)
  Future<T> update<T>({
    required String tableName,
    required String recordId,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    try {
      debugPrint('OfflineFirstRepository: Updating record $recordId in $tableName');

      // Add metadata
      final enrichedData = Map<String, dynamic>.from(data);
      enrichedData['updated_at'] = DateTime.now().toIso8601String();
      enrichedData['is_synced'] = 0; // Mark as not synced

      // Update in local database
      await _updateInDatabase(tableName, recordId, enrichedData);

      // Get updated record
      final updatedRecord = await _getById(tableName, recordId);
      if (updatedRecord == null) {
        throw Exception('Record not found after update');
      }

      // Queue for sync
      await _syncManager.queueOperation(SyncOperation(
        tableName: tableName,
        recordId: recordId,
        type: SyncOperationType.update,
        data: enrichedData,
      ));

      return fromMap(updatedRecord);

    } catch (e) {
      debugPrint('OfflineFirstRepository: Error updating record: $e');
      rethrow;
    }
  }

  /// Delete a record (offline-first)
  Future<void> delete({
    required String tableName,
    required String recordId,
  }) async {
    try {
      debugPrint('OfflineFirstRepository: Deleting record $recordId from $tableName');

      // Soft delete in local database
      await _softDeleteInDatabase(tableName, recordId);

      // Queue for sync
      await _syncManager.queueOperation(SyncOperation(
        tableName: tableName,
        recordId: recordId,
        type: SyncOperationType.delete,
        data: {'deleted_at': DateTime.now().toIso8601String()},
      ));

    } catch (e) {
      debugPrint('OfflineFirstRepository: Error deleting record: $e');
      rethrow;
    }
  }

  /// Get record by ID (local-first)
  Future<Map<String, dynamic>?> getById(String tableName, String recordId) async {
    return await _getById(tableName, recordId);
  }

  /// Stream all records for a table (real-time local updates)
  Stream<List<Map<String, dynamic>>> watchAll(String tableName, {
    String? whereClause,
    List<d.Variable>? variables,
    String? orderBy,
    int? limit,
  }) {
    debugPrint('OfflineFirstRepository: Watching all records in $tableName');

    String query = 'SELECT * FROM $tableName WHERE is_active = 1';
    if (whereClause != null) {
      query += ' AND $whereClause';
    }
    if (orderBy != null) {
      query += ' ORDER BY $orderBy';
    }
    if (limit != null) {
      query += ' LIMIT $limit';
    }

    return _database
        .customSelect(query, variables: variables ?? [])
        .watch()
        .map((rows) => rows.map((row) => row.data).toList());
  }

  /// Stream filtered records (real-time local updates)
  Stream<List<Map<String, dynamic>>> watchFiltered(
    String tableName, {
    required String filterColumn,
    required String filterValue,
    String? orderBy,
    int? limit,
  }) {
    debugPrint('OfflineFirstRepository: Watching filtered records in $tableName');

    String query = 'SELECT * FROM $tableName WHERE is_active = 1 AND $filterColumn = ?';
    if (orderBy != null) {
      query += ' ORDER BY $orderBy';
    }
    if (limit != null) {
      query += ' LIMIT $limit';
    }
    
    return _database
        .customSelect(query, variables: [_convertToVariable(filterValue)])
        .watch()
        .map((rows) => rows.map((row) => row.data).toList());
  }

  /// Get all records (one-time query)
  Future<List<Map<String, dynamic>>> getAll(String tableName, {
    String? whereClause,
    List<d.Variable>? variables,
    String? orderBy,
    int? limit,
  }) async {
    debugPrint('OfflineFirstRepository: Getting all records from $tableName');

    String query = 'SELECT * FROM $tableName WHERE is_active = 1';
    if (whereClause != null) {
      query += ' AND $whereClause';
    }
    if (orderBy != null) {
      query += ' ORDER BY $orderBy';
    }
    if (limit != null) {
      query += ' LIMIT $limit';
    }

    final result = await _database.customSelect(
      query,
      variables: variables ?? [],
    ).get();

    return result.map((row) => row.data).toList();
  }

  /// Get filtered records (one-time query)
  Future<List<Map<String, dynamic>>> getFiltered(
    String tableName, {
    required String filterColumn,
    required String filterValue,
    String? orderBy,
    int? limit,
  }) async {
    debugPrint('OfflineFirstRepository: Getting filtered records from $tableName');

    String query = 'SELECT * FROM $tableName WHERE is_active = 1 AND $filterColumn = ?';
    if (orderBy != null) {
      query += ' ORDER BY $orderBy';
    }
    if (limit != null) {
      query += ' LIMIT $limit';
    }

    final result = await _database.customSelect(
      query,
      variables: [_convertToVariable(filterValue)],
    ).get();

    return result.map((row) => row.data).toList();
  }

  /// Get records by date (one-time query)
  Future<List<Map<String, dynamic>>> getRecordsByDate(
    String tableName, {
    required String dateColumn,
    required String currentDate,
    String? orderBy,
    int? limit,
  }) async {
    debugPrint('OfflineFirstRepository: Getting records by date from $tableName');

    String query = 'SELECT * FROM $tableName WHERE is_active = 1 AND $dateColumn = ?';
    if (orderBy != null) {
      query += ' ORDER BY $orderBy';
    }
    if (limit != null) {
      query += ' LIMIT $limit';
    }

    final result = await _database.customSelect(
      query,
      variables: [_convertToVariable(currentDate)],
    ).get();

    return result.map((row) => row.data).toList();
  }

  /// Force sync specific table
  Future<SyncResult> syncTable(String tableName) async {
    return await _syncManager.syncTable(tableName);
  }

  /// Force sync all data
  Future<SyncResult> syncAll() async {
    return await _syncManager.forceSyncAll();
  }

  /// Get sync status
  Future<SyncStatus> getSyncStatus() async {
    return Future.value(_syncManager.getCurrentStatus());
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats() async {
    return Future.value(_syncManager.getSyncStats());
  }

  // Private helper methods

  Future<void> _insertIntoDatabase(String tableName, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = List.filled(data.keys.length, '?').join(', ');
    final values = data.values.map((v) => _convertToVariable(v)).toList();

    await _database.customStatement(
      'INSERT INTO $tableName ($columns) VALUES ($placeholders)',
      values,
    );
  }

  Future<void> _updateInDatabase(String tableName, String recordId, Map<String, dynamic> data) async {
    final setClause = data.keys.map((key) => '$key = ?').join(', ');
    final values = [...data.values.map((v) => _convertToVariable(v)), _convertToVariable(recordId)];

    await _database.customStatement(
      'UPDATE $tableName SET $setClause WHERE id = ?',
      values,
    );
  }

  Future<void> _softDeleteInDatabase(String tableName, String recordId) async {
    await _database.customStatement(
      'UPDATE $tableName SET is_active = 0, updated_at = ? WHERE id = ?',
      [_convertToVariable(DateTime.now().toIso8601String()), _convertToVariable(recordId)],
    );
  }

  Future<Map<String, dynamic>?> _getById(String tableName, String recordId) async {
    final result = await _database.customSelect(
      'SELECT * FROM $tableName WHERE id = ? AND is_active = 1',
      variables: [_convertToVariable(recordId)],
    ).get();

    return result.isNotEmpty ? result.first.data : null;
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
    final random = DateTime.now().millisecondsSinceEpoch;
    String result = '';
    for (int i = 0; i < length; i++) {
      result += chars[(random + i) % chars.length];
    }
    return result;
  }
}

/// Specialized repository for Users
class OfflineFirstUserRepository extends OfflineFirstRepository {
  OfflineFirstUserRepository(super.database);

  /// Stream users by company
  Stream<List<Map<String, dynamic>>> watchUsersByCompany(String companyId) {
    return watchFiltered(
      'users',
      filterColumn: 'company_id',
      filterValue: companyId,
      orderBy: 'name ASC',
    );
  }

  /// Get users by company
  Future<List<Map<String, dynamic>>> getUsersByCompany(String companyId) async {
    return await getFiltered(
      'users',
      filterColumn: 'company_id',
      filterValue: companyId,
      orderBy: 'name ASC',
    );
  }

  /// Update user permissions
  Future<void> updateUserPermissions(String userId, Map<String, dynamic> permissions) async {
    await update(
      tableName: 'users',
      recordId: userId,
      data: {
        'permissions': jsonEncode(permissions),
      },
      fromMap: (data) => data,
    );
  }

  /// Update user status
  Future<void> updateUserStatus(String userId, String status) async {
    await update(
      tableName: 'users',
      recordId: userId,
      data: {'status': status},
      fromMap: (data) => data,
    );
  }
}

/// Specialized repository for Trading Entries
class OfflineFirstTradingRepository extends OfflineFirstRepository {
  OfflineFirstTradingRepository(super.database);

  /// Stream trading entries by agent
  Stream<List<Map<String, dynamic>>> watchEntriesByAgent(String agentId) {
    return watchFiltered(
      'trading_entries',
      filterColumn: 'created_by',
      filterValue: agentId,
      orderBy: 'created_at DESC',
    );
  }

  /// Stream trading entries by company
  Stream<List<Map<String, dynamic>>> watchEntriesByCompany(String companyId) {
    return watchFiltered(
      'trading_entries',
      filterColumn: 'company_id',
      filterValue: companyId,
      orderBy: 'created_at DESC',
    );
  }

  /// Update entry status
  Future<void> updateEntryStatus(String entryId, String status) async {
    await update(
      tableName: 'trading_entries',
      recordId: entryId,
      data: {'status': status},
      fromMap: (data) => data,
    );
  }

  /// Get entries by status
  Future<List<Map<String, dynamic>>> getEntriesByStatus(String status) async {
    return await getFiltered(
      'trading_entries',
      filterColumn: 'status',
      filterValue: status,
      orderBy: 'created_at DESC',
    );
  }
}

/// Specialized repository for Properties
class OfflineFirstPropertyRepository extends OfflineFirstRepository {
  OfflineFirstPropertyRepository(super.database);

  /// Stream properties by society
  Stream<List<Map<String, dynamic>>> watchPropertiesBySociety(String societyId) {
    return watchFiltered(
      'properties',
      filterColumn: 'society_id',
      filterValue: societyId,
      orderBy: 'created_at DESC',
    );
  }

  /// Stream properties by block
  Stream<List<Map<String, dynamic>>> watchPropertiesByBlock(String blockId) {
    return watchFiltered(
      'properties',
      filterColumn: 'block_id',
      filterValue: blockId,
      orderBy: 'created_at DESC',
    );
  }

  /// Update property status
  Future<void> updatePropertyStatus(String propertyId, String status) async {
    await update(
      tableName: 'properties',
      recordId: propertyId,
      data: {'sale_status': status},
      fromMap: (data) => data,
    );
  }

  /// Get properties by status
  Future<List<Map<String, dynamic>>> getPropertiesByStatus(String status) async {
    return await getFiltered(
      'properties',
      filterColumn: 'sale_status',
      filterValue: status,
      orderBy: 'created_at DESC',
    );
  }
}

/// Specialized repository for Reminders
class OfflineFirstReminderRepository extends OfflineFirstRepository {
  OfflineFirstReminderRepository(super.database);

  /// Stream reminders by agent
  Stream<List<Map<String, dynamic>>> watchRemindersByAgent(String agentId) {
    return watchFiltered(
      'reminders',
      filterColumn: 'agent_id',
      filterValue: agentId,
      orderBy: 'reminder_date ASC, reminder_time ASC',
    );
  }

  /// Stream reminders by date
  Stream<List<Map<String, dynamic>>> watchRemindersByDate(String date) {
    return watchFiltered(
      'reminders',
      filterColumn: 'reminder_date',
      filterValue: date,
      orderBy: 'reminder_time ASC',
    );
  }

  /// Update reminder status
  Future<void> updateReminderStatus(String reminderId, String status) async {
    await update(
      tableName: 'reminders',
      recordId: reminderId,
      data: {'notification_status': status},
      fromMap: (data) => data,
    );
  }

  /// Get pending reminders
  Future<List<Map<String, dynamic>>> getPendingReminders() async {
    final now = DateTime.now();
    final currentDate = now.toIso8601String().split('T')[0];
    final currentTime = now.toIso8601String().split('T')[1].substring(0, 5);

    final result = await database.customSelect('''
      SELECT * FROM reminders 
      WHERE is_active = 1 
      AND reminder_date <= ? 
      AND reminder_time <= ? 
      AND notification_status = 'pending'
      ORDER BY reminder_date ASC, reminder_time ASC
    ''', variables: [
      _convertToVariable(currentDate),
      _convertToVariable(currentTime),
    ]).get();

    return result.map((row) => row.data).toList();
  }
}
