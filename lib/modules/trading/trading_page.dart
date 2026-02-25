// lib/modules/trading/trading_page.dart
import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import '../../domain/models/trading_entry.dart';
import '../../domain/repositories/trading_repository.dart';
import '../../data/repositories/trading_repository_impl.dart';
import '../../presentation/trading/trading_view_model.dart';
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
    viewModel.loadEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trading Management', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: "Trading File"), Tab(text: "Trading Form")],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TopRightSearch(onChanged: (q) => setState(() => _searchQuery = q)),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.entries == null) return Center(child: Text('Loading...'));
          
          return Column(
            children: [
              _buildFilterRow(),
              // Tab content with buttons
              Container(
                height: 80,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabContent(isFileTab: true),
                    _buildTabContent(isFileTab: false),
                  ],
                ),
              ),
              // List Section
              Expanded(
                child: Stack(
                  children: [
                    // TradingList is ALWAYS visible
                    TradingList(
                      // Filter by entryType based on current tab
                      entries: viewModel.entries.where((entry) {
                        // 1. Tab Filter - CRITICAL: Only show entries matching current tab
                        final currentTabIndex = _tabController.index;
                        final matchesTab = (currentTabIndex == 0 && entry.entryType == TradingEntryType.file) ||
                                           (currentTabIndex == 1 && entry.entryType == TradingEntryType.form);
                        
                        if (!matchesTab) return false;
                        
                        // 2. Search Filter
                        final matchesSearch = entry.personName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            entry.estateName.toLowerCase().contains(_searchQuery.toLowerCase());

                        // 3. Transaction Type Filter
                        final matchesType = _transactionTypeFilter == 'All' || 
                            entry.type.toString().split('.').last.toLowerCase() == _transactionTypeFilter.toLowerCase();

                        // 4. Date Filter (Simplified)
                        // Note: Aap isey mazeed behtar kar sakte hain DateFormat use karke
                        bool matchesDate = true; 
                        if (_dateRangeFilter == 'Today') {
                          final now = DateTime.now();
                          matchesDate = entry.date.year == now.year && 
                                        entry.date.month == now.month && 
                                        entry.date.day == now.day;
                        } else if (_dateRangeFilter == 'This Week') {
                          final now = DateTime.now();
                          final weekStart = now.subtract(Duration(days: now.weekday - 1));
                          final weekEnd = weekStart.add(const Duration(days: 6));
                          matchesDate = entry.date.isAfter(weekStart.subtract(const Duration(days: 1))) && 
                                        entry.date.isBefore(weekEnd.add(const Duration(days: 1)));
                        } else if (_dateRangeFilter == 'This Month') {
                          final now = DateTime.now();
                          matchesDate = entry.date.year == now.year && 
                                        entry.date.month == now.month;
                        }

                        return matchesSearch && matchesType && matchesDate;
                      }).toList(),
                      onDelete: (id) async {
                        await viewModel.deleteEntry(id);
                      },
                    ),
                    // Show loading indicator ONLY when loading, on top of the list
                    if (viewModel.isLoading)
                      Container(
                        color: Colors.white.withOpacity(0.8),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _buildDropdown('Date Range', _dateRangeFilter, ['All', 'Today', 'This Week', 'This Month'], (v) => setState(() => _dateRangeFilter = v!))),
          const SizedBox(width: 10),
          Expanded(child: _buildDropdown('Type', _transactionTypeFilter, ['All', 'Buy', 'Sell'], (v) => setState(() => _transactionTypeFilter = v!))),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTabContent({required bool isFileTab}) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildActionButton(isFileTab, TradingType.buy),
          const SizedBox(width: 8),
          _buildActionButton(isFileTab, TradingType.sell),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool isFileTab, TradingType type) {
    String label = "${type == TradingType.buy ? 'Buy' : 'Sell'} ${isFileTab ? 'File' : 'Form'}";
    return FloatingActionButton.extended(
      heroTag: label, // Unique tag to prevent crash
      onPressed: () => _showTradingFormDialog(isFileTab, type),
      label: Text(label),
      icon: Icon(type == TradingType.buy ? Icons.add_shopping_cart : Icons.sell),
    );
  }


  void _showTradingFormDialog(bool isFileTab, TradingType type) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogBuilderContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogBuilderContext).size.width * 0.9,
            maxHeight: MediaQuery.of(dialogBuilderContext).size.height * 0.9,
          ),
          child: Column(
            children: [
              // Header with back button
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(dialogBuilderContext).pop(),
                      style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 2),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // Scrollable form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: GenericTradingForm(
                    type: type,
                    isFileTab: isFileTab,
                    onSave: (entry) async {
  try {
    // Save entry first and wait for completion
    await viewModel.saveEntry(entry);
    
    // Add small delay to ensure database operation completes
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Explicitly reload entries to ensure UI updates immediately
    await viewModel.loadEntries();
    
    // Only close dialog after successful save
    if (dialogBuilderContext.mounted) {
      Navigator.of(dialogBuilderContext).pop();
    }
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trading ${isFileTab ? 'File' : 'Form'} entry saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    // Keep dialog open on error so user can try again
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error saving entry: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
},
                    onFormReset: () {
                      if (dialogBuilderContext.mounted) {
                        Navigator.of(dialogBuilderContext).pop();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(onPressed: () async {
            await viewModel.deleteEntry(id);
            Navigator.pop(ctx);
          }, child: const Text("Yes")),
        ],
      ),
    );
  }
}