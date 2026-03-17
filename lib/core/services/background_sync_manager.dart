import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared/shared.dart';
import '../../firestore_sync_service.dart';
import '../database/app_database_singleton.dart';
import 'firebase_threading_handler.dart';

/// Background sync manager for incremental local-to-cloud sync
/// Handles offline data synchronization when internet is restored
class BackgroundSyncManager {
  static final BackgroundSyncManager _instance = BackgroundSyncManager._internal();
  factory BackgroundSyncManager() => _instance;
  BackgroundSyncManager._internal();
  
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;
  
  bool _isInitialized = false;
  bool _isInitializing = false; // CRITICAL: Prevent concurrent initialization attempts
  static bool _hasBeenInitializedInSession = false; // CRITICAL: Session-wide flag
  DateTime? _lastSyncTime; // CRITICAL: Track last sync time to prevent spam
  
  // CRITICAL: Public getter to access session flag from external classes
  bool get hasBeenInitializedInSession => _hasBeenInitializedInSession;

  final FirestoreSyncService _firestoreSync = FirestoreSyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _hasInternet = false;
  
  // Sync status tracking
  final Map<String, SyncStatus> _tableSyncStatus = {};

  /// CRITICAL: Static pre-check method to prevent unnecessary initialization attempts
  /// This saves CPU cycles by checking BEFORE attempting to initialize
  static bool shouldAttemptInitialization() {
    if (_hasBeenInitializedInSession) {
      debugPrint('[SYNC] Initialization skipped - already initialized in this session');
      return false;
    }
    return true;
  }

  /// Initialize the sync manager
  /// Enhanced with comprehensive re-initialization prevention
  Future<void> initialize() async {
    // CRITICAL: Multiple layers of protection against re-initialization
    if (_isInitialized) {
      return;
    }
    
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    
    if (_hasBeenInitializedInSession) {
      return;
    }
    
    _isInitializing = true;
    // ENHANCED: Only log initialization start for first-time session initialization
    if (!_hasBeenInitializedInSession) {
      debugPrint('[SYNC] Starting Background Sync Manager initialization...');
    }
    
    try {
      _isInitialized = true;
      _hasBeenInitializedInSession = true;
      
      // Check initial connectivity
      await _checkConnectivity();
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
      // Start periodic sync check (every 5 minutes)
      _startPeriodicSyncCheck();
      
      debugPrint('[SYNC] Background Sync Manager initialized successfully');
    } catch (e) {
      debugPrint('[SYNC] Error initializing Background Sync Manager: $e');
      _isInitialized = false;
      _hasBeenInitializedInSession = false;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Dispose resources
  /// Enhanced with session flag reset for proper re-initialization control
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _isInitialized = false;
    _isInitializing = false;
    // CRITICAL: Reset session flag to allow re-initialization in next session
    _hasBeenInitializedInSession = false;
    debugPrint('[SYNC] Background Sync Manager disposed and session flag reset');
  }

  /// Start monitoring internet connectivity
  /// Enhanced with ServicesBinding thread safety for Windows
  void _startConnectivityMonitoring() {
    // CRITICAL: Ensure connectivity monitoring starts on main thread
    if (_isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
      });
    } else {
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
  /// Enhanced with ServicesBinding thread safety for Windows
  void _startPeriodicSyncCheck() {
    // CRITICAL: Ensure timer starts on main thread for Windows
    if (_isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
          if (_hasInternet && !_isSyncing) {
            debugPrint('[SYNC] Periodic sync check - triggering background sync');
            _triggerBackgroundSync();
          }
        });
        debugPrint('[SYNC] Periodic sync timer started on main thread (Windows)');
      });
    } else {
      _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (_hasInternet && !_isSyncing) {
          debugPrint('[SYNC] Periodic sync check - triggering background sync');
          _triggerBackgroundSync();
        }
      });
    }
  }

  /// Trigger background sync for all unsynced records
  Future<void> _triggerBackgroundSync() async {
    // CRITICAL: Enhanced protection against concurrent sync attempts
    if (_isSyncing) {
      debugPrint('[SYNC] Sync already in progress - skipping (concurrent call prevented)');
      return;
    }
    
    if (!_hasInternet) {
      debugPrint('[SYNC] No internet connection - skipping background sync');
      return;
    }

    // CRITICAL: Additional protection against rapid successive calls
    if (_lastSyncTime != null && 
        DateTime.now().difference(_lastSyncTime!).inSeconds < 30) {
      debugPrint('[SYNC] Sync called too recently - skipping (last sync: ${_lastSyncTime})');
      return;
    }

    _isSyncing = true;
    _lastSyncTime = DateTime.now();
    debugPrint('[SYNC] Starting background sync (timestamp: $_lastSyncTime)');

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
      await _syncBusinessTable(db, 'expenditures', 'expenditures');
      
      debugPrint('[SYNC] Background sync completed successfully');
    } catch (e) {
      debugPrint('[SYNC] Error during background sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a specific table's unsynced records
  /// Enhanced with FirebaseThreadingHandler for Windows compatibility
  Future<void> _syncTable(AppDatabase db, String tableName, String collectionName) async {
    try {
      // Enhanced with threading handler for Windows compatibility
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          await _performSyncTableOperation(db, tableName, collectionName);
        },
        operationName: 'Background sync - $tableName',
      );
    } catch (e) {
      final status = _getSyncStatus(tableName);
      status.completeSync(success: false, error: 'Sync operation failed: $e');
      debugPrint('[SYNC] Error syncing $tableName: $e');
    }
  }

  /// Perform the actual sync table operation
  Future<void> _performSyncTableOperation(AppDatabase db, String tableName, String collectionName) async {
    final status = _getSyncStatus(tableName);
    status.startSync();
    
    // Check if we're in SQLite-only mode (Windows platform)
    if (_firestoreSync.isWindows) {
      // In SQLite-only mode, mark all records as synced to prevent sync failures
      await db.customStatement(
        'UPDATE $tableName SET is_synced = 1 WHERE is_synced = 0 AND is_active = 1'
      );
      status.completeSync(success: true);
      debugPrint('[SYNC] SQLite-only mode: Marked all $tableName records as synced');
      return;
    }
    
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
  }

  /// Sync business tables (trading, expenditure)
  /// Enhanced with FirebaseThreadingHandler for Windows compatibility
  Future<void> _syncBusinessTable(AppDatabase db, String tableName, String collectionName) async {
    try {
      // Enhanced with threading handler for Windows compatibility
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          await _performSyncBusinessTableOperation(db, tableName, collectionName);
        },
        operationName: 'Background business sync - $tableName',
      );
    } catch (e) {
      final status = _getSyncStatus(tableName);
      status.completeSync(success: false, error: 'Business sync operation failed: $e');
      debugPrint('[SYNC] Error syncing business table $tableName: $e');
    }
  }

  /// Perform the actual business sync table operation
  Future<void> _performSyncBusinessTableOperation(AppDatabase db, String tableName, String collectionName) async {
    final status = _getSyncStatus(tableName);
    status.startSync();
    
    // Check if we're in SQLite-only mode (Windows platform)
    if (_firestoreSync.isWindows) {
      // In SQLite-only mode, mark all records as synced to prevent sync failures
      await db.customStatement(
        'UPDATE $tableName SET is_synced = 1 WHERE is_synced = 0 AND is_active = 1'
      );
      status.completeSync(success: true);
      debugPrint('[SYNC] SQLite-only mode: Marked all business $tableName records as synced');
      return;
    }
    
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
        'trading_entries', 'expenditures'
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
