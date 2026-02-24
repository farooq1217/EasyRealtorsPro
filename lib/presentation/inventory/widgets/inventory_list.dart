// presentation/inventory/widgets/inventory_list.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../domain/models/inventory_item.dart';
import '../inventory_view_model.dart';
import 'inventory_detail_page.dart';
import '../../../core/phone_actions.dart' show showPhoneActionSheet;

class InventoryList extends StatefulWidget {
  const InventoryList({super.key});

  @override
  State<InventoryList> createState() => _InventoryListState();
}

class _InventoryListState extends State<InventoryList> {
  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryViewModel>(
      builder: (context, viewModel, child) {
        // Filter items by selected type
        final itemsForType = viewModel.filteredItems
            .where((item) => item.type == viewModel.selectedType)
            .toList();
        
        return Column(
          children: [
            // Filter Chips Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1B1F24)
                    : Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300.withOpacity(0.7)),
                ),
              ),
              child: Row(
                children: [
                  _buildFilterChip('All', null, viewModel),
                  const SizedBox(width: 8),
                  _buildFilterChip('Available', 'Not Sold', viewModel),
                  const SizedBox(width: 8),
                  _buildFilterChip('Sold', 'Sold', viewModel),
                  // Clear Filters button - only show when any filter is active
                  if (viewModel.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        viewModel.clearAllFilters();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Clear Filters'),
                    ),
                ],
              ),
            ),
            // Society and Block Dropdowns
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1B1F24)
                    : Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300.withOpacity(0.7)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: _buildDropdown(
                        'Society',
                        viewModel.societies,
                        viewModel.selectedSocietyId,
                        (value) => viewModel.setSelectedSociety(value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: _buildDropdown(
                        'Block',
                        viewModel.getAvailableBlocks(),
                        viewModel.selectedBlockId,
                        (value) => viewModel.setSelectedBlock(value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // List View
            Expanded(
              child: viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : itemsForType.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No items found',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
                          itemCount: itemsForType.length,
                          itemBuilder: (ctx, i) {
                            final item = itemsForType[i];
                            return _buildInventoryCard(item, viewModel);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String? value, InventoryViewModel viewModel) {
    final isSelected = viewModel.selectedStatusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        viewModel.setSelectedStatusFilter(selected ? value : null);
      },
      selectedColor: const Color(0xFF4A90E2).withOpacity(0.2),
      checkmarkColor: const Color(0xFF4A90E2),
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade700,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade300,
        width: isSelected ? 2 : 1,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<Map<String, String>> items,
    String? selectedValue,
    Function(String?) onChanged,
  ) {
    final hasItems = items.isNotEmpty;
    // Always show dropdown with placeholder, even when loading or empty
    final List<Map<String, String?>> displayItems = hasItems
        ? [
            {'id': null, 'name': 'All $label'}, // Add "All" option to clear filter
            ...items.map((item) => {'id': item['id'], 'name': item['name']}),
          ]
        : [{'id': null, 'name': 'Select $label'}];
    
    return DropdownButtonFormField<String?>(
      value: selectedValue,
      onChanged: hasItems ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select $label',
        prefixIcon: const Icon(Icons.list),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        filled: true,
        fillColor: Colors.white,
      ),
      items: displayItems.map((i) {
        final itemId = i['id'];
        final itemName = i['name'] ?? '';
        return DropdownMenuItem<String?>(
          value: itemId,
          child: Text(itemName),
          enabled: hasItems,
        );
      }).toList(),
    );
  }

  Widget _buildInventoryCard(InventoryItem item, InventoryViewModel viewModel) {
    final ownerName = item.clientName;
    final size = item.type == InventoryType.file 
        ? (item.path ?? '')
        : (item.price?.toString() ?? '');
    final status = item.saleStatus;
    final statusTextColor = status == 'Sold' 
        ? Colors.red.shade700 
        : Colors.blue.shade700;
    
    final TextStyle infoStyle = TextStyle(
      fontSize: 14,
      color: const Color(0xFFFF6B35),
    );
    
    // Build title: owner name • size/category
    final title = size.isNotEmpty 
        ? '$ownerName • $size'
        : ownerName;
    
    final sizeValue = size.trim();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Action'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InventoryDetailPage(
                          item: item,
                          viewModel: viewModel,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Flexible(child: Text('Edit')),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _showEditForm(item, viewModel),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          const Flexible(child: Text('Delete')),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _deleteItem(item.id, viewModel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildResponsiveInfoRow(
              context,
              [
                _InfoEntry('Owner Name', ownerName, style: infoStyle),
              ],
            ),
            // Size field with color coding
            if (sizeValue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Size: ',
                      style: infoStyle,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getSizeColor(sizeValue).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getSizeColor(sizeValue),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        sizeValue,
                        style: _getSizeStyle(sizeValue),
                      ),
                    ),
                  ],
                ),
              ),
            _buildResponsiveInfoRow(
              context,
              [
                _InfoEntry('Status', status, style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusTextColor,
                )),
              ],
            ),
            Text(
              'Updated: ${item.updatedAt.toIso8601String().split('T').first}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditForm(InventoryItem item, InventoryViewModel viewModel) {
    // This will be handled by the parent page
    // For now, we'll use a navigation approach
    Navigator.of(context).pop(); // Close popup menu
    // The parent page will need to handle this
  }

  Future<void> _deleteItem(String id, InventoryViewModel viewModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await viewModel.deleteItem(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete item: $e')),
          );
        }
      }
    }
  }

  // Helper function to get color for Size field based on Marla value
  Color _getSizeColor(String size) {
    final sizeLower = size.toLowerCase();
    
    if (sizeLower.contains('2 marla')) {
      return const Color(0xFFD2B48C); // Light beige/tan
    } else if (sizeLower.contains('3 marla')) {
      return const Color(0xFFE6E6FA); // Light purple/lavender
    } else if (sizeLower.contains('5 marla')) {
      return const Color(0xFF90EE90); // Light green
    } else if (sizeLower.contains('8 marla')) {
      return const Color(0xFFFFB6C1); // Light pink
    } else {
      return const Color(0xFFFF6B35); // Orange - default color
    }
  }

  // Helper function to get style for Size field based on Marla value
  TextStyle _getSizeStyle(String size) {
    final sizeColor = _getSizeColor(size);
    
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: sizeColor,
    );
  }

  Widget _buildResponsiveInfoRow(BuildContext context, List<_InfoEntry> entries) {
    return Row(
      children: entries.map((entry) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.value,
                  style: entry.style ?? GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InfoEntry {
  final String label;
  final String value;
  final TextStyle? style;

  _InfoEntry(this.label, this.value, {this.style});
}
