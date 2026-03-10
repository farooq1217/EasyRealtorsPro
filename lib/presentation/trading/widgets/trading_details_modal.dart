import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../../../core/font_utils.dart';
import '../../../../core/services/standardized_pdf_service.dart';
import '../../../domain/models/trading_entry.dart';

class TradingDetailsModal extends StatefulWidget {
  final TradingEntry entry;

  const TradingDetailsModal({
    super.key,
    required this.entry,
  });

  @override
  State<TradingDetailsModal> createState() => _TradingDetailsModalState();
}

class _TradingDetailsModalState extends State<TradingDetailsModal> {
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isBuy = entry.type == TradingType.buy;
    final entryType = entry.entryType == TradingEntryType.file ? 'File' : 'Farm';

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isBuy ? const Color(0xFFFF6B35) : const Color(0xFF4A90E2),
                    isBuy ? const Color(0xFFFF6B35).withOpacity(0.8) : const Color(0xFF4A90E2).withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.estateName,
                          style: AppFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$entryType • ${isBuy ? 'Buy' : 'Sell'}',
                            style: AppFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.status ?? 'Pending',
                      style: AppFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Person Information Section
                    _buildSectionHeader('Person Information', Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildDetailCard([
                      _buildDetailRow('Name', entry.personName),
                      _buildDetailRow('Mobile', entry.mobile),
                    ]),

                    const SizedBox(height: 20),

                    // Transaction Information Section
                    _buildSectionHeader('Transaction Information', Icons.receipt_long),
                    const SizedBox(height: 12),
                    _buildDetailCard([
                      _buildDetailRow('Estate Name', entry.estateName),
                      _buildDetailRow('Transaction Type', isBuy ? 'Buy' : 'Sell'),
                      _buildDetailRow('Entry Type', entryType),
                      _buildDetailRow('Date', DateFormat('dd MMM yyyy').format(entry.date)),
                      if (entry.plotNo != null) _buildDetailRow('Plot/Form #', entry.plotNo!),
                      if (entry.block != null) _buildDetailRow('Block', entry.block!),
                      _buildDetailRow('Quantity', '${entry.quantity ?? 0}'),
                    ]),

                    const SizedBox(height: 20),

                    // Financial Information Section
                    _buildSectionHeader('Financial Information', Icons.attach_money),
                    const SizedBox(height: 12),
                    _buildDetailCard([
                      if (entry.rate != null) _buildDetailRow('Rate', 'Rs. ${NumberFormat('#,###').format(entry.rate)}'),
                      if (entry.commission != null) _buildDetailRow('Commission', 'Rs. ${NumberFormat('#,###').format(entry.commission)}'),
                      if (entry.tax != null) _buildDetailRow('Tax', 'Rs. ${NumberFormat('#,###').format(entry.tax)}'),
                      if (entry.netAmount != null) _buildDetailRow('Net Amount', 'Rs. ${NumberFormat('#,###').format(entry.netAmount)}'),
                      if (entry.totalAmount != null) _buildDetailRow('Total Amount', 'Rs. ${NumberFormat('#,###').format(entry.totalAmount)}'),
                    ]),

                    const SizedBox(height: 20),

                    // Additional Information Section
                    if (entry.comments != null && entry.comments!.isNotEmpty) ...[
                      _buildSectionHeader('Additional Information', Icons.comment_outlined),
                      const SizedBox(height: 12),
                      _buildDetailCard([
                        _buildDetailRow('Comments', entry.comments!),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // Payment Status Section
                    _buildSectionHeader('Payment Status', Icons.payment),
                    const SizedBox(height: 12),
                    _buildDetailCard([
                      _buildDetailRow('Status', entry.status ?? 'Pending'),
                    ]),

                    const SizedBox(height: 30),

                    // Generate PDF Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingPdf ? null : _generatePdfReceipt,
                        icon: _isGeneratingPdf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isGeneratingPdf ? 'Generating...' : 'Generate Professional Receipt',
                          style: AppFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBuy ? const Color(0xFFFF6B35) : const Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF6B35), size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: AppFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfReceipt() async {
    if (_isGeneratingPdf) return;

    setState(() => _isGeneratingPdf = true);

    try {
      // Use platform thread safety for Windows
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _performPdfGeneration();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _performPdfGeneration() async {
    try {
      // Generate PDF bytes
      final pdfBytes = await _generatePdfDocument();

      // Use standardized PDF service
      await StandardizedPdfService.generateAndSavePdf(
        context: context,
        moduleName: 'Trading',
        entityId: widget.entry.id,
        pdfBytes: pdfBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<Uint8List> _generatePdfDocument() async {
    final entry = widget.entry;
    final pdf = pw.Document();

    final isBuy = entry.type == TradingType.buy;
    final entryType = entry.entryType == TradingEntryType.file ? 'File' : 'Farm';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TRADING RECEIPT',
                style: pw.TextStyle(
                  fontSize: 24,
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
          pw.SizedBox(height: 20),

          // Transaction Details
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
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
                _buildPdfRow('Person Name', entry.personName),
                _buildPdfRow('Mobile', entry.mobile),
                _buildPdfRow('Estate Name', entry.estateName),
                if (entry.plotNo != null) _buildPdfRow('Plot/Form #', entry.plotNo!),
                if (entry.block != null) _buildPdfRow('Block', entry.block!),
                _buildPdfRow('Transaction Type', isBuy ? 'BUY' : 'SELL'),
                _buildPdfRow('Entry Type', entryType),
                _buildPdfRow('Date', DateFormat('dd MMM yyyy').format(entry.date)),
                _buildPdfRow('Quantity', '${entry.quantity ?? 0}'),
                _buildPdfRow('Status', entry.status ?? 'Pending'),
                if (entry.comments != null && entry.comments!.isNotEmpty)
                  _buildPdfRow('Comments', entry.comments!),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Financial Details
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
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
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (entry.rate != null) _buildPdfRow('Rate', 'Rs. ${NumberFormat('#,###').format(entry.rate)}'),
                if (entry.commission != null) _buildPdfRow('Commission', 'Rs. ${NumberFormat('#,###').format(entry.commission)}'),
                if (entry.tax != null) _buildPdfRow('Tax', 'Rs. ${NumberFormat('#,###').format(entry.tax)}'),
                if (entry.netAmount != null) _buildPdfRow('Net Amount', 'Rs. ${NumberFormat('#,###').format(entry.netAmount)}'),
                if (entry.totalAmount != null) _buildPdfRow('Total Amount', 'Rs. ${NumberFormat('#,###').format(entry.totalAmount)}'),
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
      ),
    );
    
    return pdf.save();
  }

  pw.Widget _buildPdfRow(String label, String value) {
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
