// presentation/inventory/widgets/inventory_detail_page.dart
import 'package:flutter/material.dart';
import '../../../../core/font_utils.dart';

import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/inventory_item.dart';
import '../view_models/inventory_view_model.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/inventory_repository_impl.dart';
import '../../../core/professional_pdf_generator.dart';
import '../../../core/app_utils.dart' show fmtTs;
import '../../../core/phone_actions.dart' show showPhoneActionSheet;

class InventoryDetailPage extends StatelessWidget {
  final InventoryItem item;
  final InventoryViewModel viewModel;

  const InventoryDetailPage({
    super.key,
    required this.item,
    required this.viewModel,
  });

  List<MapEntry<String, String>> _getAllFields() {
    final fields = <MapEntry<String, String>>[];
    
    fields.add(MapEntry('ID', item.id));
    fields.add(MapEntry('Owner Name', item.clientName));
    fields.add(MapEntry('Reference No.', item.referenceNo));
    
    if (item.type == InventoryType.file) {
      fields.add(MapEntry('File No.', item.fileNo ?? 'N/A'));
      fields.add(MapEntry('Mobile No.', item.mobileNo ?? 'N/A'));
      fields.add(MapEntry('Size', item.path ?? 'N/A'));
    } else {
      fields.add(MapEntry('Property Name', item.propertyName ?? 'N/A'));
      fields.add(MapEntry('Price', item.price?.toString() ?? 'N/A'));
      fields.add(MapEntry('Demand', item.demand?.toString() ?? 'N/A'));
    }
    
    fields.add(MapEntry('Sale Status', item.saleStatus));
    fields.add(MapEntry('CNIC', item.cnic ?? 'N/A'));
    fields.add(MapEntry('Society ID', item.societyId));
    fields.add(MapEntry('Block ID', item.blockId ?? 'N/A'));
    fields.add(MapEntry('Updated At', item.updatedAt.toIso8601String().split('T').first));
    
    if (item.imageUrls.isNotEmpty) {
      fields.add(MapEntry('Images', '${item.imageUrls.length} image(s)'));
    } else {
      fields.add(MapEntry('Remarks', item.remarks.isNotEmpty ? item.remarks : 'N/A'));
    }
    
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final allFields = _getAllFields();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${_capitalize(item.type.name)} Details', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF6B35),
                Color(0xFF4A90E2),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.03),
              const Color(0xFF4A90E2).withOpacity(0.03),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data Table
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_capitalize(item.type.name)} Details',
                        style: AppFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Use ListView.separated instead of Table.map() to prevent UI blocking
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
                              child: Column(
                                children: [
                                  Row(
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
                                  // Action buttons
                                  Row(
                                    children: [
                                      FilledButton.icon(
                                        icon: const Icon(Icons.edit, color: Colors.white),
                                        label: const Text('Edit'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.blue.shade600,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onPressed: () {
                                          // TODO: Implement edit functionality
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        icon: const Icon(Icons.receipt_long, color: Colors.white),
                                        label: const Text('Generate Receipt'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF6B35),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onPressed: () => _generateProfessionalReceipt(context),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        icon: const Icon(Icons.print, color: Colors.white),
                                        label: const Text('Print'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.green.shade600,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onPressed: () => _print(context),
                                      ),
                                    ],
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
                                          child: _linkify(context, field.key, field.value),
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
              
              // Image Gallery
              if (item.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Images',
                          style: AppFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF6B35),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.imageUrls.length,
                            itemBuilder: (ctx, i) {
                              return GestureDetector(
                                onTap: () => _showImageDialog(context, item.imageUrls[i]),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      item.imageUrls[i],
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(child: Icon(Icons.broken_image, size: 48)),
                                      ),
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: Colors.grey.shade200,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: (loadingProgress.expectedTotalBytes != null && loadingProgress.expectedTotalBytes! > 0)
                                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Stack(
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateProfessionalReceipt(BuildContext context) async {
    if (viewModel.filteredItems.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items to include in receipt')),
        );
      }
      return;
    }

    final today = DateTime.now();
    final keyValues = <MapEntry<String, String>>[
      MapEntry('Type', item.type.name),
      MapEntry('Items', viewModel.filteredItems.length.toString()),
      MapEntry('Generated', today.toIso8601String().split('T').first),
    ];

    final gridRows = viewModel.filteredItems.take(50).map((item) {
      return {
        'Client': item.clientName,
        'File/Property': item.type == InventoryType.file 
            ? (item.fileNo ?? '-')
            : (item.referenceNo ?? '-'),
        'Price': item.type == InventoryType.file 
            ? (item.path ?? '-')
            : (item.price?.toString() ?? '-'),
        'Status': item.saleStatus,
      };
    }).toList();

    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: (viewModel.repository as InventoryRepositoryImpl).db,
      module: 'Inventory',
      title: '${item.type.name} Receipt',
      entityId: item.id,
      keyValues: keyValues,
      gridRows: gridRows,
    );
  }

  Future<void> _print(BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: format,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Text('${_capitalize(item.type.name)} Details'),
                  ),
                  pw.Table.fromTextArray(
                    context: context,
                    data: <List<String>>[
                      <String>['Field', 'Value'],
                      ..._getAllFields().map((field) => [field.key, field.value]),
                    ],
                  ),
                ],
              );
            },
          ),
        );
        return pdf.save();
      },
    );
  }

  Widget _linkify(BuildContext context, String label, String value) {
    final isPhone = label.toLowerCase().contains('contact') || label.toLowerCase().contains('mobile');
    return GestureDetector(
      onTap: isPhone && value.trim().isNotEmpty ? () => showPhoneActionSheet(context, value) : null,
      child: Text(
        value,
        style: AppFonts.poppins(
          color: isPhone ? Colors.blue.shade700 : null,
          decoration: isPhone ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return "${text[0].toUpperCase()}${text.substring(1).toLowerCase()}";
  }
}
