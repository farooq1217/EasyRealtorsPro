import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as d;
import 'package:shared/shared.dart';
import 'firebase_threading_handler.dart';
import 'package:http/http.dart' as http;

/// Network Sync Manager for Offline-First Architecture
/// 
/// Handles background synchronization between local SQLite database
/// and Firebase Firestore when internet connectivity is available.
/// 
/// Features:
/// - Automatic connectivity detection
/// - Queued operations for offline changes
/// - Conflict resolution strategies
/// - Progress tracking and error handling
/// - Selective sync based on data type
class NetworkSyncManager {
  static NetworkSyncManager? _instance;
  static NetworkSyncManager get instance => _instance ??= NetworkSyncManager._();
  
  NetworkSyncManager._();

  // Sync state
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  bool _isOnline = false;
  Timer? _connectivityCheckTimer;

  // Streams and subscriptions
  StreamSubscription<fb.User?>? _authSubscription;
  
  // Sync controllers
  final StreamController<SyncStatus> _syncStatusController = 
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  final StreamController<SyncProgress> _syncProgressController = 
      StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  final StreamController<SyncStats> _syncStatsController = 
      StreamController<SyncStats>.broadcast();
  Stream<SyncStats> get syncStatsStream => _syncStatsController.stream;

  // Sync queue for offline operations
  final List<SyncOperation> _syncQueue = [];
  Timer? _syncRetryTimer;

  // Configuration
  static const Duration _syncRetryDelay = Duration(seconds: 30);
  static const Duration _syncTimeout = Duration(minutes: 5);
  static const int _maxRetryAttempts = 3;
  static const Duration _connectivityCheckInterval = Duration(seconds: 10);
  static const String _pingUrl = 'https://www.google.com';

  /// Initialize the sync manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('NetworkSyncManager: Initializing...');

    try {
      // Check if Firebase is properly initialized
      if (Firebase.apps.isEmpty) {
        debugPrint('NetworkSyncManager: Firebase not initialized - running in offline-only mode');
        _isInitialized = true;
        debugPrint('NetworkSyncManager: Offline-only mode initialization complete');
        return;
      }

      // Start periodic connectivity check
      _startConnectivityCheck();

      // Listen to Firebase auth changes
      _listenToFirebaseAuth();

      // Check initial connectivity
      await _checkConnectivity();
      if (_isOnline) {
        debugPrint('NetworkSyncManager: Internet available on initialization');
        await _performInitialSync();
      }

      _isInitialized = true;
      debugPrint('NetworkSyncManager: Initialization complete');

    } catch (e) {
      debugPrint('NetworkSyncManager: Initialization error: $e');
      // Still mark as initialized to prevent repeated attempts
      _isInitialized = true;
    }
  }

  /// Force sync all data
  Future<SyncResult> forceSyncAll() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      return SyncResult(
        success: false,
        message: 'Firebase not initialized - offline-only mode',
      );
    }

    debugPrint('NetworkSyncManager: Starting forced sync');
    return await _performFullSync();
  }

  /// Sync specific table
  Future<SyncResult> syncTable(String tableName) async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      return SyncResult(
        success: false,
        message: 'Firebase not initialized - offline-only mode',
      );
    }

    debugPrint('NetworkSyncManager: Syncing table: $tableName');
    return await _syncSingleTable(tableName);
  }

  /// Add operation to sync queue
  Future<void> queueOperation(SyncOperation operation) async {
    _syncQueue.add(operation);
    debugPrint('NetworkSyncManager: Queued operation: ${operation.type} on ${operation.tableName}');
    
    // Try to sync immediately if online
    await _processSyncQueue();
  }

  /// Get sync status
  SyncStatus getCurrentStatus() {
    if (_isSyncing) {
      return SyncStatus.syncing(
        operation: 'Syncing data...',
        progress: _getSyncProgress(),
      );
    } else if (_syncQueue.isNotEmpty) {
      return SyncStatus.pending(
        pendingOperations: _syncQueue.length,
      );
    } else if (_lastSyncTime != null) {
      return SyncStatus.synced(lastSyncTime: _lastSyncTime!);
    } else {
      return SyncStatus.neverSynced();
    }
  }

  /// Get sync statistics
  SyncStats getSyncStats() {
    return SyncStats(
      lastSyncTime: _lastSyncTime,
      pendingOperations: _syncQueue.length,
      isSyncing: _isSyncing,
      totalSyncs: _getTotalSyncCount(),
    );
  }

  /// Dispose the sync manager
  Future<void> dispose() async {
    debugPrint('NetworkSyncManager: Disposing...');
    
    _connectivityCheckTimer?.cancel();
    await _authSubscription?.cancel();
    await _syncStatusController.close();
    await _syncProgressController.close();
    
    _isInitialized = false;
    debugPrint('NetworkSyncManager: Disposed');
  }

  // Private methods

  void _startConnectivityCheck() {
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = Timer.periodic(_connectivityCheckInterval, (_) async {
      await _checkConnectivity();
    });
    debugPrint('NetworkSyncManager: Started periodic connectivity check');
  }

  Future<void> _checkConnectivity() async {
    try {
      final previousState = _isOnline;
      
      // Windows-safe HTTP ping check
      final response = await http.head(
        Uri.parse(_pingUrl),
      ).timeout(
        const Duration(seconds: 5),
      );
      
      _isOnline = response.statusCode >= 200 && response.statusCode < 300;
      
      if (previousState != _isOnline) {
        debugPrint('NetworkSyncManager: Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
        
        if (_isOnline) {
          debugPrint('NetworkSyncManager: Internet available, starting sync');
          _processSyncQueue();
        }
      }
    } catch (e) {
      if (_isOnline) {
        debugPrint('NetworkSyncManager: Connectivity check failed: $e');
        _isOnline = false;
      }
    }
  }

  void _listenToFirebaseAuth() {
    // Check if Firebase is initialized before setting up auth listener
    if (Firebase.apps.isEmpty) {
      debugPrint('NetworkSyncManager: Firebase not initialized - skipping auth listener');
      return;
    }

    try {
      _authSubscription = fb.FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          debugPrint('NetworkSyncManager: Firebase user authenticated, ready for sync');
          _processSyncQueue();
        } else {
          debugPrint('NetworkSyncManager: Firebase user not authenticated, pausing sync');
        }
      });
    } catch (e) {
      debugPrint('NetworkSyncManager: Error setting up Firebase auth listener: $e');
      // Continue without auth listener - app will work in offline mode
    }
  }

  Future<void> _performInitialSync() async {
    if (!_isOnline) return;

    debugPrint('NetworkSyncManager: Performing initial sync');
    await _performFullSync();
  }

  Future<void> _processSyncQueue() async {
    if (_syncQueue.isEmpty || _isSyncing || !_isOnline) {
      return;
    }

    debugPrint('NetworkSyncManager: Processing sync queue (${_syncQueue.length} operations)');
    
    try {
      _isSyncing = true;
      _emitSyncStatus(SyncStatus.syncing(
        operation: 'Processing queued operations...',
        progress: _getSyncProgress(),
      ));

      // Process operations in batches
      final operations = List<SyncOperation>.from(_syncQueue);
      _syncQueue.clear();

      for (final operation in operations) {
        try {
          await _executeSyncOperation(operation);
        } catch (e) {
          debugPrint('NetworkSyncManager: Operation failed: $e');
          
          // Re-queue failed operations with retry count
          if (operation.retryCount < _maxRetryAttempts) {
            final retryOperation = operation.copyWith(retryCount: operation.retryCount + 1);
            _syncQueue.add(retryOperation);
          }
        }
      }

      // Perform full sync after processing queue
      await _performFullSync();

    } finally {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
      _emitSyncStatus(SyncStatus.synced(lastSyncTime: _lastSyncTime!));
    }
  }

  Future<SyncResult> _performFullSync() async {
    if (!_isOnline) {
      return SyncResult(
        success: false,
        message: 'No internet connection',
      );
    }

    debugPrint('NetworkSyncManager: Starting full sync');
    
    try {
      _isSyncing = true;
      _emitSyncStatus(SyncStatus.syncing(
        operation: 'Syncing all data...',
        progress: _getSyncProgress(),
      ));

      final results = <String, SyncResult>{};

      // Define sync order (dependent tables first)
      final syncOrder = [
        'companies',
        'users',
        'societies',
        'blocks',
        'properties',
        'files_table',
        'trading_entries',
        'trading_file_entries',
        'rental_items',
        'expenditures',
        'reminders',
        'working_progress',
      ];

      int completedTables = 0;
      final totalTables = syncOrder.length;

      for (final tableName in syncOrder) {
        try {
          debugPrint('NetworkSyncManager: Syncing table: $tableName');
          final result = await _syncSingleTable(tableName);
          results[tableName] = result;
          
          completedTables++;
          _emitSyncProgress(SyncProgress(
            completedTables: completedTables,
            totalTables: totalTables,
            currentTable: tableName,
          ));
          
        } catch (e) {
          debugPrint('NetworkSyncManager: Error syncing table $tableName: $e');
          results[tableName] = SyncResult(
            success: false,
            message: 'Error syncing $tableName: $e',
          );
        }
      }

      _lastSyncTime = DateTime.now();
      
      // Calculate overall success
      final failedTables = results.values.where((r) => !r.success).length;
      final success = failedTables == 0;

      debugPrint('NetworkSyncManager: Full sync complete. Success: $success, Failed tables: $failedTables');
      
      return SyncResult(
        success: success,
        message: success 
          ? 'All tables synced successfully' 
          : '$failedTables tables failed to sync',
        details: results,
      );

    } finally {
      _isSyncing = false;
      _emitSyncStatus(SyncStatus.synced(lastSyncTime: _lastSyncTime!));
    }
  }

  Future<SyncResult> _syncSingleTable(String tableName) async {
    if (!_isOnline) {
      return SyncResult(
        success: false,
        message: 'No internet connection',
      );
    }

    debugPrint('NetworkSyncManager: Syncing table: $tableName');

    try {
      final db = await AppDatabase.instance();
      
      // Get unsynced records
      final unsyncedRecords = await db.customSelect(
        'SELECT * FROM $tableName WHERE is_synced = 0 AND is_active = 1'
      ).get();

      if (unsyncedRecords.isEmpty) {
        debugPrint('NetworkSyncManager: No unsynced records in $tableName');
        return SyncResult(success: true, message: 'No changes to sync');
      }

      int syncedCount = 0;
      int failedCount = 0;

      for (final record in unsyncedRecords) {
        try {
          await _syncRecordToFirebase(tableName, record.data);
          await _markRecordAsSynced(tableName, record.data['id'] as String);
          syncedCount++;
        } catch (e) {
          debugPrint('NetworkSyncManager: Failed to sync record ${record.data['id']}: $e');
          failedCount++;
        }
      }

      debugPrint('NetworkSyncManager: Table $tableName sync complete: $syncedCount synced, $failedCount failed');
      
      return SyncResult(
        success: failedCount == 0,
        message: 'Synced $syncedCount records${failedCount > 0 ? ', $failedCount failed' : ''}',
        details: {
          'synced': syncedCount,
          'failed': failedCount,
          'total': unsyncedRecords.length,
        },
      );

    } catch (e) {
      debugPrint('NetworkSyncManager: Error syncing table $tableName: $e');
      return SyncResult(
        success: false,
        message: 'Error syncing $tableName: $e',
      );
    }
  }

  Future<void> _syncRecordToFirebase(String tableName, Map<String, dynamic> record) async {
    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      debugPrint('NetworkSyncManager: Firebase not initialized - skipping record sync');
      throw Exception('Firebase not initialized - cannot sync record');
    }

    final firestore = FirebaseFirestore.instance;
    final collection = _getFirestoreCollection(tableName);
    final docId = record['id'] as String;

    // Prepare data for Firestore
    final firestoreData = _prepareDataForFirestore(record);

    // Use FirebaseThreadingHandler for thread safety
    await FirebaseThreadingHandler.executeWithThreadSafety(() async {
      await firestore.collection(collection).doc(docId).set(
        firestoreData,
        SetOptions(merge: true),
      );
    }, operationName: 'syncRecordToFirebase');

    debugPrint('NetworkSyncManager: Synced record $docId to $collection');
  }

  Future<void> _markRecordAsSynced(String tableName, String recordId) async {
    final db = await AppDatabase.instance();
    
    await db.customStatement(
      'UPDATE $tableName SET is_synced = 1, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), recordId],
    );
  }

  Future<void> _executeSyncOperation(SyncOperation operation) async {
    debugPrint('NetworkSyncManager: Executing operation: ${operation.type} on ${operation.tableName}');

    switch (operation.type) {
      case SyncOperationType.create:
        await _executeCreateOperation(operation);
        break;
      case SyncOperationType.update:
        await _executeUpdateOperation(operation);
        break;
      case SyncOperationType.delete:
        await _executeDeleteOperation(operation);
        break;
    }
  }

  Future<void> _executeCreateOperation(SyncOperation operation) async {
    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      debugPrint('NetworkSyncManager: Firebase not initialized - skipping create operation');
      throw Exception('Firebase not initialized - cannot execute create operation');
    }

    final firestore = FirebaseFirestore.instance;
    final collection = _getFirestoreCollection(operation.tableName);
    
    await FirebaseThreadingHandler.executeWithThreadSafety(() async {
      await firestore.collection(collection).doc(operation.recordId).set(
        operation.data,
        SetOptions(merge: true),
      );
    }, operationName: 'executeCreateOperation');
  }

  Future<void> _executeUpdateOperation(SyncOperation operation) async {
    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      debugPrint('NetworkSyncManager: Firebase not initialized - skipping update operation');
      throw Exception('Firebase not initialized - cannot execute update operation');
    }

    final firestore = FirebaseFirestore.instance;
    final collection = _getFirestoreCollection(operation.tableName);
    
    await FirebaseThreadingHandler.executeWithThreadSafety(() async {
      await firestore.collection(collection).doc(operation.recordId).update(
        operation.data,
      );
    }, operationName: 'executeUpdateOperation');
  }

  Future<void> _executeDeleteOperation(SyncOperation operation) async {
    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      debugPrint('NetworkSyncManager: Firebase not initialized - skipping delete operation');
      throw Exception('Firebase not initialized - cannot execute delete operation');
    }

    final firestore = FirebaseFirestore.instance;
    final collection = _getFirestoreCollection(operation.tableName);
    
    await FirebaseThreadingHandler.executeWithThreadSafety(() async {
      await firestore.collection(collection).doc(operation.recordId).delete();
    }, operationName: 'executeDeleteOperation');
  }

  String _getFirestoreCollection(String tableName) {
    // Map table names to Firestore collections
    switch (tableName) {
      case 'users':
        return 'users';
      case 'companies':
        return 'companies';
      case 'societies':
        return 'societies';
      case 'blocks':
        return 'blocks';
      case 'properties':
        return 'properties';
      case 'files_table':
        return 'files';
      case 'trading_entries':
        return 'trading_entries';
      case 'trading_file_entries':
        return 'trading_file_entries';
      case 'rental_items':
        return 'rental_items';
      case 'expenditures':
        return 'expenditures';
      case 'reminders':
        return 'reminders';
      case 'working_progress':
        return 'working_progress';
      default:
        return tableName;
    }
  }

  Map<String, dynamic> _prepareDataForFirestore(Map<String, dynamic> record) {
    // Remove local-only fields and prepare for Firestore
    final firestoreData = Map<String, dynamic>.from(record);
    
    // Remove fields that shouldn't be synced
    firestoreData.remove('is_synced');
    
    // Ensure timestamps are in correct format
    if (firestoreData['created_at'] != null) {
      firestoreData['created_at'] = Timestamp.fromDate(
        DateTime.parse(firestoreData['created_at']),
      );
    }
    
    if (firestoreData['updated_at'] != null) {
      firestoreData['updated_at'] = Timestamp.fromDate(
        DateTime.parse(firestoreData['updated_at']),
      );
    }
    
    return firestoreData;
  }


  SyncProgress _getSyncProgress() {
    return SyncProgress(
      completedTables: 0,
      totalTables: 12, // Total number of tables to sync
      currentTable: '',
    );
  }

  int _getTotalSyncCount() {
    // This could be stored persistently if needed
    return 0;
  }

  void _emitSyncStatus(SyncStatus status) {
    if (!_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  void _emitSyncProgress(SyncProgress progress) {
    if (!_syncProgressController.isClosed) {
      _syncProgressController.add(progress);
    }
  }

  void _emitSyncStats(SyncStats stats) {
    if (!_syncStatsController.isClosed) {
      _syncStatsController.add(stats);
    }
  }
}

// Data classes

enum SyncOperationType {
  create,
  update,
  delete,
}

class SyncOperation {
  final String tableName;
  final String recordId;
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final int retryCount;
  final DateTime timestamp;

  SyncOperation({
    required this.tableName,
    required this.recordId,
    required this.type,
    required this.data,
    this.retryCount = 0,
  }) : timestamp = DateTime.now();

  SyncOperation copyWith({
    String? tableName,
    String? recordId,
    SyncOperationType? type,
    Map<String, dynamic>? data,
    int? retryCount,
  }) {
    return SyncOperation(
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      type: type ?? this.type,
      data: data ?? this.data,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? details;

  SyncResult({
    required this.success,
    required this.message,
    this.details,
  });
}

class SyncStatus {
  final bool isSyncing;
  final bool isPending;
  final bool isSynced;
  final bool neverSynced;
  final String? operation;
  final SyncProgress? progress;
  final int? pendingOperations;
  final DateTime? lastSyncTime;

  const SyncStatus._({
    required this.isSyncing,
    required this.isPending,
    required this.isSynced,
    required this.neverSynced,
    this.operation,
    this.progress,
    this.pendingOperations,
    this.lastSyncTime,
  });

  factory SyncStatus.syncing({
    required String operation,
    SyncProgress? progress,
  }) {
    return SyncStatus._(
      isSyncing: true,
      isPending: false,
      isSynced: false,
      neverSynced: false,
      operation: operation,
      progress: progress,
    );
  }

  factory SyncStatus.pending({
    required int pendingOperations,
  }) {
    return SyncStatus._(
      isSyncing: false,
      isPending: true,
      isSynced: false,
      neverSynced: false,
      pendingOperations: pendingOperations,
    );
  }

  factory SyncStatus.synced({
    required DateTime lastSyncTime,
  }) {
    return SyncStatus._(
      isSyncing: false,
      isPending: false,
      isSynced: true,
      neverSynced: false,
      lastSyncTime: lastSyncTime,
    );
  }

  factory SyncStatus.neverSynced() {
    return const SyncStatus._(
      isSyncing: false,
      isPending: false,
      isSynced: false,
      neverSynced: true,
    );
  }
}

class SyncProgress {
  final int completedTables;
  final int totalTables;
  final String currentTable;

  SyncProgress({
    required this.completedTables,
    required this.totalTables,
    required this.currentTable,
  });

  double get percentage => totalTables > 0 ? completedTables / totalTables : 0.0;
}

class SyncStats {
  final DateTime? lastSyncTime;
  final int pendingOperations;
  final bool isSyncing;
  final int totalSyncs;

  SyncStats({
    this.lastSyncTime,
    required this.pendingOperations,
    required this.isSyncing,
    required this.totalSyncs,
  });
}
