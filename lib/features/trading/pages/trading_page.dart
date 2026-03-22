import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show TradingEntry, RoleUtils, AppDatabase;
import '../repositories/trading_repository.dart';
import '../repositories/trading_repository_impl.dart';
import '../view_models/trading_view_model.dart';
import '../widgets/trading_list.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/shared_utils.dart' show TopRightSearch;
import '../widgets/trading_form.dart';
import '../../../widgets/custom_pagination_card.dart' show CustomPaginationCard;

class TradingPage extends StatefulWidget {
  final dynamic db;
  const TradingPage({super.key, required this.db});

  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage> with TickerProviderStateMixin {
  late TradingViewModel viewModel;
  late TabController _tabController;
  String _searchQuery = '';
  String _dateRangeFilter = 'All';
  String _entryTypeFilter = 'All';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    viewModel = Provider.of<TradingViewModel>(context, listen: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          await viewModel.reinitializeIfNeeded();
          await viewModel.loadEntries();
        } catch (e) {
          debugPrint("Error loading data: $e");
          // Yahan error handle karein takay UI block na ho
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold( // Direct Scaffold use karein
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            'Trading', 
            style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)],
              ),
            ),
          ),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelStyle: AppFonts.poppins(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'File'),
              Tab(text: 'Form'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => viewModel.refresh(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: TopRightSearch(
                onChanged: (value) {
                  _searchQuery = value;
                  viewModel.searchEntries(value);
                },
              ),
            ),
          ],
        ),
        body: Consumer<TradingViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                const SizedBox(height: 12),
                // Filter Section
Container(
  padding: const EdgeInsets.all(16),
  color: Colors.white,
  child: Column(
    children: [
      Row(
        children: [
          _buildFilterDropdown(
            label: 'Date Range',
            value: _dateRangeFilter,
            icon: Icons.calendar_today,
            items: ['All', 'Today', 'This Week', 'This Month', 'This Year'],
            onChanged: (val) {
              setState(() => _dateRangeFilter = val!);
              viewModel.filterByDateRange(val!);
            },
          ),
          const SizedBox(width: 12),
          _buildFilterDropdown(
            label: 'Select payment option',
            value: _entryTypeFilter,
            icon: Icons.category,
            items: ['All', 'HP', 'KP', 'MP', 'NMP', 'NNMP', 'BOP', 'SOP', 'AEMP'],
            onChanged: (val) {
              if (val != null) {
                setState(() => _entryTypeFilter = val);
                viewModel.filterByEntryType(val);
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      
      // YAHAN FIX HAI: Status dropdown ko Row mein wrap kar diya hai
      Row(
        children: [
          _buildFilterDropdown(
            label: 'Status',
            value: _statusFilter,
            icon: Icons.info_outline,
            items: ['All', 'Pending', 'Completed', 'Cancelled'],
            onChanged: (val) {
              setState(() => _statusFilter = val!);
              viewModel.filterByStatus(val!);
            },
          ),
        ],
      ),
      
      if (_dateRangeFilter != 'All' || _entryTypeFilter != 'All' || _statusFilter != 'All')
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _dateRangeFilter = 'All';
                _entryTypeFilter = 'All';
                _statusFilter = 'All';
              });
              viewModel.clearFilters();
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear Filters'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B35),
            ),
          ),
        ),
    ],
  ),
),
                // Scrollable Content Area
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // File Tab - Show only File entries
                      Container(
                        height: double.infinity,
                        child: _buildEntriesList(viewModel, 'File'),
                      ),
                      // Form Tab - Show only Form entries  
                      Container(
                        height: double.infinity,
                        child: _buildEntriesList(viewModel, 'Form'),
                      ),
                    ],
                  ),
                ),
                // Pagination Card (Fixed at bottom)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: _buildPaginationCard(viewModel),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showTradingFormDialog(),
          backgroundColor: const Color(0xFFFF6B35),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Add',
            style: AppFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }


  // Get current active tab name
  String _getCurrentTab() {
    return _tabController.index == 0 ? 'File' : 'Form';
  }

  // Helper method for clean dropdowns
  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFFFF6B35)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildEntriesList(TradingViewModel viewModel, String category) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Filter paginated entries by category using the new category field from TradingEntry
    final filteredPaginatedEntries = viewModel.paginatedEntries.where((entry) {
      // Use the category field from TradingEntry model
      return entry.category == category;
    }).toList();
    
    return TradingList(
      entries: filteredPaginatedEntries,
      onDelete: (entryId) => viewModel.deleteEntry(entryId),
      isLoading: false,
      onStatusUpdate: (entryId, newStatus) => viewModel.updateEntryStatus(entryId, newStatus, context: context),
    );
  }

  void _showTradingFormDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Get the existing ViewModel from context - DO NOT create a new provider
        final viewModel = context.read<TradingViewModel>();
        
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF6B35),
                        Color(0xFF4A90E2),
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
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Add Trading Entry',
                        style: AppFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                
                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: GenericTradingForm(
                      viewModel: viewModel,
                      onSave: (entry) async {
                        try {
                          // Await the save operation without passing context
                          await viewModel.saveEntry(entry);
                          
                          // Close dialog exactly once after successful save
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          
                          // Show success message using main context
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Trading entry saved successfully!',
                                  style: AppFonts.poppins(),
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          // Show error message using dialog context so it's visible without closing
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error saving entry: $e',
                                  style: AppFonts.poppins(),
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 3),
                                action: SnackBarAction(
                                  label: 'OK',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();
                                  },
                                ),
                              ),
                            );
                          }
                        }
                      },
                      onFormReset: () {
                        // Close dialog cleanly when cancel is pressed
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationCard(TradingViewModel viewModel) {
    // Get total filtered entries for pagination
    final totalFilteredEntries = viewModel.entries.length;
    
    return CustomPaginationCard(
      currentPage: viewModel.currentPage,
      totalItems: totalFilteredEntries,
      itemsPerPage: viewModel.itemsPerPage,
      onPageChanged: (page) => viewModel.setPage(page),
      onItemsPerPageChanged: (limit) => viewModel.setItemsPerPage(limit),
    );
  }
}
