import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/font_utils.dart';
import '../../../../../core/services/app_storage.dart' show AppStorage;
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/standardized_pdf_service.dart';
import 'rental_receipt_generator.dart' show RentalReceiptGenerator;

class RentalDetailsModal extends StatefulWidget {
  final Map<String, dynamic> rentalItem;
  final Function()? onRefresh;

  const RentalDetailsModal({
    super.key,
    required this.rentalItem,
    this.onRefresh,
  });

  @override
  State<RentalDetailsModal> createState() => _RentalDetailsModalState();
}

class _RentalDetailsModalState extends State<RentalDetailsModal> {
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final rentalItem = widget.rentalItem;
    final isSold = (rentalItem['sale_status']?.toString() ?? 'Available') == 'Rented';

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
                    isSold ? const Color(0xFF4A90E2) : const Color(0xFFFF6B35),
                    isSold ? const Color(0xFF4A90E2).withOpacity(0.8) : const Color(0xFFFF6B35).withOpacity(0.8),
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
                          rentalItem['name']?.toString() ?? 'N/A',
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
                            isSold ? 'Rented' : 'Available',
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${rentalItem['id']?.toString() ?? 'N/A'}',
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // General Information Section
                    _buildSectionHeader('General Information', Icons.info_outline),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      _buildInfoRow('Property Name', rentalItem['name']?.toString() ?? 'N/A'),
                      _buildInfoRow('Location', rentalItem['location']?.toString() ?? 'N/A'),
                      _buildInfoRow('Owner Name', rentalItem['owner_name']?.toString() ?? 'N/A'),
                      _buildInfoRow('Contact Number', rentalItem['contact_no']?.toString() ?? 'N/A'),
                      if (rentalItem['remarks']?.toString().isNotEmpty == true)
                        _buildInfoRow('Remarks', rentalItem['remarks']!.toString()),
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    // Financial Information Section
                    _buildSectionHeader('Financial Information', Icons.attach_money),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      _buildInfoRow('Rent Amount', 'Rs. ${NumberFormat('#,###').format(
                        double.tryParse(rentalItem['rent_amount']?.toString() ?? '0') ?? 0
                      )}'),
                      _buildInfoRow('Maintenance Cost', 'Rs. ${NumberFormat('#,###').format(
                        double.tryParse(rentalItem['maintenance_cost']?.toString() ?? '0') ?? 0
                      )}'),
                      if (rentalItem['other_charges'] != null)
                        _buildInfoRow('Other Charges', 'Rs. ${NumberFormat('#,###').format(
                          double.tryParse(rentalItem['other_charges']?.toString() ?? '0') ?? 0
                        )}'),
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    // Status Information Section
                    _buildSectionHeader('Status Information', Icons.flag),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      _buildInfoRow('Current Status', isSold ? 'Rented' : 'Available'),
                      _buildInfoRow('Created Date', rentalItem['created_at'] != null 
                        ? DateFormat('dd MMM yyyy').format(DateTime.parse(rentalItem['created_at']))
                        : 'N/A'),
                      if (rentalItem['updated_at'] != null)
                        _buildInfoRow('Last Updated', DateFormat('dd MMM yyyy').format(DateTime.parse(rentalItem['updated_at']))),
                    ]),
                  ],
                ),
              ),
            ),
            
            // Footer with Generate Receipt Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFFF6B35)),
                        foregroundColor: const Color(0xFFFF6B35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _generatePdfReceipt,
                      icon: _isGeneratingPdf 
                        ? Container(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                      label: Text(_isGeneratingPdf ? 'Generating...' : 'Generate Professional Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
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
        Icon(icon, color: const Color(0xFFFF6B35), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFF6B35),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      // Generate PDF bytes
      final pdfBytes = await RentalReceiptGenerator.generateProfessionalReceipt(
        rentalItem: widget.rentalItem,
      );

      // Use standardized PDF service
      await StandardizedPdfService.generateAndSavePdf(
        context: context,
        moduleName: 'Rental',
        entityId: widget.rentalItem['id']?.toString() ?? 'unknown',
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
}
