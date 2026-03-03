import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show RootIsolateToken;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;

/// Comprehensive Firestore sync service with pagination support
/// Designed for scaling to 10,000+ users
class FirestoreSyncService {
  static final FirestoreSyncService _instance = FirestoreSyncService._internal();
  factory FirestoreSyncService() => _instance;
  FirestoreSyncService._internal();

  bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  /// Helper to ensure code runs on main thread for UI updates
  void _ensureMainThread(VoidCallback callback) {
    if (_isWindows) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        callback();
      });
    } else {
      callback();
    }
  }

  // Default pagination size - optimized for performance
  static const int defaultPageSize = 50;
  static const int maxPageSize = 200;

  /// Helper to create an empty paginated result with no-op loadNext
  static PaginatedResult _emptyPaginatedResult() {
    return PaginatedResult(
      data: <Map<String, dynamic>>[],
      hasMore: false,
      lastDoc: null,
      loadNext: () async => _emptyPaginatedResult(),
    );
  }

  /// Listen to a Firestore collection with pagination
  /// Returns a stream of paginated data
  Stream<List<Map<String, dynamic>>> listenWithPagination({
    required String collection,
    required Query Function(Query) queryBuilder,
    int pageSize = defaultPageSize,
    String? orderBy,
    bool descending = false,
  }) {
    if (_isWindows) {
      return Stream.value([]);
    }
    if (Firebase.apps.isEmpty) {
      return Stream.value([]);
    }
    if (kIsWeb == false && RootIsolateToken.instance == null) {
      return Stream.value([]);
    }

    final query = queryBuilder(FirebaseFirestore.instance.collection(collection))
        .limit(pageSize.clamp(1, maxPageSize));

    if (orderBy != null) {
      query.orderBy(orderBy, descending: descending);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Ensure ID is always present
        return data;
      }).toList();
    });
  }

  /// Load paginated data from Firestore
  /// Returns data and a function to load next page
  Future<PaginatedResult> loadPaginated({
    required String collection,
    required Query Function(Query) queryBuilder,
    int pageSize = defaultPageSize,
    String? orderBy,
    bool descending = false,
    DocumentSnapshot? startAfter,
  }) async {
    if (_isWindows) return _emptyPaginatedResult();
    if (Firebase.apps.isEmpty) return _emptyPaginatedResult();
    if (kIsWeb == false && RootIsolateToken.instance == null) return _emptyPaginatedResult();

    // Ensure Firebase operations happen on main thread
    final completer = Completer<PaginatedResult>();
    _ensureMainThread(() async {
      await _ensureAuthenticatedWithFreshToken();
      if (FirebaseAuth.instance.currentUser == null) {
        completer.complete(_emptyPaginatedResult());
        return;
      }

      try {
        Query query = queryBuilder(FirebaseFirestore.instance.collection(collection))
            .limit(pageSize.clamp(1, maxPageSize));

        if (orderBy != null) {
          query = query.orderBy(orderBy, descending: descending);
        }

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        final snapshot = await query.get();
        final data = snapshot.docs.map((doc) {
          final docData = doc.data() as Map<String, dynamic>;
          docData['id'] = doc.id;
          return docData;
        }).toList();

        final hasMore = snapshot.docs.length == pageSize;
        final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

        completer.complete(PaginatedResult(
          data: data,
          hasMore: hasMore,
          lastDoc: lastDoc,
          loadNext: lastDoc != null && hasMore
              ? () => loadPaginated(
                    collection: collection,
                    queryBuilder: queryBuilder,
                    pageSize: pageSize,
                    orderBy: orderBy,
                    descending: descending,
                    startAfter: lastDoc,
                  )
              : () async => PaginatedResult(
                    data: <Map<String, dynamic>>[],
                    hasMore: false,
                    lastDoc: null,
                    loadNext: () async => PaginatedResult(
                      data: <Map<String, dynamic>>[],
                      hasMore: false,
                      lastDoc: null,
                      loadNext: () async => PaginatedResult(
                        data: <Map<String, dynamic>>[],
                        hasMore: false,
                        lastDoc: null,
                        loadNext: () async => PaginatedResult(
                          data: <Map<String, dynamic>>[],
                          hasMore: false,
                          lastDoc: null,
                          loadNext: () async => PaginatedResult(
                            data: <Map<String, dynamic>>[],
                            hasMore: false,
                            lastDoc: null,
                            loadNext: () async => _emptyPaginatedResult(),
                          ),
                        ),
                      ),
                    ),
                  ),
        ));
      } catch (e) {
        _ensureMainThread(() {
          debugPrint('Error loading paginated Firestore data: $e');
        });
        completer.complete(_emptyPaginatedResult());
      }
    });

    return completer.future;
  }

  /// Sync a document to Firestore (with offline persistence support)
  Future<bool> syncDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    if (_isWindows) return false;
    if (Firebase.apps.isEmpty) return false;
    if (kIsWeb == false && RootIsolateToken.instance == null) return false;
    await _ensureAuthenticatedWithFreshToken();
    if (FirebaseAuth.instance.currentUser == null) return false;

    try {
      final result = await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .set(data, SetOptions(merge: merge));
      
      // Ensure any UI updates happen on main thread
      _ensureMainThread(() {
        debugPrint('Document synced successfully to Firestore: $collection/$documentId');
      });
      
      return true;
    } catch (e) {
      _ensureMainThread(() {
        debugPrint('Error syncing document to Firestore: $e');
      });
      return false;
    }
  }

  /// Batch sync multiple documents
  Future<bool> batchSync({
    required String collection,
    required List<Map<String, dynamic>> documents,
  }) async {
    if (_isWindows) return false;
    if (Firebase.apps.isEmpty) return false;
    if (kIsWeb == false && RootIsolateToken.instance == null) return false;
    await _ensureAuthenticatedWithFreshToken();
    if (FirebaseAuth.instance.currentUser == null) return false;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in documents) {
        final docId = doc['id']?.toString() ?? '';
        if (docId.isNotEmpty) {
          final ref = FirebaseFirestore.instance.collection(collection).doc(docId);
          try {
            batch.set(ref, doc, SetOptions(merge: true));
          } catch (e) {
            _ensureMainThread(() {
              debugPrint('Batch sync skipped doc $docId: $e');
            });
          }
        }
      }
      await batch.commit();
      
      _ensureMainThread(() {
        debugPrint('Batch sync completed successfully: ${documents.length} documents');
      });
      
      return true;
    } catch (e) {
      _ensureMainThread(() {
        debugPrint('Error batch syncing to Firestore: $e');
      });
      return false;
    }
  }

  /// Delete a document from Firestore
  Future<bool> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    if (_isWindows) return false;
    if (Firebase.apps.isEmpty) return false;
    if (kIsWeb == false && RootIsolateToken.instance == null) return false;
    await _ensureAuthenticatedWithFreshToken();
    if (FirebaseAuth.instance.currentUser == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting document from Firestore: $e');
      return false;
    }
  }

  /// Check if Firestore is available and connected
  bool get isAvailable => !_isWindows && Firebase.apps.isNotEmpty && RootIsolateToken.instance != null;

  /// Get Firestore instance (if available)
  FirebaseFirestore? get firestore {
    if (!isAvailable) return null;
    return FirebaseFirestore.instance;
  }

  /// Wait until an authenticated user exists (or timeout).
  Future<void> waitForAuth({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isWindows) return;
    if (FirebaseAuth.instance.currentUser != null) return;
    final completer = Completer<void>();
    late StreamSubscription sub;
    sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && !completer.isCompleted) {
        completer.complete();
        sub.cancel();
      }
    });
    try {
      await completer.future.timeout(timeout);
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    } finally {
      await sub.cancel();
    }
  }

  /// Wait for a valid Firebase Auth user and refresh the ID token before Firestore ops.
  /// Includes a short delay on Windows to let native auth state propagate.
  Future<void> _ensureAuthenticatedWithFreshToken({Duration delay = const Duration(seconds: 2)}) async {
    if (_isWindows) {
      await Future.delayed(delay);
    }
    if (FirebaseAuth.instance.currentUser == null) {
      await waitForAuth();
    }
    try {
      // On Windows, avoid getIdToken() calls that can cause platform thread errors
      if (io.Platform.isWindows) {
        // Just ensure Firebase is initialized without refreshing token
        if (FirebaseAuth.instance.currentUser != null) {
          debugPrint('Windows: Skipping ID token refresh to avoid platform thread errors');
        }
      } else {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      }
    } catch (e) {
      debugPrint('Failed to refresh ID token before Firestore operation: $e');
    }
  }
}

/// Result of a paginated query
class PaginatedResult {
  final List<Map<String, dynamic>> data;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;
  final Future<PaginatedResult> Function() loadNext;

  PaginatedResult({
    required this.data,
    required this.hasMore,
    required this.lastDoc,
    required this.loadNext,
  });
}

/// Helper class for managing Firestore sync state
class FirestoreSyncState {
  bool isLoading = false;
  bool isSynced = false;
  DateTime? lastSyncTime;
  String? error;
  int totalItems = 0;
  int loadedItems = 0;

  void reset() {
    isLoading = false;
    isSynced = false;
    lastSyncTime = null;
    error = null;
    totalItems = 0;
    loadedItems = 0;
  }

  void startLoading() {
    isLoading = true;
    error = null;
  }

  void finishLoading({bool synced = true, String? errorMessage}) {
    isLoading = false;
    isSynced = synced;
    lastSyncTime = DateTime.now();
    error = errorMessage;
  }
}

