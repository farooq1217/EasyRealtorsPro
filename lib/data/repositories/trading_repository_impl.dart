// data/repositories/trading_repository_impl.dart
import '../../domain/models/trading_entry.dart';
import '../../domain/repositories/trading_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class TradingRepositoryImpl implements TradingRepository {
  final GeneratedDatabase db;

  TradingRepositoryImpl(this.db);

  @override
  Future<void> addEntry(TradingEntry entry) async {
    final map = entry.toMap();
    final now = DateTime.now().toIso8601String();

    if (entry.entryType == TradingEntryType.file) {
      // --- FILE ENTRY (16 Columns) ---
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
      // --- FORM ENTRY (21 Columns) ---
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
  Future<List<TradingEntry>> getAllEntries() async {
    try {
      final results = await db.customSelect('''
        SELECT * FROM trading_entries 
        WHERE is_active = 1 
        ORDER BY date DESC
      ''').get();
      
      return results.map((row) {
        final data = row.data;
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
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading trading entries: $e');
      return []; // Return empty list on error to prevent crashes
    }
  }

  @override
  Future<void> updateEntry(TradingEntry entry) async {
    // Isi tarah Update ko bhi clean separate kar diya taake error na aaye
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
}