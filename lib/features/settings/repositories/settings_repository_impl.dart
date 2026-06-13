// data/repositories/settings_repository_impl.dart
import 'society_repository.dart';
import 'society_repository_impl.dart';
import 'settings_repository.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../firestore_sync_service.dart';
import '../../../core/services/app_storage.dart' show AppStorage;
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import 'package:shared/shared.dart' show SocietiesCompanion, BlocksCompanion;
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import 'package:csv/csv.dart';
import '../../../core/services/firebase_threading_handler.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final dynamic db;
  final String? companyId;
  final bool isSuperAdmin;
  final SocietyRepository _societyRepository;
  
  // SQLite-only flag - disables all Firestore operations
  static const bool _sqliteOnlyMode = false;
  
  // Platform detection for thread safety
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;
  
  SettingsRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin})
      : _societyRepository = SocietyRepositoryImpl(db, companyId: companyId, isSuperAdmin: isSuperAdmin);

  // Helper method to wrap streams with platform thread safety
  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    if (_isWindows) {
      debugPrint('SettingsRepository: Wrapping $streamName with Windows thread safety');
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'SettingsRepository $streamName',
      );
    }
    return stream;
  }

  // Helper method to disable Firestore operations in SQLite-only mode
  bool _isFirestoreOperationAllowed() {
    return !_sqliteOnlyMode && Firebase.apps.isNotEmpty;
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
  Future<List<Map<String, String>>> getSocieties() async {
    return await _societyRepository.getSocieties();
  }

  @override
  Future<void> addSociety(String name) async {
    try {
      // Generate ID
      final id = 'soc_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Save to SQLite first
      await db.into(db.societies).insertOnConflictUpdate(
        SocietiesCompanion(
          id: d.Value(id),
          name: d.Value(name),
          companyId: isSuperAdmin ? const d.Value.absent() : d.Value(companyId),
          metadata: const d.Value(null),
          updatedAt: d.Value(nowIso),
        ),
      );

      // Sync to Firestore
      await _executeFirestoreOperation(() async {
        if (Firebase.apps.isNotEmpty) {
          await FirestoreSyncService().syncDocument(
            collection: 'societies',
            documentId: id,
            data: {
              'id': id,
              'name': name,
              'companyId': isSuperAdmin ? null : companyId,
              'metadata': null,
              'updatedAt': nowIso,
            },
            merge: true,
          );
        }
      });
    } catch (e) {
      debugPrint('Error adding society: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateSociety(String id, String name) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Update SQLite
      await db.customStatement(
        'UPDATE societies SET name = ?, updated_at = ? WHERE id = ?',
        [name, nowIso, id],
      );

      // Sync to Firestore
      await _executeFirestoreOperation(() async {
        if (Firebase.apps.isNotEmpty) {
          await FirestoreSyncService().syncDocument(
            collection: 'societies',
            documentId: id,
            data: {
              'name': name,
              'updatedAt': nowIso,
            },
            merge: true,
          );
        }
      });
    } catch (e) {
      debugPrint('Error updating society: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteSociety(String id) async {
    try {
      // Delete from Firestore first (before SQLite to preserve block IDs)
      await _executeFirestoreOperation(() async {
        if (Firebase.apps.isNotEmpty) {
          // Delete all blocks for this society first from Firestore
          final blocksSnapshot = await FirebaseFirestore.instance
              .collection('blocks')
              .where('societyId', isEqualTo: id)
              .get();

          for (final blockDoc in blocksSnapshot.docs) {
            await FirestoreSyncService().deleteDocument(
              collection: 'blocks',
              documentId: blockDoc.id,
            );
          }

          await FirestoreSyncService().deleteDocument(
            collection: 'societies',
            documentId: id,
          );
        }
      });

      // Delete from SQLite (blocks will be deleted by the Firestore listener)
      await db.customStatement('DELETE FROM blocks WHERE society_id = ?', [id]);
      await db.customStatement('DELETE FROM societies WHERE id = ?', [id]);
    } catch (e) {
      debugPrint('Error deleting society: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, String>>> getBlocks() async {
    return await _societyRepository.getBlocks();
  }

  @override
  Future<List<Map<String, String>>> getBlocksBySociety(String societyId) async {
    return await _societyRepository.getBlocksBySociety(societyId);
  }

  // Stream-based methods for real-time updates
  Stream<List<Map<String, String>>> watchSocieties(String? companyId, bool isSuper) {
    final clauses = <String>['is_active = 1'];
    final vars = <d.Variable<String>>[];
    if (!isSuper && companyId != null) {
      clauses.add('company_id = ?');
      vars.add(d.Variable.withString(companyId));
    }
    final where = clauses.isNotEmpty ? 'WHERE ${clauses.join(' AND ')}' : '';
    
    final stream = db
        .customSelect('SELECT id, name FROM societies $where ORDER BY name', variables: vars)
        .watch()
        .map((rows) {
          final List<Map<String, String>> societies = [];
          for (final row in rows) {
            societies.add({
              'id': row.read<String>('id'),
              'name': row.read<String>('name'),
            });
          }
          return societies;
        });
    return _wrapStreamWithThreadSafety(stream, 'watchSocieties');
  }

  Stream<List<Map<String, String>>> watchBlocks(String? societyId) {
    final clauses = <String>['is_active = 1'];
    final vars = <d.Variable<String>>[];
    if (societyId != null) {
      clauses.add('society_id = ?');
      vars.add(d.Variable.withString(societyId));
    }
    final where = clauses.isNotEmpty ? 'WHERE ${clauses.join(' AND ')}' : '';
    
    final stream = db
        .customSelect('SELECT id, society_id, name FROM blocks $where ORDER BY name', variables: vars)
        .watch()
        .map((rows) {
          final List<Map<String, String>> blocks = [];
          for (final row in rows) {
            blocks.add({
              'id': row.read<String>('id'),
              'society_id': row.read<String>('society_id'),
              'name': row.read<String>('name'),
            });
          }
          return blocks;
        });
    return _wrapStreamWithThreadSafety(stream, 'watchBlocks');
  }

  @override
  Future<void> addBlock(String societyId, String name) async {
    try {
      // Generate ID
      final id = 'blk_${societyId}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Save to SQLite first
      await db.into(db.blocks).insertOnConflictUpdate(
        BlocksCompanion(
          id: d.Value(id),
          societyId: d.Value(societyId),
          name: d.Value(name),
          companyId: isSuperAdmin ? const d.Value.absent() : d.Value(companyId),
          metadata: const d.Value(null),
          updatedAt: d.Value(nowIso),
        ),
      );

      // Sync to Firestore
      await _executeFirestoreOperation(() async {
        if (Firebase.apps.isNotEmpty) {
          await FirestoreSyncService().syncDocument(
            collection: 'blocks',
            documentId: id,
            data: {
              'id': id,
              'societyId': societyId,
              'name': name,
              'companyId': isSuperAdmin ? null : companyId,
              'metadata': null,
              'updatedAt': nowIso,
            },
            merge: true,
          );
        }
      });
    } catch (e) {
      debugPrint('Error adding block: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateBlock(String id, String name) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Update SQLite
      await db.customStatement(
        'UPDATE blocks SET name = ?, updated_at = ? WHERE id = ?',
        [name, nowIso, id],
      );

      // Sync to Firestore
      await _executeFirestoreOperation(() async {
        if (Firebase.apps.isNotEmpty) {
          await FirestoreSyncService().syncDocument(
            collection: 'blocks',
            documentId: id,
            data: {
              'name': name,
              'updatedAt': nowIso,
            },
            merge: true,
          );
        }
      });
    } catch (e) {
      debugPrint('Error updating block: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteBlock(String id) async {
    try {
      // Delete from Firestore first
      await _executeFirestoreOperation(() async {
        if (Firebase.apps.isNotEmpty) {
          await FirestoreSyncService().deleteDocument(
            collection: 'blocks',
            documentId: id,
          );
        }
      });

      // Delete from SQLite
      await db.customStatement('DELETE FROM blocks WHERE id = ?', [id]);
    } catch (e) {
      debugPrint('Error deleting block: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      Map<String, dynamic>? mergedUser = AuthService.currentUser;
      if (authToken != null) {
        final user = await AuthService.getCurrentUser(authToken);
        mergedUser = user ?? mergedUser;
      }

      try {
        // Prefer email from mergedUser; fallback to cached settings if needed.
        final emailKey = (mergedUser?['email'] ?? mergedUser?['username'])?.toString().toLowerCase();
        if (emailKey != null && emailKey.isNotEmpty) {
          final dbResult = await db.customSelect(
        'SELECT id, username, email, password_hash, name, contact_no, permissions, company_id, status, is_active, is_first_login, user_id, created_at FROM users WHERE email = ? OR username = ?',
        variables: <d.Variable<Object>>[
          d.Variable.withString(emailKey),
          d.Variable.withString(emailKey),
        ],
      ).get();
          if (dbResult.isNotEmpty) {
            final row = dbResult.first.data;
            mergedUser = {
              ...?mergedUser,
              'id': row['id'],
              'user_uid': row['id'],
              'userId': row['id'],
              'email': row['email'] ?? mergedUser?['email'],
              'username': row['username'] ?? mergedUser?['username'],
              'name': row['name'] ?? mergedUser?['name'],
              'full_name': row['name'] ?? mergedUser?['full_name'],
              'fullName': row['name'] ?? mergedUser?['fullName'],
              'contact_no': row['contact_no'] ?? mergedUser?['contact_no'],
              'phone': row['contact_no'] ?? mergedUser?['phone'],
              'mobile': row['contact_no'] ?? mergedUser?['mobile'],
              'company_id': row['company_id'] ?? mergedUser?['company_id'],
              'companyId': row['company_id'] ?? mergedUser?['companyId'],
              'status': row['status'] ?? mergedUser?['status'],
              'is_first_login': row['is_first_login'] ?? mergedUser?['is_first_login'],
              'isFirstLogin': row['is_first_login'] ?? mergedUser?['isFirstLogin'],
              'updated_at': row['updated_at'] ?? mergedUser?['updated_at'],
              'updatedAt': row['updated_at'] ?? mergedUser?['updatedAt'],
              'created_at': row['created_at'] ?? mergedUser?['created_at'],
              'createdAt': row['created_at'] ?? mergedUser?['createdAt'],
              if (row['profile_picture_path'] != null) 'profile_picture_path': row['profile_picture_path'],
            };
          }
        }
      } catch (e) {
        debugPrint('Error refreshing user from DB: $e');
      }

      return mergedUser;
    } catch (e) {
      debugPrint('Error loading current user: $e');
      return null;
    }
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> userData) async {
    try {
      final name = userData['name'] as String;
      final phone = userData['phone'] as String;
      final companyName = userData['companyName'] as String;
      final profilePicPath = userData['profilePicturePath'] as String?;
      final emailKey = userData['email'] as String;
      final userId = userData['userId'] as String;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Local-first explicit update with safe fallbacks
      bool primaryUpdated = false;
      try {
        await db.customStatement(
          'UPDATE users SET name = ?, full_name = ?, fullName = ?, contact_no = ?, phone = ?, company_name = ?, profile_picture_path = ?, updated_at = ?, is_first_login = 0 WHERE id = ? OR email = ? OR username = ?',
          [name, name, name, phone, phone, companyName, profilePicPath, nowIso, userId, emailKey, emailKey],
        );
        primaryUpdated = true;
      } catch (e) {
        debugPrint('Primary UPDATE failed (may be missing columns): $e');
      }

      final existing = await db.customSelect(
        'SELECT id FROM users WHERE id = ? OR email = ? OR username = ?',
        variables: <d.Variable<Object>>[
          d.Variable.withString(userId),
          d.Variable.withString(emailKey),
          d.Variable.withString(emailKey),
        ],
      ).get();

      final permissions = userData['permissions'];
      final permissionsJson = permissions == null ? null : (permissions is String ? permissions : jsonEncode(permissions));

      if (existing.isNotEmpty) {
        if (!primaryUpdated) {
          await db.customStatement(
            'UPDATE users SET name = ?, contact_no = ?, updated_at = ?, is_first_login = 0 WHERE id = ? OR email = ? OR username = ?',
            [name, phone, nowIso, userId, emailKey, emailKey],
          );
          // Best-effort additional columns if present
          try {
            await db.customStatement(
              'UPDATE users SET full_name = COALESCE(full_name, ?), fullName = COALESCE(fullName, ?), phone = COALESCE(phone, ?), company_name = COALESCE(company_name, ?), profile_picture_path = COALESCE(profile_picture_path, ?) WHERE id = ? OR email = ? OR username = ?',
              [name, name, phone, companyName, profilePicPath, userId, emailKey, emailKey],
            );
          } catch (e) {
            debugPrint('Optional user columns not updated: $e');
          }
        }
      } else {
        await db.customStatement(
          'INSERT OR REPLACE INTO users (id, username, email, name, contact_no, permissions, company_id, status, is_first_login, is_active, created_at, updated_at, profile_picture_path, full_name, fullName, phone, company_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            userId,
            emailKey,
            emailKey,
            name,
            phone,
            permissionsJson,
            companyId,
            userData['status'] ?? 'active',
            0,
            1,
            userData['created_at'] ?? nowIso,
            nowIso,
            profilePicPath,
            name,
            name,
            phone,
            companyName,
          ],
        );
      }

      if (companyName.isNotEmpty) {
        await db.customStatement(
          'UPDATE companies SET name = ?, updated_at = ? WHERE id = ?',
          [companyName, nowIso, companyId],
        );
      }

      // Firestore sync is best-effort and silent on permission issues
      await _executeFirestoreOperation(() async {
        if (Firebase.apps.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(userId).set(
            {
              'name': name,
              'full_name': name,
              'fullName': name,
              'contact_no': phone,
              'contactNo': phone,
              'phone': phone,
              'is_first_login': 0,
              'isFirstLogin': 0,
              'updated_at': nowIso,
              'updatedAt': nowIso,
              if (profilePicPath != null && profilePicPath.isNotEmpty) 'profile_picture_path': profilePicPath,
              if (companyName.isNotEmpty) 'company_name': companyName,
              if (companyName.isNotEmpty) 'companyName': companyName,
              if (companyId != null) 'company_id': companyId,
              if (companyId != null) 'companyId': companyId,
            },
            SetOptions(merge: true),
          );

          if (companyName.isNotEmpty) {
            await firestore.collection('companies').doc(companyId).set(
              {
                'name': companyName,
                'updated_at': nowIso,
                'updatedAt': nowIso,
              },
              SetOptions(merge: true),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateProfileImage(String imagePath) async {
    try {
      final emailKey = AuthService.currentUser?['email']?.toString().toLowerCase() ?? '';
      final userId = AuthService.currentUser?['id']?.toString() ?? '';

      await db.customStatement(
        'UPDATE users SET profile_picture_path = ? WHERE id = ? OR email = ? OR username = ?',
        [imagePath, userId, emailKey, emailKey],
      );

      // Update AuthService cache
      if (AuthService.currentUser != null) {
        AuthService.currentUser!['profile_picture_path'] = imagePath;
      }
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      rethrow;
    }
  }

  @override
  Future<void> exportDataToCsv() async {
    try {
      final users = await db.customSelect(
        isSuperAdmin ? 'SELECT * FROM users' : 'SELECT * FROM users WHERE company_id = ? OR companyId = ?',
        variables: isSuperAdmin ? <d.Variable<Object>>[] : <d.Variable<Object>>[d.Variable.withString(companyId ?? ''), d.Variable.withString(companyId ?? '')],
      ).get();

      final trades = await db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM trading_entries'
            : 'SELECT * FROM trading_entries WHERE company_id = ?',
        variables: isSuperAdmin ? <d.Variable<Object>>[] : <d.Variable<Object>>[d.Variable.withString(companyId ?? '')],
      ).get();

      final tradeFiles = await db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM trading_file_entries'
            : 'SELECT * FROM trading_file_entries WHERE company_id = ?',
        variables: isSuperAdmin ? <d.Variable<Object>>[] : <d.Variable<Object>>[d.Variable.withString(companyId ?? '')],
      ).get();

      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final dir = await AppStorage().appDir();

      String _convertToCsv(List<Map<String, dynamic>> rows) {
        if (rows.isEmpty) return '';
        final headers = <String>{};
        for (final r in rows) {
          headers.addAll(r.keys.map((k) => k.toString()));
        }
        final headerList = headers.toList();
        final data = <List<dynamic>>[];
        data.add(headerList);
        for (final r in rows) {
          data.add(headerList.map((h) => r[h]).toList());
        }
        return const ListToCsvConverter().convert(data);
      }

      final usersCsv = _convertToCsv(users.map((r) => r.data).toList());
      final tradesCsv = _convertToCsv([
        ...trades.map((r) => r.data)..forEach((r) => r['entry_type'] = 'form'),
        ...tradeFiles.map((r) => r.data)..forEach((r) => r['entry_type'] = 'file'),
      ]);

      final usersFile = io.File('${dir.path}/users_export_$ts.csv');
      final tradingFile = io.File('${dir.path}/trading_export_$ts.csv');
      await usersFile.writeAsString(usersCsv);
      await tradingFile.writeAsString(tradesCsv);
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    }
  }
}
