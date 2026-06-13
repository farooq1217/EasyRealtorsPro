import 'dart:async';
import 'dart:convert';
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
import '../helpers/grouped_expense_logic.dart';
import '../widgets/category_detail_sheet.dart';
import '../widgets/category_selection_grid.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/utils/logger.dart';

class ExpenditurePage extends StatefulWidget {
  final AppDatabase db;
  final String? companyId;
  final bool? isSuperAdmin;
  final String? userId;
  
  const ExpenditurePage({
    super.key, 
    required this.db,
    this.companyId,
    this.isSuperAdmin,
    this.userId,
  });

  @override
  State<ExpenditurePage> createState() => _ExpenditurePageState();
}

class _ExpenditurePageState extends State<ExpenditurePage> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  ExpenditureViewModel? _viewModel; // Make nullable to prevent LateInitializationError
  bool _initialized = false; // Track initialization state
  
  // Function to update dialog state
  void setDialogState(VoidCallback fn) {
    setState(fn);
  }

  final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
  
  // Category options for different types
  static const List<String> officeCategories = ["Utility bills", "Rent", "Fuel", "Food", "Salary", "Transport", "Grocery", "Others"];
  static const List<String> projectCategories = ['Eating out', 'Transport', 'Taxi', 'Gifts', 'Entertainment'];
  
  // Form controllers
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _projectNameController = TextEditingController(); // New controller for project names
  final _customCategoryController = TextEditingController(); // Controller for custom category when "Others" is selected
  DateTime? _selectedDate;
  String? _selectedCategory;
  String _currentFormType = 'office'; // 'office' or 'project'
  bool _showCustomCategoryField = false; // Flag to show/hide custom category field

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // PRE-FETCH CHECK: Initialize ViewModel immediately to prevent hanging
    // This ensures the ViewModel is ready before the navigation animation completes
    _initializeViewModel();
  }
  
  // Separate method for ViewModel initialization
  Future<void> _initializeViewModel() async {
    debugPrint('ExpenditurePage: PRE-FETCH CHECK - Initializing with passed parameters - CompanyId: ${widget.companyId}, IsSuperAdmin: ${widget.isSuperAdmin}, UserId: ${widget.userId}');
    
    // Initialize ViewModel with passed security parameters
    _viewModel = ExpenditureViewModel(widget.db, 
        companyId: widget.companyId, 
        isSuperAdmin: widget.isSuperAdmin ?? false,
        userId: widget.userId);
    
    // Initialize ViewModel
    await _viewModel?.initialize();
    
    // Set up tab listener after ViewModel is initialized
    if (mounted) {
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging && _viewModel != null) {
          _viewModel!.setCurrentTab(
            _tabController.index == 0 ? ExpenditureTab.office : ExpenditureTab.project
          );
        }
      });
      
      _initialized = true;
      setState(() {}); // Trigger rebuild with initialized ViewModel
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel?.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _projectNameController.dispose(); // Dispose project name controller
    _customCategoryController.dispose(); // Dispose custom category controller
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _tabController.animateTo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // CRITICAL: Call super.build for AutomaticKeepAliveClientMixin
    
    // CRITICAL FIX: Ensure ViewModel is created and initialized in build method
    // This prevents the UI from using a different ViewModel instance than the one with streams
    if (_viewModel == null) {
      debugPrint('ExpenditurePage: Creating and initializing ViewModel in build method');
      _viewModel = ExpenditureViewModel(
        widget.db,
        companyId: widget.companyId,
        isSuperAdmin: widget.isSuperAdmin ?? false,
        userId: widget.userId,
      );
      
      // Initialize ViewModel immediately and set up streams
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _viewModel!.initialize();
        if (mounted) {
          _initialized = true;
          setState(() {}); // Trigger rebuild with initialized ViewModel
        }
      });
    }
    
    final viewModel = _viewModel!;
    
    return ChangeNotifierProvider<ExpenditureViewModel>.value(
      value: viewModel,
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
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        // Tab Content using ViewModel state
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Office Expenses Tab with Selector for better performance
                              Selector<ExpenditureViewModel, List<domain.ExpenditureItem>>(
                                selector: (context, viewModel) => viewModel.filteredOfficeExpenses,
                                builder: (context, officeExpenses, child) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Category Grid for Office Expense Tab
                                        CategorySelectionGrid(
                                          onCategorySelected: (category) => _showInstantExpenseDialog(context, viewModel, category),
                                          enabled: viewModel.canAdd,
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // Expense List
                                        Expanded(
                                          child: _buildListView(context, officeExpenses, "Office"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Project Expenses Tab using Selector for better performance
                              Selector<ExpenditureViewModel, List<domain.ExpenditureItem>>(
                                selector: (context, viewModel) => viewModel.filteredProjectExpenses,
                                builder: (context, projectExpenses, child) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Add Project Button with Gradient Theme
                                        if (viewModel.canAdd)
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(bottom: 8),
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
                                            child: ElevatedButton(
                                              onPressed: () => _showProjectExpenseDialog(context, viewModel, 'General'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_circle_outline,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Add Project Expense',
                                                    style: AppFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        
                                        // Expense List
                                        Expanded(
                                          child: _buildListView(context, projectExpenses, "Project"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Removed FloatingActionButton - using Category Grid instead
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
        color: Theme.of(context).textTheme.titleMedium?.color ?? Colors.black87,
      ),
    );
  }

  // Helper method to build description widget with conditional display
  Widget _buildDescriptionWidget(domain.ExpenditureItem item) {
    if (item.description.isNotEmpty && 
        item.description.toLowerCase() != (item.category ?? '').toLowerCase()) {
      return Column(
        children: [
          Text(
            item.description,
            style: AppFonts.poppins(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildListView(BuildContext context, List<domain.ExpenditureItem> list, String type) {
    if (list.isEmpty) {
      return Center(
        child: SingleChildScrollView(
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
        ),
      );
    }

    // Calculate total amount - use Grand Totals for Projects, regular amounts for Office
    double totalAmount;
    if (type == "Project") {
      // For projects, we need to calculate grand totals asynchronously
      // This will be handled by individual FutureBuilder in each item
      // For the summary card, we'll use bucket amounts as fallback
      totalAmount = list.fold<double>(
        0.0,
        (sum, item) => sum + item.amount,
      );
    } else {
      // For office expenses, use regular amounts
      totalAmount = list.fold<double>(
        0.0,
        (sum, item) => sum + item.amount,
      );
    }

    return Column(
      children: [
        // Total Amount Summary Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            physics: const BouncingScrollPhysics(),
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
                              // Show Grand Total for Projects, Regular Amount for Office
                              type == "Project" 
                                ? FutureBuilder<double>(
                                    future: _viewModel?.getProjectGrandTotal(item.id) ?? Future.value(0.0),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Text(
                                          f.format(snapshot.data!),
                                          style: AppFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.red.shade600,
                                          ),
                                        );
                                      } else if (snapshot.hasError) {
                                        return Text(
                                          f.format(item.amount), // Fallback to bucket amount
                                          style: AppFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.red.shade600,
                                          ),
                                        );
                                      } else {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Loading...',
                                              style: AppFonts.poppins(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    },
                                  )
                                : Text(
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
                          // Show description if it exists and is different from category
                          _buildDescriptionWidget(item),
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
          viewModel: _viewModel ?? ExpenditureViewModel(widget.db),
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
      
      // Determine the final category value
      String finalCategory = _selectedCategory!;
      if (_selectedCategory == "Others" && _customCategoryController.text.isNotEmpty) {
        finalCategory = _customCategoryController.text.trim();
      }
      
      // CRITICAL DEBUGGING: Print expenditure data before saving
      final expenseData = {
        'type': _currentFormType,
        'category': finalCategory,
        'description': finalCategory, // Use final category as description
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'categoryType': _currentFormType == 'office' ? 'office_expense' : 'project_expense',
      };
      Logger.debug("Expenditure Save Attempt: $expenseData");
      
      // Use ViewModel's saveExpenseWithCategory method with validated data
      final success = await viewModel.saveExpenseWithCategory(
        _currentFormType == 'office' ? 'office_expense' : 'project_expense', // CRITICAL: Ensure proper category type
        finalCategory,
        description: finalCategory, // Use final category as description
        amount: amount,
        selectedDate: _selectedDate!,
      );
      
      if (success) {
        // Clear form
        _amountController.clear();
        _categoryController.clear();
        _customCategoryController.clear();
        _selectedDate = null;
        _selectedCategory = null;
        _showCustomCategoryField = false;
      }
      
      return success;
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  // Save expense method with provided final category value (for dialog use)
  Future<bool> _saveExpenseWithValues(ExpenditureViewModel viewModel, String finalCategory) async {
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
      
      if (finalCategory.isEmpty) {
        _showErrorSnackBar('Please select a category');
        return false;
      }
      
      // CRITICAL DEBUGGING: Print expenditure data before saving
      final expenseData = {
        'type': _currentFormType,
        'category': finalCategory,
        'description': finalCategory, // Use final category as description
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'categoryType': _currentFormType == 'office' ? 'office_expense' : 'project_expense',
      };
      Logger.debug("Expenditure Save Attempt: $expenseData");
      
      // Use ViewModel's saveExpenseWithCategory method with validated data
      final success = await viewModel.saveExpenseWithCategory(
        _currentFormType == 'office' ? 'office_expense' : 'project_expense', // CRITICAL: Ensure proper category type
        finalCategory,
        description: finalCategory, // Use final category as description
        amount: amount,
        selectedDate: _selectedDate!,
      );
      
      if (success) {
        // Clear form
        _amountController.clear();
        _categoryController.clear();
        _customCategoryController.clear();
        _selectedDate = null;
        _selectedCategory = null;
        _showCustomCategoryField = false;
      }
      
      return success;
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  // Simplified instant expense save method - 1-step process
  Future<bool> _saveInstantExpense(ExpenditureViewModel viewModel, String category, TimeOfDay selectedTime) async {
    try {
      final amountText = _amountController.text.trim();
      final description = _categoryController.text.trim();
      
      // Validation
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
      
      // Create final description - use user description if provided, otherwise use category
      final finalDescription = description.isNotEmpty ? description : category;
      
      // Combine date and time for precise timestamp
      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      
      debugPrint('Instant Expense Save: Category=$category, Amount=$amount, Description=$finalDescription, DateTime=$finalDateTime');
      
      // Save directly using ViewModel's saveExpenseWithCategory method
      final success = await viewModel.saveInstantExpenseFromCategory(
        'office_expense', // Always office expense for category grid
        category,
        description: finalDescription,
        amount: amount,
        selectedDate: finalDateTime,
      );
      
      if (success) {
        // Clear form controllers
        _amountController.clear();
        _categoryController.clear();
        _selectedDate = null;
        
        _showSuccessSnackBar('Expense added successfully');
      }
      
      return success;
    } catch (e) {
      debugPrint('Error saving instant expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  // Project expense save method
  Future<bool> _saveProjectExpense(ExpenditureViewModel viewModel, String category, TimeOfDay selectedTime) async {
    try {
      final amountText = _amountController.text.trim();
      final description = _categoryController.text.trim();
      final projectName = _projectNameController.text.trim();
      
      // Validation
      if (projectName.isEmpty) {
        _showErrorSnackBar('Please enter a project name');
        return false;
      }
      
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
      
      // Create final description - combine project name and description
      final finalDescription = projectName.isNotEmpty 
          ? '$projectName${description.isNotEmpty ? ': $description' : ''}'
          : (description.isNotEmpty ? description : category);
      
      // Combine date and time for precise timestamp
      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      
      debugPrint('Project Expense Save: Project=$projectName, Category=$category, Amount=$amount, Description=$finalDescription, DateTime=$finalDateTime');
      
      // Save directly using ViewModel's saveExpenseWithCategory method
      final success = await viewModel.saveInstantExpenseFromCategory(
        'project_expense', // Project expense type
        category,
        description: finalDescription,
        amount: amount,
        selectedDate: finalDateTime,
      );
      
      if (success) {
        // Clear form controllers
        _amountController.clear();
        _categoryController.clear();
        _projectNameController.clear();
        _selectedDate = null;
        
        _showSuccessSnackBar('Project expense added successfully');
      }
      
      return success;
    } catch (e) {
      debugPrint('Error saving project expense: $e');
      _showErrorSnackBar('Failed to save project expense');
      return false;
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Dynamic Expense Dialog with Category Selection
  void _showExpenseDialog(BuildContext context, ExpenditureViewModel viewModel, String type) {
    // Reset form
    _amountController.clear();
    _categoryController.clear();
    _customCategoryController.clear();
    _selectedDate = DateTime.now(); // Auto-fill with current date
    _selectedCategory = type == 'office' ? officeCategories.first : null; // Set default to first item for office
    _currentFormType = type;
    _showCustomCategoryField = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // CRITICAL: Use local dialog state variables instead of parent widget state
        String? localSelectedCategory = type == 'office' ? officeCategories.first : null; // Set default to first item for office
        bool localShowCustomCategoryField = false;
        final localCustomCategoryController = TextEditingController();
        
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
            ),
            child: StatefulBuilder(
              builder: (dialogContext, setStateDialog) {
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
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
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
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
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
                                            ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87)
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
                            value: localSelectedCategory,
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
                              setStateDialog(() {
                                localSelectedCategory = value;
                                // Show custom category field if "Others" is selected
                                localShowCustomCategoryField = (value == "Others");
                                if (!localShowCustomCategoryField) {
                                  localCustomCategoryController.clear();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          // Custom Category Field (shown when "Others" is selected)
                          if (localShowCustomCategoryField) ...[
                            Text(
                              "Custom Category",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: localCustomCategoryController,
                              decoration: InputDecoration(
                                hintText: 'Enter custom category',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                              style: AppFonts.poppins(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 16),
                          
                          // Amount Field
                          Text(
                            "Amount",
                            style: AppFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
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
                              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
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
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
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
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey.shade700,
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
                                setStateDialog(() {});
                                
                                // Update parent widget state with local values
                                setState(() {
                                  _selectedCategory = localSelectedCategory;
                                  _categoryController.text = localSelectedCategory ?? '';
                                });
                                
                                // Determine final category value
                                String finalCategory = localSelectedCategory ?? '';
                                if (localSelectedCategory == "Others" && localCustomCategoryController.text.isNotEmpty) {
                                  finalCategory = localCustomCategoryController.text.trim();
                                }
                                
                                final success = await _saveExpenseWithValues(viewModel, finalCategory);
                                
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
      );
      }
    );
  }

  // New method for adding projects as simple name buckets
  void _showAddProjectDialog(BuildContext context, ExpenditureViewModel viewModel) {
    // Auto-generate project name
    _projectNameController.text = "Project ${viewModel.projectExpenses.length + 1}";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.5, // Smaller height for simpler form
          ),
          child: Column(
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
                        Icons.assignment,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Add Project",
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
              
              // Form Content - Only Project Name Field
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project Name Field
                      Text(
                        "Project Name",
                        style: AppFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _projectNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter project name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        ),
                        style: AppFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      
                      // Helper text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "A project acts as a bucket to organize related expenses. You can add expenses to this project later.",
                                style: AppFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
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
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final projectName = _projectNameController.text.trim();
                          if (projectName.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter a project name',
                                  style: AppFonts.poppins(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          try {
                            // Call new addProject method (to be implemented in ViewModel)
                            await viewModel.addProject(projectName);
                            
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Project "$projectName" created successfully!',
                                    style: AppFonts.poppins(),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error creating project: $e',
                                    style: AppFonts.poppins(),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Create Project',
                          style: AppFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Simplified Instant Expense Dialog - 1-Step Process
  void _showInstantExpenseDialog(BuildContext context, ExpenditureViewModel viewModel, String category) {
    // Reset form controllers
    _amountController.clear();
    _categoryController.clear();
    _selectedDate = DateTime.now();
    TimeOfDay _selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
                ),
                child: Column(
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
                              Icons.business_center,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Quick Add Expense",
                                  style: AppFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  category,
                                  style: AppFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
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
                            // Amount Field
                            Text(
                              "Amount*",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: 'Rs ',
                                prefixStyle: AppFonts.poppins(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                                hintText: '0.00',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.orange.shade400),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Description Field
                            Text(
                              "Description",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                hintText: 'Enter expense details',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.orange.shade400),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Date Field
                            Text(
                              "Date*",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
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
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, color: Colors.orange.shade600),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedDate != null 
                                            ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                                            : 'Select date',
                                        style: AppFonts.poppins(
                                          color: _selectedDate != null 
                                              ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87)
                                              : (Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Time Field
                            Text(
                              "Time",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: _selectedTime,
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    _selectedTime = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, color: Colors.orange.shade600),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedTime.format(context),
                                        style: AppFonts.poppins(
                                          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Save expense directly without breakdown step
                                final success = await _saveInstantExpense(viewModel, category, _selectedTime);
                                if (success && dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Save Expense',
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Project Expense Dialog - Similar to Office but for Projects
  void _showProjectExpenseDialog(BuildContext context, ExpenditureViewModel viewModel, String category) {
    // Reset form controllers
    _amountController.clear();
    _categoryController.clear();
    _projectNameController.clear();
    _selectedDate = DateTime.now();
    TimeOfDay _selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
                ),
                child: Column(
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
                              Icons.assignment,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Add Project Expense",
                                  style: AppFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  category,
                                  style: AppFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
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
                            // Project Name Field
                            Text(
                              "Project Name*",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _projectNameController,
                              decoration: InputDecoration(
                                hintText: 'Enter project name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade400),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Amount Field
                            Text(
                              "Amount*",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: 'Rs ',
                                prefixStyle: AppFonts.poppins(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                                hintText: '0.00',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade400),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Description Field
                            Text(
                              "Description",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                hintText: 'Enter expense details',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade400),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Date Field
                            Text(
                              "Date*",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
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
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, color: Colors.blue.shade600),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedDate != null 
                                            ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                                            : 'Select date',
                                        style: AppFonts.poppins(
                                          color: _selectedDate != null 
                                              ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87)
                                              : (Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Time Field
                            Text(
                              "Time",
                              style: AppFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: _selectedTime,
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    _selectedTime = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, color: Colors.blue.shade600),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedTime.format(context),
                                        style: AppFonts.poppins(
                                          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Save project expense
                                final success = await _saveProjectExpense(viewModel, category, _selectedTime);
                                if (success && dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Save Project Expense',
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
      await _viewModel?.deleteExpense(expense.id);
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
    // Load sub-items for both office and project expenses
    // Office expenses now have sub-items due to smart grouping
    await widget.viewModel.loadSubItems(widget.expense.id);
    
    if (mounted) setState(() => _loading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExpenditureViewModel>.value(
      value: widget.viewModel,
      child: Consumer<ExpenditureViewModel>(
        builder: (context, viewModel, child) {
          if (_loading) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Expense Details', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
              
          // Check if this is an office expense
          final isOfficeExpense = widget.expense.categoryType == 'office_expense' || 
                                widget.expense.kind == 'office';
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
                // Add button for sub-items - ONLY for Project expenses
                if (!isOfficeExpense && viewModel.canAdd)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddSubItemDialog(context, viewModel),
                    tooltip: 'Add Sub-Item',
                  ),
              ],
            ),
            body: Column(
              children: [
                // Summary Card - Simplified for Office Expenses
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
                      // Category Name as Title
                      Text(
                        widget.expense.category ?? 'Uncategorized',
                        style: AppFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Description as main detail
                      if (widget.expense.description.isNotEmpty && 
                          widget.expense.description != (widget.expense.category ?? '')) ...[
                        Text(
                          widget.expense.description,
                          style: AppFonts.poppins(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Date
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
                      
                      // Amount Display - Different for Office vs Project
                      if (isOfficeExpense) ...[
                        // Office Expense: Show single amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount',
                              style: AppFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              f.format(widget.expense.amount),
                              style: AppFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Project Expense: Show main amount + sub-items total
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
                    ],
                  ),
                ),
                
                // Sub-Items Section - Show for both Office and Project expenses when they have sub-items
                if (viewModel.subItems.isNotEmpty) ...[
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
                              // Only show add button for project expenses
                              if (!isOfficeExpense && viewModel.canAdd)
                                IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  onPressed: () => _showAddSubItemDialog(context, viewModel),
                                  tooltip: 'Add Sub-Item',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                         
                        // Category Summary Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expense Details',
                                style: AppFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCategorySummary(viewModel.subItems),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                         
                        // Grouped Category Cards
                        Expanded(
                          child: _buildGroupedCategoryView(viewModel.subItems),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Show completion message when no sub-items
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isOfficeExpense ? Colors.green.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isOfficeExpense ? Colors.green.shade200 : Colors.blue.shade200,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: isOfficeExpense ? Colors.green.shade600 : Colors.blue.shade600,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '${isOfficeExpense ? 'Office' : 'Project'} Expense Complete',
                                  style: AppFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isOfficeExpense ? Colors.green.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This expense has been recorded\nwithout sub-item breakdown',
                                  style: AppFonts.poppins(
                                    fontSize: 14,
                                    color: isOfficeExpense ? Colors.green.shade600 : Colors.blue.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
  
  // Build Category Summary Widget
  Widget _buildCategorySummary(List<domain.ExpenditureSubItem> subItems) {
    // Group sub-items by category and calculate totals
    final Map<String, double> categoryTotals = {};
    
    for (final item in subItems) {
      final category = item.category?.isNotEmpty == true ? item.category! : 'Uncategorized';
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + item.amount;
    }
    
    // Sort categories by amount (descending)
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.05),
            const Color(0xFF4A90E2).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: sortedCategories.map((entry) {
          final category = entry.key;
          final amount = entry.value;
          final color = _getCategoryColor(category);
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: AppFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ':',
                  style: AppFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  f.format(amount),
                  style: AppFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  // Get category color for consistent theming
  Color _getCategoryColor(String category) {
    final categoryColors = {
      'Civil work material': Colors.brown,
      'Sanitary material': Colors.blue,
      'Electric material': Colors.yellow,
      'Steel work material': Colors.grey,
      'Wood work material': Colors.orange,
      'Labor': Colors.green,
      'Transport': Colors.purple,
      'Utility bill': Colors.cyan,
      'Rental tools': Colors.indigo,
      'Other': Colors.red,
      'Uncategorized': Colors.grey,
    };
    
    return categoryColors[category] ?? Colors.grey;
  }
  
  // Method to show add sub-item dialog
  void _showAddSubItemDialog(BuildContext context, ExpenditureViewModel viewModel) {
    // Define exact category items as requested
    const List<String> categoryItems = [
      "Civil work material",
      "Sanitary material", 
      "Electric material",
      "Steel work material",
      "Wood work material",
      "Labor",
      "Transport",
      "Utility bill",
      "Rental tools",
      "Other"
    ];

    String? selectedCategory;
    final customCategoryController = TextEditingController();
    bool showCustomCategory = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.5,
                  minWidth: 450,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dialog Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFFFF6B35),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Add Sub-Item',
                              style: AppFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.titleMedium?.color ?? Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      

                      // Form Content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Description Field
                              Text(
                                'Description',
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: viewModel.itemDescriptionController,
                                decoration: InputDecoration(
                                  hintText: 'Enter description...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 24),
                              

                              // Amount Field
                              Text(
                                'Amount',
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: viewModel.itemAmountController,
                                decoration: InputDecoration(
                                  hintText: 'Enter amount...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 24),
                              

                              // Category Dropdown
                              Text(
                                'Category',
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: InputDecoration(
                                  hintText: 'Select category...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                items: categoryItems.map((String category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(
                                      category,
                                      style: AppFonts.poppins(fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedCategory = newValue;
                                    showCustomCategory = (newValue == "Other");
                                    if (!showCustomCategory) {
                                      customCategoryController.clear();
                                    }
                                  });
                                },
                              ),
                              

                              // Show custom category field when "Other" is selected
                              if (showCustomCategory) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Custom Category',
                                  style: AppFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: customCategoryController,
                                  decoration: InputDecoration(
                                    hintText: 'Specify custom category...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              // Determine final category value
                              String finalCategory = '';
                              if (selectedCategory != null) {
                                if (selectedCategory == "Other" && customCategoryController.text.isNotEmpty) {
                                  finalCategory = customCategoryController.text.trim();
                                } else if (selectedCategory != "Other") {
                                  finalCategory = selectedCategory!;
                                }
                              }

                              // CRITICAL FIX: Pass category directly to saveSubItem method
                              // instead of relying on ViewModel state which might have timing issues
                              final success = await viewModel.saveSubItemWithCategory(
                                widget.expense.id,
                                category: finalCategory.isEmpty ? null : finalCategory,
                              );
                              
                              if (success && dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Save Item',
                              style: AppFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // Method to handle delete sub-item
  Future<void> _handleDeleteSubItem(BuildContext context, ExpenditureViewModel viewModel, dynamic item) async {
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
  
  // Build Grouped Category View with Drill-down Functionality
  Widget _buildGroupedCategoryView(List<domain.ExpenditureSubItem> subItems) {
    if (subItems.isEmpty) {
      return Center(
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
            if (widget.viewModel.canAdd)
              Text(
                'Tap + to add breakdown items',
                style: AppFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      );
    }
    
    // Get grouped expense data
    final groupedData = GroupedExpenseLogic.getGroupedExpenseData(subItems);
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: groupedData.sortedCategories.length,
      itemBuilder: (context, index) {
        final category = groupedData.sortedCategories[index];
        final categoryTotal = groupedData.categoryTotals[category] ?? 0.0;
        final categoryExpenses = groupedData.groupedExpenses[category] ?? [];
        final categoryColor = _getCategoryColor(category);
        
        return InkWell(
          onTap: () => showCategoryDetailSheet(
            context: context,
            categoryName: category,
            expenses: categoryExpenses,
            categoryTotal: categoryTotal,
            onDeleteItem: widget.viewModel.canAdd 
                ? (expense) => _handleDeleteSubItem(context, widget.viewModel, expense)
                : null,
          ),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    categoryColor.withOpacity(0.05),
                    categoryColor.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header
                    Row(
                      children: [
                        // Category Icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                categoryColor.withOpacity(0.2),
                                categoryColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getCategoryIcon(category),
                            color: categoryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Category Name and Item Count
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: AppFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.titleMedium?.color ?? Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${categoryExpenses.length} item${categoryExpenses.length == 1 ? '' : 's'}',
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              f.format(categoryTotal),
                              style: AppFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: categoryColor.withOpacity(0.6),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Preview Items (show first 2 items if more than 2)
                    if (categoryExpenses.length > 2) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 12),
                      ...categoryExpenses.take(2).map((expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                expense.description,
                                style: AppFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              f.format(expense.amount),
                              style: AppFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 18),
                            Text(
                              '+${categoryExpenses.length - 2} more items',
                              style: AppFonts.poppins(
                                fontSize: 12,
                                color: categoryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Get category icon for better visual representation
  IconData _getCategoryIcon(String category) {
    final categoryIcons = {
      'Civil work material': Icons.construction,
      'Sanitary material': Icons.bathtub,
      'Electric material': Icons.electrical_services,
      'Steel work material': Icons.hardware,
      'Wood work material': Icons.carpenter,
      'Labor': Icons.people,
      'Transport': Icons.local_shipping,
      'Utility bill': Icons.receipt_long,
      'Rental tools': Icons.build,
      'Other': Icons.category,
      'Uncategorized': Icons.help_outline,
    };
    
    return categoryIcons[category] ?? Icons.category;
  }
}
