// ignore_for_file: parameter_types
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expenditure_item.dart' as domain;
import '../repositories/expenditure_repository.dart';
import '../repositories/expenditure_repository_impl.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/services/permission_helper.dart';
import '../../../core/services/firebase_threading_handler.dart';
import '../../../core/windows_platform_fix.dart';
import '../../../core/role_utils.dart' as local;
import 'package:shared/shared.dart';
import '../../../core/utils/logger.dart';

enum ExpenditureTab { office, project }

class ExpenditureViewModel extends ChangeNotifier {
  final ExpenditureRepository _repository;
  final AppDatabase _database;
  final String? _passedCompanyId;
  final bool _passedIsSuperAdmin;
  final String? _passedUserId;
  
  // ✅ CRITICAL FIX: Track if already initialized to prevent duplicate setup
  bool _isInitialized = false;
  
  ExpenditureViewModel(this._database, {String? companyId, bool? isSuperAdmin, String? userId}) 
      : _repository = ExpenditureRepositoryImpl(_database, 
          companyId: companyId, 
          isSuperAdmin: isSuperAdmin ?? false,
          userId: userId),
        _passedCompanyId = companyId,
        _passedIsSuperAdmin = isSuperAdmin ?? false,
        _passedUserId = userId;

  // State
  bool _loading = true;
  Map<String, dynamic>? _user;
  ExpenditureTab _currentTab = ExpenditureTab.office;
  
  String? _cachedCompanyId;
  bool? _cachedIsSuperAdmin;
  
  void _initializeUserFromCache() {
    final cachedUser = AuthService.currentUser;
    if (cachedUser != null) {
      _cachedCompanyId = local.RoleUtils.getUserCompanyId(cachedUser);
      _cachedIsSuperAdmin = local.RoleUtils.isSuperAdmin(cachedUser);
      debugPrint('ExpenditureViewModel: Initialized from AuthService cache - companyId: $_cachedCompanyId, isSuper: $_cachedIsSuperAdmin');
    }
  }
  
  // Data lists
  List<domain.ExpenditureItem> _officeExpenses = [];
  List<domain.ExpenditureItem> _projectExpenses = [];
  List<domain.ExpenditureItem> _filteredOfficeExpenses = [];
  List<domain.ExpenditureItem> _filteredProjectExpenses = [];
  
  String _searchQuery = '';
  
  int _currentPage = 1;
  int _itemsPerPage = 10;
  
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  
  List<domain.ExpenditureSubItem> _subItems = [];
  String? _currentExpenseId;
  final TextEditingController _itemDescriptionController = TextEditingController();
  final TextEditingController _itemAmountController = TextEditingController();
  final TextEditingController _itemCategoryController = TextEditingController();
  String? _selectedItemCategory;
  
  StreamSubscription<List<domain.ExpenditureItem>>? _officeExpensesSubscription;
  StreamSubscription<List<domain.ExpenditureItem>>? _projectExpensesSubscription;
  StreamSubscription<List<domain.ExpenditureSubItem>>? _subItemsSubscription;
  
  // Getters (same as before)
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
  TextEditingController get itemCategoryController => _itemCategoryController;
  String? get selectedItemCategory => _selectedItemCategory;
  ExpenditureRepository get repository => _repository;
  
  List<domain.ExpenditureItem> get currentExpenses {
    return _currentTab == ExpenditureTab.office ? _filteredOfficeExpenses : _filteredProjectExpenses;
  }
  
  double get currentTotal {
    return currentExpenses.fold(0.0, (sum, item) => sum + item.amount);
  }
  
  double get subItemsTotal {
    return _subItems.fold(0.0, (sum, item) => sum + item.amount);
  }
  
  Future<double> getProjectGrandTotal(String projectId) async {
    try {
      final project = _projectExpenses.firstWhere(
        (item) => item.id == projectId,
        orElse: () => domain.ExpenditureItem(
          id: '',
          date: '',
          description: '',
          amount: 0.0,
          category: null,
          categoryType: 'project_expense',
          isActive: true,
          isSynced: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      final subItems = await _repository.getExpenditureSubItems(projectId);
      final subItemsTotal = subItems.fold(0.0, (sum, item) => sum + item.amount);
      
      return project.amount + subItemsTotal;
    } catch (e) {
      debugPrint('Error calculating project grand total: $e');
      return 0.0;
    }
  }
  
  bool get canAdd {
    if (_user == null) return false;
    if (local.RoleUtils.isSuperAdmin(_user)) return true;
    if (local.RoleUtils.isCompanyAdmin(_user)) return true;
    final level = PermissionHelper.getModulePermissionLevel(_user, 'expenditure');
    return level == 'view_add' || level == 'view_add_edit' || level == 'full_access';
  }

  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (currentExpenses.length / _itemsPerPage).ceil();
  List<domain.ExpenditureItem> get paginatedExpenses {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    return currentExpenses.skip(startIndex).take(_itemsPerPage).toList();
  }

  // ✅ CRITICAL FIX: Make initialize() idempotent
  Future<void> initialize() async {
    // ✅ Prevent duplicate initialization
    if (_isInitialized) {
      debugPrint('ExpenditureViewModel: Already initialized, skipping...');
      return;
    }
    
    try {
      WindowsPlatformFix.initialize();
      
      _loading = true;
      _initializeUserFromCache();
      notifyListeners();
      
      // ✅ CRITICAL FIX: Load user WITHOUT updating AuthService.currentUser
      await _loadUserSafe().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('ExpenditureViewModel: User loading timed out');
        },
      );
      
      _loading = false;
      notifyListeners();
      
      // Background database checks
      Future.microtask(() async {
        try {
          debugPrint('ExpenditureViewModel: Starting background database checks...');
          await _repository.ensureExpenditureTableColumns().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('ExpenditureViewModel: Database checks timed out');
            },
          );
          debugPrint('ExpenditureViewModel: Background database checks completed');
        } catch (e) {
          debugPrint('ExpenditureViewModel: Background database checks failed: $e');
        }
      });
      
      // Setup streams
      await _setupStreams().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('ExpenditureViewModel: Stream setup timed out');
        },
      );
      
      // ✅ Mark as initialized
      _isInitialized = true;
      debugPrint('ExpenditureViewModel: Initialization complete');
    } catch (e) {
      debugPrint('Error initializing ExpenditureViewModel: $e');
      _loading = false;
      notifyListeners();
    }
  }

  // ✅ CRITICAL FIX: New safe method that doesn't update AuthService.currentUser
  Future<void> _loadUserSafe() async {
    try {
      // ✅ Use cached user instead of calling getCurrentUser again
      if (AuthService.currentUser != null) {
        _user = AuthService.currentUser;
        debugPrint('ExpenditureViewModel: Using cached user data');
        return;
      }
      
      // Only fetch if no cached user
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        _user = await AuthService.getCurrentUser(authToken);
        // ✅ CRITICAL FIX: Don't update AuthService.currentUser here to prevent notifier update
        // AuthService.currentUser = _user; // REMOVED THIS LINE
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  Future<void> _setupStreams() async {
    var companyId = _passedCompanyId;
    var isSuperAdmin = _passedIsSuperAdmin;
    
    if (_user != null) {
      final detectedRole = local.RoleUtils.getUserRole(_user);
      final detectedIsSuperAdmin = local.RoleUtils.isSuperAdmin(_user);
      
      debugPrint('ExpenditureViewModel: Role detection - Detected Role: $detectedRole, Detected isSuperAdmin: $detectedIsSuperAdmin');
      
      isSuperAdmin = detectedIsSuperAdmin;
      
      if (detectedIsSuperAdmin) {
        if (companyId != 'GLOBAL_ADMIN') {
          companyId = 'GLOBAL_ADMIN';
        }
      } else {
        if (companyId == 'GLOBAL_ADMIN') {
          companyId = '';
        }
      }
    }
    
    if (companyId == null) {
      final cachedUser = AuthService.currentUser;
      if (cachedUser != null) {
        final fallbackCompanyId = local.RoleUtils.getUserCompanyId(cachedUser);
        if (fallbackCompanyId != null) {
          companyId = fallbackCompanyId;
        } else {
          companyId = isSuperAdmin ? 'GLOBAL_ADMIN' : '';
        }
      } else {
        companyId = isSuperAdmin ? 'GLOBAL_ADMIN' : '';
      }
    }
    
    debugPrint('ExpenditureViewModel: Final parameters - isSuperAdmin: $isSuperAdmin, companyId: $companyId');
    
    final effectiveCompanyId = (isSuperAdmin && companyId == 'GLOBAL_ADMIN') ? null : companyId;
    debugPrint('ExpenditureViewModel: Effective companyId for streams: $effectiveCompanyId');

    // ✅ CRITICAL FIX: Cancel subscriptions synchronously (no await)
    _officeExpensesSubscription?.cancel();
    _projectExpensesSubscription?.cancel();

    // Setup new streams
    _officeExpensesSubscription = _repository.watchOfficeExpenses(effectiveCompanyId).listen(
      (data) {
        if (_loading) {
          _loading = false;
        }
        
        _officeExpenses = data;
        _applySearchFilter(); // ✅ This no longer calls notifyListeners()
        
        debugPrint('ExpenditureViewModel: Office expenses stream updated - ${data.length} items');
        notifyListeners(); // ✅ Only ONE notifyListeners() call
      },
      onError: (e) {
        if (_loading) {
          _loading = false;
        }
        debugPrint('Error in office expenses stream: $e');
        notifyListeners();
      },
    );

    _projectExpensesSubscription = _repository.watchProjectExpenses(effectiveCompanyId).listen(
      (data) {
        if (_loading) {
          _loading = false;
        }
        
        _projectExpenses = data;
        _applySearchFilter(); // ✅ This no longer calls notifyListeners()
        
        debugPrint('ExpenditureViewModel: Project expenses stream updated - ${data.length} items');
        notifyListeners(); // ✅ Only ONE notifyListeners() call
      },
      onError: (e) {
        if (_loading) {
          _loading = false;
        }
        debugPrint('Error in project expenses stream: $e');
        notifyListeners();
      },
    );
  }

  void setCurrentTab(ExpenditureTab tab) {
    if (tab != null) {
      _currentTab = tab;
      notifyListeners();
    }
  }

  // ✅ CRITICAL FIX: Simplified refreshData that doesn't re-setup streams
  Future<void> refreshData() async {
    try {
      _loading = true;
      notifyListeners();
      
      // ✅ Instead of re-setting up streams, just trigger a manual refresh
      // The streams will automatically pick up database changes
      await Future.delayed(const Duration(milliseconds: 100));
      
      _loading = false;
      notifyListeners();
      
      debugPrint('ExpenditureViewModel: Data refreshed');
    } catch (e) {
      debugPrint('Error refreshing expenditure data: $e');
      _loading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1;
    _applySearchFilter();
  }

  // ✅ CRITICAL FIX: Removed notifyListeners() from here
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
    // ✅ REMOVED: notifyListeners() - caller will handle this
  }

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
      
      final companyId = local.RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      final expenditure = domain.ExpenditureItem(
        id: const Uuid().v4(),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        description: description,
        amount: amount,
        categoryType: type,
        category: type == 'office' ? 'Office Expense' : 'Project Expense',
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
      
      debugPrint('ExpenditureViewModel: Expense saved - streams will update UI automatically');
      
      return true;
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  Future<bool> addProject(String projectName) async {
    try {
      if (io.Platform.isWindows) {
        await WidgetsBinding.instance.endOfFrame;
      }
      
      final companyId = local.RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      final project = domain.ExpenditureItem(
        id: const Uuid().v4(),
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        description: projectName,
        amount: 0.0,
        categoryType: 'project_bucket',
        category: 'Project Bucket',
        companyId: companyId,
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      Logger.debug("Project Repository Save: ${project.toMap()}");
      
      await _repository.addExpenditure(project);
      
      _showSuccessSnackBar('Project "$projectName" created successfully');
      
      debugPrint('ExpenditureViewModel: Project created - streams will update UI automatically');
      
      return true;
    } catch (e) {
      debugPrint('Error creating project: $e');
      _showErrorSnackBar('Failed to create project: $e');
      return false;
    }
  }

  Future<bool> saveExpenseWithCategory(String type, String? category, {
    required String description,
    required double amount,
    required DateTime selectedDate,
  }) async {
    try {
      if (io.Platform.isWindows) {
        await WidgetsBinding.instance.endOfFrame;
      }
      
      final companyId = local.RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      final expenditure = domain.ExpenditureItem(
        id: const Uuid().v4(),
        date: DateFormat('yyyy-MM-dd').format(selectedDate),
        description: description,
        amount: amount,
        categoryType: type,
        category: category,
        companyId: companyId,
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      Logger.debug("Expenditure Repository Save: ${expenditure.toMap()}");
      
      await _repository.addExpenditure(expenditure);
      
      if (kDebugMode) {
        Logger.info('$type expense saved successfully with category: $category');
        _showSuccessSnackBar('$type expense added successfully');
      }
      
      debugPrint('ExpenditureViewModel: Expense saved with category - streams will update UI automatically');
      
      return true;
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  Future<bool> saveInstantExpenseFromCategory(String type, String category, {
    required String description,
    required double amount,
    required DateTime selectedDate,
  }) async {
    try {
      if (io.Platform.isWindows) {
        await WidgetsBinding.instance.endOfFrame;
      }
      
      final companyId = local.RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      
      if (type == 'office_expense') {
        debugPrint('ExpenditureViewModel: Smart grouping check for office expense - Date: $dateStr, Category: $category');
        
        final existingExpense = await _repository.findExistingOfficeExpense(dateStr, category, companyId);
        
        if (existingExpense != null) {
          debugPrint('ExpenditureViewModel: Found existing expense, updating amount and adding sub-item');
          
          final newTotalAmount = existingExpense.amount + amount;
          
          await _repository.updateExpenditureAmount(existingExpense.id, newTotalAmount);
          
          final subItem = domain.ExpenditureSubItem(
            id: const Uuid().v4(),
            parentId: existingExpense.id,
            description: description,
            amount: amount,
            category: category,
            companyId: companyId,
            createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
            isActive: true,
            isSynced: true,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          );
          
          await _repository.addExpenditureSubItem(subItem);
          
          _showSuccessSnackBar('Expense added to existing entry');
          debugPrint('ExpenditureViewModel: Smart grouping completed - updated existing expense: ${existingExpense.id}');
        } else {
          debugPrint('ExpenditureViewModel: No existing expense found, creating new entry');
          
          final expenditure = domain.ExpenditureItem(
            id: const Uuid().v4(),
            date: dateStr,
            description: description,
            amount: amount,
            categoryType: type,
            category: category,
            companyId: companyId,
            createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
            isActive: true,
            isSynced: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          debugPrint('Instant Expense Repository Save: ${expenditure.toMap()}');
          
          await _repository.addExpenditure(expenditure);
          
          _showSuccessSnackBar('Expense added successfully');
          debugPrint('ExpenditureViewModel: New expense created: ${expenditure.id}');
        }
      } else {
        debugPrint('ExpenditureViewModel: Creating new project expense (no grouping)');
        
        final expenditure = domain.ExpenditureItem(
          id: const Uuid().v4(),
          date: dateStr,
          description: description,
          amount: amount,
          categoryType: type,
          category: category,
          companyId: companyId,
          createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
          isActive: true,
          isSynced: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _repository.addExpenditure(expenditure);
        _showSuccessSnackBar('Project expense added successfully');
      }
      
      debugPrint('ExpenditureViewModel: Smart grouping completed - streams will update UI automatically');
      
      return true;
    } catch (e) {
      debugPrint('Error saving instant expense with smart grouping: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await _repository.deleteExpenditure(id);
      _showSuccessSnackBar('Expense deleted successfully');
      
      debugPrint('ExpenditureViewModel: Expense deleted - streams will update UI automatically');
      
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      _showErrorSnackBar('Failed to delete expense');
      return false;
    }
  }

  Future<bool> updateExpense(domain.ExpenditureItem expense) async {
    try {
      await _repository.updateExpenditure(expense);
      _showSuccessSnackBar('Expense updated successfully');
      
      debugPrint('ExpenditureViewModel: Expense updated - streams will update UI automatically');
      
      return true;
    } catch (e) {
      debugPrint('Error updating expense: $e');
      _showErrorSnackBar('Failed to update expense');
      return false;
    }
  }

  Future<void> loadSubItems(String parentId) async {
    try {
      _currentExpenseId = parentId;
      
      try {
        await (_repository as ExpenditureRepositoryImpl).ensureExpenditureSubItemsCategoryColumn();
        debugPrint('ExpenditureViewModel: Category column ensured before loading sub-items');
      } catch (e) {
        debugPrint('ExpenditureViewModel: Error ensuring category column: $e');
      }
      
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
    _itemCategoryController.clear();
    _selectedItemCategory = null;
    notifyListeners();
  }

  void setSelectedSubItemCategory(String? category) {
    _selectedItemCategory = category;
    notifyListeners();
  }

  Future<bool> saveSubItem(String parentId) async {
    if (_itemDescriptionController.text.trim().isEmpty ||
        _itemAmountController.text.trim().isEmpty) {
      _showErrorSnackBar('Please fill all fields');
      return false;
    }
    
    try {
      final category = _selectedItemCategory;
          
      if (category != null && category.isEmpty) {
        _showErrorSnackBar('Invalid category');
        return false;
      }
      
      final subItem = domain.ExpenditureSubItem(
        id: const Uuid().v4(),
        parentId: parentId,
        description: _itemDescriptionController.text.trim(),
        amount: double.parse(_itemAmountController.text.trim()),
        category: category,
        companyId: local.RoleUtils.getUserCompanyId(_user) ?? '',
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      await _repository.addExpenditureSubItem(subItem);
      
      _itemDescriptionController.clear();
      _itemAmountController.clear();
      _itemCategoryController.clear();
      _selectedItemCategory = null;
      
      return true;
    } catch (e) {
      debugPrint('Error saving sub-item: $e');
      _showErrorSnackBar('Failed to save sub-item');
      return false;
    }
  }

  Future<bool> saveSubItemWithCategory(String parentId, {String? category}) async {
    if (_itemDescriptionController.text.trim().isEmpty ||
        _itemAmountController.text.trim().isEmpty) {
      _showErrorSnackBar('Please fill all fields');
      return false;
    }
    
    try {
      debugPrint('ExpenditureViewModel: Saving sub-item with category: $category');
          
      if (category != null && category.isEmpty) {
        _showErrorSnackBar('Invalid category');
        return false;
      }
      
      final subItem = domain.ExpenditureSubItem(
        id: const Uuid().v4(),
        parentId: parentId,
        description: _itemDescriptionController.text.trim(),
        amount: double.parse(_itemAmountController.text.trim()),
        category: category,
        companyId: local.RoleUtils.getUserCompanyId(_user) ?? '',
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      debugPrint('ExpenditureViewModel: Sub-item data before save: ${subItem.toMap()}');
      
      await _repository.addExpenditureSubItem(subItem);
      
      _itemDescriptionController.clear();
      _itemAmountController.clear();
      _itemCategoryController.clear();
      _selectedItemCategory = null;
      
      debugPrint('ExpenditureViewModel: Sub-item saved successfully with category: $category');
      
      try {
        final freshSubItems = await _repository.getExpenditureSubItems(subItem.parentId);
        _subItems = freshSubItems;
        debugPrint('ExpenditureViewModel: Manual refresh completed - sub-items: ${freshSubItems.length}');
        notifyListeners();
      } catch (e) {
        debugPrint('Error refreshing sub-items after save: $e');
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      debugPrint('Error saving sub-item: $e');
      _showErrorSnackBar('Failed to save sub-item');
      return false;
    }
  }

  Future<bool> deleteSubItem(String id) async {
    try {
      if (_currentExpenseId == null) {
        _showErrorSnackBar('No expense selected');
        return false;
      }
      
      final subItems = await _repository.getExpenditureSubItems(_currentExpenseId!);
      final subItemToDelete = subItems.firstWhere((item) => item.id == id);
      
      final mainExpense = await _repository.getExpenditureById(_currentExpenseId!);
      if (mainExpense == null) {
        _showErrorSnackBar('Main expense not found');
        return false;
      }
      
      final newAmount = mainExpense.amount - subItemToDelete.amount;
      
      await _repository.updateExpenditureAmount(_currentExpenseId!, newAmount);
      
      await _repository.deleteExpenditureSubItem(id);
      
      _showSuccessSnackBar('Sub-item deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting sub-item: $e');
      _showErrorSnackBar('Failed to delete sub-item');
      return false;
    }
  }

  Future<double> getTotalOfficeExpenses() async {
    final companyId = local.RoleUtils.getUserCompanyId(_user);
    if (companyId == null) return 0.0;
    
    try {
      return await _repository.getTotalOfficeExpenses(companyId);
    } catch (e) {
      debugPrint('Error calculating total office expenses: $e');
      return 0.0;
    }
  }

  Future<double> getTotalProjectExpenses() async {
    final companyId = local.RoleUtils.getUserCompanyId(_user);
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

  Future<domain.ExpenditureItem?> getExpenditureById(String id) async {
    try {
      return await _repository.getExpenditureById(id);
    } catch (e) {
      debugPrint('Error fetching expenditure: $e');
      return null;
    }
  }

  void _showErrorSnackBar(String message) {
    debugPrint('Error: $message');
  }

  void _showSuccessSnackBar(String message) {
    debugPrint('Success: $message');
  }

  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }
  
  void setItemsPerPage(int limit) {
    if (_itemsPerPage != limit) {
      _itemsPerPage = limit;
      _currentPage = 1;
      notifyListeners();
    }
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
    _itemCategoryController.dispose();
    
    super.dispose();
  }
}