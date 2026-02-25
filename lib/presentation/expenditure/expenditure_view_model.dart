import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/expenditure_item.dart';
import '../../domain/repositories/expenditure_repository.dart';
import '../../data/repositories/expenditure_repository_impl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/permission_helper.dart';
import 'package:shared/shared.dart';

enum ExpenditureTab { office, project }

class ExpenditureViewModel extends ChangeNotifier {
  final ExpenditureRepository _repository;
  final AppDatabase _database;
  
  ExpenditureViewModel(this._database) : _repository = ExpenditureRepositoryImpl(_database);

  // State
  bool _loading = true;
  Map<String, dynamic>? _user;
  ExpenditureTab _currentTab = ExpenditureTab.office;
  
  // Data lists
  List<ExpenditureItem> _officeExpenses = [];
  List<ExpenditureItem> _projectExpenses = [];
  List<ExpenditureItem> _filteredOfficeExpenses = [];
  List<ExpenditureItem> _filteredProjectExpenses = [];
  
  // Search
  String _searchQuery = '';
  
  // Form data
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  
  // Sub-items functionality - DISABLED since expenditure_items table doesn't exist in schema
  List<ExpenditureSubItem> _subItems = [];
  final TextEditingController _itemDescriptionController = TextEditingController();
  final TextEditingController _itemAmountController = TextEditingController();
  
  // Stream subscriptions
  StreamSubscription<List<ExpenditureItem>>? _officeExpensesSubscription;
  StreamSubscription<List<ExpenditureItem>>? _projectExpensesSubscription;
  StreamSubscription<List<ExpenditureSubItem>>? _subItemsSubscription;
  
  // Getters
  bool get loading => _loading;
  Map<String, dynamic>? get user => _user;
  ExpenditureTab get currentTab => _currentTab;
  List<ExpenditureItem> get officeExpenses => _officeExpenses;
  List<ExpenditureItem> get projectExpenses => _projectExpenses;
  List<ExpenditureItem> get filteredOfficeExpenses => _filteredOfficeExpenses;
  List<ExpenditureItem> get filteredProjectExpenses => _filteredProjectExpenses;
  String get searchQuery => _searchQuery;
  TextEditingController get descriptionController => _descriptionController;
  TextEditingController get amountController => _amountController;
  TextEditingController get dateController => _dateController;
  DateTime? get selectedDate => _selectedDate;
  List<ExpenditureSubItem> get subItems => _subItems;
  TextEditingController get itemDescriptionController => _itemDescriptionController;
  TextEditingController get itemAmountController => _itemAmountController;
  
  // Computed properties
  List<ExpenditureItem> get currentExpenses {
    return _currentTab == ExpenditureTab.office ? _filteredOfficeExpenses : _filteredProjectExpenses;
  }
  
  double get currentTotal {
    return currentExpenses.fold(0.0, (sum, item) => sum + item.amount);
  }
  
  double get subItemsTotal {
    return _subItems.fold(0.0, (sum, item) => sum + item.amount);
  }
  
  bool get canAdd => 
    PermissionHelper.getModulePermissionLevel(_user, 'expenditure').contains('add') || 
    RoleUtils.isCompanyAdmin(_user);

  // Initialization
  Future<void> initialize() async {
    try {
      _loading = true;
      notifyListeners();
      
      await _loadUser();
      await _repository.ensureExpenditureTableColumns();
      await _setupStreams();
    } catch (e) {
      debugPrint('Error initializing ExpenditureViewModel: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUser() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        final authService = AuthService();
        _user = await authService.getCurrentUser(authToken);
        AuthService.currentUser = _user;
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  Future<void> _setupStreams() async {
    final companyId = RoleUtils.getUserCompanyId(_user);
    if (companyId == null) return;

    // Cancel existing subscriptions
    await _officeExpensesSubscription?.cancel();
    await _projectExpensesSubscription?.cancel();

    // Setup new streams
    _officeExpensesSubscription = _repository.watchOfficeExpenses(companyId).listen(
      (data) {
        _officeExpenses = data;
        _applySearchFilter();
      },
      onError: (e) => debugPrint('Error in office expenses stream: $e'),
    );

    _projectExpensesSubscription = _repository.watchProjectExpenses(companyId).listen(
      (data) {
        _projectExpenses = data;
        _applySearchFilter();
      },
      onError: (e) => debugPrint('Error in project expenses stream: $e'),
    );
  }

  // Tab management
  void setCurrentTab(ExpenditureTab tab) {
    _currentTab = tab;
    notifyListeners();
  }

  // Search functionality
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applySearchFilter();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredOfficeExpenses = List.from(_officeExpenses);
      _filteredProjectExpenses = List.from(_projectExpenses);
    } else {
      _filteredOfficeExpenses = _officeExpenses.where((item) {
        final description = item.description.toLowerCase();
        final amount = item.amount.toString();
        final date = item.date.toLowerCase();
        return description.contains(_searchQuery.toLowerCase()) ||
               amount.contains(_searchQuery.toLowerCase()) ||
               date.contains(_searchQuery.toLowerCase());
      }).toList();
      
      _filteredProjectExpenses = _projectExpenses.where((item) {
        final description = item.description.toLowerCase();
        final amount = item.amount.toString();
        final date = item.date.toLowerCase();
        return description.contains(_searchQuery.toLowerCase()) ||
               amount.contains(_searchQuery.toLowerCase()) ||
               date.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  // Form operations
  void selectDate(DateTime date) {
    _selectedDate = date;
    _dateController.text = DateFormat('yyyy-MM-dd').format(date);
    notifyListeners();
  }

  void clearForm() {
    _descriptionController.clear();
    _amountController.clear();
    _dateController.clear();
    _selectedDate = null;
    notifyListeners();
  }

  Future<bool> saveExpense(String type) async {
    try {
      final description = _descriptionController.text.trim();
      final amountText = _amountController.text.trim();
      
      // Validation
      if (description.isEmpty) {
        _showErrorSnackBar('Please enter a description');
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
      
      final companyId = RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      final expenditure = ExpenditureItem(
        id: const Uuid().v4(),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        description: description,
        amount: amount,
        categoryType: type, // 'office' or 'project'
        companyId: companyId,
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
      );
      
      await _repository.addExpenditure(expenditure);
      clearForm();
      _showSuccessSnackBar('$type expense added successfully');
      
      return true;
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await _repository.deleteExpenditure(id);
      _showSuccessSnackBar('Expense deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      _showErrorSnackBar('Failed to delete expense');
      return false;
    }
  }

  // Sub-items operations - DISABLED since expenditure_items table doesn't exist in schema
  Future<void> loadSubItems(String parentId) async {
    // No-op since sub-items functionality is not available
    _subItems = [];
    // Defer notifyListeners to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void clearSubItemForm() {
    _itemDescriptionController.clear();
    _itemAmountController.clear();
    notifyListeners();
  }

  Future<bool> saveSubItem(String parentId) async {
    // Always return failure since sub-items functionality is not available
    _showErrorSnackBar('Sub-items functionality is not available');
    return false;
  }

  Future<bool> deleteSubItem(String id) async {
    // Always return failure since sub-items functionality is not available
    _showErrorSnackBar('Sub-items functionality is not available');
    return false;
  }

  // Statistics
  Future<double> getTotalOfficeExpenses() async {
    final companyId = RoleUtils.getUserCompanyId(_user);
    if (companyId == null) return 0.0;
    
    try {
      return await _repository.getTotalOfficeExpenses(companyId);
    } catch (e) {
      debugPrint('Error calculating total office expenses: $e');
      return 0.0;
    }
  }

  Future<double> getTotalProjectExpenses() async {
    final companyId = RoleUtils.getUserCompanyId(_user);
    if (companyId == null) return 0.0;
    
    try {
      return await _repository.getTotalProjectExpenses(companyId);
    } catch (e) {
      debugPrint('Error calculating total project expenses: $e');
      return 0.0;
    }
  }

  Future<double> getTotalExpenditureWithSubItems(String expenditureId) async {
    try {
      return await _repository.getTotalExpenditureWithSubItems(expenditureId);
    } catch (e) {
      debugPrint('Error calculating total expenditure with sub-items: $e');
      return 0.0;
    }
  }

  // Utility methods
  Future<ExpenditureItem?> getExpenditureById(String id) async {
    try {
      return await _repository.getExpenditureById(id);
    } catch (e) {
      debugPrint('Error fetching expenditure: $e');
      return null;
    }
  }

  void refreshData() {
    _setupStreams();
  }

  // Private helper methods
  void _showErrorSnackBar(String message) {
    // This will be handled by the UI layer
    debugPrint('Error: $message');
  }

  void _showSuccessSnackBar(String message) {
    // This will be handled by the UI layer
    debugPrint('Success: $message');
  }

  @override
  void dispose() {
    _officeExpensesSubscription?.cancel();
    _projectExpensesSubscription?.cancel();
    _subItemsSubscription?.cancel();
    
    _descriptionController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _itemDescriptionController.dispose();
    _itemAmountController.dispose();
    
    super.dispose();
  }
}
