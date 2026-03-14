// lib/modules/trading/trading_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show TradingEntry, TradingType;
import '../../domain/repositories/trading_repository.dart';
import '../../data/repositories/trading_repository_impl.dart';
import '../../presentation/view_models/trading_view_model.dart';
import '../../presentation/trading/widgets/trading_list.dart';
import '../../core/services/pdf_service.dart';
import '../../core/shared_utils.dart' show TopRightSearch;
import 'streamlined_trading_form.dart';

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
  String _categoryFilter = 'All Categories';

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
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFF6B35),
                      const Color(0xFFFF6B35).withOpacity(0.8),
                      const Color(0xFF4A90E2),
                    ],
                  ),
                ),
              ),
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
                      
                      // Professional Dropdown Filters - First Row
                      Row(
                        children: [
                          // Date Range Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dateRangeFilter,
                              decoration: InputDecoration(
                                labelText: 'Date Range',
                                prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFFFF6B35)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'Today', child: Text('Today')),
                                DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                                DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                                DropdownMenuItem(value: 'This Year', child: Text('This Year')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _dateRangeFilter = value;
                                    viewModel.filterByDateRange(value);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Transaction Type Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _transactionTypeFilter,
                              decoration: InputDecoration(
                                labelText: 'Transaction Type',
                                prefixIcon: const Icon(Icons.sync_alt, color: Color(0xFFFF6B35)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Transactions')),
                                DropdownMenuItem(value: 'Buy', child: Text('Buy')),
                                DropdownMenuItem(value: 'Sell', child: Text('Sell')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _transactionTypeFilter = value;
                                    if (value == 'All') {
                                      viewModel.filterByType(null);
                                    } else {
                                      viewModel.searchEntries(_searchQuery);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Professional Dropdown Filters - Second Row
                      Row(
                        children: [
                          // Category/Type Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _categoryFilter,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                prefixIcon: const Icon(Icons.category, color: Color(0xFFFF6B35)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All Categories', child: Text('All Categories')),
                                DropdownMenuItem(value: 'File', child: Text('File')),
                                DropdownMenuItem(value: 'Farm', child: Text('Farm')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _categoryFilter = value;
                                    // Apply category filter logic
                                    _applyCategoryFilter(value);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Status Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: viewModel.statusFilter,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                prefixIcon: const Icon(Icons.info_outline, color: Color(0xFFFF6B35)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Status')),
                                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  viewModel.filterByStatus(value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      // Clear Filters Row
                      if (_dateRangeFilter != 'All' || 
                          _transactionTypeFilter != 'All' || 
                          _categoryFilter != 'All Categories' ||
                          viewModel.statusFilter != 'All')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _dateRangeFilter = 'All';
                                    _transactionTypeFilter = 'All';
                                    _categoryFilter = 'All Categories';
                                    viewModel.clearFilters();
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear Filters'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF6B35),
                                ),
                              ),
                            ],
                          ),
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
            // Professional Floating Action Buttons
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Buy Button
                FloatingActionButton.extended(
                  onPressed: () => _showTradingFormDialog(true, TradingType.buy),
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Buy'),
                  heroTag: 'buyButton',
                ),
                const SizedBox(height: 12),
                // Sell Button
                FloatingActionButton.extended(
                  onPressed: () => _showTradingFormDialog(true, TradingType.sell),
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.work),
                  label: const Text('Sell'),
                  heroTag: 'sellButton',
                ),
              ],
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

  void _showTradingFormDialog(bool isFileTab, TradingType type) {
    final isBuy = type == TradingType.buy;
    final headerColor = isBuy ? const Color(0xFFFF6D3A) : const Color(0xFF4A90E2);
    final actionText = isBuy ? 'Buy' : 'Sell';
    
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
              // Dynamic Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      headerColor,
                      headerColor.withOpacity(0.8),
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
                      'Add $actionText Entry',
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
              
              // Streamlined Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStreamlinedTradingForm(type, isFileTab, headerColor, actionText, (entry) async {
                    try {
                      await viewModel.saveEntry(entry);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$actionText entry saved successfully!',
                              style: AppFonts.poppins(),
                            ),
                            backgroundColor: headerColor,
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
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamlinedTradingForm(TradingType type, bool isFileTab, Color headerColor, String actionText, Function(TradingEntry) onSave) {
    return StreamlinedTradingForm(
      type: type,
      isFileTab: isFileTab,
      headerColor: headerColor,
      actionText: actionText,
      onSave: onSave,
    );
  }

  void _applyCategoryFilter(String category) {
    // Apply category filter logic based on the current tab
    if (category == 'All Categories') {
      // Show all entries for current tab
      viewModel.searchEntries(_searchQuery);
    } else if (category == 'File') {
      // Filter to show only file entries
      if (_tabController.index == 1) {
        // Switch to Files tab if on Forms tab
        _tabController.animateTo(0);
      }
      viewModel.searchEntries(_searchQuery);
    } else if (category == 'Farm') {
      // Filter to show farm entries (could be a subcategory)
      viewModel.searchEntries(_searchQuery);
    }
  }
}
