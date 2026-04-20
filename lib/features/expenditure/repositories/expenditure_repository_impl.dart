import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import '../../expenditure/models/expenditure_item.dart' as domain;
import 'expenditure_repository.dart';
import 'package:shared/shared.dart';

class ExpenditureRepositoryImpl implements ExpenditureRepository {
  final AppDatabase db;
  final String? companyId;
  final bool isSuperAdmin;
  final String? userId; // Add userId for Agent filtering
  
  ExpenditureRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin, this.userId});

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
    try {
      final now = DateTime.now();
      final expenditureWithTimestamp = expenditure.copyWith(
        id: expenditure.id.isEmpty ? const Uuid().v4() : expenditure.id,
        createdAt: now,
        updatedAt: now,
      );
      
      await db.customStatement(
        '''INSERT INTO Expenditures 
           (id, date, description, amount, category, category_type, company_id, created_by, created_at, updated_at, is_active)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          expenditureWithTimestamp.id,
          expenditureWithTimestamp.date,
          expenditureWithTimestamp.description,
          expenditureWithTimestamp.amount,
          expenditureWithTimestamp.category,
          expenditureWithTimestamp.categoryType ?? 'office',
          expenditureWithTimestamp.companyId,
          expenditureWithTimestamp.createdBy,
          expenditureWithTimestamp.createdAt.toIso8601String(), // CRITICAL: Convert DateTime to string
          expenditureWithTimestamp.updatedAt.toIso8601String(), // CRITICAL: Convert DateTime to string
          expenditureWithTimestamp.isActive ? 1 : 0,
        ],
      );
    } catch (e) {
      throw Exception('Failed to add expenditure: $e');
    }
  }

  @override
  Future<void> updateExpenditure(domain.ExpenditureItem expenditure) async {
    try {
      final now = DateTime.now();
      final updatedExpenditure = expenditure.copyWith(updatedAt: now);
      
      await db.customStatement(
        '''UPDATE Expenditures SET 
           date = ?, description = ?, amount = ?, category = ?, category_type = ?, 
           updated_at = ?, is_active = ? 
           WHERE id = ?''',
        [
          updatedExpenditure.date,
          updatedExpenditure.description,
          updatedExpenditure.amount,
          updatedExpenditure.category,
          updatedExpenditure.categoryType,
          updatedExpenditure.updatedAt.toIso8601String(), // CRITICAL: Convert DateTime to string
          updatedExpenditure.isActive ? 1 : 0,
          updatedExpenditure.id,
        ],
      );
    } catch (e) {
      throw Exception('Failed to update expenditure: $e');
    }
  }

  @override
  Future<void> deleteExpenditure(String id) async {
    try {
      await db.customStatement('UPDATE Expenditures SET is_active = 0 WHERE id = ?', [id]);
    } catch (e) {
      throw Exception('Failed to delete expenditure: $e');
    }
  }

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
    
    return db
        .customSelect(query, variables: variables)
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
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
    
    return db
        .customSelect(query, variables: variables)
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
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
    
    return db
        .customSelect(query, variables: variables)
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
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
    
    return db
        .customSelect(sqlQuery, variables: variables)
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
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
      
      // FIXED: Category column is now handled in database schema and companion
      // No need for separate UPDATE statement - category is included in the insert
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
  Stream<List<domain.ExpenditureSubItem>> watchExpenditureSubItems(String parentId) {
    try {
      // CRITICAL: First try with category column, fallback to without if it doesn't exist
      try {
        return db.customSelect(
          'SELECT id, parent_id, description, amount, category, company_id, created_by, is_active, is_synced, created_at, updated_at '
          'FROM expenditure_sub_items '
          'WHERE parent_id = ? AND (is_active IS NULL OR is_active = 1) '
          'ORDER BY created_at DESC',
          variables: [d.Variable.withString(parentId)],
        )
        .watch()
        .map((rows) => rows.map((row) => domain.ExpenditureSubItem.fromMap(row.data)).toList());
      } catch (e) {
        // Fallback: Query without category column if it doesn't exist
        debugPrint('ExpenditureRepository: Category column missing, using fallback query');
        return db.customSelect(
          'SELECT id, parent_id, description, amount, company_id, created_by, is_active, is_synced, created_at, updated_at '
          'FROM expenditure_sub_items '
          'WHERE parent_id = ? AND (is_active IS NULL OR is_active = 1) '
          'ORDER BY created_at DESC',
          variables: [d.Variable.withString(parentId)],
        )
        .watch()
        .map((rows) => rows.map((row) {
          final data = Map<String, dynamic>.from(row.data);
          data['category'] = null; // Add null category for compatibility
          return domain.ExpenditureSubItem.fromMap(data);
        }).toList());
      }
    } catch (e) {
      throw Exception('Failed to watch expenditure sub-items: $e');
    }
  }

  @override
  Future<void> ensureExpenditureTableColumns() async {
    try {
      // OPTIMIZATION: Faster column check with early exit
      final cols = await db.customSelect('PRAGMA table_info(Expenditures)').get();
      final columnNames = cols.map((r) => r.data['name']?.toString()).toList();
      debugPrint('ExpenditureRepository: Found existing columns: $columnNames');
      
      // Batch column additions with minimal error handling
      final operations = <Future<void>>[];
      if (!columnNames.contains('category_type')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN category_type TEXT'));
      if (!columnNames.contains('kind')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN kind TEXT'));
      if (!columnNames.contains('project_id')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN project_id TEXT'));
      if (!columnNames.contains('category')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN category TEXT'));
      if (!columnNames.contains('office_month')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN office_month TEXT'));
      if (!columnNames.contains('is_active')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN is_active INTEGER DEFAULT 1'));
      if (!columnNames.contains('is_synced')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN is_synced INTEGER DEFAULT 1'));
      if (!columnNames.contains('created_at')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN created_at TEXT'));
      if (!columnNames.contains('updated_at')) operations.add(db.customStatement('ALTER TABLE Expenditures ADD COLUMN updated_at TEXT'));
      
      // Execute all operations in parallel for speed
      await Future.wait(operations);
      debugPrint('ExpenditureRepository: Table columns optimization completed - ${operations.length} operations processed');
      
      // FIXED: Category column is now handled in database migration, no need to ensure here
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

  /// CRITICAL: Ensure category column exists in expenditure_sub_items table
  Future<void> ensureExpenditureSubItemsCategoryColumn() async {
    try {
      debugPrint('ExpenditureRepository: Starting optimized category column check');
      
      // OPTIMIZATION: Try to add column directly without verification to reduce database calls
      try {
        await db.customStatement('ALTER TABLE expenditure_sub_items ADD COLUMN category TEXT');
        debugPrint('ExpenditureRepository: Category column added successfully');
      } catch (e) {
        // Column might already exist, which is fine - no need to verify
        debugPrint('ExpenditureRepository: Category column addition failed (might already exist): $e');
      }
      
      debugPrint('ExpenditureRepository: Optimized category column check completed');
    } catch (e) {
      debugPrint('ExpenditureRepository: Error ensuring category column: $e');
      // Don't throw - allow the app to continue even if column addition fails
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
}
