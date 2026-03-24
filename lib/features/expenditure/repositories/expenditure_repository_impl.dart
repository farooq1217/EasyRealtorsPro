import 'dart:async';
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import '../../expenditure/models/expenditure_item.dart' as domain;
import 'expenditure_repository.dart';
import 'package:shared/shared.dart';

class ExpenditureRepositoryImpl implements ExpenditureRepository {
  final AppDatabase db;
  
  ExpenditureRepositoryImpl(this.db);

  @override
  Future<List<domain.ExpenditureItem>> getExpenditures(String companyId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM Expenditures WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) ORDER BY date DESC',
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      return rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch Expenditures: $e');
    }
  }

  @override
  Future<List<domain.ExpenditureItem>> getOfficeExpenses(String companyId) async {
    try {
      // CRITICAL: Query for office_expense type to match what we're saving
      final rows = await db.customSelect(
        'SELECT * FROM Expenditures WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type IS NULL) ORDER BY date DESC',
        variables: [d.Variable.withString(companyId), d.Variable.withString('office_expense'), d.Variable.withString('office')],
      ).get();
      
      return rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch office expenses: $e');
    }
  }

  @override
  Future<List<domain.ExpenditureItem>> getProjectExpenses(String companyId) async {
    try {
      // CRITICAL: Query for project_expense and project_bucket types to match what we're saving
      final rows = await db.customSelect(
        'SELECT * FROM Expenditures WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type = ?) ORDER BY date DESC',
        variables: [d.Variable.withString(companyId), d.Variable.withString('project_expense'), d.Variable.withString('project'), d.Variable.withString('project_bucket')],
      ).get();
      
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
        variables: [d.Variable.withString(id)],
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
  Stream<List<domain.ExpenditureItem>> watchExpenditures(String companyId) {
    return db
        .customSelect(
          'SELECT * FROM Expenditures WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) ORDER BY date DESC',
          variables: [d.Variable.withString(companyId)],
        )
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchOfficeExpenses(String companyId) {
    // CRITICAL: Stream for office_expense type to match what we're saving
    return db
        .customSelect(
          'SELECT * FROM Expenditures WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type IS NULL) ORDER BY date DESC',
          variables: [d.Variable.withString(companyId), d.Variable.withString('office_expense'), d.Variable.withString('office')],
        )
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchProjectExpenses(String companyId) {
    // CRITICAL: Stream for project_expense and project_bucket types to match what we're saving
    return db
        .customSelect(
          'SELECT * FROM Expenditures WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) AND (category_type = ? OR category_type = ? OR category_type = ?) ORDER BY date DESC',
          variables: [d.Variable.withString(companyId), d.Variable.withString('project_expense'), d.Variable.withString('project'), d.Variable.withString('project_bucket')],
        )
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
  }

  @override
  Future<List<domain.ExpenditureItem>> searchExpenditures(String companyId, String query) async {
    try {
      final rows = await db.customSelect(
        '''SELECT * FROM Expenditures 
           WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) 
           AND (LOWER(description) LIKE LOWER(?) OR LOWER(amount) LIKE LOWER(?) OR LOWER(date) LIKE LOWER(?))
           ORDER BY date DESC''',
        variables: [
          d.Variable.withString(companyId),
          d.Variable.withString('%$query%'),
          d.Variable.withString('%$query%'),
          d.Variable.withString('%$query%'),
        ],
      ).get();
      
      return rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to search Expenditures: $e');
    }
  }

  @override
  Stream<List<domain.ExpenditureItem>> watchSearchExpenditures(String companyId, String query) {
    return db
        .customSelect(
          '''SELECT * FROM Expenditures 
             WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) 
             AND (LOWER(description) LIKE LOWER(?) OR LOWER(amount) LIKE LOWER(?) OR LOWER(date) LIKE LOWER(?))
             ORDER BY date DESC''',
          variables: [
            d.Variable.withString(companyId),
            d.Variable.withString('%$query%'),
            d.Variable.withString('%$query%'),
            d.Variable.withString('%$query%'),
          ],
        )
        .watch()
        .map((rows) => rows.map((r) => domain.ExpenditureItem.fromMap(r.data)).toList());
  }

  @override
  Future<List<domain.ExpenditureSubItem>> getExpenditureSubItems(String parentId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM expenditure_sub_items WHERE parent_id = ? AND (is_active IS NULL OR is_active = 1) ORDER BY created_at DESC',
        variables: [d.Variable.withString(parentId)],
      ).get();
      
      return rows.map((r) => domain.ExpenditureSubItem.fromMap(r.data)).toList();
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
          // category: subItem.category == null ? const d.Value.absent() : d.Value(subItem.category!), // Temporarily commented
          companyId: subItem.companyId == null ? const d.Value.absent() : d.Value(subItem.companyId!),
          createdBy: subItem.createdBy == null ? const d.Value.absent() : d.Value(subItem.createdBy!),
          isActive: d.Value(subItem.isActive),
          isSynced: d.Value(subItem.isSynced),
          createdAt: subItem.createdAt == null ? const d.Value.absent() : d.Value(subItem.createdAt!),
          updatedAt: subItem.updatedAt ?? DateTime.now().toIso8601String(),
        ),
      );
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
      return (db.select(db.expenditureSubItems)
          ..where((tbl) => tbl.parentId.equals(parentId))
          ..where((tbl) => tbl.isActive.equals(true))
        )
        .watch()
        .map((rows) => rows.map((row) => domain.ExpenditureSubItem.fromMap({
          'id': row.id,
          'parent_id': row.parentId,
          'description': row.description,
          'amount': row.amount,
          'company_id': row.companyId,
          'created_by': row.createdBy,
          'is_active': row.isActive ? 1 : 0,
          'is_synced': row.isSynced ? 1 : 0,
          'created_at': row.createdAt,
          'updated_at': row.updatedAt,
        })).toList());
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

  @override
  Future<double> getTotalOfficeExpenses(String companyId) async {
    try {
      // CRITICAL: Query for office_expense type to match what we're saving
      final rows = await db.customSelect(
        '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ? OR category_type IS NULL)''',
        variables: [d.Variable.withString(companyId), d.Variable.withString('office_expense'), d.Variable.withString('office')],
      ).get();
      
      return double.tryParse(rows.first.data['total']?.toString() ?? '0') ?? 0;
    } catch (e) {
      throw Exception('Failed to calculate total office expenses: $e');
    }
  }

  @override
  Future<double> getTotalProjectExpenses(String companyId) async {
    try {
      // CRITICAL: Query for project_expense type to match what we're saving
      final rows = await db.customSelect(
        '''SELECT COALESCE(SUM(amount), 0) as total FROM Expenditures 
           WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) 
           AND (category_type = ? OR category_type = ?)''',
        variables: [d.Variable.withString(companyId), d.Variable.withString('project_expense'), d.Variable.withString('project')],
      ).get();
      
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
