// domain/repositories/trading_repository.dart
import 'dart:async';
import '../models/trading_entry.dart';

abstract class TradingRepository {
  // Basic CRUD operations
  Future<List<TradingEntry>> getAllEntries({String? companyId});
  Future<List<TradingEntry>> getEntriesByType(TradingEntryType entryType, {String? companyId});
  Future<TradingEntry?> getEntryById(String id);
  Future<void> addEntry(TradingEntry entry);
  Future<void> updateEntry(TradingEntry entry);
  Future<void> deleteEntry(String id); // Soft delete
  
  // Stream operations for real-time updates
  Stream<List<TradingEntry>> watchEntries({String? companyId});
  Stream<List<TradingEntry>> watchEntriesByType(TradingEntryType entryType, {String? companyId});
  Stream<TradingEntry?> watchEntryById(String id);
  
  // Search and filtering
  Future<List<TradingEntry>> searchEntries(String query, {String? companyId});
  Stream<List<TradingEntry>> watchSearchEntries(String query, {String? companyId});
  
  // Statistics and analytics
  Future<double> getTotalProfit({String? companyId});
  Future<double> getTotalCommission({String? companyId});
  Future<Map<String, dynamic>> getTradingStatistics({String? companyId});
  
  // Role-based access control
  Future<bool> canUserAccessEntry(String userId, String entryId);
  Future<List<TradingEntry>> getEntriesForUser(String userId, {String? companyId});
  
  // Sync operations
  Future<void> markEntryAsUnsynced(String entryId);
  Future<void> markEntryAsSynced(String entryId);
  Future<List<TradingEntry>> getUnsyncedEntries({String? companyId});
}