import 'package:flutter/material.dart';
import '../../../../core/font_utils.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show TradingEntry, TradingType, TradingEntryType;
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
        final isBuy = entry.type == TradingType.buy;
        final entryType = entry.entryType == TradingEntryType.file ? 'File' : 'Farm';

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
                            // Type Badge: File/Farm
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isBuy ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                entryType,
                                style: AppFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isBuy ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(entry.status ?? 'Pending'),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          entry.status ?? 'Pending',
                          style: AppFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
                          label: entry.mobile ?? 'N/A',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Subtitle Row 2: Quantity and Comments/Remarks
                  Row(
                    children: [
                      Expanded(
                        child: _buildSubtitleRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'Quantity: ${entry.quantity ?? 0}',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSubtitleRow(
                          icon: Icons.comment_outlined,
                          label: entry.comments?.isNotEmpty == true 
                            ? (entry.comments?.length ?? 0) > 30 
                              ? '${entry.comments?.substring(0, 30)}...' 
                              : entry.comments ?? 'No remarks'
                            : 'No remarks',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Payment Amount Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6B35).withOpacity(0.1),
                          const Color(0xFF4A90E2).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment Amount',
                          style: AppFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          'Rs. ${NumberFormat('#,###').format(entry.totalAmount ?? 0.0)}',
                          style: AppFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF6B35),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'closed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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