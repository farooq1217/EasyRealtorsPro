import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared/shared.dart';
import '../../firestore_sync_service.dart';
import '../database/app_database_singleton.dart';

/// Background sync manager for incremental local-to-cloud sync
/// Handles offline data synchronization when internet is restored
class BackgroundSyncManager {
  static final BackgroundSyncManager _instance = BackgroundSyncManager._internal();
  factory BackgroundSyncManager() => _instance;
  BackgroundSyncManager._internal();

  final FirestoreSyncService _firestoreSync = FirestoreSyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _hasInternet = false;
  
  // Sync status tracking
  final Map<String, SyncStatus> _tableSyncStatus = {};

  /// Initialize the sync manager
  Future<void> initialize() async {
    debugPrint('[SYNC] Initializing Background Sync Manager');
    
    // Check initial connectivity
    await _checkConnectivity();
    
    // Start connectivity monitoring
    _startConnectivityMonitoring();
    
    // Start periodic sync check (every 5 minutes)
    _startPeriodicSyncCheck();
    
    debugPrint('[SYNC] Background Sync Manager initialized');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    debugPrint('[SYNC] Background Sync Manager disposed');
  }

  /// Start monitoring internet connectivity
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty ? results.last : ConnectivityResult.none;
      final hadInternet = _hasInternet;
      _hasInternet = result != ConnectivityResult.none;
      
      debugPrint('[SYNC] Connectivity changed: ${result.name}, Has Internet: $_hasInternet');
      
      // Trigger sync when internet is restored
      if (!hadInternet && _hasInternet) {
        debugPrint('[SYNC] Internet restored - triggering background sync');
        _triggerBackgroundSync();
      }
    });
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final result = results.isNotEmpty ? results.last : ConnectivityResult.none;
      _hasInternet = result != ConnectivityResult.none;
      debugPrint('[SYNC] Initial connectivity check: ${result.name}, Has Internet: $_hasInternet');
    } catch (e) {
      debugPrint('[SYNC] Error checking connectivity: $e');
      _hasInternet = false;
    }
  }

  /// Start periodic sync check
  void _startPeriodicSyncCheck() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_hasInternet && !_isSyncing) {
        debugPrint('[SYNC] Periodic sync check - triggering background sync');
        _triggerBackgroundSync();
      }
    });
  }

  /// Trigger background sync for all unsynced records
  Future<void> _triggerBackgroundSync() async {
    if (_isSyncing || !_hasInternet) {
      debugPrint('[SYNC] Sync already in progress or no internet - skipping');
      return;
    }

    _isSyncing = true;
    debugPrint('[SYNC] Starting background sync');

    try {
      final db = await AppDatabaseSingleton.instance();
      
      // Sync all tables with unsynced records
      await _syncTable(db, 'companies', 'companies');
      await _syncTable(db, 'users', 'users');
      await _syncTable(db, 'societies', 'societies');
      await _syncTable(db, 'blocks', 'blocks');
      await _syncTable(db, 'properties', 'properties');
      await _syncTable(db, 'files_table', 'files');
      await _syncTable(db, 'rental_items', 'rental_items');
      await _syncTable(db, 'working_progress', 'working_progress');
      await _syncTable(db, 'reminders', 'reminders');
      await _syncTable(db, 'clients', 'clients');
      
      // Sync business tables
      await _syncBusinessTable(db, 'trading_entries', 'trading_entries');
      await _syncBusinessTable(db, 'trading_file_entries', 'trading_file_entries');
      await _syncBusinessTable(db, 'expenditures', 'expenditures');
      
      debugPrint('[SYNC] Background sync completed successfully');
    } catch (e) {
      debugPrint('[SYNC] Error during background sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a specific table's unsynced records
  Future<void> _syncTable(AppDatabase db, String tableName, String collectionName) async {
    try {
      final status = _getSyncStatus(tableName);
      status.startSync();
      
      // Get unsynced records
      final unsyncedRecords = await db.customSelect(
        'SELECT * FROM $tableName WHERE is_synced = 0 AND is_active = 1'
      ).get();
      
      if (unsyncedRecords.isEmpty) {
        status.completeSync(success: true);
        return;
      }
      
      debugPrint('[SYNC] Syncing ${unsyncedRecords.length} records from $tableName');
      
      // Convert records to Firestore format
      final documents = unsyncedRecords.map((row) {
        final data = Map<String, dynamic>.from(row.data);
        // Remove internal fields
        data.remove('is_synced');
        return data;
      }).toList();
      
      // Batch sync to Firestore
      final success = await _firestoreSync.batchSync(
        collection: collectionName,
        documents: documents,
      );
      
      if (success) {
        // Mark records as synced
        for (final record in unsyncedRecords) {
          final id = record.data['id']?.toString();
          if (id != null) {
            await db.customStatement(
              'UPDATE $tableName SET is_synced = 1 WHERE id = ?',
              [id],
            );
          }
        }
        status.completeSync(success: true);
        debugPrint('[SYNC] Successfully synced ${unsyncedRecords.length} records from $tableName');
      } else {
        status.completeSync(success: false, error: 'Firestore batch sync failed');
        debugPrint('[SYNC] Failed to sync records from $tableName');
      }
    } catch (e) {
      final status = _getSyncStatus(tableName);
      status.completeSync(success: false, error: e.toString());
      debugPrint('[SYNC] Error syncing table $tableName: $e');
    }
  }

  /// Sync business tables (trading, expenditure)
  Future<void> _syncBusinessTable(AppDatabase db, String tableName, String collectionName) async {
    try {
      final status = _getSyncStatus(tableName);
      status.startSync();
      
      // Get unsynced records
      final unsyncedRecords = await db.customSelect(
        'SELECT * FROM $tableName WHERE is_synced = 0 AND is_active = 1'
      ).get();
      
      if (unsyncedRecords.isEmpty) {
        status.completeSync(success: true);
        return;
      }
      
      debugPrint('[SYNC] Syncing ${unsyncedRecords.length} records from $tableName');
      
      // Convert records to Firestore format
      final documents = unsyncedRecords.map((row) {
        final data = Map<String, dynamic>.from(row.data);
        // Remove internal fields
        data.remove('is_synced');
        return data;
      }).toList();
      
      // Batch sync to Firestore
      final success = await _firestoreSync.batchSync(
        collection: collectionName,
        documents: documents,
      );
      
      if (success) {
        // Mark records as synced
        for (final record in unsyncedRecords) {
          final id = record.data['id']?.toString();
          if (id != null) {
            await db.customStatement(
              'UPDATE $tableName SET is_synced = 1 WHERE id = ?',
              [id],
            );
          }
        }
        status.completeSync(success: true);
        debugPrint('[SYNC] Successfully synced ${unsyncedRecords.length} records from $tableName');
      } else {
        status.completeSync(success: false, error: 'Firestore batch sync failed');
        debugPrint('[SYNC] Failed to sync records from $tableName');
      }
    } catch (e) {
      final status = _getSyncStatus(tableName);
      status.completeSync(success: false, error: e.toString());
      debugPrint('[SYNC] Error syncing business table $tableName: $e');
    }
  }

  /// Mark a record as unsynced (for local changes)
  Future<void> markRecordUnsynced(String tableName, String recordId) async {
    try {
      final db = await AppDatabaseSingleton.instance();
      await db.customStatement(
        'UPDATE $tableName SET is_synced = 0 WHERE id = ?',
        [recordId],
      );
      debugPrint('[SYNC] Marked record $recordId in $tableName as unsynced');
    } catch (e) {
      debugPrint('[SYNC] Error marking record as unsynced: $e');
    }
  }

  /// Get sync status for a table
  SyncStatus _getSyncStatus(String tableName) {
    return _tableSyncStatus.putIfAbsent(tableName, () => SyncStatus(tableName));
  }

  /// Get current sync status for all tables
  Map<String, SyncStatus> get syncStatus => Map.unmodifiable(_tableSyncStatus);

  /// Check if there are any unsynced records
  Future<bool> hasUnsyncedRecords() async {
    try {
      final db = await AppDatabaseSingleton.instance();
      
      final tables = [
        'companies', 'users', 'societies', 'blocks', 'properties',
        'files_table', 'rental_items', 'working_progress', 'reminders', 'clients',
        'trading_entries', 'trading_file_entries', 'expenditures'
      ];
      
      for (final table in tables) {
        final result = await db.customSelect(
          'SELECT COUNT(*) as count FROM $table WHERE is_synced = 0 AND is_active = 1'
        ).get();
        
        final count = result.first.data['count'] as int;
        if (count > 0) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('[SYNC] Error checking unsynced records: $e');
      return false;
    }
  }

  /// Force trigger a sync (for manual sync)
  Future<void> forceSync() async {
    if (_hasInternet) {
      await _triggerBackgroundSync();
    } else {
      debugPrint('[SYNC] Cannot force sync - no internet connection');
    }
  }

  /// Get current connectivity status
  bool get hasInternet => _hasInternet;

  /// Check if sync is currently in progress
  bool get isSyncing => _isSyncing;
}

/// Sync status for tracking table synchronization
class SyncStatus {
  final String tableName;
  bool isSyncing = false;
  DateTime? lastSyncTime;
  String? lastError;
  int totalRecords = 0;
  int syncedRecords = 0;

  SyncStatus(this.tableName);

  void startSync() {
    isSyncing = true;
    lastError = null;
    debugPrint('[SYNC] Starting sync for $tableName');
  }

  void completeSync({required bool success, String? error}) {
    isSyncing = false;
    lastSyncTime = DateTime.now();
    if (!success && error != null) {
      lastError = error;
    }
    debugPrint('[SYNC] Completed sync for $tableName - Success: $success');
  }

  @override
  String toString() {
    return 'SyncStatus($tableName: isSyncing=$isSyncing, lastSyncTime=$lastSyncTime, error=$lastError)';
  }
}
