import 'package:flutter/material.dart';
import '../../../../core/font_utils.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show TradingEntry;
import '../../../core/services/pdf_service.dart';
import 'trading_details_modal.dart';

class TradingList extends StatefulWidget {
  final List<TradingEntry> entries;
  final Function(String) onDelete;
  final bool isLoading;
  final Function(String, String)? onStatusUpdate;

  const TradingList({
    super.key, 
    required this.entries, 
    required this.onDelete, 
    this.isLoading = false,
    this.onStatusUpdate,
  });

  @override
  State<TradingList> createState() => _TradingListState();
}

class _TradingListState extends State<TradingList> {

  @override
  Widget build(BuildContext context) {
    // Error boundary: Check if widget.entries is null
    if (widget.entries == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: AppFonts.poppins(color: Colors.grey.shade600, fontSize: 16)
            ),
            const SizedBox(height: 8),
            Text(
              'Please refresh to try again',
              style: AppFonts.poppins(color: Colors.grey.shade500, fontSize: 14)
            ),
          ],
        ),
      );
    }
    
    // Loading state
    if (widget.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading entries...'),
          ],
        ),
      );
    }
    
    // Empty state
    if (widget.entries.isEmpty) {
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
            const SizedBox(height: 8),
            Text(
              'Add your first trading entry to get started',
              style: AppFonts.poppins(color: Colors.grey.shade500, fontSize: 14)
            ),
          ],
        ),
      );
    }

    // Main content with error boundary
    try {
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: widget.entries.length,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (context, index) {
          // Error boundary for individual items
          try {
            final entry = widget.entries[index];
            if (entry == null) {
              return const SizedBox.shrink(); // Skip null entries
            }
            
            final entryType = entry.entryType;
            
            return InkWell(
              onTap: () => _showTradingDetailsModal(context, entry),
              borderRadius: BorderRadius.circular(16),
              child: AbsorbPointer(
                absorbing: entry.status?.toLowerCase() == 'completed', // Lock entire card if completed
                child: Opacity(
                  opacity: entry.status?.toLowerCase() == 'completed' ? 0.8 : 1.0, // Reduce opacity for completed entries
                  child: Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Main Title, Type, Status Badge, and 3-Dot Menu
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Title: Estate Name with Trade Type Icon
          Row(
            children: [
              // Trade Type Icon
              Icon(
                entry.tradeType == 'Buy' ? Icons.arrow_circle_down : Icons.arrow_circle_up,
                size: 20,
                color: entry.tradeType == 'Buy' ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              // Estate Name with Trade Type Color
              Expanded(
                child: Text(
                  entry.estateName ?? 'N/A',
                  style: AppFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getEstateNameColor(context, entry.tradeType, entry.status),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
              entryType ?? 'N/A',
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Buy/Sell Badge with enhanced styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: entry.tradeType == 'Buy' ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (entry.tradeType == 'Buy' ? Colors.green : Colors.red).withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  entry.tradeType == 'Buy' ? Icons.arrow_circle_down : Icons.arrow_circle_up,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  entry.tradeType ?? 'Buy',
                  style: AppFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    
    // Status Badge
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(entry.status ?? 'pending'),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        (entry.status?.toLowerCase() == 'active' ? 'pending' : (entry.status ?? 'pending')).toUpperCase(),
        style: AppFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
    const SizedBox(width: 4),
    
    // 3-Dot Menu (Hidden if completed)
    if (entry.status?.toLowerCase() != 'completed')
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          if (value == 'delete') {
            if (entry.id != null && entry.id!.isNotEmpty) {
              _showDeleteConfirmationDialog(context, entry);
            }
          } else {
            widget.onStatusUpdate?.call(entry.id!, value);
          }
        },
        itemBuilder: (BuildContext context) {
          final status = entry.status?.toLowerCase() ?? 'pending';
          List<PopupMenuEntry<String>> items = [];

          if (status != 'completed') {
            items.add(
              PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text('Mark as Completed', style: AppFonts.poppins(fontSize: 14)),
                  ],
                ),
              ),
            );
          }
          if (status != 'pending') {
            items.add(
              PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('Mark as Pending', style: AppFonts.poppins(fontSize: 14)),
                  ],
                ),
              ),
            );
          }
          if (status != 'cancelled') {
            items.add(
              PopupMenuItem(
                value: 'cancelled',
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text('Mark as Cancelled', style: AppFonts.poppins(fontSize: 14)),
                  ],
                ),
              ),
            );
          }

          items.add(const PopupMenuDivider());

          items.add(
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text('Delete Entry', style: AppFonts.poppins(fontSize: 14, color: Colors.red)),
                ],
              ),
            ),
          );

          return items;
        },
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
                                label: 'Quantity: ${entry.quantity ?? 0}',
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          } catch (e) {
            debugPrint('Error building trading list item at index $index: $e');
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading item',
                  style: AppFonts.poppins(color: Colors.red),
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('Error building trading list: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading entries',
              style: AppFonts.poppins(color: Colors.red.shade600, fontSize: 16)
            ),
            const SizedBox(height: 8),
            Text(
              'Please refresh to try again',
              style: AppFonts.poppins(color: Colors.grey.shade500, fontSize: 14)
            ),
          ],
        ),
      );
    }
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

  // Helper method to get entry type color with vibrant colors
  Color _getEntryTypeColor(String? entryType) {
    switch (entryType?.toLowerCase()) {
      case 'hp':
        return const Color(0xFF2196F3); // Vibrant Blue
      case 'kp':
        return const Color(0xFF4CAF50); // Vibrant Green
      case 'mp':
        return const Color(0xFFFF9800); // Vibrant Orange
      case 'nmp':
        return const Color(0xFF9C27B0); // Vibrant Purple
      case 'nnmp':
        return const Color(0xFFE91E63); // Vibrant Pink
      case 'bop':
        return const Color(0xFF009688); // Vibrant Teal
      case 'sop':
        return const Color(0xFF3F51B5); // Vibrant Indigo
      case 'aemp':
        return const Color(0xFFFFC107); // Vibrant Amber
      default:
        return Colors.grey.shade600;
    }
  }

  // Helper method to get estate name color based on trade type
  Color _getEstateNameColor(BuildContext context, String? tradeType, String? status) {
    // If completed, use grey regardless of trade type
    if (status?.toLowerCase() == 'completed') {
      return Colors.grey.shade600;
    }
    
    // Return color based on trade type
    switch (tradeType?.toLowerCase()) {
      case 'buy':
        return const Color(0xFF2E7D32); // Deep Green
      case 'sell':
        return const Color(0xFFC62828); // Deep Red
      default:
        return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87; // Fallback
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

  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog(BuildContext context, TradingEntry entry) {
    final isCompleted = entry.status?.toLowerCase() == 'completed';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Entry',
          style: AppFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this trading entry?',
              style: AppFonts.poppins(fontSize: 16),
            ),
            if (isCompleted) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This entry is completed. Deleting it will remove it permanently.',
                        style: AppFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Entry: ${entry.estateName ?? 'N/A'}',
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              'Amount: Rs ${NumberFormat.decimalPattern().format(entry.totalPrice)}',
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete(entry.id);
              // Show success message after delete
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Entry deleted successfully',
                    style: AppFonts.poppins(),
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete',
              style: AppFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateReceipt(entry);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Generate Receipt',
              style: AppFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
      case 'active': // Handle old entries
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Generate receipt for trading entry
  void _generateReceipt(TradingEntry entry) {
    // Implementation for generating receipt
    // This could open a PDF, show a modal, or print the receipt
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Generate Receipt',
          style: AppFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Receipt generation feature coming soon for entry: ${entry.estateName ?? 'N/A'}',
          style: AppFonts.poppins(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: AppFonts.poppins(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
