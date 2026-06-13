// data/repositories/report_repository_impl.dart
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:shared/shared.dart' show AppDatabase, WorkingProgressData, Expenditure;
import 'package:drift/drift.dart' as d;
import '../../domain/repositories/report_repository.dart';
import '../../core/services/app_storage.dart' show AppStorage;
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';

class ReportRepositoryImpl implements ReportRepository {
  final AppDatabase db;
  final String? companyId;
  final bool isSuperAdmin;
  
  ReportRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin});

  @override
  Future<Uint8List> generateProfessionalReceipt({
    required String entryId,
    required String entryType,
    Map<String, dynamic>? companyInfo,
    String? logoPath,
  }) async {
    try {
      // Fetch entry data
      final entryData = await _getEntryData(entryId, entryType);
      if (entryData == null) {
        throw Exception('Entry not found');
      }

      // Create PDF document
      final pdf = pw.Document();
      
      // Load fonts (using default fonts for now)
      final baseFont = await PdfGoogleFonts.nunitoRegular();
      final boldFont = await PdfGoogleFonts.nunitoBold();
      
      // Build PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with company info
                _buildReceiptHeader(companyInfo, baseFont, boldFont),
                
                pw.SizedBox(height: 30),
                
                // Receipt title
                pw.Text(
                  'PROFESSIONAL RECEIPT',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange800,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                
                pw.SizedBox(height: 20),
                
                // Entry details
                _buildReceiptDetails(entryData, entryType, baseFont, boldFont),
                
                pw.SizedBox(height: 30),
                
                // Footer
                _buildReceiptFooter(companyInfo, baseFont, boldFont),
              ],
            );
          },
        ),
      );
      
      return await pdf.save();
    } catch (e) {
      debugPrint('Error generating professional receipt: $e');
      rethrow;
    }
  }

  pw.Widget _buildReceiptHeader(Map<String, dynamic>? companyInfo, pw.Font baseFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (companyInfo != null) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyInfo['name'] ?? 'Company Name',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (companyInfo['address'] != null)
                    pw.Text(
                      companyInfo['address'],
                      style: pw.TextStyle(font: baseFont, fontSize: 12),
                    ),
                  if (companyInfo['contact'] != null)
                    pw.Text(
                      'Contact: ${companyInfo['contact']}',
                      style: pw.TextStyle(font: baseFont, fontSize: 12),
                    ),
                ],
              ),
              pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'LOGO',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.Divider(thickness: 2, color: PdfColors.orange800),
        ] else ...[
          pw.Text(
            'PROFESSIONAL RECEIPT',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          pw.Divider(thickness: 2, color: PdfColors.orange800),
        ],
      ],
    );
  }

  pw.Widget _buildReceiptDetails(Map<String, dynamic> entryData, String entryType, pw.Font baseFont, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Receipt ID', entryData['id'] ?? 'N/A', baseFont, boldFont),
          _buildDetailRow('Type', entryType == 'transfer' ? 'Transfer' : 'Client Requirement', baseFont, boldFont),
          _buildDetailRow('Owner Name', entryData['name'] ?? 'N/A', baseFont, boldFont),
          if (entryData['category'] != null)
            _buildDetailRow('Category', entryData['category'], baseFont, boldFont),
          if (entryData['transferDate'] != null)
            _buildDetailRow('Date', _formatDate(entryData['transferDate']), baseFont, boldFont),
          if (entryData['status'] != null)
            _buildDetailRow('Status', entryData['status'], baseFont, boldFont),
          if (entryData['remarks'] != null && entryData['remarks'].toString().isNotEmpty)
            _buildDetailRow('Remarks', entryData['remarks'], baseFont, boldFont),
          if (entryData['nextWorkingDate'] != null)
            _buildDetailRow('Next Working Date', _formatDate(entryData['nextWorkingDate']), baseFont, boldFont),
        ],
      ),
    );
  }

  pw.Widget _buildDetailRow(String label, String value, pw.Font baseFont, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: baseFont, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptFooter(Map<String, dynamic>? companyInfo, pw.Font baseFont, pw.Font boldFont) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        if (companyInfo != null) ...[
          pw.Text(
            companyInfo['address'] ?? 'Company Address',
            style: pw.TextStyle(font: baseFont, fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Email: ${companyInfo['email'] ?? 'company@example.com'} | Phone: ${companyInfo['contact'] ?? 'N/A'}',
            style: pw.TextStyle(font: baseFont, fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Text(
          'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
          style: pw.TextStyle(
            font: baseFont,
            fontSize: 10,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _getEntryData(String entryId, String entryType) async {
    try {
      final result = await db.customSelect(
        'SELECT * FROM working_progress WHERE id = ?',
        variables: [d.Variable.withString(entryId)],
      ).getSingleOrNull();
      
      if (result != null) {
        return result.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching entry data: $e');
      return null;
    }
  }

  @override
  Future<List<WorkingProgressData>> getAgentWorkingReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
    String? societyId,
    String? agentId,
  }) async {
    try {
      // Build query with explicit type-safe mapping
      final clauses = <String>['1=1'];
      final vars = <d.Variable<String>>[];
      
      // Add company filter for non-super users
      final skipCompanyFilter = isSuperAdmin || companyId == 'GLOBAL_ADMIN';
      if (!skipCompanyFilter && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      // Add date range filter
      if (startDate != null) {
        clauses.add('transfer_date >= ?');
        vars.add(d.Variable.withString(startDate));
      }
      if (endDate != null) {
        clauses.add('transfer_date <= ?');
        vars.add(d.Variable.withString(endDate));
      }
      
      final where = clauses.join(' AND ');
      
      final result = await db.customSelect(
        'SELECT * FROM working_progress WHERE $where ORDER BY transfer_date DESC',
        variables: vars,
      ).get();
      
      // Explicit type-safe mapping
      final List<WorkingProgressData> entries = [];
      for (final row in result) {
        final data = row.data;
        final entry = WorkingProgressData(
          id: data['id'] as String,
          companyId: data['company_id'] as String?,
          name: data['name'] as String,
          status: data['status'] as String?,
          remarks: data['remarks'] as String?,
          fromUser: data['from_user'] as String?,
          toUser: data['to_user'] as String?,
          transferDate: data['transfer_date'] as String?,
          nextWorkingDate: data['next_working_date'] as String?,
          category: data['category'] as String?,
          isActive: (data['is_active'] as int? ?? 1) == 1,
          updatedAt: data['updated_at'] as String,
          isSynced: (data['is_synced'] as int? ?? 1) == 1,
        );
        entries.add(entry);
      }
      
      return entries;
    } catch (e) {
      debugPrint('Error loading agent working report: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getInventoryReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
    String? societyId,
    String? blockId,
    String? status,
  }) async {
    try {
      // Build query for inventory data
      final clauses = <String>['is_active = 1'];
      final vars = <d.Variable<String>>[];
      
      // Add company filter for non-super users
      final skipCompanyFilter = isSuperAdmin || companyId == 'GLOBAL_ADMIN';
      if (!skipCompanyFilter && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      // Add date range filter
      if (startDate != null) {
        clauses.add('updated_at >= ?');
        vars.add(d.Variable.withString(startDate));
      }
      if (endDate != null) {
        clauses.add('updated_at <= ?');
        vars.add(d.Variable.withString(endDate));
      }
      
      // Add society filter
      if (societyId != null) {
        clauses.add('society_id = ?');
        vars.add(d.Variable.withString(societyId));
      }
      
      // Add block filter
      if (blockId != null) {
        clauses.add('block_id = ?');
        vars.add(d.Variable.withString(blockId));
      }
      
      // Add status filter
      if (status != null) {
        clauses.add('sale_status = ?');
        vars.add(d.Variable.withString(status));
      }
      
      final where = clauses.join(' AND ');
      
      // Query both files_table and properties
      final filesResult = await db.customSelect(
        'SELECT *, "Files" as type FROM files_table WHERE $where ORDER BY updated_at DESC',
        variables: vars,
      ).get();
      
      final propertiesResult = await db.customSelect(
        'SELECT *, "Properties" as type FROM properties WHERE $where ORDER BY updated_at DESC',
        variables: vars,
      ).get();
      
      // Combine results with explicit type casting
      final List<Map<String, dynamic>> inventory = [];
      
      for (final row in filesResult) {
        final data = row.data;
        inventory.add({
          'id': data['id'] as String,
          'type': data['type'] as String,
          'name': data['name'] as String,
          'clientName': data['client_name'] as String?,
          'fileNo': data['file_no'] as String?,
          'demand': data['demand'] as int?,
          'saleStatus': data['sale_status'] as String?,
          'societyId': data['society_id'] as String?,
          'blockId': data['block_id'] as String?,
          'updatedAt': data['updated_at'] as String,
        });
      }
      
      for (final row in propertiesResult) {
        final data = row.data;
        inventory.add({
          'id': data['id'] as String,
          'type': data['type'] as String,
          'name': data['property_name'] as String,
          'clientName': data['client_name'] as String?,
          'demand': data['price'] as int?,
          'saleStatus': data['sale_status'] as String?,
          'societyId': data['society_id'] as String?,
          'blockId': data['block_id'] as String?,
          'updatedAt': data['updated_at'] as String,
        });
      }
      
      return inventory;
    } catch (e) {
      debugPrint('Error loading inventory report: $e');
      return [];
    }
  }

  @override
  Future<List<Expenditure>> getExpenditureReport({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
    String? category,
    String? kind,
  }) async {
    try {
      // Build query with explicit type-safe mapping
      final clauses = <String>['is_active = 1'];
      final vars = <d.Variable<String>>[];
      
      // Add company filter for non-super users
      final skipCompanyFilter = isSuperAdmin || companyId == 'GLOBAL_ADMIN';
      if (!skipCompanyFilter && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId));
      }
      
      // Add date range filter
      if (startDate != null) {
        clauses.add('date >= ?');
        vars.add(d.Variable.withString(startDate));
      }
      if (endDate != null) {
        clauses.add('date <= ?');
        vars.add(d.Variable.withString(endDate));
      }
      
      // Add category filter
      if (category != null) {
        clauses.add('category = ?');
        vars.add(d.Variable.withString(category));
      }
      
      // Add kind filter
      if (kind != null) {
        clauses.add('kind = ?');
        vars.add(d.Variable.withString(kind));
      }
      
      final where = clauses.join(' AND ');
      
      final result = await db.customSelect(
        'SELECT * FROM expenditures WHERE $where ORDER BY date DESC',
        variables: vars,
      ).get();
      
      // Explicit type-safe mapping
      final List<Expenditure> expenditures = [];
      for (final row in result) {
        final data = row.data;
        final expenditure = Expenditure(
          id: data['id'] as String,
          date: data['date'] as String,
          description: data['description'] as String,
          amount: data['amount'] as double,
          category: data['category'] as String?,
          companyId: data['company_id'] as String?,
          createdBy: data['created_by'] as String?,
          kind: data['kind'] as String?,
          projectId: data['project_id'] as String?,
          categoryId: data['category_id'] as String?,
          officeMonth: data['office_month'] as String?,
          categoryType: data['category_type'] as String?,
          createdAt: data['created_at'] as String?,
          updatedAt: data['updated_at'] as String,
          isActive: (data['is_active'] as int? ?? 1) == 1,
          isSynced: (data['is_synced'] as int? ?? 1) == 1,
        );
        expenditures.add(expenditure);
      }
      
      return expenditures;
    } catch (e) {
      debugPrint('Error loading expenditure report: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getReportSummary({
    String? companyId,
    bool isSuperAdmin = false,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final summary = <String, dynamic>{};
      
      // Get agent working summary
      final agentWorkingData = await getAgentWorkingReport(
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
        startDate: startDate,
        endDate: endDate,
      );
      
      summary['totalTransfers'] = agentWorkingData.length;
      summary['pendingTransfers'] = agentWorkingData.where((e) => e.status == 'Pending').length;
      summary['completedTransfers'] = agentWorkingData.where((e) => e.status == 'Done').length;
      
      // Get inventory summary
      final inventoryData = await getInventoryReport(
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
        startDate: startDate,
        endDate: endDate,
      );
      
      summary['totalInventory'] = inventoryData.length;
      summary['soldInventory'] = inventoryData.where((e) => e['saleStatus'] == 'Sale').length;
      summary['availableInventory'] = inventoryData.where((e) => e['saleStatus'] == 'Not Sale').length;
      
      // Get expenditure summary
      final expenditureData = await getExpenditureReport(
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
        startDate: startDate,
        endDate: endDate,
      );
      
      summary['totalExpenditure'] = expenditureData.fold<double>(
        0.0,
        (sum, e) => sum + (e.amount ?? 0.0),
      );
      
      return summary;
    } catch (e) {
      debugPrint('Error generating report summary: $e');
      return {};
    }
  }

  @override
  Future<Uint8List> exportToPdf({
    required String reportType,
    required List<Map<String, dynamic>> data,
    Map<String, dynamic>? summary,
    Map<String, dynamic>? companyInfo,
  }) async {
    try {
      final pdf = pw.Document();
      
      // Load fonts
      final baseFont = await PdfGoogleFonts.nunitoRegular();
      final boldFont = await PdfGoogleFonts.nunitoBold();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                _buildPdfHeader(reportType, companyInfo, baseFont, boldFont),
                
                pw.SizedBox(height: 20),
                
                // Summary if available
                if (summary != null) ...[
                  _buildPdfSummary(summary, baseFont, boldFont),
                  pw.SizedBox(height: 20),
                ],
                
                // Data table
                _buildPdfDataTable(data, reportType, baseFont, boldFont),
              ],
            );
          },
        ),
      );
      
      return await pdf.save();
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      rethrow;
    }
  }

  @override
  Future<Uint8List> exportToCsv({
    required String reportType,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      List<List<dynamic>> csvData = [];
      
      // Add headers based on report type
      switch (reportType) {
        case 'agent_working':
          csvData.add(['ID', 'Name', 'Status', 'Category', 'Date', 'Remarks']);
          for (final item in data) {
            csvData.add([
              item['id'] ?? '',
              item['name'] ?? '',
              item['status'] ?? '',
              item['category'] ?? '',
              _formatDate(item['transferDate']),
              item['remarks'] ?? '',
            ]);
          }
          break;
        case 'inventory':
          csvData.add(['ID', 'Type', 'Name', 'Client Name', 'Demand', 'Status', 'Updated']);
          for (final item in data) {
            csvData.add([
              item['id'] ?? '',
              item['type'] ?? '',
              item['name'] ?? '',
              item['clientName'] ?? '',
              item['demand']?.toString() ?? '',
              item['saleStatus'] ?? '',
              _formatDate(item['updatedAt']),
            ]);
          }
          break;
        case 'expenditure':
          csvData.add(['ID', 'Date', 'Description', 'Amount', 'Category', 'Kind']);
          for (final item in data) {
            csvData.add([
              item['id'] ?? '',
              _formatDate(item['date']),
              item['description'] ?? '',
              item['amount']?.toString() ?? '',
              item['category'] ?? '',
              item['kind'] ?? '',
            ]);
          }
          break;
      }
      
      final csv = const ListToCsvConverter().convert(csvData);
      return Uint8List.fromList(utf8.encode(csv));
    } catch (e) {
      debugPrint('Error exporting to CSV: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getCompanyInfo(String? companyId) async {
    try {
      if (companyId == null) return null;
      
      final result = await db.customSelect(
        'SELECT * FROM companies WHERE id = ?',
        variables: [d.Variable.withString(companyId)],
      ).getSingleOrNull();
      
      if (result != null) {
        return result.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching company info: $e');
      return null;
    }
  }

  // Helper methods
  pw.Widget _buildPdfHeader(String reportType, Map<String, dynamic>? companyInfo, pw.Font baseFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (companyInfo != null) ...[
          pw.Text(
            companyInfo['name'] ?? 'Company Name',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            companyInfo['address'] ?? 'Company Address',
            style: pw.TextStyle(font: baseFont, fontSize: 12),
          ),
          pw.SizedBox(height: 10),
        ],
        pw.Text(
          '${reportType.toUpperCase()} REPORT',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange800,
          ),
        ),
        pw.Text(
          'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
          style: pw.TextStyle(font: baseFont, fontSize: 12),
        ),
        pw.Divider(thickness: 2, color: PdfColors.orange800),
      ],
    );
  }

  pw.Widget _buildPdfSummary(Map<String, dynamic> summary, pw.Font baseFont, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange100,
        border: pw.Border.all(color: PdfColors.orange300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          pw.SizedBox(height: 10),
          ...summary.entries.map((entry) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    _formatSummaryKey(entry.key),
                    style: pw.TextStyle(font: baseFont, fontSize: 12),
                  ),
                ),
                pw.Text(
                  entry.value.toString(),
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDataTable(List<Map<String, dynamic>> data, String reportType, pw.Font baseFont, pw.Font boldFont) {
    return pw.Table.fromTextArray(
      context: null,
      data: _getTableData(data, reportType),
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 12, fontWeight: pw.FontWeight.bold),
      cellStyle: pw.TextStyle(font: baseFont, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.orange100),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.center,
        5: pw.Alignment.centerLeft,
      },
    );
  }

  List<List<String>> _getTableData(List<Map<String, dynamic>> data, String reportType) {
    final tableData = <List<String>>[];
    
    switch (reportType) {
      case 'agent_working':
        tableData.add(['ID', 'Name', 'Status', 'Category', 'Date', 'Remarks']);
        for (final item in data) {
          tableData.add([
            item['id'] ?? '',
            item['name'] ?? '',
            item['status'] ?? '',
            item['category'] ?? '',
            _formatDate(item['transferDate']),
            item['remarks'] ?? '',
          ]);
        }
        break;
      case 'inventory':
        tableData.add(['ID', 'Type', 'Name', 'Client Name', 'Demand', 'Status', 'Updated']);
        for (final item in data) {
          tableData.add([
            item['id'] ?? '',
            item['type'] ?? '',
            item['name'] ?? '',
            item['clientName'] ?? '',
            item['demand']?.toString() ?? '',
            item['saleStatus'] ?? '',
            _formatDate(item['updatedAt']),
          ]);
        }
        break;
      case 'expenditure':
        tableData.add(['ID', 'Date', 'Description', 'Amount', 'Category', 'Kind']);
        for (final item in data) {
          tableData.add([
            item['id'] ?? '',
            _formatDate(item['date']),
            item['description'] ?? '',
            item['amount']?.toString() ?? '',
            item['category'] ?? '',
            item['kind'] ?? '',
          ]);
        }
        break;
    }
    
    return tableData;
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatSummaryKey(String key) {
    // Convert camelCase to readable format
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .replaceAllMapped(RegExp(r'^([a-z])'), (match) => match.group(1)!.toUpperCase());
  }
}
