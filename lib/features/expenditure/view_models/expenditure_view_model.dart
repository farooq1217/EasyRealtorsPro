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
import '../../../core/services/auth_service.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/services/permission_helper.dart';
import '../../../core/services/firebase_threading_handler.dart';
import '../../../core/windows_platform_fix.dart';
import '../../../core/role_utils.dart' as local;
import 'package:shared/shared.dart';

enum ExpenditureTab { office, project }

class ExpenditureViewModel extends ChangeNotifier {
  final ExpenditureRepository _repository;
  final AppDatabase _database;
  final String? _passedCompanyId;
  final bool _passedIsSuperAdmin;
  final String? _passedUserId;
  
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
  
  // OPTIMIZATION: Cached user data to prevent initial null state
  String? _cachedCompanyId;
  bool? _cachedIsSuperAdmin;
  
  // OPTIMIZATION: Initialize user data from cached AuthService to prevent initial null state
  void _initializeUserFromCache() {
    final cachedUser = AuthService.currentUser;
    if (cachedUser != null) {
      _cachedCompanyId = local.RoleUtils.getUserCompanyId(cachedUser);
      _cachedIsSuperAdmin = local.RoleUtils.isSuperAdmin(cachedUser);
      debugPrint('ExpenditureViewModel: Initialized from AuthService cache - companyId: $_cachedCompanyId, isSuper: $_cachedIsSuperAdmin');
    } else {
      debugPrint('ExpenditureViewModel: No cached user data available');
    }
  }
  
  // Data lists
  List<domain.ExpenditureItem> _officeExpenses = [];
  List<domain.ExpenditureItem> _projectExpenses = [];
  List<domain.ExpenditureItem> _filteredOfficeExpenses = [];
  List<domain.ExpenditureItem> _filteredProjectExpenses = [];
  
  // Search
  String _searchQuery = '';
  
  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 10;
  
  // Form data
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  
  // Sub-items functionality
  List<domain.ExpenditureSubItem> _subItems = [];
  String? _currentExpenseId; // Track current expense ID for sub-item operations
  final TextEditingController _itemDescriptionController = TextEditingController();
  final TextEditingController _itemAmountController = TextEditingController();
  final TextEditingController _itemCategoryController = TextEditingController(); // New category controller
  String? _selectedItemCategory; // Track selected category for "Other" option
  
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
  TextEditingController get itemCategoryController => _itemCategoryController; // New getter
  String? get selectedItemCategory => _selectedItemCategory; // New getter
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
  
  // Calculate grand total for a project (bucket amount + all sub-items)
  Future<double> getProjectGrandTotal(String projectId) async {
    try {
      // Find the project/bucket item
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
      
      // Load all sub-items for this project
      final subItems = await _repository.getExpenditureSubItems(projectId);
      final subItemsTotal = subItems.fold(0.0, (sum, item) => sum + item.amount);
      
      // Return bucket amount + sub-items total
      return project.amount + subItemsTotal;
    } catch (e) {
      debugPrint('Error calculating project grand total: $e');
      return 0.0;
    }
  }
  
  bool get canAdd {
    if (_user == null) return false;
    
    // Super Admin always can add
    if (local.RoleUtils.isSuperAdmin(_user)) return true;
    
    // Company Admin always can add within their company
    if (local.RoleUtils.isCompanyAdmin(_user)) return true;
    
    // Check permission level for Agents
    final level = PermissionHelper.getModulePermissionLevel(_user, 'expenditure');
    return level == 'view_add' || level == 'view_add_edit' || level == 'full_access';
  }

  // Pagination getters
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (currentExpenses.length / _itemsPerPage).ceil();
  List<domain.ExpenditureItem> get paginatedExpenses {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    return currentExpenses.skip(startIndex).take(_itemsPerPage).toList();
  }

  // Initialization
  Future<void> initialize() async {
    try {
      // CRITICAL: Initialize Windows platform fixes to prevent stream interference
      WindowsPlatformFix.initialize();
      
      _loading = true;
      // OPTIMIZATION: Initialize from cache first to prevent initial null state
      _initializeUserFromCache();
      notifyListeners();
      
      // CRITICAL FIX: Load user first with timeout to prevent hanging
      await _loadUser().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('ExpenditureViewModel: User loading timed out, proceeding with default values');
          // FIXED: Wrap setState in postFrameCallback to prevent build phase errors
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loading = false;
            notifyListeners();
          });
        },
      );
      
      // CRITICAL FIX: Set loading to false immediately to show UI
      _loading = false;
      notifyListeners();
      
      // CRITICAL FIX: Move database checks to background with timeout to prevent hanging
      Future.microtask(() async {
        try {
          debugPrint('ExpenditureViewModel: Starting background database checks...');
          await _repository.ensureExpenditureTableColumns().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('ExpenditureViewModel: Database checks timed out, proceeding with streams');
            },
          );
          debugPrint('ExpenditureViewModel: Background database checks completed');
        } catch (e) {
          debugPrint('ExpenditureViewModel: Background database checks failed: $e');
          // Don't rethrow - continue with streams even if checks fail
        }
      });
      
      // CRITICAL FIX: Setup streams with timeout to prevent hanging
      await _setupStreams().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('ExpenditureViewModel: Stream setup timed out, UI should be visible');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loading = false;
            notifyListeners();
          });
        },
      );
    } catch (e) {
      debugPrint('Error initializing ExpenditureViewModel: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loading = false;
        notifyListeners();
      });
      notifyListeners();
    }
  }

  Future<void> _loadUser() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        _user = await AuthService.getCurrentUser(authToken);
        AuthService.currentUser = _user;
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  Future<void> _setupStreams() async {
    // CRITICAL FIX: Use passed parameters but also detect role for Super Admin fallback
    var companyId = _passedCompanyId;
    var isSuperAdmin = _passedIsSuperAdmin;
    
    // ROLE SYNC FIX: Re-detect role if passed parameters don't match user data
    if (_user != null) {
      final detectedRole = local.RoleUtils.getUserRole(_user);
      final detectedIsSuperAdmin = local.RoleUtils.isSuperAdmin(_user);
      
      debugPrint('ExpenditureViewModel: Role detection - Detected Role: $detectedRole, Detected isSuperAdmin: $detectedIsSuperAdmin');
      debugPrint('ExpenditureViewModel: Passed parameters - isSuperAdmin: $isSuperAdmin, companyId: $companyId');
      
      isSuperAdmin = detectedIsSuperAdmin;
      
      // CRITICAL FIX: Enhanced GLOBAL_ADMIN handling for Super Admin
      if (detectedIsSuperAdmin) {
        // Super Admin should always be allowed to use GLOBAL_ADMIN
        if (companyId != 'GLOBAL_ADMIN') {
          debugPrint('ExpenditureViewModel: ROLE SYNC FIX - Super Admin detected, setting companyId to GLOBAL_ADMIN');
          companyId = 'GLOBAL_ADMIN';
        }
        // CRITICAL: Never clear GLOBAL_ADMIN for confirmed Super Admin
      } else {
        // Only clear GLOBAL_ADMIN for confirmed non-super-admins
        if (companyId == 'GLOBAL_ADMIN') {
          debugPrint('ExpenditureViewModel: ROLE SYNC FIX - Confirmed non-super-admin with GLOBAL_ADMIN, clearing to empty');
          companyId = ''; // Clear to empty for non-super-admin
        }
      }
    } else {
      // If user is null, preserve original Super Admin status from passed parameters
      debugPrint('ExpenditureViewModel: User data not available, using passed isSuperAdmin: $isSuperAdmin');
      if (isSuperAdmin && companyId != 'GLOBAL_ADMIN') {
        debugPrint('ExpenditureViewModel: Using passed Super Admin status, setting companyId to GLOBAL_ADMIN');
        companyId = 'GLOBAL_ADMIN';
      }
    }
    
    // IMMEDIATE FALLBACK: Set default fallback for null companyId
    if (companyId == null) {
      if (isSuperAdmin) {
        companyId = 'GLOBAL_ADMIN';
        debugPrint('ExpenditureViewModel: IMMEDIATE FALLBACK - Set companyId to GLOBAL_ADMIN for Super Admin');
      } else {
        debugPrint('ExpenditureViewModel: No companyId provided for non-super-admin, using empty string to prevent hanging');
        companyId = '';
      }
    }
    
    debugPrint('ExpenditureViewModel: Final parameters - isSuperAdmin: $isSuperAdmin, companyId: $companyId');
    debugPrint('ExpenditureViewModel: User data - Email: ${_user?['email']}, Role: ${_user?['role']}, Permissions: ${_user?['permissions']}');
    
    // For Super Admin with GLOBAL_ADMIN, pass null to see all companies
    final effectiveCompanyId = (isSuperAdmin && companyId == 'GLOBAL_ADMIN') ? null : companyId;
    debugPrint('ExpenditureViewModel: Effective companyId for streams: $effectiveCompanyId (Super Admin: $isSuperAdmin)');

    // Cancel existing subscriptions
    await _officeExpensesSubscription?.cancel();
    await _projectExpensesSubscription?.cancel();

    // Setup new streams
    _officeExpensesSubscription = _repository.watchOfficeExpenses(effectiveCompanyId).listen(
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

    _projectExpensesSubscription = _repository.watchProjectExpenses(effectiveCompanyId).listen(
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
    if (tab != null) {
      _currentTab = tab;
      notifyListeners();
    }
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
    _currentPage = 1; // Reset to page 1 when search changes
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
        categoryType: type, // 'office' or 'project'
        category: type == 'office' ? 'Office Expense' : 'Project Expense', // FIXED: Set proper category based on type
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
      
      // STREAM-BASED UPDATE: Let streams handle the UI refresh automatically
      // The streams will detect the database changes and update the UI instantly
      debugPrint('ExpenditureViewModel: Expense saved - streams will update UI automatically');
      
      // No need for manual refresh - streams will handle the update
      // notifyListeners() is already called by stream listeners
      
      return true;
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  // New method to add a project as a simple bucket (no amount, date, or category)
  Future<bool> addProject(String projectName) async {
    try {
      // CRITICAL: Ensure Firebase calls are on main thread for Windows compatibility
      if (io.Platform.isWindows) {
        // On Windows, ensure we're on the main thread for Firebase operations
        await WidgetsBinding.instance.endOfFrame;
      }
      
      final companyId = local.RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      // Create project as a special type of expenditure with zero amount and current date
      final project = domain.ExpenditureItem(
        id: const Uuid().v4(),
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()), // Current date for metadata only
        description: projectName, // Project name as description
        amount: 0.0, // Zero amount - projects are just buckets
        categoryType: 'project_bucket', // New type to distinguish from project expenses
        category: 'Project Bucket', // FIXED: Set proper category for project buckets
        companyId: companyId,
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      print("Project Repository Save: ${project.toMap()}");
      
      await _repository.addExpenditure(project);
      
      // Show success message
      _showSuccessSnackBar('Project "$projectName" created successfully');
      
      // STREAM-BASED UPDATE: Let streams handle the UI refresh automatically
      // The streams will detect the database changes and update the UI instantly
      debugPrint('ExpenditureViewModel: Project created - streams will update UI automatically');
      
      // No need for manual refresh - streams will handle the update
      // notifyListeners() is already called by stream listeners
      
      return true;
    } catch (e) {
      debugPrint('Error creating project: $e');
      _showErrorSnackBar('Failed to create project: $e');
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
      
      final companyId = local.RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      // CRITICAL DEBUGGING: Create expenditure with proper office_expense type
      final expenditure = domain.ExpenditureItem(
        id: const Uuid().v4(),
        date: DateFormat('yyyy-MM-dd').format(selectedDate),
        description: description,
        amount: amount,
        categoryType: type, // 'office_expense' or 'project_expense' - CRITICAL for proper filtering
        category: category, // Category from dropdown
        companyId: companyId,
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // CRITICAL DEBUGGING: Print expenditure data before database save
      print("Expenditure Repository Save: ${expenditure.toMap()}");
      
      await _repository.addExpenditure(expenditure);
      
      // ENHANCED: Show success message for debugging
      if (kDebugMode) {
        print('$type expense saved successfully with category: $category');
        _showSuccessSnackBar('$type expense added successfully');
      }
      
      // STREAM-BASED UPDATE: Let streams handle the UI refresh automatically
      // The streams will detect the database changes and update the UI instantly
      debugPrint('ExpenditureViewModel: Expense saved with category - streams will update UI automatically');
      
      // No need for manual refresh - streams will handle the update
      // notifyListeners() is already called by stream listeners
      
      return true;
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
      return false;
    }
  }

  // Simplified method for instant expense saving from category grid - 1-step process with smart grouping
  Future<bool> saveInstantExpenseFromCategory(String type, String category, {
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
      
      final companyId = local.RoleUtils.getUserCompanyId(_user);
      if (companyId == null) {
        _showErrorSnackBar('Unable to determine company');
        return false;
      }
      
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      
      // SMART GROUPING: Check if existing expense with same date and category exists
      if (type == 'office_expense') {
        debugPrint('ExpenditureViewModel: Smart grouping check for office expense - Date: $dateStr, Category: $category');
        
        final existingExpense = await _repository.findExistingOfficeExpense(dateStr, category, companyId);
        
        if (existingExpense != null) {
          // EXISTING EXPENSE: Update amount and add as sub-item
          debugPrint('ExpenditureViewModel: Found existing expense, updating amount and adding sub-item');
          
          final newTotalAmount = existingExpense.amount + amount;
          
          // Update the main expense amount
          await _repository.updateExpenditureAmount(existingExpense.id, newTotalAmount);
          
          // Create sub-item for the new expense
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
          // NEW EXPENSE: Create new expenditure entry
          debugPrint('ExpenditureViewModel: No existing expense found, creating new entry');
          
          final expenditure = domain.ExpenditureItem(
            id: const Uuid().v4(),
            date: dateStr,
            description: description, // Use the description as the main detail
            amount: amount,
            categoryType: type, // 'office_expense'
            category: category, // Category from grid selection
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
        // PROJECT EXPENSES: Create new entry as before (no grouping for projects)
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
      
      // STREAM-BASED UPDATE: Let streams handle the UI refresh automatically
      // The streams will detect the database changes and update the UI instantly
      debugPrint('ExpenditureViewModel: Smart grouping completed - streams will update UI automatically');
      
      // No need for manual refresh - streams will handle the update
      // notifyListeners() is already called by stream listeners
      
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
      
      // STREAM-BASED UPDATE: Let streams handle the UI refresh automatically
      // The streams will detect the database changes and update the UI instantly
      debugPrint('ExpenditureViewModel: Expense deleted - streams will update UI automatically');
      
      // No need for manual refresh - streams will handle the update
      // notifyListeners() is already called by stream listeners
      
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
      
      // STREAM-BASED UPDATE: Let streams handle the UI refresh automatically
      // The streams will detect the database changes and update the UI instantly
      debugPrint('ExpenditureViewModel: Expense updated - streams will update UI automatically');
      
      // No need for manual refresh - streams will handle the update
      // notifyListeners() is already called by stream listeners
      
      return true;
    } catch (e) {
      debugPrint('Error updating expense: $e');
      _showErrorSnackBar('Failed to update expense');
      return false;
    }
  }

  // Sub-items operations
  Future<void> loadSubItems(String parentId) async {
    try {
      // Set current expense ID for sub-item operations
      _currentExpenseId = parentId;
      
      // CRITICAL: Ensure category column exists before loading sub-items
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
    _itemCategoryController.clear(); // Clear category controller
    _selectedItemCategory = null; // Reset selected category
    notifyListeners();
  }

  // Method to set selected sub-item category from dialog
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
      // Use the category that was set by the dialog
      final category = _selectedItemCategory;
          
      // Category is optional - allow saving without it
      if (category != null && category.isEmpty) {
        _showErrorSnackBar('Invalid category');
        return false;
      }
      
      final subItem = domain.ExpenditureSubItem(
        id: const Uuid().v4(),
        parentId: parentId,
        description: _itemDescriptionController.text.trim(),
        amount: double.parse(_itemAmountController.text.trim()),
        category: category, // Category field (nullable)
        companyId: local.RoleUtils.getUserCompanyId(_user) ?? '',
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
      _itemCategoryController.clear();
      _selectedItemCategory = null;
      
      return true;
    } catch (e) {
      debugPrint('Error saving sub-item: $e');
      _showErrorSnackBar('Failed to save sub-item');
      return false;
    }
  }

  // CRITICAL FIX: New method that accepts category as parameter
  // This ensures the selected category is properly saved to database
  Future<bool> saveSubItemWithCategory(String parentId, {String? category}) async {
    if (_itemDescriptionController.text.trim().isEmpty ||
        _itemAmountController.text.trim().isEmpty) {
      _showErrorSnackBar('Please fill all fields');
      return false;
    }
    
    try {
      // CRITICAL: Use category parameter directly instead of ViewModel state
      // This ensures the selected category from dialog is saved correctly
      debugPrint('ExpenditureViewModel: Saving sub-item with category: $category');
          
      // Category is optional - allow saving without it
      if (category != null && category.isEmpty) {
        _showErrorSnackBar('Invalid category');
        return false;
      }
      
      final subItem = domain.ExpenditureSubItem(
        id: const Uuid().v4(),
        parentId: parentId,
        description: _itemDescriptionController.text.trim(),
        amount: double.parse(_itemAmountController.text.trim()),
        category: category, // CRITICAL: Category from dialog parameter
        companyId: local.RoleUtils.getUserCompanyId(_user) ?? '',
        createdBy: _user?['id']?.toString() ?? _user?['userId']?.toString(),
        isActive: true,
        isSynced: true,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      debugPrint('ExpenditureViewModel: Sub-item data before save: ${subItem.toMap()}');
      
      await _repository.addExpenditureSubItem(subItem);
      
      // Clear form
      _itemDescriptionController.clear();
      _itemAmountController.clear();
      _itemCategoryController.clear();
      _selectedItemCategory = null;
      
      debugPrint('ExpenditureViewModel: Sub-item saved successfully with category: $category');
      
      // FOOLPROOF FIX: Manually fetch fresh sub-items and update state
      // This ensures immediate UI update after adding sub-item
      try {
        final freshSubItems = await _repository.getExpenditureSubItems(subItem.parentId);
        _subItems = freshSubItems;
        debugPrint('ExpenditureViewModel: Manual refresh completed - sub-items: ${freshSubItems.length}');
        notifyListeners(); // Force UI rebuild immediately
      } catch (e) {
        debugPrint('Error refreshing sub-items after save: $e');
        notifyListeners(); // Still try to update UI even if refresh fails
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
      
      // First, get the sub-item details to know its amount and parent
      final subItems = await _repository.getExpenditureSubItems(_currentExpenseId!);
      final subItemToDelete = subItems.firstWhere((item) => item.id == id);
      
      // Get the current main expense
      final mainExpense = await _repository.getExpenditureById(_currentExpenseId!);
      if (mainExpense == null) {
        _showErrorSnackBar('Main expense not found');
        return false;
      }
      
      // Calculate new amount (subtract sub-item amount from main expense)
      final newAmount = mainExpense.amount - subItemToDelete.amount;
      
      // Update the main expense amount first
      await _repository.updateExpenditureAmount(_currentExpenseId!, newAmount);
      
      // Then delete the sub-item
      await _repository.deleteExpenditureSubItem(id);
      
      _showSuccessSnackBar('Sub-item deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting sub-item: $e');
      _showErrorSnackBar('Failed to delete sub-item');
      return false;
    }
  }

  // Statistics
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

  // Pagination methods
  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }
  
  void setItemsPerPage(int limit) {
    if (_itemsPerPage != limit) {
      _itemsPerPage = limit;
      _currentPage = 1; // Reset to page 1 when items per page changes
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
    _itemCategoryController.dispose(); // Dispose category controller
    
    super.dispose();
  }
}
