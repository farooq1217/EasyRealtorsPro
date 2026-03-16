import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:shared/shared.dart' show TradingEntry;
import '../repositories/trading_repository.dart';
import '../repositories/trading_repository_impl.dart';
import '../view_models/trading_view_model.dart';
import '../widgets/trading_list.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/shared_utils.dart' show TopRightSearch;
import '../widgets/trading_form.dart';

class TradingPage extends StatefulWidget {
  final dynamic db;
  const TradingPage({super.key, required this.db});

  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage> {
  late TradingViewModel viewModel;
  String _searchQuery = '';
  String _dateRangeFilter = 'All';
  String _entryTypeFilter = 'All';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    
    final repo = TradingRepositoryImpl(widget.db);
    viewModel = TradingViewModel(repo);
  }

  @override
  void dispose() {
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
              title: Text(
                'Trading', 
                style: AppFonts.poppins(
                  color: Colors.white, 
                  fontWeight: FontWeight.w600
                )
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFF6B35),
                      const Color(0xFF4A90E2),
                    ],
                  ),
                ),
              ),
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => viewModel.refresh(),
                  tooltip: 'Refresh',
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
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange
                    const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue
                  ],
                ),
              ),
              child: Column(
                children: [
                // Filters Only
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
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
                          
                          // Entry Type Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _entryTypeFilter,
                              decoration: InputDecoration(
                                labelText: 'Entry Type',
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
                                DropdownMenuItem(value: 'All', child: Text('All Types')),
                                DropdownMenuItem(value: 'HP', child: Text('HP')),
                                DropdownMenuItem(value: 'KP', child: Text('KP')),
                                DropdownMenuItem(value: 'MP', child: Text('MP')),
                                DropdownMenuItem(value: 'NMP', child: Text('NMP')),
                                DropdownMenuItem(value: 'NNMP', child: Text('NNMP')),
                                DropdownMenuItem(value: 'BOP', child: Text('BOP')),
                                DropdownMenuItem(value: 'SOP', child: Text('SOP')),
                                DropdownMenuItem(value: 'AEMP', child: Text('AEMP')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _entryTypeFilter = value;
                                    // filterByType method removed - using simple string filters
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Status Dropdown
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _statusFilter,
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
                          _entryTypeFilter != 'All' ||
                          _statusFilter != 'All')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _dateRangeFilter = 'All';
                                    _entryTypeFilter = 'All';
                                    _statusFilter = 'All';
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
                
                // Entries List
                Expanded(
                  child: _buildEntriesList(viewModel),
                ),
                ],
              ),
            ),
            // Floating Action Button
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add Entry Button
                FloatingActionButton.extended(
                  onPressed: () => _showTradingFormDialog(),
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Add Entry',
                    style: AppFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntriesList(TradingViewModel viewModel) {
    final entries = viewModel.entries;
    
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
    
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No trading entries found',
              style: AppFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first trading entry to get started',
              style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    
    return TradingList(
      entries: entries,
      onDelete: (entryId) => viewModel.deleteEntry(entryId),
      isLoading: viewModel.isLoading,
    );
  }

  void _showTradingFormDialog() {
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
                    onSave: (entry) async {
                      try {
                        await viewModel.saveEntry(entry);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Trading entry saved successfully!',
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
                    onFormReset: () {
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
      ),
    );
  }

  
  }
