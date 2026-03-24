import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show WorkingProgressData, WorkingComment, AppDatabase, WorkingProgressCompanion, WorkingCommentsCompanion;
import 'package:drift/drift.dart' as d;
import 'dart:convert';
import 'agent_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../firestore_sync_service.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;

class AgentRepositoryImpl implements AgentRepository {
  final AppDatabase db;
  final String? companyId;
  final bool isSuperAdmin;
  
  // SQLite-only flag - disables all Firestore operations
  static const bool _sqliteOnlyMode = true;
  
  AgentRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin});

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
  Future<List<WorkingProgressData>> getTransfers({
    String? companyId,
    bool isSuperAdmin = false,
    String? searchQuery,
  }) async {
    try {
      // Build query with explicit type-safe mapping
      final clauses = <String>['1=1']; // Start with true clause
      final vars = <d.Variable<String>>[];
      
      // Add company filter for non-super users
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      // Add search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        clauses.add('(name LIKE ? OR category LIKE ? OR remarks LIKE ?)');
        final searchPattern = '%$searchQuery%';
        vars.addAll([
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
        ]);
      }
      
      // Remove category filtering - fetch all entries for UI filtering
      // The UI will handle filtering by category values
      
      final where = clauses.join(' AND ');
      
      final result = await db.customSelect(
        'SELECT * FROM working_progress WHERE $where ORDER BY updated_at DESC',
        variables: vars,
      ).get();
      
      // Explicit type-safe mapping
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
      // Build query with explicit type-safe mapping
      final clauses = <String>['1=1']; // Start with true clause
      final vars = <d.Variable<String>>[];
      
      // Add company filter for non-super users
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      // Add search filter if provided
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
      
      return db
          .customSelect(
            'SELECT * FROM working_progress WHERE $where ORDER BY updated_at DESC',
            variables: vars,
          )
          .watch()
          .map((result) {
            // Explicit type-safe mapping
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
          });
    } catch (e) {
      debugPrint('Error setting up transfers stream: $e');
      // Return empty stream in case of error
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
      // Build query with explicit type-safe mapping
      final clauses = <String>['1=1']; // Start with true clause
      final vars = <d.Variable<String>>[];
      
      // Add company filter for non-super users
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      // Add search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        clauses.add('(name LIKE ? OR category LIKE ? OR remarks LIKE ?)');
        final searchPattern = '%$searchQuery%';
        vars.addAll([
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
          d.Variable.withString(searchPattern),
        ]);
      }
      
      // Remove category filtering - fetch all entries for UI filtering
      // The UI will handle filtering by category values
      
      final where = clauses.join(' AND ');
      
      final result = await db.customSelect(
        'SELECT * FROM working_progress WHERE $where ORDER BY updated_at DESC',
        variables: vars,
      ).get();
      
      // Explicit type-safe mapping
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
      // Build query with explicit type-safe mapping
      final clauses = <String>['1=1']; // Start with true clause
      final vars = <d.Variable<String>>[];
      
      // Add company filter for non-super users
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      // Add search filter if provided
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
      
      return db
          .customSelect(
            'SELECT * FROM working_progress WHERE $where ORDER BY updated_at DESC',
            variables: vars,
          )
          .watch()
          .map((result) {
            // Explicit type-safe mapping
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
            return requirements;
          });
    } catch (e) {
      debugPrint('Error setting up client requirements stream: $e');
      // Return empty stream in case of error
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
      
      // Save to SQLite first
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
          isSynced: const d.Value(false), // Mark as not synced
        ),
      );
      
      debugPrint('AgentRepository: SQLite insert successful for ID: $id');
      
      // Sync to Firestore if allowed
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
            'type': 'transfer', // Explicitly mark as transfer
            'updatedAt': nowIso,
            'createdAt': nowIso,
          }, SetOptions(merge: true));
          
          // Mark as synced
          await db.customStatement(
            'UPDATE working_progress SET is_synced = 1 WHERE id = ?',
            [id],
          );
          debugPrint('AgentRepository: Firestore sync successful for ID: $id');
        });
      } else {
        debugPrint('AgentRepository: SQLite-only mode, skipping Firestore sync for ID: $id');
        // In SQLite-only mode, mark as synced immediately
        await db.customStatement(
          'UPDATE working_progress SET is_synced = 1 WHERE id = ?',
          [id],
        );
        debugPrint('AgentRepository: Marked as synced in SQLite-only mode for ID: $id');
      }
      
      // Save images if provided
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
      
      // Save to SQLite first
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
          category: d.Value(source), // Store source in category field
          updatedAt: nowIso,
          isSynced: const d.Value(false), // Mark as not synced
        ),
      );
      
      // Sync to Firestore if allowed
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
          'source': source, // Store as source field
          'type': 'client_requirement', // Explicitly mark as client requirement
          'updatedAt': nowIso,
          'createdAt': nowIso,
        }, SetOptions(merge: true));
        
        // Mark as synced
        await db.customStatement(
          'UPDATE working_progress SET is_synced = 1 WHERE id = ?',
          [id],
        );
      });
      
      // Save images if provided
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
      
      // Update SQLite
      await db.customStatement(
        'UPDATE working_progress SET status = ?, next_working_date = ?, updated_at = ?, is_synced = 0 WHERE id = ?',
        [status, nextDateStr ?? '', nowIso, id],
      );
      
      // Update Firestore if allowed
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('working_progress').doc(id).update({
          'status': status,
          if (nextDateStr != null) 'nextWorkingDate': nextDateStr,
          'updatedAt': nowIso,
        });
        
        // Mark as synced
        await db.customStatement(
          'UPDATE working_progress SET is_synced = 1 WHERE id = ?',
          [id],
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
        variables: [d.Variable.withString(parentId)],
      ).get();
      
      // Explicit type-safe mapping
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
      
      // Save to SQLite
      await db.into(db.workingComments).insertOnConflictUpdate(
        WorkingCommentsCompanion.insert(
          id: id,
          parentId: parentId,
          companyId: companyId != null ? d.Value(companyId) : const d.Value.absent(),
          comment: comment,
          updatedAt: nowIso,
        ),
      );
      
      // Sync to Firestore if allowed
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
      // Delete from SQLite
      await db.customStatement('DELETE FROM working_comments WHERE id = ?', [id]);
      
      // Delete from Firestore if allowed
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
      // Delete from SQLite
      await db.customStatement('DELETE FROM working_progress WHERE id = ?', [id]);
      
      // Delete from Firestore if allowed
      await _executeFirestoreOperation(() async {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('working_progress').doc(id).delete();
      });
      
    } catch (e) {
      debugPrint('Error deleting item: $e');
      rethrow;
    }
  }

  @override
  Future<List<String>> getImages(String parentId) async {
    try {
      // For now, return empty list - images are stored as part of the main record
      // This can be extended to use a separate images table if needed
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
    // Store images as JSON string in remarks field temporarily
    // This can be improved with a separate images table
    final imagesJson = '{"images":${jsonEncode(images)}}';
    
    await db.customStatement(
      'UPDATE working_progress SET remarks = COALESCE(?, remarks), updated_at = ?, is_synced = 0 WHERE id = ?',
      [imagesJson, DateTime.now().toUtc().toIso8601String(), parentId],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getOfficeNotes() async {
    try {
      if (!_isFirestoreOperationAllowed()) {
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
      if (!_isFirestoreOperationAllowed()) {
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
            ? [d.Variable.withString(today), d.Variable.withString('Done'), d.Variable.withString('Closed')]
            : [d.Variable.withString(companyId ?? ''), d.Variable.withString(today), d.Variable.withString('Done'), d.Variable.withString('Closed')],
      ).get();
      
      // Explicit type-safe mapping
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
    // Placeholder implementation for receipt generation
    // This will be implemented later with actual PDF generation
    debugPrint('Generating professional receipt for entry: $entryId');
    
    // For now, just log the action
    try {
      final result = await db.customSelect(
        'SELECT name, status, category FROM working_progress WHERE id = ?',
        variables: [d.Variable.withString(entryId)],
      ).getSingleOrNull();
      
      if (result != null) {
        final data = result.data;
        debugPrint('Receipt data: ${data['name']} - ${data['status']} - ${data['category']}');
      }
    } catch (e) {
      debugPrint('Error fetching receipt data: $e');
      // Still throw the error to let the UI handle it
      rethrow;
    }
  }
}
