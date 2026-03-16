import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey, rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import '../../../core/services/auth_service.dart';
import '../../../shimmer_widgets.dart';
import '../../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory;
import '../../../core/professional_pdf_generator.dart';
import '../../../core/phone_actions.dart';
import '../../../core/app_utils.dart';
import '../../../core/shared_utils.dart';
import '../../../core/services/firebase_threading_handler.dart';
import '../../../firestore_sync_service.dart';
import '../../../image_cache_service.dart';
import '../../../responsive_widgets.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../reports/report_view_model.dart';
import '../../reports/repositories/report_repository_impl.dart';

class AgentWorkingDetailPage extends StatefulWidget {
  final Map<String, dynamic> entryData;
  final AppDatabase db;
  final VoidCallback onUpdate;

  const AgentWorkingDetailPage({
    super.key,
    required this.entryData,
    required this.db,
    required this.onUpdate,
  });

  @override
  State<AgentWorkingDetailPage> createState() => _AgentWorkingDetailPageState();
}

class _AgentWorkingDetailPageState extends State<AgentWorkingDetailPage> {
  DateTime? _selectedNextDate;
  late ReportViewModel _reportViewModel;

  @override
  void initState() {
    super.initState();
    
    // Initialize report view model
    final isSuperAdmin = RoleUtils.isSuperAdmin(null) || PermissionHelper.isBypassUser(null);
    final companyId = RoleUtils.getUserCompanyId(null);
    final repository = ReportRepositoryImpl(widget.db, companyId: companyId, isSuperAdmin: isSuperAdmin);
    _reportViewModel = ReportViewModel(repository);
    
    // Initialize next date from existing data
    final nextDateStr = widget.entryData['nextWorkingDate']?.toString() ?? 
                        widget.entryData['next_working_date']?.toString();
    if (nextDateStr != null && nextDateStr.isNotEmpty) {
      try {
        // Try parsing ISO format first
        _selectedNextDate = DateTime.tryParse(nextDateStr);
        // If that fails, try yyyy-MM-dd format
        if (_selectedNextDate == null) {
          _selectedNextDate = DateFormat('yyyy-MM-dd').parse(nextDateStr);
        }
      } catch (e) {
        debugPrint('Failed to parse next date: $e');
      }
    }
  }

  Future<void> _updateStatus(String status, {DateTime? nextDate}) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final id = widget.entryData['id'] as String;
      // Use yyyy-MM-dd format to match the rest of the codebase
      final nextDateStr = nextDate != null ? DateFormat('yyyy-MM-dd').format(nextDate) : null;

      // Update in SQLite
      await widget.db.customStatement(
        'UPDATE working_progress SET status = ?, next_working_date = ?, updated_at = ? WHERE id = ?',
        [status, nextDateStr ?? '', nowIso, id],
      );

      // Update in Firestore if available
      try {
        if (Firebase.apps.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('working_progress').doc(id).update({
            'status': status,
            'nextWorkingDate': nextDateStr,
            'updatedAt': nowIso,
          });
        }
      } catch (e) {
        debugPrint('Firestore update failed: $e');
      }

      if (mounted) {
        widget.onUpdate();
        Navigator.pop(context);
        final dateMsg = nextDateStr != null ? ' (Next Date: ${DateFormat('dd MMM yyyy').format(nextDate!)})' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $status$dateMsg')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _printDocument() async {
    final entry = widget.entryData;
    final isTransfer = entry['type']?.toString() == 'transfer' ||
        (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
    final title = 'Agent Working Details';
    final serial = generateReportSerial(prefix: 'RPT');
    final generatedAt = DateTime.now();

    final currentUser = await loadCurrentUserFromStorage();
    final entityId = entry['id']?.toString();
    final fields = _getAllFields(entry, isTransfer);

    await logReportHistory(
      db: widget.db,
      currentUser: currentUser,
      companyId: RoleUtils.getUserCompanyId(currentUser),
      module: 'agent_working',
      entityId: entityId,
      reportType: title,
      action: 'print',
      serialNumber: serial,
      generatedAt: generatedAt,
    );

    await Printing.layoutPdf(
      onLayout: (_) async {
        final a4Format = PdfPageFormat.a4;
        return buildKeyValueReportPdf(
          format: a4Format,
          db: widget.db,
          currentUser: currentUser,
          module: 'agent_working',
          entityId: entityId,
          title: title,
          action: 'print',
          fields: fields,
          serialNumber: serial,
          generatedAt: generatedAt,
          logHistory: false,
        );
      },
    );
  }

  Future<void> _downloadPdf() async {
    try {
      final entry = widget.entryData;
      final isTransfer = entry['type']?.toString() == 'transfer' ||
          (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
      final title = 'Agent Working Details';
      
      // Show immediate feedback dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Generating PDF...', style: AppFonts.poppins(fontSize: 14)),
              ],
            ),
          ),
        ),
      );
      
      // Pre-load ALL data BEFORE compute() to prevent blocking
      final preloadFutures = await Future.wait([
        _tryLoadRobotoBytes('assets/fonts/Roboto-Regular.ttf'),
        _tryLoadRobotoBytes('assets/fonts/Roboto-Bold.ttf'),
        loadCurrentUserFromStorage(),
      ]);

      final baseFontBytes = (preloadFutures[0] as Uint8List?) ?? Uint8List(0);
      final boldFontBytes = (preloadFutures[1] as Uint8List?) ?? Uint8List(0);
      final currentUser = preloadFutures[2] as Map<String, dynamic>?;

      // Load branding (database query - must be done before isolate)
      final branding = await loadReportBranding(db: widget.db, currentUser: currentUser);
      
      // Prepare data for isolate - convert to serializable format
      final entryData = {
        'id': entry['id']?.toString(),
        'type': entry['type']?.toString(),
        'category': entry['category']?.toString(),
        'status': entry['status']?.toString(),
        'name': entry['name']?.toString(),
        'clientMobile': entry['clientMobile']?.toString(),
        'plotNo': entry['plotNo']?.toString(),
        'registryNumber': entry['registryNumber']?.toString(),
        'transferDate': entry['transferDate']?.toString(),
        'transfer_date': entry['transfer_date']?.toString(),
        'nextWorkingDate': entry['nextWorkingDate']?.toString(),
        'next_working_date': entry['next_working_date']?.toString(),
        'fromUser': entry['fromUser']?.toString(),
        'toUser': entry['toUser']?.toString(),
        'companyId': entry['companyId']?.toString(),
        'updated_at': entry['updated_at']?.toString(),
        'updatedAt': entry['updatedAt']?.toString(),
        'remarks': entry['remarks']?.toString(),
      };
      
      // Build fields in isolate to keep UI responsive
      final fields = await compute(_buildAgentFieldsInIsolate, {
        'entry': entryData,
        'isTransfer': isTransfer,
      });
      
      final entityId = entry['id']?.toString();
      final bytes = await buildKeyValueReportPdf(
        format: PdfPageFormat.a4,
        db: widget.db,
        currentUser: currentUser,
        module: 'agent_working',
        entityId: entityId,
        title: title,
        action: 'download',
        fields: fields,
        preloadedBaseFontBytes: baseFontBytes,
        preloadedBoldFontBytes: boldFontBytes,
        preloadedBranding: branding,
      );
      
      if (context != null && context.mounted) {
        Navigator.pop(context); // Close loading dialog
      }
      
      await savePdfBytesToDisk(
        pdfBytes: bytes,
        suggestedBaseName: 'agent_working_${entityId ?? 'detail'}_${fmtTs(DateTime.now())}',
      );
      
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF exported successfully')),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateProfessionalReceipt() async {
    final entry = widget.entryData;
    final entryId = entry['id']?.toString();
    final isTransfer = entry['type']?.toString() == 'transfer' ||
        (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
    final entryType = isTransfer ? 'transfer' : 'requirement';
    
    if (entryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid entry ID'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Show preview dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.8,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Professional Receipt Preview',
                        style: AppFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Preview content
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Receipt details preview
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPreviewRow('Receipt ID', entryId),
                            _buildPreviewRow('Type', isTransfer ? 'Transfer' : 'Client Requirement'),
                            _buildPreviewRow('Owner Name', entry['name']?.toString() ?? 'N/A'),
                            if (entry['category'] != null)
                              _buildPreviewRow('Category', entry['category']!.toString()),
                            if (entry['transferDate'] != null || entry['transfer_date'] != null)
                              _buildPreviewRow('Date', _formatPreviewDate(
                                entry['transferDate']?.toString() ?? entry['transfer_date']?.toString()
                              )),
                            if (entry['status'] != null)
                              _buildPreviewRow('Status', entry['status']!.toString()),
                            if (entry['remarks'] != null && entry['remarks']!.toString().isNotEmpty)
                              _buildPreviewRow('Remarks', entry['remarks']!.toString()),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Company info preview
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company Information',
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPreviewRow('Company', _reportViewModel.companyInfo?['name']?.toString() ?? 'N/A'),
                            _buildPreviewRow('Address', _reportViewModel.companyInfo?['address']?.toString() ?? 'N/A'),
                            _buildPreviewRow('Contact', _reportViewModel.companyInfo?['contact']?.toString() ?? 'N/A'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryGradientButton(
                        text: 'Generate & Print',
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await _generateAndPrintReceipt(entryId, entryType);
                        },
                        icon: Icons.print,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppFonts.poppins(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPreviewDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _generateAndPrintReceipt(String entryId, String entryType) async {
    try {
      // Generate PDF
      final pdfBytes = await _reportViewModel.generateProfessionalReceipt(
        entryId: entryId,
        entryType: entryType,
      );
      
      if (pdfBytes != null && mounted) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Preparing receipt...', style: AppFonts.poppins(fontSize: 14)),
                ],
              ),
            ),
          ),
        );
        
        // Print the PDF
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'professional_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Professional receipt generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error generating receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  
  /// Helper to load font bytes
  Future<Uint8List?> _tryLoadRobotoBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
  
  /// Builds agent fields in isolate to prevent UI blocking
  static List<MapEntry<String, String>> _buildAgentFieldsInIsolate(Map<String, dynamic> args) {
    final entry = args['entry'] as Map<String, dynamic>;
    final isTransfer = args['isTransfer'] as bool;
    
    final fields = <MapEntry<String, String>>[];
    
    fields.add(MapEntry('ID', entry['id']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Type', isTransfer ? 'Transfer' : 'Client Requirements'));
    fields.add(MapEntry('Status', entry['status']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Category', entry['category']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Client Name', entry['name']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Client Mobile', entry['clientMobile']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Plot No.', entry['plotNo']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Registry/Transfer Number', entry['registryNumber']?.toString() ?? 'N/A'));
    
    if (entry['transferDate'] != null || entry['transfer_date'] != null) {
      final dateStr = (entry['transferDate'] ?? entry['transfer_date'])?.toString() ?? '';
      fields.add(MapEntry('Date', dateStr.split('T').first.split(' ').first));
    } else {
      fields.add(MapEntry('Date', 'N/A'));
    }
    
    if (entry['nextWorkingDate'] != null || entry['next_working_date'] != null) {
      final nextDateStr = (entry['nextWorkingDate'] ?? entry['next_working_date'])?.toString() ?? '';
      fields.add(MapEntry('Next Working Date', nextDateStr.split('T').first.split(' ').first));
    } else {
      fields.add(MapEntry('Next Working Date', 'N/A'));
    }
    
    fields.add(MapEntry('From User', entry['fromUser']?.toString() ?? 'N/A'));
    fields.add(MapEntry('To User', entry['toUser']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Company ID', entry['companyId']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Updated', (entry['updated_at'] ?? entry['updatedAt'])?.toString().split('T').first ?? 'N/A'));
    fields.add(MapEntry('Remarks', entry['remarks']?.toString() ?? 'N/A'));
    
    return fields;
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final entry = widget.entryData;
    final isTransfer = entry['type']?.toString() == 'transfer' ||
        (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
    final title = 'Agent Working Details';
    
    // Prepare data for isolate - convert to serializable format
    final entryData = {
      'id': entry['id']?.toString(),
      'type': entry['type']?.toString(),
      'category': entry['category']?.toString(),
      'status': entry['status']?.toString(),
      'name': entry['name']?.toString(),
      'clientMobile': entry['clientMobile']?.toString(),
      'plotNo': entry['plotNo']?.toString(),
      'registryNumber': entry['registryNumber']?.toString(),
      'transferDate': entry['transferDate']?.toString(),
      'transfer_date': entry['transfer_date']?.toString(),
      'nextWorkingDate': entry['nextWorkingDate']?.toString(),
      'next_working_date': entry['next_working_date']?.toString(),
      'fromUser': entry['fromUser']?.toString(),
      'toUser': entry['toUser']?.toString(),
      'companyId': entry['companyId']?.toString(),
      'updated_at': entry['updated_at']?.toString(),
      'updatedAt': entry['updatedAt']?.toString(),
      'remarks': entry['remarks']?.toString(),
    };
    
    // Build fields in isolate to keep UI responsive
    final fields = await compute(_buildAgentFieldsInIsolate, {
      'entry': entryData,
      'isTransfer': isTransfer,
    });
    
    final currentUser = await loadCurrentUserFromStorage();
    final entityId = entry['id']?.toString();
    return buildKeyValueReportPdf(
      format: format,
      db: widget.db,
      currentUser: currentUser,
      module: 'agent_working',
      entityId: entityId,
      title: title,
      action: 'print',
      fields: fields,
      logHistory: false,
    );
  }

  pw.Widget _buildPdfSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...children,
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _getAllFields(Map<String, dynamic> entry, bool isTransfer) {
    final fields = <MapEntry<String, String>>[];
    
    fields.add(MapEntry('ID', entry['id']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Type', isTransfer ? 'Transfer' : 'Client Requirements'));
    fields.add(MapEntry('Status', entry['status']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Category', entry['category']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Client Name', entry['name']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Client Mobile', entry['clientMobile']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Plot No.', entry['plotNo']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Registry/Transfer Number', entry['registryNumber']?.toString() ?? 'N/A'));
    
    if (entry['transferDate'] != null || entry['transfer_date'] != null) {
      final dateStr = (entry['transferDate'] ?? entry['transfer_date'])?.toString() ?? '';
      fields.add(MapEntry('Date', dateStr.split('T').first.split(' ').first));
    } else {
      fields.add(MapEntry('Date', 'N/A'));
    }
    
    if (entry['nextWorkingDate'] != null || entry['next_working_date'] != null) {
      final nextDateStr = (entry['nextWorkingDate'] ?? entry['next_working_date'])?.toString() ?? '';
      fields.add(MapEntry('Next Working Date', nextDateStr.split('T').first.split(' ').first));
    } else {
      fields.add(MapEntry('Next Working Date', 'N/A'));
    }
    
    fields.add(MapEntry('From User', entry['fromUser']?.toString() ?? 'N/A'));
    fields.add(MapEntry('To User', entry['toUser']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Company ID', entry['companyId']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Updated', (entry['updated_at'] ?? entry['updatedAt'])?.toString().split('T').first ?? 'N/A'));
    fields.add(MapEntry('Remarks', entry['remarks']?.toString() ?? 'N/A'));
    
    return fields;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: (label.toLowerCase().contains('mobile') || label.toLowerCase().contains('contact'))
                      && value.trim().isNotEmpty
                  ? () => showPhoneActionSheet(context, value)
                  : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: (label.toLowerCase().contains('mobile') || label.toLowerCase().contains('contact'))
                      ? Colors.blue.shade700
                      : null,
                  decoration: (label.toLowerCase().contains('mobile') || label.toLowerCase().contains('contact'))
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, IconData icon, List<Widget> children, bool isMobile) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFFFF6B35)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppFonts.poppins(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entryData;
    final status = entry['status']?.toString() ?? 'Pending';
    final isTransfer = entry['type']?.toString() == 'transfer' || 
                       (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
    final statusColor = status == 'Done' 
        ? Colors.green.shade700 
        : status == 'Closed' 
            ? Colors.orange.shade700 
            : Colors.blue.shade700;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back (ESC)',
          ),
          title: Text(
            'Agent Working Details',
            style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple.shade500, Colors.purple.shade400, Colors.purple.shade300],
              ),
            ),
          ),
          actions: [
          TextButton.icon(
            onPressed: _generateProfessionalReceipt,
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            label: const Text(
              'Generate Professional Receipt',
              style: TextStyle(color: Colors.white),
            ),
          ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange
                const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue
              ],
            ),
            border: Border.all(
              color: Colors.grey.shade300.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final isMobile = maxWidth < 600;

              final allFields = _getAllFields(entry, isTransfer);
              
              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Center(
                              child: Text(
                                'Agent Working Details',
                                style: AppFonts.poppins(
                                  fontSize: isMobile ? 20 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF6B35),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            
                            // Data Table - Use ListView.separated instead of Table.map() to prevent UI blocking
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: [
                                  // Header row
                                  Container(
                                    decoration: BoxDecoration(color: Colors.grey.shade200),
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Field',
                                            style: AppFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Value',
                                            style: AppFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Data rows using ListView.separated for better performance
                                  SizedBox(
                                    height: allFields.length * 50.0 < 400 ? allFields.length * 50.0 : 400,
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: allFields.length,
                                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
                                      itemBuilder: (context, index) {
                                        final field = allFields[index];
                                        final isEven = index % 2 == 0;
                                        return Container(
                                          color: isEven ? Colors.white : Colors.grey.shade50,
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  field.key,
                                                  style: AppFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  field.value,
                                                  style: AppFonts.poppins(fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

