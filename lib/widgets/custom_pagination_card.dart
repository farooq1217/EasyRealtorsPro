import 'package:flutter/material.dart';

class CustomPaginationCard extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int itemsPerPage;
  final Function(int) onPageChanged;
  final Function(int) onItemsPerPageChanged;

  const CustomPaginationCard({
    Key? key,
    required this.currentPage,
    required this.totalItems,
    this.itemsPerPage = 10,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
  }) : super(key: key);

  int get totalPages => (totalItems / itemsPerPage).ceil();

  int get startIndex => ((currentPage - 1) * itemsPerPage) + 1;

  int get endIndex => currentPage * itemsPerPage > totalItems ? totalItems : currentPage * itemsPerPage;

  // Helper method to get valid items per page options including current value
  List<int> _getItemsPerPageOptions() {
    final Set<int> options = {10, 25, 50}; // Default options
    // Only add current value if it's reasonable (between 5 and 100)
    if (itemsPerPage >= 5 && itemsPerPage <= 100) {
      options.add(itemsPerPage);
    }
    return options.toList()..sort(); // Sort for consistent order
  }

  // Helper method to get a valid items per page value
  int _getValidItemsPerPage(int value) {
    final options = _getItemsPerPageOptions();
    // If current value is valid and in options, use it
    if (options.contains(value)) {
      return value;
    }
    // Otherwise fallback to 10 (first in default options)
    return 10;
  }

  List<int> getVisiblePageNumbers() {
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        height: 56, // Fixed height for compact bar
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // Left Side: Items per page dropdown
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Text(
                    'Items per page:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _getValidItemsPerPage(itemsPerPage),
                        items: _getItemsPerPageOptions().map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(value.toString()),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            onItemsPerPageChanged(newValue);
                          }
                        },
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Middle: Showing text
            Expanded(
              flex: 3,
              child: Center(
                child: Text(
                  'Showing $startIndex - $endIndex of $totalItems entries',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            // Right Side: Pagination controls
            Expanded(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                  ...getVisiblePageNumbers().map((pageNumber) => Padding(
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
          ],
        ),
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive 
                ? Colors.transparent
                : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: TextStyle(
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
