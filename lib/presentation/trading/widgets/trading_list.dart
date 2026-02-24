import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/trading_entry.dart';
import '../../../core/services/pdf_service.dart';

class TradingList extends StatelessWidget {
  final List<TradingEntry> entries;
  final Function(String) onDelete;
  final bool isLoading;

  const TradingList({super.key, required this.entries, required this.onDelete, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text("No transactions found", 
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 16)),
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

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile( // ExpansionTile use kiya taake overflow ka khatra hi na rahe
            leading: CircleAvatar(
              backgroundColor: isBuy ? Colors.green.shade50 : Colors.red.shade50,
              child: Icon(
                isBuy ? Icons.add_shopping_cart : Icons.sell,
                color: isBuy ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(
              entry.personName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              "${entry.estateName} • ${DateFormat('dd MMM').format(entry.date)}",
              style: GoogleFonts.poppins(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Rs. ${NumberFormat('#,###').format(entry.totalAmount)}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: isBuy ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.entryType.toString().split('.').last.toUpperCase(),
                    style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow("Mobile", entry.mobile),
                    if (entry.plotNo != null) _buildDetailRow("Plot/Form #", entry.plotNo!),
                    if (entry.block != null) _buildDetailRow("Block", entry.block!),
                    if (entry.rate != null) _buildDetailRow("Rate", "Rs. ${NumberFormat('#,###').format(entry.rate)}"),
                    if (entry.commission != null) _buildDetailRow("Commission", "Rs. ${NumberFormat('#,###').format(entry.commission)}"),
                    if (entry.tax != null) _buildDetailRow("Tax", "Rs. ${NumberFormat('#,###').format(entry.tax)}"),
                    if (entry.netAmount != null) _buildDetailRow("Net Amount", "Rs. ${NumberFormat('#,###').format(entry.netAmount)}"),
                    _buildDetailRow("Status", entry.status, isStatus: true),
                    if (entry.comments != null && entry.comments!.isNotEmpty)
                      _buildDetailRow("Comments", entry.comments!),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => onDelete(entry.id),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text("Delete", style: TextStyle(color: Colors.red)),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _generateReceipt(entry),
                          icon: const Icon(Icons.receipt, size: 16),
                          label: const Text("Generate Receipt"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: GoogleFonts.poppins(
            fontSize: 13, 
            fontWeight: FontWeight.w500,
            color: isStatus ? Colors.orange.shade800 : Colors.black87,
          )),
        ],
      ),
    );
  }

  void _generateReceipt(TradingEntry entry) {
    // Generate professional receipt for this specific transaction
    PdfService.generateTradingReceipt(entry);
  }
}