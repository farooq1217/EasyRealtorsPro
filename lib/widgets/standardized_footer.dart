import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';

class StandardizedFooter extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int itemsPerPage;
  final Function(int) onPageChanged;
  final Function(int) onItemsPerPageChanged;
  final String addButtonLabel;
  final VoidCallback? onAddPressed;
  final bool showAddButton;
  final Color addButtonColor;

  const StandardizedFooter({
    Key? key,
    required this.currentPage,
    required this.totalItems,
    this.itemsPerPage = 10,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.addButtonLabel = 'Add',
    this.onAddPressed,
    this.showAddButton = true,
    this.addButtonColor = const Color(0xFFFF6B35),
  }) : super(key: key);

  int get totalPages => (totalItems / itemsPerPage).ceil();

  int get startIndex => ((currentPage - 1) * itemsPerPage) + 1;

  int get endIndex => currentPage * itemsPerPage > totalItems ? totalItems : currentPage * itemsPerPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use Row for wide screens, Wrap for narrow screens
          if (constraints.maxWidth > 800) {
            // Wide screen layout - use Row
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Side: Pagination controls
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Previous button
                        _buildPaginationButton(
                          context: context,
                          text: 'Previous',
                          onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                          isActive: false,
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Page numbers
                        ..._getVisiblePageNumbers().map((pageNumber) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _buildPaginationButton(
                            context: context,
                            text: pageNumber.toString(),
                            onPressed: () => onPageChanged(pageNumber),
                            isActive: pageNumber == currentPage,
                          ),
                        )).toList(),
                        
                        const SizedBox(width: 8),
                        
                        // Next button
                        _buildPaginationButton(
                          context: context,
                          text: 'Next',
                          onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                          isActive: false,
                        ),
                      ],
                    ),
                  ),
                ),

                // Middle: Items per page and showing info
                Expanded(
                  flex: 1,
                  child: Text(
                    'Showing $startIndex - $endIndex of $totalItems',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Right Side: Add button
                if (showAddButton)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: addButtonColor.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onAddPressed,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          addButtonLabel,
                          style: AppFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: addButtonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          } else {
            // Narrow screen layout - use Wrap
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16.0,
              runSpacing: 12.0,
              children: [
                // Left Side: Pagination controls
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Previous button
                        _buildPaginationButton(
                          context: context,
                          text: 'Previous',
                          onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                          isActive: false,
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Page numbers
                        ..._getVisiblePageNumbers().map((pageNumber) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _buildPaginationButton(
                            context: context,
                            text: pageNumber.toString(),
                            onPressed: () => onPageChanged(pageNumber),
                            isActive: pageNumber == currentPage,
                          ),
                        )).toList(),
                        
                        const SizedBox(width: 8),
                        
                        // Next button
                        _buildPaginationButton(
                          context: context,
                          text: 'Next',
                          onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                          isActive: false,
                        ),
                      ],
                    ),
                  ),
                ),

                // Middle: Items per page and showing info
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Showing $startIndex - $endIndex of $totalItems',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Right Side: Add button
                if (showAddButton)
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: addButtonColor.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onAddPressed,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          addButtonLabel,
                          style: AppFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: addButtonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }
        },
      ),
    );
  }

  List<int> _getVisiblePageNumbers() {
    final List<int> visiblePages = [];
    final int totalPages = this.totalPages;
    
    if (totalPages <= 5) {
      // If total pages is 5 or less, show all pages
      for (int i = 1; i <= totalPages; i++) {
        visiblePages.add(i);
      }
    } else {
      // Implement sliding window logic
      int start = currentPage - 2;
      int end = currentPage + 2;
      
      // Adjust boundaries
      if (start < 1) {
        start = 1;
        end = 5;
      }
      if (end > totalPages) {
        end = totalPages;
        start = totalPages - 4;
      }
      
      for (int i = start; i <= end; i++) {
        visiblePages.add(i);
      }
    }
    
    return visiblePages;
  }

  Widget _buildPaginationButton({
    required BuildContext context,
    required String text,
    required VoidCallback? onPressed,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Material(
      color: isActive 
        ? (isDark ? theme.primaryColor : Colors.grey[800])
        : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive 
                ? Colors.transparent
                : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive 
                ? Colors.white
                : (onPressed != null 
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}
