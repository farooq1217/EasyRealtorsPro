import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show WorkingProgressData, WorkingComment, AppDatabase, WorkingProgressCompanion, WorkingCommentsCompanion;
import 'package:drift/drift.dart' as d;
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import 'agent_repository.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../../../firestore_sync_service.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/firebase_threading_handler.dart';

class AgentRepositoryImpl implements AgentRepository {
  final AppDatabase db;
  final String? companyId;
  final bool isSuperAdmin;
  
  static const bool _sqliteOnlyMode = false;
  
  // ✅ Platform detection
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  AgentRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin});

  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    if (_isWindows) {
      debugPrint('AgentRepository: Wrapping $streamName with Windows thread safety');
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'AgentRepository $streamName',
      );
    }
    return stream;
  }

  // ✅ FIXED: Windows par Firestore operations disable
  bool _isFirestoreOperationAllowed() {
    if (_isWindows) {
      return false; // ✅ Windows par always false
    }
    return !_sqliteOnlyMode && Firebase.apps.isNotEmpty;
  }

  Future<void> _executeFirestoreOperation(Future<void> Function() operation) async {
    if (_isFirestoreOperationAllowed()) {
      try {
        await operation();
      } catch (e) {
        debugPrint('Firestore operation failed (non-critical): $e');
      }
    } else {
      debugPrint('Firestore operation skipped (Windows or SQLite-only mode)');
    }
  }

  @override
  Future<List<WorkingProgressData>> getTransfers({
    String? companyId,
    bool isSuperAdmin = false,
    String? searchQuery,
  }) async {
    try {
      final clauses = <String>['1=1'];
      final vars = <d.Variable<Object>>[];
      
      clauses.add('is_active = 1');
      
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        clauses.add('(name LIKE ? OR category LIKE ? OR remarks LIKE ?)');
        final searchPattern = '%$searchQuery%';
        vars.addAll([
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
        ]);
      }
      
      final where = clauses.join(' AND ');
      
      final result = await db.customSelect(
        'SELECT * FROM working_progress WHERE $where ORDER BY updated_at DESC',
        variables: vars,
      ).get();
      
      final List<WorkingProgressData> transfers = [];
      for (final row in result) {
        final data = row.data;
        final transfer = WorkingProgressData(
          id: data['id'] as String,
          companyId: data['company_id'] as String?,
          name: data['name'] as String,
          status: data['status'] as String?,
          remarks: data['remarks'] as String?,
          fromUser: data['from_user'] as String?,
          toUser: data['to_user'] as String?,
          transferDate: data['transfer_date'] as String?,
          nextWorkingDate: data['next_working_date'] as String?,
          category: data['category'] as String?,
          source: data['source'] as String?,
          isActive: (data['is_active'] as int? ?? 1) == 1,
          updatedAt: data['updated_at'] as String,
          isSynced: (data['is_synced'] as int? ?? 1) == 1,
        );
        transfers.add(transfer);
      }
      
      return transfers;
    } catch (e) {
      debugPrint('Error loading transfers: $e');
      return [];
    }
  }

  @override
  Stream<List<WorkingProgressData>> watchTransfers({
    String? companyId,
    bool isSuperAdmin = false,
    String? searchQuery,
  }) {
    try {
      final clauses = <String>['1=1'];
      final vars = <d.Variable<Object>>[];
      
      clauses.add('is_active = 1');
      
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        clauses.add('(name LIKE ? OR category LIKE ? OR remarks LIKE ?)');
        final searchPattern = '%$searchQuery%';
        vars.addAll([
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
        ]);
      }
      
      final where = clauses.join(' AND ');
      
      final stream = db
          .customSelect(
            'SELECT * FROM working_progress WHERE $where ORDER BY updated_at DESC',
            variables: vars,
            readsFrom: {db.workingProgress},
          )
          .watch()
          .map((result) {
            final List<WorkingProgressData> transfers = [];
            for (final row in result) {
              final data = row.data;
              final transfer = WorkingProgressData(
                id: data['id'] as String,
                companyId: data['company_id'] as String?,
                name: data['name'] as String,
                status: data['status'] as String?,
                remarks: data['remarks'] as String?,
                fromUser: data['from_user'] as String?,
                toUser: data['to_user'] as String?,
                transferDate: data['transfer_date'] as String?,
                nextWorkingDate: data['next_working_date'] as String?,
                category: data['category'] as String?,
                source: data['source'] as String?,
                isActive: (data['is_active'] as int? ?? 1) == 1,
                updatedAt: data['updated_at'] as String,
                isSynced: (data['is_synced'] as int? ?? 1) == 1,
              );
              transfers.add(transfer);
            }
            debugPrint('AgentRepository: Stream updated transfers - ${transfers.length} items');
            return transfers;
          });
      return _wrapStreamWithThreadSafety(stream, 'watchTransfers');
    } catch (e) {
      debugPrint('Error setting up transfers stream: $e');
      return Stream.value([]);
    }
  }

  @override
  Future<List<WorkingProgressData>> getClientRequirements({
    String? companyId,
    bool isSuperAdmin = false,
    String? searchQuery,
  }) async {
    try {
      final clauses = <String>['1=1'];
      final vars = <d.Variable<Object>>[];
      
      clauses.add('is_active = 1');
      
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        clauses.add('(name LIKE ? OR category LIKE ? OR remarks LIKE ?)');
        final searchPattern = '%$searchQuery%';
        vars.addAll([
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
        ]);
      }
      
      final where = clauses.join(' AND ');
      
      final result = await db.customSelect(
        'SELECT * FROM working_progress WHERE $where ORDER BY updated_at DESC',
        variables: vars,
      ).get();
      
      final List<WorkingProgressData> requirements = [];
      for (final row in result) {
        final data = row.data;
        final requirement = WorkingProgressData(
          id: data['id'] as String,
          companyId: data['company_id'] as String?,
          name: data['name'] as String,
          status: data['status'] as String?,
          remarks: data['remarks'] as String?,
          fromUser: data['from_user'] as String?,
          toUser: data['to_user'] as String?,
          transferDate: data['transfer_date'] as String?,
          nextWorkingDate: data['next_working_date'] as String?,
          category: data['category'] as String?,
          isActive: (data['is_active'] as int? ?? 1) == 1,
          updatedAt: data['updated_at'] as String,
          isSynced: (data['is_synced'] as int? ?? 1) == 1,
        );
        requirements.add(requirement);
      }
      
      return requirements;
    } catch (e) {
      debugPrint('Error loading client requirements: $e');
      return [];
    }
  }

  @override
  Stream<List<WorkingProgressData>> watchClientRequirements({
    String? companyId,
    bool isSuperAdmin = false,
    String? searchQuery,
  }) {
    try {
      final clauses = <String>['1=1'];
      final vars = <d.Variable<Object>>[];
      
      clauses.add('is_active = 1');
      
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        clauses.add('(name LIKE ? OR category LIKE ? OR remarks LIKE ?)');
        final searchPattern = '%$searchQuery%';
        vars.addAll([
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
        ]);
      }
      
      final where = clauses.join(' AND ');
      
      final stream = db
          .customSelect(
            'SELECT * FROM working_progress WHERE $where ORDER BY updated_at DESC',
            variables: vars,
            readsFrom: {db.workingProgress},
          )
          .watch()
          .map((result) {
            final List<WorkingProgressData> requirements = [];
            for (final row in result) {
              final data = row.data;
              final requirement = WorkingProgressData(
                id: data['id'] as String,
                companyId: data['company_id'] as String?,
                name: data['name'] as String,
                status: data['status'] as String?,
                remarks: data['remarks'] as String?,
                fromUser: data['from_user'] as String?,
                toUser: data['to_user'] as String?,
                transferDate: data['transfer_date'] as String?,
                nextWorkingDate: data['next_working_date'] as String?,
                category: data['category'] as String?,
                source: data['source'] as String?,
                isActive: (data['is_active'] as int? ?? 1) == 1,
                updatedAt: data['updated_at'] as String,
                isSynced: (data['is_synced'] as int? ?? 1) == 1,
              );
              requirements.add(requirement);
            }
            debugPrint('AgentRepository: Stream updated client requirements - ${requirements.length} items');
            return requirements;
          });
      return _wrapStreamWithThreadSafety(stream, 'watchClientRequirements');
    } catch (e) {
      debugPrint('Error setting up client requirements stream: $e');
      return Stream.value([]);
    }
  }

  @override
  Future<bool> addTransfer({
    required String id,
    String? companyId,
    required String name,
    required String status,
    String? remarks,
    required String transferDate,
    String? nextWorkingDate,
    String? category,
    String? plotNo,
    String? registryNumber,
    String? size,
    String? clientMobile,
    List<String>? images,
  }) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      
      debugPrint('AgentRepository: Adding transfer with ID: $id');
      
      await db.into(db.workingProgress).insertOnConflictUpdate(
        WorkingProgressCompanion.insert(
          id: id,
          companyId: isSuperAdmin ? const d.Value.absent() : d.Value(companyId),
          name: name,
          status: d.Value(status),
          remarks: remarks != null && remarks.isNotEmpty ? d.Value(remarks) : const d.Value.absent(),
          fromUser: const d.Value.absent(),
          toUser: const d.Value.absent(),
          transferDate: d.Value(transferDate),
          nextWorkingDate: nextWorkingDate != null ? d.Value(nextWorkingDate) : const d.Value.absent(),
          category: category != null && category.isNotEmpty ? d.Value(category) : const d.Value.absent(),
          source: const d.Value('Agent'),
          isActive: const d.Value(true),
          updatedAt: nowIso,
          isSynced: const d.Value(false),
        ),
      );
      
      debugPrint('AgentRepository: SQLite insert successful for ID: $id');
      
      if (_isFirestoreOperationAllowed()) {
        await _executeFirestoreOperation(() async {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('working_progress').doc(id).set({
            'id': id,
            if (companyId != null) 'companyId': companyId,
            'name': name,
            'status': status,
            if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
            'transferDate': transferDate,
            if (nextWorkingDate != null) 'nextWorkingDate': nextWorkingDate,
            if (category != null && category.isNotEmpty) 'category': category,
            if (plotNo != null && plotNo.isNotEmpty) 'plotNo': plotNo,
            if (registryNumber != null && registryNumber.isNotEmpty) 'registryNumber': registryNumber,
            if (size != null && size.isNotEmpty) 'size': size,
            if (clientMobile != null && clientMobile.isNotEmpty) 'clientMobile': clientMobile,
            'type': 'transfer',
            'updatedAt': nowIso,
            'createdAt': nowIso,
          }, SetOptions(merge: true));
          
          await db.customStatement(
            'UPDATE working_progress SET is_synced = 1 WHERE id = ?',
            <Object>[id],
          );
          debugPrint('AgentRepository: Firestore sync successful for ID: $id');
        });
      } else {
        debugPrint('AgentRepository: SQLite-only mode, skipping Firestore sync for ID: $id');
        await db.customStatement(
          'UPDATE working_progress SET is_synced = 1 WHERE id = ?',
          <Object>[id],
        );
      }
      
      if (images != null && images.isNotEmpty) {
        await _saveImages(id, images);
      }
      
      debugPrint('AgentRepository: Transfer added successfully - ID: $id');
      return true;
    } catch (e) {
      debugPrint('AgentRepository: Error adding transfer: $e');
      return false;
    }
  }

  @override
  Future<void> addClientRequirement({
    required String id,
    String? companyId,
    required String name,
    required String status,
    String? remarks,
    required String transferDate,
    String? nextWorkingDate,
    String? source,
    List<String>? images,
  }) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      
      await db.into(db.workingProgress).insertOnConflictUpdate(
        WorkingProgressCompanion.insert(
          id: id,
          companyId: isSuperAdmin ? const d.Value.absent() : d.Value(companyId),
          name: name,
          status: d.Value(status),
          remarks: remarks != null && remarks.isNotEmpty ? d.Value(remarks) : const d.Value.absent(),
          fromUser: const d.Value.absent(),
          toUser: const d.Value.absent(),
          transferDate: d.Value(transferDate),
          nextWorkingDate: nextWorkingDate != null ? d.Value(nextWorkingDate) : const d.Value.absent(),
          category: d.Value(source),
          updatedAt: nowIso,
          isSynced: const d.Value(false),
        ),
      );
      
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('working_progress').doc(id).set({
          'id': id,
          if (companyId != null) 'companyId': companyId,
          'name': name,
          'status': status,
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
          'transferDate': transferDate,
          if (nextWorkingDate != null) 'nextWorkingDate': nextWorkingDate,
          'source': source,
          'type': 'client_requirement',
          'updatedAt': nowIso,
          'createdAt': nowIso,
        }, SetOptions(merge: true));
        
        await db.customStatement(
          'UPDATE working_progress SET is_synced = 1 WHERE id = ?',
          <Object>[id],
        );
      });
      
      if (images != null && images.isNotEmpty) {
        await _saveImages(id, images);
      }
      
    } catch (e) {
      debugPrint('Error adding client requirement: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateStatus({
    required String id,
    required String status,
    String? nextWorkingDate,
  }) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final nextDateStr = nextWorkingDate != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(nextWorkingDate!)) : null;
      
      await db.customStatement(
        'UPDATE working_progress SET status = ?, next_working_date = ?, updated_at = ?, is_synced = 0 WHERE id = ?',
        <Object>[status, nextDateStr ?? '', nowIso, id],
      );
      
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('working_progress').doc(id).update({
          'status': status,
          if (nextDateStr != null) 'nextWorkingDate': nextDateStr,
          'updatedAt': nowIso,
        });
        
        await db.customStatement(
          'UPDATE working_progress SET is_synced = 1 WHERE id = ?',
          <Object>[id],
        );
      });
      
    } catch (e) {
      debugPrint('Error updating status: $e');
      rethrow;
    }
  }

  @override
  Future<List<WorkingComment>> getComments(String parentId) async {
    try {
      final result = await db.customSelect(
        'SELECT * FROM working_comments WHERE parent_id = ? ORDER BY updated_at DESC',
        variables: <d.Variable<Object>>[d.Variable.withString(parentId)],
      ).get();
      
      final List<WorkingComment> comments = [];
      for (final row in result) {
        final data = row.data;
        final comment = WorkingComment(
          id: data['id'] as String,
          parentId: data['parent_id'] as String,
          companyId: data['company_id'] as String?,
          comment: data['comment'] as String,
          updatedAt: data['updated_at'] as String,
        );
        comments.add(comment);
      }
      
      return comments;
    } catch (e) {
      debugPrint('Error loading comments: $e');
      return [];
    }
  }

  @override
  Future<void> addComment({
    required String id,
    required String parentId,
    String? companyId,
    required String comment,
  }) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      
      await db.into(db.workingComments).insertOnConflictUpdate(
        WorkingCommentsCompanion.insert(
          id: id,
          parentId: parentId,
          companyId: companyId != null ? d.Value(companyId) : const d.Value.absent(),
          comment: comment,
          updatedAt: nowIso,
        ),
      );
      
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('working_comments').doc(id).set({
          'id': id,
          'parentId': parentId,
          if (companyId != null) 'companyId': companyId,
          'comment': comment,
          'updatedAt': nowIso,
          'createdAt': nowIso,
        }, SetOptions(merge: true));
      });
      
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteComment(String id) async {
    try {
      await db.customStatement('DELETE FROM working_comments WHERE id = ?', <Object>[id]);
      
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('working_comments').doc(id).delete();
      });
      
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    try {
      debugPrint('AgentRepository: Attempting to delete item with ID: $id');
      
      final String cleanId = id.toString().trim();
      debugPrint('Cleaned ID for delete: "$cleanId"');
      
      await db.customStatement(
        'UPDATE working_progress SET is_active = 0, updated_at = ? WHERE id = ?',
        <Object>[DateTime.now().toIso8601String(), cleanId],
      );
      
      debugPrint('AgentRepository: Soft delete completed for ID: $cleanId');
      
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('working_progress').doc(cleanId).delete();
        debugPrint('AgentRepository: Deleted from Firestore: $cleanId');
      });
      
    } catch (e) {
      debugPrint('AgentRepository: Error deleting item: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateEntry({
    required String id,
    String? name,
    String? status,
    String? remarks,
    String? transferDate,
    String? nextWorkingDate,
    String? category,
    String? plotNo,
    String? registryNumber,
    String? size,
    String? clientMobile,
    List<String>? images,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      final updates = <String>[];
      final vars = <d.Variable<Object>>[];
      
      if (name != null) {
        updates.add('name = ?');
        vars.add(d.Variable.withString(name));
      }
      if (status != null) {
        updates.add('status = ?');
        vars.add(d.Variable.withString(status));
      }
      if (remarks != null) {
        updates.add('remarks = ?');
        vars.add(d.Variable.withString(remarks));
      }
      if (transferDate != null) {
        updates.add('transfer_date = ?');
        vars.add(d.Variable.withString(transferDate));
      }
      if (nextWorkingDate != null) {
        updates.add('next_working_date = ?');
        vars.add(d.Variable.withString(nextWorkingDate));
      }
      if (category != null) {
        updates.add('category = ?');
        vars.add(d.Variable.withString(category));
      }
      
      updates.add('updated_at = ?');
      vars.add(d.Variable.withString(now));
      
      if (updates.isNotEmpty) {
        final setClause = updates.join(', ');
        final String targetId = id.toString();
        final List<Object> args = <Object>[];
        for (final variable in vars) {
          args.add(variable.value as Object);
        }
        args.add(targetId);
        await db.customStatement(
          'UPDATE working_progress SET $setClause WHERE id = ?',
          args,
        );
      }
      
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        final updateData = <String, dynamic>{
          'updated_at': now,
        };
        
        if (name != null) updateData['name'] = name;
        if (status != null) updateData['status'] = status;
        if (remarks != null) updateData['remarks'] = remarks;
        if (transferDate != null) updateData['transfer_date'] = transferDate;
        if (nextWorkingDate != null) updateData['next_working_date'] = nextWorkingDate;
        if (category != null) updateData['category'] = category;
        
        await firestore.collection('working_progress').doc(id).update(updateData);
      });
      
    } catch (e) {
      debugPrint('Error updating item: $e');
      rethrow;
    }
  }

  @override
  Future<List<String>> getImages(String parentId) async {
    try {
      return [];
    } catch (e) {
      debugPrint('Error loading images: $e');
      return [];
    }
  }

  @override
  Future<void> updateImages({
    required String parentId,
    required List<String> images,
  }) async {
    try {
      await _saveImages(parentId, images);
    } catch (e) {
      debugPrint('Error updating images: $e');
      rethrow;
    }
  }

  Future<void> _saveImages(String parentId, List<String> images) async {
    final imagesJson = '{"images":${jsonEncode(images)}}';
    
    await db.customStatement(
      'UPDATE working_progress SET remarks = COALESCE(?, remarks), updated_at = ?, is_synced = 0 WHERE id = ?',
      <Object>[imagesJson, DateTime.now().toUtc().toIso8601String(), parentId],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getOfficeNotes() async {
    try {
      // ✅ Windows par empty list return karein
      if (_isWindows || !_isFirestoreOperationAllowed()) {
        debugPrint('AgentRepository: getOfficeNotes skipped (Windows or no Firestore)');
        return [];
      }
      
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('agent_working')
          .doc('office_notes')
          .collection('notes')
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        'text': doc.data()['text']?.toString() ?? '',
        'createdAt': _decodeTimestamp(doc.data()['createdAt']),
      }).toList();
    } catch (e) {
      debugPrint('Error loading office notes: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOtherNotes() async {
    try {
      // ✅ Windows par empty list return karein
      if (_isWindows || !_isFirestoreOperationAllowed()) {
        debugPrint('AgentRepository: getOtherNotes skipped (Windows or no Firestore)');
        return [];
      }
      
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('agent_working')
          .doc('other_notes')
          .collection('notes')
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        'text': doc.data()['text']?.toString() ?? '',
        'createdAt': _decodeTimestamp(doc.data()['createdAt']),
      }).toList();
    } catch (e) {
      debugPrint('Error loading other notes: $e');
      return [];
    }
  }

  @override
  Future<void> addOfficeNote({
    required String id,
    required String text,
    required DateTime createdAt,
  }) async {
    try {
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore
            .collection('agent_working')
            .doc('office_notes')
            .collection('notes')
            .doc(id)
            .set({
          'text': text,
          'createdAt': Timestamp.fromDate(createdAt),
        });
      });
    } catch (e) {
      debugPrint('Error adding office note: $e');
      rethrow;
    }
  }

  @override
  Future<void> addOtherNote({
    required String id,
    required String text,
    required DateTime createdAt,
  }) async {
    try {
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore
            .collection('agent_working')
            .doc('other_notes')
            .collection('notes')
            .doc(id)
            .set({
          'text': text,
          'createdAt': Timestamp.fromDate(createdAt),
        });
      });
    } catch (e) {
      debugPrint('Error adding other note: $e');
      rethrow;
    }
  }

  @override
  Future<List<WorkingProgressData>> getTasksDueToday({
    String? companyId,
    bool isSuperAdmin = false,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final result = await db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM working_progress WHERE next_working_date = ? AND status NOT IN (?, ?)'
            : 'SELECT * FROM working_progress WHERE company_id = ? AND next_working_date = ? AND status NOT IN (?, ?)',
        variables: isSuperAdmin
            ? <d.Variable<Object>>[d.Variable.withString(today), d.Variable.withString('Done'), d.Variable.withString('Closed')]
            : <d.Variable<Object>>[d.Variable.withString(companyId ?? ''), d.Variable.withString(today), d.Variable.withString('Done'), d.Variable.withString('Closed')],
      ).get();
      
      final List<WorkingProgressData> tasks = [];
      for (final row in result) {
        final data = row.data;
        final task = WorkingProgressData(
          id: data['id'] as String,
          companyId: data['company_id'] as String?,
          name: data['name'] as String,
          status: data['status'] as String?,
          remarks: data['remarks'] as String?,
          fromUser: data['from_user'] as String?,
          toUser: data['to_user'] as String?,
          transferDate: data['transfer_date'] as String?,
          nextWorkingDate: data['next_working_date'] as String?,
          category: data['category'] as String?,
          isActive: (data['is_active'] as int? ?? 1) == 1,
          updatedAt: data['updated_at'] as String,
          isSynced: (data['is_synced'] as int? ?? 1) == 1,
        );
        tasks.add(task);
      }
      
      return tasks;
    } catch (e) {
      debugPrint('Error loading tasks due today: $e');
      return [];
    }
  }

  DateTime _decodeTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  @override
  Future<void> generateProfessionalReceipt(String entryId) async {
    debugPrint('Generating professional receipt for entry: $entryId');
    
    try {
      final result = await db.customSelect(
        'SELECT name, status, category FROM working_progress WHERE id = ?',
        variables: <d.Variable<Object>>[d.Variable.withString(entryId)],
      ).getSingleOrNull();
      
      if (result != null) {
        final data = result.data;
        debugPrint('Receipt data: ${data['name']} - ${data['status']} - ${data['category']}');
      }
    } catch (e) {
      debugPrint('Error fetching receipt data: $e');
      rethrow;
    }
  }
}