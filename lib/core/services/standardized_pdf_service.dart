import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart' show AppDatabase;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../core/services/auth_service.dart';
import '../../professional_reports.dart' show generateReportSerial, logReportHistory, ReportBranding;

/// Standardized PDF service for all modules
class StandardizedPdfService {
  /// Standardized path for saving PDF receipts
  static Future<String> getStandardizedPdfPath(String moduleName, String entityId) async {
    final directory = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${directory.path}/Receipts/${moduleName}');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Receipt_${entityId}_$timestamp.pdf';
    return '${receiptsDir.path}/$fileName';
  }

  /// Generate and save PDF with standardized path and success feedback
  static Future<void> generateAndSavePdf({
    required BuildContext context,
    required String moduleName,
    required String entityId,
    required Uint8List pdfBytes,
    String? customFileName,
  }) async {
    try {
      // Save to standardized path
      final filePath = customFileName ?? await getStandardizedPdfPath(moduleName, entityId);
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Show success message with open option
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$moduleName receipt saved successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  if (Platform.isWindows) {
                    await Process.run('start', [filePath], runInShell: true);
                  } else if (Platform.isMacOS) {
                    await Process.run('open', [filePath], runInShell: true);
                  } else if (Platform.isLinux) {
                    await Process.run('xdg-open', [filePath], runInShell: true);
                  } else {
                    await Printing.sharePdf(bytes: pdfBytes, filename: filePath.split('/').last);
                  }
                } catch (e) {
                  debugPrint('Error opening file: $e');
                }
              },
            ),
          ),
        );
      }

      // Log to history
      await _logPdfHistory(moduleName, entityId);
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving $moduleName receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  /// Log PDF generation to history
  static Future<void> _logPdfHistory(String moduleName, String entityId) async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      Map<String, dynamic>? currentUser;
      
      if (authToken != null) {
        currentUser = await AuthService.getCurrentUser(authToken);
      }
      
      final db = AppDatabase.instanceIfInitialized;
      if (db != null && currentUser != null) {
        await logReportHistory(
          db: db,
          currentUser: currentUser,
          companyId: currentUser['company_id']?.toString(),
          module: moduleName.toLowerCase(),
          entityId: entityId,
          reportType: '$moduleName Receipt',
          action: 'generated',
          serialNumber: generateReportSerial(prefix: '${moduleName.toUpperCase()}_RECEIPT'),
          generatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error logging PDF history: $e');
    }
  }

  /// Platform-safe PDF generation with error handling
  static Future<void> generatePdfWithPlatformSafety({
    required BuildContext context,
    required Future<Uint8List> pdfGenerator,
    required String moduleName,
    required String entityId,
  }) async {
    if (!context.mounted) return;

    // Wrap in WidgetsBinding for platform thread safety (especially Windows)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final pdfBytes = await pdfGenerator;
        await generateAndSavePdf(
          context: context,
          moduleName: moduleName,
          entityId: entityId,
          pdfBytes: pdfBytes,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating $moduleName receipt: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  /// Platform-safe notification with error handling
  static void notifyListenersWithPlatformSafety(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in platform-safe notification: $e');
      }
    });
  }

  /// Standardized PDF metadata
  static pw.Document createStandardPdf({
    required String title,
    required ReportBranding? branding,
  }) {
    final pdf = pw.Document(
      pageMode: PdfPageMode.outlines,
    );

    return pdf;
  }

  /// Standardized header for all PDF receipts
  static pw.Widget buildStandardHeader({
    required String title,
    required ReportBranding? branding,
    required String serialNumber,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.blue800, PdfColors.blue600],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Company info
          if (branding?.companyName != null)
            pw.Text(
              branding!.companyName,
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          
          if (branding?.address != null)
            pw.Text(
              branding!.address!,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          
          if (branding?.contact != null)
            pw.Text(
              branding!.contact!,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          
          pw.SizedBox(height: 20),
          
          // Receipt title
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          
          pw.SizedBox(height: 8),
          
          // Serial number and date
          pw.Row(
            children: [
              pw.Text(
                'Receipt #: $serialNumber',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.white,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Standardized footer for all PDF receipts
  static pw.Widget buildStandardFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'This is a computer-generated receipt and does not require signature',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Generated by EasyRealtorsPro on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
