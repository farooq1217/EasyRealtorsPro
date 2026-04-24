import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';

class CategorySelectionGrid extends StatelessWidget {
  final Function(String) onCategorySelected;
  final bool enabled;

  const CategorySelectionGrid({
    super.key,
    required this.onCategorySelected,
    this.enabled = true,
  });

  // Define the 8 office categories with their icons and colors
  static const List<Map<String, dynamic>> categories = [
    {
      'name': 'Utility Bills',
      'icon': Icons.electrical_services,
      'color': Color(0xFFFF6B35),
      'bgColor': Color(0xFFFFF3E9),
    },
    {
      'name': 'Staff Salary',
      'icon': Icons.people,
      'color': Color(0xFF4A90E2),
      'bgColor': Color(0xFFE8F4FD),
    },
    {
      'name': 'Grocery',
      'icon': Icons.shopping_cart,
      'color': Color(0xFF28A745),
      'bgColor': Color(0xFFE8F5E8),
    },
    {
      'name': 'Office Rent',
      'icon': Icons.home_work,
      'color': Color(0xFF6F42C1),
      'bgColor': Color(0xFFF3E8FF),
    },
    {
      'name': 'Stationery',
      'icon': Icons.edit,
      'color': Color(0xFFFD7E14),
      'bgColor': Color(0xFFFFF8E8),
    },
    {
      'name': 'Maintenance',
      'icon': Icons.build,
      'color': Color(0xFF20C997),
      'bgColor': Color(0xFFE8FCF5),
    },
    {
      'name': 'Marketing',
      'icon': Icons.campaign,
      'color': Color(0xFFE91E63),
      'bgColor': Color(0xFFFFE8F3),
    },
    {
      'name': 'Other',
      'icon': Icons.more_horiz,
      'color': Color(0xFF6C757D),
      'bgColor': Color(0xFFF8F9FA),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Quick Add Expense',
            style: AppFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a category to add expense instantly',
            style: AppFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Category Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3, // Better aspect ratio for Windows to prevent overflow
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              
              return _buildCategoryCard(
                context,
                category['name'] as String,
                category['icon'] as IconData,
                category['color'] as Color,
                category['bgColor'] as Color,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String name,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onCategorySelected(name) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container with Glassmorphism Effect
              Container(
                padding: const EdgeInsets.all(8), // Reduced padding
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10), // Slightly smaller radius
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20, // Smaller icon size
                ),
              ),
              const SizedBox(height: 6), // Reduced spacing
              
              // Category Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2), // Reduced padding
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 11, // Smaller font size
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
