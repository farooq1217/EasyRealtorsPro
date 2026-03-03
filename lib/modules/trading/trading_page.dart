// lib/modules/trading/trading_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import '../../domain/models/trading_entry.dart';
import '../../domain/repositories/trading_repository.dart';
import '../../data/repositories/trading_repository_impl.dart';
import '../../presentation/view_models/trading_view_model.dart';
import '../../presentation/trading/widgets/trading_form.dart';
import '../../presentation/trading/widgets/trading_list.dart';
import '../../core/services/pdf_service.dart';
import '../../core/shared_utils.dart' show TopRightSearch;

class TradingPage extends StatefulWidget {
  final dynamic db;
  const TradingPage({super.key, required this.db});

  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TradingViewModel viewModel;
  String _searchQuery = '';
  String _dateRangeFilter = 'All';
  String _transactionTypeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Add tab listener to force re-filtering when tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Force rebuild to re-filter data for active tab
      }
    });
    
    final repo = TradingRepositoryImpl(widget.db);
    viewModel = TradingViewModel(repo);
  }

  @override
  void dispose() {
    _tabController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TradingViewModel>.value(
      value: viewModel,
      child: Consumer<TradingViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              title: Text('Trading', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFF2D3748),
              foregroundColor: Colors.white,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFF6B35),
                labelColor: const Color(0xFFFF6B35),
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Files'),
                  Tab(text: 'Forms'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => viewModel.refresh(),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            body: Column(
              children: [
                // Search and Filters
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search Bar
                      TopRightSearch(
                        onChanged: (value) {
                          _searchQuery = value;
                          viewModel.searchEntries(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Filter Chips
                      Row(
                        children: [
                          // Date Range Filter
                          FilterChip(
                            label: Text(_dateRangeFilter),
                            selected: _dateRangeFilter != 'All',
                            onSelected: (selected) {
                              _showDateRangeFilter();
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: const Color(0xFFFF6B35).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _dateRangeFilter != 'All' 
                                ? const Color(0xFFFF6B35) 
                                : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Transaction Type Filter
                          FilterChip(
                            label: Text(_transactionTypeFilter),
                            selected: _transactionTypeFilter != 'All',
                            onSelected: (selected) {
                              _showTransactionTypeFilter();
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: const Color(0xFFFF6B35).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _transactionTypeFilter != 'All' 
                                ? const Color(0xFFFF6B35) 
                                : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Status Filter
                          FilterChip(
                            label: Text(viewModel.statusFilter),
                            selected: viewModel.statusFilter != 'All',
                            onSelected: (selected) {
                              _showStatusFilter();
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: const Color(0xFFFF6B35).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: viewModel.statusFilter != 'All' 
                                ? const Color(0xFFFF6B35) 
                                : Colors.grey.shade700,
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Clear Filters
                          if (_dateRangeFilter != 'All' || 
                              _transactionTypeFilter != 'All' || 
                              viewModel.statusFilter != 'All')
                            TextButton.icon(
                              onPressed: () {
                                _dateRangeFilter = 'All';
                                _transactionTypeFilter = 'All';
                                viewModel.clearFilters();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6B35),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Files Tab
                      _buildFilesTab(viewModel),
                      
                      // Forms Tab
                      _buildFormsTab(viewModel),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showTradingFormDialog(_tabController.index == 0),
              backgroundColor: const Color(0xFFFF6B35),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilesTab(TradingViewModel viewModel) {
    final fileEntries = viewModel.fileEntries;
    
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (viewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: AppFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.error!,
              style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (fileEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No file entries found',
              style: AppFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first file entry to get started',
              style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    
    return TradingList(
      entries: fileEntries,
      onDelete: (entryId) => viewModel.deleteEntry(entryId),
      isLoading: viewModel.isLoading,
    );
  }

  Widget _buildFormsTab(TradingViewModel viewModel) {
    final formEntries = viewModel.formEntries;
    
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (viewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: AppFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.error!,
              style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (formEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No form entries found',
              style: AppFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first form entry to get started',
              style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    
    return TradingList(
      entries: formEntries,
      onDelete: (entryId) => viewModel.deleteEntry(entryId),
      isLoading: viewModel.isLoading,
    );
  }

  void _showTradingFormDialog(bool isFileTab) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
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
                decoration: const BoxDecoration(
                  color: Color(0xFF2D3748),
                  borderRadius: BorderRadius.only(
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
                      'Add ${isFileTab ? 'File' : 'Form'} Entry',
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
                child: GenericTradingForm(
                  type: TradingType.buy, // Default type
                  isFileTab: isFileTab,
                  onSave: (entry) async {
                    try {
                      await viewModel.saveEntry(entry);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Trading ${isFileTab ? 'File' : 'Form'} entry saved successfully!',
                              style: AppFonts.poppins(),
                            ),
                            backgroundColor: const Color(0xFFFF6B35),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error saving entry: $e',
                              style: AppFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDateRangeFilter() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Filter by Date Range',
          style: AppFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDateOption('All', 'All'),
            _buildDateOption('Today', 'Today'),
            _buildDateOption('This Week', 'This Week'),
            _buildDateOption('This Month', 'This Month'),
            _buildDateOption('This Year', 'This Year'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label, style: AppFonts.poppins()),
      value: value,
      groupValue: _dateRangeFilter,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _dateRangeFilter = value;
            viewModel.filterByDateRange(value);
          });
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _showTransactionTypeFilter() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Filter by Transaction Type',
          style: AppFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTransactionTypeOption('All', 'All'),
            _buildTransactionTypeOption('Buy', 'Buy'),
            _buildTransactionTypeOption('Sell', 'Sell'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label, style: AppFonts.poppins()),
      value: value,
      groupValue: _transactionTypeFilter,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _transactionTypeFilter = value;
            if (value == 'All') {
              viewModel.filterByType(null);
            } else {
              // For transaction type filter, we need to filter by type in the search query
              // This will be handled in the ViewModel's _getFilteredEntries method
              viewModel.searchEntries(_searchQuery);
            }
          });
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Filter by Status',
          style: AppFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption('All', 'All'),
            _buildStatusOption('Pending', 'Pending'),
            _buildStatusOption('Completed', 'Completed'),
            _buildStatusOption('Cancelled', 'Cancelled'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label, style: AppFonts.poppins()),
      value: value,
      groupValue: viewModel.statusFilter,
      onChanged: (value) {
        if (value != null) {
          viewModel.filterByStatus(value);
          Navigator.of(context).pop();
        }
      },
    );
  }
}
