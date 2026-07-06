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
import 'expenditure_details_page.dart';

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

class _ExpenditurePageState extends State<ExpenditurePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  ExpenditureViewModel? _viewModel;
  bool _initialized = false;

  void setDialogState(VoidCallback fn) {
    setState(fn);
  }

  final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

  static const List<String> officeCategories = [
    "Utility bills", "Rent", "Fuel", "Food", "Salary",
    "Transport", "Grocery", "Others"
  ];
  static const List<String> projectCategories = [
    'Eating out', 'Transport', 'Taxi', 'Gifts', 'Entertainment'
  ];

  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _customCategoryController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCategory;
  String _currentFormType = 'office';
  bool _showCustomCategoryField = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeViewModel();
  }

  Future<void> _initializeViewModel() async {
    debugPrint('ExpenditurePage: PRE-FETCH CHECK - Initializing with passed parameters - CompanyId: ${widget.companyId}, IsSuperAdmin: ${widget.isSuperAdmin}, UserId: ${widget.userId}');

    _viewModel = ExpenditureViewModel(
      widget.db,
      companyId: widget.companyId,
      isSuperAdmin: widget.isSuperAdmin ?? false,
      userId: widget.userId,
    );

    await _viewModel?.initialize();

    if (mounted) {
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging && _viewModel != null) {
          _viewModel!.setCurrentTab(
            _tabController.index == 0 ? ExpenditureTab.office : ExpenditureTab.project,
          );
        }
      });
      _initialized = true;
      setState(() {});
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
    _projectNameController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _tabController.animateTo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_viewModel == null) {
      debugPrint('ExpenditurePage: Creating and initializing ViewModel in build method');
      _viewModel = ExpenditureViewModel(
        widget.db,
        companyId: widget.companyId,
        isSuperAdmin: widget.isSuperAdmin ?? false,
        userId: widget.userId,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _viewModel!.initialize();
        if (mounted) {
          _initialized = true;
          setState(() {});
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
              const SizedBox(height: 12),
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
                          colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)],
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
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOfficeTab(context, viewModel),
                        _buildProjectTab(context, viewModel),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ FIXED: Office Tab with FULL scrolling
  Widget _buildOfficeTab(BuildContext context, ExpenditureViewModel viewModel) {
    return Selector<ExpenditureViewModel, List<domain.ExpenditureItem>>(
      selector: (context, viewModel) => viewModel.filteredOfficeExpenses,
      builder: (context, officeExpenses, child) {
        return _buildFullyScrollableContent(context, officeExpenses, "Office", viewModel);
      },
    );
  }

  // ✅ FIXED: Project Tab with FULL scrolling
  Widget _buildProjectTab(BuildContext context, ExpenditureViewModel viewModel) {
    return Selector<ExpenditureViewModel, List<domain.ExpenditureItem>>(
      selector: (context, viewModel) => viewModel.filteredProjectExpenses,
      builder: (context, projectExpenses, child) {
        return _buildFullyScrollableContent(context, projectExpenses, "Project", viewModel);
      },
    );
  }

  // ✅ NEW: Unified scrollable content method
  Widget _buildFullyScrollableContent(BuildContext context, List<domain.ExpenditureItem> list, String type, ExpenditureViewModel viewModel) {
    double totalAmount = list.fold<double>(0.0, (sum, item) => sum + item.amount);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ✅ Category Grid (NOW SCROLLABLE)
        if (type == "Office")
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CategorySelectionGrid(
                onCategorySelected: (category) => _showInstantExpenseDialog(context, viewModel, category),
                enabled: viewModel.canAdd,
              ),
            ),
          ),
        
        // ✅ Add Project Button (NOW SCROLLABLE)
        if (type == "Project" && viewModel.canAdd)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)],
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
                      const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
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
            ),
          ),

        // Empty state
        if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
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
                  ],
                ),
              ),
            ),
          )
        else ...[
          // ✅ Total Amount Summary Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)],
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
          ),
          
          // ✅ Scrollable expense list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = list[i];
                  return _buildExpenseCard(context, item, type);
                },
                childCount: list.length,
              ),
            ),
          ),
          
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ],
    );
  }

  Widget _buildExpenseCard(BuildContext context, domain.ExpenditureItem item, String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onLongPress: () => _handleDelete(context, item),
        onTap: () => _navigateToDetails(context, item),
        child: Card(
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
                                  f.format(item.amount),
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
                _buildCategoryTitle(item, type),
                const SizedBox(height: 4),
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
      ),
    );
  }

  Widget _buildCategoryTitle(domain.ExpenditureItem item, String type) {
    String displayTitle;
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

  Future<bool> _saveExpense(ExpenditureViewModel viewModel) async {
    try {
      final amountText = _amountController.text.trim();
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

      String finalCategory = _selectedCategory!;
      if (_selectedCategory == "Others" && _customCategoryController.text.isNotEmpty) {
        finalCategory = _customCategoryController.text.trim();
      }

      final expenseData = {
        'type': _currentFormType,
        'category': finalCategory,
        'description': finalCategory,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'categoryType': _currentFormType == 'office' ? 'office_expense' : 'project_expense',
      };
      Logger.debug("Expenditure Save Attempt: $expenseData");

      final success = await viewModel.saveExpenseWithCategory(
        _currentFormType == 'office' ? 'office_expense' : 'project_expense',
        finalCategory,
        description: finalCategory,
        amount: amount,
        selectedDate: _selectedDate!,
      );

      if (success) {
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

  Future<bool> _saveExpenseWithValues(ExpenditureViewModel viewModel, String finalCategory) async {
    try {
      final amountText = _amountController.text.trim();
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

      final expenseData = {
        'type': _currentFormType,
        'category': finalCategory,
        'description': finalCategory,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'categoryType': _currentFormType == 'office' ? 'office_expense' : 'project_expense',
      };
      Logger.debug("Expenditure Save Attempt: $expenseData");

      final success = await viewModel.saveExpenseWithCategory(
        _currentFormType == 'office' ? 'office_expense' : 'project_expense',
        finalCategory,
        description: finalCategory,
        amount: amount,
        selectedDate: _selectedDate!,
      );

      if (success) {
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

  Future<bool> _saveInstantExpense(ExpenditureViewModel viewModel, String category, TimeOfDay selectedTime) async {
    try {
      final amountText = _amountController.text.trim();
      final description = _categoryController.text.trim();
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

      final finalDescription = description.isNotEmpty ? description : category;
      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      debugPrint('Instant Expense Save: Category=$category, Amount=$amount, Description=$finalDescription, DateTime=$finalDateTime');

      final success = await viewModel.saveInstantExpenseFromCategory(
        'office_expense',
        category,
        description: finalDescription,
        amount: amount,
        selectedDate: finalDateTime,
      );

      if (success) {
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

  Future<bool> _saveProjectExpense(ExpenditureViewModel viewModel, String category, TimeOfDay selectedTime) async {
    try {
      final amountText = _amountController.text.trim();
      final description = _categoryController.text.trim();
      final projectName = _projectNameController.text.trim();

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

      final finalDescription = projectName.isNotEmpty
          ? '$projectName${description.isNotEmpty ? ': $description' : ''}'
          : (description.isNotEmpty ? description : category);
      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      debugPrint('Project Expense Save: Project=$projectName, Category=$category, Amount=$amount, Description=$finalDescription, DateTime=$finalDateTime');

      final success = await viewModel.saveInstantExpenseFromCategory(
        'project_expense',
        category,
        description: finalDescription,
        amount: amount,
        selectedDate: finalDateTime,
      );

      if (success) {
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

  void _showExpenseDialog(BuildContext context, ExpenditureViewModel viewModel, String type) {
    _amountController.clear();
    _categoryController.clear();
    _customCategoryController.clear();
    _selectedDate = DateTime.now();
    _selectedCategory = type == 'office' ? officeCategories.first : null;
    _currentFormType = type;
    _showCustomCategoryField = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? localSelectedCategory = type == 'office' ? officeCategories.first : null;
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)],
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
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Date", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
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
                                        _selectedDate != null ? DateFormat('dd MMM yyyy').format(_selectedDate!) : 'Select Date',
                                        style: AppFonts.poppins(
                                          color: _selectedDate != null ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87) : Colors.grey.shade500,
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
                            Text("Category", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButton<String>(
                              value: localSelectedCategory,
                              hint: Text("Select category", style: AppFonts.poppins(color: Colors.grey.shade500)),
                              isExpanded: true,
                              items: (type == 'office' ? officeCategories : projectCategories).map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category, style: AppFonts.poppins(fontWeight: FontWeight.w500)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setStateDialog(() {
                                  localSelectedCategory = value;
                                  localShowCustomCategoryField = (value == "Others");
                                  if (!localShowCustomCategoryField) {
                                    localCustomCategoryController.clear();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            if (localShowCustomCategoryField) ...[
                              Text("Custom Category", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: localCustomCategoryController,
                                decoration: InputDecoration(
                                  hintText: 'Enter custom category',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ] else
                              const SizedBox(height: 16),
                            Text("Amount", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: 'Enter amount',
                                prefixText: 'Rs ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text("Cancel", style: AppFonts.poppins(fontWeight: FontWeight.w500)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  setStateDialog(() {});
                                  setState(() {
                                    _selectedCategory = localSelectedCategory;
                                    _categoryController.text = localSelectedCategory ?? '';
                                  });
                                  String finalCategory = localSelectedCategory ?? '';
                                  if (localSelectedCategory == "Others" && localCustomCategoryController.text.isNotEmpty) {
                                    finalCategory = localCustomCategoryController.text.trim();
                                  }
                                  final success = await _saveExpenseWithValues(viewModel, finalCategory);
                                  if (success && dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                    if (context.mounted) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${type == 'office' ? 'Office Expense' : 'Project'} saved successfully!'),
                                              backgroundColor: const Color(0xFFFF6B35),
                                              duration: const Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      });
                                    }
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text("Save Expense", style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
      },
    );
  }

  void _showAddProjectDialog(BuildContext context, ExpenditureViewModel viewModel) {
    _projectNameController.text = "Project ${viewModel.projectExpenses.length + 1}";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)]),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.assignment, color: Colors.blue.shade600, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text("Add Project", style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(dialogContext).pop()),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Project Name", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _projectNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter project name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text("A project acts as a bucket to organize related expenses.", style: AppFonts.poppins(fontSize: 12, color: Colors.blue.shade700)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final projectName = _projectNameController.text.trim();
                          if (projectName.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Please enter a project name'), backgroundColor: Colors.red));
                            return;
                          }
                          try {
                            await viewModel.addProject(projectName);
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project "$projectName" created successfully!'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Error creating project: $e'), backgroundColor: Colors.red));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text('Create Project', style: AppFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
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

  void _showInstantExpenseDialog(BuildContext context, ExpenditureViewModel viewModel, String category) {
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)]),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.business_center, color: Colors.orange.shade600, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Quick Add Expense", style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text(category, style: AppFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.9))),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(dialogContext).pop()),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Amount*", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: 'Rs ',
                                hintText: '0.00',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text("Description", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                hintText: 'Enter expense details',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text("Date*", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
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
                                        _selectedDate != null ? DateFormat('dd MMM yyyy').format(_selectedDate!) : 'Select date',
                                        style: AppFonts.poppins(color: _selectedDate != null ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87) : Colors.grey.shade600),
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text("Time", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(context: dialogContext, initialTime: _selectedTime);
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
                                      child: Text(_selectedTime.format(context), style: AppFonts.poppins(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87)),
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(child: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('Cancel'))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final success = await _saveInstantExpense(viewModel, category, _selectedTime);
                                if (success && dialogContext.mounted) Navigator.of(dialogContext).pop();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: Text('Save Expense', style: AppFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
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

  // REPLACED: _showProjectExpenseDialog
  void _showProjectExpenseDialog(BuildContext context, ExpenditureViewModel viewModel, String category) {
    _projectNameController.clear();
    _categoryController.clear(); // For Description
    
    // Remove Date & Time initializations as they are no longer needed here.

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
                  // Reduced height because fields are removed
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.6, 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)]),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.assignment, color: Colors.blue.shade600, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Add Project", style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text(category, style: AppFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.9))),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(dialogContext).pop()),
                        ],
                      ),
                    ),
                    
                    // Body Fields
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Project Name*", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _projectNameController,
                              decoration: InputDecoration(
                                hintText: 'Enter project name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Text("Description (Optional)", style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                hintText: 'Enter project details or context',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                              ),
                            ),
                            
                            // Info Box (Instead of Time/Date)
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50, 
                                borderRadius: BorderRadius.circular(8), 
                                border: Border.all(color: Colors.blue.shade200)
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Amounts, dates, and times for individual expenses will be added inside this project.", 
                                      style: AppFonts.poppins(fontSize: 12, color: Colors.blue.shade700)
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(child: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('Cancel'))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final projectName = _projectNameController.text.trim();
                                if (projectName.isEmpty) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Please enter a project name'), backgroundColor: Colors.red));
                                  return;
                                }
                                
                                // Since we removed amount, we pass 0.0 initially for the main project bucket
                                // The description field is repurposed for context/details.
                                final description = _categoryController.text.trim();
                                final finalDescription = projectName.isNotEmpty
                                    ? '$projectName${description.isNotEmpty ? ': $description' : ''}'
                                    : (description.isNotEmpty ? description : category);

                                try {
                                  // Call the save method. 
                                  // Since Amount is required by the ViewModel method, we pass 0.0. 
                                  // Date/Time is set to DateTime.now() silently in the background just for record keeping.
                                  final success = await viewModel.saveInstantExpenseFromCategory(
                                    'project_expense',
                                    category,
                                    description: finalDescription,
                                    amount: 0.0, 
                                    selectedDate: DateTime.now(),
                                  );

                                  if (success && dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                      _showSuccessSnackBar('Project created successfully');
                                  }
                                } catch (e) {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Error creating project: $e'), backgroundColor: Colors.red));
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: Text('Create Project', style: AppFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
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

  Future<void> _generateProfessionalReceipt(ExpenditureViewModel viewModel) async {
    final currentList = viewModel.currentTab == ExpenditureTab.office ? viewModel.filteredOfficeExpenses : viewModel.filteredProjectExpenses;
    final title = viewModel.currentTab == ExpenditureTab.office ? "Office Expense Receipt" : "Project Expense Receipt";
    if (currentList.isEmpty) {
      _showErrorSnackBar('No expenses to generate receipt');
      return;
    }

    final keyValues = <MapEntry<String, String>>[
      MapEntry('Report Type', title),
      MapEntry('Date Generated', DateFormat('dd MMM yyyy').format(DateTime.now())),
      MapEntry('Total Expenses', '${currentList.length}'),
      MapEntry('Generated By', viewModel.user?['username']?.toString() ?? 'N/A'),
    ];

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