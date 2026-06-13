import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../expenditure/models/expenditure_item.dart' as domain;
import 'expenditure_repository.dart';
import 'package:shared/shared.dart';
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import '../../../core/services/firebase_threading_handler.dart';

class ExpenditureRepositoryImpl implements ExpenditureRepository {
  final AppDatabase db;
  final String? companyId;
  final bool isSuperAdmin;
  final String? userId; // Add userId for Agent filtering
  
  // Platform detection for thread safety
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  ExpenditureRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin, this.userId});

  // Helper method to wrap streams with platform thread safety
  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    if (_isWindows) {
      debugPrint('ExpenditureRepository: Wrapping $streamName with Windows thread safety');
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'ExpenditureRepository $streamName',
      );
    }
    return stream;
  }

  @override
  Future<List<domain.ExpenditureItem>> getExpenditures(String? companyId) async {
    try {
      // CRITICAL FIX: Strict company filtering for data leakage prevention
      String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1)';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[];
      
      // Use provided companyId or fall back to instance companyId
      final effectiveCompanyId = companyId ?? this.companyId;
      
      if (!isSuperAdmin) {
        // For non-super-admins, ALWAYS require companyId and never allow null
        if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
          debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin, returning empty results');
          return []; // Return empty list for security
        }
        query += ' AND company_id = ?';
        variables.add(d.Variable.withString(effectiveCompanyId));
        
        // CRITICAL FIX: Add created_by filtering for Agent role
        // This ensures Agents can only see their own expenditures
        if (userId != null) {
          query += ' AND created_by = ?'; // Strict filtering - only user's own records
          variables.add(d.Variable.withString(userId ?? ''));
        } else {
          debugPrint('ExpenditureRepository: SECURITY - No userId for Agent filtering, returning empty results');
          return []; // Return empty list for security
        }
        
        debugPrint('ExpenditureRepository: SECURITY - Filtering expenditures by company: $effectiveCompanyId');
        debugPrint('ExpenditureRepository: SECURITY - Agent created_by filtering applied for user: $userId');
      }
      // Super Admin: No company filtering (can see all data)
      
      query += ' ORDER BY date DESC';
      
      final rows = await db.customSelect(query, variables: variables).get();
      
      return rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch Expenditures: $e');
    }
  }

  @override
  Future<List<domain.ExpenditureItem>> getOfficeExpenses(String? companyId) async {
    try {
      // CRITICAL FIX: Strict company filtering for data leakage prevention
      // Query for office_expense type to match what we're saving
      String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type IS NULL)';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('office_expense'), 
        d.Variable.withString('office')
      ];
      
      // Use provided companyId or fall back to instance companyId
      final effectiveCompanyId = companyId ?? this.companyId;
      
      if (!isSuperAdmin) {
        // For non-super-admins, ALWAYS require companyId and never allow null
        if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
          debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin office expenses, returning empty results');
          return []; // Return empty list for security
        }
        query += ' AND company_id = ?';
        variables.add(d.Variable.withString(effectiveCompanyId));
        
        // CRITICAL FIX: Add created_by filtering for Agent role
        if (userId != null) {
          query += ' AND created_by = ?'; // Strict filtering - only user's own records
          variables.add(d.Variable.withString(userId ?? ''));
        } else {
          debugPrint('ExpenditureRepository: SECURITY - No userId for Agent filtering, returning empty results');
          return []; // Return empty list for security
        }
        
        debugPrint('ExpenditureRepository: SECURITY - Filtering office expenses by company: $effectiveCompanyId');
        debugPrint('ExpenditureRepository: SECURITY - Agent created_by filtering applied for user: $userId');
      }
      // Super Admin: No company filtering (can see all data)
      
      query += ' ORDER BY date DESC';
      
      final rows = await db.customSelect(query, variables: variables).get();
      
      return rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch office expenses: $e');
    }
  }

  @override
  Future<List<domain.ExpenditureItem>> getProjectExpenses(String? companyId) async {
    try {
      // CRITICAL FIX: Strict company filtering for data leakage prevention
      // Query for project_expense and project_bucket types to match what we're saving
      String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type = ?)';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('project_expense'), 
        d.Variable.withString('project'), 
        d.Variable.withString('project_bucket')
      ];
      
      // Use provided companyId or fall back to instance companyId
      final effectiveCompanyId = companyId ?? this.companyId;
      
      if (!isSuperAdmin) {
        // For non-super-admins, ALWAYS require companyId and never allow null
        if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
          debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin project expenses, returning empty results');
          return []; // Return empty list for security
        }
        query += ' AND company_id = ?';
        variables.add(d.Variable.withString(effectiveCompanyId));
        
        // CRITICAL FIX: Add created_by filtering for Agent role
        if (userId != null) {
          query += ' AND created_by = ?'; // Strict filtering - only user's own records
          variables.add(d.Variable.withString(userId ?? ''));
        } else {
          debugPrint('ExpenditureRepository: SECURITY - No userId for Agent filtering, returning empty results');
          return []; // Return empty list for security
        }
        
        debugPrint('ExpenditureRepository: SECURITY - Filtering project expenses by company: $effectiveCompanyId');
        debugPrint('ExpenditureRepository: SECURITY - Agent created_by filtering applied for user: $userId');
      }
      // Super Admin: No company filtering (can see all data)
      
      query += ' ORDER BY date DESC';
      
      final rows = await db.customSelect(query, variables: variables).get();
      
      return rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch project expenses: $e');
    }
  }

  @override
  Future<domain.ExpenditureItem?> getExpenditureById(String id) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM Expenditures WHERE id = ? AND (is_active IS NULL OR is_active = 1)',
        variables: <d.Variable<Object>>[d.Variable.withString(id)],
      ).get();
      
      if (rows.isEmpty) return null;
      return domain.ExpenditureItem.fromMap(rows.first.data);
    } catch (e) {
      throw Exception('Failed to fetch expenditure: $e');
    }
  }

  @override
  Future<void> addExpenditure(domain.ExpenditureItem expenditure) async {
    final now = DateTime.now();
    final expenditureWithTimestamp = expenditure.copyWith(
      id: expenditure.id.isEmpty ? const Uuid().v4() : expenditure.id,
      createdAt: now,
      updatedAt: now,
    );
    
    try {
      // CRITICAL FIX: Use Drift's high-level API for proper stream notifications
      await db.into(db.expenditures).insert(
        ExpendituresCompanion.insert(
          id: expenditureWithTimestamp.id,
          date: expenditureWithTimestamp.date,
          description: expenditureWithTimestamp.description,
          amount: expenditureWithTimestamp.amount,
          category: d.Value(expenditureWithTimestamp.category),
          categoryType: d.Value(expenditureWithTimestamp.categoryType ?? 'office'),
          companyId: expenditureWithTimestamp.companyId == null 
              ? const d.Value.absent() 
              : d.Value(expenditureWithTimestamp.companyId!),
          createdBy: expenditureWithTimestamp.createdBy == null 
              ? const d.Value.absent() 
              : d.Value(expenditureWithTimestamp.createdBy!),
          createdAt: d.Value(expenditureWithTimestamp.createdAt.toIso8601String()),
          updatedAt: expenditureWithTimestamp.updatedAt.toIso8601String(),
          isActive: d.Value(expenditureWithTimestamp.isActive),
          isSynced: d.Value(Firebase.apps.isEmpty),
        ),
      );
      
      debugPrint('ExpenditureRepository: Successfully inserted expenditure: ${expenditureWithTimestamp.id}');
    } catch (e) {
      debugPrint('ExpenditureRepository: Error inserting expenditure: $e');
      // Fallback to customStatement if Drift fails - use the same timestamped variable
      try {
        final isSyncedVal = Firebase.apps.isNotEmpty ? 0 : 1;
        await db.customStatement(
          '''INSERT INTO Expenditures 
             (id, date, description, amount, category, category_type, company_id, created_by, created_at, updated_at, is_active, is_synced)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            expenditureWithTimestamp.id,
            expenditureWithTimestamp.date,
            expenditureWithTimestamp.description,
            expenditureWithTimestamp.amount,
            expenditureWithTimestamp.category,
            expenditureWithTimestamp.categoryType ?? 'office',
            expenditureWithTimestamp.companyId,
            expenditureWithTimestamp.createdBy,
            expenditureWithTimestamp.createdAt.toIso8601String(),
            expenditureWithTimestamp.updatedAt.toIso8601String(),
            expenditureWithTimestamp.isActive ? 1 : 0,
            isSyncedVal,
          ],
        );
        debugPrint('ExpenditureRepository: Fallback insert successful for expenditure: ${expenditureWithTimestamp.id}');
      } catch (fallbackError) {
        debugPrint('ExpenditureRepository: Fallback insert also failed: $fallbackError');
        throw Exception('Failed to add expenditure: $e (Fallback: $fallbackError)');
      }
    }
  }

  @override
  Future<void> updateExpenditure(domain.ExpenditureItem expenditure) async {
    final now = DateTime.now();
    final updatedExpenditure = expenditure.copyWith(updatedAt: now);
    
    try {
      // CRITICAL FIX: Use Drift's high-level API for proper stream notifications
      await (db.update(db.expenditures)..where((tbl) => tbl.id.equals(updatedExpenditure.id)))
          .write(ExpendituresCompanion(
        date: d.Value(updatedExpenditure.date),
        description: d.Value(updatedExpenditure.description),
        amount: d.Value(updatedExpenditure.amount),
        category: d.Value(updatedExpenditure.category),
        categoryType: d.Value(updatedExpenditure.categoryType),
        updatedAt: d.Value(updatedExpenditure.updatedAt.toIso8601String()),
        isActive: d.Value(updatedExpenditure.isActive),
        isSynced: d.Value(Firebase.apps.isEmpty),
      ));
      
      debugPrint('ExpenditureRepository: Successfully updated expenditure: ${updatedExpenditure.id}');
    } catch (e) {
      debugPrint('ExpenditureRepository: Error updating expenditure: $e');
      // Fallback to customStatement if Drift fails
      try {
        final isSyncedVal = Firebase.apps.isNotEmpty ? 0 : 1;
        await db.customStatement(
          '''UPDATE Expenditures SET 
             date = ?, description = ?, amount = ?, category = ?, category_type = ?, 
             updated_at = ?, is_active = ?, is_synced = ? 
             WHERE id = ?''',
          [
            updatedExpenditure.date,
            updatedExpenditure.description,
            updatedExpenditure.amount,
            updatedExpenditure.category,
            updatedExpenditure.categoryType,
            updatedExpenditure.updatedAt.toIso8601String(),
            updatedExpenditure.isActive ? 1 : 0,
            isSyncedVal,
            updatedExpenditure.id,
          ],
        );
        debugPrint('ExpenditureRepository: Fallback update successful for expenditure: ${updatedExpenditure.id}');
      } catch (fallbackError) {
        debugPrint('ExpenditureRepository: Fallback update also failed: $fallbackError');
        throw Exception('Failed to update expenditure: $e (Fallback: $fallbackError)');
      }
    }
  }

  @override
  Future<void> deleteExpenditure(String id) async {
    try {
      // OPTIMIZATION: Check if record exists before attempting deletion
      final existingRecord = await db.customSelect(
        'SELECT id, is_active FROM Expenditures WHERE id = ?',
        variables: [d.Variable.withString(id)]
      ).getSingleOrNull();
      
      if (existingRecord == null) {
        debugPrint('ExpenditureRepository: Record not found, skipping deletion: $id');
        return; // Record doesn't exist, no need to delete
      }
      
      final isActive = existingRecord.data['is_active'] as int?;
      if (isActive == 0) {
        debugPrint('ExpenditureRepository: Record already deleted (inactive), skipping: $id');
        return; // Already deleted, no need to delete again
      }
      
      // CRITICAL FIX: Use Drift's high-level API for proper stream notifications
      await (db.update(db.expenditures)..where((tbl) => tbl.id.equals(id)))
          .write(ExpendituresCompanion(
            isActive: const d.Value(false),
            isSynced: d.Value(Firebase.apps.isEmpty),
          ));
      
      debugPrint('ExpenditureRepository: Successfully deleted expenditure: $id');
    } catch (e) {
      debugPrint('ExpenditureRepository: Error deleting expenditure: $e');
      // Fallback to customStatement if Drift fails
      try {
        final isSyncedVal = Firebase.apps.isNotEmpty ? 0 : 1;
        await db.customStatement('UPDATE Expenditures SET is_active = 0, is_synced = ? WHERE id = ?', [isSyncedVal, id]);
        debugPrint('ExpenditureRepository: Fallback delete successful for expenditure: $id');
      } catch (fallbackError) {
        debugPrint('ExpenditureRepository: Fallback delete also failed: $fallbackError');
        throw Exception('Failed to delete expenditure: $e (Fallback: $fallbackError)');
      }
    }
  }

  @override
  @override
  Stream<List<domain.ExpenditureItem>> watchExpenditures(String? companyId) {
    // CRITICAL FIX: Strict company filtering for data leakage prevention
    String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1)';
    List<d.Variable<Object>> variables = <d.Variable<Object>>[];
    
    // Use provided companyId or fall back to instance companyId
    final effectiveCompanyId = companyId ?? this.companyId;
    
    if (!isSuperAdmin) {
      // For non-super-admins, ALWAYS require companyId and never allow null
      if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
        debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin watch, returning empty stream');
        return Stream.value([]); // Return empty stream for security
      }
      query += ' AND company_id = ?';
      variables.add(d.Variable.withString(effectiveCompanyId));
      debugPrint('ExpenditureRepository: SECURITY - Watch filtering expenditures by company: $effectiveCompanyId');
    }
    // Super Admin: No company filtering (can see all data)
    
    query += ' ORDER BY date DESC';
    
    final stream = db
        .customSelect(query, variables: variables, readsFrom: {db.expenditures})
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
    return _wrapStreamWithThreadSafety(stream, 'watchExpenditures');
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchOfficeExpenses(String? companyId) {
    // CRITICAL FIX: Strict company filtering for data leakage prevention
    // Stream for office_expense type to match what we're saving
    String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type IS NULL)';
    List<d.Variable<Object>> variables = <d.Variable<Object>>[
      d.Variable.withString('office_expense'), 
      d.Variable.withString('office')
    ];
    
    // Use provided companyId or fall back to instance companyId
    final effectiveCompanyId = companyId ?? this.companyId;
    
    if (!isSuperAdmin) {
      // For non-super-admins, ALWAYS require companyId and never allow null
      if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
        debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin office expenses watch, returning empty stream');
        return Stream.value([]); // Return empty stream for security
      }
      query += ' AND company_id = ?';
      variables.add(d.Variable.withString(effectiveCompanyId));
      debugPrint('ExpenditureRepository: SECURITY - Watch filtering office expenses by company: $effectiveCompanyId');
    }
    // Super Admin: No company filtering (can see all data)
    
    query += ' ORDER BY date DESC';
    
    final stream = db
        .customSelect(query, variables: variables, readsFrom: {db.expenditures})
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
    return _wrapStreamWithThreadSafety(stream, 'watchOfficeExpenses');
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchProjectExpenses(String? companyId) {
    // CRITICAL FIX: Strict company filtering for data leakage prevention
    // Stream for project_expense and project_bucket types to match what we're saving
    String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type = ?)';
    List<d.Variable<Object>> variables = <d.Variable<Object>>[
      d.Variable.withString('project_expense'), 
      d.Variable.withString('project'), 
      d.Variable.withString('project_bucket')
    ];
    
    // Use provided companyId or fall back to instance companyId
    final effectiveCompanyId = companyId ?? this.companyId;
    
    if (!isSuperAdmin) {
      // For non-super-admins, ALWAYS require companyId and never allow null
      if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
        debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin project expenses watch, returning empty stream');
        return Stream.value([]); // Return empty stream for security
      }
      query += ' AND company_id = ?';
      variables.add(d.Variable.withString(effectiveCompanyId));
      debugPrint('ExpenditureRepository: SECURITY - Watch filtering project expenses by company: $effectiveCompanyId');
    }
    // Super Admin: No company filtering (can see all data)
    
    query += ' ORDER BY date DESC';
    
    final stream = db
        .customSelect(query, variables: variables, readsFrom: {db.expenditures})
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
    return _wrapStreamWithThreadSafety(stream, 'watchProjectExpenses');
  }

  @override
  Future<List<domain.ExpenditureItem>> searchExpenditures(String? companyId, String query) async {
    try {
      // CRITICAL FIX: Strict company filtering for data leakage prevention
      String sqlQuery = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1)';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
      ];
      
      // Use provided companyId or fall back to instance companyId
      final effectiveCompanyId = companyId ?? this.companyId;
      
      if (!isSuperAdmin) {
        // For non-super-admins, ALWAYS require companyId and never allow null
        if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
          debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin search, returning empty results');
          return []; // Return empty list for security
        }
        sqlQuery += ' AND company_id = ?';
        variables.insert(0, d.Variable.withString(effectiveCompanyId));
        debugPrint('ExpenditureRepository: SECURITY - Filtering search expenditures by company: $effectiveCompanyId');
      }
      // Super Admin: No company filtering (can see all data)
      
      sqlQuery += ' AND (LOWER(description) LIKE LOWER(?) OR LOWER(amount) LIKE LOWER(?) OR LOWER(date) LIKE LOWER(?)) ORDER BY date DESC';
      
      final rows = await db.customSelect(sqlQuery, variables: variables).get();
      
      return rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to search Expenditures: $e');
    }
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchSearchExpenditures(String? companyId, String query) {
    // CRITICAL FIX: Strict company filtering for data leakage prevention
    String sqlQuery = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1)';
    List<d.Variable<Object>> variables = <d.Variable<Object>>[
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
    ];
    
    // Use provided companyId or fall back to instance companyId
    final effectiveCompanyId = companyId ?? this.companyId;
    
    if (!isSuperAdmin) {
      // For non-super-admins, ALWAYS require companyId and never allow null
      if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
        debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin search watch, returning empty stream');
        return Stream.value([]); // Return empty stream for security
      }
      sqlQuery += ' AND company_id = ?';
      variables.insert(0, d.Variable.withString(effectiveCompanyId));
      debugPrint('ExpenditureRepository: SECURITY - Filtering search watch expenditures by company: $effectiveCompanyId');
    }
    // Super Admin: No company filtering (can see all data)
    
    sqlQuery += ' AND (LOWER(description) LIKE LOWER(?) OR LOWER(amount) LIKE LOWER(?) OR LOWER(date) LIKE LOWER(?)) ORDER BY date DESC';
    
    final stream = db
        .customSelect(sqlQuery, variables: variables, readsFrom: {db.expenditures})
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
    return _wrapStreamWithThreadSafety(stream, 'watchSearchExpenditures');
  }

  @override
  Future<List<domain.ExpenditureSubItem>> getExpenditureSubItems(String parentId) async {
    try {
      // CRITICAL: First try with category column, fallback to without if it doesn't exist
      try {
        final rows = await db.customSelect(
          'SELECT id, parent_id, description, amount, category, company_id, created_by, is_active, is_synced, created_at, updated_at '
          'FROM expenditure_sub_items '
          'WHERE parent_id = ? AND (is_active IS NULL OR is_active = 1) '
          'ORDER BY created_at DESC',
          variables: [d.Variable.withString(parentId)],
        ).get();
        
        return rows.map((r) => domain.ExpenditureSubItem.fromMap(r.data)).toList();
      } catch (e) {
        // Fallback: Query without category column if it doesn't exist
        debugPrint('ExpenditureRepository: Category column missing, using fallback query');
        final rows = await db.customSelect(
          'SELECT id, parent_id, description, amount, company_id, created_by, is_active, is_synced, created_at, updated_at '
          'FROM expenditure_sub_items '
          'WHERE parent_id = ? AND (is_active IS NULL OR is_active = 1) '
          'ORDER BY created_at DESC',
          variables: [d.Variable.withString(parentId)],
        ).get();
        
        return rows.map((row) {
          final data = Map<String, dynamic>.from(row.data);
          data['category'] = null; // Add null category for compatibility
          return domain.ExpenditureSubItem.fromMap(data);
        }).toList();
      }
    } catch (e) {
      throw Exception('Failed to fetch expenditure sub-items: $e');
    }
  }

  @override
  Future<void> addExpenditureSubItem(domain.ExpenditureSubItem subItem) async {
    try {
      // CRITICAL FIX: Ensure category column exists before inserting
      await ensureExpenditureSubItemsCategoryColumn();
      
      // First, insert the basic sub-item without category
      await db.into(db.expenditureSubItems).insert(
        ExpenditureSubItemsCompanion.insert(
          id: subItem.id,
          parentId: subItem.parentId,
          description: subItem.description,
          amount: subItem.amount,
          companyId: subItem.companyId == null ? const d.Value.absent() : d.Value(subItem.companyId!),
          createdBy: subItem.createdBy == null ? const d.Value.absent() : d.Value(subItem.createdBy!),
          isActive: d.Value(subItem.isActive),
          isSynced: d.Value(subItem.isSynced),
          createdAt: subItem.createdAt == null ? const d.Value.absent() : d.Value(subItem.createdAt!),
          updatedAt: subItem.updatedAt ?? DateTime.now().toIso8601String(),
        ),
      );
      
      // CRITICAL FIX: Now update with category to ensure it's properly saved
      if (subItem.category != null && subItem.category!.isNotEmpty) {
        try {
          await db.customStatement(
            'UPDATE expenditure_sub_items SET category = ? WHERE id = ?',
            [subItem.category, subItem.id],
          );
          debugPrint('ExpenditureRepository: Category "${subItem.category}" saved for sub-item ${subItem.id}');
        } catch (e) {
          debugPrint('ExpenditureRepository: Failed to save category for sub-item: $e');
          // Don't rethrow - the sub-item was still created, just without category
        }
      }
    } catch (e) {
      throw Exception('Failed to add expenditure sub-item: $e');
    }
  }

  @override
  Future<void> deleteExpenditureSubItem(String id) async {
    try {
      await (db.delete(db.expenditureSubItems)..where((tbl) => tbl.id.equals(id))).go();
    } catch (e) {
      throw Exception('Failed to delete expenditure sub-item: $e');
    }
  }

  @override
  @override
  Stream<List<domain.ExpenditureSubItem>> watchExpenditureSubItems(String parentId) {
    try {
      // CRITICAL: First try with category column, fallback to without if it doesn't exist
      Stream<List<domain.ExpenditureSubItem>> stream;
      try {
        stream = db.customSelect(
          'SELECT id, parent_id, description, amount, category, company_id, created_by, is_active, is_synced, created_at, updated_at '
          'FROM expenditure_sub_items '
          'WHERE parent_id = ? AND (is_active IS NULL OR is_active = 1) '
          'ORDER BY created_at DESC',
          variables: [d.Variable.withString(parentId)],
          readsFrom: {db.expenditureSubItems},
        )
        .watch()
        .map((rows) => rows.map((row) => domain.ExpenditureSubItem.fromMap(row.data)).toList());
      } catch (e) {
        // Fallback: Query without category column if it doesn't exist
        debugPrint('ExpenditureRepository: Category column missing, using fallback query');
        stream = db.customSelect(
          'SELECT id, parent_id, description, amount, company_id, created_by, is_active, is_synced, created_at, updated_at '
          'FROM expenditure_sub_items '
          'WHERE parent_id = ? AND (is_active IS NULL OR is_active = 1) '
          'ORDER BY created_at DESC',
          variables: [d.Variable.withString(parentId)],
          readsFrom: {db.expenditureSubItems},
        )
        .watch()
        .map((rows) => rows.map((row) {
          final data = Map<String, dynamic>.from(row.data);
          data['category'] = null; // Add null category for compatibility
          return domain.ExpenditureSubItem.fromMap(data);
        }).toList());
      }
      return _wrapStreamWithThreadSafety(stream, 'watchExpenditureSubItems');
    } catch (e) {
      throw Exception('Failed to watch expenditure sub-items: $e');
    }
  }

  // Helper method to safely add columns with comprehensive duplicate error handling
  Future<void> _addColumnSafely(String tableName, String columnName, String columnType) async {
    try {
      await db.customStatement('ALTER TABLE $tableName ADD COLUMN $columnName $columnType');
      debugPrint('ExpenditureRepository: $columnName column added successfully to $tableName');
    } catch (e) {
      // CRITICAL: Comprehensive error handling for SQLite duplicate column errors
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('duplicate column name') || 
          errorMessage.contains('code 1') || 
          errorMessage.contains('syntax error') ||
          errorMessage.contains('already exists')) {
        debugPrint('ExpenditureRepository: $columnName column already exists in $tableName - ignoring duplicate column error');
      } else {
        debugPrint('ExpenditureRepository: $columnName column addition failed for $tableName: $e');
        // Don't rethrow - allow app to continue even if column addition fails
      }
    }
  }

  @override
  Future<void> ensureExpenditureTableColumns() async {
    try {
      // OPTIMIZATION: Faster column check with early exit
      final cols = await db.customSelect('PRAGMA table_info(Expenditures)').get();
      final columnNames = cols.map((r) => r.data['name']?.toString()).toList();
      debugPrint('ExpenditureRepository: Found existing columns: $columnNames');
      
      // FIXED: Use helper method for all column additions with tableName parameter
      final operations = <Future<void>>[];
      if (!columnNames.contains('category_type')) {
        operations.add(_addColumnSafely('Expenditures', 'category_type', 'TEXT'));
      }
      if (!columnNames.contains('kind')) {
        operations.add(_addColumnSafely('Expenditures', 'kind', 'TEXT'));
      }
      if (!columnNames.contains('project_id')) {
        operations.add(_addColumnSafely('Expenditures', 'project_id', 'TEXT'));
      }
      if (!columnNames.contains('category')) {
        operations.add(_addColumnSafely('Expenditures', 'category', 'TEXT'));
      }
      if (!columnNames.contains('office_month')) {
        operations.add(_addColumnSafely('Expenditures', 'office_month', 'TEXT'));
      }
      if (!columnNames.contains('is_active')) {
        operations.add(_addColumnSafely('Expenditures', 'is_active', 'INTEGER DEFAULT 1'));
      }
      if (!columnNames.contains('is_synced')) {
        operations.add(_addColumnSafely('Expenditures', 'is_synced', 'INTEGER DEFAULT 1'));
      }
      if (!columnNames.contains('created_at')) {
        operations.add(_addColumnSafely('Expenditures', 'created_at', 'TEXT'));
      }
      if (!columnNames.contains('updated_at')) {
        operations.add(_addColumnSafely('Expenditures', 'updated_at', 'TEXT'));
      }
      
      // Execute all operations in parallel for speed
      await Future.wait(operations);
      debugPrint('ExpenditureRepository: Table columns optimization completed - ${operations.length} operations processed');
      
      // FIXED: Add safe column existence checks to prevent duplicate column errors
    } catch (e) {
      debugPrint('ExpenditureRepository: Failed to ensure expenditure table columns: $e');
      // Don't throw - allow app to continue even if column checks fail
    }
  }

  @override
  Future<void> ensureExpenditureItemsTable() async {
    // No-op since expenditure_items table doesn't exist in schema
    // Sub-items functionality is disabled
  }

  /// CRITICAL: Ensure category column exists in expenditure_sub_items table with enhanced safety
  Future<void> ensureExpenditureSubItemsCategoryColumn() async {
    try {
      debugPrint('ExpenditureRepository: Starting enhanced safe category column check');
      
      // ENHANCED: Use the safe column addition method
      await _addColumnSafely('expenditure_sub_items', 'category', 'TEXT');
      
      debugPrint('ExpenditureRepository: Enhanced safe category column check completed');
    } catch (e) {
      debugPrint('ExpenditureRepository: Error ensuring category column: $e');
      // Don't throw - allow app to continue even if column addition fails
    }
  }

  @override
  Future<double> getTotalOfficeExpenses(String? companyId) async {
    try {
      // CRITICAL FIX: Strict company filtering for data leakage prevention
      // Query for office_expense type to match what we're saving
      String query = '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ? OR category_type IS NULL)''';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('office_expense'), 
        d.Variable.withString('office')
      ];
      
      // Use provided companyId or fall back to instance companyId
      final effectiveCompanyId = companyId ?? this.companyId;
      
      if (!isSuperAdmin) {
        // For non-super-admins, ALWAYS require companyId and never allow null
        if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
          debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin total office expenses, returning 0');
          return 0.0; // Return 0 for security
        }
        query = '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ? OR category_type IS NULL)''';
        variables.insert(0, d.Variable.withString(effectiveCompanyId));
        debugPrint('ExpenditureRepository: SECURITY - Filtering total office expenses by company: $effectiveCompanyId');
      }
      // Super Admin: No company filtering (can see all data)
      
      final rows = await db.customSelect(query, variables: variables).get();
      
      return double.tryParse(rows.first.data['total']?.toString() ?? '0') ?? 0;
    } catch (e) {
      throw Exception('Failed to calculate total office expenses: $e');
    }
  }

  @override
  Future<double> getTotalProjectExpenses(String? companyId) async {
    try {
      // CRITICAL FIX: Strict company filtering for data leakage prevention
      // Query for project_expense and project_bucket types to match what we're saving
      String query = '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ?)''';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('project_expense'), 
        d.Variable.withString('project')
      ];
      
      // Use provided companyId or fall back to instance companyId
      final effectiveCompanyId = companyId ?? this.companyId;
      
      if (!isSuperAdmin) {
        // For non-super-admins, ALWAYS require companyId and never allow null
        if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
          debugPrint('ExpenditureRepository: SECURITY - No companyId for non-super-admin total project expenses, returning 0');
          return 0.0; // Return 0 for security
        }
        query = '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ?)''';
        variables.insert(0, d.Variable.withString(effectiveCompanyId));
        debugPrint('ExpenditureRepository: SECURITY - Filtering total project expenses by company: $effectiveCompanyId');
      }
      // Super Admin: No company filtering (can see all data)
      
      final rows = await db.customSelect(query, variables: variables).get();
      
      return double.tryParse(rows.first.data['total']?.toString() ?? '0') ?? 0;
    } catch (e) {
      throw Exception('Failed to calculate total project expenses: $e');
    }
  }

  @override
  Future<double> getTotalExpenditureWithSubItems(String expenditureId) async {
    try {
      // Get main expenditure amount
      final mainRows = await db.customSelect(
        'SELECT amount FROM Expenditures WHERE id = ? AND (is_active IS NULL OR is_active = 1)',
        variables: [d.Variable.withString(expenditureId)],
      ).get();
      
      final mainAmount = mainRows.isEmpty 
          ? 0.0 
          : double.tryParse(mainRows.first.data['amount']?.toString() ?? '0') ?? 0;
      
      // Sub-items functionality is disabled, return only main amount
      return mainAmount;
    } catch (e) {
      throw Exception('Failed to calculate total expenditure: $e');
    }
  }

  @override
  Future<domain.ExpenditureItem?> findExistingOfficeExpense(String date, String category, String companyId) async {
    try {
      debugPrint('ExpenditureRepository: Searching for existing office expense - Date: $date, Category: $category, Company: $companyId');
      
      final query = '''SELECT * FROM Expenditures 
        WHERE date = ? 
        AND category = ?
        AND company_id = ? 
        AND (category_type = ? OR category_type = ? OR kind = ?)
        AND (is_active IS NULL OR is_active = 1)
        ORDER BY created_at DESC
        LIMIT 1''';
      
      final variables = <d.Variable<Object>>[
        d.Variable.withString(date),
        d.Variable.withString(category),
        d.Variable.withString(companyId),
        d.Variable.withString('office_expense'),
        d.Variable.withString('office'),
        d.Variable.withString('office'),
      ];
      
      final rows = await db.customSelect(query, variables: variables).get();
      
      if (rows.isNotEmpty) {
        final existingExpense = domain.ExpenditureItem.fromMap(rows.first.data);
        debugPrint('ExpenditureRepository: Found existing office expense: ${existingExpense.id}');
        return existingExpense;
      }
      
      debugPrint('ExpenditureRepository: No existing office expense found');
      return null;
    } catch (e) {
      debugPrint('ExpenditureRepository: Error finding existing office expense: $e');
      return null;
    }
  }

  @override
  Future<void> updateExpenditureAmount(String expenditureId, double newAmount) async {
    try {
      debugPrint('ExpenditureRepository: Updating expenditure amount - ID: $expenditureId, New Amount: $newAmount');
      
      // CRITICAL FIX: Use Drift's high-level API for proper stream notifications
      await (db.update(db.expenditures)..where((tbl) => tbl.id.equals(expenditureId)))
          .write(ExpendituresCompanion(
        amount: d.Value(newAmount),
        updatedAt: d.Value(DateTime.now().toIso8601String()),
      ));
      
      debugPrint('ExpenditureRepository: Successfully updated expenditure amount with stream notification');
    } catch (e) {
      debugPrint('ExpenditureRepository: Error updating expenditure amount: $e');
      // Fallback to customStatement if Drift fails
      try {
        final now = DateTime.now().toIso8601String();
        await db.customStatement('''UPDATE Expenditures SET
          amount = ?, 
          updated_at = ?
          WHERE id = ?''', [newAmount, now, expenditureId]);
        debugPrint('ExpenditureRepository: Fallback update successful for expenditure amount');
      } catch (fallbackError) {
        debugPrint('ExpenditureRepository: Fallback update also failed: $fallbackError');
        throw Exception('Failed to update expenditure amount: $e (Fallback: $fallbackError)');
      }
    }
  }
}
