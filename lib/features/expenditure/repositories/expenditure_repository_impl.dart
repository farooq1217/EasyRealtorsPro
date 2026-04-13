import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import '../../expenditure/models/expenditure_item.dart' as domain;
import 'expenditure_repository.dart';
import 'package:shared/shared.dart';

class ExpenditureRepositoryImpl implements ExpenditureRepository {
  final AppDatabase db;
  
  ExpenditureRepositoryImpl(this.db);

  @override
  Future<List<domain.ExpenditureItem>> getExpenditures(String? companyId) async {
    try {
      String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1)';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[];
      
      if (companyId != null) {
        query += ' AND company_id = ?';
        variables.add(d.Variable.withString(companyId));
      }
      
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
      // CRITICAL: Query for office_expense type to match what we're saving
      String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type IS NULL)';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('office_expense'), 
        d.Variable.withString('office')
      ];
      
      if (companyId != null) {
        query += ' AND company_id = ?';
        variables.add(d.Variable.withString(companyId));
      }
      
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
      // CRITICAL: Query for project_expense and project_bucket types to match what we're saving
      String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type = ?)';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('project_expense'), 
        d.Variable.withString('project'), 
        d.Variable.withString('project_bucket')
      ];
      
      if (companyId != null) {
        query += ' AND company_id = ?';
        variables.add(d.Variable.withString(companyId));
      }
      
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
    String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1)';
    List<d.Variable<Object>> variables = <d.Variable<Object>>[];
    
    if (companyId != null) {
      query += ' AND company_id = ?';
      variables.add(d.Variable.withString(companyId));
    }
    
    query += ' ORDER BY date DESC';
    
    return db
        .customSelect(query, variables: variables)
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchOfficeExpenses(String? companyId) {
    // CRITICAL: Stream for office_expense type to match what we're saving
    String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type IS NULL)';
    List<d.Variable<Object>> variables = <d.Variable<Object>>[
      d.Variable.withString('office_expense'), 
      d.Variable.withString('office')
    ];
    
    if (companyId != null) {
      query += ' AND company_id = ?';
      variables.add(d.Variable.withString(companyId));
    }
    
    query += ' ORDER BY date DESC';
    
    return db
        .customSelect(query, variables: variables)
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchProjectExpenses(String? companyId) {
    // CRITICAL: Stream for project_expense and project_bucket types to match what we're saving
    String query = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type = ?)';
    List<d.Variable<Object>> variables = <d.Variable<Object>>[
      d.Variable.withString('project_expense'), 
      d.Variable.withString('project'), 
      d.Variable.withString('project_bucket')
    ];
    
    if (companyId != null) {
      query += ' AND company_id = ?';
      variables.add(d.Variable.withString(companyId));
    }
    
    query += ' ORDER BY date DESC';
    
    return db
        .customSelect(query, variables: variables)
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
  }

  @override
  Future<List<domain.ExpenditureItem>> searchExpenditures(String? companyId, String query) async {
    try {
      String sqlQuery = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1)';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
      ];
      
      if (companyId != null) {
        sqlQuery += ' AND company_id = ?';
        variables.insert(0, d.Variable.withString(companyId));
      }
      
      sqlQuery += ' AND (LOWER(description) LIKE LOWER(?) OR LOWER(amount) LIKE LOWER(?) OR LOWER(date) LIKE LOWER(?)) ORDER BY date DESC';
      
      final rows = await db.customSelect(sqlQuery, variables: variables).get();
      
      return rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to search Expenditures: $e');
    }
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchSearchExpenditures(String? companyId, String query) {
    String sqlQuery = 'SELECT * FROM Expenditures WHERE (is_active IS NULL OR is_active = 1)';
    List<d.Variable<Object>> variables = <d.Variable<Object>>[
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
    ];
    
    if (companyId != null) {
      sqlQuery += ' AND company_id = ?';
      variables.insert(0, d.Variable.withString(companyId));
    }
    
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
      
      // CRITICAL: Since the generated companion doesn't include category, 
      // we need to update it separately - but only if the column exists
      if (subItem.category != null) {
        try {
          await db.customStatement(
            'UPDATE expenditure_sub_items SET category = ? WHERE id = ?',
            [subItem.category, subItem.id],
          );
          debugPrint('ExpenditureRepository: Category saved successfully: ${subItem.category}');
        } catch (e) {
          // If category column doesn't exist, log but don't fail
          debugPrint('ExpenditureRepository: Category column missing, category not saved: $e');
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
      final cols = await db.customSelect('PRAGMA table_info(Expenditures)').get();
      final columnNames = cols.map((r) => r.data['name']?.toString()).toList();
      
      if (!columnNames.contains('category_type')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN category_type TEXT');
      }
      if (!columnNames.contains('kind')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN kind TEXT');
      }
      if (!columnNames.contains('project_id')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN project_id TEXT');
      }
      if (!columnNames.contains('category')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN category TEXT');
      }
      if (!columnNames.contains('office_month')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN office_month TEXT');
      }
      if (!columnNames.contains('is_active')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN is_active INTEGER DEFAULT 1');
      }
      if (!columnNames.contains('is_synced')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN is_synced INTEGER DEFAULT 1');
      }
      if (!columnNames.contains('created_at')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN created_at TEXT');
      }
      if (!columnNames.contains('updated_at')) {
        await db.customStatement('ALTER TABLE Expenditures ADD COLUMN updated_at TEXT');
      }
    } catch (e) {
      throw Exception('Failed to ensure expenditure table columns: $e');
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
      debugPrint('ExpenditureRepository: Starting category column check');
      
      // First, try to add the column directly (this will fail if it already exists, which is fine)
      try {
        await db.customStatement('ALTER TABLE expenditure_sub_items ADD COLUMN category TEXT');
        debugPrint('ExpenditureRepository: Category column added successfully');
      } catch (e) {
        // Column might already exist, which is fine
        debugPrint('ExpenditureRepository: Category column addition failed (might already exist): $e');
      }
      
      // Now verify the column exists
      final cols = await db.customSelect('PRAGMA table_info(expenditure_sub_items)').get();
      final columnNames = cols.map((r) => r.data['name']?.toString()).toList();
      debugPrint('ExpenditureRepository: Found columns: $columnNames');
      
      if (columnNames.contains('category')) {
        debugPrint('ExpenditureRepository: Category column verified to exist');
      } else {
        debugPrint('ExpenditureRepository: WARNING: Category column still missing after addition attempt');
      }
    } catch (e) {
      debugPrint('ExpenditureRepository: Error ensuring category column: $e');
      // Don't throw - allow the app to continue even if column addition fails
    }
  }

  @override
  Future<double> getTotalOfficeExpenses(String? companyId) async {
    try {
      // CRITICAL: Query for office_expense type to match what we're saving
      String query = '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ? OR category_type IS NULL)''';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('office_expense'), 
        d.Variable.withString('office')
      ];
      
      if (companyId != null) {
        query = '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ? OR category_type IS NULL)''';
        variables.insert(0, d.Variable.withString(companyId));
      }
      
      final rows = await db.customSelect(query, variables: variables).get();
      
      return double.tryParse(rows.first.data['total']?.toString() ?? '0') ?? 0;
    } catch (e) {
      throw Exception('Failed to calculate total office expenses: $e');
    }
  }

  @override
  Future<double> getTotalProjectExpenses(String? companyId) async {
    try {
      // CRITICAL: Query for project_expense and project_bucket types to match what we're saving
      String query = '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ?)''';
      List<d.Variable<Object>> variables = <d.Variable<Object>>[
        d.Variable.withString('project_expense'), 
        d.Variable.withString('project')
      ];
      
      if (companyId != null) {
        query = '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ?)''';
        variables.insert(0, d.Variable.withString(companyId));
      }
      
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
