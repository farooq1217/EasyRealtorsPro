// data/repositories/trading_repository_impl.dart
import 'dart:async';
import '../../domain/models/trading_entry.dart';
import '../../domain/repositories/trading_repository.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';

class TradingRepositoryImpl implements TradingRepository {
  final AppDatabase db;

  TradingRepositoryImpl(this.db);

  @override
  Future<List<TradingEntry>> getAllEntries({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 $whereClause
        ORDER BY date DESC
      ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error loading trading entries: $e');
      return [];
    }
  }

  @override
  Future<List<TradingEntry>> getEntriesByType(TradingEntryType entryType, {String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = [
        d.Variable.withString(entryType.name),
        if (companyId != null) d.Variable.withString(companyId),
      ];
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 AND entry_type = ? $whereClause
        ORDER BY date DESC
      ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error loading trading entries by type: $e');
      return [];
    }
  }

  @override
  Future<TradingEntry?> getEntryById(String id) async {
    try {
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 AND id = ?
      ''', variables: [d.Variable.withString(id)]).get();
      
      if (results.isEmpty) return null;
      return _mapRowToTradingEntry(results.first.data);
    } catch (e) {
      debugPrint('Error loading trading entry by ID: $e');
      return null;
    }
  }

  @override
  Stream<List<TradingEntry>> watchEntries({String? companyId}) {
    final whereClause = companyId != null ? 'AND company_id = ?' : '';
    final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
    
    return db.customSelect('''
      SELECT * FROM trading_entries 
      WHERE is_active = 1 $whereClause
      ORDER BY date DESC
    ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).watch().map((rows) => 
      rows.map((row) => _mapRowToTradingEntry(row.data)).toList()
    );
  }

  @override
  Stream<List<TradingEntry>> watchEntriesByType(TradingEntryType entryType, {String? companyId}) {
    final whereClause = companyId != null ? 'AND company_id = ?' : '';
    final vars = [
      d.Variable.withString(entryType.name),
      if (companyId != null) d.Variable.withString(companyId),
    ];
    
    return db.customSelect('''
      SELECT * FROM trading_entries 
      WHERE is_active = 1 AND entry_type = ? $whereClause
      ORDER BY date DESC
    ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).watch().map((rows) => 
      rows.map((row) => _mapRowToTradingEntry(row.data)).toList()
    );
  }

  @override
  Stream<TradingEntry?> watchEntryById(String id) {
    return db.customSelect('''
      SELECT * FROM trading_entries 
      WHERE is_active = 1 AND id = ?
    ''', variables: [d.Variable.withString(id)]).watch().map((rows) {
      if (rows.isEmpty) return null;
      return _mapRowToTradingEntry(rows.first.data);
    });
  }

  @override
  Future<List<TradingEntry>> searchEntries(String query, {String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = [
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
        d.Variable.withString('%$query%'),
        if (companyId != null) d.Variable.withString(companyId),
      ];
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 AND (
          person_name LIKE ? OR 
          estate_name LIKE ? OR 
          mobile LIKE ? OR
          comments LIKE ?
        ) $whereClause
        ORDER BY date DESC
      ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error searching trading entries: $e');
      return [];
    }
  }

  @override
  Stream<List<TradingEntry>> watchSearchEntries(String query, {String? companyId}) {
    final whereClause = companyId != null ? 'AND company_id = ?' : '';
    final vars = [
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
      d.Variable.withString('%$query%'),
      if (companyId != null) d.Variable.withString(companyId),
    ];
    
    return db.customSelect('''
      SELECT * FROM trading_entries 
      WHERE is_active = 1 AND (
        person_name LIKE ? OR 
        estate_name LIKE ? OR 
        mobile LIKE ? OR
        comments LIKE ?
      ) $whereClause
      ORDER BY date DESC
    ''', variables: vars.map((v) => d.Variable.withString(v.value ?? '')).toList()).watch().map((rows) => 
      rows.map((row) => _mapRowToTradingEntry(row.data)).toList()
    );
  }

  @override
  Future<double> getTotalProfit({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final result = await db.customSelect('''
        SELECT 
          SUM(CASE 
            WHEN type = 'sell' THEN total_amount 
            WHEN type = 'buy' THEN -total_amount 
            ELSE 0 
          END) as profit
        FROM trading_entries 
        WHERE is_active = 1 AND status = 'Completed' $whereClause
      ''', variables: vars.map((v) => d.Variable.withString(v.value)).toList()).get();
      
      return result.first.data['profit'] as double? ?? 0.0;
    } catch (e) {
      debugPrint('Error calculating total profit: $e');
      return 0.0;
    }
  }

  @override
  Future<double> getTotalCommission({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final result = await db.customSelect('''
        SELECT SUM(commission) as total_commission
        FROM trading_entries 
        WHERE is_active = 1 AND entry_type = 'form' AND commission IS NOT NULL $whereClause
      ''', variables: vars.map((v) => d.Variable.withString(v.value)).toList()).get();
      
      return result.first.data['total_commission'] as double? ?? 0.0;
    } catch (e) {
      debugPrint('Error calculating total commission: $e');
      return 0.0;
    }
  }

  @override
  Future<Map<String, dynamic>> getTradingStatistics({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final result = await db.customSelect('''
        SELECT 
          COUNT(*) as total_entries,
          COUNT(CASE WHEN type = 'buy' THEN 1 END) as buy_entries,
          COUNT(CASE WHEN type = 'sell' THEN 1 END) as sell_entries,
          COUNT(CASE WHEN entry_type = 'form' THEN 1 END) as form_entries,
          COUNT(CASE WHEN entry_type = 'file' THEN 1 END) as file_entries,
          COUNT(CASE WHEN status = 'Completed' THEN 1 END) as completed_entries,
          COUNT(CASE WHEN status = 'Pending' THEN 1 END) as pending_entries,
          SUM(total_amount) as total_amount,
          SUM(CASE WHEN type = 'sell' THEN total_amount ELSE 0 END) as sell_amount,
          SUM(CASE WHEN type = 'buy' THEN total_amount ELSE 0 END) as buy_amount,
          SUM(commission) as total_commission
        FROM trading_entries 
        WHERE is_active = 1 $whereClause
      ''', variables: vars.map((v) => d.Variable.withString(v.value)).toList()).get();
      
      final data = result.first.data;
      return {
        'totalEntries': data['total_entries'] as int? ?? 0,
        'buyEntries': data['buy_entries'] as int? ?? 0,
        'sellEntries': data['sell_entries'] as int? ?? 0,
        'formEntries': data['form_entries'] as int? ?? 0,
        'fileEntries': data['file_entries'] as int? ?? 0,
        'completedEntries': data['completed_entries'] as int? ?? 0,
        'pendingEntries': data['pending_entries'] as int? ?? 0,
        'totalAmount': data['total_amount'] as double? ?? 0.0,
        'sellAmount': data['sell_amount'] as double? ?? 0.0,
        'buyAmount': data['buy_amount'] as double? ?? 0.0,
        'totalCommission': data['total_commission'] as double? ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting trading statistics: $e');
      return {};
    }
  }

  @override
  Future<bool> canUserAccessEntry(String userId, String entryId) async {
    try {
      final result = await db.customSelect('''
        SELECT COUNT(*) as count
        FROM trading_entries 
        WHERE id = ? AND is_active = 1 AND (created_by = ? OR company_id IN (
          SELECT company_id FROM users WHERE id = ?
        ))
      ''', variables: [
        d.Variable.withString(entryId),
        d.Variable.withString(userId),
        d.Variable.withString(userId),
      ]).get();
      
      return (result.first.data['count'] as int? ?? 0) > 0;
    } catch (e) {
      debugPrint('Error checking user access: $e');
      return false;
    }
  }

  @override
  Future<List<TradingEntry>> getEntriesForUser(String userId, {String? companyId}) async {
    try {
      final whereClauses = ['is_active = 1', 'created_by = ?'];
      final vars = [d.Variable.withString(userId)];
      
      if (companyId != null) {
        whereClauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      final whereClause = whereClauses.join(' AND ');
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE $whereClause
        ORDER BY date DESC
      ''', variables: vars).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error getting entries for user: $e');
      return [];
    }
  }

  @override
  Future<void> markEntryAsUnsynced(String entryId) async {
    await db.customStatement('''
      UPDATE trading_entries SET is_synced = 0, updated_at = ? 
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), entryId]);
  }

  @override
  Future<void> markEntryAsSynced(String entryId) async {
    await db.customStatement('''
      UPDATE trading_entries SET is_synced = 1, updated_at = ? 
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), entryId]);
  }

  @override
  Future<List<TradingEntry>> getUnsyncedEntries({String? companyId}) async {
    try {
      final whereClause = companyId != null ? 'AND company_id = ?' : '';
      final vars = companyId != null ? [d.Variable.withString(companyId)] : [];
      
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 AND is_synced = 0 $whereClause
        ORDER BY updated_at DESC
      ''', variables: vars.map((v) => d.Variable.withString(v)).toList()).get();
      
      return results.map((row) => _mapRowToTradingEntry(row.data)).toList();
    } catch (e) {
      debugPrint('Error getting unsynced entries: $e');
      return [];
    }
  }

  @override
  Future<void> addEntry(TradingEntry entry) async {
    final map = entry.toMap();
    final now = DateTime.now().toIso8601String();

    if (entry.entryType == TradingEntryType.file) {
      const sql = '''INSERT INTO trading_entries (
          id, company_id, created_by, entry_type, type, date, mobile, person_name, 
          estate_name, quantity, total_amount, status, 
          comments, is_active, is_synced, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''';

      await db.customStatement(sql, [
        map['id'],
        map['company_id'] ?? '',
        map['created_by'] ?? '',
        map['entry_type'],
        map['type'],
        map['date'],
        map['mobile'],
        map['person_name'],
        map['estate_name'],
        map['quantity'],
        map['total_amount'],
        map['status'],
        map['comments'],
        1, // is_active
        1, // is_synced
        now, // updated_at
      ]);
    } else {
      const sql = '''INSERT INTO trading_entries (
          id, company_id, created_by, entry_type, type, date, mobile, person_name, 
          estate_name, plot_no, block, commission, tax, quantity, rate, total_amount, 
          status, is_active, is_synced, comments, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''';

      await db.customStatement(sql, [
        map['id'],
        map['company_id'] ?? '',
        map['created_by'] ?? '',
        map['entry_type'],
        map['type'],
        map['date'],
        map['mobile'],
        map['person_name'],
        map['estate_name'],
        map['plot_no'],
        map['block'],
        map['commission'],
        map['tax'],
        map['quantity'],
        map['rate'],
        map['total_amount'],
        map['status'],
        1, // is_active
        1, // is_synced
        map['comments'],
        now, // updated_at
      ]);
    }
  }

  @override
  Future<void> updateEntry(TradingEntry entry) async {
    final map = entry.toMap();
    final now = DateTime.now().toIso8601String();

    if (entry.entryType == TradingEntryType.file) {
      await db.customStatement('''UPDATE trading_entries SET
          type = ?, date = ?, person_name = ?, mobile = ?, estate_name = ?, 
          quantity = ?, total_amount = ?, status = ?, comments = ?, updated_at = ?
        WHERE id = ?''', [
        map['type'], map['date'], map['person_name'], map['mobile'], map['estate_name'],
        map['quantity'], map['total_amount'], map['status'], map['comments'], now, map['id']
      ]);
    } else {
      await db.customStatement('''UPDATE trading_entries SET
          type = ?, date = ?, person_name = ?, mobile = ?, estate_name = ?, 
          plot_no = ?, block = ?, commission = ?, quantity = ?, rate = ?, 
          total_amount = ?, status = ?, comments = ?, updated_at = ?
        WHERE id = ?''', [
        map['type'], map['date'], map['person_name'], map['mobile'], map['estate_name'],
        map['plot_no'], map['block'], map['commission'], map['quantity'], map['rate'],
        map['total_amount'], map['status'], map['comments'], now, map['id']
      ]);
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    await db.customStatement('''
      UPDATE trading_entries SET is_active = 0, updated_at = ? WHERE id = ?
    ''', [DateTime.now().toIso8601String(), id]);
  }

  // Helper method to map database row to TradingEntry
  TradingEntry _mapRowToTradingEntry(Map<String, dynamic> data) {
    final entryType = data['entry_type'] == 'file' ? TradingEntryType.file : TradingEntryType.form;
    
    return TradingEntry(
      id: data['id'],
      type: data['type'] == 'buy' ? TradingType.buy : TradingType.sell,
      entryType: entryType,
      date: DateTime.parse(data['date']),
      personName: data['person_name'] ?? '',
      mobile: data['mobile'] ?? '',
      estateName: data['estate_name'] ?? '',
      plotNo: data['plot_no'],
      block: data['block'],
      quantity: int.tryParse(data['quantity']?.toString() ?? '0') ?? 0,
      rate: double.tryParse(data['rate']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0,
      commission: double.tryParse(data['commission']?.toString() ?? '0') ?? 0.0,
      tax: double.tryParse(data['tax']?.toString() ?? '0') ?? 0.0,
      status: data['status'] ?? 'Pending',
      comments: data['comments'],
      companyId: data['company_id'],
      createdBy: data['created_by'],
    );
  }
}