import 'dart:async';
import '../../expenditure/models/expenditure_item.dart';

abstract class ExpenditureRepository {
  // Main expenditure operations
  Future<List<ExpenditureItem>> getExpenditures(String? companyId);
  Future<List<ExpenditureItem>> getOfficeExpenses(String? companyId);
  Future<List<ExpenditureItem>> getProjectExpenses(String? companyId);
  Future<ExpenditureItem?> getExpenditureById(String id);
  Future<void> addExpenditure(ExpenditureItem expenditure);
  Future<void> updateExpenditure(ExpenditureItem expenditure);
  Future<void> deleteExpenditure(String id);
  
  // Stream operations for real-time updates
  Stream<List<ExpenditureItem>> watchExpenditures(String? companyId);
  Stream<List<ExpenditureItem>> watchOfficeExpenses(String? companyId);
  Stream<List<ExpenditureItem>> watchProjectExpenses(String? companyId);
  
  // Search functionality
  Future<List<ExpenditureItem>> searchExpenditures(String? companyId, String query);
  Stream<List<ExpenditureItem>> watchSearchExpenditures(String? companyId, String query);
  
  // Sub-item operations
  Future<List<ExpenditureSubItem>> getExpenditureSubItems(String parentId);
  Future<void> addExpenditureSubItem(ExpenditureSubItem subItem);
  Future<void> deleteExpenditureSubItem(String id);
  Stream<List<ExpenditureSubItem>> watchExpenditureSubItems(String parentId);
  
  // Database schema management
  Future<void> ensureExpenditureTableColumns();
  Future<void> ensureExpenditureItemsTable();
  
  // Statistics and totals
  Future<double> getTotalOfficeExpenses(String? companyId);
  Future<double> getTotalProjectExpenses(String? companyId);
  Future<double> getTotalExpenditureWithSubItems(String expenditureId);
}
