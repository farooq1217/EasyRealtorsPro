import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'core/services/app_storage.dart' show AppStorage;

/// Service to handle offline data persistence and synchronization
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final AppStorage _storage = AppStorage();
  bool _isOnline = true;
  final List<SyncAction> _pendingActions = [];
  StreamController<bool>? _connectivityController;
  Timer? _syncTimer;

  /// Stream of connectivity status
  Stream<bool> get connectivityStream {
    _connectivityController ??= StreamController<bool>.broadcast();
    return _connectivityController!.stream;
  }

  /// Current online status
  bool get isOnline => _isOnline;

  /// Initialize the service
  Future<void> initialize() async {
    await _checkConnectivity();
    _startPeriodicConnectivityCheck();
    await _loadPendingActions();
  }

  /// Check connectivity status
  Future<void> _checkConnectivity() async {
    try {
      // Simple connectivity check using HTTP ping
      final response = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      final wasOnline = _isOnline;
      _isOnline = response.statusCode == 200;
      if (wasOnline != _isOnline) {
        _connectivityController?.add(_isOnline);
        if (_isOnline) {
          await _syncPendingActions();
        }
      }
    } catch (e) {
      final wasOnline = _isOnline;
      _isOnline = false;
      if (wasOnline != _isOnline) {
        _connectivityController?.add(_isOnline);
      }
    }
  }

  /// Start periodic connectivity checking
  void _startPeriodicConnectivityCheck() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });
  }

  /// Load pending sync actions from storage
  Future<void> _loadPendingActions() async {
    try {
      final settings = await _storage.readSettings();
      final pendingJson = settings['pending_sync_actions'] as String?;
      if (pendingJson != null && pendingJson.isNotEmpty) {
        final List<dynamic> actionsJson = jsonDecode(pendingJson);
        _pendingActions.clear();
        _pendingActions.addAll(
          actionsJson.map((json) => SyncAction.fromJson(json)),
        );
      }
    } catch (e) {
      debugPrint('Error loading pending actions: $e');
    }
  }

  /// Save pending sync actions to storage
  Future<void> _savePendingActions() async {
    try {
      final settings = await _storage.readSettings();
      final actionsJson = _pendingActions.map((a) => a.toJson()).toList();
      settings['pending_sync_actions'] = jsonEncode(actionsJson);
      await _storage.writeSettings(settings);
    } catch (e) {
      debugPrint('Error saving pending actions: $e');
    }
  }

  /// Queue an action for sync when online
  Future<void> queueAction(SyncAction action) async {
    _pendingActions.add(action);
    await _savePendingActions();
    
    if (_isOnline) {
      await _syncPendingActions();
    }
  }

  /// Sync all pending actions
  Future<void> _syncPendingActions() async {
    if (!_isOnline || _pendingActions.isEmpty) return;

    final actionsToSync = List<SyncAction>.from(_pendingActions);
    final List<SyncAction> failedActions = [];

    for (final action in actionsToSync) {
      try {
        final success = await _executeAction(action);
        if (!success) {
          failedActions.add(action);
        }
      } catch (e) {
        debugPrint('Error syncing action ${action.id}: $e');
        failedActions.add(action);
      }
    }

    _pendingActions.clear();
    _pendingActions.addAll(failedActions);
    await _savePendingActions();
  }

  /// Execute a sync action
  Future<bool> _executeAction(SyncAction action) async {
    try {
      switch (action.type) {
        case SyncActionType.createFile:
          return await _syncCreateFile(action);
        case SyncActionType.updateFile:
          return await _syncUpdateFile(action);
        case SyncActionType.deleteFile:
          return await _syncDeleteFile(action);
        case SyncActionType.createProperty:
          return await _syncCreateProperty(action);
        case SyncActionType.updateProperty:
          return await _syncUpdateProperty(action);
        case SyncActionType.deleteProperty:
          return await _syncDeleteProperty(action);
      }
    } catch (e) {
      debugPrint('Error executing action ${action.id}: $e');
      return false;
    }
  }

  /// Sync create file action
  Future<bool> _syncCreateFile(SyncAction action) async {
    // Implementation depends on your backend API
    // For now, we'll just mark it as synced if it's in local DB
    try {
      final data = action.data as Map<String, dynamic>;
      // Verify the file exists in local DB
      // If using Firestore, sync to Firestore here
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sync update file action
  Future<bool> _syncUpdateFile(SyncAction action) async {
    // Similar to create, sync to backend
    return true;
  }

  /// Sync delete file action
  Future<bool> _syncDeleteFile(SyncAction action) async {
    // Sync deletion to backend
    return true;
  }

  /// Sync create property action
  Future<bool> _syncCreateProperty(SyncAction action) async {
    return true;
  }

  /// Sync update property action
  Future<bool> _syncUpdateProperty(SyncAction action) async {
    return true;
  }

  /// Sync delete property action
  Future<bool> _syncDeleteProperty(SyncAction action) async {
    return true;
  }

  /// Get count of pending actions
  int get pendingActionsCount => _pendingActions.length;

  /// Manually trigger sync
  Future<void> syncNow() async {
    if (_isOnline) {
      await _syncPendingActions();
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
    final c = _connectivityController;
    _connectivityController = null;
    if (c != null) {
      try {
        c.close();
      } catch (_) {}
    }
  }
}

/// Types of sync actions
enum SyncActionType {
  createFile,
  updateFile,
  deleteFile,
  createProperty,
  updateProperty,
  deleteProperty,
}

/// Represents an action to be synced
class SyncAction {
  final String id;
  final SyncActionType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SyncAction({
    required this.id,
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString(),
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncAction.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String;
    SyncActionType type;
    switch (typeString) {
      case 'SyncActionType.createFile':
        type = SyncActionType.createFile;
        break;
      case 'SyncActionType.updateFile':
        type = SyncActionType.updateFile;
        break;
      case 'SyncActionType.deleteFile':
        type = SyncActionType.deleteFile;
        break;
      case 'SyncActionType.createProperty':
        type = SyncActionType.createProperty;
        break;
      case 'SyncActionType.updateProperty':
        type = SyncActionType.updateProperty;
        break;
      case 'SyncActionType.deleteProperty':
        type = SyncActionType.deleteProperty;
        break;
      default:
        type = SyncActionType.createFile;
    }
    return SyncAction(
      id: json['id'] as String,
      type: type,
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

