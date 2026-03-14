// domain/repositories/report_repository.dart
import 'dart:typed_data';
import 'package:shared/shared.dart' show WorkingProgressData, Expenditure, RentalItem, TradingEntry, Reminder;

/// Repository interface for Reports and Professional Receipt Generation module operations
abstract class ReportRepository {
  // Professional Receipt Generation
  Future<Uint8List> generateProfessionalReceipt({
    required String entryId,
    required String entryType, // 'transfer' or 'requirement'
    Map<String, dynamic>? companyInfo,
    String? logoPath,
  });

  // Reports Dashboard Data
  Future<List<WorkingProgressData>> getAgentWorkingReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
    String? societyId,
    String? agentId,
  });

  Future<List<Map<String, dynamic>>> getInventoryReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
    String? societyId,
    String? blockId,
    String? status,
  });

  Future<List<Expenditure>> getExpenditureReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
    String? category,
    String? kind,
  });

  Future<List<RentalItem>> getRentalReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
  });

  Future<List<Reminder>> getTodoReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
  });

  Future<List<TradingEntry>> getTradingReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
  });

  // Summary Statistics
  Future<Map<String, dynamic>> getReportSummary({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
  });

  // Export Functions
  Future<Uint8List> exportToPdf({
    required String reportType,
    required List<Map<String, dynamic>> data,
    Map<String, dynamic>? summary,
    Map<String, dynamic>? companyInfo,
  });

  Future<Uint8List> exportToCsv({
    required String reportType,
    required List<Map<String, dynamic>> data,
  });

  // Company Information
  Future<Map<String, dynamic>?> getCompanyInfo(String? companyId);
}
