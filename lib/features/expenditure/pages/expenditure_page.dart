import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';
import '../models/expenditure_item.dart' as domain;
import '../../../core/professional_pdf_generator.dart' show ProfessionalPdfGenerator;
import '../../../core/shared_utils.dart' show TopRightSearch;
import '../../../shimmer_widgets.dart';
import '../../../widgets/primary_gradient_button.dart';
import '../view_models/expenditure_view_model.dart';

class ExpenditurePage extends StatefulWidget {
  final AppDatabase db;
  const ExpenditurePage({super.key, required this.db});

  @override
  State<ExpenditurePage> createState() => _ExpenditurePageState();
}

class _ExpenditurePageState extends State<ExpenditurePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ExpenditureViewModel _viewModel;
  
  // Function to update dialog state
  void setDialogState(VoidCallback fn) {
    setState(fn);
  }

  final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
  
  // Category options for different types
  static const List<String> officeCategories = ['Bills', 'House', 'Toiletry', 'Health', 'Communications', 'Food'];
  static const List<String> projectCategories = ['Eating out', 'Transport', 'Taxi', 'Gifts', 'Entertainment'];
  
  // Form controllers
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCategory;
  String _currentFormType = 'office'; // 'office' or 'project'

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
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _tabController.animateTo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExpenditureViewModel>.value(
      value: _viewModel,
      child: Consumer<ExpenditureViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.loading) {
            return Scaffold(
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFF6B35).withOpacity(0.03),
                      const Color(0xFF4A90E2).withOpacity(0.03),
                    ],
                  ),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }

          return Column(
            children: [
              // Vertical Separator "Cut" - Creates the separation line between main header and module
              const SizedBox(height: 12),
              
              // Expenditure Module Content
              Expanded(
                child: Scaffold(
                  backgroundColor: Colors.grey.shade50,
                  appBar: AppBar(
                    automaticallyImplyLeading: false,
                    centerTitle: true,
                    elevation: 0,
                    title: Text(
                      'Expenditures',
                      style: AppFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    flexibleSpace: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF6B35), // Orange
                            Color(0xFF4A90E2), // Blue
                          ],
                        ),
                      ),
                    ),
                    bottom: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFFFF6B35),
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: AppFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: AppFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'Office Expense'),
                        Tab(text: 'Projects'),
                      ],
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: TopRightSearch(
                          onChanged: (query) => viewModel.setSearchQuery(query),
                          hintText: 'Search...',
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
                          const Color(0xFFFF6B35).withOpacity(0.03),
                          const Color(0xFF4A90E2).withOpacity(0.03),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.grey.shade300.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Tab Content with StreamBuilder for real-time updates
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Office Expenses Tab with StreamBuilder
                              StreamBuilder<List<domain.ExpenditureItem>>(
                                stream: _viewModel.repository.watchOfficeExpenses(
                                  RoleUtils.getUserCompanyId(_viewModel.user) ?? ''
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Text(
                                        'Error loading office expenses',
                                        style: AppFonts.poppins(color: Colors.red),
                                      ),
                                    );
                                  }
                                  final officeExpenses = snapshot.data ?? [];
                                  return _buildListView(context, officeExpenses, "Office");
                                },
                              ),
                              // Project Expenses Tab with StreamBuilder
                              StreamBuilder<List<domain.ExpenditureItem>>(
                                stream: _viewModel.repository.watchProjectExpenses(
                                  RoleUtils.getUserCompanyId(_viewModel.user) ?? ''
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Text(
                                        'Error loading project expenses',
                                        style: AppFonts.poppins(color: Colors.red),
                                      ),
                                    );
                                  }
                                  final projectExpenses = snapshot.data ?? [];
                                  return _buildListView(context, projectExpenses, "Project");
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () => _showExpenseDialog(context, viewModel, 
                      _tabController.index == 0 ? 'office' : 'project'),
                    label: Text('ADD'),
                    icon: const Icon(Icons.add),
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper method to build category title with proper fallback logic
  Widget _buildCategoryTitle(domain.ExpenditureItem item, String type) {
    String displayTitle;
    
    // Logic: If category is 'Other' or empty, show description. Otherwise show category.
    if (item.category != null && item.category!.isNotEmpty && item.category != 'Other') {
      displayTitle = item.category!;
    } else {
      displayTitle = item.description.isNotEmpty ? item.description : 'No Category';
    }
    
    return Text(
      displayTitle,
      style: AppFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<domain.ExpenditureItem> list, String type) {
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
              
              return InkWell(
                onLongPress: () => _handleDelete(context, item),
                onTap: () => _navigateToDetails(context, item),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.category != null && item.category!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: type == "Office" ? Colors.orange.shade100 : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.category!,
                                  style: AppFonts.poppins(
                                    fontSize: 12,
                                    color: type == "Office" ? Colors.orange.shade700 : Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              f.format(item.amount),
                              style: AppFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // CRITICAL: Category Name as main title with enhanced styling
                        _buildCategoryTitle(item, type),
                        const SizedBox(height: 4),
                        Text(
                          item.date,
                          style: AppFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Navigation to details page
  void _navigateToDetails(BuildContext context, domain.ExpenditureItem expense) {
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

  // Date picker method for local form
  Future<void> _selectDate(BuildContext context, ExpenditureViewModel viewModel) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Save expense method with enhanced real-time refresh and debugging
  Future<bool> _saveExpense(ExpenditureViewModel viewModel) async {
    try {
      final amountText = _amountController.text.trim();
      
      // Validation - Description removed
      if (amountText.isEmpty) {
        _showErrorSnackBar('Please enter an amount');
        return false;
      }
      
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        _showErrorSnackBar('Please enter a valid amount');
        return false;
      }
      
      if (_selectedDate == null) {
        _showErrorSnackBar('Please select a date');
        return false;
      }
      
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        _showErrorSnackBar('Please select a category');
        return false;
      }
      
      // CRITICAL DEBUGGING: Print expenditure data before saving
      final expenseData = {
        'type': _currentFormType,
        'category': _selectedCategory,
        'description': _selectedCategory!, // Use category as description
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'categoryType': _currentFormType == 'office' ? 'office_expense' : 'project_expense',
      };
      print("Expenditure Save Attempt: $expenseData");
      
      // Use ViewModel's saveExpenseWithCategory method with validated data
      final success = await viewModel.saveExpenseWithCategory(
        _currentFormType == 'office' ? 'office_expense' : 'project_expense', // CRITICAL: Ensure proper category type
        _selectedCategory,
        description: _selectedCategory!, // Use category as description
        amount: amount,
        selectedDate: _selectedDate!,
      );
      
      if (success) {
        // CRITICAL: Immediate UI refresh through multiple mechanisms
        
        // 1. Force immediate page refresh (backup mechanism)
        if (mounted) {
          setState(() {});
        }
        
        // 2. Trigger ViewModel data refresh (primary mechanism)
        viewModel.refreshData();
        
        // 3. Clear form
        _amountController.clear();
        _categoryController.clear();
        _selectedDate = null;
        _selectedCategory = null;
      }
      
      return success;
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Dynamic Expense Dialog with Category Selection
  void _showExpenseDialog(BuildContext context, ExpenditureViewModel viewModel, String type) {
    // Reset form
    _amountController.clear();
    _categoryController.clear();
    _selectedDate = DateTime.now(); // Auto-fill with current date
    _selectedCategory = null;
    _currentFormType = type;

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
          child: StatefulBuilder(
            builder: (dialogContext, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient background
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            type == 'office' ? Icons.business_center : Icons.assignment,
                            color: type == 'office' ? Colors.orange.shade600 : Colors.blue.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Add ${type == 'office' ? 'Office Expense' : 'Project'}",
                            style: AppFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Form Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Field (Auto-filled)
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
                            onTap: () => _selectDate(dialogContext, viewModel),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.orange.shade600),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedDate != null
                                          ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                                          : 'Select Date',
                                      style: AppFonts.poppins(
                                        color: _selectedDate != null
                                            ? Colors.black87
                                            : Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Category Dropdown
                          Text(
                            "Category",
                            style: AppFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                            value: _selectedCategory,
                            hint: Text(
                              "Select category",
                              style: AppFonts.poppins(color: Colors.grey.shade500),
                            ),
                            isExpanded: true,
                            items: (type == 'office' ? officeCategories : projectCategories)
                                .map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(
                                  category,
                                  style: AppFonts.poppins(fontWeight: FontWeight.w500),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedCategory = value;
                                _categoryController.text = value ?? '';
                              });
                            },
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
                            controller: _amountController,
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
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  
                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B35).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                // Show loading state
                                setDialogState(() {});
                                
                                final success = await _saveExpense(viewModel);
                                
                                if (success && dialogContext.mounted) {
                                  // CRITICAL: Auto-close dialog immediately on success
                                  Navigator.of(dialogContext).pop();
                                  
                                  // CRITICAL: Show success message after dialog close
                                  if (context.mounted) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${type == 'office' ? 'Office Expense' : 'Project'} saved successfully!',
                                              style: AppFonts.poppins(),
                                            ),
                                            backgroundColor: const Color(0xFFFF6B35),
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    });
                                  }
                                  
                                  // CRITICAL: Force immediate UI refresh after dialog close
                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, domain.ExpenditureItem expense) async {
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
      _showErrorSnackBar('No expenses to generate receipt');
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
      'Category': expense.category ?? expense.description,
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
}

// --- Expenditure Details Page ---

class ExpenditureDetailsPage extends StatefulWidget {
  final AppDatabase db;
  final domain.ExpenditureItem expense;
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
                      widget.expense.category ?? widget.expense.description,
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
  
  Future<void> _handleDeleteSubItem(BuildContext context, ExpenditureViewModel viewModel, domain.ExpenditureSubItem item) async {
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
      MapEntry('Category', widget.expense.category ?? widget.expense.description),
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
      gridRows: gridRows.cast<Map<String, String>>(),
    );
  }
}
