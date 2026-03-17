import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expenditure_item.dart' as domain;
import '../repositories/expenditure_repository.dart';
import '../repositories/expenditure_repository_impl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/services/permission_helper.dart';
import '../../../core/services/firebase_threading_handler.dart';
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
  List<domain.ExpenditureItem> _officeExpenses = [];
  List<domain.ExpenditureItem> _projectExpenses = [];
  List<domain.ExpenditureItem> _filteredOfficeExpenses = [];
  List<domain.ExpenditureItem> _filteredProjectExpenses = [];
  
  // Search
  String _searchQuery = '';
  
  // Form data
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  
  // Sub-items functionality
  List<domain.ExpenditureSubItem> _subItems = [];
  final TextEditingController _itemDescriptionController = TextEditingController();
  final TextEditingController _itemAmountController = TextEditingController();
  
  // Stream subscriptions
  StreamSubscription<List<domain.ExpenditureItem>>? _officeExpensesSubscription;
  StreamSubscription<List<domain.ExpenditureItem>>? _projectExpensesSubscription;
  StreamSubscription<List<domain.ExpenditureSubItem>>? _subItemsSubscription;
  
  // Getters
  bool get loading => _loading;
  Map<String, dynamic>? get user => _user;
  ExpenditureTab get currentTab => _currentTab;
  List<domain.ExpenditureItem> get officeExpenses => _officeExpenses;
  List<domain.ExpenditureItem> get projectExpenses => _projectExpenses;
  List<domain.ExpenditureItem> get filteredOfficeExpenses => _filteredOfficeExpenses;
  List<domain.ExpenditureItem> get filteredProjectExpenses => _filteredProjectExpenses;
  String get searchQuery => _searchQuery;
  TextEditingController get descriptionController => _descriptionController;
  TextEditingController get amountController => _amountController;
  TextEditingController get dateController => _dateController;
  DateTime? get selectedDate => _selectedDate;
  List<domain.ExpenditureSubItem> get subItems => _subItems;
  TextEditingController get itemDescriptionController => _itemDescriptionController;
  TextEditingController get itemAmountController => _itemAmountController;
  ExpenditureRepository get repository => _repository; // Expose repository
  
  // Computed properties
  List<domain.ExpenditureItem> get currentExpenses {
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
        // CRITICAL: Set loading to false when stream data arrives
        if (_loading) {
          _loading = false;
          debugPrint('ExpenditureViewModel: Loading set to false - office expenses stream data received');
        }
        
        _officeExpenses = data;
        _applySearchFilter();
        
        debugPrint('ExpenditureViewModel: Office expenses stream updated - notifyListeners called');
        notifyListeners();
      },
      onError: (e) {
        if (_loading) {
          _loading = false;
          debugPrint('ExpenditureViewModel: Loading set to false - office expenses stream error');
        }
        debugPrint('Error in office expenses stream: $e');
        notifyListeners();
      },
    );

    _projectExpensesSubscription = _repository.watchProjectExpenses(companyId).listen(
      (data) {
        // CRITICAL: Set loading to false when stream data arrives
        if (_loading) {
          _loading = false;
          debugPrint('ExpenditureViewModel: Loading set to false - project expenses stream data received');
        }
        
        _projectExpenses = data;
        _applySearchFilter();
        
        debugPrint('ExpenditureViewModel: Project expenses stream updated - notifyListeners called');
        notifyListeners();
      },
      onError: (e) {
        if (_loading) {
          _loading = false;
          debugPrint('ExpenditureViewModel: Loading set to false - project expenses stream error');
        }
        debugPrint('Error in project expenses stream: $e');
        notifyListeners();
      },
    );
  }

  // Tab management
  void setCurrentTab(ExpenditureTab tab) {
    _currentTab = tab;
    notifyListeners();
  }

  // CRITICAL: Manual refresh method for immediate UI updates
  // Enhanced with FirebaseThreadingHandler for Windows compatibility
  Future<void> refreshData() async {
    try {
      _loading = true;
      notifyListeners();
      
      // Enhanced with threading handler for Windows compatibility
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Re-setup streams to force immediate refresh
          await _setupStreams();
        },
        operationName: 'Expenditure refreshData',
      );
      
      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing expenditure data: $e');
      _loading = false;
      notifyListeners();
    }
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
      
      final expenditure = domain.ExpenditureItem(
        id: const Uuid().v4(),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        description: description,
        amount: amount,
        categoryType: type, // 'office' or 'project'
        category: null, // Category will be set by the page
        companyId: companyId,
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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

  // New method to save expense with category - accepts form data as parameters
  Future<bool> saveExpenseWithCategory(String type, String? category, {
    required String description,
    required double amount,
    required DateTime selectedDate,
  }) async {
    try {
      // CRITICAL: Ensure Firebase calls are on main thread for Windows compatibility
      if (io.Platform.isWindows) {
        // On Windows, ensure we're on the main thread for Firebase operations
        await WidgetsBinding.instance.endOfFrame;
      }
      
      final companyId = RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      final expenditure = domain.ExpenditureItem(
        id: const Uuid().v4(),
        date: DateFormat('yyyy-MM-dd').format(selectedDate),
        description: description,
        amount: amount,
        categoryType: type, // 'office' or 'project'
        category: category, // Category from dropdown
        companyId: companyId,
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _repository.addExpenditure(expenditure);
      // ENHANCED: Reduce console noise - only log success in debug mode
      if (kDebugMode) {
        _showSuccessSnackBar('$type expense added successfully');
      }
      
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

  // Sub-items operations
  Future<void> loadSubItems(String parentId) async {
    try {
      _subItemsSubscription?.cancel();
      _subItemsSubscription = _repository.watchExpenditureSubItems(parentId).listen((subItems) {
        _subItems = subItems;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error loading sub-items: $e');
      _subItems = [];
      notifyListeners();
    }
  }

  void clearSubItemForm() {
    _itemDescriptionController.clear();
    _itemAmountController.clear();
    notifyListeners();
  }

  Future<bool> saveSubItem(String parentId) async {
    if (_itemDescriptionController.text.trim().isEmpty ||
        _itemAmountController.text.trim().isEmpty) {
      _showErrorSnackBar('Please fill all fields');
      return false;
    }
    
    try {
      final subItem = domain.ExpenditureSubItem(
        id: const Uuid().v4(),
        parentId: parentId,
        description: _itemDescriptionController.text.trim(),
        amount: double.parse(_itemAmountController.text.trim()),
        companyId: RoleUtils.getUserCompanyId(_user) ?? '',
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      await _repository.addExpenditureSubItem(subItem);
      
      // Clear form
      _itemDescriptionController.clear();
      _itemAmountController.clear();
      
      return true;
    } catch (e) {
      debugPrint('Error saving sub-item: $e');
      _showErrorSnackBar('Failed to save sub-item');
      return false;
    }
  }

  Future<bool> deleteSubItem(String id) async {
    try {
      await _repository.deleteExpenditureSubItem(id);
      return true;
    } catch (e) {
      debugPrint('Error deleting sub-item: $e');
      _showErrorSnackBar('Failed to delete sub-item');
      return false;
    }
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
  Future<domain.ExpenditureItem?> getExpenditureById(String id) async {
    try {
      return await _repository.getExpenditureById(id);
    } catch (e) {
      debugPrint('Error fetching expenditure: $e');
      return null;
    }
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
