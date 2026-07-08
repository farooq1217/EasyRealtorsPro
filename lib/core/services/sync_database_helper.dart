import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';
import '../database/app_database_singleton.dart';
import 'background_sync_manager.dart';

/// Helper service to mark records as unsynced when they are created/updated
/// This ensures that local changes will be synced to the cloud
class SyncDatabaseHelper {
  static final SyncDatabaseHelper _instance = SyncDatabaseHelper._internal();
  factory SyncDatabaseHelper() => _instance;
  SyncDatabaseHelper._internal();

  final BackgroundSyncManager _syncManager = BackgroundSyncManager();

  /// Mark a record as unsynced after INSERT/UPDATE operations
  Future<void> markAsUnsynced(String tableName, String recordId) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      await db.customStatement(
        'UPDATE $tableName SET is_synced = 0 WHERE id = ?',
        [recordId],
      );
      debugPrint('[SYNC_HELPER] Marked record $recordId in $tableName as unsynced');
      _syncManager.forceSync().catchError((e) {
        debugPrint('[SYNC_HELPER] Error auto-triggering background sync: $e');
      });
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error marking record as unsynced: $e');
    }
  }

  /// Mark multiple records as unsynced
  Future<void> markMultipleAsUnsynced(String tableName, List<String> recordIds) async {
    if (recordIds.isEmpty) return;
    
    try {
      final db = await AppDatabaseSingleton.instance();
      final placeholders = List.filled(recordIds.length, '?').join(',');
      await db.customStatement(
        'UPDATE $tableName SET is_synced = 0 WHERE id IN ($placeholders)',
        recordIds,
      );
      debugPrint('[SYNC_HELPER] Marked ${recordIds.length} records in $tableName as unsynced');
      _syncManager.forceSync().catchError((e) {
        debugPrint('[SYNC_HELPER] Error auto-triggering background sync: $e');
      });
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error marking multiple records as unsynced: $e');
    }
  }

  /// Helper method for INSERT operations - returns the ID and marks as unsynced
  Future<String?> insertWithSyncMark(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      
      // Ensure is_synced is set to 0 for new records
      data['is_synced'] = 0;
      
      // Build INSERT statement
      final columns = data.keys.join(', ');
      final placeholders = List.filled(data.length, '?').join(', ');
      final values = data.values.toList();
      
      await db.customStatement(
        'INSERT INTO $tableName ($columns) VALUES ($placeholders)',
        values,
      );
      
      // Get the inserted record ID (assuming it's provided in data)
      final recordId = data['id']?.toString();
      
      if (recordId != null) {
        debugPrint('[SYNC_HELPER] Inserted and marked record $recordId in $tableName as unsynced');
        _syncManager.forceSync().catchError((e) {
          debugPrint('[SYNC_HELPER] Error auto-triggering background sync: $e');
        });
        return recordId;
      }
      
      return null;
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error in insertWithSyncMark: $e');
      return null;
    }
  }

  /// Helper method for UPDATE operations - marks as unsynced
  Future<bool> updateWithSyncMark(
    String tableName,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      
      // Build UPDATE statement
      final setClause = data.keys.map((key) => '$key = ?').join(', ');
      final values = [...data.values, recordId];
      
      await db.customStatement(
        'UPDATE $tableName SET $setClause, is_synced = 0 WHERE id = ?',
        values,
      );
      
      debugPrint('[SYNC_HELPER] Updated and marked record $recordId in $tableName as unsynced');
      _syncManager.forceSync().catchError((e) {
        debugPrint('[SYNC_HELPER] Error auto-triggering background sync: $e');
      });
      return true;
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error in updateWithSyncMark: $e');
      return false;
    }
  }

  /// Helper method for DELETE operations - marks as unsynced before soft delete
  Future<bool> deleteWithSyncMark(String tableName, String recordId) async {
    try {
      // First mark as unsynced
      await markAsUnsynced(tableName, recordId);
      
      // Then perform the soft delete (which should be handled by triggers)
      final db = await AppDatabaseSingleton.instance();
      await db.customStatement(
        'DELETE FROM $tableName WHERE id = ?',
        [recordId],
      );
      
      debugPrint('[SYNC_HELPER] Marked record $recordId in $tableName as unsynced before deletion');
      _syncManager.forceSync().catchError((e) {
        debugPrint('[SYNC_HELPER] Error auto-triggering background sync: $e');
      });
      return true;
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error in deleteWithSyncMark: $e');
      return false;
    }
  }

  /// Batch mark records as unsynced for bulk operations
  Future<void> markBulkOperationAsUnsynced(String tableName) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      await db.customStatement(
        'UPDATE $tableName SET is_synced = 0 WHERE is_active = 1',
      );
      debugPrint('[SYNC_HELPER] Marked all active records in $tableName as unsynced (bulk operation)');
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error in bulk mark as unsynced: $e');
    }
  }

  /// Get count of unsynced records for a table
  Future<int> getUnsyncedCount(String tableName) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      final result = await db.customSelect(
        'SELECT COUNT(*) as count FROM $tableName WHERE is_synced = 0 AND is_active = 1'
      ).get();
      
      return result.first.data['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error getting unsynced count: $e');
      return 0;
    }
  }

  /// Get all unsynced records for a table
  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String tableName) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      final result = await db.customSelect(
        'SELECT * FROM $tableName WHERE is_synced = 0 AND is_active = 1'
      ).get();
      
      return result.map((row) => Map<String, dynamic>.from(row.data)).toList();
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error getting unsynced records: $e');
      return [];
    }
  }

  /// Mark a record as synced (after successful sync to cloud)
  Future<void> markAsSynced(String tableName, String recordId) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      await db.customStatement(
        'UPDATE $tableName SET is_synced = 1 WHERE id = ?',
        [recordId],
      );
      debugPrint('[SYNC_HELPER] Marked record $recordId in $tableName as synced');
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error marking record as synced: $e');
    }
  }

  /// Mark multiple records as synced (after successful batch sync)
  Future<void> markMultipleAsSynced(String tableName, List<String> recordIds) async {
    if (recordIds.isEmpty) return;
    
    try {
      final db = await AppDatabaseSingleton.instance();
      final placeholders = List.filled(recordIds.length, '?').join(',');
      await db.customStatement(
        'UPDATE $tableName SET is_synced = 1 WHERE id IN ($placeholders)',
        recordIds,
      );
      debugPrint('[SYNC_HELPER] Marked ${recordIds.length} records in $tableName as synced');
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error marking multiple records as synced: $e');
    }
  }

  /// Check if a specific record needs syncing
  Future<bool> needsSync(String tableName, String recordId) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      final result = await db.customSelect(
        'SELECT is_synced FROM $tableName WHERE id = ?'
      ).get();
      
      if (result.isNotEmpty) {
        final isSynced = result.first.data['is_synced'] as int? ?? 1;
        return isSynced == 0;
      }
      
      return false;
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error checking sync status: $e');
      return false;
    }
  }

  /// Reset sync status for all records (use with caution)
  Future<void> resetAllSyncStatus() async {
    try {
      final db = await AppDatabaseSingleton.instance();
      
      final tables = [
        'companies', 'users', 'societies', 'blocks', 'properties',
        'files_table', 'rental_items', 'working_progress', 'reminders', 'clients',
        'trading_entries', 'trading_file_entries', 'expenditures'
      ];
      
      for (final table in tables) {
        await db.customStatement('UPDATE $table SET is_synced = 1');
      }
      
      debugPrint('[SYNC_HELPER] Reset sync status for all tables');
    } catch (e) {
      debugPrint('[SYNC_HELPER] Error resetting sync status: $e');
    }
  }
}
