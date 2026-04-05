import 'dart:typed_data';
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart' show AppDatabase;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../core/services/auth_service.dart';
import '../view_models/rental_view_model.dart';
import '../../../professional_reports.dart' show loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory, ReportBranding;

class RentalReceiptGenerator {
  static Map<String, dynamic> _brandingToMap(ReportBranding? branding) {
    if (branding == null) return {};
    return {
      'company_name': branding.companyName,
      'address': branding.address,
      'phone': branding.contact,
      'logo_path': branding.logoPathOrUrl,
    };
  }
  static Future<Uint8List> generateProfessionalReceipt({
    required Map<String, dynamic> rentalItem,
    Map<String, dynamic>? companyInfo,
    String? logoPath,
  }) async {
    // Create PDF document
    final pdf = pw.Document();
    
    // Load branding information
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final authToken = settings['authToken'] as String?;
    Map<String, dynamic>? currentUser;
    
    if (authToken != null) {
      currentUser = await AuthService.getCurrentUser(authToken);
    }
    
    // Create a dummy database instance for branding
    final db = AppDatabase.instanceIfInitialized!;
    final branding = await loadReportBranding(db: db, currentUser: currentUser);

    // Generate serial number
    final serial = generateReportSerial(prefix: 'RENTAL_RECEIPT');

    // Add page to PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with logo and company info
            _buildHeader(_brandingToMap(branding), companyInfo, logoPath),
            
            pw.SizedBox(height: 30),
            
            // Receipt title and serial
            _buildReceiptTitle(serial),
            
            pw.SizedBox(height: 20),
            
            // Rental item details
            _buildRentalDetails(rentalItem),
            
            pw.SizedBox(height: 20),
            
            // Financial details
            _buildFinancialDetails(rentalItem),
            
            pw.SizedBox(height: 20),
            
            // Terms and conditions
            _buildTermsAndConditions(),
            
            pw.SizedBox(height: 30),
            
            // Signature section
            _buildSignatureSection(currentUser, rentalItem),
            
            // Footer
            pw.SizedBox(height: 20),
            _buildFooter(_brandingToMap(branding)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    Map<String, dynamic> branding,
    Map<String, dynamic>? companyInfo,
    String? logoPath,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                companyInfo?['name'] ?? branding['company_name'] ?? 'Real Estate Company',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange800,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                companyInfo?['address'] ?? branding['address'] ?? 'Company Address',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Phone: ${companyInfo?['phone'] ?? branding['phone'] ?? 'N/A'}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Email: ${companyInfo?['email'] ?? branding['email'] ?? 'N/A'}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            alignment: pw.Alignment.topRight,
            child: pw.Container(
              width: 80,
              height: 80,
              decoration: pw.BoxDecoration(
                color: PdfColors.orange100,
                border: pw.Border.all(color: PdfColors.orange300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Center(
                child: pw.Text(
                  'LOGO',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildReceiptTitle(String serial) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.orange800, PdfColors.blue800],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'RENTAL RECEIPT',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            'Serial: $serial',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRentalDetails(Map<String, dynamic> rentalItem) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Property Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          pw.SizedBox(height: 10),
          _buildDetailRow('Property Type:', rentalItem['name']?.toString() ?? 'N/A'),
          _buildDetailRow('Location:', rentalItem['location']?.toString() ?? 'N/A'),
          _buildDetailRow('Owner Name:', rentalItem['owner_name']?.toString() ?? 'N/A'),
          _buildDetailRow('Contact No:', rentalItem['contact_no']?.toString() ?? 'N/A'),
          _buildDetailRow('CNIC:', rentalItem['cnic']?.toString() ?? 'N/A'),
          _buildDetailRow('Status:', rentalItem['sale_status']?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  static pw.Widget _buildFinancialDetails(Map<String, dynamic> rentalItem) {
    final monthlyRent = double.tryParse(rentalItem['price']?.toString() ?? '0') ?? 0.0;
    final security = double.tryParse(rentalItem['security']?.toString() ?? '0') ?? 0.0;
    final total = monthlyRent + security;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Financial Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          pw.SizedBox(height: 10),
          _buildDetailRow('Monthly Rent:', 'Rs ${monthlyRent.toStringAsFixed(2)}'),
          _buildDetailRow('Security Deposit:', 'Rs ${security.toStringAsFixed(2)}'),
          pw.Divider(color: PdfColors.grey400),
          _buildDetailRow(
            'Total Amount:',
            'Rs ${total.toStringAsFixed(2)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTermsAndConditions() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Terms and Conditions',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '1. This receipt confirms the rental agreement for the mentioned property.\n'
            '2. Monthly rent is due on the 1st of each month.\n'
            '3. Security deposit is refundable upon termination of agreement, subject to property condition.\n'
            '4. Any damages to the property will be deducted from the security deposit.\n'
            '5. This receipt is valid for legal and tax purposes.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureSection(
    Map<String, dynamic>? currentUser,
    Map<String, dynamic> rentalItem,
  ) {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd MMMM yyyy').format(now);

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Container(
              width: 200,
              child: pw.Column(
                children: [
                  pw.Container(
                    height: 50,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Property Owner Signature',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.Container(
              width: 200,
              child: pw.Column(
                children: [
                  pw.Container(
                    height: 50,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Agent Signature',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Date: $formattedDate',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(Map<String, dynamic> branding) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'This is a computer-generated receipt and does not require a physical signature.',
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${branding['company_name'] ?? 'Real Estate Company'} - ${branding['phone'] ?? 'Contact Number'}',
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> printReceipt(Map<String, dynamic> rentalItem) async {
    try {
      // Load company info
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final companyInfo = settings['companyInfo'] as Map<String, dynamic>?;
      
      // Get current user
      final authToken = settings['authToken'] as String?;
      Map<String, dynamic>? currentUser;
      
      if (authToken != null) {
        currentUser = await AuthService.getCurrentUser(authToken);
      }
      
      // Create database instance
      final db = AppDatabase.instanceIfInitialized!;
      
      // Generate PDF
      final pdfBytes = await generateProfessionalReceipt(
        rentalItem: rentalItem,
        companyInfo: companyInfo,
      );

      // Print or share
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Rental Receipt - ${rentalItem['name']}',
      );

      // Save to disk for history
      await savePdfBytesToDisk(
        pdfBytes: pdfBytes,
        suggestedBaseName: 'rental_receipt_${rentalItem['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      // Log to history
      await logReportHistory(
        db: db,
        currentUser: currentUser,
        companyId: currentUser?['company_id']?.toString(),
        module: 'rental',
        entityId: rentalItem['id']?.toString(),
        reportType: 'Rental Receipt',
        action: 'generated',
        serialNumber: generateReportSerial(prefix: 'RENTAL_RECEIPT'),
        generatedAt: DateTime.now(),
      );

    } catch (e) {
      debugPrint('Error printing rental receipt: $e');
      throw Exception('Failed to generate rental receipt: $e');
    }
  }
}
