// lib/core/services/pdf_service.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show TradingEntry;

class PdfService {
  static Future<void> generateTradingReport(List<TradingEntry> entries) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Trading & Inventory Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text("Date: $dateStr"),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Type', 'Person Name', 'Estate', 'Quantity', 'Unit Price', 'Total Price', 'Date', 'Mobile'],
            data: entries.map((e) => [
              e.entryType == 'buy' ? 'BUY' : 'SELL',
              e.personName,
              e.estateName,
              e.quantity.toString(),
              'Rs. ${e.unitPrice.toStringAsFixed(2)}',
              'Rs. ${e.totalPrice.toStringAsFixed(2)}',
              DateFormat('dd MMM yyyy').format(e.date),
              e.mobileNo,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 20),
          // Summary Section
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Total Quantity: ${entries.fold<double>(0, (sum, e) => sum + e.quantity).toStringAsFixed(0)}'),
                pw.Text('Total Value: Rs. ${entries.fold<double>(0, (sum, e) => sum + e.totalPrice).toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );

    // Seedha printer ya preview par bhej dein
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateTradingReceipt(TradingEntry entry) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TRADING RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Transaction Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Transaction Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      _buildReceiptRow('Person Name', entry.personName),
                      _buildReceiptRow('Mobile', entry.mobileNo),
                      _buildReceiptRow('Estate Name', entry.estateName),
                      _buildReceiptRow('Quantity', entry.quantity.toString()),
                      _buildReceiptRow('Entry Type', entry.entryType),
                      _buildReceiptRow('Date', DateFormat('dd MMM yyyy').format(entry.date)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                // Financial Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Financial Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      _buildReceiptRow('Unit Price', 'Rs. ${entry.unitPrice.toStringAsFixed(2)}'),
                      _buildReceiptRow('Quantity', entry.quantity.toString()),
                      _buildReceiptRow('Total Price', 'Rs. ${entry.totalPrice.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Center(
                    child: pw.Text(
                      'This is a computer-generated receipt and does not require signature',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Seedha printer ya preview par bhej dein
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}