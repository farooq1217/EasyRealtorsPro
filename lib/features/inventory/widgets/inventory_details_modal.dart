import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import '../../../../core/font_utils.dart';
import '../../../../core/services/app_storage.dart' show AppStorage;
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../../../../core/services/standardized_pdf_service.dart';
import '../../../../core/professional_pdf_generator.dart';
import '../models/inventory_item.dart';

class InventoryDetailsModal extends StatefulWidget {
  final InventoryItem inventoryItem;
  final Function()? onRefresh;

  const InventoryDetailsModal({
    super.key,
    required this.inventoryItem,
    this.onRefresh,
  });

  @override
  State<InventoryDetailsModal> createState() => _InventoryDetailsModalState();
}

class _InventoryDetailsModalState extends State<InventoryDetailsModal> {
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final inventoryItem = widget.inventoryItem;
    final isFile = inventoryItem.type == InventoryType.file;
    final isSold = inventoryItem.saleStatus == 'Sold';
    final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

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
                          inventoryItem.clientName,
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
                            '${isFile ? 'File' : 'Property'} • ${isSold ? 'Sold' : 'Available'}',
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
                      'ID: ${inventoryItem.id}',
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
                      _buildInfoRow('Client Name', inventoryItem.clientName),
                      _buildInfoRow('Type', isFile ? 'File' : 'Property'),
                      if (inventoryItem.path?.isNotEmpty == true)
                        _buildInfoRow('Path/Location', inventoryItem.path!),
                      if (inventoryItem.contactNumber?.isNotEmpty == true)
                        _buildInfoRow('Contact Number', inventoryItem.contactNumber!),
                      if (inventoryItem.description?.isNotEmpty == true)
                        _buildInfoRow('Description', inventoryItem.description!),
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    // Financial Information Section
                    _buildSectionHeader('Financial Information', Icons.attach_money),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      if (inventoryItem.price != null)
                        _buildInfoRow('Price', f.format(inventoryItem.price!)),
                      if (inventoryItem.commission?.isNotEmpty == true)
                        _buildInfoRow('Commission', inventoryItem.commission!),
                      if (inventoryItem.netAmount?.isNotEmpty == true)
                        _buildInfoRow('Net Amount', inventoryItem.netAmount!),
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    // Status Information Section
                    _buildSectionHeader('Status Information', Icons.flag),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      _buildInfoRow('Sale Status', inventoryItem.saleStatus),
                      _buildInfoRow('Created Date', DateFormat('dd MMM yyyy').format(inventoryItem.createdAt)),
                      if (inventoryItem.updatedAt != inventoryItem.createdAt)
                        _buildInfoRow('Last Updated', DateFormat('dd MMM yyyy').format(inventoryItem.updatedAt)),
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
                        side: BorderSide(color: isSold ? const Color(0xFF4A90E2) : const Color(0xFFFF6B35)),
                        foregroundColor: isSold ? const Color(0xFF4A90E2) : const Color(0xFFFF6B35),
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
                        backgroundColor: isSold ? const Color(0xFF4A90E2) : const Color(0xFFFF6B35),
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
    final isSold = widget.inventoryItem.saleStatus == 'Sold';
    return Row(
      children: [
        Icon(icon, color: isSold ? const Color(0xFF4A90E2) : const Color(0xFFFF6B35), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSold ? const Color(0xFF4A90E2) : const Color(0xFFFF6B35),
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
      // Build key values for receipt header
      final keyValues = <MapEntry<String, String>>[
        MapEntry('Item ID', widget.inventoryItem.id),
        MapEntry('Client Name', widget.inventoryItem.clientName),
        MapEntry('Type', widget.inventoryItem.type == InventoryType.file ? 'File' : 'Property'),
        MapEntry('Sale Status', widget.inventoryItem.saleStatus),
        if (widget.inventoryItem.path?.isNotEmpty == true)
          MapEntry('Path/Location', widget.inventoryItem.path!),
        if (widget.inventoryItem.contactNumber?.isNotEmpty == true)
          MapEntry('Contact Number', widget.inventoryItem.contactNumber!),
        if (widget.inventoryItem.price != null)
          MapEntry('Price', NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2).format(widget.inventoryItem.price!)),
        if (widget.inventoryItem.commission?.isNotEmpty == true)
          MapEntry('Commission', widget.inventoryItem.commission!),
        if (widget.inventoryItem.netAmount?.isNotEmpty == true)
          MapEntry('Net Amount', widget.inventoryItem.netAmount!),
        if (widget.inventoryItem.description?.isNotEmpty == true)
          MapEntry('Description', widget.inventoryItem.description!),
        MapEntry('Created Date', DateFormat('dd MMM yyyy').format(widget.inventoryItem.createdAt)),
      ];

      // Generate PDF using existing ProfessionalPdfGenerator
      await ProfessionalPdfGenerator.generateReceipt(
        context: context,
        db: AppDatabase.instanceIfInitialized!,
        module: 'Inventory',
        title: '${widget.inventoryItem.type == InventoryType.file ? 'File' : 'Property'} Details Receipt',
        entityId: widget.inventoryItem.id,
        keyValues: keyValues,
        gridRows: [], // No grid data for single item
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
