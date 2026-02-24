// domain/repositories/trading_repository.dart
import '../models/trading_entry.dart';

abstract class TradingRepository {
  Future<List<TradingEntry>> getAllEntries();
  Future<void> addEntry(TradingEntry entry); // UNIFIED: Single method for all entry types
  Future<void> updateEntry(TradingEntry entry);
  Future<void> deleteEntry(String id);
}