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
import '../../../widgets/standardized_footer.dart' show StandardizedFooter;

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
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Update ViewModel category when tab changes
        final newCategory = _tabController.index == 0 ? 'File' : 'Form';
        viewModel.setCurrentCategory(newCategory);
      }
    });
    
    viewModel = Provider.of<TradingViewModel>(context, listen: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          await viewModel.reinitializeIfNeeded();
          await viewModel.loadEntries();
          // Set initial category after loading
          viewModel.setCurrentCategory('File');
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            indicatorColor: Colors.purple,
            indicatorWeight: 3,
            labelColor: Colors.purple,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            labelStyle: AppFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            ),
            unselectedLabelStyle: AppFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 16.0,
            ),
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
            return Column( // Main body Column
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderAndTabs(), // Your top search, headers, or tabs
                      _buildFilters(),       // Any dropdowns/filters
                    ],
                  ),
                ),
                Expanded(
                  child: _tabController.index == 0 
                      ? _buildEntriesList(viewModel, 'File')
                      : _buildEntriesList(viewModel, 'Form'),
                ),
                // 4. Standardized Footer with pagination and add button
                Consumer<TradingViewModel>(
                  builder: (context, viewModel, child) {
                    return StandardizedFooter(
                      currentPage: viewModel.currentPage,
                      totalItems: _getFilteredEntriesCount(viewModel),
                      itemsPerPage: viewModel.itemsPerPage,
                      onPageChanged: (page) => viewModel.setPage(page),
                      onItemsPerPageChanged: (itemsPerPage) => viewModel.setItemsPerPage(itemsPerPage),
                      addButtonLabel: 'Add Trading Entry',
                      onAddPressed: () => _showTradingFormDialog(),
                      showAddButton: true,
                      addButtonColor: const Color(0xFFFF6B35),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  Widget _buildHeaderAndTabs() {
    return Column(
      children: [
        // TabBar is already in AppBar, so no need to rebuild here
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
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
          
          // Status dropdown in Row
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
    
    // The paginatedEntries are now already filtered by category in the ViewModel
    // No need to filter again here
    return TradingList(
      entries: viewModel.paginatedEntries, // Already filtered by currentCategory
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
                      initialCategory: viewModel.currentCategory, // Pass current tab category
                      onSave: (entry) async {
                        debugPrint('TradingPage: onSave callback called with entry: ${entry.toString()}');
                        try {
                          debugPrint('TradingPage: Calling viewModel.saveEntry...');
                          // Await the save operation without passing context
                          await viewModel.saveEntry(entry);
                          debugPrint('TradingPage: viewModel.saveEntry completed successfully');
                          
                          // Close dialog exactly once after successful save
                          if (dialogContext.mounted) {
                            debugPrint('TradingPage: Closing dialog...');
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
                          debugPrint('TradingPage: Error saving entry: $e');
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

  
  // Helper method to get filtered entries count for current category
  int _getFilteredEntriesCount(TradingViewModel viewModel) {
    final allEntries = viewModel.entries;
    final currentCategory = viewModel.currentCategory;
    
    return allEntries.where((entry) {
      // Apply same filtering logic as in ViewModel but only count
      if (entry.category != currentCategory) return false;
      
      // Apply other filters (search, status, date range, entry type)
      if (viewModel.searchQuery.isNotEmpty) {
        final query = viewModel.searchQuery.toLowerCase();
        final matchesSearch = entry.personName.toLowerCase().contains(query) ||
            entry.estateName.toLowerCase().contains(query) ||
            entry.mobileNo.toLowerCase().contains(query);
        if (!matchesSearch) return false;
      }
      
      if (viewModel.statusFilter != 'All' && viewModel.statusFilter.isNotEmpty) {
        if (entry.status.toLowerCase() != viewModel.statusFilter.toLowerCase()) return false;
      }
      
      // Date range filter (simplified for counting)
      if (viewModel.dateRangeFilter != 'All' && viewModel.dateRangeFilter.isNotEmpty) {
        final now = DateTime.now();
        bool matchesDateRange = false;
        
        switch (viewModel.dateRangeFilter) {
          case 'Today':
            matchesDateRange = entry.date.year == now.year && 
                             entry.date.month == now.month && 
                             entry.date.day == now.day;
            break;
          case 'This Week':
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            final weekEnd = weekStart.add(const Duration(days: 7));
            matchesDateRange = entry.date.isAfter(weekStart) && entry.date.isBefore(weekEnd);
            break;
          case 'This Month':
            matchesDateRange = entry.date.year == now.year && entry.date.month == now.month;
            break;
          case 'This Year':
            matchesDateRange = entry.date.year == now.year;
            break;
          default:
            matchesDateRange = true;
        }
        if (!matchesDateRange) return false;
      }
      
      if (viewModel.entryTypeFilter != 'All' && viewModel.entryTypeFilter.isNotEmpty) {
        if (entry.entryType != viewModel.entryTypeFilter) return false;
      }
      
      return true;
    }).length;
  }
}
