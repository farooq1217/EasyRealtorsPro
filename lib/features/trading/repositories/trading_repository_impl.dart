// data/repositories/trading_repository_impl.dart
import 'dart:async';
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import 'trading_repository.dart';
import 'package:shared/shared.dart';
import '../../../core/services/sync_database_helper.dart';
import '../../../firestore_sync_service.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/app_utils.dart';
import '../../../core/services/firebase_threading_handler.dart';

class AlreadyDeletedException implements Exception {
  final String message;
  AlreadyDeletedException(this.message);
  
  @override
  String toString() => message;
}

class TradingRepositoryImpl implements TradingRepository {
  final AppDatabase db;
  final SyncDatabaseHelper _syncHelper = SyncDatabaseHelper();
  final FirestoreSyncService _firestoreSync = FirestoreSyncService();
  
  // SQLite-only flag - disables all Firestore operations
  static const bool _sqliteOnlyMode = true;

  // Platform detection for thread safety
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  TradingRepositoryImpl(this.db);

  // Helper method to wrap streams with platform thread safety
  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    if (_isWindows) {
      debugPrint('TradingRepository: Wrapping $streamName with Windows thread safety');
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'TradingRepository $streamName',
      );
    }
    return stream;
  }

  // Helper method to disable Firestore operations in SQLite-only mode
  bool _isFirestoreOperationAllowed() {
    return !_sqliteOnlyMode;
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
  Future<List<TradingEntry>> getAllEntries({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 $whereClause
        ORDER BY date DESC
      ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error loading trading entries: $e');
      return [];
    }
  }

  @override
  Future<List<TradingEntry>> getEntriesByType(String entryType, {String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = [
        d.Variable.withString(entryType),
        if (companyId != null) d.Variable.withString(companyId),
      ];
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 AND entry_type = ? $whereClause
        ORDER BY date DESC
      ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error loading trading entries by type: $e');
      return [];
    }
  }

  @override
  Future<TradingEntry?> getEntryById(String id) async {
    try {
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 AND id = ?
      ''', variables: [d.Variable.withString(id)]).get();
      
      if (results.isEmpty) return null;
      return _mapRowToTradingEntry(results.first.data);
    } catch (e) {
      debugPrint('Error loading trading entry by ID: $e');
      return null;
    }
  }

  @override
  Stream<List<TradingEntry>> watchEntries({String? companyId}) {
    final whereClause = companyId != null ? 'AND company_id = ?' : '';
    final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
    
    final stream = db.customSelect('''
      SELECT * FROM trading_entries 
      WHERE is_active = 1 $whereClause
      ORDER BY date DESC
    ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).watch().map((rows) => 
      rows.map((row) => _mapRowToTradingEntry(row.data)).toList()
    );
    
    // CRITICAL: Wrap stream with platform thread safety for Windows
    return _wrapStreamWithThreadSafety(stream, 'watchEntries');
  }

  @override
  Stream<List<TradingEntry>> watchEntriesByType(String entryType, {String? companyId}) {
    final whereClause = companyId != null ? 'AND company_id = ?' : '';
    final vars = [
      d.Variable.withString(entryType),
      if (companyId != null) d.Variable.withString(companyId),
    ];
    
    final stream = db.customSelect('''
      SELECT * FROM trading_entries 
      WHERE is_active = 1 AND entry_type = ? $whereClause
      ORDER BY date DESC
    ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).watch().map((rows) => 
      rows.map((row) => _mapRowToTradingEntry(row.data)).toList()
    );
    
    // CRITICAL: Wrap stream with platform thread safety for Windows
    return _wrapStreamWithThreadSafety(stream, 'watchEntriesByType');
  }

  @override
  Stream<TradingEntry?> watchEntryById(String id) {
    return db.customSelect('''
      SELECT * FROM trading_entries 
      WHERE is_active = 1 AND id = ?
    ''', variables: [d.Variable.withString(id)]).watch().map((rows) {
      if (rows.isEmpty) return null;
      return _mapRowToTradingEntry(rows.first.data);
    });
  }

  @override
  Future<List<TradingEntry>> searchEntries(String query, {String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = [
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
        if (companyId != null) d.Variable.withString(companyId),
      ];
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 AND (
          person_name LIKE ? OR 
          estate_name LIKE ? OR 
          mobile LIKE ? OR
          comments LIKE ?
        ) $whereClause
        ORDER BY date DESC
      ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error searching trading entries: $e');
      return [];
    }
  }

  @override
  Stream<List<TradingEntry>> watchSearchEntries(String query, {String? companyId}) {
    final whereClause = companyId != null ? 'AND company_id = ?' : '';
    final vars = [
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
      if (companyId != null) d.Variable.withString(companyId),
    ];
    
    return db.customSelect('''
      SELECT * FROM trading_entries 
      WHERE is_active = 1 AND (
        person_name LIKE ? OR 
        estate_name LIKE ? OR 
        mobile LIKE ? OR
        comments LIKE ?
      ) $whereClause
      ORDER BY date DESC
    ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).watch().map((rows) => 
      rows.map((row) => _mapRowToTradingEntry(row.data)).toList()
    );
  }

  @override
  Future<double> getTotalProfit({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final result = await db.customSelect('''
        SELECT 
          SUM(CASE 
            WHEN entry_type = 'sell' THEN quantity 
            WHEN entry_type = 'buy' THEN -quantity 
            ELSE 0 
          END) as profit
        FROM trading_entries 
        WHERE is_active = 1 $whereClause
      ''', variables: vars.map((v) => d.Variable.withString(v.value)).toList()).get();
      
      return result.first.data['profit'] as double? ?? 0.0;
    } catch (e) {
      debugPrint('Error calculating total profit: $e');
      return 0.0;
    }
  }

  @override
  Future<double> getTotalCommission({String? companyId}) async {
    return 0.0;
  }

  @override
  Future<Map<String, dynamic>> getTradingStatistics({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final result = await db.customSelect('''
        SELECT 
          COUNT(*) as total_entries,
          COUNT(CASE WHEN entry_type = 'buy' THEN 1 END) as buy_entries,
          COUNT(CASE WHEN entry_type = 'sell' THEN 1 END) as sell_entries,
          COUNT(CASE WHEN entry_type = 'form' THEN 1 END) as form_entries,
          COUNT(CASE WHEN entry_type = 'file' THEN 1 END) as file_entries,
          SUM(quantity) as total_quantity
        FROM trading_entries 
        WHERE is_active = 1 $whereClause
      ''', variables: vars.map((v) => d.Variable.withString(v.value)).toList()).get();
      
      final data = result.first.data;
      return {
        'totalEntries': data['total_entries'] as int? ?? 0,
        'buyEntries': data['buy_entries'] as int? ?? 0,
        'sellEntries': data['sell_entries'] as int? ?? 0,
        'formEntries': data['form_entries'] as int? ?? 0,
        'fileEntries': data['file_entries'] as int? ?? 0,
        'totalQuantity': data['total_quantity'] as double? ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting trading statistics: $e');
      return {};
    }
  }

  @override
  Future<bool> canUserAccessEntry(String userId, String entryId) async {
    try {
      final result = await db.customSelect('''
        SELECT COUNT(*) as count
        FROM trading_entries 
        WHERE id = ? AND is_active = 1 AND (created_by = ? OR company_id IN (
          SELECT company_id FROM users WHERE id = ?
        ))
      ''', variables: [
        d.Variable.withString(entryId),
        d.Variable.withString(userId),
        d.Variable.withString(userId),
      ]).get();
      
      return (result.first.data['count'] as int? ?? 0) > 0;
    } catch (e) {
      debugPrint('Error checking user access: $e');
      return false;
    }
  }

  @override
  Future<List<TradingEntry>> getEntriesForUser(String userId, {String? companyId}) async {
    try {
      final whereClauses = ['is_active = 1', 'created_by = ?'];
      final vars = [d.Variable.withString(userId)];
      
      if (companyId != null) {
        whereClauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      final whereClause = whereClauses.join(' AND ');
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE $whereClause
        ORDER BY date DESC
      ''', variables: vars).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error getting entries for user: $e');
      return [];
    }
  }

  @override
  Future<void> markEntryAsUnsynced(String entryId) async {
    await db.customStatement('''
      UPDATE trading_entries SET is_synced = 0, updated_at = ? 
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), entryId]);
  }

  @override
  Future<void> markEntryAsSynced(String entryId) async {
    await db.customStatement('''
      UPDATE trading_entries SET is_synced = 1, updated_at = ? 
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), entryId]);
  }

  @override
  Future<List<TradingEntry>> getUnsyncedEntries({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 AND is_synced = 0 $whereClause
        ORDER BY updated_at DESC
      ''', variables: vars.map((v) => d.Variable.withString(v)).toList()).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error getting unsynced entries: $e');
      return [];
    }
  }

  @override
  Future<void> addEntry(TradingEntry entry) async {
    try {
      final map = entry.toMap();
      final now = DateTime.now().toIso8601String();

      // Exactly 17 columns and 17 placeholders
      const sql = '''INSERT INTO trading_entries (
        id, entry_type, trade_type, category, date, person_name, mobile_no, estate_name, 
        quantity, unit_price, image_path, company_id, is_active, is_synced, created_at, updated_at, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''';

      await db.customStatement(sql, [
        map['id'],
        map['entry_type'],
        map['trade_type'] ?? '',
        map['category'] ?? '',
        map['date'],
        map['person_name'],
        map['mobile_no'],
        map['estate_name'],
        map['quantity'],
        map['unit_price'],
        map['image_path'],
        map['company_id'],
        map['is_active'],
        map['is_synced'],
        map['created_at'],
        now, // updated_at
        map['status'] ?? 'pending', // status
      ]);
      
      // Mark as unsynced for Firestore sync
      if (!_sqliteOnlyMode) {
        await markEntryAsUnsynced(map['id']);
      }
    } catch (e) {
      debugPrint('Error adding trading entry in repository: $e');
      rethrow; // CRITICAL: Rethrow so that ViewModel does not optimistically update UI on failure
    }
  }

  @override
  Future<void> updateEntry(TradingEntry entry) async {
    final map = entry.toMap();
    final now = DateTime.now().toIso8601String();

    await db.customStatement('''UPDATE trading_entries SET
        entry_type = ?, trade_type = ?, category = ?, date = ?, person_name = ?, mobile_no = ?, estate_name = ?, 
        quantity = ?, unit_price = ?, image_path = ?, updated_at = ?, status = ?
      WHERE id = ?''', [
      map['entry_type'], map['trade_type'], map['category'], map['date'], map['person_name'], map['mobile_no'], map['estate_name'],
      map['quantity'], map['unit_price'], map['image_path'], now, map['status'] ?? 'active', map['id']
    ]);
  }

  @override
  Future<void> updateEntryStatus(String entryId, String newStatus) async {
    final now = DateTime.now().toIso8601String();
    
    // Debug: Print the ID being updated
    print('TradingRepository: Updating ID: $entryId');
    print('TradingRepository: New status: $newStatus');
    
    // Check if entry exists in local SQLite cache before attempting update
    final currentResult = await db.customSelect(
      'SELECT status, is_active FROM trading_entries WHERE id = ?',
      variables: [d.Variable.withString(entryId)]
    ).getSingleOrNull();
    
    if (currentResult == null) {
      print('TradingRepository: Entry not found in local cache - ID: $entryId');
      throw AlreadyDeletedException('Entry not found. It may have been deleted or does not exist.');
    }
    
    final isActive = currentResult.data['is_active'] as int? ?? 0;
    final currentStatus = currentResult.data['status']?.toString();
    
    print('TradingRepository: Entry found - Active: $isActive, Status: $currentStatus');
    
    // Check if entry was already deleted (is_active = 0)
    if (isActive == 0) {
      print('TradingRepository: Entry already deleted - ID: $entryId');
      throw AlreadyDeletedException('Entry was already deleted and cannot be updated.');
    }
    
    // Strict lock: Prevent any updates if current status is already 'completed'
    if (currentStatus == 'completed') {
      debugPrint('TradingRepository: Status update blocked - entry $entryId is already completed');
      throw Exception('Cannot update status of completed entry');
    }
    
    await db.customStatement('''UPDATE trading_entries SET
        status = ?, updated_at = ?
      WHERE id = ?''', [newStatus, now, entryId]);
    
    print('TradingRepository: Successfully updated entry $entryId status to $newStatus');
    debugPrint('TradingRepository: Updated entry $entryId status to $newStatus');
  }

  @override
  Future<void> deleteEntry(String id) async {
    await db.customStatement('''
      UPDATE trading_entries SET is_active = 0, updated_at = ? WHERE id = ?
    ''', [DateTime.now().toIso8601String(), id]);
  }

  // Helper method to map database row to TradingEntry
  TradingEntry _mapRowToTradingEntry(Map<String, dynamic> data) {
    return TradingEntry(
      id: data['id']?.toString() ?? '',
      entryType: data['entry_type']?.toString() ?? '',
      tradeType: data['trade_type']?.toString() ?? 'Buy',
      category: data['category']?.toString() ?? 'File',
      date: DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
      personName: data['person_name']?.toString() ?? '',
      mobileNo: data['mobile_no']?.toString() ?? '',
      estateName: data['estate_name']?.toString() ?? '',
      quantity: double.tryParse(data['quantity']?.toString() ?? '0') ?? 0.0,
      unitPrice: double.tryParse(data['unit_price']?.toString() ?? '0') ?? 0.0,
      imagePath: data['image_path']?.toString(),
      companyId: data['company_id']?.toString() ?? '',
      isActive: (data['is_active'] as int? ?? 1) == 1,
      isSynced: (data['is_synced'] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? DateTime.now(),
      status: data['status']?.toString() ?? 'active',
    );
  }
}