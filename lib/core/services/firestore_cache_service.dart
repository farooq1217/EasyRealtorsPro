import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show RootIsolateToken;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';

/// Service for caching Firestore queries to reduce network calls
class FirestoreCacheService {
  static final FirestoreCacheService _instance = FirestoreCacheService._internal();
  factory FirestoreCacheService() => _instance;
  FirestoreCacheService._internal();

  final Map<String, CachedQuery> _cache = {};
  static const Duration _defaultCacheDuration = Duration(minutes: 5);
  static const int _maxCacheSize = 100; // Max 100 cached queries

  /// Get cached data or fetch from Firestore
  Future<Map<String, dynamic>?> getCachedDocument(
    String collection,
    String documentId, {
    Duration? cacheDuration,
  }) async {
    final cacheKey = '$collection/$documentId';
    final cached = _cache[cacheKey];

    // Check if cache is valid
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) <
            (cacheDuration ?? _defaultCacheDuration)) {
      return cached.data;
    }

    // Fetch from Firestore
    if (Firebase.apps.isEmpty) return null;
    if (RootIsolateToken.instance == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data != null) {
        _setCache(cacheKey, data, cacheDuration);
        return data;
      }
    } catch (e) {
      debugPrint('Error fetching Firestore document: $e');
      // Return cached data even if expired if fetch fails
      if (cached != null) {
        return cached.data;
      }
    }

    return null;
  }

  /// Batch get multiple documents with caching
  Future<Map<String, Map<String, dynamic>>> getCachedDocuments(
    String collection,
    List<String> documentIds, {
    Duration? cacheDuration,
  }) async {
    final result = <String, Map<String, dynamic>>{};
    final uncachedIds = <String>[];

    // Check cache for each document
    for (final docId in documentIds) {
      final cacheKey = '$collection/$docId';
      final cached = _cache[cacheKey];

      if (cached != null &&
          DateTime.now().difference(cached.timestamp) <
              (cacheDuration ?? _defaultCacheDuration)) {
        result[docId] = cached.data;
      } else {
        uncachedIds.add(docId);
      }
    }

    // Fetch uncached documents
    if (uncachedIds.isNotEmpty && Firebase.apps.isNotEmpty) {
      if (RootIsolateToken.instance == null) return result;
      try {
        // Batch fetch (Firestore allows up to 10 per batch)
        for (int i = 0; i < uncachedIds.length; i += 10) {
          final batch = uncachedIds.skip(i).take(10).toList();
          final futures = batch.map((docId) =>
              FirebaseFirestore.instance
                  .collection(collection)
                  .doc(docId)
                  .get());

          final docs = await Future.wait(futures);

          for (int j = 0; j < docs.length; j++) {
            final doc = docs[j];
            if (doc.exists) {
              final data = doc.data();
              if (data != null) {
                final docId = batch[j];
                result[docId] = data;
                _setCache('$collection/$docId', data, cacheDuration);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error batch fetching Firestore documents: $e');
      }
    }

    return result;
  }

  /// Invalidate cache for a document
  void invalidateCache(String collection, String documentId) {
    final cacheKey = '$collection/$documentId';
    _cache.remove(cacheKey);
  }

  /// Invalidate all cache for a collection
  void invalidateCollection(String collection) {
    _cache.removeWhere((key, value) => key.startsWith('$collection/'));
  }

  /// Clear all cache
  void clearCache() {
    _cache.clear();
  }

  void _setCache(String key, Map<String, dynamic> data, Duration? duration) {
    // Evict old entries if cache is full
    if (_cache.length >= _maxCacheSize) {
      final oldestKey = _cache.entries
          .reduce((a, b) =>
              a.value.timestamp.isBefore(b.value.timestamp) ? a : b)
          .key;
      _cache.remove(oldestKey);
    }

    _cache[key] = CachedQuery(
      data: data,
      timestamp: DateTime.now(),
    );
  }
}

class CachedQuery {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  CachedQuery({
    required this.data,
    required this.timestamp,
  });
}
