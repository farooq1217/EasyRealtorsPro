import 'package:flutter/material.dart';
import '../../../../core/font_utils.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show TradingEntry;
import '../../../core/services/pdf_service.dart';
import 'trading_details_modal.dart';

class TradingList extends StatelessWidget {
  final List<TradingEntry> entries;
  final Function(String) onDelete;
  final bool isLoading;

  const TradingList({
    super.key, 
    required this.entries, 
    required this.onDelete, 
    this.isLoading = false
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              "No transactions found", 
              style: AppFonts.poppins(color: Colors.grey.shade600, fontSize: 16)
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: entries.length,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final entryType = entry.entryType;
        
        return InkWell(
          onTap: () => _showTradingDetailsModal(context, entry),
          borderRadius: BorderRadius.circular(16),
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Main Title and Type
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Title: Estate Name
                            Text(
                              entry.estateName ?? 'N/A',
                              style: AppFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Type Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getEntryTypeColor(entryType),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                entryType,
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
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Subtitle Row 1: Date and Mobile Number
                  Row(
                    children: [
                      Expanded(
                        child: _buildSubtitleRow(
                          icon: Icons.calendar_today_outlined,
                          label: DateFormat('dd MMM yyyy').format(entry.date),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSubtitleRow(
                          icon: Icons.phone_outlined,
                          label: entry.mobileNo ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Subtitle Row 2: Person Name and Unit Price
                  Row(
                    children: [
                      Expanded(
                        child: _buildSubtitleRow(
                          icon: Icons.person_outline,
                          label: entry.personName ?? 'N/A',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSubtitleRow(
                          icon: Icons.attach_money_outlined,
                          label: 'Unit Price: Rs ${NumberFormat.decimalPattern().format(entry.unitPrice)}',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Subtitle Row 3: Quantity and Total Price
                  Row(
                    children: [
                      Expanded(
                        child: _buildSubtitleRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'Quantity: ${entry.quantity}',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSubtitleRow(
                          icon: Icons.calculate_outlined,
                          label: 'Total: Rs ${NumberFormat.decimalPattern().format(entry.totalPrice)}',
                        ),
                      ),
                    ],
                  ),
                  
                  if (entry.imagePath != null && entry.imagePath!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    // Image attachment
                    Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          entry.imagePath!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 60,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('📷', style: TextStyle(color: Colors.grey[400]!)),
                                    SizedBox(height: 4),
                                    Text('Image not available', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Delete Button
                      TextButton.icon(
                        onPressed: () => onDelete(entry.id),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: Text(
                          'Delete',
                          style: AppFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to build subtitle rows with icon
  Widget _buildSubtitleRow({
    required IconData icon,
    required String label,
  }) {
    return Row(
      children: [
        Icon(
          icon, 
          size: 16, 
          color: Colors.grey.shade600
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Helper method to get entry type color
  Color _getEntryTypeColor(String? entryType) {
    switch (entryType?.toLowerCase()) {
      case 'hp':
        return Colors.blue.shade600;
      case 'kp':
        return Colors.green.shade600;
      case 'mp':
        return Colors.orange.shade600;
      case 'nmp':
        return Colors.purple.shade600;
      case 'nnmp':
        return Colors.red.shade600;
      case 'bop':
        return Colors.teal.shade600;
      case 'sop':
        return Colors.indigo.shade600;
      case 'aemp':
        return Colors.amber.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // Show trading details modal
  void _showTradingDetailsModal(BuildContext context, TradingEntry entry) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TradingDetailsModal(entry: entry),
    );
  }

  // Generate receipt method
  void _generateReceipt(TradingEntry entry) {
    // Generate professional receipt for this specific transaction
    PdfService.generateTradingReceipt(entry);
  }
}