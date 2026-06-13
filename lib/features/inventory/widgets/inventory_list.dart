// presentation/inventory/widgets/inventory_list.dart
import 'package:flutter/material.dart';
import '../../../../core/font_utils.dart';

import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../view_models/inventory_view_model.dart';
import 'inventory_detail_page.dart';
import 'inventory_details_modal.dart';
import 'inventory_form.dart';
import '../../../core/phone_actions.dart' show showPhoneActionSheet;
import '../../../widgets/standardized_footer.dart' show StandardizedFooter;

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
                
        // Filter paginated items by selected type
        final paginatedItemsForType = viewModel.paginatedItems
            .where((item) => item.type == viewModel.selectedType)
            .toList();
        
        return Column(
          children: [
            // Filter Chips and Dropdowns fixed at the top
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Chips Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1B1F24)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300.withOpacity(0.7)),
                    ),
                    child: Row(
                      children: [
                        _buildFilterChip('All', null, viewModel),
                        const SizedBox(width: 8),
                        _buildFilterChip('Available', 'Not Sold', viewModel),
                        const SizedBox(width: 8),
                        _buildFilterChip('Sold', 'Sold', viewModel),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Society and Block Dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          key: ValueKey('dropdown_${viewModel.selectedSocietyId}_${viewModel.societies.length}'),
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
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          key: ValueKey('dropdown_${viewModel.selectedSocietyId}_${viewModel.blocks.length}'),
                          child: SizedBox(
                            height: 60,
                            child: _buildDropdown(
                              'Block',
                              viewModel.getAvailableBlocks(),
                              viewModel.selectedBlockId,
                              // CRITICAL FIX: Disable Block dropdown if no specific society is selected
                              (viewModel.selectedSocietyId == null || viewModel.selectedSocietyId == 'All') 
                                  ? null // This disables the dropdown
                                  : (String? value) => viewModel.setSelectedBlock(value),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Scrollable List View
            Expanded(
              child: viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : paginatedItemsForType.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No items found',
                                style: AppFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters or add new items',
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: paginatedItemsForType.length,
                          itemBuilder: (ctx, i) {
                            final item = paginatedItemsForType[i];
                            return _buildInventoryCard(item, viewModel);
                          },
                        ),
            ),
            // Standardized Footer with pagination and add button
            Container(
              padding: const EdgeInsets.all(16),
              child: StandardizedFooter(
                currentPage: viewModel.currentPage,
                totalItems: viewModel.filteredItems
                    .where((item) => item.type == viewModel.selectedType)
                    .length,
                itemsPerPage: viewModel.itemsPerPage,
                onPageChanged: (page) => viewModel.setPage(page),
                onItemsPerPageChanged: (itemsPerPage) => viewModel.setItemsPerPage(itemsPerPage),
                addButtonLabel: 'Add Item',
                onAddPressed: () => _showAddFormDialog(context, viewModel),
                showAddButton: true,
                addButtonColor: const Color(0xFFFF6B35),
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
      labelStyle: AppFonts.poppins(
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
    void Function(String?)? onChanged,
  ) {
    final hasItems = items.isNotEmpty;
    final isDisabled = onChanged == null; // Check if dropdown is disabled
    
    // Always show dropdown with placeholder, even when loading or empty
    final List<Map<String, String?>> displayItems = hasItems
        ? [
            {'id': null, 'name': 'All $label'}, // Add "All" option to clear filter
            ...items.map((item) => {'id': item['id'], 'name': item['name']}),
          ]
        : [{'id': null, 'name': isDisabled ? 'Select a Society first' : 'Select $label'}];
    
    // CRITICAL FIX: Show "All Society" when selectedValue is null
    // The dropdown will automatically select the first item with value=null when selectedValue is null
    final displayValue = selectedValue;
    
    return DropdownButtonFormField<String?>(
      value: displayValue, // Use display value to show "All Society" when null
      onChanged: hasItems ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: isDisabled ? 'Select a Society first' : 'Select $label',
        prefixIcon: const Icon(Icons.list),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        filled: true,
        fillColor: isDisabled ? Colors.grey.shade100 : Colors.white,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      items: displayItems.map((i) {
        final itemId = i['id'];
        final itemName = i['name'] ?? '';
        return DropdownMenuItem<String?>(
          value: itemId,
          child: Text(
            itemName,
            style: TextStyle(
              color: isDisabled ? Colors.grey.shade500 : null,
            ),
          ),
          enabled: hasItems && !isDisabled,
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
    
    return InkWell(
      onTap: () => _showInventoryDetailsModal(context, item, viewModel),
      borderRadius: BorderRadius.circular(12),
      child: Card(
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
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEditForm(context, item, viewModel);
                    } else if (value == 'delete') {
                      await _deleteItem(context, item, viewModel);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
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
      ),
    );
  }

  // Helper methods inside the class
  void _showInventoryDetailsModal(BuildContext context, InventoryItem item, InventoryViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => InventoryDetailsModal(
        inventoryItem: item,
        onRefresh: () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.loadItems();
            });
          }
        },
      ),
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
                  entry.label ?? '',
                  style: entry.style ?? AppFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.value ?? '',
                  style: entry.style ?? AppFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

  // Show edit form dialog
  void _showEditForm(BuildContext context, InventoryItem item, InventoryViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with back button
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 2),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                // Scrollable form content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ChangeNotifierProvider.value(
                      value: viewModel,
                      child: InventoryForm(
                        existing: item,
                        onSave: () { 
                          Navigator.of(dialogContext).pop(); 
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Delete item with confirmation
  Future<void> _deleteItem(BuildContext context, InventoryItem item, InventoryViewModel viewModel) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete this ${item.type.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await viewModel.deleteItem(item.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  }

  void _showAddFormDialog(BuildContext context, InventoryViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with back button
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 2),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                // Scrollable form content
                Flexible(
                  child: SingleChildScrollView(
                    child: ChangeNotifierProvider.value(
                      value: viewModel,
                      child: InventoryForm(
                        onSave: () {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Item saved successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

class _InfoEntry {
  final String label;
  final String value;
  final TextStyle? style;
  
  const _InfoEntry(this.label, this.value, {this.style});
}
