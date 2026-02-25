import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../../domain/models/expenditure_item.dart';
import '../../core/professional_pdf_generator.dart';
import '../../core/shared_utils.dart';
import '../../shimmer_widgets.dart';
import 'expenditure_view_model.dart';

class ExpenditurePage extends StatefulWidget {
  final AppDatabase db;
  const ExpenditurePage({super.key, required this.db});

  @override
  State<ExpenditurePage> createState() => _ExpenditurePageState();
}

class _ExpenditurePageState extends State<ExpenditurePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ExpenditureViewModel _viewModel;
  
  final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewModel = ExpenditureViewModel(widget.db);
    
    // Initialize ViewModel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize();
    });
    
    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _viewModel.setCurrentTab(
          _tabController.index == 0 ? ExpenditureTab.office : ExpenditureTab.project
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExpenditureViewModel>.value(
      value: _viewModel,
      child: Consumer<ExpenditureViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.loading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          return Scaffold(
            appBar: AppBar(
              title: Text('Expenditures', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: "Office Expense", icon: Icon(Icons.business_center)),
                  Tab(text: "Projects", icon: Icon(Icons.assignment)),
                ],
              ),
              actions: [
                // Professional Receipt Generation
                IconButton(
                  icon: const Icon(Icons.receipt_long),
                  onPressed: () => _generateProfessionalReceipt(viewModel),
                  tooltip: 'Generate Professional Receipt',
                ),
                // Add button in AppBar
                if (viewModel.canAdd)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddDialog(context, viewModel, _tabController.index == 0 ? "office" : "project"),
                    tooltip: 'Add Expense',
                  ),
                // Global Search
                TopRightSearch(
                  onChanged: (query) => viewModel.setSearchQuery(query),
                  hintText: 'Search expenses...',
                ),
              ],
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildListView(context, viewModel.filteredOfficeExpenses, "Office"),
                _buildListView(context, viewModel.filteredProjectExpenses, "Project"),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<ExpenditureItem> list, String type) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == "Office" ? Icons.business_center : Icons.assignment,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No $type Records Found",
              style: AppFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Consumer<ExpenditureViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.canAdd) {
                  return Text(
                    "Tap the + button to add your first expense",
                    style: AppFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      );
    }

    // Calculate total amount
    final totalAmount = list.fold<double>(
      0.0,
      (sum, item) => sum + item.amount,
    );

    return Column(
      children: [
        // Total Amount Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Total $type Expense:",
                  style: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                f.format(totalAmount),
                style: AppFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Expense List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "${i + 1}",
                        style: AppFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    item.description,
                    style: AppFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.date,
                              style: AppFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        f.format(item.amount),
                        style: AppFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red.shade600,
                        ),
                      ),
                      if (item.category != null)
                        Text(
                          item.category!,
                          style: AppFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  onLongPress: () => _handleDelete(context, item),
                  onTap: () => _navigateToDetails(context, item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Navigation to details page
  void _navigateToDetails(BuildContext context, ExpenditureItem expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenditureDetailsPage(
          db: widget.db,
          expense: expense,
          viewModel: _viewModel,
        ),
      ),
    );
  }

  // Date picker method
  Future<void> _selectDate(BuildContext context, ExpenditureViewModel viewModel) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: viewModel.selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      viewModel.selectDate(picked);
    }
  }

  void _showAddDialog(BuildContext context, ExpenditureViewModel viewModel, String type) {
    viewModel.clearForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      type == "office" ? Icons.business_center : Icons.assignment,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Add $type Expense",
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Date Field
              Text(
                "Date",
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, viewModel),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          viewModel.selectedDate != null
                              ? DateFormat('dd MMM yyyy').format(viewModel.selectedDate!)
                              : 'Select Date',
                          style: AppFonts.poppins(
                            color: viewModel.selectedDate != null
                                ? Colors.black
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description Field
              Text(
                "Description",
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: viewModel.descriptionController,
                decoration: InputDecoration(
                  hintText: 'Enter expense description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              
              // Amount Field
              Text(
                "Amount",
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: viewModel.amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: AppFonts.poppins(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          final success = await viewModel.saveExpense(type);
                          if (success && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Save Expense",
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, ExpenditureItem expense) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete?"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _viewModel.deleteExpense(expense.id);
    }
  }

  // Professional Receipt Generation
  Future<void> _generateProfessionalReceipt(ExpenditureViewModel viewModel) async {
    final currentList = viewModel.currentTab == ExpenditureTab.office 
        ? viewModel.filteredOfficeExpenses 
        : viewModel.filteredProjectExpenses;
    final title = viewModel.currentTab == ExpenditureTab.office 
        ? "Office Expense Receipt" 
        : "Project Expense Receipt";
    
    if (currentList.isEmpty) {
      _showErrorSnackBar(context, 'No expenses to generate receipt');
      return;
    }
    
    // Build key values for receipt header
    final keyValues = <MapEntry<String, String>>[
      MapEntry('Report Type', title),
      MapEntry('Date Generated', DateFormat('dd MMM yyyy').format(DateTime.now())),
      MapEntry('Total Expenses', '${currentList.length}'),
      MapEntry('Generated By', viewModel.user?['username']?.toString() ?? 'N/A'),
    ];
    
    // Build grid rows for expense items
    final gridRows = currentList.map((expense) => {
      'Date': expense.date,
      'Description': expense.description,
      'Amount': f.format(expense.amount),
      'Type': expense.categoryType ?? 'N/A',
    }).toList();
    
    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: widget.db,
      module: 'Expenditure',
      title: title,
      entityId: 'EXP_${DateTime.now().millisecondsSinceEpoch}',
      keyValues: keyValues,
      gridRows: gridRows,
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// --- Expenditure Details Page ---

class ExpenditureDetailsPage extends StatefulWidget {
  final AppDatabase db;
  final ExpenditureItem expense;
  final ExpenditureViewModel viewModel;
  
  const ExpenditureDetailsPage({
    super.key,
    required this.db,
    required this.expense,
    required this.viewModel,
  });

  @override
  State<ExpenditureDetailsPage> createState() => _ExpenditureDetailsPageState();
}

class _ExpenditureDetailsPageState extends State<ExpenditureDetailsPage> {
  bool _loading = true;
  
  final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
  
  @override
  void initState() {
    super.initState();
    _setup();
  }
  
  Future<void> _setup() async {
    await widget.viewModel.loadSubItems(widget.expense.id);
    if (mounted) setState(() => _loading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    // Use the passed viewModel directly instead of Consumer
    final viewModel = widget.viewModel;
    
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Expense Details', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
        
        final subItemsTotal = viewModel.subItemsTotal;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Expense Details',
              style: AppFonts.poppins(fontWeight: FontWeight.w600),
            ),
            actions: [
              // Professional Receipt Generation for individual expense
              IconButton(
                icon: const Icon(Icons.receipt_long),
                onPressed: () => _generateProfessionalReceipt(viewModel),
                tooltip: 'Generate Professional Receipt',
              ),
              // Add button for sub-items
              if (viewModel.canAdd)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddSubItemDialog(context, viewModel),
                  tooltip: 'Add Sub-Item',
                ),
            ],
          ),
          body: Column(
            children: [
              // Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.expense.description,
                      style: AppFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.expense.date,
                          style: AppFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Main Amount',
                              style: AppFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              f.format(widget.expense.amount),
                              style: AppFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Sub-Items Total',
                              style: AppFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              f.format(subItemsTotal),
                              style: AppFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      color: Colors.white30,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Expense',
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          f.format(widget.expense.amount + subItemsTotal),
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Sub-Items Section
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Expense Breakdown',
                            style: AppFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (viewModel.canAdd)
                            IconButton(
                              icon: const Icon(Icons.add_circle),
                              onPressed: () => _showAddSubItemDialog(context, viewModel),
                              tooltip: 'Add Sub-Item',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: viewModel.subItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Sub-Items Found',
                                    style: AppFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (viewModel.canAdd)
                                    Text(
                                      'Tap + to add breakdown items',
                                      style: AppFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: viewModel.subItems.length,
                              itemBuilder: (context, i) {
                                final item = viewModel.subItems[i];
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "${i + 1}",
                                          style: AppFonts.poppins(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      item.description,
                                      style: AppFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    trailing: Text(
                                      f.format(item.amount),
                                      style: AppFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                                    onLongPress: () => _handleDeleteSubItem(context, viewModel, item),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }
  
  void _showAddSubItemDialog(BuildContext context, ExpenditureViewModel viewModel) {
    viewModel.clearSubItemForm();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Add Sub-Item",
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text(
                "Description",
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: viewModel.itemDescriptionController,
                decoration: InputDecoration(
                  hintText: 'Enter sub-item description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              
              Text(
                "Amount",
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: viewModel.itemAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: AppFonts.poppins(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          final success = await viewModel.saveSubItem(widget.expense.id);
                          if (success && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Save Item",
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _handleDeleteSubItem(BuildContext context, ExpenditureViewModel viewModel, ExpenditureSubItem item) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Sub-Item?"),
        content: const Text("Are you sure you want to delete this sub-item?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      await viewModel.deleteSubItem(item.id);
    }
  }
  
  // Professional Receipt Generation for individual expense
  Future<void> _generateProfessionalReceipt(ExpenditureViewModel viewModel) async {
    final subItemsTotal = viewModel.subItemsTotal;
    
    // Build key values for receipt header
    final keyValues = <MapEntry<String, String>>[
      MapEntry('Expense ID', widget.expense.id),
      MapEntry('Description', widget.expense.description),
      MapEntry('Date', widget.expense.date),
      MapEntry('Type', widget.expense.categoryType ?? 'N/A'),
      MapEntry('Main Amount', f.format(widget.expense.amount)),
      MapEntry('Sub-Items Count', '${viewModel.subItems.length}'),
      MapEntry('Sub-Items Total', f.format(subItemsTotal)),
      MapEntry('Total Expense', f.format(widget.expense.amount + subItemsTotal)),
      MapEntry('Generated By', viewModel.user?['username']?.toString() ?? 'N/A'),
    ];
    
    // Build grid rows for sub-items
    final gridRows = viewModel.subItems.map((subItem) => {
      'Description': subItem.description,
      'Amount': f.format(subItem.amount),
      'Date Added': subItem.createdAt ?? 'N/A',
    }).toList();
    
    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: widget.db,
      module: 'Expenditure',
      title: 'Expense Details Receipt',
      entityId: widget.expense.id,
      keyValues: keyValues,
      gridRows: gridRows,
    );
  }
}
